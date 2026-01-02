/// App-wide constants
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'LuxeMarket';
  static const String appVersion = '1.0.0';

  // Storage Keys
  static const String accessTokenKey = 'access_token';
  static const String userKey = 'user_data';
  static const String onboardingKey = 'onboarding_complete';
  static const String languageKey = 'app_language';
  static const String currencyKey = 'app_currency';

  // Pagination
  static const int defaultPageSize = 20;
  static const int homeProductsPageSize = 20;

  // Animation Durations
  static const Duration shortAnimation = Duration(milliseconds: 200);
  static const Duration mediumAnimation = Duration(milliseconds: 350);
  static const Duration longAnimation = Duration(milliseconds: 500);

  // Debounce Durations
  static const Duration searchDebounce = Duration(milliseconds: 500);
  static const Duration scrollDebounce = Duration(milliseconds: 200);

  // Image Placeholders
  static const String placeholderImage = 'assets/images/placeholder.png';
  static const String avatarPlaceholder = 'assets/images/avatar_placeholder.png';
  static const String logoImage = 'assets/images/logo.png';

  // Categories display
  static const int categoriesPerRow = 4;
  static const int maxVisibleCategories = 8;

  // Home Screen
  static const double bannerAspectRatio = 16 / 9;
  static const double categoryCircleSize = 72.0;
  static const double productCardAspectRatio = 0.62;
}

