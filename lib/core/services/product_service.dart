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

  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Set HomeService reference for cache sync
  void setHomeService(HomeService homeService) {
    _homeService = homeService;
  }

  /// Clear all cached product details
  void clearCache() {
    _productCache.clear();
    debugPrint('🧹 Product details cache cleared');
    notifyListeners();
  }

  Future<Product?> getProductDetails(int id) async {
    // 1. Check cache first
    if (_productCache.containsKey(id)) {
      debugPrint('📦 Returning cached details for product $id');
      return _productCache[id];
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(
        ApiConstants.getProductById,
        queryParams: {'id': id},
      );

      if (response.success && response.data != null) {
        debugPrint('Product details response keys: ${response.data!.keys.toList()}');
        Product product;
        if (response.data!.containsKey('product')) {
          product = Product.fromJson(response.data!['product'] as Map<String, dynamic>);
        } else {
          product = Product.fromJson(response.data!);
        }
        
        // 2. Save to cache
        _productCache[id] = product;
        
        // 3. Sync to HomeService cache so category lists get updated product name
        _homeService?.updateProductInCache(product);
        
        return product;
      } else {
        _error = response.message ?? 'Failed to load product details';
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
