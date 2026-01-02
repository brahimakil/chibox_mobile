import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/theme.dart';

/// Base skeleton component
class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final BorderRadius? borderRadius;
  final bool isCircle;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.borderRadius,
    this.isCircle = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final baseColor = isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBase;
    final highlightColor = isDark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlight;

    return Container(
      width: isCircle ? height : width,
      height: height,
      decoration: BoxDecoration(
        color: baseColor,
        borderRadius: isCircle ? null : (borderRadius ?? AppSpacing.borderRadiusMd),
        shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1500.ms,
          color: highlightColor.withOpacity(isDark ? 0.15 : 0.4),
        );
  }
}

/// Product card skeleton
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        borderRadius: AppSpacing.borderRadiusBase,
        border: Border.all(
          color: isDark ? DarkThemeColors.border : LightThemeColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton
          const AspectRatio(
            aspectRatio: 1,
            child: SkeletonBox(
              height: double.infinity,
              width: double.infinity,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(AppSpacing.radiusBase),
                topRight: Radius.circular(AppSpacing.radiusBase),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                const SkeletonBox(height: 16, width: 120),
                AppSpacing.verticalSm,
                // Subtitle skeleton
                const SkeletonBox(height: 12, width: 80),
                AppSpacing.verticalSm,
                // Price skeleton
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SkeletonBox(height: 20, width: 60),
                    SkeletonBox(height: 32, width: 32, borderRadius: AppSpacing.borderRadiusFull),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Category circle skeleton
class CategorySkeleton extends StatelessWidget {
  const CategorySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SkeletonBox(height: 64, isCircle: true),
        AppSpacing.verticalSm,
        const SkeletonBox(height: 12, width: 50),
      ],
    );
  }
}

/// Banner/carousel skeleton
class BannerSkeleton extends StatelessWidget {
  final double height;

  const BannerSkeleton({super.key, this.height = 180});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingHorizontalBase,
      child: SkeletonBox(
        height: height,
        borderRadius: AppSpacing.borderRadiusLg,
      ),
    );
  }
}

/// Section header skeleton
class SectionHeaderSkeleton extends StatelessWidget {
  const SectionHeaderSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: AppSpacing.paddingHorizontalBase,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SkeletonBox(height: 20, width: 140),
          SkeletonBox(height: 16, width: 60, borderRadius: AppSpacing.borderRadiusFull),
        ],
      ),
    );
  }
}

/// Product list skeleton (horizontal)
class ProductListSkeleton extends StatelessWidget {
  final int count;
  final double itemWidth;

  const ProductListSkeleton({
    super.key,
    this.count = 4,
    this.itemWidth = 160,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 260,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.paddingHorizontalBase,
        itemCount: count,
        separatorBuilder: (_, __) => AppSpacing.horizontalMd,
        itemBuilder: (_, __) => SizedBox(
          width: itemWidth,
          child: const ProductCardSkeleton(),
        ),
      ),
    );
  }
}

/// Categories row skeleton
class CategoriesRowSkeleton extends StatelessWidget {
  final int count;

  const CategoriesRowSkeleton({super.key, this.count = 5});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: AppSpacing.paddingHorizontalBase,
        itemCount: count,
        separatorBuilder: (_, __) => AppSpacing.horizontalLg,
        itemBuilder: (_, __) => const CategorySkeleton(),
      ),
    );
  }
}

/// Home screen full skeleton
class HomeScreenSkeleton extends StatelessWidget {
  const HomeScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppSpacing.verticalBase,
          // Banner skeleton
          const BannerSkeleton(height: 180),
          AppSpacing.verticalXl,
          
          // Categories section
          const SectionHeaderSkeleton(),
          AppSpacing.verticalMd,
          const CategoriesRowSkeleton(),
          AppSpacing.verticalXl,
          
          // Product section 1
          const SectionHeaderSkeleton(),
          AppSpacing.verticalMd,
          const ProductListSkeleton(),
          AppSpacing.verticalXl,
          
          // Banner/Ad skeleton
          const BannerSkeleton(height: 120),
          AppSpacing.verticalXl,
          
          // Product section 2
          const SectionHeaderSkeleton(),
          AppSpacing.verticalMd,
          const ProductListSkeleton(),
        ],
      ),
    );
  }
}

/// Text skeleton with lines
class TextSkeleton extends StatelessWidget {
  final int lines;
  final double lineHeight;
  final double lastLineWidth;

  const TextSkeleton({
    super.key,
    this.lines = 3,
    this.lineHeight = 14,
    this.lastLineWidth = 0.6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(lines, (index) {
        final isLast = index == lines - 1;
        return Padding(
          padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.sm),
          child: SkeletonBox(
            height: lineHeight,
            width: isLast ? MediaQuery.of(context).size.width * lastLineWidth : null,
          ),
        );
      }),
    );
  }
}

