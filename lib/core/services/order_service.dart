import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../models/order_model.dart';
import 'api_service.dart';

/// Order Service - Handles all order-related API calls
class OrderService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<OrderSummary> _orders = [];
  OrderDetails? _selectedOrder;
  bool _isLoading = false;
  String? _error;
  
  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalCount = 0;
  bool _hasNext = false;
  bool _hasPrev = false;

  // Getters
  List<OrderSummary> get orders => _orders;
  OrderDetails? get selectedOrder => _selectedOrder;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get lastPage => _lastPage;
  int get totalCount => _totalCount;
  bool get hasNext => _hasNext;
  bool get hasPrev => _hasPrev;
  bool get hasMore => _hasNext;

  /// Checkout - Create order from cart
  /// Returns the order ID if successful, null otherwise
  Future<int?> checkout(Map<String, dynamic> checkoutData) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConstants.checkout,
        body: checkoutData,
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        // Backend returns { order: { id, order_number, ... } }
        final order = data['order'] as Map<String, dynamic>?;
        final orderId = order?['id'] as int?;
        
        _isLoading = false;
        notifyListeners();
        return orderId;
      } else {
        _error = response.message ?? 'Failed to create order';
      }
    } catch (e) {
      _error = 'Failed to create order: $e';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Fetch orders with pagination and optional status filter
  Future<void> fetchOrders({
    int page = 1,
    int perPage = 20,
    int? status,
    bool refresh = false,
  }) async {
    if (_isLoading) return;

    _isLoading = true;
    _error = null;
    
    if (refresh) {
      _orders = [];
      _currentPage = 1;
    }
    
    notifyListeners();

    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };
      
      if (status != null) {
        queryParams['status'] = status.toString();
      }

      final response = await _apiService.get(
        '/v3_0_0-order/get-orders',
        queryParams: queryParams,
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // Parse orders
        final ordersJson = data['orders'] as List<dynamic>? ?? [];
        final newOrders = ordersJson
            .map((json) => OrderSummary.fromJson(json as Map<String, dynamic>))
            .toList();

        // Parse pagination
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};
        _currentPage = pagination['current_page'] ?? 1;
        _lastPage = pagination['last_page'] ?? 1;
        _totalCount = pagination['total'] ?? 0;
        _hasNext = pagination['has_next'] ?? false;
        _hasPrev = pagination['has_prev'] ?? false;

        if (refresh || page == 1) {
          _orders = newOrders;
        } else {
          _orders.addAll(newOrders);
        }
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = 'Failed to fetch orders';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load next page of orders
  Future<void> loadMore() async {
    if (!_hasNext || _isLoading) return;
    await fetchOrders(page: _currentPage + 1);
  }

  /// Refresh orders (first page)
  Future<void> refresh() async {
    await fetchOrders(page: 1, refresh: true);
  }

  /// Fetch order details by ID
  Future<OrderDetails?> fetchOrderDetails(int orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use query parameter ?id=X for Yii2 action parameter
      final response = await _apiService.get('${ApiConstants.getOrderDetails}?id=$orderId');

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final orderJson = data['order'] as Map<String, dynamic>?;
        
        if (orderJson != null) {
          _selectedOrder = OrderDetails.fromJson(orderJson);
          _isLoading = false;
          notifyListeners();
          return _selectedOrder;
        }
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Failed to fetch order details';
    }

    _isLoading = false;
    notifyListeners();
    return null;
  }

  /// Cancel order
  Future<bool> cancelOrder(int orderId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // Use query parameter ?id=X for Yii2 action parameter
      final response = await _apiService.post('${ApiConstants.cancelOrder}?id=$orderId');

      if (response.success) {
        // Update order status in local list
        final index = _orders.indexWhere((o) => o.id == orderId);
        if (index != -1) {
          // Refresh orders to get updated data
          await refresh();
        }
        
        // Update selected order if it's the cancelled one
        if (_selectedOrder?.id == orderId) {
          await fetchOrderDetails(orderId);
        }
        
        _isLoading = false;
        notifyListeners();
        return true;
      }
      
      _error = response.message;
    } catch (e) {
      _error = 'Failed to cancel order';
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  /// Initiate payment for an order (Products or Shipping based on order state)
  /// Returns payment data with 'payment_url' if successful
  Future<Map<String, dynamic>?> initiatePayment(int orderId) async {
    try {
      final response = await _apiService.post(
        ApiConstants.paymentInitiate,
        body: {'order_id': orderId},
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        return data;
      } else {
        return {'message': response.message ?? 'Failed to initiate payment'};
      }
    } catch (e) {
      return {'message': 'Error: $e'};
    }
  }

  /// Clear selected order
  void clearSelectedOrder() {
    _selectedOrder = null;
    notifyListeners();
  }

  /// Clear all data
  void clear() {
    _orders = [];
    _selectedOrder = null;
    _isLoading = false;
    _error = null;
    _currentPage = 1;
    _lastPage = 1;
    _totalCount = 0;
    _hasNext = false;
    _hasPrev = false;
    notifyListeners();
  }
}
