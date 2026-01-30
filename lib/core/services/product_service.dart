import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../models/product_model.dart';
import 'api_service.dart';
import 'home_service.dart';

class ProductService extends ChangeNotifier {
  final ApiService _api = ApiService();
  HomeService? _homeService;
  bool _isLoading = false;
  String? _error;
  
  // In-memory cache for product details
  final Map<int, Product> _productCache = {};
  
  // Track when each product was cached (for staleness check)
  final Map<int, DateTime> _productCacheTimestamps = {};
  
  // How old (in days) before we consider product data stale and need refresh
  static const int _cacheMaxAgeDays = 7;

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Set HomeService reference for cache sync
  void setHomeService(HomeService homeService) {
    _homeService = homeService;
  }

  /// Clear all cached product details
  void clearCache() {
    _productCache.clear();
    _productCacheTimestamps.clear();
    debugPrint('🧹 Product details cache cleared');
    notifyListeners();
  }

  /// Get a cached product by ID (returns null if not cached)
  Product? getCachedProduct(int id) {
    return _productCache[id];
  }

  /// Clear cached product data for a specific product ID
  /// Useful when variant data becomes stale
  void clearProductCache(int id) {
    _productCache.remove(id);
    _productCacheTimestamps.remove(id);
    debugPrint('🗑️ Cleared cache for product $id');
  }
  
  /// Check if cached product is stale (older than _cacheMaxAgeDays)
  bool _isCacheStale(int id) {
    final timestamp = _productCacheTimestamps[id];
    if (timestamp == null) return true;
    
    final age = DateTime.now().difference(timestamp);
    final isStale = age.inDays >= _cacheMaxAgeDays;
    
    if (isStale) {
      debugPrint('⏰ Product $id cache is stale (${age.inDays} days old, max: $_cacheMaxAgeDays days)');
    }
    
    return isStale;
  }

  Future<Product?> getProductDetails(int id, {bool forceRefresh = false}) async {
    // 1. Check cache first - only use if product was fetched with full API call
    // Products from search/category lists don't have complete data
    // We mark a product as "complete" if it has non-null options list (even if empty)
    // AND has images (full product always has images array from API)
    // ALSO check if cache is stale (older than _cacheMaxAgeDays)
    if (!forceRefresh && _productCache.containsKey(id)) {
      final cached = _productCache[id]!;
      // A product fetched via get-product-by-id will always have:
      // - options list (even if empty [])
      // - images list (even if empty [])
      // Products from search listings have options=null and images=null
      final wasFullyFetched = cached.options != null && cached.images != null;
      final isStale = _isCacheStale(id);
      
      if (wasFullyFetched && !isStale) {
        debugPrint('📦 Returning cached details for product $id (fully fetched)');
        return cached;
      } else if (wasFullyFetched && isStale) {
        debugPrint('🔄 Cache is stale for product $id, refreshing from API...');
      } else {
        debugPrint('🔄 Cache exists but was from listing for product $id, fetching full details...');
      }
    }
    
    if (forceRefresh) {
      debugPrint('🔄 Force refresh requested for product $id, bypassing cache...');
      _productCache.remove(id);
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🌐 Making API call for product $id...');
      final response = await _api.get(
        ApiConstants.getProductById,
        queryParams: {'id': id},
      );

      if (response.success && response.data != null) {
        debugPrint('Product details response keys: ${response.data!.keys.toList()}');
        Product product;
        if (response.data!.containsKey('product')) {
          // Parse product with related_products from response root
          final productData = response.data!['product'] as Map<String, dynamic>;
          
          // Debug: Log options and variants from API
          debugPrint('📋 API options: ${productData['options']?.length ?? 'null'}');
          debugPrint('📋 API variations: ${productData['variations']?.length ?? 'null'}');
          
          // Merge related_products from response root into product data
          if (response.data!.containsKey('related_products')) {
            productData['related_products'] = response.data!['related_products'];
          }
          
          product = Product.fromJson(productData);
          
          // Debug: Log parsed product
          debugPrint('✅ Parsed product - options: ${product.options?.length ?? 'null'}, variants: ${product.variants?.length ?? 'null'}');
        } else {
          product = Product.fromJson(response.data!);
          debugPrint('✅ Parsed product (no wrapper) - options: ${product.options?.length ?? 'null'}, variants: ${product.variants?.length ?? 'null'}');
        }
        
        // 2. Save to cache with timestamp
        _productCache[id] = product;
        _productCacheTimestamps[id] = DateTime.now();
        debugPrint('💾 Cached product $id (will refresh after $_cacheMaxAgeDays days)');
        
        // 3. Sync to HomeService cache so category lists get updated product name
        _homeService?.updateProductInCache(product);
        
        return product;
      } else {
        _error = response.message ?? 'Failed to load product details';
        debugPrint('❌ API error: $_error');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('Error fetching product details: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
    return null;
  }
}
