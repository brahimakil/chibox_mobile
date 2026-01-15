import 'package:flutter/material.dart';
import '../../../core/models/product_model.dart';
import 'unified_products_grid_screen.dart';

/// Search Results Screen - A wrapper around UnifiedProductsGridScreen
/// for backward compatibility with existing navigation calls.
/// 
/// This screen supports:
/// - Text search with filters (sort, price range)
/// - Image search with filters
/// - Pagination for infinite scrolling
class SearchResultsScreen extends StatelessWidget {
  final List<Product>? initialProducts;
  final String title;
  final String? searchQuery;
  final String? imagePath;

  const SearchResultsScreen({
    super.key,
    this.initialProducts,
    this.title = 'Search Results',
    this.searchQuery,
    this.imagePath,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the configuration based on what was provided
    ProductGridConfig config;
    
    if (searchQuery != null && searchQuery!.isNotEmpty) {
      // Text search
      config = ProductGridConfig.search(
        query: searchQuery!,
        initialProducts: initialProducts,
      );
    } else if (imagePath != null && imagePath!.isNotEmpty) {
      // Image search
      config = ProductGridConfig.imageSearch(
        imagePath: imagePath!,
        initialProducts: initialProducts,
      );
    } else if (initialProducts != null && initialProducts!.isNotEmpty) {
      // Custom products list (e.g., from quick search)
      config = ProductGridConfig.custom(
        title: title,
        products: initialProducts!,
        enableFilters: true,
      );
    } else {
      // Fallback - should not happen in normal usage
      config = ProductGridConfig.custom(
        title: title,
        products: const [],
        enableFilters: false,
      );
    }

    return UnifiedProductsGridScreen(config: config);
  }
}
