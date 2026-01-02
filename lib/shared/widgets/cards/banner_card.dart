import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';
import '../loading/skeleton_loader.dart';
import '../buttons/app_button.dart';

/// Promotional Banner Card
class BannerCard extends StatelessWidget {
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? buttonText;
  final VoidCallback? onTap;
  final VoidCallback? onButtonTap;
  final double height;
  final BorderRadius? borderRadius;

  const BannerCard({
    super.key,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.buttonText,
    this.onTap,
    this.onButtonTap,
    this.height = 220,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: borderRadius ?? BorderRadius.circular(20),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonBox(height: double.infinity),
                      errorWidget: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: AppColors.primaryGradient,
                        ),
                        child: const Center(
                          child: Icon(Icons.image_not_supported, color: Colors.white54),
                        ),
                      ),
                    )
                  : Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                      child: const Center(
                        child: Icon(Icons.image_not_supported, color: Colors.white54),
                      ),
                    ),

              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withOpacity(0.8),
                      Colors.black.withOpacity(0.4),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.6, 1.0],
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (subtitle != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: Colors.white.withOpacity(0.3)),
                        ),
                        child: Text(
                          subtitle!.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 1.2,
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 100.ms)
                          .slideX(begin: -0.2, end: 0),
                    
                    if (title != null) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.65,
                        child: Text(
                          title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            height: 1.1,
                            letterSpacing: -0.5,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 200.ms)
                          .slideX(begin: -0.2, end: 0),
                    ],

                    if (buttonText != null) ...[
                      const SizedBox(height: 16),
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        child: InkWell(
                          onTap: onButtonTap ?? onTap,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  buttonText!,
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.black),
                              ],
                            ),
                          ),
                        ),
                      )
                          .animate()
                          .fadeIn(delay: 300.ms)
                          .slideX(begin: -0.2, end: 0),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Product Ad Banner (between sections)
class ProductAdBanner extends StatelessWidget {
  final int productId;
  final String productName;
  final String imageUrl;
  final double price;
  final double? originalPrice;
  final String currencySymbol;
  final VoidCallback? onTap;

  const ProductAdBanner({
    super.key,
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.price,
    this.originalPrice,
    this.currencySymbol = '\$',
    this.onTap,
  });

  double? get _discount {
    if (originalPrice != null && originalPrice! > price) {
      return ((originalPrice! - price) / originalPrice! * 100);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discount = _discount;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: AppSpacing.paddingHorizontalBase,
        padding: const EdgeInsets.all(AppSpacing.base),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppColors.primary900, AppColors.primary950]
                : [AppColors.primary50, AppColors.primary100],
          ),
          borderRadius: AppSpacing.borderRadiusLg,
          boxShadow: AppShadows.md,
        ),
        child: Row(
          children: [
            // Product Image
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusMd,
              child: imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 100,
                      height: 100,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonBox(height: 100, width: 100),
                      errorWidget: (_, __, ___) => Container(
                        width: 100,
                        height: 100,
                        color: isDark ? AppColors.neutral800 : AppColors.neutral200,
                      ),
                    )
                  : Container(
                      width: 100,
                      height: 100,
                      color: isDark ? AppColors.neutral800 : AppColors.neutral200,
                      child: Icon(
                        Iconsax.image,
                        color: isDark ? AppColors.neutral600 : AppColors.neutral400,
                      ),
                    ),
            ),
            AppSpacing.horizontalBase,

            // Product Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (discount != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.error,
                        borderRadius: AppSpacing.borderRadiusSm,
                      ),
                      child: Text(
                        '${discount.round()}% OFF',
                        style: AppTypography.labelSmall(color: Colors.white),
                      ),
                    ),
                  if (discount != null) AppSpacing.verticalSm,
                  Text(
                    productName,
                    style: AppTypography.bodyLarge(
                      color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.verticalSm,
                  Row(
                    children: [
                      Text(
                        '$currencySymbol${price.toStringAsFixed(2)}',
                        style: AppTypography.priceLarge(),
                      ),
                      if (originalPrice != null) ...[
                        AppSpacing.horizontalSm,
                        Text(
                          '$currencySymbol${originalPrice!.toStringAsFixed(2)}',
                          style: AppTypography.priceStrikethrough(),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.primary500,
                borderRadius: AppSpacing.borderRadiusFull,
              ),
              child: const Icon(
                Icons.arrow_forward,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn()
        .scale(begin: const Offset(0.95, 0.95), end: const Offset(1, 1));
  }
}

/// Hero Banner with parallax effect
class HeroBanner extends StatelessWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final String? buttonText;
  final VoidCallback? onButtonTap;
  final double height;

  const HeroBanner({
    super.key,
    required this.imageUrl,
    required this.title,
    this.subtitle,
    this.buttonText,
    this.onButtonTap,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: double.infinity,
      margin: AppSpacing.paddingHorizontalBase,
      decoration: BoxDecoration(
        borderRadius: AppSpacing.borderRadiusXl,
        boxShadow: AppShadows.lg,
      ),
      child: ClipRRect(
        borderRadius: AppSpacing.borderRadiusXl,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Image
            imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                    errorWidget: (_, __, ___) => Container(
                      decoration: const BoxDecoration(
                        gradient: AppColors.primaryGradient,
                      ),
                    ),
                  )
                : Container(
                    decoration: const BoxDecoration(
                      gradient: AppColors.primaryGradient,
                    ),
                  ),

            // Gradient Overlay
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Color(0x40000000),
                    Color(0x99000000),
                  ],
                ),
              ),
            ),

            // Content
            Positioned(
              left: AppSpacing.xl,
              right: AppSpacing.xl,
              bottom: AppSpacing.xl,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (subtitle != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: AppSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.secondary500,
                        borderRadius: AppSpacing.borderRadiusSm,
                      ),
                      child: Text(
                        subtitle!,
                        style: AppTypography.labelSmall(color: Colors.white),
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 100.ms)
                        .slideY(begin: 0.3, end: 0),
                  if (subtitle != null) AppSpacing.verticalSm,
                  Text(
                    title,
                    style: AppTypography.displaySmall(color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                      .animate()
                      .fadeIn(delay: 200.ms)
                      .slideY(begin: 0.3, end: 0),
                  if (buttonText != null) ...[
                    AppSpacing.verticalMd,
                    AppButton(
                      text: buttonText!,
                      variant: AppButtonVariant.primary,
                      size: AppButtonSize.medium,
                      fullWidth: false,
                      onPressed: onButtonTap,
                    )
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.3, end: 0),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

