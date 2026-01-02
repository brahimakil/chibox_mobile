import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wishlist_service.dart';
import '../services/home_service.dart';
import '../services/auth_service.dart';
import '../../features/wishlist/widgets/add_to_wishlist_sheet.dart';
import '../../shared/widgets/guest_guard.dart';

class ProductLikeUpdate {
  final int id;
  final bool isLiked;
  ProductLikeUpdate(this.id, this.isLiked);
}

class WishlistHelper {
  // Broadcast stream for global updates
  static final StreamController<ProductLikeUpdate> _controller = StreamController.broadcast();
  static Stream<ProductLikeUpdate> get onStatusChanged => _controller.stream;

  /// Toggles favorite status and ensures all services are updated
  static Future<bool> toggleFavorite(BuildContext context, int productId, {bool? currentIsLiked}) async {
    final authService = context.read<AuthService>();
    if (authService.isGuest) {
      showGuestLoginDialog(context, 'Wishlist');
      return false;
    }

    final wishlistService = context.read<WishlistService>();
    final homeService = context.read<HomeService>();

    // If current status is not provided, try to guess or assume false (add)
    // But usually the caller knows.
    // If we don't know, we can't do optimistic updates easily.
    
    bool isLiked = currentIsLiked ?? false; // Default to false if unknown

    if (isLiked) {
      // Remove
      final success = await wishlistService.toggleFavorite(productId);
      if (success) {
        homeService.updateProductLikeStatus(productId, false);
        _controller.add(ProductLikeUpdate(productId, false));
        return true;
      }
    } else {
      // Add (Show sheet)
      final result = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (context) => AddToWishlistSheet(productId: productId),
      );
      
      if (result == true) {
        homeService.updateProductLikeStatus(productId, true);
        _controller.add(ProductLikeUpdate(productId, true));
        return true;
      }
    }
    
    return false;
  }

  /// Directly remove without sheet (for "Remove" buttons)
  static Future<bool> removeFavorite(BuildContext context, int productId) async {
    final wishlistService = context.read<WishlistService>();
    final homeService = context.read<HomeService>();

    final success = await wishlistService.toggleFavorite(productId);
    if (success) {
      homeService.updateProductLikeStatus(productId, false);
      _controller.add(ProductLikeUpdate(productId, false));
      return true;
    }
    return false;
  }
}
