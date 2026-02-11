import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/services/home_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../shared/widgets/cards/product_card.dart';
import '../../product/screens/product_details_screen.dart';
import '../../categories/screens/category_products_screen.dart';


/// Widget to display products for a selected category with infinite scroll
/// This widget exposes loading state and provides a method to load more products
class CategoryProductsGrid extends StatefulWidget {
  final ProductCategory category;
  final ScrollController? parentScrollController; // Optional parent scroll controller
  
  const CategoryProductsGrid({
    super.key,
    required this.category,
    this.parentScrollController,
  });

  @override
  State<CategoryProductsGrid> createState() => CategoryProductsGridState();
}

class CategoryProductsGridState extends State<CategoryProductsGrid> {
  List<Product> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _isPrefetching = false; // Track prefetch state to avoid duplicate calls
  bool _hasMore = true;
  int _currentPage = 1;
  StreamSubscription? _wishlistSubscription;

  @override
  void initState() {
    super.initState();
    // Try to load from cache first, then fetch if needed
    _loadLocalProducts();
    
    // If parent scroll controller is provided, use it for infinite scroll
    widget.parentScrollController?.addListener(_onParentScroll);
    
    // Listen for global wishlist updates to keep product states in sync
    _wishlistSubscription = WishlistHelper.onStatusChanged.listen((update) {
      if (!mounted) return;
      final index = _products.indexWhere((p) => p.id == update.id);
      if (index != -1) {
        setState(() {
          _products[index] = _products[index].copyWith(isLiked: update.isLiked);
        });
      }
    });
  }


  /// Try to load products from local cache for instant display
  void _loadLocalProducts() {
    final homeService = Provider.of<HomeService>(context, listen: false);
    
    // 1. Check specific category cache first (most relevant & fastest)
    final cached = homeService.getCachedCategoryProducts(widget.category.id);
    if (cached.isNotEmpty) {
      setState(() {
        _products = cached;
        _isLoading = false;
        // Estimate next page based on cached count (30 per page like home screen)
        _currentPage = (cached.length / 30).ceil() + 1;
        _hasMore = true;
      });
      return;
    }

    // 2. Fallback to home screen data
    final localMatches = homeService.allProducts.where((p) => p.categoryId == widget.category.id).toList();
    
    if (localMatches.isNotEmpty) {
      setState(() {
        _products = localMatches;
        _isLoading = false;
      });
      // Found some matches but not full list, so trigger fetch for more
      _fetchProducts(refresh: true);
    } else {
      // No local matches, fetch from API
      _fetchProducts(refresh: true);
    }
  }

  @override
  void didUpdateWidget(CategoryProductsGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If category changed, refetch
    if (oldWidget.category.id != widget.category.id) {
      _fetchProducts(refresh: true);
    }
    
    // Update scroll listener if controller changed
    if (oldWidget.parentScrollController != widget.parentScrollController) {
      oldWidget.parentScrollController?.removeListener(_onParentScroll);
      widget.parentScrollController?.addListener(_onParentScroll);
    }
  }

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    widget.parentScrollController?.removeListener(_onParentScroll);
    super.dispose();
  }

  void _onParentScroll() {
    final controller = widget.parentScrollController;
    if (controller == null) return;
    
    // SMART FETCH: Percentage-based loading like home screen
    final maxScroll = controller.position.maxScrollExtent;
    if (maxScroll > 0) {
      final currentScroll = controller.position.pixels;
      final scrollPercentage = (currentScroll / maxScroll * 100).clamp(0, 100);
      
      // AGGRESSIVE PREFETCH: Start loading at just 1% scroll (user barely scrolled)
      // This ensures products are ready before user even sees the loading indicator
      if (scrollPercentage >= 1 && !_isPrefetching && !_isLoadingMore && _hasMore && !_isLoading) {
        _isPrefetching = true;
        _fetchProducts().then((_) => _isPrefetching = false);
      }
    }
  }

  /// Public method to trigger loading more products
  void loadMore() {
    if (!_isLoadingMore && _hasMore && !_isLoading) {
      _fetchProducts();
    }
  }

  Future<void> _fetchProducts({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      setState(() {
        _isLoading = true;
        _products = [];
      });
    }

    if (!_hasMore && !refresh) return;

    final homeService = Provider.of<HomeService>(context, listen: false);
    
    try {
      if (!refresh) {
        setState(() => _isLoadingMore = true);
      }
      
      final result = await homeService.fetchProductsByCategory(
        widget.category.id,
        page: _currentPage,
        sortBy: 'newest',
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
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Loading state
    if (_isLoading) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.62,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          delegate: SliverChildBuilderDelegate(
            (_, __) => _buildShimmerCard(),
            childCount: 6,
          ),
        ),
      );
    }

    // Empty state
    if (_products.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.inventory_2_outlined,
                  size: 48,
                  color: isDark ? Colors.white24 : Colors.black26,
                ),
                const SizedBox(height: 12),
                Text(
                  'No products found',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try selecting a different category',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Products grid with loading more indicator
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: isDark 
                  ? Colors.black.withOpacity(0.5) 
                  : Colors.black.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // View All header - goes to products page
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryProductsScreen(
                        category: widget.category,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Products',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            'View All',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: AppColors.primary500,
                            ),
                          ),
                          const SizedBox(width: 3),
                          Icon(
                            Iconsax.arrow_right_3,
                            size: 14,
                            color: AppColors.primary500,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              // Products grid - tight spacing with header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                child: MasonryGridView.count(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  itemCount: _products.length + (_isLoadingMore ? 4 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _products.length) {
                      return _buildShimmerCard();
                    }
                    final product = _products[index];
                    return RepaintBoundary(
                      child: ProductCard.fromProduct(
                        product,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // End message
              if (!_hasMore && _products.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Center(
                    child: Text(
                      'You\'ve seen all products!',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Fixed heights for masonry grid
    final heights = [180.0, 220.0, 200.0, 240.0, 190.0, 210.0];
    final height = heights[DateTime.now().millisecond % heights.length];
    
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark
              ? AppColors.neutral800.withOpacity(0.3)
              : AppColors.neutral200.withOpacity(0.4),
          width: 0.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            Expanded(
              child: Container(
                width: double.infinity,
                color: isDark ? Colors.grey[850] : Colors.grey[200],
                child: Image.asset(
                  'assets/images/productfailbackorskeleton_loading.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, __, ___) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[300],
                  ),
                ),
              ),
            ),
            // Text placeholder
            Padding(
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
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 80,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[400],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
