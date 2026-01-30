import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/theme/theme.dart';

/// Result returned when payment WebView is closed
class PaymentWebViewResult {
  final bool success;
  final String? externalId;
  final String? message;
  final int? orderId;

  PaymentWebViewResult({
    required this.success,
    this.externalId,
    this.message,
    this.orderId,
  });
}

/// WebView screen for Whish Money payment
class PaymentWebViewScreen extends StatefulWidget {
  final String paymentUrl;
  final String externalId;
  final double amount;
  final String currency;

  const PaymentWebViewScreen({
    super.key,
    required this.paymentUrl,
    required this.externalId,
    required this.amount,
    required this.currency,
  });

  @override
  State<PaymentWebViewScreen> createState() => _PaymentWebViewScreenState();
}

class _PaymentWebViewScreenState extends State<PaymentWebViewScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isVerifying = false;
  double _loadingProgress = 0;
  String _currentUrl = '';
  Timer? _pollTimer;
  bool _hasError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _initWebView();
    _startPolling();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            setState(() {
              _loadingProgress = progress / 100;
            });
          },
          onPageStarted: (url) {
            debugPrint('📄 Page started: $url');
            setState(() {
              _isLoading = true;
              _currentUrl = url;
            });
          },
          onPageFinished: (url) {
            debugPrint('✅ Page finished: $url');
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            _checkForPaymentCompletion(url);
          },
          onNavigationRequest: (request) {
            debugPrint('🔗 Navigation: ${request.url}');
            // Allow all navigation within payment flow
            return NavigationDecision.navigate;
          },
          onWebResourceError: (error) {
            debugPrint('❌ WebView error: ${error.description}');
            // Don't show error for minor issues, only major ones
            if (error.errorType == WebResourceErrorType.hostLookup ||
                error.errorType == WebResourceErrorType.timeout ||
                error.errorType == WebResourceErrorType.connect) {
              setState(() {
                _hasError = true;
                _errorMessage = 'Connection error. Please check your internet.';
              });
            }
          },
          onHttpError: (error) {
            debugPrint('❌ HTTP error: ${error.response?.statusCode}');
            // Ignore 404 on redirect pages - they're temporary
            if (error.response?.statusCode == 404) {
              final url = error.request?.uri.toString() ?? '';
              if (url.contains('/payment/success') || url.contains('/payment/failure')) {
                debugPrint('⚠️ Ignoring 404 on payment redirect page');
                return;
              }
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.paymentUrl));
  }

  void _startPolling() {
    // Poll every 5 seconds to check payment status
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      if (!mounted || _isVerifying) return;
      await _verifyPayment(silent: true);
    });
  }

  void _checkForPaymentCompletion(String url) {
    // Check if URL indicates success or failure
    final lowerUrl = url.toLowerCase();
    
    if (lowerUrl.contains('/payment/success') || 
        lowerUrl.contains('-payment/success') ||
        lowerUrl.contains('status=success') ||
        lowerUrl.contains('payment_success')) {
      _verifyPayment();
    } else if (lowerUrl.contains('/payment/failure') || 
               lowerUrl.contains('-payment/failure') ||
               lowerUrl.contains('status=failed') ||
               lowerUrl.contains('payment_failed') ||
               lowerUrl.contains('payment_cancelled')) {
      _handlePaymentFailure();
    }
  }

  Future<void> _verifyPayment({bool silent = false}) async {
    if (_isVerifying) return;
    
    _isVerifying = true; // No setState - silent operation

    try {
      final paymentService = Provider.of<PaymentService>(context, listen: false);
      debugPrint('🔍 Polling verify for: ${widget.externalId}');
      final result = await paymentService.verifyPayment(
        externalId: widget.externalId,
      );

      debugPrint('🔍 Verify result: verified=${result.verified}, status=${result.status}, orderId=${result.orderId}');

      if (!mounted) return;

      if (result.verified && result.isPaymentSuccess) {
        debugPrint('✅ Payment verified as SUCCESS - popping webview');
        _pollTimer?.cancel();
        Navigator.of(context).pop(PaymentWebViewResult(
          success: true,
          externalId: widget.externalId,
          message: 'Payment successful',
          orderId: result.orderId,
        ));
      } else if (result.verified && result.isPaymentFailed) {
        debugPrint('❌ Payment verified as FAILED - popping webview');
        _pollTimer?.cancel();
        if (!silent) {
          Navigator.of(context).pop(PaymentWebViewResult(
            success: false,
            externalId: widget.externalId,
            message: result.message,
            orderId: result.orderId,
          ));
        }
      } else {
        debugPrint('⏳ Payment still pending, continuing to poll...');
      }
    } catch (e) {
      debugPrint('❌ Verification error: $e');
    } finally {
      _isVerifying = false; // No setState - silent operation
    }
  }

  void _handlePaymentFailure() {
    _pollTimer?.cancel();
    Navigator.of(context).pop(PaymentWebViewResult(
      success: false,
      externalId: widget.externalId,
      message: 'Payment was cancelled or failed',
    ));
  }

  Future<bool> _onWillPop() async {
    _pollTimer?.cancel();
    
    // Show confirmation dialog
    final shouldClose = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Payment?'),
        content: const Text(
          'Are you sure you want to cancel this payment? '
          'You can retry payment from your order details.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Continue Payment'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (shouldClose == true) {
      if (mounted) {
        Navigator.of(context).pop(PaymentWebViewResult(
          success: false,
          externalId: widget.externalId,
          message: 'Payment cancelled by user',
        ));
      }
    }
    
    return false; // Prevent default pop since we handle it
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Complete Payment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              Text(
                '${widget.currency} ${widget.amount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => _onWillPop(),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _controller.reload(),
              tooltip: 'Refresh',
            ),
          ],
          bottom: _isLoading
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(2),
                  child: LinearProgressIndicator(
                    value: _loadingProgress,
                    backgroundColor: Colors.transparent,
                    valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary500),
                  ),
                )
              : null,
        ),
        body: Stack(
          children: [
            WebViewWidget(controller: _controller),
            // Show loading overlay for initial load
            if (_isLoading && _loadingProgress < 0.3)
              Container(
                color: isDark ? DarkThemeColors.background : Colors.white,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated loading indicator
                      SizedBox(
                        width: 80,
                        height: 80,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              color: AppColors.primary500,
                              strokeWidth: 3,
                            ),
                            Icon(
                              Icons.payment,
                              size: 32,
                              color: AppColors.primary500,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Loading payment page...',
                        style: TextStyle(
                          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait',
                        style: TextStyle(
                          color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            // Show error message if connection failed
            if (_hasError)
              Container(
                color: (isDark ? DarkThemeColors.background : Colors.white).withOpacity(0.95),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.error_outline,
                          size: 64,
                          color: AppColors.error,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          _errorMessage,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _hasError = false;
                              _errorMessage = '';
                            });
                            _controller.reload();
                          },
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary500,
                            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
              border: Border(
                top: BorderSide(color: isDark ? DarkThemeColors.border : LightThemeColors.border, width: 1),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Secure payment powered by Whish Money',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
