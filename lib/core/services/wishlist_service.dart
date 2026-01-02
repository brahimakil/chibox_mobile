import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../models/product_model.dart';
import '../models/board_model.dart';
import 'api_service.dart';

class WishlistService extends ChangeNotifier {
  final ApiService _api = ApiService();
  
  List<Product> _wishlistItems = [];
  List<Board> _boards = [];
  Map<int, List<String>> _boardPreviews = {}; // boardId -> list of image urls
  int _totalItems = 0;
  int _globalTotalItems = 0; // Tracks total items across all boards (for "All Items" view)
  
  bool _isLoading = false;
  String? _error;
  
  List<Product> get wishlistItems => _wishlistItems;
  List<Board> get boards => _boards;
  Map<int, List<String>> get boardPreviews => _boardPreviews;
  int get totalItems => _totalItems;
  int get globalTotalItems => _globalTotalItems;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Fetch all boards
  Future<void> fetchBoards({bool silent = false}) async {
    if (!_api.isAuthenticated) {
      _boards = [];
      notifyListeners();
      return;
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final response = await _api.get(ApiConstants.getBoards);

      if (response.success && response.data != null) {
        final items = response.data!['boards'] as List?;
        if (items != null) {
          _boards = items.map((item) => Board.fromJson(item)).toList();
        }
        // After fetching boards, try to populate previews from recent favorites
        await _populateBoardPreviews();
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error fetching boards: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// Fetch wishlist items (optionally for a specific board)
  Future<void> fetchWishlist({int? boardId, bool silent = false}) async {
    if (!_api.isAuthenticated) {
      _wishlistItems = [];
      notifyListeners();
      return;
    }

    if (!silent) {
      _isLoading = true;
      _error = null;
      notifyListeners();
    }

    try {
      final Map<String, dynamic> queryParams = {
        'is_liked': '1', // Only fetch active favorites
      };
      if (boardId != null && boardId != -1) {
        queryParams['board_id'] = boardId.toString();
      }

      final response = await _api.get(
        ApiConstants.getFavorites,
        queryParams: queryParams,
      );

      if (response.success && response.data != null) {
        if (response.data!['pagination'] != null) {
          _totalItems = response.data!['pagination']['total'] ?? 0;
          // If fetching all items (no specific board), update global total
          if (boardId == null || boardId == -1) {
            _globalTotalItems = _totalItems;
          }
        }
        final items = response.data!['favorites'] as List?;
        if (items != null) {
          _wishlistItems = items.map((item) {
            final productData = item['product'];
            if (productData != null) {
               final product = Product.fromJson(productData);
               return Product(
                 id: product.id,
                 name: product.name,
                 displayName: product.displayName,
                 description: product.description,
                 slug: product.slug,
                 mainImage: product.mainImage,
                 price: product.price,
                 originalPrice: product.originalPrice,
                 currencySymbol: product.currencySymbol,
                 isLiked: true,
                 cartQuantity: product.cartQuantity,
                 variants: product.variants,
                 images: product.images,
                 rating: product.rating,
                 reviewCount: product.reviewCount,
                 categoryId: product.categoryId,
                 productCode: product.productCode,
                 originalName: product.originalName,
                 videoUrl: product.videoUrl,
                 options: product.options,
                 serviceTags: product.serviceTags,
                 productProps: product.productProps,
                 relatedProducts: product.relatedProducts,
                 favoriteId: item['favorite_id'],
               );
            }
            return Product.fromJson(item); 
          }).toList();
        }
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Error fetching wishlist: $e');
    } finally {
      if (!silent) {
        _isLoading = false;
      }
      notifyListeners();
    }
  }

  /// Helper to populate board previews
  Future<void> _populateBoardPreviews() async {
    try {
      final response = await _api.get(
        ApiConstants.getFavorites,
        queryParams: {
          'per_page': '50',
          'is_liked': '1', // Only fetch active favorites
        },
      );

      if (response.success && response.data != null) {
        final items = response.data!['favorites'] as List?;
        if (items != null) {
          _boardPreviews = {};
          
          for (var item in items) {
            final int? boardId = item['board_id'];
            final product = item['product'];
            if (boardId != null && product != null && product['main_image'] != null) {
              if (!_boardPreviews.containsKey(boardId)) {
                _boardPreviews[boardId] = [];
              }
              if (_boardPreviews[boardId]!.length < 3) {
                _boardPreviews[boardId]!.add(product['main_image']);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error populating previews: $e');
    }
  }

  /// Create a new board
  Future<bool> createBoard(String name) async {
    try {
      final response = await _api.post(
        ApiConstants.createBoard,
        body: {'name': name},
      );

      if (response.success) {
        await fetchBoards();
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error creating board: $e');
    }
    return false;
  }

  /// Update a board
  Future<bool> updateBoard(int id, String name) async {
    try {
      final response = await _api.put(
        ApiConstants.updateBoard,
        body: {'board_id': id, 'name': name},
      );

      if (response.success) {
        await fetchBoards();
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error updating board: $e');
    }
    return false;
  }

  /// Delete a board
  Future<bool> deleteBoard(int id) async {
    try {
      final response = await _api.delete(
        ApiConstants.deleteBoard,
        queryParams: {'board_id': id.toString()},
      );

      if (response.success) {
        await fetchBoards();
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error deleting board: $e');
    }
    return false;
  }

  /// Toggle favorite status (with optional boardId)
  Future<bool> toggleFavorite(int productId, {int? boardId}) async {
    if (!_api.isAuthenticated) {
      return false;
    }

    try {
      final body = {'product_id': productId};
      if (boardId != null) {
        body['board_id'] = boardId;
      }

      final response = await _api.post(
        ApiConstants.toggleFavorite,
        body: body,
      );

      if (response.success) {
        final isLiked = response.data != null && response.data!['is_liked'] == true;

        if (!isLiked) {
          // If unliked, remove from local list immediately
          _wishlistItems.removeWhere((item) => item.id == productId);
          if (_totalItems > 0) _totalItems--;
          if (_globalTotalItems > 0) _globalTotalItems--; // Also decrement global total
          notifyListeners();
        } else {
          // If liked, we need to fetch to get the updated list/count
          // Note: This might reset the view to "All Items" if we are in a board,
          // but usually adding happens from outside the wishlist screen.
          fetchWishlist(silent: true); 
        }
        
        fetchBoards(silent: true); 
        return true;
      }
    } catch (e) {
      debugPrint('❌ Error toggling favorite: $e');
    }
    return false;
  }
}
