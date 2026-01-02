import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';

class DiscoverScreen extends StatelessWidget {
  const DiscoverScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.base,
                  vertical: AppSpacing.md,
                ),
                decoration: BoxDecoration(
                  color: isDark ? DarkThemeColors.inputBackground : LightThemeColors.inputBackground,
                  borderRadius: AppSpacing.borderRadiusFull,
                  border: Border.all(
                    color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Iconsax.search_normal,
                      color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                      size: 20,
                    ),
                    AppSpacing.horizontalMd,
                    Expanded(
                      child: Text(
                        'Search products, brands, categories...',
                        style: AppTypography.bodyMedium(
                          color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                        ),
                      ),
                    ),
                    Icon(
                      Iconsax.camera,
                      color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                      size: 20,
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn()
                  .slideY(begin: -0.2, end: 0),
            ),

            // Placeholder Content
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.primary900.withOpacity(0.3) : AppColors.primary50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Iconsax.search_favorite,
                        size: 56,
                        color: AppColors.primary500,
                      ),
                    )
                        .animate()
                        .scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut),
                    AppSpacing.verticalXl,
                    Text(
                      'Discover Products',
                      style: AppTypography.headingMedium(
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms),
                    AppSpacing.verticalSm,
                    Padding(
                      padding: AppSpacing.paddingHorizontalBase,
                      child: Text(
                        'Search for products, browse categories, and find your next favorite item.',
                        style: AppTypography.bodyMedium(
                          color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 400.ms),
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

