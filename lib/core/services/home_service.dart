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

      _homeData = HomeData(
        banners: _homeData!.banners,
        gridElements: _homeData!.gridElements,
        categories: _homeData!.categories,
        productSections: newSections,
        randomProducts: newRandom,
        flashSales: newFlashSales,
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
      // Clear cache on manual refresh
      await CacheService.clearCache();
      debugPrint('🔄 Manual refresh - cache cleared');
    }

    // If we are already loading and it's NOT a refresh, skip.
    // If it IS a refresh, we want to proceed even if loading (to restart/override).
    if (_isLoading && !refresh) return;
    
    _setLoading(true);
    _error = null;

    try {
      // Try to load from cache first (only if not refreshing)
      // if (!refresh && _currentPage == 1) {
      //   final cachedData = await CacheService.getCachedHomeData();
      //   if (cachedData != null) {
      //     debugPrint('📦 Loading from cache...');
      //     _homeData = await compute(_parseHomeData, cachedData);
      //     _allProducts = _homeData!.randomProducts;
      //     _hasMoreProducts = _homeData!.pagination.hasNext;
      //     _currentPage++;
      //     _setLoading(false);
      //     notifyListeners();
      //     debugPrint('✅ Loaded from cache: ${_homeData!.randomProducts.length} products');
      //     return;
      //   }
      // }

      debugPrint('🌐 Fetching home data from API: ${ApiConstants.baseUrl}${ApiConstants.getHomeScreen}');
      
      final response = await _api.get(
        ApiConstants.getHomeScreen,
        queryParams: {
          'page': _currentPage,
          'per_page': 20,
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
        debugPrint('✅ Parsed ${_homeData!.banners.length} banners, ${_homeData!.categories.length} categories, ${_homeData!.productSections.length} sections, ${_homeData!.randomProducts.length} products');
      } else {
        _error = response.message ?? 'Failed to load home data';
        debugPrint('⚠️ Home API failed: $_error');
      }
    } catch (e, stackTrace) {
      _error = e.toString();
      debugPrint('❌ Error fetching home data: $e');
      debugPrint('Stack trace: $stackTrace');
    }

    _setLoading(false);
  }



  /// Load more products (infinite scroll)
  Future<void> loadMoreProducts() async {
    if (_isLoadingMore || !_hasMoreProducts || _isPrefetching) {
      debugPrint('⚠️ Skipping load more: isLoadingMore=$_isLoadingMore, hasMore=$_hasMoreProducts, isPrefetching=$_isPrefetching');
      return;
    }

    _isLoadingMore = true;
    notifyListeners();

    try {
      debugPrint('📥 Loading more products - Page: $_currentPage');
      
      // Use get-home-screen API for pagination of random products
      final response = await _api.get(
        ApiConstants.getHomeScreen,
        queryParams: {
          'page': _currentPage,
          'per_page': 20,
        },
      );

      if (response.success && response.data != null) {
        // Parse full home data to handle complex structure of random_products
        final homeData = await compute(_parseHomeData, response.data!);
        final newProducts = homeData.randomProducts;
        
        if (newProducts.isNotEmpty) {
          _allProducts = [..._allProducts, ...newProducts];
          _currentPage++;
          debugPrint('✅ Loaded ${newProducts.length} more products. Total now: ${_allProducts.length}');
        }
        
        _hasMoreProducts = homeData.pagination.hasNext;
        debugPrint('📊 Has more products: $_hasMoreProducts');
      } else {
        debugPrint('⚠️ Load more failed: ${response.message}');
        _hasMoreProducts = false;
      }
    } catch (e) {
      debugPrint('❌ Error loading more products: $e');
      _hasMoreProducts = false; // Stop trying on error
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
          debugPrint('✅ Parsed ${categoriesJson.length} fallback categories.');
          // Debug: Print first category to see structure
          if (categoriesJson.isNotEmpty) {
            debugPrint('📦 First category data: ${categoriesJson[0]}');
          }
          final categories = categoriesJson.map((c) => ProductCategory.fromJson(c)).toList();
          // Debug: Print parsed category
          if (categories.isNotEmpty) {
            debugPrint('🏷️ First parsed category: id=${categories[0].id}, name=${categories[0].name}, image=${categories[0].mainImage}');
          }
          return categories;
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching categories: $e');
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
          debugPrint('✅ Fetched category with subcategories: ${categoryJson['category_name']}');
          return ProductCategory.fromJson(categoryJson);
        }
      }
    } catch (e) {
      debugPrint('❌ Error fetching category with subcategories: $e');
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
      debugPrint('Error fetching badge counts: $e');
    }
    return const BadgeCount();
  }

  /// Smart prefetch - called when user scrolls near bottom
  Future<void> prefetchNextPage() async {
    // Don't prefetch if:
    // - Already prefetching
    // - No more products
    // - Currently loading
    // - Loading more
    if (_isPrefetching || !_hasMoreProducts || _isLoading || _isLoadingMore) {
      return;
    }

    _isPrefetching = true;
    notifyListeners();

    try {
      debugPrint('⚡ Smart prefetch triggered: Page $_currentPage');
      
      final response = await _api.get(
        ApiConstants.getProducts,
        queryParams: {
          'page': _currentPage,
          'per_page': 10,
        },
      );

      if (response.success && response.data != null) {
        final productsJson = response.data!['products'] as List?;
        final pagination = response.data!['pagination'];
        
        if (productsJson != null && productsJson.isNotEmpty) {
          // Parse products on background thread
          final newProducts = await compute(_parseProducts, productsJson);
          _allProducts = [..._allProducts, ...newProducts];
          _currentPage++;
          debugPrint('✅ Prefetched ${newProducts.length} products. Total: ${_allProducts.length}');
        }
        
        if (pagination != null) {
          _hasMoreProducts = pagination['has_next'] == true || pagination['has_next'] == 1;
        }
      }
    } catch (e) {
      debugPrint('❌ Error prefetching: $e');
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
            pagination: _homeData!.pagination,
          );
          changed = true;
          break;
        }
      }
    }

    if (changed) {
      debugPrint('📦 Updated product ${updatedProduct.id} in HomeService cache');
      notifyListeners();
    }
  }

  /// Search products (Paginated)
  Future<Map<String, dynamic>> searchProductsPaginated(
    String query, {
    int page = 1,
    int perPage = 20,
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
      
      debugPrint('🔍 Search request: query="$query", page=$page, sortBy=$sortBy, minPrice=$minPrice, maxPrice=$maxPrice');
      
      final response = await _api.get(
        ApiConstants.searchProducts,
        queryParams: queryParams,
      );

      debugPrint('🔍 Search response: success=${response.success}, message=${response.message}');

      if (response.success && response.data != null) {
        final productsData = response.data!['products'] ?? response.data!['data'];
        final pagination = response.data!['pagination'];
        
        if (productsData != null && productsData is List) {
          final products = await compute(_parseProducts, productsData);
          debugPrint('🔍 Search parsed ${products.length} products');
          return {
            'products': products,
            'has_next': pagination != null ? pagination['has_next'] ?? false : false,
          };
        }
      } else {
        debugPrint('❌ Search failed: ${response.message}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Search error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
    }
    return {'products': <Product>[], 'has_next': false};
  }

  /// Search products (Legacy wrapper)
  Future<List<Product>> searchProducts(String query) async {
    final result = await searchProductsPaginated(query);
    return result['products'] as List<Product>;
  }

  /// Search products by image (Paginated)
  Future<Map<String, dynamic>> searchByImagePaginated(
    String imagePath, {
    int page = 1,
    int perPage = 20,
    String? sortBy,
    double? minPrice,
    double? maxPrice,
  }) async {
    try {
      debugPrint('🔍 searchByImagePaginated called with: $imagePath');
      
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
      
      final response = await _api.postMultipart(
        ApiConstants.searchByImage,
        filePath: imagePath,
        fileField: 'file',
        queryParams: queryParams,
      );

      debugPrint('📡 API Response success: ${response.success}');
      debugPrint('📡 API Response message: ${response.message}');
      debugPrint('📡 API Response data keys: ${response.data?.keys.toList()}');

      if (response.success && response.data != null) {
        final productsData = response.data!['products'] ?? response.data!['data'];
        final pagination = response.data!['pagination'];
        
        debugPrint('📦 Products data type: ${productsData.runtimeType}');
        debugPrint('📦 Products count: ${productsData is List ? productsData.length : 'not a list'}');

        if (productsData != null && productsData is List) {
          final products = await compute(_parseProducts, productsData);
          return {
            'products': products,
            'has_next': pagination != null ? pagination['has_next'] ?? false : false,
          };
        }
      } else {
        debugPrint('❌ API call failed: ${response.message}');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ Image search error: $e');
      debugPrint('📍 Stack trace: $stackTrace');
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
        'per_page': 10,
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
          debugPrint('⚡ Using cached products for category $categoryId');
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
      debugPrint('❌ Error fetching category products: $e');
      return {'products': <Product>[]};
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

