import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';
import '../loading/skeleton_loader.dart';

/// Category Circle Card
class CategoryCard extends StatefulWidget {
  final int id;
  final String name;
  final String? imageUrl;
  final VoidCallback? onTap;
  final double size;
  final bool isSelected;

  const CategoryCard({
    super.key,
    required this.id,
    required this.name,
    this.imageUrl,
    this.onTap,
    this.size = 72,
    this.isSelected = false,
  });

  @override
  State<CategoryCard> createState() => _CategoryCardState();
}

class _CategoryCardState extends State<CategoryCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        transform: Matrix4.identity()..scale(_isPressed ? 0.95 : 1.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                // Circle Container
                Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: widget.isSelected ? AppColors.primaryGradient : null,
                    color: widget.isSelected
                        ? null
                        : (isDark ? DarkThemeColors.surface : LightThemeColors.surface),
                    border: widget.isSelected
                        ? null
                        : Border.all(
                            color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                            width: 1,
                          ),
                    boxShadow: widget.isSelected ? AppShadows.primarySm : [],
                  ),
                  child: ClipOval(
                    child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: widget.imageUrl!,
                            fit: BoxFit.cover,
                            memCacheWidth: 150, // Small cache for category icons
                            maxWidthDiskCache: 150,
                            placeholder: (_, __) => _CategoryPlaceholder(
                              isDark: isDark,
                              size: widget.size,
                            ),
                            errorWidget: (_, __, ___) => _CategoryPlaceholder(
                              isDark: isDark,
                              size: widget.size,
                              showIcon: true,
                            ),
                          )
                        : _CategoryPlaceholder(
                            isDark: isDark,
                            size: widget.size,
                            showIcon: true,
                          ),
                  ),
                ),
                const SizedBox(height: 4),
                // Category Name
                Text(
                  widget.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: widget.isSelected
                        ? AppTypography.fontWeightSemiBold
                        : AppTypography.fontWeightRegular,
                    color: widget.isSelected
                        ? AppColors.primary500
                        : (isDark ? DarkThemeColors.text : LightThemeColors.text),
                    height: 1.1,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            );
          },
        ),
      ),
    )
        .animate(target: _isPressed ? 1 : 0)
        .scale(
          begin: const Offset(1, 1),
          end: const Offset(0.95, 0.95),
          duration: 100.ms,
        );
  }
}

class _CategoryPlaceholder extends StatelessWidget {
  final bool isDark;
  final double size;
  final bool showIcon;

  const _CategoryPlaceholder({
    required this.isDark,
    required this.size,
    this.showIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: isDark ? AppColors.neutral800 : AppColors.neutral100,
      child: Image.asset(
        'assets/images/category_loadingorfailbak.png',
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return showIcon
              ? Icon(
                  Iconsax.category,
                  size: size * 0.4,
                  color: isDark ? AppColors.neutral600 : AppColors.neutral400,
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }
}

/// Category Chip (alternative style)
class CategoryChip extends StatelessWidget {
  final String name;
  final bool isSelected;
  final VoidCallback? onTap;

  const CategoryChip({
    super.key,
    required this.name,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          gradient: isSelected ? AppColors.primaryGradient : null,
          color: isSelected
              ? null
              : (isDark ? DarkThemeColors.surface : LightThemeColors.surface),
          borderRadius: AppSpacing.borderRadiusFull,
          border: isSelected
              ? null
              : Border.all(
                  color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                ),
          boxShadow: isSelected ? AppShadows.primarySm : null,
        ),
        child: Text(
          name,
          style: AppTypography.labelMedium(
            color: isSelected
                ? Colors.white
                : (isDark ? DarkThemeColors.text : LightThemeColors.text),
          ),
        ),
      ),
    );
  }
}

/// Large Category Card (for grid display)
class CategoryCardLarge extends StatelessWidget {
  final int id;
  final String name;
  final String? imageUrl;
  final int? productsCount;
  final VoidCallback? onTap;

  const CategoryCardLarge({
    super.key,
    required this.id,
    required this.name,
    this.imageUrl,
    this.productsCount,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppSpacing.borderRadiusLg,
          boxShadow: AppShadows.md,
        ),
        child: ClipRRect(
          borderRadius: AppSpacing.borderRadiusLg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              if (imageUrl != null && imageUrl!.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Image.asset(
                    'assets/images/category_loadingorfailbak.png',
                    fit: BoxFit.cover,
                  ),
                  errorWidget: (_, __, ___) => Image.asset(
                    'assets/images/category_loadingorfailbak.png',
                    fit: BoxFit.cover,
                  ),
                )
              else
                Image.asset(
                  'assets/images/category_loadingorfailbak.png',
                  fit: BoxFit.cover,
                ),

              // Gradient Overlay
              Container(
                decoration: const BoxDecoration(
                  gradient: AppColors.darkOverlay,
                ),
              ),

              // Content
              Positioned(
                left: AppSpacing.base,
                right: AppSpacing.base,
                bottom: AppSpacing.base,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: AppTypography.headingSmall(color: Colors.white),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (productsCount != null) ...[
                      AppSpacing.verticalXs,
                      Text(
                        '$productsCount products',
                        style: AppTypography.caption(color: Colors.white70),
                      ),
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

