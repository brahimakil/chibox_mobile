import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/models/address_model.dart';
import '../../../core/models/cart_model.dart';
import '../../../core/models/coupon_model.dart';
import '../../../core/services/address_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/coupon_service.dart';
import '../../../core/services/navigation_provider.dart';
import '../../../core/services/payment_service.dart';
import '../../../core/theme/theme.dart';
import '../../address/screens/add_address_screen.dart';
import '../../address/screens/address_list_screen.dart';
import '../../orders/screens/order_details_screen.dart';
import '../../orders/screens/orders_list_screen.dart';
import '../../payments/screens/payment_webview_screen.dart';
import '../../payments/screens/payment_result_screen.dart';
import '../widgets/coupon_selection_sheet.dart';

/// Checkout Screen with Payment Method Selection
/// The payment UI is temporary/fake but order creation is real
class CheckoutScreen extends StatefulWidget {
  /// List of cart item IDs to checkout (if null, checkout all items)
  final List<int>? selectedCartItemIds;
  
  /// Shipping method selected from previous screen ('air' or 'sea')
  final String shippingMethod;
  
  const CheckoutScreen({
    super.key, 
    this.selectedCartItemIds,
    required this.shippingMethod,
  });

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  Address? _selectedAddress;
  int _selectedPaymentMethod = 6; // 6 = Whish Money (only payment method)
  bool _isLoading = false;
  bool _isLoadingAddress = true;
  String? _notes;
  
  // Payment methods - Only Whish Money is supported
  // Backend Order.php: PAYMENT_WHISH_MONEY = 6
  final List<Map<String, dynamic>> _paymentMethods = [
    {
      'id': 6, // PAYMENT_WHISH_MONEY
      'name': 'Whish Money',
      'icon': Iconsax.wallet_3,
      'description': 'Pay securely with Whish Money',
      'isOnline': true,
    },
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDefaultAddress();
    });
  }

  Future<void> _loadDefaultAddress() async {
    final addressService = context.read<AddressService>();
    await addressService.fetchAddresses();
    
    if (mounted) {
      setState(() {
        _isLoadingAddress = false;
        // Get default address or first address
        final addresses = addressService.addresses;
        if (addresses.isNotEmpty) {
          _selectedAddress = addresses.firstWhere(
            (a) => a.isDefault,
            orElse: () => addresses.first,
          );
        }
      });
    }
  }

  Future<void> _selectAddress() async {
    final addressService = context.read<AddressService>();
    final addresses = addressService.addresses;
    
    Address? result;
    
    if (addresses.isEmpty) {
      // No addresses exist - go directly to add address screen
      result = await Navigator.push<Address>(
        context,
        MaterialPageRoute(
          builder: (_) => const AddAddressScreen(fromCheckout: true),
        ),
      );
    } else {
      // Has addresses - show address list for selection
      result = await Navigator.push<Address>(
        context,
        MaterialPageRoute(
          builder: (_) => const AddressListScreen(selectionMode: true),
        ),
      );
    }
    
    if (result != null && mounted) {
      setState(() => _selectedAddress = result);
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedAddress == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a delivery address'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cartService = context.read<CartService>();
      final couponService = context.read<CouponService>();

      // Calculate tax for backend
      final selectedItems = _getSelectedItems(cartService);
      final taxAmount = _calculateSelectedTax(selectedItems);
      
      // Get coupon info if applied
      final appliedCoupon = couponService.appliedCoupon;
      final validationResult = couponService.validationResult;
      
      // Build checkout data matching backend requirements
      // All payments go through Whish Money (payment first, then order)
      final checkoutData = {
        'tax_amount': taxAmount,
        'address_first_name': _selectedAddress!.firstName,
        'address_last_name': _selectedAddress!.lastName,
        'address_country_code': _selectedAddress!.countryCode,
        'address_phone_number': _selectedAddress!.phoneNumber,
        'address': _selectedAddress!.address,
        'country': _selectedAddress!.country?.name ?? '',
        'city': _selectedAddress!.city?.name ?? '',
        'state': _selectedAddress!.state,
        'route_name': _selectedAddress!.routeName,
        'building_name': _selectedAddress!.buildingName,
        'floor_number': _selectedAddress!.floorNumber.toString(),
        'payment_type': 6, // PAYMENT_WHISH_MONEY - only supported method
        'is_paid': 0, // Will be updated after successful payment
        'client_notes': _notes,
        // Shipping method - passed from shipping selection screen
        'shipping_method': widget.shippingMethod, // 'air' or 'sea'
        // Include selected cart item IDs for partial checkout
        if (widget.selectedCartItemIds != null && widget.selectedCartItemIds!.isNotEmpty)
          'cart_item_ids': widget.selectedCartItemIds,
        // Coupon info - backend will validate again
        if (appliedCoupon != null && validationResult != null) ...{
          'coupon_code': appliedCoupon.code,
          'coupon_usage_id': validationResult.usageId,
          'discount_amount': couponService.discountAmount,
        },
      };

      // Initiate payment FIRST, order created on success
      await _initiateCheckoutPayment(checkoutData);
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
      }
    }
  }

  /// Initiate checkout payment - NEW CORRECT FLOW
  /// Payment first, order created only on successful payment
  Future<void> _initiateCheckoutPayment(Map<String, dynamic> checkoutData) async {
    final paymentService = context.read<PaymentService>();
    final cartService = context.read<CartService>();
    
    // Get cart total for display
    final cartTotal = cartService.cartData?.total ?? 0.0;
    
    final initResponse = await paymentService.initiateCheckoutPayment(
      checkoutData: checkoutData,
      currency: 'USD',
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (initResponse.success && initResponse.paymentUrl != null) {
      // Navigate to WebView for payment
      final result = await Navigator.push<PaymentWebViewResult>(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentWebViewScreen(
            paymentUrl: initResponse.paymentUrl!,
            externalId: initResponse.externalId!,
            amount: initResponse.amount ?? cartTotal,
            currency: initResponse.currency ?? 'USD',
          ),
        ),
      );

      if (!mounted) return;

      if (result != null) {
        _handleCheckoutPaymentResult(result, initResponse.amount ?? cartTotal);
      }
    } else {
      // Payment initiation failed - cart is still intact, just show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(initResponse.message),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    }
  }

  /// Handle checkout payment result
  /// On success: Order was created by backend, cart was cleared, show success
  /// On failure: Nothing happened, cart intact, show error and return to cart
  void _handleCheckoutPaymentResult(PaymentWebViewResult result, double amount) {
    if (result.success) {
      // Success! Backend created order and cleared cart
      // Refresh cart to show it's empty
      context.read<CartService>().fetchCart();
      
      // Clear the applied coupon and refresh coupons list (coupon was redeemed)
      context.read<CouponService>().clearAppliedCoupon();
      context.read<CouponService>().fetchMyCoupons();
      
      // Show success result screen
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PaymentResultScreen(
            success: true,
            message: result.message ?? 'Payment successful! Your order has been placed.',
            orderId: result.orderId,
            amount: amount,
            currency: 'USD',
            onViewOrder: result.orderId != null ? (ctx) {
              Navigator.pushReplacement(
                ctx,
                MaterialPageRoute(
                  builder: (_) => OrderDetailsScreen(orderId: result.orderId!),
                ),
              );
            } : null,
            onGoHome: (ctx) {
              final navProvider = ctx.read<NavigationProvider>();
              navProvider.setIndex(0);
              Navigator.of(ctx).popUntil((route) => route.isFirst);
            },
          ),
        ),
      );
    } else {
      // Payment failed - cart is still intact, just show error and let user go back
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message ?? 'Payment failed. Your cart items are still saved.'),
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      // Just stay on checkout screen - user can try again or go back to cart
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartService = context.watch<CartService>();
    final cartData = cartService.cartData;
    
    // Get only selected items
    final selectedItems = _getSelectedItems(cartService);
    final selectedSubtotal = _calculateSelectedSubtotal(selectedItems);
    final selectedTotal = _calculateSelectedTotal(selectedItems);
    final currency = cartData?.currencySymbol ?? '\$';

    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      appBar: AppBar(
        title: Text(
          'Checkout',
          style: AppTypography.headingSmall(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        backgroundColor: isDark ? DarkThemeColors.surface : Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Shipping Method Badge (already selected)
                  _buildShippingBadge(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // Delivery Address Section
                  _buildSectionHeader('Delivery Address', isDark),
                  const SizedBox(height: 12),
                  _buildAddressCard(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // Payment Method Section
                  _buildSectionHeader('Payment Method', isDark),
                  const SizedBox(height: 12),
                  ..._paymentMethods.map((method) => _buildPaymentMethodCard(method, isDark)),
                  
                  const SizedBox(height: 24),
                  
                  // Order Notes Section
                  _buildSectionHeader('Order Notes (Optional)', isDark),
                  const SizedBox(height: 12),
                  _buildNotesField(isDark),
                  
                  const SizedBox(height: 24),
                  
                  // Order Summary
                  _buildSectionHeader('Order Summary', isDark),
                  const SizedBox(height: 12),
                  _buildOrderSummary(selectedItems, selectedSubtotal, currency, isDark),
                  
                  const SizedBox(height: 100), // Bottom padding for button
                ],
              ),
            ),
          ),
          
          // Bottom Checkout Button - pass subtotal only (no tax)
          _buildBottomBar(selectedSubtotal, currency, isDark),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppColors.primary500,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildAddressCard(bool isDark) {
    if (_isLoadingAddress) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? DarkThemeColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: 150,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 200,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate(onPlay: (c) => c.repeat())
          .shimmer(duration: 1200.ms, color: isDark ? Colors.white10 : Colors.white54);
    }

    if (_selectedAddress == null) {
      return InkWell(
        onTap: _selectAddress,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? DarkThemeColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary500.withOpacity(0.3),
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.add, color: AppColors.primary500),
              const SizedBox(width: 8),
              Text(
                'Add Delivery Address',
                style: TextStyle(
                  color: AppColors.primary500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return InkWell(
      onTap: _selectAddress,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? DarkThemeColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary500.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Iconsax.location, color: AppColors.primary500),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_selectedAddress!.firstName} ${_selectedAddress!.lastName}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (_selectedAddress!.isDefault) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.primary500.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Default',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primary500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_selectedAddress!.address}, ${_selectedAddress!.buildingName}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    '${_selectedAddress!.city?.name ?? ''}, ${_selectedAddress!.country?.name ?? ''}',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentMethodCard(Map<String, dynamic> method, bool isDark) {
    final isSelected = _selectedPaymentMethod == method['id'];
    final isDisabled = method['disabled'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: isDisabled ? null : () => setState(() => _selectedPaymentMethod = method['id']),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? DarkThemeColors.surface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected 
                  ? AppColors.primary500 
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDisabled 
                      ? (isDark ? Colors.white10 : Colors.grey.shade100)
                      : AppColors.primary500.withOpacity(isSelected ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  method['icon'],
                  color: isDisabled 
                      ? (isDark ? Colors.white30 : Colors.grey)
                      : AppColors.primary500,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          method['name'],
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isDisabled 
                                ? (isDark ? Colors.white30 : Colors.grey)
                                : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        if (isDisabled) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white10 : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'Coming Soon',
                              style: TextStyle(
                                fontSize: 10,
                                color: isDark ? Colors.white38 : Colors.grey,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      method['description'],
                      style: TextStyle(
                        fontSize: 12,
                        color: isDisabled 
                            ? (isDark ? Colors.white.withOpacity(0.2) : Colors.grey.shade400)
                            : (isDark ? Colors.white54 : Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
              ),
              if (!isDisabled)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected ? AppColors.primary500 : Colors.transparent,
                    border: Border.all(
                      color: isSelected 
                          ? AppColors.primary500 
                          : (isDark ? Colors.white38 : Colors.grey.shade400),
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShippingBadge(bool isDark) {
    final isAir = widget.shippingMethod == 'air';
    final color = isAir ? Colors.blue : Colors.teal;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Text(
            isAir ? '✈️' : '🚢',
            style: const TextStyle(fontSize: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAir ? 'Air Freight' : 'Sea Freight',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAir ? 'Estimated: 7-14 days' : 'Estimated: 30-45 days',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Change',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesField(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: TextField(
        onChanged: (value) => _notes = value,
        maxLines: 3,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: 'Add any special instructions for your order...',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.grey,
            fontSize: 14,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(16),
        ),
      ),
    );
  }

  /// Get only the selected cart items
  List<CartItem> _getSelectedItems(CartService cartService) {
    if (widget.selectedCartItemIds == null || widget.selectedCartItemIds!.isEmpty) {
      return cartService.items; // All items if none specified
    }
    return cartService.items
        .where((item) => widget.selectedCartItemIds!.contains(item.id))
        .toList();
  }

  /// Calculate total for selected items only (subtotal + tax)
  double _calculateSelectedTotal(List<CartItem> selectedItems) {
    return selectedItems.fold(0.0, (sum, item) => sum + item.subtotal + item.taxAmount);
  }

  /// Calculate subtotal for selected items only (without tax)
  double _calculateSelectedSubtotal(List<CartItem> selectedItems) {
    return selectedItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Calculate total tax for selected items
  double _calculateSelectedTax(List<CartItem> selectedItems) {
    return selectedItems.fold(0.0, (sum, item) => sum + item.taxAmount);
  }

  Widget _buildOrderSummary(List<CartItem> selectedItems, double subtotal, String currency, bool isDark) {
    final tax = _calculateSelectedTax(selectedItems);
    final itemCount = selectedItems.length;
    final isAir = widget.shippingMethod == 'air';
    final methodName = isAir ? 'Air ✈️' : 'Sea 🚢';
    
    // Get coupon discount
    final couponService = context.watch<CouponService>();
    final discountAmount = couponService.discountAmount;
    final appliedCoupon = couponService.appliedCoupon;
    final subtotalAfterDiscount = subtotal - discountAmount;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
      ),
      child: Column(
        children: [
          _buildSummaryRow('Items ($itemCount)', '$currency${subtotal.toStringAsFixed(2)}', isDark),
          const SizedBox(height: 12),
          // Coupon row
          _buildCouponRow(subtotal, currency, isDark, appliedCoupon, discountAmount),
          if (discountAmount > 0) ...[
            const SizedBox(height: 12),
            _buildSummaryRow(
              'Subtotal after discount',
              '$currency${subtotalAfterDiscount.toStringAsFixed(2)}',
              isDark,
            ),
          ],
          const SizedBox(height: 12),
          // Shipping method selected (cost calculated after order)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shipping Method',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? Colors.white60 : Colors.grey[600],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAir
                      ? Colors.blue.withOpacity(0.1)
                      : Colors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  methodName,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isAir ? Colors.blue : Colors.teal,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Note about deferred shipping & tax payment
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Iconsax.timer_1, size: 18, color: Colors.amber[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Shipping & Tax - Pay Later',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[800],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '• Shipping cost will be calculated and confirmed by our team\n'
                  '• Once confirmed, you\'ll be notified to pay for shipping\n'
                  '• Tax (if applicable) will also be added at that time',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.5,
                    color: Colors.amber[900]?.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pay Now (Products)',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (discountAmount > 0) ...[                    Text(
                      '$currency${subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        decoration: TextDecoration.lineThrough,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    ),
                  ],
                  Text(
                    '$currency${subtotalAfterDiscount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, bool isDark, {bool isGreen = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.white60 : Colors.grey[600],
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isGreen ? AppColors.success : (isDark ? Colors.white : Colors.black87),
          ),
        ),
      ],
    );
  }

  Widget _buildCouponRow(double subtotal, String currency, bool isDark, Coupon? appliedCoupon, double discountAmount) {
    return InkWell(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => CouponSelectionSheet(
            subtotal: subtotal,
            currencySymbol: currency,
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: appliedCoupon != null
              ? Colors.green.withOpacity(0.1)
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: appliedCoupon != null
                ? Colors.green.withOpacity(0.3)
                : (isDark ? Colors.white12 : Colors.grey.shade300),
          ),
        ),
        child: Row(
          children: [
            Icon(
              Iconsax.ticket_discount,
              size: 20,
              color: appliedCoupon != null ? Colors.green : (isDark ? Colors.white60 : Colors.grey[600]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: appliedCoupon != null
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appliedCoupon.code,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                        Text(
                          appliedCoupon.label,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey[600],
                          ),
                        ),
                      ],
                    )
                  : Text(
                      'Apply Coupon',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white70 : Colors.grey[700],
                      ),
                    ),
            ),
            if (appliedCoupon != null) ...[
              Text(
                '-$currency${discountAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.green[700],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  context.read<CouponService>().clearAppliedCoupon();
                },
                child: Icon(
                  Icons.close,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                ),
              ),
            ] else
              Icon(
                Icons.chevron_right,
                size: 20,
                color: isDark ? Colors.white54 : Colors.grey[600],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(double subtotal, String currency, bool isDark) {
    final couponService = context.watch<CouponService>();
    final discountAmount = couponService.discountAmount;
    final total = subtotal - discountAmount; // Subtract discount from subtotal
    final canCheckout = !_isLoading;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  discountAmount > 0 ? 'Pay Now' : 'Subtotal',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currency${total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary500,
                      ),
                    ),
                    if (discountAmount > 0) ...[
                      const SizedBox(width: 6),
                      Text(
                        '$currency${subtotal.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: ElevatedButton(
                onPressed: canCheckout ? _placeOrder : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary500.withOpacity(0.5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Iconsax.shopping_bag),
                          SizedBox(width: 8),
                          Text(
                            'Place Order',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
