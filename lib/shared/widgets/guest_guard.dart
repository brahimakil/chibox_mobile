import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:iconsax/iconsax.dart';
import '../../core/services/auth_service.dart';
import '../../core/theme/theme.dart';
import '../../features/auth/screens/login_screen.dart';

class GuestGuard extends StatelessWidget {
  final Widget child;
  final String featureName;

  const GuestGuard({
    super.key,
    required this.child,
    this.featureName = 'this feature',
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (!authService.isGuest) {
          return child;
        }

        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Lottie.asset(
                  'assets/animations/login_required.json',
                  width: 200,
                  height: 200,
                  repeat: true,
                ),
                const SizedBox(height: 24),
                Text(
                  'Login Required',
                  style: AppTypography.headingMedium(
                    color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Please login or register to access $featureName.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyLarge(
                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Login / Register',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Show login dialog for guest users
void showGuestLoginDialog(BuildContext context, String featureName) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Lottie.asset(
            'assets/animations/login_required.json',
            width: 150,
            height: 150,
            repeat: true,
          ),
          const SizedBox(height: 16),
          Text(
            'Login Required',
            style: AppTypography.headingSmall(
              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please login or register to access $featureName.',
            textAlign: TextAlign.center,
            style: AppTypography.bodyMedium(
              color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary500,
            foregroundColor: Colors.white,
          ),
          child: const Text('Login / Register'),
        ),
      ],
    ),
  );
}
