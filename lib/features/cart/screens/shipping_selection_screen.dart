import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/models/cart_model.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/shipping_service.dart';
import '../../../core/services/api_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/shipping_model.dart';
import '../../../core/theme/theme.dart';
import 'checkout_screen.dart';

/// Shipping Method Selection Screen
/// Shows BEFORE checkout - user picks Air or Sea with ACTUAL calculated costs
class ShippingSelectionScreen extends StatefulWidget {
  final List<int>? selectedCartItemIds;

  const ShippingSelectionScreen({
    super.key,
    this.selectedCartItemIds,
  });

  @override
  State<ShippingSelectionScreen> createState() => _ShippingSelectionScreenState();
}

class _ShippingSelectionScreenState extends State<ShippingSelectionScreen> {
  String? _selectedMethod; // 'air' or 'sea'
  ShippingComparison? _comparison;
  bool _isLoading = true;
  String? _error;
  Timer? _pollingTimer;
  bool _isPolling = false;

  @override
  void initState() {
    super.initState();
    // Use post-frame callback to avoid calling context.read during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadShippingCosts();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadShippingCosts({bool isPolling = false}) async {
    if (!isPolling) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final shippingService = context.read<ShippingService>();
      final comparison = await shippingService.compareShippingMethods(
        cartItemIds: widget.selectedCartItemIds,
      );
      
      if (mounted) {
        String? autoSelectedMethod;
        
        setState(() {
          _comparison = comparison;
          _isLoading = false;
          
          // AUTO-SELECT cheapest shipping method when data is ready
          if (!comparison.hasProcessingItems && _selectedMethod == null) {
            final airCost = comparison.air.totalCost;
            final seaCost = comparison.sea.totalCost;
            
            // Select the cheaper option
            if (airCost <= seaCost) {
              _selectedMethod = 'air';
              autoSelectedMethod = 'air';
              debugPrint('✈️ Auto-selected AIR shipping (\$${airCost.toStringAsFixed(2)} vs Sea \$${seaCost.toStringAsFixed(2)})');
            } else {
              _selectedMethod = 'sea';
              autoSelectedMethod = 'sea';
              debugPrint('🚢 Auto-selected SEA shipping (\$${seaCost.toStringAsFixed(2)} vs Air \$${airCost.toStringAsFixed(2)})');
            }
          }
        });
        
        // If a method was auto-selected, fetch cart with tax for that method
        if (autoSelectedMethod != null) {
          _refetchCartWithTax(autoSelectedMethod!);
        }

        // If there are still processing items, start polling
        if (comparison.hasProcessingItems) {
          _startPolling();
          // Trigger queue processor to process remaining items
          if (isPolling) {
            _triggerQueueProcessor();
          }
        } else {
          _stopPolling();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _startPolling() {
    if (_isPolling) return;
    _isPolling = true;
    debugPrint('🔄 Starting shipping cost polling...');
    
    // Poll every 3 seconds
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (mounted && _comparison?.hasProcessingItems == true) {
        debugPrint('🔄 Polling for shipping costs update...');
        _loadShippingCosts(isPolling: true);
      } else {
        _stopPolling();
      }
    });
  }

  void _stopPolling() {
    if (!_isPolling) return;
    debugPrint('✅ Stopping shipping cost polling');
    _pollingTimer?.cancel();
    _pollingTimer = null;
    _isPolling = false;
  }
  
  /// Trigger AI queue processor to process remaining items
  void _triggerQueueProcessor() {
    if (!mounted) return;
    debugPrint('🚀 Triggering AI queue processor from shipping selection polling...');
    try {
      final api = context.read<ApiService>();
      // Fire-and-forget
      api.get(
        ApiConstants.shippingQueueProcess,
        queryParams: {'secret': ApiConstants.shippingQueueSecret},
      ).then((response) {
        if (response.success) {
          final data = response.data;
          debugPrint('✅ Queue processor: processed=${data?['processed']}, remaining=${data?['remaining']}');
        }
      }).catchError((e) {
        debugPrint('⚠️ Queue processor error: $e');
      });
    } catch (e) {
      debugPrint('⚠️ Could not trigger queue processor: $e');
    }
  }

  void _selectMethod(String method) {
    // Don't allow selection if still processing
    if (_comparison?.hasProcessingItems == true) return;
    
    setState(() {
      _selectedMethod = method;
    });
    
    // Refetch cart with shipping method to get correct tax calculation
    // Tax depends on shipping method (air vs sea have different tax rates)
    _refetchCartWithTax(method);
  }
  
  /// Refetch cart data with shipping method to calculate correct tax
  Future<void> _refetchCartWithTax(String method) async {
    debugPrint('🔄 TAX: Refetching cart with shipping_method=$method');
    final cartService = context.read<CartService>();
    await cartService.fetchCart(silent: true, shippingMethod: method);
    
    // Debug: Log what tax we got back
    if (cartService.cartData != null) {
      debugPrint('📊 TAX: Cart total_tax=${cartService.cartData!.totalTax}');
      debugPrint('📊 TAX: Item count=${cartService.items.length}');
      for (var item in cartService.items) {
        debugPrint('   TAX: id=${item.id}, product=${item.productId}, categoryId=${item.categoryId}, qty=${item.quantity}, taxAmount=${item.taxAmount}');
      }
    } else {
      debugPrint('❌ TAX: cartData is null after fetch!');
    }
  }

  double get _selectedShippingCost {
    if (_comparison == null || _selectedMethod == null) return 0.0;
    return _selectedMethod == 'air' 
        ? _comparison!.air.totalCost 
        : _comparison!.sea.totalCost;
  }

  bool get _canProceedToCheckout {
    return _selectedMethod != null && 
           _comparison != null && 
           !_comparison!.hasProcessingItems;
  }

  void _proceedToCheckout() {
    if (!_canProceedToCheckout) return;

    // Use push instead of pushReplacement so user can go back to shipping selection
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CheckoutScreen(
          selectedCartItemIds: widget.selectedCartItemIds,
          shippingMethod: _selectedMethod!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartService = context.watch<CartService>();
    
    // Calculate subtotal and tax for SELECTED items only
    final selectedItems = _getSelectedItems(cartService);
    final subtotal = _calculateSelectedSubtotal(selectedItems);
    final tax = _calculateSelectedTax(selectedItems);
    final currency = cartService.items.isNotEmpty 
        ? cartService.items.first.currencySymbol 
        : '\$';

    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      appBar: AppBar(
        title: Text(
          'Choose Shipping',
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
      body: _isLoading
          ? _buildLoadingState(isDark)
          : _error != null
              ? _buildErrorState(isDark)
              : _buildContent(isDark, subtotal, tax, currency),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary500,
          ),
          const SizedBox(height: 16),
          Text(
            'Calculating shipping costs...',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.warning_2,
              size: 64,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              'Could not load shipping costs',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadShippingCosts,
              icon: const Icon(Iconsax.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(bool isDark, double subtotal, double tax, String currency) {
    final airCost = _comparison?.air.totalCost ?? 0.0;
    final seaCost = _comparison?.sea.totalCost ?? 0.0;
    final total = subtotal + tax + _selectedShippingCost;
    final isProcessing = _comparison?.hasProcessingItems == true;
    
    // Get surcharge info for the selected method
    final selectedMethodComparison = _selectedMethod == 'air' 
        ? _comparison?.air 
        : (_selectedMethod == 'sea' ? _comparison?.sea : null);
    final hasSurcharge = selectedMethodComparison?.hasSurcharge ?? false;
    final totalSurcharge = selectedMethodComparison?.totalSurchargeAmount ?? 0.0;
    final baseShipping = _selectedShippingCost - totalSurcharge;
    final surchargeBreakdown = selectedMethodComparison?.surchargeBreakdown ?? [];
    final hasSingleSurchargePercent = selectedMethodComparison?.hasSingleSurchargePercent ?? true;
    final singleSurchargePercent = selectedMethodComparison?.singleSurchargePercent;
    
    // Get rate info for display - now properly handles multiple different rates
    final totalCbm = selectedMethodComparison?.totalCbm ?? 0.0;
    final cbmBreakdown = selectedMethodComparison?.cbmBreakdownByRate ?? {};
    final hasSingleCbmRate = selectedMethodComparison?.hasSingleCbmRate ?? true;
    final singlePricePerCbm = selectedMethodComparison?.singlePricePerCbm;
    
    final totalWeight = selectedMethodComparison?.totalWeightKg ?? 0.0;
    final weightBreakdown = selectedMethodComparison?.weightBreakdownByRate ?? {};
    final hasSingleKgRate = selectedMethodComparison?.hasSingleKgRate ?? true;
    final singlePricePerKg = selectedMethodComparison?.singlePricePerKg;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'How would you like your order shipped?',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ).animate().fadeIn(duration: 300.ms),
          
          const SizedBox(height: 8),
          
          Text(
            isProcessing
                ? 'Calculating shipping costs for your items...'
                : 'These are approximate shipping costs,the exact shipping costs will be calculated after the goods arrive to our warehouse in China.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white60 : Colors.grey[600],
            ),
          ).animate(delay: 100.ms).fadeIn(duration: 300.ms),
          
          // Processing indicator
          if (isProcessing) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Calculating dimensions...',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        Text(
                          '${_comparison?.processingProductIds.length ?? 0} product(s) being analyzed',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ).animate(onPlay: (c) => c.repeat())
                .shimmer(duration: 1500.ms, color: Colors.orange.withOpacity(0.3)),
          ],
          
          const SizedBox(height: 32),
          
          // Air Shipping Option with ACTUAL COST
          _ShippingOptionCard(
            icon: '✈️',
            title: 'Air Freight',
            subtitle: 'Fast delivery',
            duration: _comparison?.air.estimatedDays ?? '14-21 days',
            cost: airCost,
            currency: currency,
            isSelected: _selectedMethod == 'air',
            isProcessing: isProcessing,
            onTap: () => _selectMethod('air'),
            isDark: isDark,
            color: Colors.blue,
          ).animate(delay: 200.ms).fadeIn().slideX(begin: -0.1, end: 0),
          
          const SizedBox(height: 16),
          
          // Sea Shipping Option with ACTUAL COST
          _ShippingOptionCard(
            icon: '🚢',
            title: 'Sea Freight',
            subtitle: 'Economical shipping',
            duration: _comparison?.sea.estimatedDays ?? '45-60 days',
            cost: seaCost,
            currency: currency,
            isSelected: _selectedMethod == 'sea',
            isProcessing: isProcessing,
            onTap: () => _selectMethod('sea'),
            isDark: isDark,
            color: Colors.teal,
          ).animate(delay: 300.ms).fadeIn().slideX(begin: -0.1, end: 0),
          
          const SizedBox(height: 32),
          
          // Order Summary with CALCULATED totals
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? DarkThemeColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
              ),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Products Subtotal',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.grey[600],
                      ),
                    ),
                    Text(
                      '$currency${subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
                // Tax row (only show if there's tax)
                if (tax > 0) ...[
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tax',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                      ),
                      Text(
                        '\$${tax.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Shipping',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                        if (_selectedMethod != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: _selectedMethod == 'air'
                                  ? Colors.blue.withOpacity(0.1)
                                  : Colors.teal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _selectedMethod == 'air' ? '✈️' : '🚢',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _selectedMethod == null 
                          ? 'Select method' 
                          : '$currency${_selectedShippingCost.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: _selectedMethod != null ? FontWeight.w600 : FontWeight.normal,
                        fontStyle: _selectedMethod == null ? FontStyle.italic : FontStyle.normal,
                        color: _selectedMethod != null 
                            ? (_selectedMethod == 'air' ? Colors.blue : Colors.teal)
                            : (isDark ? Colors.white38 : Colors.grey),
                      ),
                    ),
                  ],
                ),
                // Shipping rate details (show weight/CBM info)
                if (_selectedMethod != null) ...[
                  const SizedBox(height: 8),
                  // For Air: show weight breakdown
                  if (_selectedMethod == 'air') ...[
                    if (hasSingleKgRate)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Weight: ${totalWeight.toStringAsFixed(2)} kg @ \$${singlePricePerKg?.toStringAsFixed(2) ?? '-'}/kg',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      )
                    else
                      // Multiple rates - show breakdown
                      ...weightBreakdown.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 2),
                        child: Text(
                          '${entry.value.toStringAsFixed(2)} kg @ \$${entry.key.toStringAsFixed(2)}/kg',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      )),
                  ],
                  // For Sea: show CBM breakdown
                  if (_selectedMethod == 'sea') ...[
                    if (hasSingleCbmRate)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'CBM: ${totalCbm.toStringAsFixed(4)} @ \$${singlePricePerCbm?.toStringAsFixed(2) ?? '-'}/cbm',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      )
                    else
                      // Multiple rates - show breakdown per rate
                      ...cbmBreakdown.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(left: 16, bottom: 2),
                        child: Text(
                          '${entry.value.toStringAsFixed(4)} cbm @ \$${entry.key.toStringAsFixed(2)}/cbm',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      )),
                    // Show minimum applied notice if base shipping is significantly higher than raw CBM calc
                    // (tolerance of $1 to account for rounding vs actual minimum application)
                    Builder(builder: (_) {
                      final rawCbmCost = cbmBreakdown.entries.fold(0.0, (sum, e) => sum + (e.value * e.key));
                      final difference = baseShipping - rawCbmCost;
                      // Get minimum from comparison model (fallback to 0.50 if not present)
                      final minShipping = _comparison?.minimumShippingCost ?? 0.50;
                      // Only show if minimum added at least $1 (not just rounding differences)
                      if (difference > 1.0 && baseShipping > 0) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 16, top: 2),
                          child: Text(
                            '(\$${minShipping.toStringAsFixed(2)} min/item applied)',
                            style: TextStyle(
                              fontSize: 10,
                              fontStyle: FontStyle.italic,
                              color: isDark ? Colors.white30 : Colors.grey[400],
                            ),
                          ),
                        );
                      }
                      return const SizedBox.shrink();
                    }),
                  ],
                ],
                // Category Surcharge breakdown (only show if there's a surcharge)
                if (_selectedMethod != null && hasSurcharge) ...[
                  const SizedBox(height: 8),
                  // Base shipping cost
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          'Base Shipping',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.grey[500],
                          ),
                        ),
                      ),
                      Text(
                        '$currency${baseShipping.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Category surcharge row with highlight - show breakdown if different percentages
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.orange.withOpacity(0.3),
                      ),
                    ),
                    child: Column(
                      children: [
                        // Header row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Iconsax.warning_2,
                                  size: 14,
                                  color: Colors.orange.shade700,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  hasSingleSurchargePercent
                                      ? 'Category Surcharge (${singleSurchargePercent?.toStringAsFixed(0) ?? ''}%)'
                                      : 'Category Surcharges',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.orange.shade700,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '+$currency${totalSurcharge.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.orange.shade700,
                              ),
                            ),
                          ],
                        ),
                        // Breakdown rows if multiple different percentages
                        if (!hasSingleSurchargePercent) ...[
                          const SizedBox(height: 4),
                          ...surchargeBreakdown.map((item) => Padding(
                            padding: const EdgeInsets.only(left: 20, top: 2),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Product #${item.productId} (${item.percent.toStringAsFixed(0)}%)',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                                Text(
                                  '+$currency${item.amount.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.orange.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
                  ),
                ],
                if (_selectedMethod != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      Text(
                        '$currency${total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary500,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 20),
          
          // Continue Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canProceedToCheckout ? _proceedToCheckout : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                disabledBackgroundColor: isDark 
                    ? Colors.white10 
                    : Colors.grey.shade300,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (isProcessing)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: isDark ? Colors.white38 : Colors.grey,
                      ),
                    )
                  else
                    Icon(
                      _selectedMethod != null ? Iconsax.arrow_right_1 : Iconsax.ship,
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  Text(
                    isProcessing
                        ? 'Calculating...'
                        : (_selectedMethod != null 
                            ? 'Continue to Checkout' 
                            : 'Select a Shipping Method'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ).animate(delay: 500.ms).fadeIn().slideY(begin: 0.1, end: 0),
          
          const SizedBox(height: 16),
        ],
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

  /// Calculate subtotal for selected items only (without tax)
  double _calculateSelectedSubtotal(List<CartItem> selectedItems) {
    return selectedItems.fold(0.0, (sum, item) => sum + item.subtotal);
  }

  /// Calculate total tax for selected items
  double _calculateSelectedTax(List<CartItem> selectedItems) {
    return selectedItems.fold(0.0, (sum, item) => sum + item.taxAmount);
  }
}

class _ShippingOptionCard extends StatelessWidget {
  final String icon;
  final String title;
  final String subtitle;
  final String duration;
  final double cost;
  final String currency;
  final bool isSelected;
  final bool isProcessing;
  final VoidCallback onTap;
  final bool isDark;
  final Color color;

  const _ShippingOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.cost,
    required this.currency,
    required this.isSelected,
    this.isProcessing = false,
    required this.onTap,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Reduce opacity if processing
    final effectiveOpacity = isProcessing ? 0.6 : 1.0;
    
    return GestureDetector(
      onTap: isProcessing ? null : onTap, // Disable tap when processing
      child: Opacity(
        opacity: effectiveOpacity,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isSelected 
                ? color.withOpacity(0.1) 
                : (isDark ? DarkThemeColors.surface : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : (isDark ? Colors.white10 : Colors.grey.shade200),
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: color.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? color.withOpacity(0.15) 
                      : (isDark ? Colors.white10 : Colors.grey.shade100),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    icon,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
              
              const SizedBox(width: 16),
              
              // Text
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? color : (isDark ? Colors.white : Colors.black87),
                            ),
                          ),
                        ),
                        // PRICE BADGE
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected 
                                ? color.withOpacity(0.2) 
                                : (isDark ? Colors.white10 : Colors.grey.shade100),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: isProcessing
                              ? Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 1.5,
                                        color: color,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '...',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: isDark ? Colors.white60 : Colors.grey,
                                      ),
                                    ),
                                  ],
                                )
                              : Text(
                                  '$currency${cost.toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? color : (isDark ? Colors.white : Colors.black87),
                                  ),
                                ),
                        ),
                      ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white60 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white10 : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Iconsax.clock,
                          size: 12,
                          color: isDark ? Colors.white60 : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          duration,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white60 : Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(width: 8),
            
            // Checkmark
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : (isDark ? Colors.white30 : Colors.grey.shade400),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : null,
            ),
          ],
        ),
        ),
      ),
    );
  }
}
