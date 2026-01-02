import 'package:flutter/material.dart';

/// LuxeMarket Spacing System
/// Base unit: 4px
class AppSpacing {
  AppSpacing._();

  // ============== SPACING VALUES ==============
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double xxxl = 40.0;
  static const double huge = 48.0;

  // ============== PADDING ==============
  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingBase = EdgeInsets.all(base);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  // Horizontal Padding
  static const EdgeInsets paddingHorizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets paddingHorizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets paddingHorizontalBase = EdgeInsets.symmetric(horizontal: base);
  static const EdgeInsets paddingHorizontalLg = EdgeInsets.symmetric(horizontal: lg);
  static const EdgeInsets paddingHorizontalXl = EdgeInsets.symmetric(horizontal: xl);

  // Vertical Padding
  static const EdgeInsets paddingVerticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets paddingVerticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets paddingVerticalBase = EdgeInsets.symmetric(vertical: base);
  static const EdgeInsets paddingVerticalLg = EdgeInsets.symmetric(vertical: lg);
  static const EdgeInsets paddingVerticalXl = EdgeInsets.symmetric(vertical: xl);

  // Screen Padding (default horizontal padding for screens)
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: base);

  // ============== SIZED BOXES ==============
  static const SizedBox verticalXs = SizedBox(height: xs);
  static const SizedBox verticalSm = SizedBox(height: sm);
  static const SizedBox verticalMd = SizedBox(height: md);
  static const SizedBox verticalBase = SizedBox(height: base);
  static const SizedBox verticalLg = SizedBox(height: lg);
  static const SizedBox verticalXl = SizedBox(height: xl);
  static const SizedBox verticalXxl = SizedBox(height: xxl);
  static const SizedBox verticalXxxl = SizedBox(height: xxxl);

  static const SizedBox horizontalXs = SizedBox(width: xs);
  static const SizedBox horizontalSm = SizedBox(width: sm);
  static const SizedBox horizontalMd = SizedBox(width: md);
  static const SizedBox horizontalBase = SizedBox(width: base);
  static const SizedBox horizontalLg = SizedBox(width: lg);
  static const SizedBox horizontalXl = SizedBox(width: xl);

  // ============== BORDER RADIUS ==============
  static const double radiusSm = 6.0;
  static const double radiusMd = 8.0;
  static const double radiusBase = 12.0;
  static const double radiusLg = 16.0;
  static const double radiusXl = 20.0;
  static const double radiusXxl = 24.0;
  static const double radiusFull = 9999.0;

  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusBase = BorderRadius.all(Radius.circular(radiusBase));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius borderRadiusXxl = BorderRadius.all(Radius.circular(radiusXxl));
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(radiusFull));

  // ============== ICON SIZES ==============
  static const double iconSm = 16.0;
  static const double iconMd = 20.0;
  static const double iconBase = 24.0;
  static const double iconLg = 28.0;
  static const double iconXl = 32.0;

  // ============== BUTTON HEIGHTS ==============
  static const double buttonSmall = 36.0;
  static const double buttonMedium = 44.0;
  static const double buttonLarge = 52.0;

  // ============== AVATAR SIZES ==============
  static const double avatarSm = 32.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 56.0;
  static const double avatarXl = 80.0;

  // ============== CATEGORY CIRCLE SIZE ==============
  static const double categorySize = 72.0;
  static const double categoryImageSize = 48.0;
}

