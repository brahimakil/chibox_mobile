import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/guest_guard.dart';
import '../../address/screens/address_list_screen.dart';
import '../../orders/screens/orders_list_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../invoices/screens/invoices_list_screen.dart';

/// SHEIN-style Quick Actions Row - displays 3 shortcut buttons
class QuickActionsRow extends StatelessWidget {
  const QuickActionsRow({super.key});

  void _handleProtectedAction(BuildContext context, String featureName, VoidCallback action) {
    final authService = context.read<AuthService>();
    if (authService.isGuest) {
      showGuestLoginDialog(context, featureName);
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.5) 
                : Colors.black.withOpacity(0.10),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
              _handleProtectedAction(context, 'Orders', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrdersListScreen()),
                );
              });
            },
          ),
          _buildDivider(isDark),
          _QuickActionItem(
            icon: Iconsax.notification,
            label: 'Notifications',
            isDark: isDark,
            onTap: () {
              _handleProtectedAction(context, 'Notifications', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                );
              });
            },
          ),
          _buildDivider(isDark),
          _QuickActionItem(
            icon: Iconsax.location,
            label: 'Addresses',
            isDark: isDark,
            onTap: () {
              _handleProtectedAction(context, 'Addresses', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressListScreen()),
                );
              });
            },
          ),
          _buildDivider(isDark),
          _QuickActionItem(
            icon: Iconsax.receipt,
            label: 'Invoices',
            isDark: isDark,
            onTap: () {
              _handleProtectedAction(context, 'Invoices', () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InvoicesListScreen()),
                );
              });
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildDivider(bool isDark) {
    return Container(
      width: 1,
      height: 32,
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
        width: 60,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 18,
                color: AppColors.primary500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
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
