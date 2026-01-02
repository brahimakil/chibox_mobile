import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../guest_guard.dart';

class CartControlSheet extends StatelessWidget {
  final int productId;
  final String productName;
  final double price;
  final String currencySymbol;
  final String imageUrl;

  const CartControlSheet({
    super.key,
    required this.productId,
    required this.productName,
    required this.price,
    required this.currencySymbol,
    required this.imageUrl,
  });

  static void show(
    BuildContext context, {
    required int productId,
    required String productName,
    required double price,
    required String currencySymbol,
    required String imageUrl,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => CartControlSheet(
        productId: productId,
        productName: productName,
        price: price,
        currencySymbol: currencySymbol,
        imageUrl: imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cartService = context.watch<CartService>();
    
    // Check if item exists in cart
    final isInCart = cartService.items.any((item) => item.productId == productId);
    final quantity = isInCart ? cartService.getProductQuantity(productId) : 0;
    
    // We need the cartItemId to update/remove specific items. 
    // If there are multiple variants, this simple sheet might be ambiguous.
    // We'll assume the most recent or first item for this product ID.
    final currentCartItem = isInCart 
        ? cartService.items.firstWhere((item) => item.productId == productId) 
        : null;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: isDark ? AppColors.neutral700 : AppColors.neutral200,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          AppSpacing.verticalLg,

          // Product Info (Mini)
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
                child: Image.network(
                  imageUrl,
                  width: 60,
                  height: 60,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 60,
                    height: 60,
                    color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                  ),
                ),
              ),
              AppSpacing.horizontalMd,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      productName,
                      style: AppTypography.bodyLarge(
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ).copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    AppSpacing.verticalXs,
                    Text(
                      '$currencySymbol${price.toStringAsFixed(2)}',
                      style: AppTypography.bodyMedium(
                        color: AppColors.primary500,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const Divider(height: 32),

          // Controls
          if (!isInCart)
            // Add to Cart Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final authService = context.read<AuthService>();
                  if (authService.isGuest) {
                    Navigator.pop(context);
                    showGuestLoginDialog(context, 'Cart');
                    return;
                  }
                  
                  await cartService.addToCart(productId: productId, quantity: 1);
                  // Keep sheet open or close? Usually close after adding.
                  // But user might want to add more. Let's keep it open and show controls.
                },
                icon: const Icon(Iconsax.shopping_cart),
                label: const Text('Add to Cart'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            )
          else
            // Quantity Controls
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Quantity',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                Row(
                  children: [
                    // Always visible Delete Button
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: _ControlButton(
                        icon: Iconsax.trash,
                        color: AppColors.error,
                        onTap: () {
                          if (currentCartItem != null) {
                            cartService.removeFromCart(currentCartItem.id);
                          }
                        },
                      ),
                    ),

                    // Stepper
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                        borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                        border: Border.all(
                          color: isDark ? AppColors.neutral700 : AppColors.neutral200,
                        ),
                      ),
                      child: Row(
                        children: [
                          // Decrease
                          _ControlButton(
                            icon: Iconsax.minus,
                            color: isDark ? Colors.white : Colors.black,
                            onTap: () {
                              if (currentCartItem != null) {
                                if (quantity > 1) {
                                  cartService.updateCartItem(currentCartItem.id, quantity - 1);
                                } else {
                                  // Optional: Remove if quantity is 1? 
                                  // Since we have a dedicated delete button, let's just remove for convenience
                                  // or maybe do nothing? 
                                  // Let's remove to keep it fluid.
                                  cartService.removeFromCart(currentCartItem.id);
                                }
                              }
                            },
                          ),
                          
                          // Count
                          Container(
                            width: 40,
                            alignment: Alignment.center,
                            child: Text(
                              '$quantity',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ).animate(key: ValueKey(quantity)).scale(duration: 200.ms),
                          ),

                          // Increase
                          _ControlButton(
                            icon: Iconsax.add,
                            color: isDark ? Colors.white : Colors.black,
                            onTap: () {
                              if (currentCartItem != null) {
                                cartService.updateCartItem(currentCartItem.id, quantity + 1);
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            
          AppSpacing.verticalLg,
        ],
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Icon(icon, size: 20, color: color),
      ),
    );
  }
}
