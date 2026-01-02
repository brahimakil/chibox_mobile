import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/models/home_data_model.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/cards/product_card.dart';
import '../../product/screens/product_details_screen.dart';

class FlashSaleProductsScreen extends StatelessWidget {
  final FlashSale flashSale;

  const FlashSaleProductsScreen({
    super.key,
    required this.flashSale,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(flashSale.title),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left_2),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: flashSale.products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.box,
                    size: 64,
                    color: isDark ? AppColors.neutral700 : AppColors.neutral300,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'No products available',
                    style: AppTypography.bodyLarge(
                      color: isDark ? AppColors.neutral400 : AppColors.neutral500,
                    ),
                  ),
                ],
              ),
            )
          : MasonryGridView.count(
              padding: const EdgeInsets.all(8),
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              itemCount: flashSale.products.length,
              itemBuilder: (context, index) {
                final product = flashSale.products[index];
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
            ),
    );
  }
}
