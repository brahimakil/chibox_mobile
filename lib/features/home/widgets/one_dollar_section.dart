import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/product_model.dart';
import '../../../shared/widgets/widgets.dart';
import '../../product/screens/product_details_screen.dart';
import '../screens/one_dollar_screen.dart';

/// One Dollar Section Widget - Displays products priced $1 or less
/// Shows the best deals with prices between $0 and $1
class OneDollarSection extends StatelessWidget {
  final List<Product> products;

  const OneDollarSection({
    super.key,
    required this.products,
  });

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
          // Section Header with dollar icon
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    // Dollar icon
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF00C853), Color(0xFF009624)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Iconsax.dollar_circle,
                        size: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '\$1 Deals',
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
                        color: const Color(0xFF00C853).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Under \$1',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF00C853),
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
                        builder: (context) => OneDollarScreen(
                          initialProducts: products,
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
                    child: _OneDollarProductCard(
                      product: product,
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

/// One Dollar Product Card with deal badge
class _OneDollarProductCard extends StatelessWidget {
  final Product product;

  const _OneDollarProductCard({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(
              product: product,
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image with Deal Badge
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: CachedNetworkImage(
                      imageUrl: product.mainImage,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                        child: const Icon(Icons.image_not_supported, size: 24),
                      ),
                    ),
                  ),
                ),
                // Deal badge
                Positioned(
                  top: 4,
                  left: 4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00C853), Color(0xFF009624)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'DEAL',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 8,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Product Name
                    Text(
                      product.displayName ?? product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    // Price
                    Row(
                      children: [
                        Text(
                          '\$${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF00C853),
                          ),
                        ),
                        if (product.originalPrice != null && 
                            product.originalPrice! > product.price) ...[
                          const SizedBox(width: 4),
                          Text(
                            '\$${product.originalPrice!.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w400,
                              color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
