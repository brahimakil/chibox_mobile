import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/theme.dart';

/// Button variants
enum AppButtonVariant {
  primary,
  secondary,
  outline,
  ghost,
  danger,
}

/// Button sizes
enum AppButtonSize {
  small,
  medium,
  large,
}

/// Reusable App Button with multiple variants
class AppButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final AppButtonVariant variant;
  final AppButtonSize size;
  final bool isLoading;
  final bool isDisabled;
  final IconData? leftIcon;
  final IconData? rightIcon;
  final double? width;
  final bool fullWidth;

  const AppButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AppButtonVariant.primary,
    this.size = AppButtonSize.medium,
    this.isLoading = false,
    this.isDisabled = false,
    this.leftIcon,
    this.rightIcon,
    this.width,
    this.fullWidth = true,
  });

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  bool _isPressed = false;

  double get _height {
    switch (widget.size) {
      case AppButtonSize.small:
        return AppSpacing.buttonSmall;
      case AppButtonSize.medium:
        return AppSpacing.buttonMedium;
      case AppButtonSize.large:
        return AppSpacing.buttonLarge;
    }
  }

  double get _iconSize {
    switch (widget.size) {
      case AppButtonSize.small:
        return 16;
      case AppButtonSize.medium:
        return 20;
      case AppButtonSize.large:
        return 24;
    }
  }

  double get _fontSize {
    switch (widget.size) {
      case AppButtonSize.small:
        return AppTypography.fontSizeSm;
      case AppButtonSize.medium:
        return AppTypography.fontSizeBase;
      case AppButtonSize.large:
        return AppTypography.fontSizeMd;
    }
  }

  EdgeInsets get _padding {
    switch (widget.size) {
      case AppButtonSize.small:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.md);
      case AppButtonSize.medium:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.lg);
      case AppButtonSize.large:
        return const EdgeInsets.symmetric(horizontal: AppSpacing.xl);
    }
  }

  Color _getBackgroundColor(bool isDark) {
    if (widget.isDisabled || widget.isLoading) {
      return isDark ? AppColors.neutral700 : AppColors.neutral200;
    }
    
    switch (widget.variant) {
      case AppButtonVariant.primary:
        return _isPressed ? AppColors.primary600 : AppColors.primary500;
      case AppButtonVariant.secondary:
        return _isPressed
            ? (isDark ? AppColors.neutral700 : AppColors.neutral200)
            : (isDark ? AppColors.neutral800 : AppColors.neutral100);
      case AppButtonVariant.outline:
      case AppButtonVariant.ghost:
        return _isPressed
            ? (isDark ? AppColors.neutral800 : AppColors.neutral100)
            : Colors.transparent;
      case AppButtonVariant.danger:
        return _isPressed ? const Color(0xFFDC2626) : AppColors.error;
    }
  }

  Color _getTextColor(bool isDark) {
    if (widget.isDisabled || widget.isLoading) {
      return isDark ? AppColors.neutral500 : AppColors.neutral400;
    }
    
    switch (widget.variant) {
      case AppButtonVariant.primary:
      case AppButtonVariant.danger:
        return AppColors.neutral0;
      case AppButtonVariant.secondary:
        return isDark ? AppColors.neutral100 : AppColors.neutral800;
      case AppButtonVariant.outline:
        return AppColors.primary500;
      case AppButtonVariant.ghost:
        return isDark ? AppColors.neutral100 : AppColors.neutral700;
    }
  }

  BorderSide? _getBorder(bool isDark) {
    if (widget.variant == AppButtonVariant.outline) {
      final color = widget.isDisabled
          ? (isDark ? AppColors.neutral700 : AppColors.neutral300)
          : AppColors.primary500;
      return BorderSide(color: color, width: 1.5);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = _getBackgroundColor(isDark);
    final textColor = _getTextColor(isDark);
    final border = _getBorder(isDark);

    return GestureDetector(
      onTapDown: widget.isDisabled || widget.isLoading
          ? null
          : (_) => setState(() => _isPressed = true),
      onTapUp: widget.isDisabled || widget.isLoading
          ? null
          : (_) => setState(() => _isPressed = false),
      onTapCancel: widget.isDisabled || widget.isLoading
          ? null
          : () => setState(() => _isPressed = false),
      onTap: widget.isDisabled || widget.isLoading ? null : widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: widget.fullWidth ? double.infinity : widget.width,
        height: _height,
        padding: _padding,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: AppSpacing.borderRadiusBase,
          border: border != null ? Border.fromBorderSide(border) : null,
          boxShadow: widget.variant == AppButtonVariant.primary && !widget.isDisabled
              ? AppShadows.primarySm
              : null,
        ),
        child: Row(
          mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.isLoading) ...[
              SizedBox(
                width: _iconSize,
                height: _iconSize,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(textColor),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ] else if (widget.leftIcon != null) ...[
              Icon(widget.leftIcon, size: _iconSize, color: textColor),
              const SizedBox(width: AppSpacing.sm),
            ],
            Text(
              widget.text,
              style: TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: _fontSize,
                fontWeight: AppTypography.fontWeightSemiBold,
                color: textColor,
              ),
            ),
            if (widget.rightIcon != null && !widget.isLoading) ...[
              const SizedBox(width: AppSpacing.sm),
              Icon(widget.rightIcon, size: _iconSize, color: textColor),
            ],
          ],
        ),
      ),
    ).animate(target: _isPressed ? 1 : 0).scale(
      begin: const Offset(1, 1),
      end: const Offset(0.98, 0.98),
      duration: 100.ms,
    );
  }
}

/// Icon Button
class AppIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? backgroundColor;
  final bool hasBadge;
  final int? badgeCount;

  const AppIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 24,
    this.color,
    this.backgroundColor,
    this.hasBadge = false,
    this.badgeCount,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = color ?? (isDark ? AppColors.neutral100 : AppColors.neutral700);
    
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: backgroundColor ?? Colors.transparent,
          borderRadius: AppSpacing.borderRadiusFull,
          child: InkWell(
            onTap: onPressed,
            borderRadius: AppSpacing.borderRadiusFull,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.sm),
              child: Icon(icon, size: size, color: iconColor),
            ),
          ),
        ),
        if (hasBadge)
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(badgeCount != null ? 4 : 3),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: badgeCount != null
                  ? Text(
                      badgeCount! > 99 ? '99+' : badgeCount.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    )
                  : null,
            ),
          ),
      ],
    );
  }
}

