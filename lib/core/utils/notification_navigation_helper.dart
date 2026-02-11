import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notification_model.dart';
import '../models/product_model.dart';
import '../models/category_model.dart';
import '../services/navigation_provider.dart';
import '../../features/product/screens/product_details_screen.dart';
import '../../features/orders/screens/order_details_screen.dart';
import '../../features/categories/screens/category_products_screen.dart';

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
      return false;
    }

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
    final targetIdStr = data['target_id']?.toString() 
        ?? data['order_id']?.toString()
        ?? data['row_id']?.toString();
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
      return false;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orderId: orderId),
      ),
    );
    return true;
  }

  static Future<bool> _navigateToProduct(BuildContext context, int? productId) async {
    if (productId == null) {
      return false;
    }

    if (!context.mounted) return false;

    // Navigate immediately with a minimal stub product.
    // ProductDetailsScreen already calls _fetchFullDetails() on init
    // and shows the real data once loaded (with built-in skeleton loading).
    final stubProduct = Product(
      id: productId,
      name: '',
      mainImage: '',
      price: 0,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailsScreen(product: stubProduct),
      ),
    );
    return true;
  }

  static Future<bool> _navigateToCategory(BuildContext context, int? categoryId) async {
    if (categoryId == null) {
      return false;
    }

    // Push immediately — the screen shows its own skeleton loading
    // while fetching full category data + products in background.
    if (!context.mounted) return false;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          category: ProductCategory(id: categoryId, name: ''),
          lazyLoadCategoryId: categoryId,
        ),
      ),
    );
    return true;
  }

  static Future<bool> _navigateToCart(BuildContext context) async {
    try {
      final navProvider = Provider.of<NavigationProvider>(context, listen: false);
      navProvider.setIndex(2); // Cart tab (adjust index if different)
      return true;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> _navigateToWebView(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) {
      return false;
    }

    // Navigate to a simple webview screen
    // Using the existing payment webview or create a generic one
    Navigator.of(context).pushNamed('/webview', arguments: {'url': url});
    return true;
  }
}
