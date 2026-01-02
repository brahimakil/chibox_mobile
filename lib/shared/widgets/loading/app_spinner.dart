import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/theme.dart';

/// Spinner sizes
enum SpinnerSize { small, medium, large }

/// App Spinner - Loading indicator
class AppSpinner extends StatelessWidget {
  final SpinnerSize size;
  final Color? color;
  final double? strokeWidth;

  const AppSpinner({
    super.key,
    this.size = SpinnerSize.medium,
    this.color,
    this.strokeWidth,
  });

  double get _size {
    switch (size) {
      case SpinnerSize.small:
        return 20;
      case SpinnerSize.medium:
        return 32;
      case SpinnerSize.large:
        return 48;
    }
  }

  double get _strokeWidth {
    return strokeWidth ?? (size == SpinnerSize.small ? 2 : 3);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: _size,
      height: _size,
      child: CircularProgressIndicator(
        strokeWidth: _strokeWidth,
        valueColor: AlwaysStoppedAnimation<Color>(
          color ?? AppColors.primary500,
        ),
      ),
    );
  }
}

/// Full page loading overlay
class LoadingOverlay extends StatelessWidget {
  final String? message;
  final bool isTransparent;

  const LoadingOverlay({
    super.key,
    this.message,
    this.isTransparent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isTransparent
          ? Colors.black.withOpacity(0.3)
          : (isDark ? DarkThemeColors.background : LightThemeColors.background),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const AppSpinner(size: SpinnerSize.large)
                .animate(onPlay: (c) => c.repeat())
                .rotate(duration: 1000.ms),
            if (message != null) ...[
              AppSpacing.verticalBase,
              Text(
                message!,
                style: AppTypography.bodyMedium(
                  color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Pulsing dot loader
class PulsingDots extends StatelessWidget {
  final Color? color;
  final double size;

  const PulsingDots({
    super.key,
    this.color,
    this.size = 10,
  });

  @override
  Widget build(BuildContext context) {
    final dotColor = color ?? AppColors.primary500;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return Container(
          margin: EdgeInsets.symmetric(horizontal: size / 4),
          child: _Dot(color: dotColor, size: size)
              .animate(
                onPlay: (c) => c.repeat(),
                delay: Duration(milliseconds: index * 200),
              )
              .scale(
                begin: const Offset(1, 1),
                end: const Offset(1.3, 1.3),
                duration: 400.ms,
              )
              .then()
              .scale(
                begin: const Offset(1.3, 1.3),
                end: const Offset(1, 1),
                duration: 400.ms,
              ),
        );
      }),
    );
  }
}

class _Dot extends StatelessWidget {
  final Color color;
  final double size;

  const _Dot({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Shimmer loading effect
class ShimmerLoading extends StatelessWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const ShimmerLoading({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBase,
        borderRadius: borderRadius ?? AppSpacing.borderRadiusMd,
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1200.ms,
          color: isDark
              ? AppColors.shimmerHighlightDark.withOpacity(0.3)
              : AppColors.shimmerHighlight.withOpacity(0.5),
        );
  }
}

