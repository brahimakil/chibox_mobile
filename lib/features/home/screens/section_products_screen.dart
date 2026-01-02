import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'dart:async';
import '../../../core/theme/theme.dart';
import '../../../core/models/home_data_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../shared/widgets/widgets.dart';
import '../../product/screens/product_details_screen.dart';

class SectionProductsScreen extends StatefulWidget {
  final ProductSection section;

  const SectionProductsScreen({
    super.key,
    required this.section,
  });

  @override
  State<SectionProductsScreen> createState() => _SectionProductsScreenState();
}

class _SectionProductsScreenState extends State<SectionProductsScreen> {
  late List<Product> _products;
  StreamSubscription? _wishlistSubscription;

  @override
  void initState() {
    super.initState();
    _products = List.from(widget.section.products);
    
    // Listen for global wishlist updates
    _wishlistSubscription = WishlistHelper.onStatusChanged.listen((update) {
      if (!mounted) return;
      final index = _products.indexWhere((p) => p.id == update.id);
      if (index != -1) {
        setState(() {
          _products[index] = _products[index].copyWith(isLiked: update.isLiked);
        });
      }
    });
  }

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.section.title,
          style: AppTypography.headingMedium(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
      ),
      body: _products.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.box,
                    size: 64,
                    color: isDark ? AppColors.neutral700 : AppColors.neutral300,
                  ),
                  AppSpacing.verticalMd,
                  Text(
                    'No products found',
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
              itemCount: _products.length,
              itemBuilder: (context, index) {
                final product = _products[index];
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
                )
                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 50 * index))
                    .slideY(begin: 0.1, end: 0);
              },
            ),
    );
  }
}
