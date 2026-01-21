import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_typography.dart';
import 'app_spacing.dart';

/// LuxeMarket Theme Configuration
class AppTheme {
  AppTheme._();

  // ============== LIGHT THEME ==============
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    fontFamily: AppTypography.fontFamily,
    
    // Page Transitions - Enable iOS-style swipe back on all platforms
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    ),
    
    // Color Scheme
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary500,
      onPrimary: AppColors.neutral0,
      primaryContainer: AppColors.primary100,
      onPrimaryContainer: AppColors.primary900,
      secondary: AppColors.secondary500,
      onSecondary: AppColors.neutral0,
      secondaryContainer: AppColors.secondary100,
      onSecondaryContainer: AppColors.secondary900,
      surface: LightThemeColors.surface,
      onSurface: LightThemeColors.text,
      surfaceContainerHighest: LightThemeColors.backgroundSecondary,
      onSurfaceVariant: LightThemeColors.textSecondary,
      error: AppColors.error,
      onError: AppColors.neutral0,
      outline: LightThemeColors.border,
      outlineVariant: AppColors.neutral200,
    ),

    // Scaffold
    scaffoldBackgroundColor: LightThemeColors.background,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: LightThemeColors.background,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
      ),
      iconTheme: IconThemeData(
        color: LightThemeColors.text,
        size: AppSpacing.iconBase,
      ),
      titleTextStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeLg,
        fontWeight: AppTypography.fontWeightSemiBold,
        color: LightThemeColors.text,
      ),
    ),

    // Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: LightThemeColors.surface,
      selectedItemColor: AppColors.primary500,
      unselectedItemColor: AppColors.neutral400,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeXs,
        fontWeight: AppTypography.fontWeightMedium,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeXs,
        fontWeight: AppTypography.fontWeightMedium,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      color: LightThemeColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        side: const BorderSide(color: LightThemeColors.border),
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: LightThemeColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: LightThemeColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: LightThemeColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: AppColors.primary500, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeBase,
        color: AppColors.neutral400,
      ),
      labelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeBase,
        color: LightThemeColors.textSecondary,
      ),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.neutral0,
        elevation: 0,
        minimumSize: const Size(double.infinity, AppSpacing.buttonMedium),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusBase,
        ),
        textStyle: AppTypography.button(),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary500,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        textStyle: AppTypography.labelLarge(),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary500,
        minimumSize: const Size(double.infinity, AppSpacing.buttonMedium),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusBase,
        ),
        side: const BorderSide(color: AppColors.primary500),
        textStyle: AppTypography.button(color: AppColors.primary500),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: LightThemeColors.divider,
      thickness: 1,
      space: 0,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: LightThemeColors.backgroundSecondary,
      selectedColor: AppColors.primary100,
      labelStyle: AppTypography.labelMedium(),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusFull,
      ),
    ),
  );

  // ============== DARK THEME ==============
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    fontFamily: AppTypography.fontFamily,
    
    // Page Transitions - Enable iOS-style swipe back on all platforms
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
      },
    ),
    
    // Color Scheme
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary400,
      onPrimary: AppColors.neutral900,
      primaryContainer: AppColors.primary900,
      onPrimaryContainer: AppColors.primary100,
      secondary: AppColors.secondary500,
      onSecondary: AppColors.neutral900,
      secondaryContainer: AppColors.secondary900,
      onSecondaryContainer: AppColors.secondary100,
      surface: DarkThemeColors.surface,
      onSurface: DarkThemeColors.text,
      surfaceContainerHighest: DarkThemeColors.backgroundSecondary,
      onSurfaceVariant: DarkThemeColors.textSecondary,
      error: AppColors.error,
      onError: AppColors.neutral0,
      outline: DarkThemeColors.border,
      outlineVariant: AppColors.neutral700,
    ),

    // Scaffold
    scaffoldBackgroundColor: DarkThemeColors.background,

    // AppBar
    appBarTheme: const AppBarTheme(
      backgroundColor: DarkThemeColors.background,
      elevation: 0,
      scrolledUnderElevation: 1,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      iconTheme: IconThemeData(
        color: DarkThemeColors.text,
        size: AppSpacing.iconBase,
      ),
      titleTextStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeLg,
        fontWeight: AppTypography.fontWeightSemiBold,
        color: DarkThemeColors.text,
      ),
    ),

    // Bottom Navigation
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: DarkThemeColors.surface,
      selectedItemColor: AppColors.primary400,
      unselectedItemColor: AppColors.neutral500,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      selectedLabelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeXs,
        fontWeight: AppTypography.fontWeightMedium,
      ),
      unselectedLabelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeXs,
        fontWeight: AppTypography.fontWeightMedium,
      ),
    ),

    // Card
    cardTheme: CardThemeData(
      color: DarkThemeColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        side: const BorderSide(color: DarkThemeColors.border),
      ),
    ),

    // Input Decoration
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: DarkThemeColors.inputBackground,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.base,
        vertical: AppSpacing.md,
      ),
      border: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: DarkThemeColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: DarkThemeColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: AppColors.primary400, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: AppColors.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: AppSpacing.borderRadiusBase,
        borderSide: const BorderSide(color: AppColors.error, width: 2),
      ),
      hintStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeBase,
        color: AppColors.neutral500,
      ),
      labelStyle: TextStyle(
        fontFamily: AppTypography.fontFamily,
        fontSize: AppTypography.fontSizeBase,
        color: DarkThemeColors.textSecondary,
      ),
    ),

    // Elevated Button
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary500,
        foregroundColor: AppColors.neutral0,
        elevation: 0,
        minimumSize: const Size(double.infinity, AppSpacing.buttonMedium),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusBase,
        ),
        textStyle: AppTypography.button(),
      ),
    ),

    // Text Button
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary400,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.base,
          vertical: AppSpacing.sm,
        ),
        textStyle: AppTypography.labelLarge(),
      ),
    ),

    // Outlined Button
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary400,
        minimumSize: const Size(double.infinity, AppSpacing.buttonMedium),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
        shape: RoundedRectangleBorder(
          borderRadius: AppSpacing.borderRadiusBase,
        ),
        side: const BorderSide(color: AppColors.primary400),
        textStyle: AppTypography.button(color: AppColors.primary400),
      ),
    ),

    // Divider
    dividerTheme: const DividerThemeData(
      color: DarkThemeColors.divider,
      thickness: 1,
      space: 0,
    ),

    // Chip
    chipTheme: ChipThemeData(
      backgroundColor: DarkThemeColors.backgroundSecondary,
      selectedColor: AppColors.primary900,
      labelStyle: AppTypography.labelMedium(color: DarkThemeColors.text),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      shape: RoundedRectangleBorder(
        borderRadius: AppSpacing.borderRadiusFull,
      ),
    ),
  );
}

