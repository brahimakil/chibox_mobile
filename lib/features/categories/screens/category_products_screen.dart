import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:ui';
import 'dart:math';
import '../../../core/theme/theme.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/home_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../shared/widgets/cards/product_card.dart';
import 'dart:async';
import '../../product/screens/product_details_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final ProductCategory category;

  const CategoryProductsScreen({
    super.key,
    required this.category,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  double _sheetPosition = 0.6;
  List<Product> _products = [];
  bool _isLoading = false;
  
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

  @override
  void initState() {
    super.initState();
    
    // Listen for global wishlist updates
    _wishlistSubscription = WishlistHelper.onStatusChanged.listen((update) {
      if (!mounted) return;
      final index = _products.indexWhere((p) => p.id == update.id);
      if (index != -1) {
        setState(() {
          _products[index] = _products[index].copyWith(isLiked: update.isLiked);
        });
      }
    });

    _sheetController.addListener(() {
      if (mounted) {
        setState(() {
          _sheetPosition = _sheetController.size;
        });
      }
    });
    
    // 1. Try to load from local cache first (instant)
    final loadedFromCache = _loadLocalProducts();

    // 2. Then fetch fresh data from API (background) ONLY if not in cache
    if (!loadedFromCache) {
      _fetchProducts(refresh: true);
    }
  }

  bool _loadLocalProducts() {
    final homeService = Provider.of<HomeService>(context, listen: false);
    
    // 1. Check specific category cache first (most relevant & fastest)
    final cached = homeService.getCachedCategoryProducts(widget.category.id);
    if (cached.isNotEmpty) {
       setState(() { 
         _products = cached; 
         _isLoading = false;
         // Estimate next page based on cached count (assuming 10 per page)
         _currentPage = (cached.length / 10).ceil() + 1;
         _hasMore = true; 
       });
       return true;
    }

    // 2. Fallback to home screen data
    final localMatches = homeService.allProducts.where((p) => p.categoryId == widget.category.id).toList();
    
    if (localMatches.isNotEmpty) {
      setState(() {
        _products = localMatches;
        _isLoading = false;
      });
      // Found some matches but not full list, so return false to trigger fetch
      return false;
    } else {
      // If no local matches, show loading
      setState(() => _isLoading = true);
      return false;
    }
  }

  Future<void> _fetchProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
    }

    if (!_hasMore && !refresh) return;

    final homeService = Provider.of<HomeService>(context, listen: false);
    
    try {
      // Only show full loading if we have absolutely no data or if filtering/refreshing
      if (refresh && _products.isEmpty) {
        setState(() => _isLoading = true);
      } else if (!refresh) {
        setState(() => _isLoadingMore = true);
      }
      
      final result = await homeService.fetchProductsByCategory(
        widget.category.id,
        page: _currentPage,
        sortBy: _sortBy,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
      );
      
      if (mounted) {
        setState(() {
          final rawProducts = result['products'] as List<Product>? ?? [];
          // Filter out products with 0 price
          final newProducts = rawProducts.where((p) => (p.price ?? 0) > 0).toList();
          
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
            // Fallback if no pagination data
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

  void _applyFilters() {
    setState(() {
      _minPrice = double.tryParse(_minPriceController.text);
      _maxPrice = double.tryParse(_maxPriceController.text);
      _isLoading = true;
      _products = []; // Clear current list
    });
    Navigator.pop(context); // Close sheet
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
    _sheetController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use fetched products, or fallback to empty list
    final categoryProducts = _products;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          // 1. Parallax Header Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).size.height * 0.65, // Cover top 65%
            child: Transform.scale(
              scale: 1.0 + (_sheetPosition - 0.6) * 0.5, // Zoom effect when dragging up
              child: widget.category.mainImage != null && widget.category.mainImage!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: widget.category.mainImage!,
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

          // Gradient Overlay for text visibility if needed (optional)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 120,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),



          // Title in Header (Visible when sheet is down)
          Positioned(
            top: MediaQuery.of(context).size.height * 0.25,
            left: 24,
            right: 24,
            child: Opacity(
              opacity: (1.0 - ((_sheetPosition - 0.6) / 0.4)).clamp(0.0, 1.0), // Fade out as sheet goes up
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.category.name,
                    style: AppTypography.headingLarge(color: Colors.white).copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black.withOpacity(0.5),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.2, end: 0),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: Text(
                        _isLoading ? 'Loading...' : '${categoryProducts.length} Products',
                        style: AppTypography.labelMedium(color: Colors.white),
                      ),
                    ),
                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                ],
              ),
            ),
          ),

          // 2. Draggable Bottom Sheet
          Positioned.fill(
            top: MediaQuery.of(context).padding.top + 60,
            child: DraggableScrollableSheet(
              controller: _sheetController,
            initialChildSize: 1.0, // Start fully expanded
            minChildSize: 0.55,
            maxChildSize: 1.0,
            snap: true,
            snapSizes: const [0.6, 1.0],
            builder: (context, scrollController) {
              return NotificationListener<ScrollNotification>(
                onNotification: (ScrollNotification scrollInfo) {
                  // Smart Prefetching: Load more when user scrolls 70% down the list
                  if (!_isLoadingMore && 
                      _hasMore && 
                      scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.7) {
                    _fetchProducts();
                  }
                  return false;
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF121212) : const Color(0xFFF8F9FA),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: CustomScrollView(
                    controller: scrollController,
                    physics: const BouncingScrollPhysics(),
                    slivers: [
                      // Drag Handle
                      SliverToBoxAdapter(
                        child: Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 20),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withOpacity(0.2) : AppColors.neutral300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),

                      // Sheet Header (Title)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Text(
                            'Collection',
                            style: AppTypography.headingSmall(
                              color: isDark ? Colors.white : AppColors.neutral900,
                            ),
                          ),
                        ),
                      ),

                      SliverToBoxAdapter(child: AppSpacing.verticalLg),

                      // Products Grid
                      if (_isLoading && _products.isEmpty)
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          sliver: SliverGrid(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 0.62,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                return Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ).animate(onPlay: (controller) => controller.repeat())
                                 .shimmer(duration: 1200.ms, color: isDark ? Colors.white10 : Colors.white54);
                              },
                              childCount: 6,
                            ),
                          ),
                        )
                      else if (categoryProducts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
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
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          sliver: SliverMasonryGrid.count(
                            crossAxisCount: 2,
                            mainAxisSpacing: 4,
                            crossAxisSpacing: 4,
                            childCount: categoryProducts.length,
                            itemBuilder: (context, index) {
                              final product = categoryProducts[index];
                              return ProductCard.fromProduct(
                                product,
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => ProductDetailsScreen(product: product),
                                    ),
                                  ).then((_) {
                                    if (mounted) {
                                      _fetchProducts(refresh: true);
                                    }
                                  });
                                },
                              ).animate().fadeIn(delay: Duration(milliseconds: 50 * (index % 6)));
                            },
                          ),
                        ),

                      // Loading More Indicator
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

                      SliverToBoxAdapter(child: AppSpacing.verticalXxl),
                      SliverToBoxAdapter(child: AppSpacing.verticalXxl), // Extra padding for bottom
                    ],
                  ),
                ),
              );
            },
          ),
          ),

          // Back Button (Moved to end of Stack to stay on top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: IconButton(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black.withOpacity(0.3),
                padding: const EdgeInsets.all(12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),

          // Filter Button (Moved to end of Stack to stay on top)
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: Stack(
              children: [
                IconButton(
                  onPressed: _showFilterSheet,
                  icon: const Icon(Iconsax.setting_4, color: Colors.white),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withOpacity(0.3),
                    padding: const EdgeInsets.all(12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                if (_minPrice != null || _maxPrice != null || _sortBy != 'newest')
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.primary500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary500
            : (isDark ? Colors.white.withOpacity(0.05) : AppColors.neutral100),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected
              ? AppColors.primary500
              : (isDark ? Colors.white.withOpacity(0.1) : AppColors.neutral200),
        ),
      ),
      child: Text(
        label,
        style: AppTypography.labelMedium(
          color: isSelected
              ? Colors.white
              : (isDark ? Colors.white : AppColors.neutral700),
        ),
      ),
    );
  }
}
