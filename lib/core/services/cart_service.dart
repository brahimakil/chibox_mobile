import 'package:flutter/foundation.dart';
import 'dart:async';
import '../constants/api_constants.dart';
import '../models/cart_model.dart';
import 'api_service.dart';

class CartService extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  // Stream for ID updates (Tampi -> Local)
  final StreamController<Map<String, int>> _idUpdateController = StreamController.broadcast();
  Stream<Map<String, int>> get onIdUpdated => _idUpdateController.stream;

  bool _isLoading = false;
  bool _isUpdating = false;
  String? _error;
  CartData? _cartData;
  
  bool get isLoading => _isLoading;
  bool get isUpdating => _isUpdating;
  String? get error => _error;
  CartData? get cartData => _cartData;
  List<CartItem> get items => _cartData?.items ?? [];
  // Use totalItems (unique products) instead of totalQuantity for badge
  int get itemCount => _cartData?.totalItems ?? 0;

  /// Get quantity of a specific product in cart
  int getProductQuantity(int productId) {
    if (_cartData == null) return 0;
    // Sum quantity of all items with this productId (could be multiple variants)
    return _cartData!.items
        .where((item) => item.productId == productId)
        .fold(0, (sum, item) => sum + item.quantity);
  }

  // Debounce timer for fetchCart
  Timer? _fetchDebounce;

  /// Fetch cart items
  Future<void> fetchCart({bool silent = false}) async {
    // Cancel any pending fetch
    _fetchDebounce?.cancel();

    // If silent, we can debounce to avoid spamming the server
    if (silent) {
      _fetchDebounce = Timer(const Duration(milliseconds: 300), () async {
        await _performFetch(silent: true);
      });
    } else {
      // If not silent (user initiated or initial load), run immediately
      await _performFetch(silent: false);
    }
  }

  Future<void> _performFetch({required bool silent}) async {
    if (!silent) {
      _isLoading = true;
    } else {
      _isUpdating = true;
    }
    _error = null;
    notifyListeners();

    try {
      final response = await _api.get(ApiConstants.getCart);

      if (response.success) {
        _cartData = CartData.fromJson(response.data ?? {});
      } else {
        _error = response.message;
        debugPrint('⚠️ Failed to fetch cart: $_error');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error fetching cart: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
      } else {
        _isUpdating = false;
      }
      notifyListeners();
    }
  }

  /// Add item to cart
  Future<bool> addToCart({
    required int productId,
    int quantity = 1,
    int? variantId,
  }) async {
    // We don't set _isLoading = true here because the UI (ProductDetailsScreen) 
    // handles its own loading state for the "Add" button.
    // Setting it here would trigger the global cart loading overlay/spinner unnecessarily.
    
    // Helper for the add request
    Future<ApiResponse> attemptAdd(int id) {
      return _api.post(
        ApiConstants.addToCart,
        body: {
          'product_id': id,
          'quantity': quantity,
          if (variantId != null) 'variant_id': variantId,
        },
      );
    }

    try {
      var response = await attemptAdd(productId);

      if (!response.success) {
        // Check if it might be a missing product (Tampi case)
        // The error message is usually "Product not found" or similar.
        // We'll try to "import" it by fetching details.
        debugPrint('⚠️ Add to cart failed: ${response.message} (status: ${response.statusCode})');
        debugPrint('⚠️ Attempting to import product details...');
        
        try {
          // Trigger import by fetching details
          final importResponse = await _api.get(
            ApiConstants.getProductById,
            queryParams: {'id': productId},
          );
          
          if (importResponse.success && importResponse.data != null) {
            // Extract the NEW local ID from the response
            int? localId;
            if (importResponse.data!.containsKey('product')) {
              localId = importResponse.data!['product']['id'];
            } else {
              localId = importResponse.data!['id'];
            }

            if (localId != null) {
              debugPrint('🔄 Imported product. Swapping Tampi ID $productId for Local ID $localId');
              
              // Notify listeners about the ID change so UI can update
              _idUpdateController.add({'old': productId, 'new': localId});

              // Retry add with the new local ID
              response = await attemptAdd(localId);
            } else {
              // Fallback to original ID if parsing fails
              response = await attemptAdd(productId);
            }
          }
        } catch (e) {
          debugPrint('❌ Failed to import product during add to cart retry: $e');
        }
      }

      if (response.success) {
        debugPrint('✅ Added to cart: Product $productId');
        // Refresh cart data silently
        await fetchCart(silent: true);
        return true;
      } else {
        _error = response.message;
        debugPrint('⚠️ Failed to add to cart: $_error');
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error adding to cart: $e');
      notifyListeners();
    }

    return false;
  }

  /// Update cart item quantity
  Future<bool> updateCartItem(int cartItemId, int quantity) async {
    _isUpdating = true;
    // Optimistic update
    final index = _cartData?.items.indexWhere((item) => item.id == cartItemId) ?? -1;
    if (index == -1) {
      _isUpdating = false;
      notifyListeners();
      return false;
    }

    final oldItem = _cartData!.items[index];
    final oldQuantity = oldItem.quantity;

    // Update local state immediately
    final newItem = CartItem(
      id: oldItem.id,
      productId: oldItem.productId,
      variantId: oldItem.variantId,
      quantity: quantity,
      productName: oldItem.productName,
      slug: oldItem.slug,
      mainImage: oldItem.mainImage,
      variationName: oldItem.variationName,
      propsIds: oldItem.propsIds,
      skuId: oldItem.skuId,
      price: oldItem.price,
      currencySymbol: oldItem.currencySymbol,
      subtotal: oldItem.price * quantity,
    );
    
    _cartData!.items[index] = newItem;
    notifyListeners();

    try {
      debugPrint('🔄 Updating cart item $cartItemId to quantity $quantity');
      final response = await _api.put(
        '${ApiConstants.updateCartItem}?id=$cartItemId',
        body: {'quantity': quantity},
      );

      if (response.success) {
        // Fetch fresh data to ensure sync (silently)
        await fetchCart(silent: true);
        return true;
      } else {
        // Revert on failure
        _cartData!.items[index] = oldItem;
        _error = response.message;
        debugPrint('⚠️ Failed to update cart item: $_error');
        _isUpdating = false;
        notifyListeners();
      }
    } catch (e) {
      // Revert on error
      _cartData!.items[index] = oldItem;
      _error = e.toString();
      debugPrint('❌ Error updating cart item: $e');
      _isUpdating = false;
      notifyListeners();
    }
    return false;
  }

  /// Remove item from cart
  Future<bool> removeFromCart(int cartItemId) async {
    _isUpdating = true;
    // Optimistic update
    final index = _cartData?.items.indexWhere((item) => item.id == cartItemId) ?? -1;
    if (index == -1) {
      _isUpdating = false;
      return false;
    }

    final oldItem = _cartData!.items[index];
    
    // Remove from local state immediately
    _cartData!.items.removeAt(index);
    notifyListeners();

    try {
      debugPrint('🗑️ Removing cart item $cartItemId');
      final response = await _api.delete(
        '${ApiConstants.removeFromCart}?id=$cartItemId',
      );

      if (response.success) {
        await fetchCart(silent: true);
        return true;
      } else {
        // If the item is already gone from the server (e.g. "Cart item not found"), 
        // do NOT revert the local removal. Just accept it's gone.
        if (response.statusCode == 404 || 
            (response.message != null && 
            (response.message!.toLowerCase().contains('not found') || 
             response.message!.toLowerCase().contains('does not exist')))) {
          debugPrint('⚠️ Item already removed from server (404). Keeping local removal.');
          await fetchCart(silent: true);
          return true;
        }

        // Revert on failure
        _cartData!.items.insert(index, oldItem);
        _error = response.message;
        debugPrint('⚠️ Failed to remove from cart: $_error');
        _isUpdating = false;
        notifyListeners();
      }
    } catch (e) {
      // Revert on error
      _cartData!.items.insert(index, oldItem);
      _error = e.toString();
      debugPrint('❌ Error removing from cart: $e');
      _isUpdating = false;
      notifyListeners();
    }
    return false;
  }

  /// Clear cart
  Future<bool> clearCart() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await _api.delete(ApiConstants.clearCart);

      if (response.success) {
        await fetchCart();
        return true;
      } else {
        _error = response.message;
        debugPrint('⚠️ Failed to clear cart: $_error');
        notifyListeners();
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error clearing cart: $e');
      notifyListeners();
    }
    
    _isLoading = false;
    notifyListeners();
    return false;
  }
}
