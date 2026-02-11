import 'dart:async';
import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../models/shipping_model.dart';
import 'api_service.dart';

/// Shipping Service
/// Handles all shipping-related API calls and state management
class ShippingService extends ChangeNotifier {
  final ApiService _api = ApiService();

  // ============== STATE ==============
  bool _isLoading = false;
  bool _isComparing = false;
  String? _error;
  
  // Cached data
  List<ShippingMethod>? _methods;
  ShippingComparison? _comparison;
  ShippingCalculation? _airCalculation;
  ShippingCalculation? _seaCalculation;
  ShippingMethodType _selectedMethod = ShippingMethodType.air;
  
  // Polling for AI estimation
  Timer? _pollingTimer;
  Set<int> _processingProductIds = {};
  
  // ============== GETTERS ==============
  bool get isLoading => _isLoading;
  bool get isComparing => _isComparing;
  bool get isCalculating => _isLoading || _isComparing;
  String? get error => _error;
  List<ShippingMethod>? get methods => _methods;
  ShippingComparison? get comparison => _comparison;
  ShippingMethodType get selectedMethod => _selectedMethod;
  
  /// Get current calculation based on selected method
  ShippingCalculation? get currentCalculation {
    return _selectedMethod == ShippingMethodType.air 
        ? _airCalculation 
        : _seaCalculation;
  }
  
  /// Get shipping cost for current method
  double get shippingCost {
    return currentCalculation?.summary.totalShippingCost ?? 0.0;
  }
  
  /// Check if all items have shipping calculated
  bool get allItemsCalculated {
    return currentCalculation?.summary.allCalculated ?? false;
  }
  
  /// Check if any products are still being processed by AI
  bool get hasProcessingItems => _processingProductIds.isNotEmpty;
  
  /// Get number of pending items
  int get pendingItemsCount {
    return currentCalculation?.summary.itemsPending ?? 0;
  }

  // ============== METHODS ==============
  
  /// Set selected shipping method
  void setSelectedMethod(ShippingMethodType method) {
    if (_selectedMethod != method) {
      _selectedMethod = method;
      notifyListeners();
    }
  }

  /// Fetch available shipping methods
  Future<List<ShippingMethod>> fetchMethods() async {
    try {
      final response = await _api.get(ApiConstants.shippingGetMethods);
      
      if (response.success && response.data != null) {
        final data = response.data['data'] ?? response.data;
        final methodsList = data['methods'] as List?;
        
        if (methodsList != null) {
          _methods = methodsList
              .map((m) => ShippingMethod.fromJson(m))
              .toList();
          notifyListeners();
          return _methods!;
        }
      }
      
      _error = response.message;
      return [];
    } catch (e) {
      _error = e.toString();
      return [];
    }
  }

  /// Calculate shipping for cart items
  /// [productIds] - Optional list of product IDs (will fetch from cart)
  /// [cartItemIds] - Optional list of specific cart item IDs to calculate
  /// [method] - Shipping method (air/sea)
  Future<ShippingCalculation> calculateForCart({
    List<int>? productIds,
    List<int>? cartItemIds,
    ShippingMethodType method = ShippingMethodType.air,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{
        'method': method.value,
      };
      
      // Use cart_item_ids if provided, otherwise backend calculates for all cart items
      if (cartItemIds != null && cartItemIds.isNotEmpty) {
        queryParams['cart_item_ids'] = cartItemIds.join(',');
      }
      
      final response = await _api.get(
        ApiConstants.shippingCalculateForCart,
        queryParams: queryParams,
      );

      if (response.success && response.data != null) {
        final calculation = ShippingCalculation.fromJson(response.data);
        
        // Store based on method
        if (method == ShippingMethodType.air) {
          _airCalculation = calculation;
        } else {
          _seaCalculation = calculation;
        }
        
        // Track processing products for polling
        _updateProcessingProducts(calculation);
        
        _isLoading = false;
        notifyListeners();
        return calculation;
      }
      
      _error = response.message;
      _isLoading = false;
      notifyListeners();
      return ShippingCalculation.error(_error ?? 'Unknown error');
    } catch (e) {
      _error = e.toString();
      _isLoading = false;
      notifyListeners();
      return ShippingCalculation.error(_error!);
    }
  }

  /// Compare both shipping methods
  Future<ShippingComparison> compareShippingMethods({
    List<int>? productIds,
    List<int>? cartItemIds,
  }) async {
    _isComparing = true;
    _error = null;
    notifyListeners();

    try {
      // Build request body
      final body = <String, dynamic>{};
      if (cartItemIds != null && cartItemIds.isNotEmpty) {
        body['cart_item_ids'] = cartItemIds;
      }
      
      final response = await _api.post(
        ApiConstants.shippingCompare,
        body: body.isNotEmpty ? body : null,
      );

      if (response.success && response.data != null) {
        _comparison = ShippingComparison.fromJson(response.data);
        
        _isComparing = false;
        notifyListeners();
        return _comparison!;
      }
      
      _error = response.message;
      _isComparing = false;
      notifyListeners();
      return ShippingComparison.empty();
    } catch (e) {
      _error = e.toString();
      _isComparing = false;
      notifyListeners();
      return ShippingComparison.empty();
    }
  }

  /// Get product shipping status
  Future<ProductShippingStatus?> getProductStatus(int productId) async {
    try {
      final response = await _api.get(
        ApiConstants.shippingGetProductStatus,
        queryParams: {'product_id': productId},
      );

      if (response.success && response.data != null) {
        return ProductShippingStatus.fromJson(response.data);
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Trigger AI estimation for a product
  Future<bool> triggerEstimation(int productId, {bool async = true}) async {
    try {
      final response = await _api.post(
        ApiConstants.shippingTriggerEstimation,
        body: {
          'product_id': productId,
          'async': async,
        },
      );

      if (response.success) {
        final data = response.data?['data'] ?? response.data;
        final status = data?['status'];
        
        if (status == 'processing_started' || status == 'already_processing') {
          _processingProductIds.add(productId);
          _startPollingIfNeeded();
        }
        
        return true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  // ============== POLLING FOR AI ESTIMATION ==============
  
  /// Update tracking of products being processed
  void _updateProcessingProducts(ShippingCalculation calculation) {
    final newProcessing = <int>{};
    
    for (final item in calculation.items) {
      if (item.isAiProcessing || item.isPending) {
        newProcessing.add(item.productId);
      }
    }
    
    _processingProductIds = newProcessing;
    
    if (_processingProductIds.isNotEmpty) {
      _startPollingIfNeeded();
    } else {
      _stopPolling();
    }
  }

  /// Start polling for AI estimation updates
  void _startPollingIfNeeded() {
    if (_pollingTimer != null && _pollingTimer!.isActive) {
      return; // Already polling
    }
    
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      if (_processingProductIds.isEmpty) {
        _stopPolling();
        return;
      }
      
      // Re-fetch current calculation to check for updates
      await calculateForCart(method: _selectedMethod);
      
      // Check if all done
      if (_processingProductIds.isEmpty) {
        _stopPolling();
      }
    });
  }

  /// Stop polling
  void _stopPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Clear cached data
  void clearCache() {
    _comparison = null;
    _airCalculation = null;
    _seaCalculation = null;
    _processingProductIds.clear();
    _stopPolling();
    notifyListeners();
  }

  @override
  void dispose() {
    _stopPolling();
    super.dispose();
  }
}
