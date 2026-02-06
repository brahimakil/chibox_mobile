import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/models/shipping_model.dart';
import '../../../core/services/shipping_service.dart';
import '../../../core/theme/theme.dart';

/// Shipping Method Selector Widget
/// Displays Air and Sea shipping options with real-time pricing
class ShippingMethodSelector extends StatefulWidget {
  /// Called when shipping method is selected with the new method and cost
  final void Function(ShippingMethodType method, double cost)? onMethodSelected;
  
  /// Cart item IDs to calculate shipping for (these are the cart table IDs)
  final List<int>? cartItemIds;
  
  /// Legacy: Product IDs (use cartItemIds instead)
  final List<int>? productIds;
  
  /// Currency symbol
  final String currency;
  
  /// Currently selected shipping method
  final ShippingMethodType selectedMethod;

  const ShippingMethodSelector({
    super.key,
    this.onMethodSelected,
    this.cartItemIds,
    this.productIds,
    this.currency = '\$',
    this.selectedMethod = ShippingMethodType.air,
  });

  @override
  State<ShippingMethodSelector> createState() => _ShippingMethodSelectorState();
}

class _ShippingMethodSelectorState extends State<ShippingMethodSelector> {
  bool _isInitialized = false;
  List<int>? _lastCartItemIds;
  
  /// Get the cart item IDs (supports legacy productIds parameter)
  List<int>? get _effectiveCartItemIds => widget.cartItemIds ?? widget.productIds;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeShipping();
    });
  }
  
  @override
  void didUpdateWidget(ShippingMethodSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-initialize if cart item IDs changed
    final oldIds = oldWidget.cartItemIds ?? oldWidget.productIds;
    final newIds = _effectiveCartItemIds;
    if (_idsChanged(oldIds, newIds)) {
      _isInitialized = false;
      _initializeShipping();
    }
  }
  
  bool _idsChanged(List<int>? old, List<int>? current) {
    if (old == null && current == null) return false;
    if (old == null || current == null) return true;
    if (old.length != current.length) return true;
    for (int i = 0; i < old.length; i++) {
      if (old[i] != current[i]) return true;
    }
    return false;
  }

  Future<void> _initializeShipping() async {
    if (_isInitialized) return;
    _isInitialized = true;
    _lastCartItemIds = _effectiveCartItemIds;
    
    final shippingService = context.read<ShippingService>();
    
    // Set initial method
    shippingService.setSelectedMethod(widget.selectedMethod);
    
    // Compare both methods to get costs
    await shippingService.compareShippingMethods(
      cartItemIds: _effectiveCartItemIds,
    );
    
    // Calculate for the initial method
    final calculation = await shippingService.calculateForCart(
      cartItemIds: _effectiveCartItemIds,
      method: widget.selectedMethod,
    );
    
    // Notify parent of initial cost
    if (calculation.success && widget.onMethodSelected != null) {
      widget.onMethodSelected!(widget.selectedMethod, calculation.summary.totalShippingCost);
    }
  }

  void _selectMethod(ShippingMethodType method) async {
    final shippingService = context.read<ShippingService>();
    
    if (shippingService.selectedMethod == method) return;
    
    shippingService.setSelectedMethod(method);
    
    // Calculate for the new method
    final calculation = await shippingService.calculateForCart(
      cartItemIds: _effectiveCartItemIds,
      method: method,
    );
    
    if (widget.onMethodSelected != null) {
      widget.onMethodSelected!(method, calculation.success ? calculation.summary.totalShippingCost : 0.0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currency = widget.currency;
    
    return Consumer<ShippingService>(
      builder: (context, shippingService, _) {
        final comparison = shippingService.comparison;
        final isLoading = shippingService.isLoading || shippingService.isComparing;
        final selectedMethod = shippingService.selectedMethod;
        final hasProcessing = shippingService.hasProcessingItems;
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Air Shipping Option
            _ShippingMethodCard(
              method: ShippingMethodType.air,
              name: 'Air Freight',
              icon: '✈️',
              description: 'Fast delivery by air',
              estimatedDays: '14-21 days',
              cost: comparison?.air.totalCost,
              currency: currency,
              isSelected: selectedMethod == ShippingMethodType.air,
              isLoading: isLoading,
              isCalculated: comparison?.air.allCalculated ?? false,
              hasProcessing: hasProcessing,
              onTap: () => _selectMethod(ShippingMethodType.air),
              isDark: isDark,
            ),
            
            const SizedBox(height: 12),
            
            // Sea Shipping Option
            _ShippingMethodCard(
              method: ShippingMethodType.sea,
              name: 'Sea Freight',
              icon: '🚢',
              description: 'Economical shipping by sea',
              estimatedDays: '45-60 days',
              cost: comparison?.sea.totalCost,
              currency: currency,
              isSelected: selectedMethod == ShippingMethodType.sea,
              isLoading: isLoading,
              isCalculated: comparison?.sea.allCalculated ?? false,
              hasProcessing: hasProcessing,
              onTap: () => _selectMethod(ShippingMethodType.sea),
              isDark: isDark,
            ),
            
            // AI Processing indicator
            if (hasProcessing) ...[
              const SizedBox(height: 12),
              _AiProcessingIndicator(isDark: isDark),
            ],
            
            // Recommendation badge
            if (comparison != null && !isLoading && comparison.allItemsCalculated) ...[
              const SizedBox(height: 12),
              _RecommendationBadge(
                recommended: comparison.recommended,
                airCost: comparison.air.totalCost,
                seaCost: comparison.sea.totalCost,
                isDark: isDark,
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Individual shipping method card
class _ShippingMethodCard extends StatelessWidget {
  final ShippingMethodType method;
  final String name;
  final String icon;
  final String description;
  final String estimatedDays;
  final double? cost;
  final String currency;
  final bool isSelected;
  final bool isLoading;
  final bool isCalculated;
  final bool hasProcessing;
  final VoidCallback onTap;
  final bool isDark;

  const _ShippingMethodCard({
    required this.method,
    required this.name,
    required this.icon,
    required this.description,
    required this.estimatedDays,
    this.cost,
    this.currency = '\$',
    required this.isSelected,
    required this.isLoading,
    required this.isCalculated,
    required this.hasProcessing,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
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
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary500.withOpacity(0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary500.withOpacity(0.15)
                    : (isDark ? Colors.white10 : Colors.grey.shade100),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  icon,
                  style: const TextStyle(fontSize: 24),
                ),
              ),
            ),
            
            const SizedBox(width: 12),
            
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Selected',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Iconsax.clock,
                        size: 12,
                        color: isDark ? Colors.white38 : Colors.grey[500],
                      ),
                      const SizedBox(width: 4),
                      Text(
                        estimatedDays,
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white38 : Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Cost
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (isLoading && cost == null)
                  SizedBox(
                    width: 60,
                    child: LinearProgressIndicator(
                      backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                      color: AppColors.primary500,
                    ),
                  )
                else if (cost != null)
                  Text(
                    '$currency${cost!.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppColors.primary500 : (isDark ? Colors.white : Colors.black87),
                    ),
                  )
                else
                  Text(
                    'Calculating...',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey[500],
                    ),
                  ),
                if (!isCalculated && cost != null && hasProcessing)
                  Text(
                    'Estimating...',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.warning,
                    ),
                  ),
              ],
            ),
            
            const SizedBox(width: 8),
            
            // Radio indicator
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
    );
  }
}

/// AI Processing indicator
class _AiProcessingIndicator extends StatelessWidget {
  final bool isDark;

  const _AiProcessingIndicator({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.info.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.info,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'AI is calculating shipping dimensions for some products...',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.info,
              ),
            ),
          ),
        ],
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 300.ms)
        .then()
        .shimmer(duration: 1500.ms, color: AppColors.info.withOpacity(0.2));
  }
}

/// Recommendation badge
class _RecommendationBadge extends StatelessWidget {
  final String recommended;
  final double airCost;
  final double seaCost;
  final bool isDark;

  const _RecommendationBadge({
    required this.recommended,
    required this.airCost,
    required this.seaCost,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final savings = airCost - seaCost;
    final isSeaCheaper = savings > 0;
    final savingsAmount = savings.abs();
    
    if (savingsAmount < 1) return const SizedBox.shrink(); // Don't show for tiny differences
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.success.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Iconsax.tick_circle,
            size: 16,
            color: AppColors.success,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                children: [
                  TextSpan(
                    text: isSeaCheaper ? 'Sea freight ' : 'Air freight ',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const TextSpan(text: 'saves you '),
                  TextSpan(
                    text: '\$${savingsAmount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.success,
                    ),
                  ),
                  TextSpan(
                    text: isSeaCheaper ? ' but takes longer' : ' and is faster',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0);
  }
}

/// Compact shipping summary for order summary section
class ShippingSummaryRow extends StatelessWidget {
  final bool isDark;
  
  const ShippingSummaryRow({
    super.key,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<ShippingService>(
      builder: (context, shippingService, _) {
        final cost = shippingService.shippingCost;
        final isLoading = shippingService.isLoading;
        final hasProcessing = shippingService.hasProcessingItems;
        final method = shippingService.selectedMethod;
        
        String methodLabel = method == ShippingMethodType.air ? 'Air ✈️' : 'Sea 🚢';
        
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'Shipping ',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary500.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    methodLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary500,
                    ),
                  ),
                ),
              ],
            ),
            if (isLoading)
              SizedBox(
                width: 40,
                height: 12,
                child: LinearProgressIndicator(
                  backgroundColor: isDark ? Colors.white10 : Colors.grey[200],
                  color: AppColors.primary500,
                ),
              )
            else
              Row(
                children: [
                  Text(
                    cost > 0 ? '\$${cost.toStringAsFixed(2)}' : 'Free',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: cost == 0 ? AppColors.success : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (hasProcessing) ...[
                    const SizedBox(width: 4),
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ],
              ),
          ],
        );
      },
    );
  }
}
