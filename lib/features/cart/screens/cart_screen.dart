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
import '../../../core/services/shipping_service.dart';
import '../../../core/models/cart_model.dart';
import '../../../core/models/shipping_model.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/guest_guard.dart';
import '../../../core/models/product_model.dart';
import '../../product/screens/product_details_screen.dart';
import '../../navigation/main_shell.dart';
import 'shipping_selection_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  int _lastIndex = -1;
  // Key to force animation restart
  Key _animationKey = UniqueKey();
  // Selected cart item IDs for checkout
  Set<int> _selectedItemIds = {};
  // Track if user manually cleared selection (to prevent auto-reselect)
  bool _userClearedSelection = false;
  // Shipping comparison data for displaying per-item shipping costs
  ShippingComparison? _shippingComparison;
  bool _isLoadingShipping = false;

  @override
  void initState() {
    super.initState();
    // Fetch cart on init
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Only fetch if we don't have data or if it's stale
      // But for now, let's just fetch silently to update
      Provider.of<CartService>(context, listen: false).fetchCart(silent: true).then((_) {
        // After cart loads, fetch shipping costs
        if (mounted) {
          _fetchShippingCosts();
        }
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navProvider = Provider.of<NavigationProvider>(context);
    // Check if we just switched TO this tab (index 3 for Cart)
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
        cartService.fetchCart(silent: cartService.items.isNotEmpty).then((_) {
          // Select all items by default when cart loads
          if (mounted) {
            setState(() {
              _selectedItemIds = cartService.items.map((item) => item.id).toSet();
            });
            // Also fetch shipping costs for display
            _fetchShippingCosts();
          }
        });
      }
    });
  }
  
  /// Fetch shipping costs for all cart items to display on each card
  Future<void> _fetchShippingCosts() async {
    if (!mounted) return;
    
    final cartService = Provider.of<CartService>(context, listen: false);
    if (cartService.items.isEmpty) return;
    
    setState(() => _isLoadingShipping = true);
    
    try {
      final shippingService = Provider.of<ShippingService>(context, listen: false);
      final cartItemIds = cartService.items.map((i) => i.id).toList();
      
      final comparison = await shippingService.compareShippingMethods(
        cartItemIds: cartItemIds,
      );
      
      if (mounted) {
        setState(() {
          _shippingComparison = comparison;
          _isLoadingShipping = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching shipping costs: $e');
      if (mounted) {
        setState(() => _isLoadingShipping = false);
      }
    }
  }

  void _toggleItemSelection(int itemId) {
    setState(() {
      if (_selectedItemIds.contains(itemId)) {
        _selectedItemIds.remove(itemId);
        // If user manually unselects last item, mark as intentionally cleared
        if (_selectedItemIds.isEmpty) {
          _userClearedSelection = true;
        }
      } else {
        _selectedItemIds.add(itemId);
        _userClearedSelection = false; // User is selecting items, so reset flag
      }
    });
  }

  void _toggleSelectAll(List<CartItem> items) {
    setState(() {
      if (_selectedItemIds.length == items.length) {
        _selectedItemIds.clear();
        _userClearedSelection = true; // User intentionally cleared all
      } else {
        _selectedItemIds = items.map((item) => item.id).toSet();
        _userClearedSelection = false;
      }
    });
  }

  double _calculateSelectedTotal(CartService cartService) {
    return cartService.items
        .where((item) => _selectedItemIds.contains(item.id))
        .fold(0.0, (sum, item) => sum + item.subtotal);
  }
  
  /// Build shipping cost row for a cart item
  /// Shows "China → Lebanon" with lowest shipping cost (sea or air)
  /// Shows "AI Processing..." if estimation is in progress
  Widget _buildShippingCostRow(int productId, bool isDark) {
    if (_shippingComparison == null) {
      if (_isLoadingShipping) {
        return Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'Calculating shipping...',
                style: AppTypography.bodySmall(
                  color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                ),
              ),
            ],
          ),
        );
      }
      return const SizedBox.shrink();
    }
    
    // Check if AI is still processing this product
    final isProcessing = _shippingComparison!.isProductProcessing(productId);
    
    if (isProcessing) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.warning.withOpacity(0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 10,
                height: 10,
                child: CircularProgressIndicator(
                  strokeWidth: 1.5,
                  color: AppColors.warning,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '🇨🇳 → 🇱🇧',
                style: const TextStyle(fontSize: 11),
              ),
              const SizedBox(width: 4),
              Text(
                'AI Processing...',
                style: AppTypography.bodySmall(
                  color: AppColors.warning,
                ).copyWith(fontWeight: FontWeight.w500, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }
    
    final shippingInfo = _shippingComparison!.getLowestCostForProduct(productId);
    if (shippingInfo == null) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: (isDark ? AppColors.primary500 : AppColors.primary100).withOpacity(0.2),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '🇨🇳',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_forward,
              size: 12,
              color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
            ),
            const SizedBox(width: 4),
            Text(
              '🇱🇧',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(width: 6),
            Text(
              shippingInfo.icon,
              style: const TextStyle(fontSize: 11),
            ),
            const SizedBox(width: 4),
            Text(
              '\$${shippingInfo.cost.toStringAsFixed(2)}',
              style: AppTypography.bodySmall(
                color: AppColors.primary500,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteItem(CartService cartService, int itemId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Item'),
        content: const Text('Are you sure you want to remove this item from your cart?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              cartService.removeFromCart(itemId);
              setState(() {
                _selectedItemIds.remove(itemId);
              });
            },
            child: const Text('Remove', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
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
          'My Cart',
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

          // Ensure selected items are synced when cart updates (only on first load)
          // Don't auto-select if user manually cleared selection
          if (_selectedItemIds.isEmpty && cartService.items.isNotEmpty && !_userClearedSelection) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                setState(() {
                  _selectedItemIds = cartService.items.map((item) => item.id).toSet();
                });
              }
            });
          }
          // Remove any selected IDs that no longer exist in cart
          _selectedItemIds.removeWhere((id) => !cartService.items.any((item) => item.id == id));

          return Column(
            children: [
              // Select All Header
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                child: Row(
                  children: [
                    Checkbox(
                      value: _selectedItemIds.length == cartService.items.length && cartService.items.isNotEmpty,
                      onChanged: (_) => _toggleSelectAll(cartService.items),
                      activeColor: AppColors.primary500,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                    Text(
                      'Select All (${_selectedItemIds.length}/${cartService.items.length})',
                      style: AppTypography.bodyMedium(
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  itemCount: cartService.items.length,
                  separatorBuilder: (context, index) => AppSpacing.verticalMd,
                  itemBuilder: (context, index) {
                    final item = cartService.items[index];
                    final isSelected = _selectedItemIds.contains(item.id);
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
                          border: isSelected 
                              ? Border.all(color: AppColors.primary500.withOpacity(0.5), width: 1.5)
                              : null,
                        ),
                        child: Row(
                          children: [
                            // Checkbox
                            Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleItemSelection(item.id),
                              activeColor: AppColors.primary500,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                            ),
                            // Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: item.mainImage.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: item.mainImage,
                                      width: 70,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                      ),
                                      errorWidget: (context, url, error) => const Icon(Icons.error),
                                    )
                                  : Container(
                                      width: 70,
                                      height: 70,
                                      color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                      child: Icon(
                                        Iconsax.image,
                                        color: isDark ? AppColors.neutral600 : AppColors.neutral400,
                                      ),
                                    ),
                            ),
                            AppSpacing.horizontalSm,
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
                                        onPressed: () => _confirmDeleteItem(cartService, item.id),
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
                                  // Shipping cost display (China → Lebanon)
                                  _buildShippingCostRow(item.productId, isDark),
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
                                              onTap: () async {
                                                if (item.quantity > 1) {
                                                  await cartService.updateCartItem(item.id, item.quantity - 1);
                                                  _fetchShippingCosts(); // Refresh shipping after quantity change
                                                } else {
                                                  _confirmDeleteItem(cartService, item.id);
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
                                              onTap: () async {
                                                await cartService.updateCartItem(item.id, item.quantity + 1);
                                                _fetchShippingCosts(); // Refresh shipping after quantity change
                                              },
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
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total (${_selectedItemIds.length} items)',
                                style: AppTypography.headingSmall(
                                  color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                                ),
                              ),
                              if (_selectedItemIds.length != cartService.items.length)
                                Text(
                                  '${cartService.items.length - _selectedItemIds.length} items not selected',
                                  style: AppTypography.bodySmall(
                                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                          Text(
                            '${cartService.cartData?.currencySymbol ?? '\$'}${_calculateSelectedTotal(cartService).toStringAsFixed(2)}',
                            style: AppTypography.headingSmall(
                              color: AppColors.primary500,
                            ),
                          ),
                        ],
                      ),
                      AppSpacing.verticalLg,
                      AppButton(
                        text: 'Checkout (${_selectedItemIds.length})',
                        isLoading: false, // Never show loading - let user tap anytime
                        isDisabled: _selectedItemIds.isEmpty,
                        onPressed: _selectedItemIds.isEmpty ? null : () {
                          final authService = context.read<AuthService>();
                          if (authService.isGuest) {
                            showGuestLoginDialog(context, 'Checkout');
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ShippingSelectionScreen(selectedCartItemIds: _selectedItemIds.toList()),
                              ),
                            );
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
      borderRadius: BorderRadius.circular(6),
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        child: Icon(
          icon,
          size: 14,
          color: isDark ? Colors.white : Colors.black,
        ),
      ),
    );
  }
}
