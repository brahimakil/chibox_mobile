import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../services/product_service.dart';
import '../services/navigation_provider.dart';
import '../../features/product/screens/product_details_screen.dart';
import '../../features/orders/screens/order_details_screen.dart';

/// Universal Navigation Helper for Notifications
/// 
/// Handles navigation based on notification_type from backend.
/// Supports: order, product, category, cart, web, promo, shipping
class NotificationNavigationHelper {
  
  /// Navigate based on notification data
  /// 
  /// [context] - BuildContext for navigation
  /// [notificationType] - Type from backend (order, product, web, etc.)
  /// [targetId] - The ID to navigate to (order_id, product_id, etc.)
  /// [actionUrl] - Optional URL for web type notifications
  /// 
  /// Returns true if navigation was handled, false otherwise
  static Future<bool> navigate({
    required BuildContext context,
    required String? notificationType,
    int? targetId,
    String? actionUrl,
  }) async {
    if (notificationType == null) {
      debugPrint('📬 NotificationNav: No notification_type, skipping navigation');
      return false;
    }

    debugPrint('📬 NotificationNav: type=$notificationType, targetId=$targetId, url=$actionUrl');

    switch (notificationType) {
      case NotificationType.order:
      case NotificationType.shipping:
        return _navigateToOrder(context, targetId);
      
      case NotificationType.product:
        return _navigateToProduct(context, targetId);
      
      case NotificationType.category:
        return _navigateToCategory(context, targetId);
      
      case NotificationType.cart:
        return _navigateToCart(context);
      
      case NotificationType.web:
      case NotificationType.promo:
        return _navigateToWebView(context, actionUrl);
      
      case NotificationType.general:
      default:
        debugPrint('📬 NotificationNav: General notification, no navigation');
        return false;
    }
  }

  /// Navigate from AppNotification model
  static Future<bool> navigateFromNotification(
    BuildContext context, 
    AppNotification notification,
  ) {
    return navigate(
      context: context,
      notificationType: notification.notificationType,
      targetId: notification.targetId,
      actionUrl: notification.actionUrl,
    );
  }

  /// Navigate from FCM/Push data map
  static Future<bool> navigateFromPushData(
    BuildContext context,
    Map<String, dynamic> data,
  ) {
    final notificationType = data['notification_type']?.toString();
    final targetIdStr = data['target_id']?.toString() ?? data['order_id']?.toString();
    final targetId = targetIdStr != null ? int.tryParse(targetIdStr) : null;
    final actionUrl = data['action_url']?.toString();

    return navigate(
      context: context,
      notificationType: notificationType,
      targetId: targetId,
      actionUrl: actionUrl,
    );
  }

  // ==================== Private Navigation Methods ====================

  static Future<bool> _navigateToOrder(BuildContext context, int? orderId) async {
    if (orderId == null) {
      debugPrint('📬 NotificationNav: Order ID is null, cannot navigate');
      return false;
    }

    debugPrint('📬 NotificationNav: Navigating to Order #$orderId');
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orderId: orderId),
      ),
    );
    return true;
  }

  static Future<bool> _navigateToProduct(BuildContext context, int? productId) async {
    if (productId == null) {
      debugPrint('📬 NotificationNav: Product ID is null, cannot navigate');
      return false;
    }

    debugPrint('📬 NotificationNav: Navigating to Product #$productId');

    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Fetch product details
      final productService = Provider.of<ProductService>(context, listen: false);
      final product = await productService.getProductDetails(productId);
      
      // Close loading
      if (context.mounted) Navigator.of(context).pop();

      if (product != null && context.mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProductDetailsScreen(product: product),
          ),
        );
        return true;
      } else {
        debugPrint('📬 NotificationNav: Product not found');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Product not found')),
          );
        }
        return false;
      }
    } catch (e) {
      debugPrint('📬 NotificationNav: Error loading product: $e');
      if (context.mounted) {
        Navigator.of(context).pop(); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load product: $e')),
        );
      }
      return false;
    }
  }

  static Future<bool> _navigateToCategory(BuildContext context, int? categoryId) async {
    if (categoryId == null) {
      debugPrint('📬 NotificationNav: Category ID is null, cannot navigate');
      return false;
    }

    debugPrint('📬 NotificationNav: Navigating to Category #$categoryId');
    
    // Navigate to categories tab and select the category
    // Using NavigationProvider to switch tabs
    try {
      final navProvider = Provider.of<NavigationProvider>(context, listen: false);
      navProvider.setIndex(1); // Categories tab (adjust index if different)
      
      // TODO: Could pass categoryId to auto-select in category screen
      // For now, just switch to the tab
      return true;
    } catch (e) {
      debugPrint('📬 NotificationNav: Error navigating to category: $e');
      return false;
    }
  }

  static Future<bool> _navigateToCart(BuildContext context) async {
    debugPrint('📬 NotificationNav: Navigating to Cart');
    
    try {
      final navProvider = Provider.of<NavigationProvider>(context, listen: false);
      navProvider.setIndex(2); // Cart tab (adjust index if different)
      return true;
    } catch (e) {
      debugPrint('📬 NotificationNav: Error navigating to cart: $e');
      return false;
    }
  }

  static Future<bool> _navigateToWebView(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      debugPrint('📬 NotificationNav: URL is null/empty, cannot navigate');
      return false;
    }

    debugPrint('📬 NotificationNav: Opening WebView for URL: $url');
    
    // Navigate to a simple webview screen
    // Using the existing payment webview or create a generic one
    Navigator.of(context).pushNamed('/webview', arguments: {'url': url});
    return true;
  }
}
