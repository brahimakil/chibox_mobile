import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Theme mode options
enum AppThemeMode {
  light,
  dark,
  system,
}

/// Theme Provider for managing light/dark mode
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'app_theme_mode';
  
  AppThemeMode _themeMode = AppThemeMode.system;
  SharedPreferences? _prefs;

  AppThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    if (_themeMode == AppThemeMode.system) {
      return SchedulerBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == AppThemeMode.dark;
  }

  ThemeMode get currentThemeMode {
    switch (_themeMode) {
      case AppThemeMode.light:
        return ThemeMode.light;
      case AppThemeMode.dark:
        return ThemeMode.dark;
      case AppThemeMode.system:
        return ThemeMode.system;
    }
  }

  /// Initialize the theme provider
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final savedTheme = _prefs?.getString(_themeKey);
    
    if (savedTheme != null) {
      _themeMode = AppThemeMode.values.firstWhere(
        (e) => e.name == savedTheme,
        orElse: () => AppThemeMode.system,
      );
    }
    notifyListeners();
  }

  /// Set the theme mode
  Future<void> setThemeMode(AppThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    await _prefs?.setString(_themeKey, mode.name);
    notifyListeners();
  }

  /// Toggle between light and dark mode (ignores system)
  Future<void> toggleTheme() async {
    final newMode = isDarkMode ? AppThemeMode.light : AppThemeMode.dark;
    await setThemeMode(newMode);
  }

  /// Set to light mode
  Future<void> setLightMode() async => setThemeMode(AppThemeMode.light);

  /// Set to dark mode
  Future<void> setDarkMode() async => setThemeMode(AppThemeMode.dark);

  /// Set to system mode
  Future<void> setSystemMode() async => setThemeMode(AppThemeMode.system);
}

