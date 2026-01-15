import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/product_model.dart';
import '../../product/screens/product_details_screen.dart';
import '../screens/unified_products_grid_screen.dart';

/// Price Deals Section Widget - Displays products in a specific price range
/// Configurable for $1, $2, $5, $7, etc. deals
class PriceDealsSection extends StatelessWidget {
  final List<Product> products;
  final double minPrice;
  final double maxPrice;
  final String? title;
  final Color? accentColor;
  final IconData? icon;

  const PriceDealsSection({
    super.key,
    required this.products,
    this.minPrice = 0.01,
    this.maxPrice = 1.0,
    this.title,
    this.accentColor,
    this.icon,
  });

  String get _displayTitle {
    if (title != null) return title!;
    if (maxPrice <= 1) return '\$1 Deals';
    if (maxPrice <= 2) return '\$2 Deals';
    if (maxPrice <= 5) return '\$5 Deals';
    if (maxPrice <= 7) return '\$7 Deals';
    if (maxPrice <= 10) return '\$10 Deals';
    return 'Under \$${maxPrice.toStringAsFixed(0)}';
  }

  String get _priceLabel {
    if (maxPrice <= 1) return 'Under \$1';
    if (minPrice >= 1 && maxPrice <= 2) return '\$1-\$2';
    if (minPrice >= 2 && maxPrice <= 5) return '\$2-\$5';
    if (minPrice >= 5 && maxPrice <= 7) return '\$5-\$7';
    if (minPrice >= 7 && maxPrice <= 10) return '\$7-\$10';
    return '\$${minPrice.toStringAsFixed(0)}-\$${maxPrice.toStringAsFixed(0)}';
  }

  Color get _color => accentColor ?? _getColorForPrice();

  Color _getColorForPrice() {
    if (maxPrice <= 1) return const Color(0xFF00C853); // Green for $1
    if (maxPrice <= 2) return const Color(0xFF2196F3); // Blue for $2
    if (maxPrice <= 5) return const Color(0xFF9C27B0); // Purple for $5
    if (maxPrice <= 7) return const Color(0xFFFF9800); // Orange for $7
    if (maxPrice <= 10) return const Color(0xFFE91E63); // Pink for $10
    return const Color(0xFF607D8B); // Blue grey for others
  }

  IconData get _icon => icon ?? _getIconForPrice();

  IconData _getIconForPrice() {
    if (maxPrice <= 1) return Iconsax.dollar_circle;
    if (maxPrice <= 2) return Iconsax.money;
    if (maxPrice <= 5) return Iconsax.wallet_2;
    if (maxPrice <= 7) return Iconsax.coin_1;
    return Iconsax.tag;
  }

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.5) 
                : Colors.black.withOpacity(0.12),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Icon
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [_color, _color.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        _icon,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _displayTitle,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Price badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _priceLabel,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _color,
                        ),
                      ),
                    ),
                  ],
                ),
                // See All button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UnifiedProductsGridScreen(
                          config: ProductGridConfig.priceDeals(
                            title: _displayTitle,
                            minPrice: minPrice,
                            maxPrice: maxPrice,
                            initialProducts: products,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary500,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Iconsax.arrow_right_3,
                        size: 14,
                        color: AppColors.primary500,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Horizontal scrolling product list
          SizedBox(
            height: 200,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: products.length,
              itemBuilder: (context, index) {
                final product = products[index];
                return Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? 0 : 4,
                    right: index == products.length - 1 ? 0 : 4,
                  ),
                  child: SizedBox(
                    width: 130,
                    child: _PriceDealsProductCard(
                      product: product,
                      accentColor: _color,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual product card for the price deals section
class _PriceDealsProductCard extends StatelessWidget {
  final Product product;
  final Color accentColor;

  const _PriceDealsProductCard({
    required this.product,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(product: product),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.08) 
                : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                child: CachedNetworkImage(
                  imageUrl: product.mainImage,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: isDark ? Colors.grey[800] : Colors.grey[200],
                    child: const Icon(Icons.image_not_supported, size: 24),
                  ),
                ),
              ),
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName ?? product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Price with deal highlight
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.2),
                          accentColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
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
}
