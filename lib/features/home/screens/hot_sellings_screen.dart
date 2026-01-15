import 'package:flutter/material.dart';
import '../../../core/models/product_model.dart';
import 'unified_products_grid_screen.dart';

/// Hot Sellings Screen - A wrapper around UnifiedProductsGridScreen
/// for displaying top selling products with pagination and sorting.
/// 
/// This screen supports:
/// - API pagination
/// - Price sorting (low to high, high to low)
/// - Sales count sorting (default)
class HotSellingsScreen extends StatelessWidget {
  final List<Product>? initialProducts;

  const HotSellingsScreen({
    super.key,
    this.initialProducts,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedProductsGridScreen(
      config: ProductGridConfig.hotSellings(
        initialProducts: initialProducts,
      ),
    );
  }
}
