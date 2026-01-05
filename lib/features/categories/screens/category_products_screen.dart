import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:async';
import '../../../core/theme/theme.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../shared/widgets/cards/product_card.dart';
import '../../product/screens/product_details_screen.dart';

/// SHEIN-style Category Products Screen with story-like category circles
class CategoryProductsScreen extends StatefulWidget {
  final ProductCategory category;
  final List<ProductCategory>? siblingCategories;

  const CategoryProductsScreen({
    super.key,
    required this.category,
    this.siblingCategories,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  
  List<Product> _products = [];
  bool _isLoading = false;
  late ProductCategory _selectedCategory;
  
  // Pagination State
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  // Filter State
  String _sortBy = 'newest';
  double? _minPrice;
  double? _maxPrice;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  StreamSubscription? _wishlistSubscription;

  // All sibling categories for the story circles
  List<ProductCategory> _allCategories = [];

  @override
  void initState() {
    super.initState();
    _selectedCategory = widget.category;
    
    _initializeCategories();
    
    _wishlistSubscription = WishlistHelper.onStatusChanged.listen((update) {
      if (!mounted) return;
      final index = _products.indexWhere((p) => p.id == update.id);
      if (index != -1) {
        setState(() {
          _products[index] = _products[index].copyWith(isLiked: update.isLiked);
        });
      }
    });

    _scrollController.addListener(_onScroll);
    _fetchProducts(refresh: true);
    
    // Listen for HomeService updates (e.g., when product name gets translated)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final homeService = Provider.of<HomeService>(context, listen: false);
      homeService.addListener(_onHomeServiceUpdate);
    });
  }
  
  /// Called when HomeService notifies (e.g., product cache updated with translated name)
  void _onHomeServiceUpdate() {
    if (!mounted) return;
    final homeService = Provider.of<HomeService>(context, listen: false);
    final cachedProducts = homeService.getCachedCategoryProducts(_selectedCategory.id);
    
    // Update local products with any changes from cache (e.g., translated names)
    bool anyUpdated = false;
    for (int i = 0; i < _products.length; i++) {
      final cached = cachedProducts.firstWhere(
        (p) => p.id == _products[i].id,
        orElse: () => _products[i],
      );
      // Check if name changed (translation happened)
      if (cached.name != _products[i].name && cached.name.isNotEmpty) {
        _products[i] = _products[i].copyWith(
          name: cached.name,
          displayName: cached.displayName,
        );
        anyUpdated = true;
      }
    }
    
    if (anyUpdated) {
      setState(() {});
      debugPrint('🔄 Updated products with translated names from cache');
    }
  }

  void _initializeCategories() {
    if (widget.siblingCategories != null && widget.siblingCategories!.isNotEmpty) {
      _allCategories = widget.siblingCategories!;
    } else {
      _allCategories = [widget.category];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadSiblingCategories();
      });
    }
  }

  void _loadSiblingCategories() {
    final categoryService = Provider.of<CategoryService>(context, listen: false);
    
    for (final parent in categoryService.categories) {
      if (parent.subcategories != null) {
        final found = parent.subcategories!.any((sub) => sub.id == widget.category.id);
        if (found) {
          setState(() {
            _allCategories = parent.subcategories!;
          });
          _scrollToSelectedCategory();
          break;
        }
      }
    }
  }

  void _scrollToSelectedCategory() {
    final selectedIndex = _allCategories.indexWhere((c) => c.id == _selectedCategory.id);
    if (selectedIndex != -1 && _categoryScrollController.hasClients) {
      final targetOffset = selectedIndex * 90.0;
      _categoryScrollController.animateTo(
        targetOffset.clamp(0.0, _categoryScrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 300) {
      if (!_isLoadingMore && _hasMore) {
        _fetchProducts();
      }
    }
  }

  Future<void> _fetchProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    final homeService = Provider.of<HomeService>(context, listen: false);
    
    // Check if we have cached products for instant display (only for first page with default filters)
    final isDefaultFilters = _sortBy == 'newest' && _minPrice == null && _maxPrice == null;
    if (refresh && isDefaultFilters) {
      final cachedProducts = homeService.getCachedCategoryProducts(_selectedCategory.id);
      if (cachedProducts.isNotEmpty) {
        setState(() {
          _products = cachedProducts;
          _isLoading = false;
          _hasMore = true; // Assume more pages exist
        });
        debugPrint('⚡ Instant load: ${cachedProducts.length} cached products for category ${_selectedCategory.id}');
        // Fetch fresh data in background
        _fetchProductsInBackground();
        return;
      }
    }
    
    try {
      if (refresh) {
        setState(() => _isLoading = true);
      } else {
        setState(() => _isLoadingMore = true);
      }
      
      final result = await homeService.fetchProductsByCategory(
        _selectedCategory.id,
        page: _currentPage,
        sortBy: _sortBy,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
      );
      
      if (mounted) {
        setState(() {
          final rawProducts = result['products'] as List<Product>? ?? [];
          // Allow all products including those with price 0 (API products where price is fetched on detail view)
          final newProducts = rawProducts.toList();
          
          final pagination = result['pagination'];
          
          if (refresh) {
            _products = newProducts;
          } else {
            _products.addAll(newProducts);
          }
          
          if (pagination != null) {
            _hasMore = pagination['has_next'] == true || pagination['has_next'] == 1;
            if (_hasMore) {
              _currentPage++;
            }
          } else {
            _hasMore = newProducts.isNotEmpty;
            if (_hasMore) _currentPage++;
          }

          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching products: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }
  
  /// Fetch fresh products in background without blocking UI
  Future<void> _fetchProductsInBackground() async {
    final homeService = Provider.of<HomeService>(context, listen: false);
    
    try {
      final result = await homeService.fetchProductsByCategory(
        _selectedCategory.id,
        page: 1,
        sortBy: _sortBy,
      );
      
      if (mounted && result['fromCache'] != true) {
        final newProducts = result['products'] as List<Product>? ?? [];
        final pagination = result['pagination'];
        
        // Only update if product count changed
        if (newProducts.length != _products.length) {
          setState(() {
            _products = newProducts;
            _hasMore = pagination?['has_next'] == true;
            _currentPage = 2;
          });
          debugPrint('🔄 Background refresh: updated to ${newProducts.length} products');
        }
      }
    } catch (e) {
      debugPrint('Background fetch error: $e');
    }
  }

  void _onCategorySelected(ProductCategory category) {
    if (category.id == _selectedCategory.id) return;
    
    setState(() {
      _selectedCategory = category;
      _products = [];
      _isLoading = true;
    });
    
    _fetchProducts(refresh: true);
  }

  void _applyFilters() {
    setState(() {
      _minPrice = double.tryParse(_minPriceController.text);
      _maxPrice = double.tryParse(_maxPriceController.text);
      _products = [];
    });
    Navigator.pop(context);
    _fetchProducts(refresh: true);
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              padding: const EdgeInsets.all(24),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Filters', style: AppTypography.headingSmall(color: isDark ? Colors.white : Colors.black)),
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    // Sort By
                    Text('Sort By', style: AppTypography.labelLarge(color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      children: [
                        _buildSortChip('Newest', 'newest', isDark, setSheetState),
                        _buildSortChip('Price: Low to High', 'price_asc', isDark, setSheetState),
                        _buildSortChip('Price: High to Low', 'price_desc', isDark, setSheetState),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Price Range
                    Text('Price Range', style: AppTypography.labelLarge(color: isDark ? Colors.white70 : Colors.black87)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Min',
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text('-', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _maxPriceController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            style: TextStyle(color: isDark ? Colors.white : Colors.black),
                            decoration: InputDecoration(
                              hintText: 'Max',
                              hintStyle: TextStyle(color: isDark ? Colors.white38 : Colors.black38),
                              filled: true,
                              fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Apply Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _applyFilters,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary500,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: const Text('Apply Filters', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSortChip(String label, String value, bool isDark, StateSetter setSheetState) {
    final isSelected = _sortBy == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (bool selected) {
        setSheetState(() {
          _sortBy = value;
        });
        setState(() {
          _sortBy = value;
        });
      },
      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
      selectedColor: AppColors.primary500,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary500 : Colors.transparent,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    
    // Remove HomeService listener
    final homeService = Provider.of<HomeService>(context, listen: false);
    homeService.removeListener(_onHomeServiceUpdate);
    
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusBarHeight = MediaQuery.of(context).padding.top;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: Column(
          children: [
            // Header with back button and filter
            Container(
              padding: EdgeInsets.only(top: statusBarHeight),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Top row: Back, Title, Filter
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            _selectedCategory.name,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black,
                              height: 1.2,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Stack(
                          children: [
                            IconButton(
                              onPressed: _showFilterSheet,
                              icon: Icon(
                                Iconsax.setting_4,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                            ),
                            if (_minPrice != null || _maxPrice != null || _sortBy != 'newest')
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: AppColors.primary500,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  // Story-style category circles
                  if (_allCategories.length > 1)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        controller: _categoryScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _allCategories.length,
                        itemBuilder: (context, index) {
                          final category = _allCategories[index];
                          final isSelected = category.id == _selectedCategory.id;
                          
                          return GestureDetector(
                            onTap: () => _onCategorySelected(category),
                            child: Container(
                              width: 80,
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Circle avatar with border
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected 
                                            ? AppColors.primary500 
                                            : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
                                        width: isSelected ? 3 : 2,
                                      ),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: ClipOval(
                                        child: category.mainImage != null && category.mainImage!.isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: category.mainImage!,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) => Image.asset(
                                                  'assets/images/category_loadingorfailbak.png',
                                                  fit: BoxFit.cover,
                                                ),
                                                errorWidget: (context, url, error) => Image.asset(
                                                  'assets/images/category_loadingorfailbak.png',
                                                  fit: BoxFit.cover,
                                                ),
                                              )
                                            : Image.asset(
                                                'assets/images/category_loadingorfailbak.png',
                                                fit: BoxFit.cover,
                                              ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  // Category name - allow wrapping to 2 lines
                                  SizedBox(
                                    height: 28,
                                    child: Text(
                                      category.name,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                                        color: isSelected 
                                            ? AppColors.primary500 
                                            : (isDark ? Colors.white70 : Colors.black87),
                                        height: 1.2,
                                      ),
                                      textAlign: TextAlign.center,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      softWrap: true,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
            
            // Products Grid
            Expanded(
              child: _isLoading
                  ? _buildLoadingGrid(isDark)
                  : _products.isEmpty
                      ? _buildEmptyState(isDark)
                      : _buildProductsGrid(isDark),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingGrid(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.62,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/productfailbackorskeleton_loading.png',
              fit: BoxFit.cover,
            ),
          ).animate(onPlay: (controller) => controller.repeat())
           .shimmer(duration: 1200.ms, color: isDark ? Colors.white10 : Colors.white54);
        },
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.box, size: 48, color: isDark ? Colors.white54 : Colors.black26),
          const SizedBox(height: 16),
          Text(
            'No products found',
            style: AppTypography.bodyLarge(
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductsGrid(bool isDark) {
    return RefreshIndicator(
      onRefresh: () => _fetchProducts(refresh: true),
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
                return ProductCard.fromProduct(
                  product,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProductDetailsScreen(product: product),
                      ),
                    );
                    // Note: Removed .then(() => _fetchProducts(refresh: true)) because
                    // it was overwriting the wishlist state. The wishlist subscription
                    // already keeps the state in sync without needing to refetch.
                  },
                ).animate().fadeIn(delay: Duration(milliseconds: 50 * (index % 6)));

              },
            ),
          ),
          
          // Loading more indicator
          if (_isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: isDark ? Colors.white : AppColors.primary500,
                    ),
                  ),
                ),
              ),
            ),
          
          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }
}
