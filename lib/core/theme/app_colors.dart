import 'package:flutter/material.dart';

/// LuxeMarket Color System
/// Luxurious Deep Blue theme with Gold accents
class AppColors {
  AppColors._();

  // ============== PRIMARY COLORS (Orange/Red) ==============
  static const Color primary50 = Color(0xFFFFF8ED);
  static const Color primary100 = Color(0xFFFFEBD4);
  static const Color primary200 = Color(0xFFFFD5A8);
  static const Color primary300 = Color(0xFFFFB670);
  static const Color primary400 = Color(0xFFF9A044);
  static const Color primary500 = Color(0xFFEE8C22); // Main Brand Color
  static const Color primary600 = Color(0xFFDF6726);
  static const Color primary700 = Color(0xFFCF4927);
  static const Color primary800 = Color(0xFFA6361E);
  static const Color primary900 = Color(0xFF852D1B);
  static const Color primary950 = Color(0xFF4A150D);

  // ============== SECONDARY COLORS (Warm Gold) ==============
  static const Color secondary100 = Color(0xFFFEF3C7);
  static const Color secondary500 = Color(0xFFF59E0B); // Main Secondary
  static const Color secondary900 = Color(0xFF78350F);

  // ============== NEUTRAL COLORS (Grays) ==============
  static const Color neutral0 = Color(0xFFFFFFFF);
  static const Color neutral50 = Color(0xFFF8FAFC); // Light Background
  static const Color neutral100 = Color(0xFFF1F5F9);
  static const Color neutral200 = Color(0xFFE2E8F0); // Borders
  static const Color neutral300 = Color(0xFFCBD5E1);
  static const Color neutral400 = Color(0xFF94A3B8); // Icons
  static const Color neutral500 = Color(0xFF64748B);
  static const Color neutral600 = Color(0xFF475569);
  static const Color neutral700 = Color(0xFF2A2A2A); // Dark border
  static const Color neutral800 = Color(0xFF1E1E1E); // Dark surface
  static const Color neutral900 = Color(0xFF121212); // Near black
  static const Color neutral950 = Color(0xFF000000); // Pure black

  // ============== SEMANTIC COLORS ==============
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);

  // ============== GRADIENT COLORS ==============
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary500, primary700],
  );

  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [secondary500, Color(0xFFD97706)],
  );

  static const LinearGradient darkOverlay = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Colors.transparent, Color(0x99000000)],
  );

  // ============== SHIMMER COLORS ==============
  static const Color shimmerBase = Color(0xFFE2E8F0);
  static const Color shimmerHighlight = Color(0xFFF8FAFC);
  static const Color shimmerBaseDark = Color(0xFF334155);
  static const Color shimmerHighlightDark = Color(0xFF475569);
}

/// Light Theme Colors
class LightThemeColors {
  static const Color background = AppColors.neutral0;
  static const Color backgroundSecondary = AppColors.neutral50;
  static const Color surface = AppColors.neutral0;
  static const Color text = AppColors.neutral900;
  static const Color textSecondary = AppColors.neutral600;
  static const Color border = AppColors.neutral200;
  static const Color inputBackground = AppColors.neutral50;
  static const Color icon = AppColors.neutral400;
  static const Color divider = AppColors.neutral200;
}

/// Dark Theme Colors
class DarkThemeColors {
  static const Color background = Color(0xFF000000);        // Pure black
  static const Color backgroundSecondary = Color(0xFF121212); // Near black
  static const Color surface = Color(0xFF1E1E1E);           // Dark gray surface
  static const Color text = AppColors.neutral50;
  static const Color textSecondary = AppColors.neutral300;
  static const Color border = Color(0xFF2A2A2A);            // Dark border
  static const Color inputBackground = Color(0xFF1E1E1E);   // Match surface
  static const Color icon = AppColors.neutral400;
  static const Color divider = Color(0xFF2A2A2A);           // Dark divider
}

