import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/security_service.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/guest_guard.dart';
import '../../address/screens/address_list_screen.dart';
import 'edit_profile_screen.dart';
import 'security_settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _handleProtectedAction(BuildContext context, AuthService authService, String featureName, VoidCallback action) {
    if (authService.isGuest) {
      showGuestLoginDialog(context, featureName);
    } else {
      action();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = context.watch<AuthService>();
    final user = authService.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingHorizontalBase,
          child: Column(
            children: [
              AppSpacing.verticalLg,
              
              // Profile Header
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [AppColors.primary900, AppColors.primary950]
                        : [AppColors.primary50, AppColors.primary100],
                  ),
                  borderRadius: AppSpacing.borderRadiusXl,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.primarySm,
                      ),
                      child: user?.mainImage != null
                          ? ClipOval(
                              child: Image.network(
                                user!.mainImage!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => _buildInitials(user.fullName, isDark),
                              ),
                            )
                          : _buildInitials(user?.fullName ?? 'Guest', isDark),
                    ),
                    AppSpacing.horizontalBase,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user?.fullName ?? 'Guest User',
                            style: AppTypography.headingSmall(
                              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                            ),
                          ),
                          AppSpacing.verticalXs,
                          Text(
                            user?.email ?? user?.phone ?? (authService.isGuest ? 'Guest Account' : 'Sign in to continue'),
                            style: AppTypography.bodySmall(
                              color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!authService.isGuest)
                      IconButton(
                        icon: Icon(
                          Iconsax.edit_2,
                          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                          );
                        },
                      ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn()
                  .slideY(begin: 0.1, end: 0),
              AppSpacing.verticalXl,

              // Menu Sections
              _MenuSection(
                title: 'My Account',
                items: [
                  _MenuItem(
                    icon: Iconsax.box, 
                    title: 'My Orders', 
                    onTap: () => _handleProtectedAction(context, authService, 'My Orders', () {}),
                  ),
                  _MenuItem(
                    icon: Iconsax.location, 
                    title: 'Addresses', 
                    onTap: () => _handleProtectedAction(context, authService, 'Addresses', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddressListScreen()),
                      );
                    }),
                  ),
                  _MenuItem(
                    icon: Iconsax.card, 
                    title: 'Payment Methods', 
                    onTap: () => _handleProtectedAction(context, authService, 'Payment Methods', () {}),
                  ),
                  _MenuItem(
                    icon: Iconsax.notification, 
                    title: 'Notifications', 
                    onTap: () => _handleProtectedAction(context, authService, 'Notifications', () {}),
                  ),
                ],
              )
                  .animate()
                  .fadeIn(delay: 100.ms)
                  .slideX(begin: -0.1, end: 0),
              AppSpacing.verticalBase,

              _MenuSection(
                title: 'Preferences',
                items: [
                  _MenuItem(
                    icon: Iconsax.shield_security,
                    title: 'Security',
                    onTap: () => _handleProtectedAction(context, authService, 'Security', () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SecuritySettingsScreen()),
                      );
                    }),
                  ),
                  _MenuItemSwitch(icon: Iconsax.moon, title: 'Dark Mode', value: isDark, onChanged: (value) {
                    context.read<ThemeProvider>().toggleTheme();
                  }),
                ],
              )
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideX(begin: -0.1, end: 0),
              AppSpacing.verticalBase,

              _MenuSection(
                title: 'Support',
                items: [
                  _MenuItem(icon: Iconsax.message_question, title: 'Help Center', onTap: () {}),
                  _MenuItem(icon: Iconsax.message, title: 'Contact Us', onTap: () {}),
                  _MenuItem(icon: Iconsax.info_circle, title: 'About', onTap: () {}),
                ],
              )
                  .animate()
                  .fadeIn(delay: 300.ms)
                  .slideX(begin: -0.1, end: 0),
              AppSpacing.verticalXl,

              // Login/Logout Section
              if (authService.isGuest) ...[
                GestureDetector(
                  onTap: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    decoration: BoxDecoration(
                      color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                      borderRadius: AppSpacing.borderRadiusBase,
                      border: Border.all(color: AppColors.primary500),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.login, color: AppColors.primary500),
                        AppSpacing.horizontalMd,
                        Text(
                          'Login / Register',
                          style: AppTypography.labelLarge(color: AppColors.primary500),
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 400.ms),
              ] else ...[
                // Logout Button
                GestureDetector(
                  onTap: () => _handleLogout(context, authService),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    decoration: BoxDecoration(
                      color: AppColors.errorLight,
                      borderRadius: AppSpacing.borderRadiusBase,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.logout, color: AppColors.error),
                        AppSpacing.horizontalMd,
                        Text(
                          'Log Out',
                          style: AppTypography.labelLarge(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms),
                AppSpacing.verticalBase,
                
                // Delete Account Button
                GestureDetector(
                  onTap: () => _handleDeleteAccount(context, authService),
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.base),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.error),
                      borderRadius: AppSpacing.borderRadiusBase,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Iconsax.trash, color: AppColors.error),
                        AppSpacing.horizontalMd,
                        Text(
                          'Delete Account',
                          style: AppTypography.labelLarge(color: AppColors.error),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 450.ms),
              ],
              AppSpacing.verticalXxl,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInitials(String name, bool isDark) {
    final initials = name.split(' ').map((n) => n.isNotEmpty ? n[0] : '').take(2).join().toUpperCase();
    return Center(
      child: Text(
        initials.isNotEmpty ? initials : 'G',
        style: AppTypography.headingMedium(color: Colors.white),
      ),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthService authService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log Out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Log Out', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Remove PIN and security settings on logout
      if (context.mounted) {
        await context.read<SecurityService>().removePin();
      }
      await authService.logout();
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context, AuthService authService) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final response = await authService.deleteAccount();
      if (context.mounted) {
        if (response.success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.message ?? 'Failed to delete account')),
          );
        }
      }
    }
  }
}

class _MenuSection extends StatelessWidget {
  final String title;
  final List<Widget> items;

  const _MenuSection({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.labelMedium(
            color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
          ),
        ),
        AppSpacing.verticalSm,
        Container(
          decoration: BoxDecoration(
            color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
            borderRadius: AppSpacing.borderRadiusBase,
            border: Border.all(
              color: isDark ? DarkThemeColors.border : LightThemeColors.border,
            ),
          ),
          child: Column(children: items),
        ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? trailing;
  final VoidCallback onTap;

  const _MenuItem({
    required this.icon,
    required this.title,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium(
          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (trailing != null)
            Text(
              trailing!,
              style: AppTypography.bodySmall(
                color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
              ),
            ),
          AppSpacing.horizontalSm,
          Icon(
            Icons.arrow_forward_ios,
            size: 14,
            color: isDark ? AppColors.neutral600 : AppColors.neutral400,
          ),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _MenuItemSwitch extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _MenuItemSwitch({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      leading: Icon(
        icon,
        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
        size: 22,
      ),
      title: Text(
        title,
        style: AppTypography.bodyMedium(
          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
        ),
      ),
      trailing: Switch.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.primary500,
      ),
    );
  }
}

