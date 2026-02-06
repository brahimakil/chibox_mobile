import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../loading/skeleton_loader.dart';
import '../guest_guard.dart';

/// Product Card Widget
class ProductCard extends StatefulWidget {
  final Product? product; // Optional full product object
  final int id;
  final String name;
  final String imageUrl;
  final double price;
  final double? originalPrice;
  final String currencySymbol;
  final bool isLiked;
  final VoidCallback? onTap;
  final VoidCallback? onFavoriteToggle;
  final VoidCallback? onAddToCart;
  final VoidCallback? onMenuTap;
  final int? cartQuantity;

  const ProductCard({
    super.key,
    this.product,
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.originalPrice,
    this.currencySymbol = '\$',
    this.isLiked = false,
    this.onTap,
    this.onFavoriteToggle,
    this.onAddToCart,
    this.onMenuTap,
    this.cartQuantity,
  });

  // Factory constructor to create from Product model
  factory ProductCard.fromProduct(Product product, {VoidCallback? onTap, VoidCallback? onMenuTap}) {
    // Get the best available name
    // Priority: displayName (English/DeepSeek) > name (English) > originalName (Chinese)
    // Note: Product cards show Chinese as-is. Translation only happens inside ProductDetails.
    String productName = '';
    
    // Helper to check if text contains Chinese characters
    bool containsChinese(String text) => RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    
    final hasChineseOriginal = product.originalName != null && 
        product.originalName!.isNotEmpty && 
        containsChinese(product.originalName!);
    
    final hasGoodEnglishDisplay = product.displayName != null && 
        product.displayName!.isNotEmpty && 
        !containsChinese(product.displayName!) &&
        product.displayName!.length > 10;
    
    if (hasGoodEnglishDisplay) {
      productName = product.displayName!;
    } else if (product.name.isNotEmpty && !containsChinese(product.name)) {
      productName = product.name;
    } else if (hasChineseOriginal) {
      // Show Chinese - user will see translation when they tap into product
      productName = product.originalName!;
    } else if (product.name.isNotEmpty) {
      productName = product.name;
    }
    
    return ProductCard(
      product: product,
      id: product.id,
      name: productName,
      imageUrl: product.mainImage,
      price: product.price,
      originalPrice: product.originalPrice,
      currencySymbol: product.currencySymbol,
      isLiked: product.isLiked,
      cartQuantity: product.cartQuantity,
      onTap: onTap,
      onMenuTap: onMenuTap,
    );
  }

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  bool _isPressed = false;
  late bool _isLiked;
  final GlobalKey _imageKey = GlobalKey();
  StreamSubscription? _wishlistSubscription;
  StreamSubscription? _cartIdSubscription;
  late int _currentId;

  @override
  void initState() {
    super.initState();
    _currentId = widget.id;
    
    // Check WishlistHelper cache for the correct like state first
    // This is the single source of truth for like states
    final cachedLikeState = WishlistHelper.getLikeState(widget.id);
    _isLiked = cachedLikeState ?? widget.isLiked;
    
    // Listen for global wishlist updates
    _wishlistSubscription = WishlistHelper.onStatusChanged.listen((update) {
      if (update.id == _currentId && mounted) {
        setState(() {
          _isLiked = update.isLiked;
        });
      }
    });


    // Listen for Cart ID updates (Tampi -> Local swap)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cartService = Provider.of<CartService>(context, listen: false);
      _cartIdSubscription = cartService.onIdUpdated.listen((update) {
        if (update['old'] == _currentId && mounted) {
          debugPrint('🔄 ProductCard: Updating ID from ${_currentId} to ${update['new']}');
          setState(() {
            _currentId = update['new']!;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    _cartIdSubscription?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When widget is updated, check cache first as it's the source of truth
    if (widget.id != oldWidget.id) {
      _currentId = widget.id;
      final cachedLikeState = WishlistHelper.getLikeState(widget.id);
      _isLiked = cachedLikeState ?? widget.isLiked;
    } else if (widget.isLiked != oldWidget.isLiked) {
      // Only use widget.isLiked if cache doesn't have a state
      final cachedLikeState = WishlistHelper.getLikeState(widget.id);
      _isLiked = cachedLikeState ?? widget.isLiked;
    }
  }


  double? get _discount {
    if (widget.originalPrice != null && widget.originalPrice! > widget.price) {
      return ((widget.originalPrice! - widget.price) / widget.originalPrice! * 100);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final discount = _discount;

    return Stack(
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _isPressed = true),
          onTapUp: (_) => setState(() => _isPressed = false),
          onTapCancel: () => setState(() => _isPressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            transform: Matrix4.identity()..scale(_isPressed ? 0.98 : 1.0),
            decoration: BoxDecoration(
              color: isDark ? DarkThemeColors.surface : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark 
                    ? AppColors.neutral800.withOpacity(0.3) 
                    : AppColors.neutral200.withOpacity(0.4),
                width: 0.5,
              ),
              boxShadow: _isPressed 
                  ? [] 
                  : [
                      BoxShadow(
                        color: isDark 
                            ? Colors.black.withOpacity(0.4) 
                            : Colors.black.withOpacity(0.06),
                        blurRadius: 6,
                        spreadRadius: 0,
                        offset: const Offset(0, 1),
                      ),
                    ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Section
                Stack(
                  children: [
                    // Product Image
                    AspectRatio(
                      aspectRatio: 1,
                      child: widget.imageUrl.isNotEmpty && widget.imageUrl.startsWith('http')
                          ? CachedNetworkImage(
                              key: _imageKey,
                              imageUrl: widget.imageUrl,
                              fit: BoxFit.cover,
                              memCacheWidth: 400, // Limit memory cache size
                              maxWidthDiskCache: 400, // Limit disk cache size
                              placeholder: (_, __) => Image.asset(
                                'assets/images/productfailbackorskeleton_loading.png',
                                fit: BoxFit.cover,
                              ),
                              errorWidget: (_, __, ___) => Image.asset(
                                'assets/images/productfailbackorskeleton_loading.png',
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/images/productfailbackorskeleton_loading.png',
                              fit: BoxFit.cover,
                            ),
                    ),

                    // Discount Badge (Only show if original price is available)
                    if (discount != null && discount > 0)
                      Positioned(
                        top: AppSpacing.sm,
                        left: AppSpacing.sm,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                            vertical: AppSpacing.xs,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: AppSpacing.borderRadiusSm,
                          ),
                          child: Text(
                            '-${discount.round()}%',
                            style: AppTypography.labelSmall(color: Colors.white),
                          ),
                        ),
                      ),

                    // Favorite Button & Menu
                    Positioned(
                      top: AppSpacing.sm,
                      right: AppSpacing.sm,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _FavoriteButton(
                            isLiked: _isLiked,
                            onTap: () async {
                              final authService = context.read<AuthService>();
                              if (authService.isGuest) {
                                showGuestLoginDialog(context, 'Wishlist');
                                return;
                              }

                              if (widget.onFavoriteToggle != null) {
                                widget.onFavoriteToggle!();
                              } else {
                                // Optimistic update
                                setState(() => _isLiked = !_isLiked);
                                
                                final success = await WishlistHelper.toggleFavorite(
                                  context, 
                                  _currentId, 
                                  currentIsLiked: !_isLiked // Pass the OLD state (before toggle)
                                );
                                
                                if (!success) {
                                  // Revert if failed or cancelled
                                  if (mounted) setState(() => _isLiked = !_isLiked);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Info Section
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Product Name - uses backend translation (DeepSeek)
                      Text(
                        widget.name,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),

                      // Price Section
                      Text(
                        '${widget.currencySymbol}${widget.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary500,
                          height: 1,
                        ),
                      ),
                      if (widget.originalPrice != null && widget.originalPrice! > widget.price) ...[
                        const SizedBox(height: 1),
                        Text(
                          '${widget.currencySymbol}${widget.originalPrice!.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 9,
                            decoration: TextDecoration.lineThrough,
                            color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Favorite Button with animation
class _FavoriteButton extends StatelessWidget {
  final bool isLiked;
  final VoidCallback? onTap;

  const _FavoriteButton({
    required this.isLiked,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: (isDark ? DarkThemeColors.surface : LightThemeColors.surface).withOpacity(0.9),
          shape: BoxShape.circle,
          boxShadow: AppShadows.sm,
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isLiked ? Iconsax.heart5 : Iconsax.heart,
            key: ValueKey(isLiked),
            size: 16,
            color: isLiked ? AppColors.error : (isDark ? AppColors.neutral400 : AppColors.neutral500),
          ),
        ),
      )
          .animate(target: isLiked ? 1 : 0)
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.2, 1.2),
            duration: 150.ms,
          )
          .then()
          .scale(
            begin: const Offset(1.2, 1.2),
            end: const Offset(1, 1),
            duration: 150.ms,
          ),
    );
  }
}

/// Horizontal Product Card (for cart, orders, etc.)
class ProductCardHorizontal extends StatelessWidget {
  final String name;
  final String imageUrl;
  final double price;
  final String currencySymbol;
  final String? variant;
  final int quantity;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;
  final ValueChanged<int>? onQuantityChanged;

  const ProductCardHorizontal({
    super.key,
    required this.name,
    required this.imageUrl,
    required this.price,
    this.currencySymbol = '\$',
    this.variant,
    required this.quantity,
    this.onTap,
    this.onRemove,
    this.onQuantityChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
          borderRadius: AppSpacing.borderRadiusBase,
          border: Border.all(
            color: isDark ? DarkThemeColors.border : LightThemeColors.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: AppSpacing.borderRadiusMd,
              child: imageUrl.isNotEmpty && imageUrl.startsWith('http')
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => const SkeletonBox(height: 80, width: 80),
                      errorWidget: (_, __, ___) => Container(
                        width: 80,
                        height: 80,
                        color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                        child: const Icon(Iconsax.image),
                      ),
                    )
                  : Container(
                      width: 80,
                      height: 80,
                      color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                      child: const Icon(Iconsax.image),
                    ),
            ),
            AppSpacing.horizontalMd,

            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTypography.bodyMedium(
                      color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (variant != null) ...[
                    AppSpacing.verticalXs,
                    Text(
                      variant!,
                      style: AppTypography.caption(
                        color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                      ),
                    ),
                  ],
                  AppSpacing.verticalSm,
                  Text(
                    '$currencySymbol${price.toStringAsFixed(2)}',
                    style: AppTypography.priceMedium(),
                  ),
                ],
              ),
            ),

            // Quantity Controls
            if (onQuantityChanged != null)
              Column(
                children: [
                  if (onRemove != null)
                    IconButton(
                      icon: const Icon(Iconsax.trash, size: 18),
                      onPressed: onRemove,
                      color: AppColors.error,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  AppSpacing.verticalSm,
                  _QuantitySelector(
                    quantity: quantity,
                    onChanged: onQuantityChanged!,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantitySelector({
    required this.quantity,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.backgroundSecondary : LightThemeColors.backgroundSecondary,
        borderRadius: AppSpacing.borderRadiusMd,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _QuantityButton(
            icon: Icons.remove,
            onTap: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Text(
              quantity.toString(),
              style: AppTypography.labelLarge(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
          ),
          _QuantityButton(
            icon: Icons.add,
            onTap: () => onChanged(quantity + 1),
          ),
        ],
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QuantityButton({
    required this.icon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppSpacing.borderRadiusMd,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? (isDark ? AppColors.neutral600 : AppColors.neutral400)
                : (isDark ? DarkThemeColors.text : LightThemeColors.text),
          ),
        ),
      ),
    );
  }
}

