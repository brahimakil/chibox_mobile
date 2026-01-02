import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';

/// Error State Widget for Home Screen
class HomeErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const HomeErrorState({
    super.key,
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingHorizontalBase,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? AppColors.error.withOpacity(0.15) : AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.wifi_square,
                size: 48,
                color: AppColors.error,
              ),
            )
                .animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut),
            AppSpacing.verticalXl,
            Text(
              'Oops! Something went wrong',
              style: AppTypography.headingMedium(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 200.ms),
            AppSpacing.verticalSm,
            Text(
              'Server error. Please try again later.',
              style: AppTypography.bodyMedium(
                color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            )
                .animate()
                .fadeIn(delay: 300.ms),
            AppSpacing.verticalXxl,
            AppButton(
              text: 'Try Again',
              onPressed: onRetry,
              leftIcon: Iconsax.refresh,
              fullWidth: false,
            )
                .animate()
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
  }
}
