import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/models/home_data_model.dart';
import '../../../core/theme/theme.dart';

class GridElementsSection extends StatelessWidget {
  final List<GridElement> elements;

  const GridElementsSection({
    super.key,
    required this.elements,
  });

  @override
  Widget build(BuildContext context) {
    if (elements.isEmpty) return const SizedBox.shrink();

    // Group elements by grid_id
    final Map<int, List<GridElement>> groupedGrids = {};
    for (var element in elements) {
      if (!groupedGrids.containsKey(element.gridId)) {
        groupedGrids[element.gridId] = [];
      }
      groupedGrids[element.gridId]!.add(element);
    }

    return Column(
      children: groupedGrids.values.map((gridElements) {
        return _buildSingleGrid(context, gridElements);
      }).toList(),
    );
  }

  Widget _buildSingleGrid(BuildContext context, List<GridElement> elements) {
    // Sort by Y then X
    elements.sort((a, b) {
      if (a.positionY != b.positionY) {
        return a.positionY.compareTo(b.positionY);
      }
      return a.positionX.compareTo(b.positionX);
    });

    // Determine grid dimensions
    // Assuming standard 12-column grid or similar. 
    // If width is small (e.g. 1, 2, 3, 4), it's likely a 4-column grid.
    // If width is large (e.g. 300), it's pixels (unlikely for responsive).
    // Let's assume a 4-column grid for mobile as it's standard.
    
    // Group by Row (Y position)
    final Map<int, List<GridElement>> rows = {};
    for (var element in elements) {
      if (!rows.containsKey(element.positionY)) {
        rows[element.positionY] = [];
      }
      rows[element.positionY]!.add(element);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        children: rows.values.map((rowElements) {
          return _buildRow(context, rowElements);
        }).toList(),
      ),
    );
  }

  Widget _buildRow(BuildContext context, List<GridElement> rowElements) {
    // Calculate total width units in this row
    int totalUnits = rowElements.fold(0, (sum, e) => sum + e.width);
    
    // If total units < 4 (assuming 4 col grid), we might need to space them or stretch?
    // Let's assume flex based on width.
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: rowElements.map((element) {
          return Expanded(
            flex: element.width,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: _buildElementCard(context, element),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildElementCard(BuildContext context, GridElement element) {
    return GestureDetector(
      onTap: () {
        // Handle actions
        if (element.actions != null) {
          // TODO: Implement action handling (navigation, etc)
          debugPrint('Grid Element tapped: ${element.actions}');
        }
      },
      child: AspectRatio(
        aspectRatio: element.width / element.height, // Use width/height ratio
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: element.imageUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: element.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error),
                    ),
                  )
                : Container(
                    color: Colors.grey[200],
                    child: const Icon(Icons.image_not_supported),
                  ),
          ),
        ),
      ),
    ).animate().fadeIn().scale();
  }
}
