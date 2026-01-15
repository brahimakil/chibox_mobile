import 'package:flutter/material.dart';
import '../../../core/models/product_model.dart';
import 'unified_products_grid_screen.dart';

/// One Dollar Screen - A wrapper around UnifiedProductsGridScreen
/// for displaying products priced between $0 and $1 with pagination and sorting.
/// 
/// This screen supports:
/// - API pagination
/// - Price sorting (low to high, high to low)
/// - Sales count sorting
class OneDollarScreen extends StatelessWidget {
  final List<Product>? initialProducts;

  const OneDollarScreen({
    super.key,
    this.initialProducts,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedProductsGridScreen(
      config: ProductGridConfig.oneDollar(
        initialProducts: initialProducts,
      ),
    );
  }
}
