import 'package:flutter/material.dart';

/// LuxeMarket Spacing System
/// Base unit: 4px - Compact (SHEIN-style)
class AppSpacing {
  AppSpacing._();

  // ============== SPACING VALUES ==============
  static const double xs = 3.0;
  static const double sm = 6.0;
  static const double md = 10.0;
  static const double base = 14.0;
  static const double lg = 18.0;
  static const double xl = 22.0;
  static const double xxl = 28.0;
  static const double xxxl = 36.0;
  static const double huge = 44.0;

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
  static const double radiusSm = 5.0;
  static const double radiusMd = 7.0;
  static const double radiusBase = 10.0;
  static const double radiusLg = 14.0;
  static const double radiusXl = 18.0;
  static const double radiusXxl = 22.0;
  static const double radiusFull = 9999.0;

  static const BorderRadius borderRadiusSm = BorderRadius.all(Radius.circular(radiusSm));
  static const BorderRadius borderRadiusMd = BorderRadius.all(Radius.circular(radiusMd));
  static const BorderRadius borderRadiusBase = BorderRadius.all(Radius.circular(radiusBase));
  static const BorderRadius borderRadiusLg = BorderRadius.all(Radius.circular(radiusLg));
  static const BorderRadius borderRadiusXl = BorderRadius.all(Radius.circular(radiusXl));
  static const BorderRadius borderRadiusXxl = BorderRadius.all(Radius.circular(radiusXxl));
  static const BorderRadius borderRadiusFull = BorderRadius.all(Radius.circular(radiusFull));

  // ============== ICON SIZES ==============
  static const double iconSm = 14.0;
  static const double iconMd = 18.0;
  static const double iconBase = 22.0;
  static const double iconLg = 26.0;
  static const double iconXl = 30.0;

  // ============== BUTTON HEIGHTS ==============
  static const double buttonSmall = 32.0;
  static const double buttonMedium = 40.0;
  static const double buttonLarge = 48.0;

  // ============== AVATAR SIZES ==============
  static const double avatarSm = 28.0;
  static const double avatarMd = 36.0;
  static const double avatarLg = 50.0;
  static const double avatarXl = 72.0;

  // ============== CATEGORY CIRCLE SIZE ==============
  static const double categorySize = 64.0;
  static const double categoryImageSize = 42.0;
}

