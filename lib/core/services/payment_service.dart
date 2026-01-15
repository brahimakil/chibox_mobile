import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../models/payment_model.dart';
import 'api_service.dart';

/// Payment Service - Handles all Whish Money payment operations
class PaymentService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // State
  bool _isLoading = false;
  String? _error;
  PaymentTransaction? _currentTransaction;
  String? _paymentUrl;

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  PaymentTransaction? get currentTransaction => _currentTransaction;
  String? get paymentUrl => _paymentUrl;

  /// Clear error
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Reset state
  void reset() {
    _isLoading = false;
    _error = null;
    _currentTransaction = null;
    _paymentUrl = null;
    notifyListeners();
  }

  /// Initiate payment for an order
  /// Returns PaymentInitResponse with payment URL
  Future<PaymentInitResponse> initiatePayment({
    required int orderId,
    String currency = 'USD',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('💳 Initiating payment for order: $orderId');

      final response = await _apiService.post(
        ApiConstants.paymentInitiate,
        body: {
          'order_id': orderId,
          'currency': currency,
        },
      );

      if (response.success && response.data != null) {
        final result = PaymentInitResponse.fromJson({
          'success': true,
          'message': response.message,
          'data': response.data,
        });

        if (result.success && result.paymentUrl != null) {
          _paymentUrl = result.paymentUrl;
          debugPrint('✅ Payment initiated: ${result.externalId}');
          debugPrint('🔗 Payment URL: ${result.paymentUrl}');
        }

        _isLoading = false;
        notifyListeners();
        return result;
      } else {
        _error = response.message;
        debugPrint('❌ Payment initiation failed: ${response.message}');
        _isLoading = false;
        notifyListeners();
        return PaymentInitResponse.error(response.message);
      }
    } catch (e) {
      _error = 'Failed to initiate payment: $e';
      debugPrint('❌ Payment initiation exception: $e');
      _isLoading = false;
      notifyListeners();
      return PaymentInitResponse.error(_error!);
    }
  }

  /// Initiate checkout payment - PAYMENT BEFORE ORDER
  /// This is the CORRECT flow:
  /// 1. Validate and send checkout data
  /// 2. Get payment URL
  /// 3. User pays
  /// 4. On success, backend creates order and clears cart
  /// 5. On failure, cart remains intact
  Future<PaymentInitResponse> initiateCheckoutPayment({
    required Map<String, dynamic> checkoutData,
    String currency = 'USD',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('💳 Initiating checkout payment');

      // Add currency to checkout data
      final requestData = {
        ...checkoutData,
        'currency': currency,
      };

      final response = await _apiService.post(
        ApiConstants.paymentInitiateCheckout,
        body: requestData,
      );

      if (response.success && response.data != null) {
        final result = PaymentInitResponse.fromJson({
          'success': true,
          'message': response.message,
          'data': response.data,
        });

        if (result.success && result.paymentUrl != null) {
          _paymentUrl = result.paymentUrl;
          debugPrint('✅ Checkout payment initiated: ${result.externalId}');
          debugPrint('🔗 Payment URL: ${result.paymentUrl}');
        }

        _isLoading = false;
        notifyListeners();
        return result;
      } else {
        _error = response.message;
        debugPrint('❌ Checkout payment initiation failed: ${response.message}');
        _isLoading = false;
        notifyListeners();
        return PaymentInitResponse.error(response.message);
      }
    } catch (e) {
      _error = 'Failed to initiate checkout payment: $e';
      debugPrint('❌ Checkout payment initiation exception: $e');
      _isLoading = false;
      notifyListeners();
      return PaymentInitResponse.error(_error!);
    }
  }

  /// Check payment status by external ID
  Future<PaymentStatusResponse> checkPaymentStatus({
    String? externalId,
    int? orderId,
  }) async {
    if (externalId == null && orderId == null) {
      return PaymentStatusResponse.error(
          'Either external_id or order_id is required');
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔍 Checking payment status: externalId=$externalId, orderId=$orderId');

      final body = <String, dynamic>{};
      if (externalId != null) body['external_id'] = externalId;
      if (orderId != null) body['order_id'] = orderId;

      final response = await _apiService.post(
        ApiConstants.paymentStatus,
        body: body,
      );

      if (response.success && response.data != null) {
        final result = PaymentStatusResponse.fromJson({
          'success': true,
          'message': response.message,
          'data': response.data,
        });

        if (result.transaction != null) {
          _currentTransaction = result.transaction;
          _paymentUrl = result.paymentUrl;
        }

        debugPrint('✅ Payment status: ${result.transaction?.status}');
        _isLoading = false;
        notifyListeners();
        return result;
      } else {
        _error = response.message;
        debugPrint('❌ Payment status check failed: ${response.message}');
        _isLoading = false;
        notifyListeners();
        return PaymentStatusResponse.error(response.message);
      }
    } catch (e) {
      _error = 'Failed to check payment status: $e';
      debugPrint('❌ Payment status exception: $e');
      _isLoading = false;
      notifyListeners();
      return PaymentStatusResponse.error(_error!);
    }
  }

  /// Verify payment after user returns from payment page
  /// This should be called after the WebView is closed
  Future<PaymentVerifyResponse> verifyPayment({
    required String externalId,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('✔️ Verifying payment: $externalId');

      final response = await _apiService.post(
        ApiConstants.paymentVerify,
        body: {'external_id': externalId},
      );

      if (response.success && response.data != null) {
        final result = PaymentVerifyResponse.fromJson({
          'success': true,
          'message': response.message,
          'data': response.data,
        });

        debugPrint('✅ Payment verified: ${result.status}');
        _isLoading = false;
        notifyListeners();
        return result;
      } else {
        _error = response.message;
        debugPrint('❌ Payment verification failed: ${response.message}');
        _isLoading = false;
        notifyListeners();
        return PaymentVerifyResponse.error(response.message);
      }
    } catch (e) {
      _error = 'Failed to verify payment: $e';
      debugPrint('❌ Payment verification exception: $e');
      _isLoading = false;
      notifyListeners();
      return PaymentVerifyResponse.error(_error!);
    }
  }

  /// Poll for payment completion (useful when user is on payment page)
  /// Returns true when payment is complete (success or failed)
  Future<PaymentVerifyResponse?> pollPaymentStatus({
    required String externalId,
    Duration interval = const Duration(seconds: 3),
    Duration timeout = const Duration(minutes: 5),
  }) async {
    final stopTime = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(stopTime)) {
      try {
        final result = await verifyPayment(externalId: externalId);

        if (result.verified && !result.isPaymentPending) {
          return result;
        }

        // Wait before next poll
        await Future.delayed(interval);
      } catch (e) {
        debugPrint('❌ Poll error: $e');
        await Future.delayed(interval);
      }
    }

    return PaymentVerifyResponse.error('Payment verification timed out');
  }

  /// Retry a failed payment - creates a NEW payment transaction
  /// This cancels any old pending transactions and creates fresh one
  Future<PaymentInitResponse> retryPayment({
    required int orderId,
    String currency = 'USD',
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('🔄 Retrying payment for order: $orderId');

      final response = await _apiService.post(
        ApiConstants.paymentRetry,
        body: {
          'order_id': orderId,
          'currency': currency,
        },
      );

      if (response.success && response.data != null) {
        final result = PaymentInitResponse.fromJson({
          'success': true,
          'message': response.message,
          'data': response.data,
        });

        if (result.success && result.paymentUrl != null) {
          _paymentUrl = result.paymentUrl;
          debugPrint('✅ Payment retry initiated: ${result.externalId}');
          debugPrint('🔗 Payment URL: ${result.paymentUrl}');
        }

        _isLoading = false;
        notifyListeners();
        return result;
      } else {
        _error = response.message;
        debugPrint('❌ Payment retry failed: ${response.message}');
        _isLoading = false;
        notifyListeners();
        return PaymentInitResponse.error(response.message);
      }
    } catch (e) {
      _error = 'Failed to retry payment: $e';
      debugPrint('❌ Payment retry exception: $e');
      _isLoading = false;
      notifyListeners();
      return PaymentInitResponse.error(_error!);
    }
  }

  /// Cancel a pending payment transaction
  /// Only works for pending/processing transactions, NOT successful ones
  Future<bool> cancelPayment({
    String? externalId,
    int? orderId,
  }) async {
    if (externalId == null && orderId == null) {
      _error = 'Either external_id or order_id is required';
      return false;
    }

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      debugPrint('❌ Cancelling payment: externalId=$externalId, orderId=$orderId');

      final body = <String, dynamic>{};
      if (externalId != null) body['external_id'] = externalId;
      if (orderId != null) body['order_id'] = orderId;

      final response = await _apiService.post(
        ApiConstants.paymentCancel,
        body: body,
      );

      _isLoading = false;
      notifyListeners();

      if (response.success) {
        debugPrint('✅ Payment cancelled');
        return true;
      } else {
        _error = response.message;
        debugPrint('❌ Payment cancel failed: ${response.message}');
        return false;
      }
    } catch (e) {
      _error = 'Failed to cancel payment: $e';
      debugPrint('❌ Payment cancel exception: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
}
