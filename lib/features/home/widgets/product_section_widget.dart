import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/home_data_model.dart' show ProductSection;
import '../../../shared/widgets/widgets.dart';
import '../../product/screens/product_details_screen.dart';
import '../screens/section_products_screen.dart';

/// Product Section Widget - Clean horizontal scroll layout
class ProductSectionWidget extends StatelessWidget {
  final ProductSection section;

  const ProductSectionWidget({
    super.key,
    required this.section,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final type = section.sliderType?.toLowerCase() ?? '';
    final isGrid = type == 'grid' || type == '1';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      padding: const EdgeInsets.only(top: 10),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                section.title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SectionProductsScreen(section: section),
                    ),
                  );
                },
                child: Row(
                  children: [
                    Text(
                      'See All',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Iconsax.arrow_right_3,
                      size: 16,
                      color: AppColors.primary500,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
          const SizedBox(height: 8),
          if (isGrid)
            _buildGridLayout(context)
          else
            _buildHorizontalScrollLayout(context),
        ],
      ),
    );
  }

  Widget _buildGridLayout(BuildContext context) {
    return MasonryGridView.count(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      itemCount: section.products.length > 4 ? 4 : section.products.length,
      itemBuilder: (context, index) {
        final product = section.products[index];
        return ProductCard.fromProduct(
          product,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ProductDetailsScreen(product: product),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHorizontalScrollLayout(BuildContext context) {
    return SizedBox(
      height: 250,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(left: 12, right: 12, bottom: 8),
        itemCount: section.products.length,
        itemExtent: 162, // 150 width + 12 margin for performance
        addAutomaticKeepAlives: false,
        addRepaintBoundaries: true,
        itemBuilder: (context, index) {
          final product = section.products[index];
          return Container(
            width: 150,
            margin: const EdgeInsets.only(right: 12),
            child: ProductCard.fromProduct(
              product,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(product: product),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
