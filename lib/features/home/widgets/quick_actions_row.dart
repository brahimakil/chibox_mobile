import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';

/// SHEIN-style Quick Actions Row - displays 4 shortcut buttons
/// (similar to Logistics, Wallet, Tracking, Club Cards)
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.5) 
                : Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _QuickActionItem(
            icon: Iconsax.truck_fast,
            label: 'Orders',
            isDark: isDark,
            onTap: () {
              // TODO: Navigate to orders
            },
          ),
          _buildDivider(isDark),
          _QuickActionItem(
            icon: Iconsax.card,
            label: 'Payments',
            isDark: isDark,
            onTap: () {
              // TODO: Navigate to payments
            },
          ),
          _buildDivider(isDark),
          _QuickActionItem(
            icon: Iconsax.location,
            label: 'Addresses',
            isDark: isDark,
            onTap: () {
              // TODO: Navigate to addresses
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 40,
      color: isDark ? Colors.white10 : Colors.black.withOpacity(0.08),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primary500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                size: 22,
                color: AppColors.primary500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
