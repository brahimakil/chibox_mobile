import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/home_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../shared/widgets/widgets.dart';
import 'dart:async';
import '../../product/screens/product_details_screen.dart';

class SearchResultsScreen extends StatefulWidget {
  final List<Product>? initialProducts;
  final String title;
  final String? searchQuery;
  final String? imagePath;

  const SearchResultsScreen({
    super.key,
    this.initialProducts,
    this.title = 'Search Results',
    this.searchQuery,
    this.imagePath,
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  late List<Product> _products;
  late ScrollController _scrollController;
  bool _isLoadingMore = false;
  bool _isInitialLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  StreamSubscription? _wishlistSubscription;

  @override
  void initState() {
    super.initState();
    _products = widget.initialProducts != null ? List.from(widget.initialProducts!) : [];
    _scrollController = ScrollController()..addListener(_onScroll);
    
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

    // If no initial products provided, load them
    if (widget.initialProducts == null || widget.initialProducts!.isEmpty) {
      _loadInitial();
    } else if (_products.length < 20) {
      // If initial load was less than 20, assume no more
      _hasMore = false;
    }
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
    });

    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      Map<String, dynamic> result;

      if (widget.searchQuery != null) {
        result = await homeService.searchProductsPaginated(
          widget.searchQuery!,
          page: 1,
        );
      } else if (widget.imagePath != null) {
        result = await homeService.searchByImagePaginated(
          widget.imagePath!,
          page: 1,
        );
      } else {
        setState(() => _isInitialLoading = false);
        return;
      }

      final newProducts = result['products'] as List<Product>;
      final hasNext = result['has_next'] as bool;

      if (mounted) {
        setState(() {
          _products = newProducts;
          _hasMore = hasNext;
          _currentPage = 1;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading initial search results: $e');
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      Map<String, dynamic> result;

      if (widget.searchQuery != null) {
        result = await homeService.searchProductsPaginated(
          widget.searchQuery!,
          page: _currentPage + 1,
        );
      } else if (widget.imagePath != null) {
        result = await homeService.searchByImagePaginated(
          widget.imagePath!,
          page: _currentPage + 1,
        );
      } else {
        // Should not happen
        setState(() => _isLoadingMore = false);
        return;
      }

      final newProducts = result['products'] as List<Product>;
      final hasNext = result['has_next'] as bool;

      if (mounted) {
        setState(() {
          _products.addAll(newProducts);
          _hasMore = hasNext;
          _currentPage++;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading more search results: $e');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      Map<String, dynamic> result;

      if (widget.searchQuery != null) {
        result = await homeService.searchProductsPaginated(
          widget.searchQuery!,
          page: 1,
        );
      } else if (widget.imagePath != null) {
        result = await homeService.searchByImagePaginated(
          widget.imagePath!,
          page: 1,
        );
      } else {
        setState(() => _isLoadingMore = false);
        return;
      }

      final newProducts = result['products'] as List<Product>;
      final hasNext = result['has_next'] as bool;

      if (mounted) {
        setState(() {
          _products = newProducts;
          _hasMore = hasNext;
          _currentPage = 1;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.title,
          style: AppTypography.headingSmall(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _isInitialLoading
          ? _buildSkeletonGrid(isDark)
          : _products.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.search_normal, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      Text(
                        'No products found',
                        style: AppTypography.bodyLarge(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : MasonryGridView.count(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(8),
                  crossAxisCount: 2,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  itemCount: _products.length + (_isLoadingMore ? 2 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _products.length) {
                      // Skeleton loading cards for pagination
                      return _buildSkeletonCard(isDark, index);
                    }

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
                      },
                    ).animate().fadeIn(
                          duration: 400.ms,
                          delay: (50 * (index % 20)).ms, // Reset delay for new pages
                        ).slideY(begin: 0.1, end: 0);
                  },
                ),
    );
  }

  /// Build skeleton loading card for pagination
  Widget _buildSkeletonCard(bool isDark, [int index = 0]) {
    // Height variation for masonry effect
    final heights = [200.0, 240.0, 220.0, 260.0, 180.0, 230.0, 250.0, 210.0];
    final randomHeight = heights[index % heights.length];
    
    return Container(
      height: randomHeight,
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark 
              ? AppColors.neutral800.withOpacity(0.5) 
              : AppColors.neutral200.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image skeleton with placeholder
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
            // Text skeleton
            Padding(
              padding: const EdgeInsets.all(8.0),
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
                  const SizedBox(height: 8),
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
          ],
        ),
      ),
    );
  }

  /// Build skeleton grid for initial loading
  Widget _buildSkeletonGrid(bool isDark) {
    return MasonryGridView.count(
      padding: const EdgeInsets.all(8),
      crossAxisCount: 2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      itemCount: 8,
      itemBuilder: (context, index) => _buildSkeletonCard(isDark, index),
    );
  }
}
