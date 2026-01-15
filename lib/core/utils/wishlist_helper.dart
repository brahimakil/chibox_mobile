import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/wishlist_service.dart';
import '../services/home_service.dart';
import '../services/auth_service.dart';
import '../services/cache_service.dart';
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

  // Local cache of like states - this is the single source of truth for UI
  // Key: productId, Value: isLiked
  static final Map<int, bool> _likeStateCache = {};

  /// Get the like state for a product (returns null if not in cache)
  static bool? getLikeState(int productId) => _likeStateCache[productId];

  /// Set the like state for a product (called when we know the definitive state)
  static void setLikeState(int productId, bool isLiked) {
    _likeStateCache[productId] = isLiked;
  }

  /// Initialize like states from wishlist (call this after fetching wishlist)
  static void initializeFromWishlist(List<int> likedProductIds) {
    for (final id in likedProductIds) {
      _likeStateCache[id] = true;
    }
  }

  /// Clear the cache (call on logout)
  static void clearCache() => _likeStateCache.clear();

  /// Toggles favorite status and ensures all services are updated
  static Future<bool> toggleFavorite(BuildContext context, int productId, {bool? currentIsLiked}) async {
    final authService = context.read<AuthService>();
    if (authService.isGuest) {
      showGuestLoginDialog(context, 'Wishlist');
      return false;
    }

    final wishlistService = context.read<WishlistService>();
    final homeService = context.read<HomeService>();

    bool isLiked = currentIsLiked ?? (_likeStateCache[productId] ?? false);

    if (isLiked) {
      // Remove
      final success = await wishlistService.toggleFavorite(productId);
      if (success) {
        _likeStateCache[productId] = false; // Update local cache
        homeService.updateProductLikeStatus(productId, false);
        _controller.add(ProductLikeUpdate(productId, false));
        CacheService.clearCategoryProductsCache();
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
        _likeStateCache[productId] = true; // Update local cache
        homeService.updateProductLikeStatus(productId, true);
        _controller.add(ProductLikeUpdate(productId, true));
        CacheService.clearCategoryProductsCache();
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
      _likeStateCache[productId] = false; // Update local cache
      homeService.updateProductLikeStatus(productId, false);
      _controller.add(ProductLikeUpdate(productId, false));
      CacheService.clearCategoryProductsCache();
      return true;
    }
    return false;
  }
}
