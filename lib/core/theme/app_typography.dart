import 'package:flutter/material.dart';
import 'app_colors.dart';

/// LuxeMarket Typography System
class AppTypography {
  AppTypography._();

  // Font Family - Plus Jakarta Sans for modern, professional look
  static const String fontFamily = 'PlusJakartaSans';

  // Font Sizes - Compact (SHEIN-style)
  static const double fontSizeXs = 9.0;
  static const double fontSizeSm = 11.0;
  static const double fontSizeBase = 13.0;
  static const double fontSizeMd = 14.0;
  static const double fontSizeLg = 16.0;
  static const double fontSizeXl = 18.0;
  static const double fontSize2xl = 20.0;
  static const double fontSize3xl = 24.0;
  static const double fontSize4xl = 28.0;
  static const double fontSize5xl = 32.0;

  // Font Weights
  static const FontWeight fontWeightLight = FontWeight.w300;
  static const FontWeight fontWeightRegular = FontWeight.w400;
  static const FontWeight fontWeightMedium = FontWeight.w500;
  static const FontWeight fontWeightSemiBold = FontWeight.w600;
  static const FontWeight fontWeightBold = FontWeight.w700;

  // ============== TEXT STYLES ==============
  
  // Display Styles
  static TextStyle displayLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize5xl,
    fontWeight: fontWeightBold,
    color: color ?? AppColors.neutral900,
    letterSpacing: -1.0,
    height: 1.2,
  );

  static TextStyle displayMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize4xl,
    fontWeight: fontWeightBold,
    color: color ?? AppColors.neutral900,
    letterSpacing: -0.5,
    height: 1.25,
  );

  static TextStyle displaySmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize3xl,
    fontWeight: fontWeightSemiBold,
    color: color ?? AppColors.neutral900,
    letterSpacing: -0.25,
    height: 1.3,
  );

  // Heading Styles
  static TextStyle headingLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize2xl,
    fontWeight: fontWeightSemiBold,
    color: color ?? AppColors.neutral900,
    height: 1.35,
  );

  static TextStyle headingMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeXl,
    fontWeight: fontWeightSemiBold,
    color: color ?? AppColors.neutral900,
    height: 1.4,
  );

  static TextStyle headingSmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeLg,
    fontWeight: fontWeightSemiBold,
    color: color ?? AppColors.neutral900,
    height: 1.4,
  );

  // Body Styles
  static TextStyle bodyLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeMd,
    fontWeight: fontWeightRegular,
    color: color ?? AppColors.neutral900,
    height: 1.5,
  );

  static TextStyle bodyMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBase,
    fontWeight: fontWeightRegular,
    color: color ?? AppColors.neutral900,
    height: 1.5,
  );

  static TextStyle bodySmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSm,
    fontWeight: fontWeightRegular,
    color: color ?? AppColors.neutral600,
    height: 1.5,
  );

  // Label Styles
  static TextStyle labelLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBase,
    fontWeight: fontWeightMedium,
    color: color ?? AppColors.neutral900,
    height: 1.4,
  );

  static TextStyle labelMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSm,
    fontWeight: fontWeightMedium,
    color: color ?? AppColors.neutral900,
    height: 1.4,
  );

  static TextStyle labelSmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeXs,
    fontWeight: fontWeightMedium,
    color: color ?? AppColors.neutral600,
    height: 1.4,
    letterSpacing: 0.5,
  );

  // Caption
  static TextStyle caption({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeXs,
    fontWeight: fontWeightRegular,
    color: color ?? AppColors.neutral500,
    height: 1.4,
  );

  // Button
  static TextStyle button({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeMd,
    fontWeight: fontWeightSemiBold,
    color: color ?? AppColors.neutral0,
    height: 1.25,
    letterSpacing: 0.25,
  );

  // Price Styles
  static TextStyle priceLarge({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSize2xl,
    fontWeight: fontWeightBold,
    color: color ?? AppColors.primary500,
    height: 1.2,
  );

  static TextStyle priceMedium({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeLg,
    fontWeight: fontWeightSemiBold,
    color: color ?? AppColors.primary500,
    height: 1.2,
  );

  static TextStyle priceSmall({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeBase,
    fontWeight: fontWeightSemiBold,
    color: color ?? AppColors.primary500,
    height: 1.2,
  );

  static TextStyle priceStrikethrough({Color? color}) => TextStyle(
    fontFamily: fontFamily,
    fontSize: fontSizeSm,
    fontWeight: fontWeightRegular,
    color: color ?? AppColors.neutral400,
    height: 1.2,
    decoration: TextDecoration.lineThrough,
  );
}

