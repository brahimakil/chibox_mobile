import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/wishlist_service.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import 'dart:async';
import '../../../core/services/navigation_provider.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/animations/add_to_cart_animation.dart';
import '../../../shared/widgets/guest_guard.dart';
import '../../navigation/main_shell.dart';

import '../../wishlist/widgets/add_to_wishlist_sheet.dart';
import '../../../shared/widgets/sheets/cart_control_sheet.dart';
import '../widgets/product_variant_sheet.dart';

class ProductDetailsScreen extends StatefulWidget {
  final Product product;

  const ProductDetailsScreen({
    super.key,
    required this.product,
  });

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  late Product _product;
  int _currentImageIndex = 0;
  bool _isLoading = false;
  bool _isAddingToCart = false;
  final CarouselSliderController _carouselController = CarouselSliderController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _productImageKey = GlobalKey();
  final GlobalKey _cartButtonKey = GlobalKey();
  final GlobalKey<AddToCartAnimationState> _addToCartAnimationKey = GlobalKey<AddToCartAnimationState>();
  
  // Variants selection
  Map<String, String> _selectedOptions = {};
  ProductVariant? _selectedVariant;
  StreamSubscription? _wishlistSubscription;

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    
    // Listen for global wishlist updates
    _wishlistSubscription = WishlistHelper.onStatusChanged.listen((update) {
      if (update.id == _product.id && mounted) {
        setState(() {
          _product = _product.copyWith(isLiked: update.isLiked);
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchFullDetails();
    });
  }

  void _updateSelectedVariant() {
    if (_product.variants == null || _product.variants!.isEmpty) return;
    if (_product.options == null || _product.options!.isEmpty) return;

    // Check if all options are selected
    bool allSelected = true;
    for (var option in _product.options!) {
      if (!_selectedOptions.containsKey(option.name)) {
        allSelected = false;
        break;
      }
    }

    if (!allSelected) {
      setState(() => _selectedVariant = null);
      return;
    }

    // Find matching variant
    // We need to match selected option values to variant propsIds
    // This is tricky because propsIds are like "123:456;789:012"
    // And we have option names and value names.
    // We need to find the IDs of the selected values.

    try {
      List<String> selectedValueIds = [];
      
      for (var option in _product.options!) {
        final selectedValueName = _selectedOptions[option.name];
        final valueObj = option.values.firstWhere((v) => v.name == selectedValueName);
        // We need the prop ID (option ID) and value ID
        // Assuming propsIds format is "optionId:valueId"
        // But our model might not have optionId directly exposed in a way that matches 1688 exactly unless we stored it.
        // Let's assume we can match by checking if the variant's propsIds contains the value ID.
        // Actually, let's look at ProductOptionValue model. It has 'id'.
        // If propsIds contains "optionId:valueId", we might just search for ":valueId" or "valueId" if unique.
        // A safer bet is to try to match all selected value IDs.
        selectedValueIds.add(valueObj.id.toString());
      }

      final matchingVariant = _product.variants!.firstWhere((variant) {
        if (variant.propsIds == null) return false;
        final variantProps = variant.propsIds!.split(';');
        // Check if all selected value IDs are present in variantProps
        // variantProps are "pid:vid". We check if any part ends with :vid
        
        int matchCount = 0;
        for (var vid in selectedValueIds) {
          bool found = false;
          for (var prop in variantProps) {
            if (prop.endsWith(':$vid') || prop == vid) {
              found = true;
              break;
            }
          }
          if (found) matchCount++;
        }
        
        return matchCount == selectedValueIds.length;
      }, orElse: () => _product.variants!.first); // Fallback? No, better null.
      
      // Actually firstWhere throws if not found unless orElse is provided.
      // Let's use a loop or try/catch.
      
      ProductVariant? found;
      try {
        found = _product.variants!.firstWhere((variant) {
          if (variant.propsIds == null) return false;
          final variantProps = variant.propsIds!.split(';');
          int matchCount = 0;
          for (var vid in selectedValueIds) {
            for (var prop in variantProps) {
              // Check if prop ends with :vid (standard) or equals vid (fallback)
              // Also check if prop contains :vid: (middle) just in case
              if (prop.endsWith(':$vid') || prop == vid) {
                matchCount++;
                break;
              }
            }
          }
          return matchCount == selectedValueIds.length;
        });
      } catch (e) {
        found = null;
      }

      setState(() => _selectedVariant = found);
      
    } catch (e) {
      debugPrint('Error matching variant: $e');
    }
  }

  Future<void> _fetchFullDetails() async {
    setState(() => _isLoading = true);
    final productService = Provider.of<ProductService>(context, listen: false);
    final fullProduct = await productService.getProductDetails(_product.id);
    
    if (mounted && fullProduct != null) {
      setState(() {
        // Preserve isLiked state if it was optimistically updated in the list
        // But wait, the list might be stale.
        // Actually, getProductDetails should return the correct isLiked status from the server.
        _product = fullProduct;
        _isLoading = false;
      });
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openFullScreenGallery(int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenGallery(
          images: _getCarouselImages(),
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _showVariantSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: ProductVariantSheet(
          product: _product,
          selectedOptions: _selectedOptions,
          selectedVariant: _selectedVariant,
          onOptionSelected: (optionName, value) {
            setState(() {
              _selectedOptions[optionName] = value;
              _updateSelectedVariant();
            });
          },
          onAddToCart: (cartItems) async {
            Navigator.pop(context); // Close sheet
            
            if (_isAddingToCart) return;
            if (cartItems.isEmpty) return;

            setState(() => _isAddingToCart = true);
            
            try {
              final cartService = Provider.of<CartService>(context, listen: false);
              
              // Trigger animation for the first item (visual feedback)
              _addToCartAnimationKey.currentState?.runAnimation(
                _productImageKey,
                _product.mainImage,
              );

              // Add all items to cart
              for (var item in cartItems) {
                final variant = item['variant'] as ProductVariant?;
                final quantity = item['quantity'] as int;
                
                await cartService.addToCart(
                  productId: _product.id,
                  quantity: quantity,
                  variantId: variant?.id,
                );
              }
              
              // Update local selection to match the last added item (optional, for UX continuity)
              // Or just leave it as is.
              
            } finally {
              if (mounted) {
                setState(() => _isAddingToCart = false);
              }
            }
          },
        ),
      ),
    );
  }

  List<String> _getCarouselImages() {
    final Set<String> topImages = {};
    
    // Always include main image
    if (_product.mainImage.isNotEmpty) {
      topImages.add(_product.mainImage);
    }
    
    // Add variant images
    if (_product.variants != null) {
      for (var variant in _product.variants!) {
        if (variant.image != null && variant.image!.isNotEmpty) {
          topImages.add(variant.image!);
        }
      }
    }
    
    // Add option images
    if (_product.options != null) {
      for (var option in _product.options!) {
        for (var value in option.values) {
          if (value.imageUrl != null && value.imageUrl!.isNotEmpty) {
            topImages.add(value.imageUrl!);
          }
        }
      }
    }
    
    return topImages.toList();
  }

  List<String> _getDetailImages() {
    final Set<String> carouselImages = _getCarouselImages().toSet();
    final List<String> detailImages = [];
    
    if (_product.images != null) {
      for (var img in _product.images!) {
        if (img.isNotEmpty && !carouselImages.contains(img)) {
          detailImages.add(img);
        }
      }
    }
    
    return detailImages;
  }

  Widget _buildDetailImages() {
    final detailImages = _getDetailImages();
    if (detailImages.isEmpty) return const SizedBox.shrink();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...detailImages.map((img) => Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: CachedNetworkImage(
            imageUrl: img,
            width: double.infinity,
            fit: BoxFit.fitWidth,
            placeholder: (context, url) => Container(
              height: 200, 
              color: Colors.grey[100],
              child: Image.asset(
                'assets/images/productfailbackorskeleton_loading.png',
                fit: BoxFit.cover,
              ),
            ),
            errorWidget: (context, url, error) => Image.asset(
              'assets/images/productfailbackorskeleton_loading.png',
              fit: BoxFit.cover,
            ),
          ),
        )),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildServiceTags() {
    if (_product.serviceTags == null || _product.serviceTags!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _product.serviceTags!.map((tag) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.primary500.withOpacity(0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            tag,
            style: TextStyle(
              color: AppColors.primary500,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildVariantPreview(bool isDark) {
    if (_isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 150, height: 20),
          SizedBox(height: 12),
          SkeletonBox(width: double.infinity, height: 60),
          SizedBox(height: 24),
        ],
      );
    }

    if (_product.variants == null || _product.variants!.isEmpty) {
      if (_product.options != null && _product.options!.isNotEmpty) {
         return Padding(
           padding: const EdgeInsets.only(bottom: 16), // Reduced padding
           child: GestureDetector(
             onTap: _showVariantSheet,
             child: Container(
               padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12), // Reduced padding
               decoration: BoxDecoration(
                 border: Border.all(color: isDark ? AppColors.neutral700 : AppColors.neutral300),
                 borderRadius: BorderRadius.circular(8),
               ),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Text('Select Options', style: AppTypography.bodyMedium(color: isDark ? Colors.white : Colors.black)), // Reduced font
                   Icon(Icons.arrow_forward_ios, size: 14, color: isDark ? Colors.white : Colors.black),
                 ],
               ),
             ),
           ),
         );
      }
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Available Options',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black),
            ),
            TextButton(
              onPressed: _showVariantSheet,
              child: const Text('View All', style: TextStyle(fontSize: 11)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Dynamic height horizontal list - calculate based on variant name lengths
        Builder(
          builder: (context) {
            // Calculate max lines needed based on longest variant name
            int maxLines = 1;
            if (_product.variants != null) {
              for (final variant in _product.variants!) {
                String displayName = variant.name;
                final productName = _product.name;
                if (displayName.toLowerCase().contains(productName.toLowerCase())) {
                  displayName = displayName.replaceAll(RegExp(RegExp.escape(productName), caseSensitive: false), '').trim();
                }
                displayName = displayName.replaceAll(RegExp(r'^[\s\-\.,;]+|[\s\-\.,;]+$'), '');
                if (displayName.isEmpty && variant.name.contains(':')) {
                  displayName = variant.name.split(':').last.trim();
                }
                // Estimate lines needed (roughly 12 chars per line at font size 10)
                final estimatedLines = (displayName.length / 12).ceil().clamp(1, 4);
                if (estimatedLines > maxLines) maxLines = estimatedLines;
              }
            }
            // Base height: image (60) + spacing (6) + price line (14) + spacing (4) + padding
            // Plus text lines: maxLines * 12 (line height)
            final dynamicHeight = 60.0 + 6 + (maxLines * 14) + 4 + 14 + 8;
            
            return SizedBox(
              height: dynamicHeight.clamp(100, 175), // Min 100, max 175
              child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _product.variants!.length > 10 ? 10 : _product.variants!.length, // Show more items
            itemBuilder: (context, index) {
              final variant = _product.variants![index];
              final isSelected = _selectedVariant?.id == variant.id;
              
              // Extract short name (value only)
              String displayName = variant.name;
              
              // Remove product name if present to avoid repetition
              final productName = _product.name;
              if (displayName.toLowerCase().contains(productName.toLowerCase())) {
                 // Use regex to replace case-insensitive
                 displayName = displayName.replaceAll(RegExp(RegExp.escape(productName), caseSensitive: false), '').trim();
              }
              
              // Clean up leading/trailing punctuation that might remain (e.g. "- Red", ", Size")
              displayName = displayName.replaceAll(RegExp(r'^[\s\-\.,;]+|[\s\-\.,;]+$'), '');

              if (displayName.isEmpty) {
                 // If we stripped everything, try to use the part after the last colon if it exists
                 if (variant.name.contains(':')) {
                    displayName = variant.name.split(':').last.trim();
                 } else {
                    displayName = variant.name; // Fallback to original
                 }
              } else if (displayName.contains(':')) {
                // If we still have a colon, take the last part (often the specific value)
                displayName = displayName.split(':').last.trim();
              }
              
              return GestureDetector(
                onTap: _showVariantSheet,
                child: Container(
                  width: 120, // Increased width to allow text to flow horizontally
                  margin: const EdgeInsets.only(right: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      // Image
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? AppColors.primary500 : (isDark ? AppColors.neutral700 : AppColors.neutral300),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: variant.image != null && variant.image!.isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: variant.image!,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                    child: Image.asset(
                                      'assets/images/productfailbackorskeleton_loading.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                    child: Image.asset(
                                      'assets/images/productfailbackorskeleton_loading.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                )
                              : Container(
                                  color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                  child: Image.asset(
                                    'assets/images/productfailbackorskeleton_loading.png',
                                    fit: BoxFit.cover,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Short Name
                      Text(
                        displayName,
                        maxLines: 6, // Increased to 6 lines
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? AppColors.primary500 : (isDark ? Colors.white : Colors.black87),
                          fontSize: 10,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Price
                      Text(
                        '${_product.currencySymbol}${variant.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSpecifications(bool isDark) {
    if (_product.productProps == null || _product.productProps!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specifications',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.withOpacity(0.2)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: _product.productProps!.asMap().entries.map((entry) {
              final index = entry.key;
              final prop = entry.value;
              final key = prop.keys.first;
              final value = prop.values.first;
              final isLast = index == _product.productProps!.length - 1;
              
              return Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: isLast ? null : Border(
                    bottom: BorderSide(color: Colors.grey.withOpacity(0.2)),
                  ),
                  color: index % 2 == 0 
                      ? (isDark ? Colors.white.withOpacity(0.05) : Colors.grey[50]) 
                      : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(
                        key,
                        style: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: Text(
                        value,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildRelatedProducts() {
    if (_product.relatedProducts == null || _product.relatedProducts!.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Related Products',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 260,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _product.relatedProducts!.length,
            itemBuilder: (context, index) {
              final product = _product.relatedProducts![index];
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 160,
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
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final carouselImages = _getCarouselImages();

    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      body: Stack(
        children: [
          SafeArea(
            top: false,
            child: Column(
              children: [
                Expanded(
                  child: CustomScrollView(
                controller: _scrollController,
                slivers: [
                  // App Bar & Image Carousel
                  SliverAppBar(
                    expandedHeight: 300,
                    pinned: true,
                    backgroundColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black54 : Colors.white70,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new, size: 18, color: isDark ? Colors.white : Colors.black),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.black54 : Colors.white70,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: Icon(
                            _product.isLiked ? Iconsax.heart5 : Iconsax.heart,
                            color: _product.isLiked ? Colors.red : (isDark ? Colors.white : Colors.black),
                            size: 20,
                          ),
                            onPressed: () async {
                              final success = await WishlistHelper.toggleFavorite(
                                context, 
                                _product.id, 
                                currentIsLiked: _product.isLiked
                              );
                              
                              if (success) {
                                setState(() {
                                  _product = _product.copyWith(isLiked: !_product.isLiked);
                                });
                              }
                          },
                        ),
                      ),
                    ],
                    flexibleSpace: FlexibleSpaceBar(
                      background: Stack(
                        alignment: Alignment.bottomCenter,
                        children: [
                          CarouselSlider(
                            carouselController: _carouselController,
                            options: CarouselOptions(
                              height: 320, // Reduced height
                              viewportFraction: 1.0,
                              enableInfiniteScroll: false,
                              onPageChanged: (index, reason) {
                                setState(() => _currentImageIndex = index);
                              },
                            ),
                            items: carouselImages.map((imageUrl) {
                              return GestureDetector(
                                onTap: () => _openFullScreenGallery(carouselImages.indexOf(imageUrl)),
                                child: Hero(
                                  tag: 'product_${_product.id}_$imageUrl',
                                  child: CachedNetworkImage(
                                    key: carouselImages.indexOf(imageUrl) == 0 ? _productImageKey : null,
                                    imageUrl: imageUrl,
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    placeholder: (context, url) => Container(
                                      color: Colors.grey[200],
                                      child: Image.asset(
                                        'assets/images/productfailbackorskeleton_loading.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    errorWidget: (context, url, error) => Image.asset(
                                      'assets/images/productfailbackorskeleton_loading.png',
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          // Page Indicator
                          if (carouselImages.length > 1)
                            Positioned(
                              bottom: 16,
                              child: AnimatedSmoothIndicator(
                                activeIndex: _currentImageIndex,
                                count: carouselImages.length,
                                effect: ExpandingDotsEffect(
                                  dotHeight: 8,
                                  dotWidth: 8,
                                  activeDotColor: AppColors.primary500,
                                  dotColor: Colors.white.withOpacity(0.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Product Info
                  SliverToBoxAdapter(
                    child: Container(
                      padding: const EdgeInsets.all(16), // Reduced padding
                      decoration: BoxDecoration(
                        color: isDark ? DarkThemeColors.background : LightThemeColors.background,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Price & Rating
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_product.variants != null && _product.variants!.isNotEmpty && _selectedVariant == null)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Starting from',
                                            style: AppTypography.labelSmall(color: Colors.grey).copyWith(fontSize: 10),
                                          ),
                                          Text(
                                            '${_product.currencySymbol}${_product.price.toStringAsFixed(2)}',
                                            style: AppTypography.headingSmall( // Reduced from Medium
                                              color: AppColors.primary500,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(
                                        '${_product.currencySymbol}${(_selectedVariant?.price ?? _product.price).toStringAsFixed(2)}',
                                        style: AppTypography.headingSmall( // Reduced from Medium
                                          color: AppColors.primary500,
                                        ),
                                      ),
                                    if (_product.originalPrice != null && _product.originalPrice! > (_selectedVariant?.price ?? _product.price))
                                      Text(
                                        '${_product.currencySymbol}${_product.originalPrice!.toStringAsFixed(2)}',
                                        style: AppTypography.bodySmall( // Reduced from Medium
                                          color: Colors.grey,
                                        ).copyWith(decoration: TextDecoration.lineThrough),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.primary500.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(Iconsax.star1, size: 14, color: Colors.orange),
                                    const SizedBox(width: 4),
                                    Text(
                                      _product.rating?.toStringAsFixed(1) ?? '0.0',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                    ),
                                    Text(
                                      ' (${_product.reviewCount ?? 0})',
                                      style: const TextStyle(color: Colors.grey, fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Title
                          Text(
                            _product.displayName ?? _product.name,
                            style: AppTypography.bodyLarge(
                              color: isDark ? Colors.white : Colors.black,
                            ).copyWith(fontWeight: FontWeight.bold, fontSize: 16), // Reduced size
                          ),
                          const SizedBox(height: 8),
                          
                          // Service Tags
                          _buildServiceTags(),
                          
                          const SizedBox(height: 16),

                          // Variant Preview
                          _buildVariantPreview(isDark),

                          // Description
                          const Text(
                            'Description',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold), // Reduced size
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _product.description ?? _product.displayName ?? 'No description available.',
                            style: AppTypography.bodyMedium( // Reduced from Large
                              color: isDark ? Colors.grey[400] : Colors.grey[700],
                            ).copyWith(fontSize: 13),
                          ),
                          const SizedBox(height: 20),

                          // Detail Images
                          _buildDetailImages(),

                          // Specifications
                          _buildSpecifications(isDark),

                          // Related Products
                          _buildRelatedProducts(),

                          const SizedBox(height: 80), // Bottom padding for FAB
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    // Cart Icon with Badge
                    GestureDetector(
                      onTap: _isAddingToCart ? null : () {
                        Provider.of<NavigationProvider>(context, listen: false).setIndex(3);
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      },
                      child: Opacity(
                        opacity: _isAddingToCart ? 0.5 : 1.0,
                        child: Stack(
                          children: [
                            Container(
                              key: _cartButtonKey,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.withOpacity(0.3)),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Iconsax.bag_2, color: isDark ? Colors.white : Colors.black),
                            ),
                            Consumer<CartService>(
                              builder: (context, cart, child) {
                                if (cart.itemCount == 0) return const SizedBox.shrink();
                                return Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    child: Text(
                                      '${cart.itemCount}',
                                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Add to Cart Button
                    Expanded(
                      child: AppButton(
                        text: 'Add to Cart',
                        isLoading: _isAddingToCart,
                        onPressed: () {
                          _showVariantSheet();
                        },
                        leftIcon: Iconsax.shopping_cart,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      AddToCartAnimation(
        key: _addToCartAnimationKey,
        cartKey: _cartButtonKey,
        createOverlayEntry: (key) {},
      ),
    ],
    ),
    );
  }
}

class FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: widget.images.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              return InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Center(
                  child: CachedNetworkImage(
                    imageUrl: widget.images[index],
                    fit: BoxFit.contain,
                    placeholder: (context, url) => Image.asset(
                      'assets/images/productfailbackorskeleton_loading.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              );
            },
          ),
          // Close Button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          // Page Indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedSmoothIndicator(
                activeIndex: _currentIndex,
                count: widget.images.length,
                effect: const ScrollingDotsEffect(
                  activeDotColor: Colors.white,
                  dotColor: Colors.grey,
                  dotHeight: 8,
                  dotWidth: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
