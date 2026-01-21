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
import '../../../core/services/product_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../core/utils/image_helper.dart';
import '../../../shared/widgets/cards/product_card.dart';
import '../../product/screens/product_details_screen.dart';

/// SHEIN-style Category Products Screen with hierarchical category navigation
class CategoryProductsScreen extends StatefulWidget {
  final ProductCategory category;
  final List<ProductCategory>? siblingCategories; // Kept for backward compatibility

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

  // Categories to display in the top bar (selected + siblings)
  List<ProductCategory> _displayCategories = [];
  bool _isLoadingCategories = false;

  @override
  void initState() {
    super.initState();
    // Always start with the passed category as selected
    _selectedCategory = widget.category;
    
    // Load display categories (selected + siblings)
    _loadDisplayCategories();
    
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
    
    // NOTE: HomeService listener removed - updateProductInCache no longer notifies
    // This was causing expensive UI rebuilds. Cache updates happen silently.
  }
  
  /// Load categories to display in top bar: selected category + its siblings
  Future<void> _loadDisplayCategories() async {
    if (!mounted) return;
    
    setState(() => _isLoadingCategories = true);
    
    final categoryService = Provider.of<CategoryService>(context, listen: false);
    
    // First, check if the selected category has subcategories (children)
    List<ProductCategory> children = [];
    
    // Check embedded subcategories
    if (_selectedCategory.subcategories != null && _selectedCategory.subcategories!.isNotEmpty) {
      children = _selectedCategory.subcategories!;
    } else {
      // Check cache
      children = categoryService.getCachedSubcategories(_selectedCategory.id) ?? [];
      
      // Fetch from API if not cached
      if (children.isEmpty) {
        try {
          final response = await categoryService.fetchSubcategories(
            _selectedCategory.id,
            page: 1,
            perPage: 50,
          );
          children = response['subcategories'] as List<ProductCategory>? ?? [];
        } catch (e) {
          debugPrint('❌ Error fetching subcategories: $e');
        }
      }
    }
    
    if (children.isNotEmpty) {
      // Category has children - show the selected category + its children as siblings
      // Put selected category first, then its children
      setState(() {
        _displayCategories = [_selectedCategory, ...children];
        _isLoadingCategories = false;
      });
      debugPrint('📂 Display: ${_selectedCategory.name} + ${children.length} children');
    } else {
      // Category has no children - find and show siblings (categories with same parent)
      await _loadSiblingCategories();
    }
    
    // Scroll to selected category
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToSelectedCategory();
    });
  }
  
  /// Load sibling categories (same parent level)
  Future<void> _loadSiblingCategories() async {
    if (!mounted) return;
    
    final categoryService = Provider.of<CategoryService>(context, listen: false);
    final parentId = _selectedCategory.parentId;
    
    if (parentId != null && parentId > 0) {
      // Has a parent - get siblings from parent's children
      List<ProductCategory> siblings = categoryService.getCachedSubcategories(parentId) ?? [];
      
      if (siblings.isEmpty) {
        try {
          final response = await categoryService.fetchSubcategories(parentId, page: 1, perPage: 50);
          siblings = response['subcategories'] as List<ProductCategory>? ?? [];
        } catch (e) {
          debugPrint('❌ Error fetching siblings: $e');
        }
      }
      
      if (siblings.isNotEmpty) {
        setState(() {
          _displayCategories = siblings;
          _isLoadingCategories = false;
        });
        debugPrint('📂 Display siblings: ${siblings.length} items');
        return;
      }
    }
    
    // Fallback: just show the selected category alone
    setState(() {
      _displayCategories = [_selectedCategory];
      _isLoadingCategories = false;
    });
  }

  void _scrollToSelectedCategory() {
    if (_displayCategories.length <= 1) return;
    
    final selectedIndex = _displayCategories.indexWhere((c) => c.id == _selectedCategory.id);
    if (selectedIndex != -1) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (!mounted || !_categoryScrollController.hasClients) return;
        
        // Each item is 80px wide + 8px margin = 88px total
        const itemWidth = 88.0;
        final viewportWidth = _categoryScrollController.position.viewportDimension;
        // Calculate offset to center the selected item
        final targetOffset = (selectedIndex * itemWidth) - (viewportWidth / 2) + (itemWidth / 2);
        _categoryScrollController.animateTo(
          targetOffset.clamp(0.0, _categoryScrollController.position.maxScrollExtent),
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      });
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
    if (!mounted) return;
    
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
    if (!mounted) return;
    
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

  /// Check if a category has children (subcategories)
  Future<bool> _categoryHasChildren(ProductCategory category) async {
    // First check embedded subcategories
    if (category.subcategories != null && category.subcategories!.isNotEmpty) {
      return true;
    }
    
    // Check cache
    final categoryService = Provider.of<CategoryService>(context, listen: false);
    final cached = categoryService.getCachedSubcategories(category.id);
    if (cached != null && cached.isNotEmpty) {
      return true;
    }
    
    // Fetch from API to check
    try {
      final response = await categoryService.fetchSubcategories(
        category.id,
        page: 1,
        perPage: 1, // Just need to know if any exist
      );
      final children = response['subcategories'] as List<ProductCategory>? ?? [];
      return children.isNotEmpty;
    } catch (e) {
      debugPrint('❌ Error checking children: $e');
      return false;
    }
  }

  /// When a category is tapped from the top bar
  void _onCategorySelected(ProductCategory category) async {
    if (category.id == _selectedCategory.id) return;
    
    debugPrint('📂 Category tapped: ${category.name} (id: ${category.id})');
    
    // INSTANT FEEDBACK: Immediately show selection and start loading
    setState(() {
      _selectedCategory = category;
      _products = [];
      _isLoading = true;
    });
    
    // Scroll to selected category immediately
    _scrollToSelectedCategory();
    
    // Check if the tapped category has children
    final hasChildren = await _categoryHasChildren(category);
    
    if (hasChildren) {
      // Category has children - push new screen to show subcategories in top bar
      // But first, restore products loading state since we're navigating away
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryProductsScreen(
              category: category,
            ),
          ),
        );
      }
    } else {
      // Leaf category (no children) - products are already loading, just continue
      _fetchProducts(refresh: true);
    }
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
    
    // NOTE: HomeService listener was removed - no longer needed
    
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
                  
                  // Story-style category circles (selected + siblings/children)
                  if (_displayCategories.isNotEmpty)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        controller: _categoryScrollController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        itemCount: _displayCategories.length,
                        itemBuilder: (context, index) {
                          final category = _displayCategories[index];
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
                                        child: ImageHelper.parse(category.mainImage).isNotEmpty
                                            ? CachedNetworkImage(
                                                imageUrl: ImageHelper.parse(category.mainImage),
                                                fit: BoxFit.cover,
                                                memCacheWidth: 128,
                                                memCacheHeight: 128,
                                                maxWidthDiskCache: 128,
                                                maxHeightDiskCache: 128,
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
                    )
                  else if (_isLoadingCategories)
                    SizedBox(
                      height: 120,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: 6,
                        itemBuilder: (context, index) {
                          return Container(
                            width: 70,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Circle placeholder
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                                  ),
                                  child: ClipOval(
                                    child: Image.asset(
                                      'assets/images/category_loadingorfailbak.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                // Text placeholder
                                Container(
                                  height: 10,
                                  width: 50,
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          ).animate(onPlay: (controller) => controller.repeat())
                           .shimmer(duration: 1200.ms, color: isDark ? Colors.white10 : Colors.white54);
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
          return Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.08) 
                    : Colors.black.withOpacity(0.06),
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image section with aspect ratio 1:1 like ProductCard
                  AspectRatio(
                    aspectRatio: 1,
                    child: Image.asset(
                      'assets/images/productfailbackorskeleton_loading.png',
                      fit: BoxFit.cover,
                      width: double.infinity,
                    ),
                  ),
                  // Info section skeleton
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: 12,
                            width: 80,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            height: 14,
                            width: 60,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[700] : Colors.grey[400],
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
