import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/models/board_model.dart';
import '../../../core/services/wishlist_service.dart';

class BoardCard extends StatelessWidget {
  final Board board;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const BoardCard({
    super.key,
    required this.board,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final previews = context.select<WishlistService, List<String>?>(
      (service) => service.boardPreviews[board.id],
    );

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Grid
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: _buildImageGrid(previews, isDark),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    board.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${board.favoritesCount} items',
                    style: TextStyle(
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid(List<String>? images, bool isDark) {
    if (images == null || images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.heart,
              size: 48,
              color: isDark ? Colors.white24 : Colors.black12,
            ),
          ],
        ),
      );
    }

    if (images.length == 1) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        child: Image.network(
          images[0],
          fit: BoxFit.cover,
          width: double.infinity,
          height: double.infinity,
          errorBuilder: (_, __, ___) => const Icon(Icons.error),
        ),
      );
    }

    if (images.length == 2) {
      return Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
              child: Image.network(images[0], fit: BoxFit.cover, height: double.infinity),
            ),
          ),
          const SizedBox(width: 1),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(topRight: Radius.circular(12)),
              child: Image.network(images[1], fit: BoxFit.cover, height: double.infinity),
            ),
          ),
        ],
      );
    }

    // 3 or more
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: ClipRRect(
            borderRadius: const BorderRadius.only(topLeft: Radius.circular(12)),
            child: Image.network(images[0], fit: BoxFit.cover, height: double.infinity),
          ),
        ),
        const SizedBox(width: 1),
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(topRight: Radius.circular(12)),
                  child: Image.network(images[1], fit: BoxFit.cover, width: double.infinity),
                ),
              ),
              const SizedBox(height: 1),
              Expanded(
                child: Image.network(images[2], fit: BoxFit.cover, width: double.infinity),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
