import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/models/shipping_model.dart';
import '../../../core/theme/theme.dart';

/// Simple Shipping Method Selector
/// Just two buttons: Air ✈️ or Sea 🚢
/// No polling, no API calls - just UI selection
class SimpleShippingSelector extends StatelessWidget {
  final ShippingMethodType selectedMethod;
  final ValueChanged<ShippingMethodType> onMethodSelected;
  final bool isEnabled;

  const SimpleShippingSelector({
    super.key,
    required this.selectedMethod,
    required this.onMethodSelected,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info text
          Row(
            children: [
              Icon(
                Iconsax.info_circle,
                size: 16,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Choose your preferred shipping method',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white60 : Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Two buttons side by side
          Row(
            children: [
              // Air Shipping
              Expanded(
                child: _ShippingOption(
                  icon: '✈️',
                  label: 'Air Freight',
                  subtitle: '7-14 days',
                  isSelected: selectedMethod == ShippingMethodType.air,
                  onTap: isEnabled ? () => onMethodSelected(ShippingMethodType.air) : null,
                  isDark: isDark,
                  color: Colors.blue,
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Sea Shipping
              Expanded(
                child: _ShippingOption(
                  icon: '🚢',
                  label: 'Sea Freight',
                  subtitle: '30-45 days',
                  isSelected: selectedMethod == ShippingMethodType.sea,
                  onTap: isEnabled ? () => onMethodSelected(ShippingMethodType.sea) : null,
                  isDark: isDark,
                  color: Colors.teal,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Note about shipping cost
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary500.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Iconsax.truck_fast,
                  size: 18,
                  color: AppColors.primary500,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Shipping cost will be calculated based on product weight and dimensions',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms);
  }
}

class _ShippingOption extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool isDark;
  final Color color;

  const _ShippingOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected 
              ? color.withOpacity(0.1) 
              : (isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? color : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            // Icon
            Text(
              icon,
              style: const TextStyle(fontSize: 32),
            ),
            
            const SizedBox(height: 8),
            
            // Label
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : (isDark ? Colors.white : Colors.black87),
              ),
            ),
            
            const SizedBox(height: 4),
            
            // Subtitle
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Checkmark
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? color : (isDark ? Colors.white30 : Colors.grey.shade400),
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
