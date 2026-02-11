import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../models/invoice_model.dart';
import 'api_service.dart';

/// Invoice Service - Handles all invoice-related API calls
class InvoiceService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<Invoice> _invoices = [];
  Invoice? _selectedInvoice;
  bool _isLoading = false;
  String? _error;

  // Pagination
  int _currentPage = 1;
  int _lastPage = 1;
  int _totalCount = 0;
  bool _hasNext = false;

  // Getters
  List<Invoice> get invoices => _invoices;
  Invoice? get selectedInvoice => _selectedInvoice;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get currentPage => _currentPage;
  int get totalCount => _totalCount;
  bool get hasMore => _hasNext;

  /// Fetch invoices list
  /// [type] - optional filter: 'product' or 'shipping'
  Future<void> fetchInvoices({String? type, bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _invoices = [];
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      String url = '${ApiConstants.getInvoices}?page=$_currentPage&per_page=20';
      if (type != null) {
        url += '&type=$type';
      }

      final response = await _apiService.get(url);

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final invoicesList = data['invoices'] as List<dynamic>? ?? [];
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        final newInvoices = invoicesList
            .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
            .toList();

        if (refresh || _currentPage == 1) {
          _invoices = newInvoices;
        } else {
          _invoices.addAll(newInvoices);
        }

        _totalCount = pagination['total'] ?? 0;
        _lastPage = pagination['last_page'] ?? 1;
        _hasNext = pagination['has_next'] ?? false;
      } else {
        _error = response.message ?? 'Failed to fetch invoices';
      }
    } catch (e) {
      _error = 'Failed to fetch invoices: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Load next page
  Future<void> loadMore({String? type}) async {
    if (!_hasNext || _isLoading) return;
    _currentPage++;
    await fetchInvoices(type: type);
  }

  /// Refresh invoices list
  Future<void> refresh({String? type}) async {
    await fetchInvoices(type: type, refresh: true);
  }

  /// Fetch a single invoice detail
  Future<void> fetchInvoiceDetail(int invoiceId) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get(
        '${ApiConstants.getInvoiceDetail}?id=$invoiceId',
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        _selectedInvoice = Invoice.fromJson(
            data['invoice'] as Map<String, dynamic>);
      } else {
        _error = response.message ?? 'Failed to fetch invoice';
      }
    } catch (e) {
      _error = 'Failed to fetch invoice: $e';
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Get the HTML view URL for an invoice
  String getInvoiceViewUrl(int invoiceId) {
    return '${ApiConstants.baseUrl}${ApiConstants.viewInvoice}?id=$invoiceId';
  }

  /// Fetch invoices for a specific order
  Future<List<Invoice>> fetchOrderInvoices(int orderId) async {
    try {
      final response = await _apiService.get(
        '${ApiConstants.getOrderInvoices}?order_id=$orderId',
      );
      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final invoicesList = data['invoices'] as List<dynamic>? ?? [];
        return invoicesList
            .map((json) => Invoice.fromJson(json as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}
    return [];
  }

  void clearSelectedInvoice() {
    _selectedInvoice = null;
    notifyListeners();
  }

  void clear() {
    _invoices = [];
    _selectedInvoice = null;
    _isLoading = false;
    _error = null;
    _currentPage = 1;
    _lastPage = 1;
    _totalCount = 0;
    _hasNext = false;
    notifyListeners();
  }
}
