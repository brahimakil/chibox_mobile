import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/theme.dart';

/// Section Header Widget with title and optional action
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionText;
  final VoidCallback? onActionTap;
  final IconData? actionIcon;
  final bool animate;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText,
    this.onActionTap,
    this.actionIcon,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final content = Padding(
      padding: AppSpacing.paddingHorizontalBase,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              title,
              style: AppTypography.headingMedium(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (actionText != null || actionIcon != null)
            SectionAction(
              text: actionText,
              icon: actionIcon,
              onTap: onActionTap,
            ),
        ],
      ),
    );

    if (!animate) return content;

    return content
        .animate()
        .fadeIn(duration: 400.ms)
        .slideX(begin: -0.1, end: 0, duration: 400.ms);
  }
}

/// Standard Action Button for Sections
class SectionAction extends StatelessWidget {
  final String? text;
  final IconData? icon;
  final VoidCallback? onTap;
  final Color? color;

  const SectionAction({
    super.key,
    this.text,
    this.icon,
    this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    // Use provided color or default to primary
    // Note: AppColors.primary600 is used for text/icon in original implementation
    final baseColor = color ?? AppColors.primary600;
    final bgColor = color ?? AppColors.primary500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: bgColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: bgColor.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (text != null)
              Text(
                text!,
                style: AppTypography.labelMedium(
                  color: baseColor,
                ).copyWith(fontWeight: FontWeight.w600),
              ),
            if (icon != null) ...[
              if (text != null) const SizedBox(width: 4),
              Icon(
                icon,
                size: 16,
                color: baseColor,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Animated Section Title (larger, more prominent)
class AnimatedSectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AnimatedSectionTitle({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: AppSpacing.paddingHorizontalBase,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTypography.labelSmall(
                      color: AppColors.secondary500,
                    ),
                  )
                      .animate()
                      .fadeIn(delay: 100.ms)
                      .slideY(begin: 0.3, end: 0),
                if (subtitle != null) AppSpacing.verticalXs,
                Text(
                  title,
                  style: AppTypography.headingLarge(
                    color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.3, end: 0),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

/// Divider with label
class LabeledDivider extends StatelessWidget {
  final String label;

  const LabeledDivider({
    super.key,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dividerColor = isDark ? DarkThemeColors.divider : LightThemeColors.divider;

    return Padding(
      padding: AppSpacing.paddingHorizontalBase,
      child: Row(
        children: [
          Expanded(child: Divider(color: dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
            child: Text(
              label,
              style: AppTypography.caption(
                color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
              ),
            ),
          ),
          Expanded(child: Divider(color: dividerColor)),
        ],
      ),
    );
  }
}

