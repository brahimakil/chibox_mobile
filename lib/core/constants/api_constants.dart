/// API Constants for ChiHelo/LuxeMarket App
class ApiConstants {
  ApiConstants._();

  // Base URL
  static const String baseUrl = 'https://cms2.devback.website';

  // API Version Prefix
  static const String apiPrefix = '/v3_0_0';

  // ============== AUTH ENDPOINTS ==============
  static const String register = '$apiPrefix-auth/register';
  static const String login = '$apiPrefix-auth/login';
  static const String verifyOtp = '$apiPrefix-auth/verify-otp';
  static const String resendOtp = '$apiPrefix-auth/resend-otp';
  static const String logout = '$apiPrefix-auth/logout';
  static const String editProfile = '$apiPrefix-auth/edit-profile';
  static const String deleteAccount = '$apiPrefix-auth/delete-account';

  // ============== ADDRESS ENDPOINTS ==============
  static const String getAddresses = '$apiPrefix-address/get-addresses';
  static const String createAddress = '$apiPrefix-address/create-address';
  static const String updateAddress = '$apiPrefix-address/update-address';
  static const String deleteAddress = '$apiPrefix-address/delete-address';
  static const String setDefaultAddress = '$apiPrefix-address/set-default-address';
  static const String getCountries = '$apiPrefix-address/get-countries';
  static const String getCities = '$apiPrefix-address/get-cities';

  // ============== APP ENDPOINTS ==============
  static const String getHomeScreen = '$apiPrefix-app/get-home-screen';
  static const String getBadgeCount = '$apiPrefix-app/get-badge-count';

  // ============== CART ENDPOINTS ==============
  static const String addToCart = '$apiPrefix-cart/add-to-cart';
  static const String getCart = '$apiPrefix-cart/get-cart';
  static const String updateCartItem = '$apiPrefix-cart/update-cart-item';
  static const String removeFromCart = '$apiPrefix-cart/remove-from-cart';
  static const String clearCart = '$apiPrefix-cart/clear-cart';

  // ============== CATEGORY ENDPOINTS ==============
  static const String getAllCategories = '$apiPrefix-category/get-all-categories';
  static const String getCategoryById = '$apiPrefix-category/get-category-by-id';

  // ============== FAVORITE ENDPOINTS ==============
  static const String toggleFavorite = '$apiPrefix-favorite/toggle-favorite';
  static const String getFavorites = '$apiPrefix-favorite/get-favorites';
  static const String createBoard = '$apiPrefix-favorite/create-board';
  static const String getBoards = '$apiPrefix-favorite/get-boards';
  static const String updateBoard = '$apiPrefix-favorite/update-board';
  static const String deleteBoard = '$apiPrefix-favorite/delete-board';

  // ============== NOTIFICATION ENDPOINTS ==============
  static const String getNotifications = '$apiPrefix-notification/get-notifications';
  static const String markAsSeen = '$apiPrefix-notification/mark-as-seen';
  static const String markAllAsSeen = '$apiPrefix-notification/mark-all-as-seen';
  static const String getUnreadCount = '$apiPrefix-notification/get-unread-count';

  // ============== ORDER ENDPOINTS ==============
  static const String checkout = '$apiPrefix-order/checkout';
  static const String getOrders = '$apiPrefix-order/get-orders';
  static const String getOrderDetails = '$apiPrefix-order/get-order-details';
  static const String cancelOrder = '$apiPrefix-order/cancel-order';

  // ============== PRODUCT ENDPOINTS ==============
  static const String getProducts = '$apiPrefix-product/get-products';
  static const String searchProducts = '$apiPrefix-product/search';
  static const String getProductById = '$apiPrefix-product/get-product-by-id';
  static const String searchByImage = '$apiPrefix-product/search-by-image';

  // ============== TIMEOUTS ==============
  static const Duration connectionTimeout = Duration(seconds: 90);
  static const Duration receiveTimeout = Duration(seconds: 90);

  // ============== OTP SETTINGS ==============
  static const int otpLength = 6;
  static const int otpExpirySeconds = 300; // 5 minutes
}

