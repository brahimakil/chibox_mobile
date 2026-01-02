import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/navigation_provider.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/guest_guard.dart';
import '../../../core/models/product_model.dart';
import '../../product/screens/product_details_screen.dart';
import '../../navigation/main_shell.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int _lastIndex = -1;
  // Key to force animation restart
  Key _animationKey = UniqueKey();

  @override
  void initState() {
    super.initState();
    // Fetch cart on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only fetch if we don't have data or if it's stale
      // But for now, let's just fetch silently to update
      Provider.of<CartService>(context, listen: false).fetchCart(silent: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navProvider = Provider.of<NavigationProvider>(context);
    // Check if we just switched TO this tab (index 3 for Bag)
    if (navProvider.currentIndex == 3 && _lastIndex != 3) {
      _refreshData();
      setState(() {
        _animationKey = UniqueKey();
      });
    }
    _lastIndex = navProvider.currentIndex;
  }

  void _refreshData() {
    // Use silent fetch on tab switch to avoid full screen loading if we already have data
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final cartService = Provider.of<CartService>(context, listen: false);
        cartService.fetchCart(silent: cartService.items.isNotEmpty);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Watch NavigationProvider to ensure rebuilds on tab switch
    Provider.of<NavigationProvider>(context);
    
    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      appBar: AppBar(
        title: Text(
          'My Bag',
          style: AppTypography.headingMedium(
            color: isDark ? DarkThemeColors.text : LightThemeColors.text,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        actions: [
          Consumer<CartService>(
            builder: (context, cartService, _) {
              if (cartService.items.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Iconsax.trash, color: AppColors.error),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear Cart'),
                      content: const Text('Are you sure you want to remove all items from your cart?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(context);
                            cartService.clearCart();
                          },
                          child: const Text('Clear', style: TextStyle(color: AppColors.error)),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Consumer<CartService>(
        builder: (context, cartService, child) {
          if (cartService.isLoading && cartService.items.isEmpty) {
            return Center(
              child: Lottie.asset(
                'assets/animations/loadingproducts.json',
                width: 200,
                height: 200,
              ),
            );
          }

          if (cartService.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    height: 220,
                    child: Lottie.asset(
                      'assets/animations/emphty_cart.json',
                      repeat: true,
                      fit: BoxFit.contain,
                    ),
                  ).animate(key: ValueKey('lottie_$_animationKey')).scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut),
                  const SizedBox(height: 0),
                  Padding(
                    padding: AppSpacing.paddingHorizontalBase,
                    child: AppButton(
                      text: 'Go Shopping',
                      onPressed: () {
                        Provider.of<NavigationProvider>(context, listen: false).setIndex(0);
                      },
                      width: 200,
                      fullWidth: false,
                    ),
                  ).animate(key: ValueKey('btn_$_animationKey')).fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),
                ],
              ),
            );
          }

          return Column(
            children: [
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: cartService.items.length,
                  separatorBuilder: (context, index) => AppSpacing.verticalMd,
                  itemBuilder: (context, index) {
                    final item = cartService.items[index];
                    return GestureDetector(
                      onTap: () {
                        // Create a minimal Product object to navigate
                        final product = Product(
                          id: item.productId,
                          name: item.productName,
                          mainImage: item.mainImage,
                          price: item.price,
                          currencySymbol: item.currencySymbol,
                          // Other fields will be fetched in details screen
                        );
                        
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProductDetailsScreen(product: product),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(AppSpacing.sm),
                        decoration: BoxDecoration(
                          color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: AppShadows.sm,
                        ),
                        child: Row(
                          children: [
                            // Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.mainImage.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: item.mainImage,
                                      width: 80,
                                      height: 80,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                      ),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    )
                                  : Container(
                                      width: 80,
                                      height: 80,
                                      color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                      child: Icon(
                                        Iconsax.image,
                                        color: isDark ? AppColors.neutral600 : AppColors.neutral400,
                                      ),
                                    ),
                            ),
                            AppSpacing.horizontalMd,
                            // Details
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.productName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.bodyLarge(
                                            color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                                          ).copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Iconsax.close_circle, size: 20, color: AppColors.neutral400),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                        onPressed: () => cartService.removeFromCart(item.id),
                                      ),
                                    ],
                                  ),
                                  if (item.variationName != null) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                      item.variationName!,
                                      style: AppTypography.bodySmall(
                                        color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                                      ),
                                    ),
                                  ],
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${item.currencySymbol}${item.price}',
                                        style: AppTypography.bodyLarge(
                                          color: AppColors.primary500,
                                        ).copyWith(fontWeight: FontWeight.bold),
                                      ),
                                      // Quantity Controls
                                      Container(
                                        decoration: BoxDecoration(
                                          color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          children: [
                                            _QuantityButton(
                                              icon: Icons.remove,
                                              onTap: () {
                                                if (item.quantity > 1) {
                                                  cartService.updateCartItem(item.id, item.quantity - 1);
                                                } else {
                                                  cartService.removeFromCart(item.id);
                                                }
                                              },
                                            ),
                                            SizedBox(
                                              width: 32,
                                              child: Center(
                                                child: Text(
                                                  '${item.quantity}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark ? Colors.white : Colors.black,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            _QuantityButton(
                                              icon: Icons.add,
                                              onTap: () => cartService.updateCartItem(item.id, item.quantity + 1),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Checkout Section
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Total',
                            style: AppTypography.headingSmall(
                              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                            ),
                          ),
                          Text(
                            '${cartService.cartData?.currencySymbol ?? '\$'}${(cartService.cartData?.total ?? 0).toStringAsFixed(2)}',
                            style: AppTypography.headingSmall(
                              color: AppColors.primary500,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalLg,
                      AppButton(
                        text: 'Checkout',
                        isLoading: cartService.isLoading || cartService.isUpdating,
                        isDisabled: cartService.isLoading || cartService.isUpdating,
                        onPressed: () {
                          final authService = context.read<AuthService>();
                          if (authService.isGuest) {
                            showGuestLoginDialog(context, 'Checkout');
                          } else {
                            // TODO: Implement checkout
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 16,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
