import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../models/home_data_model.dart' show HomeData, HomeBanner, GridElement, ProductSection, FlashSale, BadgeCount, PaginationInfo;
import '../models/product_model.dart';
import '../models/category_model.dart' show ProductCategory;
import 'api_service.dart';
import 'cache_service.dart';

// Isolate functions for heavy JSON parsing (run on background thread)
List<ProductCategory> _parseCategories(List<dynamic> jsonList) {
  return jsonList.map((c) => ProductCategory.fromJson(c as Map<String, dynamic>)).toList();
}

List<Product> _parseProducts(List<dynamic> jsonList) {
  return jsonList.map((p) => Product.fromJson(p as Map<String, dynamic>)).toList();
}

HomeData _parseHomeData(dynamic json) {
  return HomeData.fromJson(json as Map<String, dynamic>);
}

/// Home Screen Service
class HomeService extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  HomeData? _homeData;
  List<Product> _allProducts = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMoreProducts = true;
  
  // Smart prefetching
  bool _isPrefetching = false;

  HomeData? get homeData => _homeData;
  List<Product> get allProducts => _allProducts;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isPrefetching => _isPrefetching;
  String? get error => _error;
  bool get hasMoreProducts => _hasMoreProducts;

  List<HomeBanner> get banners => _homeData?.banners ?? [];
  List<GridElement> get gridElements => _homeData?.gridElements ?? [];
  List<ProductCategory> get categories => _homeData?.categories ?? [];
  List<ProductSection> get productSections => _homeData?.productSections ?? [];
  List<FlashSale> get flashSales => _homeData?.flashSales ?? [];
  List<Product> get hotSellings => _homeData?.hotSellings ?? []; // Hot selling products
  List<Product> get oneDollarProducts => _homeData?.oneDollarProducts ?? []; // $1 deals
  FlashSale? get flashSale => _homeData?.flashSale; // Keep for backward compatibility

  /// Update product like status locally
  void updateProductLikeStatus(int productId, bool isLiked) {
    bool changed = false;

    // Helper to update list
    List<Product> updateList(List<Product> list) {
      return list.map((p) {
        if (p.id == productId) {
          changed = true;
          return p.copyWith(isLiked: isLiked);
        }
        return p;
      }).toList();
    }

    // Update _allProducts
    _allProducts = updateList(_allProducts);

    if (_homeData != null) {
      // Update random products
      final newRandom = updateList(_homeData!.randomProducts);
      
      // Update sections
      final newSections = _homeData!.productSections.map((section) {
        return ProductSection(
          id: section.id,
          title: section.title,
          subtitle: section.subtitle,
          sectionType: section.sectionType,
          products: updateList(section.products),
          categoryId: section.categoryId,
        );
      }).toList();

      // Update flash sales
      final newFlashSales = _homeData!.flashSales.map((fs) {
        return FlashSale(
          id: fs.id,
          title: fs.title,
          startTime: fs.startTime,
          endTime: fs.endTime,
          products: updateList(fs.products),
          color1: fs.color1,
          color2: fs.color2,
          color3: fs.color3,
          discount: fs.discount,
          sliderType: fs.sliderType,
        );
      }).toList();

      // Update hot sellings
      final newHotSellings = updateList(_homeData!.hotSellings);

      // Update one dollar products
      final newOneDollarProducts = updateList(_homeData!.oneDollarProducts);

      _homeData = HomeData(
        banners: _homeData!.banners,
        gridElements: _homeData!.gridElements,
        categories: _homeData!.categories,
        productSections: newSections,
        randomProducts: newRandom,
        flashSales: newFlashSales,
        hotSellings: newHotSellings,
        oneDollarProducts: newOneDollarProducts,
        pagination: _homeData!.pagination,
      );
    }

    // Update _categoryCache - this ensures cached category products have correct isLiked status
    for (final categoryId in _categoryCache.keys) {
      _categoryCache[categoryId] = updateList(_categoryCache[categoryId]!);
    }

    if (changed) {
      notifyListeners();
    }
  }


  /// Fetch home screen data
  Future<void> fetchHomeData({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _allProducts = [];
      _hasMoreProducts = true;
      _consecutiveErrors = 0; // Reset error counter on refresh
      _lastErrorTime = null;
      _isPrefetching = false;
    }

    // If we are already loading and it's NOT a refresh, skip.
    // If it IS a refresh, we want to proceed even if loading (to restart/override).
    if (_isLoading && !refresh) return;
    
    _setLoading(true);
    _error = null;

    try {
      // STALE-WHILE-REVALIDATE: Show cached data immediately, then fetch fresh in background
      if (!refresh && _currentPage == 1 && _homeData == null) {
        final cachedData = await CacheService.getCachedHomeData();
        if (cachedData != null) {
          _homeData = await compute(_parseHomeData, cachedData);
          _allProducts = _homeData!.randomProducts;
          _hasMoreProducts = _homeData!.pagination.hasNext;
          _currentPage = 2; // Ready for page 2 on next load
          _setLoading(false);
          notifyListeners();
          
          // Continue to fetch fresh data in background (don't return!)
          _fetchFreshDataInBackground();
          return;
        }
      }

      final response = await _api.get(
        ApiConstants.getHomeScreen,
        queryParams: {
          'page': _currentPage,
          'per_page': 30,
        },
      );
      
      // debugPrint('Home API Response - Success: ${response.success}, Message: ${response.message}');

      if (response.success && response.data != null) {
        // Cache the raw response data
        if (_currentPage == 1) {
          await CacheService.cacheHomeData(response.data!);
        }
        
        // Parse on background thread to avoid blocking UI
        _homeData = await compute(_parseHomeData, response.data!);
        _allProducts = [..._allProducts, ..._homeData!.randomProducts];
        _hasMoreProducts = _homeData!.pagination.hasNext;
        _currentPage++;
      } else {
        _error = response.message ?? 'Failed to load home data';
      }
    } catch (e, stackTrace) {
      _error = e.toString();
    }

    _setLoading(false);
  }

  /// Fetch fresh data in background without blocking UI
  /// Used for stale-while-revalidate pattern
  Future<void> _fetchFreshDataInBackground() async {
    try {
      final response = await _api.get(
        ApiConstants.getHomeScreen,
        queryParams: {
          'page': 1,
          'per_page': 30,
        },
      );

      if (response.success && response.data != null) {
        // Cache the fresh data
        await CacheService.cacheHomeData(response.data!);
        
        // Parse on background thread
        final freshData = await compute(_parseHomeData, response.data!);
        
        // Only update if data is actually different (avoid unnecessary rebuilds)
        final oldProductCount = _homeData?.randomProducts.length ?? 0;
        final newProductCount = freshData.randomProducts.length;
        
        _homeData = freshData;
        _allProducts = freshData.randomProducts;
        _hasMoreProducts = freshData.pagination.hasNext;
        _currentPage = 2; // Ready for page 2 on next load
        
        notifyListeners();
      }
    } catch (e) {
      // Don't set error - user already has cached data showing
    }
  }


  // Track consecutive errors for backoff
  int _consecutiveErrors = 0;
  DateTime? _lastErrorTime;

  /// Load more products (infinite scroll)
  Future<void> loadMoreProducts() async {
    // Skip if already loading or prefetching, or no more products
    if (_isLoadingMore || _isPrefetching || !_hasMoreProducts) {
      return;
    }

    // Backoff after consecutive errors (wait longer before retrying)
    if (_consecutiveErrors > 0 && _lastErrorTime != null) {
      final waitTime = Duration(seconds: _consecutiveErrors * 2); // 2s, 4s, 6s...
      final elapsed = DateTime.now().difference(_lastErrorTime!);
      if (elapsed < waitTime) {
        return;
      }
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      // Use get-home-screen API for pagination of random products
      final response = await _api.get(
        ApiConstants.getHomeScreen,
        queryParams: {
          'page': _currentPage,
          'per_page': 30,
        },
      );

      if (response.success && response.data != null) {
        // Success! Reset error counter
        _consecutiveErrors = 0;
        _lastErrorTime = null;
        
        // Parse full home data to handle complex structure of random_products
        final homeData = await compute(_parseHomeData, response.data!);
        final newProducts = homeData.randomProducts;
        
        if (newProducts.isNotEmpty) {
          _allProducts = [..._allProducts, ...newProducts];
          _currentPage++;
        }
        
        _hasMoreProducts = homeData.pagination.hasNext;
      } else {
        _consecutiveErrors++;
        _lastErrorTime = DateTime.now();
      }
    } catch (e) {
      _consecutiveErrors++;
      _lastErrorTime = DateTime.now();
    }

    _isLoadingMore = false;
    notifyListeners();
  }

  /// Refresh home data
  Future<void> refresh() => fetchHomeData(refresh: true);



  /// Get categories
  Future<List<ProductCategory>> fetchCategories({int page = 1, int perPage = 20}) async {
    try {
      final response = await _api.get(
        ApiConstants.getAllCategories,
        queryParams: {
          'page': page,
          'per_page': perPage,
        },
      );

      if (response.success && response.data != null) {
        final categoriesJson = response.data!['categories'] as List?;
        if (categoriesJson != null) {
          final categories = categoriesJson.map((c) => ProductCategory.fromJson(c)).toList();
          return categories;
        }
      }
    } catch (e) {
    }
    return [];
  }

  /// Get category by ID with subcategories
  Future<ProductCategory?> fetchCategoryWithSubcategories(int categoryId) async {
    try {
      // Use same format as fetchProductsByCategory: query param 'id'
      final response = await _api.get(
        ApiConstants.getCategoryById,
        queryParams: {'id': categoryId},
      );

      if (response.success && response.data != null) {
        final categoryJson = response.data!['category'] as Map<String, dynamic>?;
        if (categoryJson != null) {
          return ProductCategory.fromJson(categoryJson);
        }
      }
    } catch (e) {
    }
    return null;
  }

  /// Get badge counts
  Future<BadgeCount> fetchBadgeCounts() async {
    try {
      final response = await _api.get(ApiConstants.getBadgeCount);
      if (response.success && response.data != null) {
        return BadgeCount.fromJson(response.data!);
      }
    } catch (e) {
    }
    return const BadgeCount();
  }

  /// Smart prefetch - called when user scrolls near bottom
  /// Prefetches next page in background and buffers it for instant use by loadMoreProducts
  Future<void> prefetchNextPage() async {
    // Don't prefetch if:
    // - Already prefetching
    // - No more products
    // - Currently loading initial data
    // - Currently loading more (let loadMoreProducts handle it)
    if (_isPrefetching || !_hasMoreProducts || _isLoading || _isLoadingMore) {
      return; // Silent skip - prefetch is opportunistic
    }

    _isPrefetching = true;
    notifyListeners(); // Show skeleton during prefetch

    try {
      // Use same API as loadMoreProducts for consistency
      final response = await _api.get(
        ApiConstants.getHomeScreen,
        queryParams: {
          'page': _currentPage,
          'per_page': 30,
        },
      );

      if (response.success && response.data != null) {
        // Parse full home data to handle complex structure of random_products
        final homeData = await compute(_parseHomeData, response.data!);
        final newProducts = homeData.randomProducts;
        
        if (newProducts.isNotEmpty) {
          // Apply prefetched data directly to list (instant display)
          _allProducts = [..._allProducts, ...newProducts];
          _currentPage++;
          _hasMoreProducts = homeData.pagination.hasNext;
        }
      }
    } catch (e) {
      // Don't stop pagination on prefetch errors - it's just optimization
    }

    _isPrefetching = false;
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Cache for category products to avoid refetching
  final Map<int, List<Product>> _categoryCache = {};

  List<Product> getCachedCategoryProducts(int categoryId) {
    return _categoryCache[categoryId] ?? [];
  }

  /// Update a product in all caches (used when product details are fetched with translation)
  /// NOTE: Does NOT call notifyListeners() to avoid expensive UI rebuilds.
  /// The cache is updated silently - UI will see changes on next navigation.
  void updateProductInCache(Product updatedProduct) {
    bool changed = false;

    // Update in _allProducts
    for (int i = 0; i < _allProducts.length; i++) {
      if (_allProducts[i].id == updatedProduct.id) {
        _allProducts[i] = updatedProduct;
        changed = true;
        break;
      }
    }

    // Update in _categoryCache
    for (final categoryId in _categoryCache.keys) {
      final products = _categoryCache[categoryId]!;
      for (int i = 0; i < products.length; i++) {
        if (products[i].id == updatedProduct.id) {
          products[i] = updatedProduct;
          changed = true;
          break;
        }
      }
    }

    // Update in homeData sections
    if (_homeData != null) {
      // Update random products
      for (int i = 0; i < _homeData!.randomProducts.length; i++) {
        if (_homeData!.randomProducts[i].id == updatedProduct.id) {
          final newRandom = List<Product>.from(_homeData!.randomProducts);
          newRandom[i] = updatedProduct;
          _homeData = HomeData(
            banners: _homeData!.banners,
            gridElements: _homeData!.gridElements,
            categories: _homeData!.categories,
            productSections: _homeData!.productSections,
            randomProducts: newRandom,
            flashSales: _homeData!.flashSales,
            hotSellings: _homeData!.hotSellings,
            oneDollarProducts: _homeData!.oneDollarProducts,
            pagination: _homeData!.pagination,
          );
          changed = true;
          break;
        }
      }
    }

    if (changed) {
      // OPTIMIZATION: Don't call notifyListeners() here!
      // This was causing expensive UI rebuilds (171+ product checks per notification).
      // The cache is updated - UI will see changes on next navigation/refresh.
    }
  }

  /// Get hot sellings products (Paginated with sorting)
  /// Supports sort: 'sales_desc' (default), 'price_asc', 'price_desc'
  Future<Map<String, dynamic>> getHotSellingsPaginated({
    int page = 1,
    int perPage = 20,
    String? sortBy,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'per_page': perPage,
      };
      
      // Map sort values to API format
      if (sortBy != null && sortBy.isNotEmpty) {
        // Accept both 'price:asc' and 'price_asc' formats
        if (sortBy == 'price:asc' || sortBy == 'price_asc') {
          queryParams['sort'] = 'price_asc';
        } else if (sortBy == 'price:desc' || sortBy == 'price_desc') {
          queryParams['sort'] = 'price_desc';
        } else if (sortBy == 'sales:desc' || sortBy == 'sales_desc') {
          queryParams['sort'] = 'sales_desc';
        } else {
          queryParams['sort'] = 'sales_desc'; // Default for hot sellings
        }
      }
      
      final response = await _api.get(
        ApiConstants.getHotSellings,
        queryParams: queryParams,
      );

      if (response.success && response.data != null) {
        final productsData = response.data!['products'];
        final pagination = response.data!['pagination'];
        
        if (productsData != null && productsData is List) {
          final products = await compute(_parseProducts, productsData);
          return {
            'products': products,
            'has_next': pagination != null ? pagination['has_next'] ?? false : false,
            'pagination': pagination,
          };
        }
      } else {
      }
    } catch (e, stackTrace) {
    }
    return {'products': <Product>[], 'has_next': false};
  }

  /// Get one dollar products (Paginated with sorting)
  /// Products with price > $0 and <= $1
  /// Supports sort: 'price_asc' (default), 'price_desc', 'sales_desc'
  Future<Map<String, dynamic>> getOneDollarProductsPaginated({
    int page = 1,
    int perPage = 20,
    String? sortBy,
    double minPrice = 0.01,
    double maxPrice = 1.0,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'per_page': perPage,
        'min_price': minPrice,
        'max_price': maxPrice,
      };
      
      // Map sort values to API format
      if (sortBy != null && sortBy.isNotEmpty) {
        // Accept both 'price:asc' and 'price_asc' formats
        if (sortBy == 'price:asc' || sortBy == 'price_asc') {
          queryParams['sort'] = 'price_asc';
        } else if (sortBy == 'price:desc' || sortBy == 'price_desc') {
          queryParams['sort'] = 'price_desc';
        } else if (sortBy == 'sales:desc' || sortBy == 'sales_desc') {
          queryParams['sort'] = 'sales_desc';
        } else {
          queryParams['sort'] = 'price_asc'; // Default for dollar deals
        }
      }
      
      final response = await _api.get(
        ApiConstants.getOneDollarProducts,
        queryParams: queryParams,
      );

      if (response.success && response.data != null) {
        final productsData = response.data!['products'];
        final pagination = response.data!['pagination'];
        
        if (productsData != null && productsData is List) {
          final products = await compute(_parseProducts, productsData);
          return {
            'products': products,
            'has_next': pagination != null ? pagination['has_next'] ?? false : false,
            'pagination': pagination,
          };
        }
      } else {
      }
    } catch (e, stackTrace) {
    }
    return {'products': <Product>[], 'has_next': false};
  }

  /// Search products (Paginated)
  Future<Map<String, dynamic>> searchProductsPaginated(
    String query, {
    int page = 1,
    int perPage = 30,
    String? sortBy,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'keyword': query,
        'page': page,
        'per_page': perPage,
      };
      
      // Add filter parameters if provided
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['sort_by'] = sortBy;
      }
      if (minPrice != null) {
        queryParams['min_price'] = minPrice;
      }
      if (maxPrice != null) {
        queryParams['max_price'] = maxPrice;
      }
      
      final response = await _api.get(
        ApiConstants.searchProducts,
        queryParams: queryParams,
      );

      if (response.success && response.data != null) {
        final productsData = response.data!['products'] ?? response.data!['data'];
        final pagination = response.data!['pagination'];
        
        if (productsData != null && productsData is List) {
          final products = await compute(_parseProducts, productsData);
          return {
            'products': products,
            'has_next': pagination != null ? pagination['has_next'] ?? false : false,
            'pagination': pagination,
          };
        }
      }
    } catch (e, stackTrace) {
    }
    return {'products': <Product>[], 'has_next': false};
  }

  /// Search products (Legacy wrapper)
  Future<List<Product>> searchProducts(String query) async {
    final result = await searchProductsPaginated(query);
    return result['products'] as List<Product>;
  }

  /// Search products by image (Paginated)
  /// Can use either imagePath (file upload) or imageUrl (converted URL for pagination)
  Future<Map<String, dynamic>> searchByImagePaginated(
    String imagePath, {
    int page = 1,
    int perPage = 30,
    String? sortBy,
    double? minPrice,
    double? maxPrice,
    String? imageUrl, // Use this for pagination instead of re-uploading file
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'page': page,
        'per_page': perPage,
      };
      
      // Add filter parameters if provided
      if (sortBy != null && sortBy.isNotEmpty) {
        queryParams['sort_by'] = sortBy;
      }
      if (minPrice != null) {
        queryParams['min_price'] = minPrice;
      }
      if (maxPrice != null) {
        queryParams['max_price'] = maxPrice;
      }
      
      ApiResponse response;
      
      // Check if imagePath is a URL (network image) or a local file path
      final isNetworkUrl = imagePath.startsWith('http://') || imagePath.startsWith('https://');
      
      // If we have a converted URL (from previous response), use POST with image_url
      // Also use this path if the imagePath is already a network URL
      if ((imageUrl != null && imageUrl.isNotEmpty) || isNetworkUrl) {
        queryParams['image_url'] = imageUrl ?? imagePath;
        response = await _api.post(
          ApiConstants.searchByImage,
          body: queryParams,
        );
      } else {
        // Local file - upload it via multipart
        response = await _api.postMultipart(
          ApiConstants.searchByImage,
          filePath: imagePath,
          fileField: 'file',
          queryParams: queryParams,
        );
      }

      if (response.success && response.data != null) {
        final productsData = response.data!['products'] ?? response.data!['data'];
        final pagination = response.data!['pagination'];
        final meta = response.data!['meta'];
        
        // Extract converted URL for faster pagination
        final convertedUrl = meta?['converted_url'];
        
        if (productsData != null && productsData is List) {
          final products = await compute(_parseProducts, productsData);
          return {
            'products': products,
            'has_next': pagination != null ? pagination['has_next'] ?? false : false,
            'pagination': pagination,
            'converted_url': convertedUrl, // Return this for pagination
          };
        }
      } else {
      }
    } catch (e, stackTrace) {
    }
    return {'products': <Product>[], 'has_next': false};
  }

  /// Search products by image (Legacy wrapper)
  Future<List<Product>> searchByImage(String imagePath) async {
    final result = await searchByImagePaginated(imagePath);
    return result['products'] as List<Product>;
  }

  /// Fetch products by category
  /// OPTIMIZED: Uses local cache for first page with default filters
  Future<Map<String, dynamic>> fetchProductsByCategory(
    int categoryId, {
    int page = 1,
    String? search,
    double? minPrice,
    double? maxPrice,
    String? sortBy,
  }) async {
    try {
      final Map<String, dynamic> queryParams = {
        'id': categoryId,
        'page': page,
        'per_page': 30, // Smart fetch: 30 products per page like home screen
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (minPrice != null) queryParams['min_price'] = minPrice;
      if (maxPrice != null) queryParams['max_price'] = maxPrice;
      if (sortBy != null) queryParams['sort_by'] = sortBy;
      
      // Check if this is a cacheable request (first page, no filters)
      final isDefaultFilter = search == null && minPrice == null && maxPrice == null && (sortBy == null || sortBy == 'newest');
      final isCacheable = page == 1 && isDefaultFilter;
      
      // Try to load from local cache first
      if (isCacheable) {
        final cachedProducts = await CacheService.getCachedCategoryProducts(categoryId);
        if (cachedProducts != null && cachedProducts.isNotEmpty) {
          final products = await compute(_parseProducts, cachedProducts);
          _categoryCache[categoryId] = products;
          return {
            'products': products,
            'pagination': {'has_next': true}, // Assume more pages exist
            'filters': {},
            'fromCache': true,
          };
        }
      }

      // Use getCategoryById to leverage the optimized backend endpoint
      final response = await _api.get(
        ApiConstants.getCategoryById,
        queryParams: queryParams,
      );

      if (response.success && response.data != null) {
        final data = response.data!;
        final productsData = data['products'];
        
        if (productsData != null && productsData is List) {
          final products = await compute(_parseProducts, productsData);
          
          // Update cache only for the first page and default filters
          // Allow 'newest' as it is the default sort
          
          if (page == 1 && isDefaultFilter) {
            _categoryCache[categoryId] = products;
            // Also save to persistent cache
            await CacheService.cacheCategoryProducts(
              categoryId, 
              productsData.map((p) => p as Map<String, dynamic>).toList(),
            );
          } else if (page > 1 && isDefaultFilter) {
             _categoryCache[categoryId]?.addAll(products);
          }
          
          return {
            'products': products,
            'pagination': data['pagination'],
            'filters': data['filters'],
          };
        }
      }
      return {'products': <Product>[]};
    } catch (e) {
      return {'products': <Product>[]};
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

