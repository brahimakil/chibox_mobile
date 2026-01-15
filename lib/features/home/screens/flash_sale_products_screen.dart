import 'package:flutter/material.dart';
import '../../../core/models/home_data_model.dart';
import 'unified_products_grid_screen.dart';

/// Flash Sale Products Screen - A wrapper around UnifiedProductsGridScreen
/// for displaying products from a flash sale.
/// 
/// This screen supports:
/// - Local filtering (sort, price range)
/// - Products from FlashSale
class FlashSaleProductsScreen extends StatelessWidget {
  final FlashSale flashSale;

  const FlashSaleProductsScreen({
    super.key,
    required this.flashSale,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedProductsGridScreen(
      config: ProductGridConfig.flashSale(flashSale: flashSale),
    );
  }
}
