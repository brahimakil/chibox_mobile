import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import '../../../core/theme/theme.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/category_model.dart';
import '../../../core/models/home_data_model.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../core/utils/image_helper.dart';
import '../../../shared/widgets/widgets.dart';
import '../../product/screens/product_details_screen.dart';
import '../../categories/screens/category_products_screen.dart';

/// Enum to define the data source type for the products grid
enum ProductGridSource {
  search,
  imageSearch,
  section,
  flashSale,
  hotSellings,
  oneDollar,
  custom,
}

/// Configuration for the unified products grid
class ProductGridConfig {
  final ProductGridSource source;
  final String title;
  
  // For search
  final String? searchQuery;
  
  // For image search
  final String? imagePath;
  
  // For section
  final ProductSection? section;
  
  // For flash sale
  final FlashSale? flashSale;
  
  // For custom products
  final List<Product>? initialProducts;
  
  // For price deals (dynamic min/max price)
  final double? minPrice;
  final double? maxPrice;
  
  // Whether to enable pagination (API fetching)
  final bool enablePagination;
  
  // Whether to enable filters
  final bool enableFilters;
  
  // Whether to show related categories at the top (for search)
  final bool showRelatedCategories;
  
  // Custom empty state icon
  final IconData? emptyIcon;
  
  // Custom empty state message
  final String? emptyMessage;

  const ProductGridConfig({
    required this.source,
    required this.title,
    this.searchQuery,
    this.imagePath,
    this.section,
    this.flashSale,
    this.initialProducts,
    this.minPrice,
    this.maxPrice,
    this.enablePagination = true,
    this.enableFilters = true,
    this.showRelatedCategories = false,
    this.emptyIcon,
    this.emptyMessage,
  });

  /// Factory for search results
  factory ProductGridConfig.search({
    required String query,
    List<Product>? initialProducts,
  }) {
    return ProductGridConfig(
      source: ProductGridSource.search,
      title: 'Search Results',
      searchQuery: query,
      initialProducts: initialProducts,
      enablePagination: true,
      enableFilters: true,
      showRelatedCategories: true, // Show categories for search
      emptyIcon: Iconsax.search_normal,
      emptyMessage: 'No products found for "$query"',
    );
  }

  /// Factory for image search results
  factory ProductGridConfig.imageSearch({
    required String imagePath,
    List<Product>? initialProducts,
  }) {
    return ProductGridConfig(
      source: ProductGridSource.imageSearch,
      title: 'Image Search Results',
      imagePath: imagePath,
      initialProducts: initialProducts,
      enablePagination: true,
      enableFilters: true,
      emptyIcon: Iconsax.image,
      emptyMessage: 'No matching products found',
    );
  }

  /// Factory for section products
  factory ProductGridConfig.section({
    required ProductSection section,
  }) {
    return ProductGridConfig(
      source: ProductGridSource.section,
      title: section.title,
      section: section,
      initialProducts: section.products,
      enablePagination: false, // Sections don't have pagination currently
      enableFilters: true, // Enable local filtering
      emptyIcon: Iconsax.box,
      emptyMessage: 'No products found',
    );
  }

  /// Factory for flash sale products
  factory ProductGridConfig.flashSale({
    required FlashSale flashSale,
  }) {
    return ProductGridConfig(
      source: ProductGridSource.flashSale,
      title: flashSale.title,
      flashSale: flashSale,
      initialProducts: flashSale.products,
      enablePagination: false, // Flash sales don't have pagination currently
      enableFilters: true, // Enable local filtering
      emptyIcon: Iconsax.flash_1,
      emptyMessage: 'No products in this flash sale',
    );
  }

  /// Factory for hot sellings products (paginated from API)
  factory ProductGridConfig.hotSellings({
    List<Product>? initialProducts,
  }) {
    return ProductGridConfig(
      source: ProductGridSource.hotSellings,
      title: 'Hot Sellings',
      initialProducts: initialProducts,
      enablePagination: true, // API pagination supported
      enableFilters: true, // Enable price sorting filters
      emptyIcon: Iconsax.flash_1,
      emptyMessage: 'No hot selling products found',
    );
  }

  /// Factory for price deals products (paginated from API)
  /// Products with prices in a dynamic range (default $0.01-$1)
  factory ProductGridConfig.priceDeals({
    required String title,
    double minPrice = 0.01,
    double maxPrice = 1.0,
    List<Product>? initialProducts,
  }) {
    return ProductGridConfig(
      source: ProductGridSource.oneDollar,
      title: title,
      minPrice: minPrice,
      maxPrice: maxPrice,
      initialProducts: initialProducts,
      enablePagination: true, // API pagination supported
      enableFilters: true, // Enable price sorting filters
      emptyIcon: Iconsax.dollar_circle,
      emptyMessage: 'No deals found',
    );
  }

  /// Factory for one dollar products (paginated from API)
  /// Products with prices > $0 and <= $1
  factory ProductGridConfig.oneDollar({
    List<Product>? initialProducts,
  }) {
    return ProductGridConfig(
      source: ProductGridSource.oneDollar,
      title: '\$1 Deals',
      minPrice: 0.01,
      maxPrice: 1.0,
      initialProducts: initialProducts,
      enablePagination: true, // API pagination supported
      enableFilters: true, // Enable price sorting filters
      emptyIcon: Iconsax.dollar_circle,
      emptyMessage: 'No \$1 deals found',
    );
  }

  /// Factory for custom product list
  factory ProductGridConfig.custom({
    required String title,
    required List<Product> products,
    bool enableFilters = true,
  }) {
    return ProductGridConfig(
      source: ProductGridSource.custom,
      title: title,
      initialProducts: products,
      enablePagination: false,
      enableFilters: enableFilters,
      emptyIcon: Iconsax.box,
      emptyMessage: 'No products available',
    );
  }
}

/// A unified screen for displaying product grids with filtering and pagination.
/// This replaces separate implementations in SearchResultsScreen, SectionProductsScreen,
/// and FlashSaleProductsScreen.
class UnifiedProductsGridScreen extends StatefulWidget {
  final ProductGridConfig config;

  const UnifiedProductsGridScreen({
    super.key,
    required this.config,
  });

  @override
  State<UnifiedProductsGridScreen> createState() => _UnifiedProductsGridScreenState();
}

class _UnifiedProductsGridScreenState extends State<UnifiedProductsGridScreen> {
  late List<Product> _products;
  late List<Product> _allProducts; // Original unfiltered products for local filtering
  late ScrollController _scrollController;
  
  bool _isLoadingMore = false;
  bool _isInitialLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  int _totalProducts = 0; // Total products from API pagination
  
  // Related categories for search
  List<CategorySearchResult> _relatedCategories = [];
  bool _isLoadingCategories = false;
  
  // "You May Also Like" recommended products
  List<Product> _recommendedProducts = [];
  bool _isLoadingRecommended = false;
  
  // Filter state
  ProductFilterState _filterState = const ProductFilterState();
  
  StreamSubscription? _wishlistSubscription;

  @override
  void initState() {
    super.initState();
    _initializeProducts();
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
      // Also update in _allProducts for local filtering
      final allIndex = _allProducts.indexWhere((p) => p.id == update.id);
      if (allIndex != -1) {
        _allProducts[allIndex] = _allProducts[allIndex].copyWith(isLiked: update.isLiked);
      }
      // Also update in recommended products
      final recIndex = _recommendedProducts.indexWhere((p) => p.id == update.id);
      if (recIndex != -1) {
        setState(() {
          _recommendedProducts[recIndex] = _recommendedProducts[recIndex].copyWith(isLiked: update.isLiked);
        });
      }
    });

    // Load initial data and categories in parallel for faster results
    _loadInitialDataParallel();
  }
  
  /// Load products and categories in parallel for faster initial load
  Future<void> _loadInitialDataParallel() async {
    final futures = <Future>[];
    
    // Load products if needed
    final needsProducts = widget.config.initialProducts == null || widget.config.initialProducts!.isEmpty;
    
    // For hotSellings or oneDollar, ALWAYS load from API to get proper pagination
    // The initialProducts are just for display continuity - API has more data
    if ((widget.config.source == ProductGridSource.hotSellings || 
         widget.config.source == ProductGridSource.oneDollar) && widget.config.enablePagination) {
      futures.add(_loadInitial());
    } else if (needsProducts && widget.config.enablePagination) {
      futures.add(_loadInitial());
    } else if (!needsProducts && _products.length < 20 && widget.config.enablePagination) {
      // If initial load was less than 20 and pagination is enabled, assume no more
      // But NOT for hotSellings or oneDollar - those always have more from API
      if (widget.config.source != ProductGridSource.hotSellings && 
          widget.config.source != ProductGridSource.oneDollar) {
        _hasMore = false;
      }
    }
    
    // Load related categories if enabled (in parallel with products)
    if (widget.config.showRelatedCategories && widget.config.searchQuery != null) {
      futures.add(_loadRelatedCategories());
    }
    
    // Wait for all to complete
    if (futures.isNotEmpty) {
      await Future.wait(futures);
    }
  }

  void _initializeProducts() {
    final initial = widget.config.initialProducts ?? [];
    _products = List.from(initial);
    _allProducts = List.from(initial);
  }
  
  Future<void> _loadRelatedCategories() async {
    if (widget.config.searchQuery == null || widget.config.searchQuery!.isEmpty) return;
    
    setState(() => _isLoadingCategories = true);
    
    try {
      final categoryService = Provider.of<CategoryService>(context, listen: false);
      final results = await categoryService.searchCategories(
        widget.config.searchQuery!,
        limit: 15,
      );
      
      if (mounted) {
        setState(() {
          _relatedCategories = results;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading related categories: $e');
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
    }
  }
  
  /// Load "You May Also Like" recommended products from home page sections
  Future<void> _loadRecommendedProducts() async {
    if (_recommendedProducts.isNotEmpty || _isLoadingRecommended) return;
    
    setState(() => _isLoadingRecommended = true);
    
    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      
      // Try to get products from home data productSections (like "Recommended" or "Popular")
      if (homeService.homeData != null && homeService.homeData!.productSections.isNotEmpty) {
        // Find a section with products to show
        for (final section in homeService.homeData!.productSections) {
          if (section.products.isNotEmpty) {
            // Exclude products that are already in search results
            final existingIds = _products.map((p) => p.id).toSet();
            final recommended = section.products
                .where((p) => !existingIds.contains(p.id))
                .take(10)
                .toList();
            
            if (recommended.isNotEmpty) {
              if (mounted) {
                setState(() {
                  _recommendedProducts = recommended;
                  _isLoadingRecommended = false;
                });
              }
              debugPrint('📦 Loaded ${recommended.length} recommended products from "${section.title}"');
              return;
            }
          }
        }
      }
      
      // Fallback: try to search for generic popular items
      final result = await homeService.searchProductsPaginated(
        'popular fashion',
        page: 1,
        perPage: 10,
      );
      
      final products = (result['products'] as List<Product>?) ?? [];
      // Exclude products that are already in search results
      final existingIds = _products.map((p) => p.id).toSet();
      final recommended = products.where((p) => !existingIds.contains(p.id)).take(10).toList();
      
      if (mounted) {
        setState(() {
          _recommendedProducts = recommended;
          _isLoadingRecommended = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading recommended products: $e');
      if (mounted) {
        setState(() => _isLoadingRecommended = false);
      }
    }
  }

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isPrefetching = false;
  List<Product> _prefetchedProducts = [];
  bool _prefetchedHasNext = true; // Store has_next from prefetch response
  
  void _onScroll() {
    if (!widget.config.enablePagination) return;
    
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.position.pixels;
    
    if (maxScroll > 0) {
      final scrollPercentage = (currentScroll / maxScroll * 100).clamp(0, 100);
      
      // Debug scroll position periodically
      if (scrollPercentage.toInt() % 25 == 0) {
        debugPrint('📜 Scroll: ${scrollPercentage.toInt()}%, hasMore: $_hasMore, isLoading: $_isLoadingMore, prefetched: ${_prefetchedProducts.length}');
      }
      
      // Aggressive prefetch at 2% scroll for instant loading
      if (scrollPercentage >= 2 && scrollPercentage < 70 && !_isPrefetching && !_isLoadingMore && _hasMore && _prefetchedProducts.isEmpty) {
        _prefetchNextPage();
      }
      
      // Load more at 75% scroll (use prefetched data if available)
      if (scrollPercentage >= 75 && !_isLoadingMore && _hasMore) {
        debugPrint('🔄 Triggering loadMore at ${scrollPercentage.toInt()}%');
        _loadMore();
      }
    }
  }
  
  Future<void> _prefetchNextPage() async {
    if (_isPrefetching || !_hasMore || _prefetchedProducts.isNotEmpty) return;
    
    _isPrefetching = true;
    debugPrint('🔮 Prefetching next page: ${_currentPage + 1}');
    
    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      Map<String, dynamic> result;
      
      switch (widget.config.source) {
        case ProductGridSource.search:
          if (widget.config.searchQuery == null) {
            _isPrefetching = false;
            return;
          }
          result = await homeService.searchProductsPaginated(
            widget.config.searchQuery!,
            page: _currentPage + 1,
            sortBy: _filterState.sortBy.apiValue,
            minPrice: _filterState.minPrice,
            maxPrice: _filterState.maxPrice,
          );
          break;
          
        case ProductGridSource.imageSearch:
          if (widget.config.imagePath == null) {
            _isPrefetching = false;
            return;
          }
          result = await homeService.searchByImagePaginated(
            widget.config.imagePath!,
            page: _currentPage + 1,
            sortBy: _filterState.sortBy.apiValue,
            minPrice: _filterState.minPrice,
            maxPrice: _filterState.maxPrice,
          );
          break;
        
        case ProductGridSource.hotSellings:
          result = await homeService.getHotSellingsPaginated(
            page: _currentPage + 1,
            sortBy: _filterState.sortBy.apiValue,
          );
          break;
        
        case ProductGridSource.oneDollar:
          result = await homeService.getOneDollarProductsPaginated(
            page: _currentPage + 1,
            sortBy: _filterState.sortBy.apiValue,
            minPrice: widget.config.minPrice ?? 0.01,
            maxPrice: widget.config.maxPrice ?? 1.0,
          );
          break;
          
        default:
          _isPrefetching = false;
          return;
      }
      
      final newProducts = (result['products'] as List<Product>?) ?? [];
      final hasNext = result['has_next'] == true;
      _prefetchedProducts = newProducts;
      _prefetchedHasNext = hasNext;
      debugPrint('✅ Prefetched ${newProducts.length} products. has_next: $hasNext');
    } catch (e) {
      debugPrint('❌ Prefetch error: $e');
    }
    
    _isPrefetching = false;
  }

  Future<void> _loadInitial() async {
    if (!widget.config.enablePagination) return;
    
    // Only show full screen loading if we don't have initial products to show
    // This allows "Instant View" where passed products are shown while we fetch specifics
    if (_products.isEmpty) {
      setState(() {
        _isInitialLoading = true;
      });
    }

    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      Map<String, dynamic> result;

      switch (widget.config.source) {
        case ProductGridSource.search:
          if (widget.config.searchQuery == null) {
            setState(() => _isInitialLoading = false);
            return;
          }
          result = await homeService.searchProductsPaginated(
            widget.config.searchQuery!,
            page: 1,
            sortBy: _filterState.sortBy.apiValue,
            minPrice: _filterState.minPrice,
            maxPrice: _filterState.maxPrice,
          );
          break;
          
        case ProductGridSource.imageSearch:
          if (widget.config.imagePath == null) {
            setState(() => _isInitialLoading = false);
            return;
          }
          result = await homeService.searchByImagePaginated(
            widget.config.imagePath!,
            page: 1,
            sortBy: _filterState.sortBy.apiValue,
            minPrice: _filterState.minPrice,
            maxPrice: _filterState.maxPrice,
          );
          break;
        
        case ProductGridSource.hotSellings:
          result = await homeService.getHotSellingsPaginated(
            page: 1,
            sortBy: _filterState.sortBy.apiValue,
          );
          break;
        
        case ProductGridSource.oneDollar:
          result = await homeService.getOneDollarProductsPaginated(
            page: 1,
            sortBy: _filterState.sortBy.apiValue,
            minPrice: widget.config.minPrice ?? 0.01,
            maxPrice: widget.config.maxPrice ?? 1.0,
          );
          break;
          
        default:
          setState(() => _isInitialLoading = false);
          return;
      }

      final newProducts = (result['products'] as List<Product>?) ?? [];
      final hasNext = result['has_next'] == true;
      final pagination = result['pagination'] as Map<String, dynamic>?;
      final total = pagination?['total'] ?? newProducts.length;
      
      debugPrint('📦 Initial load: ${newProducts.length} products, hasNext: $hasNext, total: $total');

      if (mounted) {
        setState(() {
          _products = newProducts;
          _allProducts = List.from(newProducts);
          _hasMore = hasNext;
          _currentPage = 1;
          _totalProducts = total is int ? total : int.tryParse(total.toString()) ?? newProducts.length;
          _isInitialLoading = false;
        });
        
        // INSTANT VIEW OPTIMIZATION:
        // If we came from home screen (had initial products) and we successfully loaded Page 1,
        // immediately prefetch Page 2 so the user can scroll without waiting.
        if (widget.config.initialProducts != null && 
            widget.config.initialProducts!.isNotEmpty && 
            hasNext) {
           debugPrint('🚀 Instant View: Initial products matched, prefetching Page 2...');
           WidgetsBinding.instance.addPostFrameCallback((_) {
             _prefetchNextPage();
           });
        }
        
        // If initial load returned too few products to fill screen, auto-load more
        // This handles cases where many products are filtered out (e.g., $0 prices)
        if (hasNext && newProducts.length < 20) {
          debugPrint('📦 Initial load too small (${newProducts.length}), auto-loading more...');
          // Schedule after frame to let the UI build
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _hasMore) {
              _loadMore();
            }
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading initial products: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  Future<void> _loadMore() async {
    if (_isLoadingMore || !_hasMore || !widget.config.enablePagination) return;

    // Use prefetched products if available (instant load)
    if (_prefetchedProducts.isNotEmpty) {
      debugPrint('⚡ Using prefetched products: ${_prefetchedProducts.length}, has_next: $_prefetchedHasNext');
      final prefetchedList = _prefetchedProducts;
      final prefetchedHasNext = _prefetchedHasNext;
      final totalAfterLoad = _products.length + prefetchedList.length;
      
      setState(() {
        _products.addAll(prefetchedList);
        _allProducts.addAll(prefetchedList);
        _currentPage++;
        _hasMore = prefetchedHasNext; // Use actual API response
      });
      _prefetchedProducts = [];
      _prefetchedHasNext = true; // Reset for next prefetch
      
      // If we still don't have enough products to enable scroll, auto-load more
      if (prefetchedHasNext && totalAfterLoad < 20) {
        debugPrint('📦 Still too few products after prefetch ($totalAfterLoad), auto-loading more...');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _hasMore && !_isLoadingMore) {
            _loadMore();
          }
        });
      }
      return;
    }

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      Map<String, dynamic> result;

      switch (widget.config.source) {
        case ProductGridSource.search:
          if (widget.config.searchQuery == null) {
            setState(() => _isLoadingMore = false);
            return;
          }
          result = await homeService.searchProductsPaginated(
            widget.config.searchQuery!,
            page: _currentPage + 1,
            sortBy: _filterState.sortBy.apiValue,
            minPrice: _filterState.minPrice,
            maxPrice: _filterState.maxPrice,
          );
          break;
          
        case ProductGridSource.imageSearch:
          if (widget.config.imagePath == null) {
            setState(() => _isLoadingMore = false);
            return;
          }
          result = await homeService.searchByImagePaginated(
            widget.config.imagePath!,
            page: _currentPage + 1,
            sortBy: _filterState.sortBy.apiValue,
            minPrice: _filterState.minPrice,
            maxPrice: _filterState.maxPrice,
          );
          break;
        
        case ProductGridSource.hotSellings:
          result = await homeService.getHotSellingsPaginated(
            page: _currentPage + 1,
            sortBy: _filterState.sortBy.apiValue,
          );
          break;
        
        case ProductGridSource.oneDollar:
          result = await homeService.getOneDollarProductsPaginated(
            page: _currentPage + 1,
            sortBy: _filterState.sortBy.apiValue,
            minPrice: widget.config.minPrice ?? 0.01,
            maxPrice: widget.config.maxPrice ?? 1.0,
          );
          break;
          
        default:
          setState(() => _isLoadingMore = false);
          return;
      }

      final newProducts = (result['products'] as List<Product>?) ?? [];
      final hasNext = result['has_next'] == true;
      
      debugPrint('📦 Load more: ${newProducts.length} products, hasNext: $hasNext, total now: ${_products.length + newProducts.length}');

      if (mounted) {
        final totalAfterLoad = _products.length + newProducts.length;
        setState(() {
          _products.addAll(newProducts);
          _allProducts.addAll(newProducts);
          _hasMore = hasNext;
          _currentPage++;
          _isLoadingMore = false;
        });
        
        // If we still don't have enough products to enable scroll, auto-load more
        if (hasNext && totalAfterLoad < 20) {
          debugPrint('📦 Still too few products ($totalAfterLoad), auto-loading more...');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _hasMore && !_isLoadingMore) {
              _loadMore();
            }
          });
        }
      }
    } catch (e, stackTrace) {
      debugPrint('Error loading more products: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() => _isLoadingMore = false);
      }
    }
  }

  Future<void> _refresh() async {
    // Clear prefetched data on refresh
    _prefetchedProducts = [];
    _prefetchedHasNext = true;
    
    if (widget.config.enablePagination) {
      // For API-backed grids, reload from API
      setState(() {
        _currentPage = 1;
        _hasMore = true;
      });
      await _loadInitial();
    } else {
      // For local grids, just reset the filter
      setState(() {
        _products = _applyLocalFilters(_allProducts);
      });
    }
  }

  void _showFilterSheet() async {
    final result = await ProductFilterSheet.show(
      context,
      currentFilter: _filterState,
    );

    if (result != null && result != _filterState) {
      setState(() {
        _filterState = result;
      });
      
      if (widget.config.enablePagination) {
        // For API-backed grids, reload with new filters
        _currentPage = 1;
        _hasMore = true;
        _products = [];
        await _loadInitial();
      } else {
        // For local grids, apply filters locally
        setState(() {
          _products = _applyLocalFilters(_allProducts);
        });
      }
    }
  }

  List<Product> _applyLocalFilters(List<Product> products) {
    var filtered = List<Product>.from(products);
    
    // Apply price filters
    if (_filterState.minPrice != null) {
      filtered = filtered.where((p) => p.price >= _filterState.minPrice!).toList();
    }
    if (_filterState.maxPrice != null) {
      filtered = filtered.where((p) => p.price <= _filterState.maxPrice!).toList();
    }
    
    // Apply sorting
    switch (_filterState.sortBy) {
      case ProductSortOption.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case ProductSortOption.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case ProductSortOption.newest:
        // Keep original order (assumed to be newest first)
        break;
    }
    
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark 
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      child: Scaffold(
        backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
        appBar: AppBar(
        backgroundColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.config.title,
              style: AppTypography.headingMedium(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            // Show search query and/or results count
            if (widget.config.searchQuery != null && widget.config.searchQuery!.isNotEmpty) ...[
              Text(
                '"${widget.config.searchQuery}"',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (_totalProducts > 0 && !_isInitialLoading)
                Text(
                  '$_totalProducts results',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    fontWeight: FontWeight.w400,
                  ),
                ),
            ] else if (_totalProducts > 0 && !_isInitialLoading)
              Text(
                '$_totalProducts products found',
                style: TextStyle(
                  fontSize: 10,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w400,
                ),
              ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (widget.config.enableFilters)
            Stack(
              children: [
                IconButton(
                  icon: Icon(
                    Iconsax.filter,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: _showFilterSheet,
                ),
                // Show indicator if filters are active
                if (_filterState.hasActiveFilters)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.primary500,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
              ],
            ),
        ],
      ),
      body: _buildBody(isDark),
    ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_isInitialLoading) {
      return _buildSkeletonGrid(isDark);
    }

    if (_products.isEmpty) {
      return _buildEmptyState(isDark);
    }

    // Calculate header height for categories section
    final showCategories = widget.config.showRelatedCategories && _relatedCategories.isNotEmpty;
    
    // Load recommended products when no more results (for search/image search)
    final showRecommendedAtBottom = !_hasMore && 
        (widget.config.source == ProductGridSource.search || 
         widget.config.source == ProductGridSource.imageSearch);
    
    if (showRecommendedAtBottom && _recommendedProducts.isEmpty && !_isLoadingRecommended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRecommendedProducts();
      });
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // Related Categories Section
          if (showCategories)
            SliverToBoxAdapter(
              child: _buildRelatedCategoriesSection(isDark),
            ),
          
          // Products Grid
          SliverPadding(
            padding: const EdgeInsets.all(8),
            sliver: SliverMasonryGrid.count(
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              childCount: _products.length + (_isLoadingMore ? 2 : 0),
              itemBuilder: (context, index) {
                if (index >= _products.length) {
                  return _buildSkeletonCard(isDark, index);
                }

                final product = _products[index];
                return RepaintBoundary(
                  child: ProductCard.fromProduct(
                    product,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailsScreen(product: product),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
          
          // "You May Also Like" section at bottom when no more results
          if (showRecommendedAtBottom && (_recommendedProducts.isNotEmpty || _isLoadingRecommended))
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(top: 24, bottom: 100),
                child: _buildYouMayAlsoLikeSection(isDark),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildRelatedCategoriesSection(bool isDark) {
    return Container(
      color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Text(
              'Related Categories',
              style: AppTypography.labelLarge(
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
          ),
          SizedBox(
            height: 110,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _relatedCategories.length,
              itemBuilder: (context, index) {
                final result = _relatedCategories[index];
                return _buildCategoryCircle(result, isDark);
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
  
  Widget _buildCategoryCircle(CategorySearchResult result, bool isDark) {
    return GestureDetector(
      onTap: () async {
        // Get siblings for the category
        final categoryService = Provider.of<CategoryService>(context, listen: false);
        List<ProductCategory> siblings = [];
        
        if (result.isSubcategory && result.parentCategory != null) {
          // For subcategories, get siblings from the parent
          siblings = categoryService.getCachedSubcategories(result.parentCategory!.id) ?? [];
          if (siblings.isEmpty) {
            final response = await categoryService.fetchSubcategories(result.parentCategory!.id);
            siblings = response['subcategories'] as List<ProductCategory>? ?? [];
          }
        } else {
          // For main categories, get its subcategories
          siblings = categoryService.getCachedSubcategories(result.category.id) ?? [];
          if (siblings.isEmpty) {
            final response = await categoryService.fetchSubcategories(result.category.id);
            siblings = response['subcategories'] as List<ProductCategory>? ?? [];
          }
        }
        
        if (!mounted) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryProductsScreen(
              category: result.category,
            ),
          ),
        );
      },
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
                  color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: ClipOval(
                  child: ImageHelper.parse(result.category.mainImage).isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ImageHelper.parse(result.category.mainImage),
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
            const SizedBox(height: 3),
            // Category name - allow wrapping to 2 lines
            SizedBox(
              height: 24,
              child: Text(
                result.category.name,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.normal,
                  color: isDark ? Colors.white70 : Colors.black87,
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
  }

  Widget _buildEmptyState(bool isDark) {
    // Load recommended products when empty
    if (_recommendedProducts.isEmpty && !_isLoadingRecommended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadRecommendedProducts();
      });
    }
    
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 80),
          Icon(
            widget.config.emptyIcon ?? Iconsax.box,
            size: 64,
            color: isDark ? AppColors.neutral700 : AppColors.neutral300,
          ),
          AppSpacing.verticalMd,
          Text(
            widget.config.emptyMessage ?? 'No products found',
            style: AppTypography.bodyLarge(
              color: isDark ? AppColors.neutral400 : AppColors.neutral500,
            ),
          ),
          if (_filterState.hasActiveFilters) ...[
            AppSpacing.verticalMd,
            TextButton(
              onPressed: () {
                setState(() {
                  _filterState = const ProductFilterState();
                });
                if (widget.config.enablePagination) {
                  _loadInitial();
                } else {
                  setState(() {
                    _products = _applyLocalFilters(_allProducts);
                  });
                }
              },
              child: Text(
                'Clear Filters',
                style: TextStyle(color: AppColors.primary500),
              ),
            ),
          ],
          
          // "You May Also Like" section
          if (_recommendedProducts.isNotEmpty || _isLoadingRecommended) ...[
            const SizedBox(height: 40),
            _buildYouMayAlsoLikeSection(isDark),
          ],
        ],
      ),
    );
  }
  
  /// Build "You May Also Like" section
  Widget _buildYouMayAlsoLikeSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'You May Also Like',
            style: AppTypography.headingSmall(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        
        if (_isLoadingRecommended)
          SizedBox(
            height: 200,
            child: Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary500,
              ),
            ),
          )
        else
          SizedBox(
            height: 280,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _recommendedProducts.length,
              itemBuilder: (context, index) {
                final product = _recommendedProducts[index];
                return Container(
                  width: 160,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  child: ProductCard.fromProduct(
                    product,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ProductDetailsScreen(product: product),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSkeletonCard(bool isDark, [int index = 0]) {
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
