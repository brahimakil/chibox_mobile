import 'package:flutter/material.dart';
import '../../../core/models/home_data_model.dart';
import 'unified_products_grid_screen.dart';

/// Section Products Screen - A wrapper around UnifiedProductsGridScreen
/// for displaying products from a specific section.
/// 
/// This screen supports:
/// - Local filtering (sort, price range)
/// - Products from ProductSection
class SectionProductsScreen extends StatelessWidget {
  final ProductSection section;

  const SectionProductsScreen({
    super.key,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    return UnifiedProductsGridScreen(
      config: ProductGridConfig.section(section: section),
    );
  }
}
