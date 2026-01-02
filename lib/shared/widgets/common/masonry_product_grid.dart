import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../../../core/models/product_model.dart';
import '../cards/product_card.dart';

/// A SHEIN-style masonry grid for displaying products.
/// 
/// This widget provides a staggered grid layout that creates visual density
/// and organic feel, similar to SHEIN/Pinterest product feeds.
/// 
/// Uses the existing [ProductCard] without modification.
class MasonryProductGrid extends StatelessWidget {
  /// The list of products to display
  final List<Product> products;
  
  /// Callback when a product is tapped
  final void Function(Product product)? onProductTap;
  
  /// Number of columns (defaults to 2 for mobile)
  final int crossAxisCount;
  
  /// Spacing between items in the main axis
  final double mainAxisSpacing;
  
  /// Spacing between items in the cross axis
  final double crossAxisSpacing;
  
  /// Padding around the grid
  final EdgeInsetsGeometry? padding;
  
  /// Whether to shrink wrap the grid (for non-scrollable contexts)
  final bool shrinkWrap;
  
  /// Scroll physics for the grid
  final ScrollPhysics? physics;
  
  /// Optional scroll controller
  final ScrollController? controller;

  const MasonryProductGrid({
    super.key,
    required this.products,
    this.onProductTap,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return MasonryGridView.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      padding: padding,
      shrinkWrap: shrinkWrap,
      physics: physics,
      controller: controller,
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard.fromProduct(
          product,
          onTap: onProductTap != null ? () => onProductTap!(product) : null,
        );
      },
    );
  }
}

/// A sliver version of [MasonryProductGrid] for use in CustomScrollView.
/// 
/// This widget integrates seamlessly with slivers for infinite scroll implementations.
class SliverMasonryProductGrid extends StatelessWidget {
  /// The list of products to display
  final List<Product> products;
  
  /// Callback when a product is tapped
  final void Function(Product product)? onProductTap;
  
  /// Number of columns (defaults to 2 for mobile)
  final int crossAxisCount;
  
  /// Spacing between items in the main axis
  final double mainAxisSpacing;
  
  /// Spacing between items in the cross axis
  final double crossAxisSpacing;

  const SliverMasonryProductGrid({
    super.key,
    required this.products,
    this.onProductTap,
    this.crossAxisCount = 2,
    this.mainAxisSpacing = 12,
    this.crossAxisSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SliverMasonryGrid.count(
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: mainAxisSpacing,
      crossAxisSpacing: crossAxisSpacing,
      childCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return ProductCard.fromProduct(
          product,
          onTap: onProductTap != null ? () => onProductTap!(product) : null,
        );
      },
    );
  }
}
