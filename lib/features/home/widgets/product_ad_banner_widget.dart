import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/product_model.dart';
import '../../../shared/widgets/widgets.dart';
import '../../product/screens/product_details_screen.dart';

/// Product Ad Banner widget
class ProductAdBannerWidget extends StatelessWidget {
  final Product product;

  const ProductAdBannerWidget({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return ProductAdBanner(
      productId: product.id,
      productName: product.name,
      imageUrl: product.mainImage,
      price: product.price,
      originalPrice: product.originalPrice,
      currencySymbol: product.currencySymbol,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(product: product),
          ),
        );
      },
    );
  }
}
