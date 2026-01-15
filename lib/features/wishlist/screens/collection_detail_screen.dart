import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:provider/provider.dart';
import '../../../core/services/wishlist_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../shared/widgets/cards/product_card.dart';
import '../../product/screens/product_details_screen.dart';
import '../widgets/create_board_dialog.dart';
import '../widgets/add_to_wishlist_sheet.dart';

class CollectionDetailScreen extends StatefulWidget {
  final int? boardId;
  final String boardName;

  const CollectionDetailScreen({
    super.key,
    this.boardId,
    required this.boardName,
  });

  @override
  State<CollectionDetailScreen> createState() => _CollectionDetailScreenState();
}

class _CollectionDetailScreenState extends State<CollectionDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // If boardId is null, it means "All Items" (or if it's -1)
      final idToFetch = (widget.boardId == -1) ? null : widget.boardId;
      context.read<WishlistService>().fetchWishlist(boardId: idToFetch);
    });
  }

  void _showMenu(BuildContext context, String currentName) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit),
            title: const Text('Rename Collection'),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => CreateBoardDialog(
                  initialName: currentName,
                  boardId: widget.boardId,
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete, color: Colors.red),
            title: const Text('Delete Collection', style: TextStyle(color: Colors.red)),
            onTap: () {
              Navigator.pop(context);
              _confirmDelete();
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: const Text('This will delete the collection. Items will remain in your main wishlist.'), // Verify behavior: Backend says "Remove board_id from all favorites". Correct.
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              final success = await context.read<WishlistService>().deleteBoard(widget.boardId!);
              if (success && mounted) {
                Navigator.pop(context); // Go back to wishlist
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wishlistService = context.watch<WishlistService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Try to get the latest board name from the service
    String displayBoardName = widget.boardName;
    if (widget.boardId != null) {
      try {
        final board = wishlistService.boards.firstWhere((b) => b.id == widget.boardId);
        displayBoardName = board.name;
      } catch (_) {
        // Fallback to initial name if not found
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(displayBoardName),
        actions: [
          if (widget.boardId != null) // Only show menu for custom boards
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showMenu(context, displayBoardName),
            ),
        ],
      ),
      body: wishlistService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : wishlistService.wishlistItems.isEmpty
              ? _buildEmptyState(isDark)
              : MasonryGridView.count(
                  padding: const EdgeInsets.all(8),
                  crossAxisCount: 2,
                  mainAxisSpacing: 4,
                  crossAxisSpacing: 4,
                  itemCount: wishlistService.wishlistItems.length,
                  itemBuilder: (context, index) {
                    final product = wishlistService.wishlistItems[index];
                    return ProductCard(
                      id: product.id,
                      name: product.name,
                      price: product.price,
                      imageUrl: product.mainImage,
                      originalPrice: product.originalPrice,
                      isLiked: true, // Always liked in wishlist
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailsScreen(product: product),
                          ),
                        );
                        // Removed .then() refetch - WishlistService tracks items via local state
                        // and WishlistHelper broadcasts updates via stream
                      },

                      onMenuTap: () {
                        showModalBottomSheet(
                          context: context,
                          builder: (context) => Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.delete_outline, color: Colors.red),
                                title: const Text('Remove from wishlist', style: TextStyle(color: Colors.red)),
                                onTap: () async {
                                  Navigator.pop(context);
                                  await WishlistHelper.toggleFavorite(
                                    context, 
                                    product.id, 
                                    currentIsLiked: true
                                  );
                                },
                              ),
                              const SizedBox(height: 16),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border,
            size: 64,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No items in this collection',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start adding products',
            style: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}
