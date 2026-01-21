import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:dio/dio.dart';
import 'dart:math';
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
import '../../home/screens/unified_products_grid_screen.dart';

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
  
  // ValueNotifier for gallery images - allows dynamic updates
  final ValueNotifier<List<String>> _galleryImagesNotifier = ValueNotifier([]);
  
  // Scroll-based title visibility
  double _scrollOffset = 0;
  
  // Variants selection
  Map<String, String> _selectedOptions = {};
  ProductVariant? _selectedVariant;
  StreamSubscription? _wishlistSubscription;
  
  // Similar products
  List<Product> _similarProducts = [];
  bool _isLoadingSimilar = true; // Start as true to show skeleton initially
  bool _isLoadingMoreSimilar = false;
  bool _hasMoreSimilar = true;
  int _similarPage = 1;
  ScrollController _similarScrollController = ScrollController();

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _similarScrollController.dispose();
    _galleryImagesNotifier.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _product = widget.product;
    
    // Create a fresh scroll controller for similar products
    _similarScrollController = ScrollController();
    
    // Listen for scroll to show/hide product name in app bar
    _scrollController.addListener(_onScroll);
    
    // Listen for global wishlist updates
    _wishlistSubscription = WishlistHelper.onStatusChanged.listen((update) {
      if (update.id == _product.id && mounted) {
        setState(() {
          _product = _product.copyWith(isLiked: update.isLiked);
        });
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      // OPTIMIZATION: Start fetching in parallel for faster loading
      // If we already have categoryId from listing, start similar products fetch immediately
      // This runs in parallel with full product details fetch
      if (_product.categoryId != null) {
        debugPrint('🚀 PARALLEL FETCH: Starting similar products early (categoryId: ${_product.categoryId})');
        _fetchSimilarProducts();
      }
      _fetchFullDetails();
    });
  }
  
  void _onScroll() {
    if (!mounted) return;
    final offset = _scrollController.offset;
    if (offset != _scrollOffset) {
      setState(() {
        _scrollOffset = offset;
      });
    }
  }
  
  // Track if initial similar products fetch has been started (to prevent duplicates)
  bool _similarFetchStarted = false;
  
  Future<void> _fetchSimilarProducts({bool loadMore = false}) async {
    debugPrint('🔵 _fetchSimilarProducts called - loadMore: $loadMore, categoryId: ${_product.categoryId}, productId: ${_product.id}');
    
    if (_product.categoryId == null) {
      debugPrint('⚠️ No categoryId, skipping similar products fetch');
      if (mounted) {
        setState(() {
          _isLoadingSimilar = false;
          _isLoadingMoreSimilar = false;
        });
      }
      return;
    }
    
    if (loadMore) {
      if (_isLoadingMoreSimilar || !_hasMoreSimilar) return;
      setState(() => _isLoadingMoreSimilar = true);
    } else {
      // Guard against duplicate initial fetches (from parallel optimization)
      if (_similarFetchStarted && _isLoadingSimilar) {
        debugPrint('⏭️ Similar products fetch already in progress, skipping duplicate');
        return;
      }
      _similarFetchStarted = true;
      
      // Reset scroll controller position when doing a fresh load
      if (_similarScrollController.hasClients) {
        _similarScrollController.jumpTo(0);
      }
      // Clear previous similar products
      _similarProducts = [];
      setState(() {
        _isLoadingSimilar = true;
        _similarPage = 1;
        _hasMoreSimilar = true;
      });
    }
    
    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      final page = loadMore ? _similarPage + 1 : 1;
      
      final result = await homeService.fetchProductsByCategory(
        _product.categoryId!,
        page: page,
      );
      
      final products = result['products'] as List<Product>? ?? [];
      final pagination = result['pagination'] as Map<String, dynamic>?;
      final hasNext = pagination?['has_next'] == true || products.length >= 10;
      
      debugPrint('📦 Fetched ${products.length} products from category ${_product.categoryId} (page: $page)');
      
      // Filter out the current product AND products already in relatedProducts
      final relatedIds = _product.relatedProducts?.map((p) => p.id).toSet() ?? <int>{};
      var similar = products.where((p) => p.id != _product.id && !relatedIds.contains(p.id)).toList();
      debugPrint('📦 After filtering: ${similar.length} similar products (removed current product ${_product.id} and ${relatedIds.length} related products)');
      
      // Shuffle similar products using current product ID as seed for variety
      // Different product IDs will produce different shuffle orders
      // Adding timestamp component so revisiting same product shows different order
      final shuffleSeed = _product.id ^ DateTime.now().millisecondsSinceEpoch ~/ 60000; // Changes every minute
      similar.shuffle(Random(shuffleSeed));
      debugPrint('🔀 Shuffled similar products with seed: $shuffleSeed');
      
      if (mounted) {
        debugPrint('✅ Mounted, updating state with ${similar.length} similar products');
        setState(() {
          if (loadMore) {
            _similarProducts.addAll(similar);
            _similarPage = page;
          } else {
            _similarProducts = similar;
          }
          _hasMoreSimilar = hasNext && similar.isNotEmpty;
          _isLoadingSimilar = false;
          _isLoadingMoreSimilar = false;
        });
      } else {
        debugPrint('⚠️ Widget not mounted, skipping state update');
      }
    } catch (e) {
      debugPrint('❌ Error fetching similar products: $e');
      if (mounted) {
        setState(() {
          _isLoadingSimilar = false;
          _isLoadingMoreSimilar = false;
        });
      }
    }
  }
  
  void _onSimilarProductsScroll() {
    if (_similarScrollController.position.pixels >= 
        _similarScrollController.position.maxScrollExtent - 100) {
      _fetchSimilarProducts(loadMore: true);
    }
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
    debugPrint('🔍 Fetching full details for product ${_product.id}');
    debugPrint('📦 Initial product - options: ${_product.options?.length ?? 'null'}, variants: ${_product.variants?.length ?? 'null'}');
    final fullProduct = await productService.getProductDetails(_product.id);
    
    if (mounted && fullProduct != null) {
      debugPrint('✅ Full product loaded - id: ${fullProduct.id}, categoryId: ${fullProduct.categoryId}, relatedProducts: ${fullProduct.relatedProducts?.length ?? 0}');
      debugPrint('📋 Full product - options: ${fullProduct.options?.length ?? 'null'}, variants: ${fullProduct.variants?.length ?? 'null'}');
      
      // Check WishlistHelper's local cache for the correct isLiked state
      // This cache is always in sync with local state, unlike HomeService
      // which may not contain products accessed from cart
      final cachedLikeState = WishlistHelper.getLikeState(fullProduct.id);
      
      // Shuffle related products for variety each time user views a product
      Product productToSet = fullProduct;
      if (fullProduct.relatedProducts != null && fullProduct.relatedProducts!.isNotEmpty) {
        final shuffledRelated = List<Product>.from(fullProduct.relatedProducts!);
        // Use timestamp-based seed so each visit shows different order
        shuffledRelated.shuffle(Random(DateTime.now().millisecondsSinceEpoch));
        productToSet = fullProduct.copyWith(relatedProducts: shuffledRelated);
        debugPrint('🔀 Shuffled ${shuffledRelated.length} related products');
      }
      
      setState(() {
        // Use cached isLiked state if available (it's the most recent local truth)
        // Otherwise use the API response
        _product = cachedLikeState != null
            ? productToSet.copyWith(isLiked: cachedLikeState)
            : productToSet;
        
        // Also cache the state from API if we didn't have it locally
        if (cachedLikeState == null) {
          WishlistHelper.setLikeState(fullProduct.id, fullProduct.isLiked);
        }
        
        _isLoading = false;
      });
      
      // Update gallery images notifier so open gallery gets updated images
      _galleryImagesNotifier.value = _getAllImages();
      
      // OPTIMIZATION: Only fetch similar products here if we didn't have categoryId earlier
      // (parallel fetch was already started in initState if categoryId was available)
      if (widget.product.categoryId == null && _product.categoryId != null) {
        debugPrint('🔄 SEQUENTIAL FETCH: Fetching similar products now (categoryId was null before)');
        _fetchSimilarProducts();
      } else {
        debugPrint('✅ Similar products already fetching in parallel (started in initState)');
      }
    } else {
      debugPrint('⚠️ Failed to load full product details for product ${_product.id}');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingSimilar = false; // Also stop loading similar since we can't get product details
        });
      }
    }
  }



  /// Get all product images (carousel + detail images)
  List<String> _getAllImages() {
    return [..._getCarouselImages(), ..._getDetailImages()];
  }

  void _openFullScreenGallery(int initialIndex) {
    // Update the notifier with current images
    _galleryImagesNotifier.value = _getAllImages();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenGallery(
          imagesNotifier: _galleryImagesNotifier,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  void _openFullScreenGalleryWithAllImages(int initialIndex) {
    // Update the notifier with current images
    _galleryImagesNotifier.value = _getAllImages();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenGallery(
          imagesNotifier: _galleryImagesNotifier,
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
        height: MediaQuery.of(context).size.height * 0.92,
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
    
    // Combine all images for gallery view
    final allImages = [..._getCarouselImages(), ...detailImages];
    final carouselCount = _getCarouselImages().length;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Product Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        ...detailImages.asMap().entries.map((entry) {
          final index = entry.key;
          final img = entry.value;
          // The gallery index should account for carousel images
          final galleryIndex = carouselCount + index;
          
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: GestureDetector(
              onTap: () => _openFullScreenGalleryWithAllImages(galleryIndex),
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
            ),
          );
        }),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildServiceTags() {
    if (_product.serviceTags == null || _product.serviceTags!.isEmpty) {
      return const SizedBox.shrink();
    }
    
    // Filter out Chinese-only tags (contain Chinese characters but no English)
    final englishTags = _product.serviceTags!.where((tag) {
      // Check if tag contains Chinese characters
      final containsChinese = RegExp(r'[\u4e00-\u9fff]').hasMatch(tag);
      // Check if tag contains English letters
      final containsEnglish = RegExp(r'[a-zA-Z]').hasMatch(tag);
      // Keep tag only if it's English or mixed (has English letters)
      return !containsChinese || containsEnglish;
    }).toList();
    
    if (englishTags.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: englishTags.map((tag) {
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
      ),
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
        // Use LayoutBuilder + Wrap for truly dynamic sizing
        LayoutBuilder(
          builder: (context, constraints) {
            // Collect all option values with images (from options, not variants)
            // This ensures colors/visual options show first
            final List<Map<String, dynamic>> visualItems = [];
            
            // First, collect option values that have images (typically colors)
            if (_product.options != null) {
              for (final option in _product.options!) {
                for (final value in option.values) {
                  if (value.imageUrl != null && value.imageUrl!.isNotEmpty) {
                    visualItems.add({
                      'type': 'option',
                      'name': value.name,
                      'image': value.imageUrl,
                      'optionName': option.name,
                    });
                  }
                }
              }
            }
            
            // If no option values have images, fall back to variants with images
            if (visualItems.isEmpty && _product.variants != null) {
              for (final variant in _product.variants!) {
                if (variant.image != null && variant.image!.isNotEmpty) {
                  visualItems.add({
                    'type': 'variant',
                    'name': variant.name,
                    'image': variant.image,
                    'price': variant.price,
                    'id': variant.id,
                  });
                }
              }
            }
            
            // If still no visual items, show first 10 variants as before
            if (visualItems.isEmpty && _product.variants != null) {
              for (final variant in _product.variants!.take(10)) {
                visualItems.add({
                  'type': 'variant',
                  'name': variant.name,
                  'image': variant.image,
                  'price': variant.price,
                  'id': variant.id,
                });
              }
            }
            
            final displayItems = visualItems.take(10).toList();
            
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 180),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: List.generate(
                      displayItems.length,
                      (index) {
                        final item = displayItems[index];
                        final String? imageUrl = item['image'] as String?;
                        String displayName = item['name'] as String? ?? '';
                        
                        // Clean up display name
                        final productName = _product.name;
                        if (displayName.toLowerCase().contains(productName.toLowerCase())) {
                           displayName = displayName.replaceAll(RegExp(RegExp.escape(productName), caseSensitive: false), '').trim();
                        }
                        displayName = displayName.replaceAll(RegExp(r'^[\s\-\.,;]+|[\s\-\.,;]+$'), '');
                        if (displayName.isEmpty) {
                           displayName = item['name'] as String? ?? '';
                           if (displayName.contains(':')) {
                              displayName = displayName.split(':').last.trim();
                           }
                        } else if (displayName.contains(':')) {
                          displayName = displayName.split(':').last.trim();
                        }
                        
                        return GestureDetector(
                          onTap: _showVariantSheet,
                          child: Container(
                            width: 90,
                            margin: EdgeInsets.only(right: index < displayItems.length - 1 ? 10 : 0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // Image
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isDark ? AppColors.neutral700 : AppColors.neutral300,
                                      width: 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: imageUrl != null && imageUrl.isNotEmpty
                                        ? CachedNetworkImage(
                                            imageUrl: imageUrl,
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
                                // Name
                                Flexible(
                                  child: Text(
                                    displayName,
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontSize: 10,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (item['type'] == 'variant' && item['price'] != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    '${_product.currencySymbol}${(item['price'] as double).toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
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
    // Combine relatedProducts (from API, 6 items) with similarProducts (from pagination)
    // Start with relatedProducts, then add similarProducts excluding duplicates
    final List<Product> productsToShow = [];
    final Set<int> addedIds = {};
    
    // First add relatedProducts from API (the initial 6)
    if (_product.relatedProducts != null && _product.relatedProducts!.isNotEmpty) {
      for (final p in _product.relatedProducts!) {
        if (!addedIds.contains(p.id)) {
          productsToShow.add(p);
          addedIds.add(p.id);
        }
      }
    }
    
    // Then add similarProducts from pagination (avoiding duplicates)
    for (final p in _similarProducts) {
      if (!addedIds.contains(p.id)) {
        productsToShow.add(p);
        addedIds.add(p.id);
      }
    }
    
    debugPrint('🔄 Building related products - relatedProducts: ${_product.relatedProducts?.length ?? 0}, similarProducts: ${_similarProducts.length}, isLoading: $_isLoadingSimilar, productsToShow: ${productsToShow.length}, categoryId: ${_product.categoryId}');
    
    // Show skeleton while loading even if productsToShow is empty
    if (productsToShow.isEmpty && !_isLoadingSimilar) {
      debugPrint('⚠️ No related products to show and not loading - returning empty');
      return const SizedBox.shrink();
    }
    
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Container(
              width: 4,
              height: 20,
              decoration: BoxDecoration(
                color: AppColors.primary500,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'You May Also Like',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Products List
        if (_isLoadingSimilar && productsToShow.isEmpty)
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: 4,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _buildSimilarProductSkeleton(isDark),
              ),
            ),
          )
        else
          NotificationListener<ScrollNotification>(
            onNotification: (scrollInfo) {
              if (scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent - 100) {
                _fetchSimilarProducts(loadMore: true);
              }
              return false;
            },
            child: SizedBox(
              height: 220,
              child: ListView.builder(
                controller: _similarScrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: productsToShow.length + (_isLoadingMoreSimilar || _hasMoreSimilar ? 1 : 0),
                itemBuilder: (context, index) {
                  // Show loading skeleton at the end
                  if (index >= productsToShow.length) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: _buildSimilarProductSkeleton(isDark),
                    );
                  }
                  
                  final product = productsToShow[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildSimilarProductCard(product, isDark),
                  );
                },
              ),
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
  
  Widget _buildSimilarProductSkeleton(bool isDark) {
    final baseColor = isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBase;
    final highlightColor = isDark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlight;
    
    return Container(
      width: 140,
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image skeleton with shimmer
          Container(
            height: 140,
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title skeleton
                Container(
                  height: 12,
                  width: 100,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 8),
                // Second line
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 12),
                // Price skeleton
                Container(
                  height: 14,
                  width: 60,
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate(onPlay: (c) => c.repeat())
        .shimmer(
          duration: 1500.ms,
          color: highlightColor.withOpacity(isDark ? 0.15 : 0.4),
        );
  }
  
  Widget _buildSimilarProductCard(Product product, bool isDark) {
    final baseColor = isDark ? AppColors.shimmerBaseDark : AppColors.shimmerBase;
    final highlightColor = isDark ? AppColors.shimmerHighlightDark : AppColors.shimmerHighlight;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ProductDetailsScreen(product: product),
          ),
        );
      },
      child: Container(
        width: 140,
        decoration: BoxDecoration(
          color: isDark ? DarkThemeColors.surface : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: product.mainImage,
                    height: 140,
                    width: 140,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      height: 140,
                      width: 140,
                      decoration: BoxDecoration(
                        color: baseColor,
                      ),
                    )
                        .animate(onPlay: (c) => c.repeat())
                        .shimmer(
                          duration: 1500.ms,
                          color: highlightColor.withOpacity(isDark ? 0.15 : 0.4),
                        ),
                    errorWidget: (context, url, error) => Container(
                      height: 140,
                      color: isDark ? Colors.grey[800] : Colors.grey[200],
                      child: const Center(
                        child: Icon(Icons.broken_image, color: Colors.grey, size: 32),
                      ),
                    ),
                  ),
                  // Discount badge
                  if (product.discountPercentage != null && product.discountPercentage! > 0)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '-${product.discountPercentage!.toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Product Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Name
                    Text(
                      product.displayName ?? product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white70 : Colors.black87,
                        height: 1.2,
                      ),
                    ),
                    const Spacer(),
                    // Price
                    Row(
                      children: [
                        Text(
                          '${product.currencySymbol}${product.price.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary500,
                          ),
                        ),
                        if (product.originalPrice != null && product.originalPrice! > product.price) ...[
                          const SizedBox(width: 4),
                          Text(
                            '${product.currencySymbol}${product.originalPrice!.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
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
                    // Title that appears when scrolled
                    title: AnimatedOpacity(
                      opacity: _scrollOffset > 200 ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: GestureDetector(
                        onTap: () {
                          _scrollController.animateTo(
                            0,
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                          );
                        },
                        child: Text(
                          _product.name,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    centerTitle: true,
                    titleSpacing: 0,
                    leading: Container(
                      margin: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _scrollOffset > 200 
                            ? Colors.transparent 
                            : (isDark ? Colors.black54 : Colors.white70),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_new, 
                          size: 18, 
                          color: isDark ? Colors.white : Colors.black,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    actions: [
                      Container(
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _scrollOffset > 200 
                              ? Colors.transparent 
                              : (isDark ? Colors.black54 : Colors.white70),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                top: false, // Don't add top padding
                child: Row(
                  children: [
                    // Cart Icon with Badge
                    GestureDetector(
                      onTap: _isAddingToCart ? null : () {
                        final navProvider = Provider.of<NavigationProvider>(context, listen: false);
                        navProvider.requestCloseSearch(); // Close any active search overlay
                        navProvider.setIndex(3);
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
                        text: _isLoading ? 'Loading...' : 'Add to Cart',
                        isLoading: _isAddingToCart,
                        onPressed: _isLoading ? null : () {
                          _showVariantSheet();
                        },
                        leftIcon: Iconsax.shopping_cart,
                        isDisabled: _isLoading,
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
  final ValueNotifier<List<String>> imagesNotifier;
  final int initialIndex;

  const FullScreenGallery({
    super.key,
    required this.imagesNotifier,
    required this.initialIndex,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late ScrollController _thumbnailScrollController;
  late int _currentIndex;
  bool _isSaving = false;
  bool _showSaveSuccess = false;
  late AnimationController _saveIconController;
  late List<String> _images;

  @override
  void initState() {
    super.initState();
    _images = widget.imagesNotifier.value;
    _currentIndex = widget.initialIndex.clamp(0, _images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _thumbnailScrollController = ScrollController();
    _saveIconController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // Listen for image updates
    widget.imagesNotifier.addListener(_onImagesUpdated);
    
    // Scroll thumbnails to show current image after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToThumbnail(_currentIndex, animate: false);
    });
  }
  
  void _onImagesUpdated() {
    final newImages = widget.imagesNotifier.value;
    if (newImages.length != _images.length) {
      setState(() {
        _images = newImages;
        // Keep current index valid
        if (_currentIndex >= _images.length) {
          _currentIndex = _images.length - 1;
        }
      });
    }
  }

  @override
  void dispose() {
    widget.imagesNotifier.removeListener(_onImagesUpdated);
    _pageController.dispose();
    _thumbnailScrollController.dispose();
    _saveIconController.dispose();
    super.dispose();
  }

  void _scrollToThumbnail(int index, {bool animate = true}) {
    if (!_thumbnailScrollController.hasClients) return;
    
    const thumbnailWidth = 64.0;
    const thumbnailSpacing = 8.0;
    final screenWidth = MediaQuery.of(context).size.width;
    
    // Calculate the scroll offset to center the thumbnail
    final targetOffset = (index * (thumbnailWidth + thumbnailSpacing)) - 
                         (screenWidth / 2) + (thumbnailWidth / 2);
    final maxOffset = _thumbnailScrollController.position.maxScrollExtent;
    final clampedOffset = targetOffset.clamp(0.0, maxOffset);
    
    if (animate) {
      _thumbnailScrollController.animateTo(
        clampedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _thumbnailScrollController.jumpTo(clampedOffset);
    }
  }

  void _goToImage(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _showSaveOptions() {
    HapticFeedback.mediumImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[600],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            // Search by Image option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary500.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Iconsax.search_normal, color: AppColors.primary500),
              ),
              title: const Text(
                'Search by Image',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Find similar products',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _searchByCurrentImage();
              },
            ),
            const Divider(color: Colors.grey, height: 1),
            // Save option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.download_rounded, color: Colors.blue),
              ),
              title: const Text(
                'Save to Gallery',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              subtitle: Text(
                'Save this image to your device',
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
              ),
              onTap: () {
                Navigator.pop(context);
                _saveCurrentImage();
              },
            ),
            const Divider(color: Colors.grey, height: 1),
            // Cancel option
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.close, color: Colors.grey),
              ),
              title: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              onTap: () => Navigator.pop(context),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  void _searchByCurrentImage() {
    final imageUrl = _images[_currentIndex];
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UnifiedProductsGridScreen(
          config: ProductGridConfig.imageSearch(
            imagePath: imageUrl, // The API accepts URL too
          ),
        ),
      ),
    );
  }

  Future<void> _saveCurrentImage() async {
    if (_isSaving) return;
    
    setState(() => _isSaving = true);
    
    try {
      final imageUrl = _images[_currentIndex];
      
      // Download the image
      final response = await Dio().get(
        imageUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      
      // Save to gallery
      final result = await ImageGallerySaverPlus.saveImage(
        Uint8List.fromList(response.data),
        quality: 100,
        name: 'ChiHelo_${DateTime.now().millisecondsSinceEpoch}',
      );
      
      if (mounted) {
        if (result['isSuccess'] == true) {
          setState(() => _showSaveSuccess = true);
          HapticFeedback.mediumImpact();
          
          // Hide success indicator after 2 seconds
          Future.delayed(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _showSaveSuccess = false);
            }
          });
        } else {
          _showErrorSnackbar('Failed to save image');
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackbar('Error saving image: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Main Image Viewer with PhotoViewGallery (smooth pinch-to-zoom)
            Positioned.fill(
              bottom: 100 + bottomPadding, // Leave space for thumbnails
              child: GestureDetector(
                // Long press to show save options
                onLongPress: _showSaveOptions,
              child: PhotoViewGallery.builder(
                scrollPhysics: const BouncingScrollPhysics(),
                pageController: _pageController,
                itemCount: _images.length,
                onPageChanged: (index) {
                  setState(() => _currentIndex = index);
                  _scrollToThumbnail(index);
                },
                builder: (context, index) {
                  return PhotoViewGalleryPageOptions(
                    imageProvider: CachedNetworkImageProvider(_images[index]),
                    initialScale: PhotoViewComputedScale.contained,
                    minScale: PhotoViewComputedScale.contained * 0.8,
                    maxScale: PhotoViewComputedScale.covered * 4,
                    heroAttributes: PhotoViewHeroAttributes(tag: 'product_image_$index'),
                    errorBuilder: (context, error, stackTrace) => Image.asset(
                      'assets/images/productfailbackorskeleton_loading.png',
                      fit: BoxFit.contain,
                    ),
                  );
                },
                loadingBuilder: (context, event) => Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                      value: event == null
                          ? null
                          : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                    ),
                  ),
                ),
                backgroundDecoration: const BoxDecoration(color: Colors.black),
              ),
            ),
          ),
          
          // Close Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 24),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          // Search by Image Button (top right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 124,
            child: GestureDetector(
              onTap: _searchByCurrentImage,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.search_normal,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
          
          // Save Button (top right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 70,
            child: GestureDetector(
              onTap: _showSaveOptions,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _showSaveSuccess 
                      ? Colors.green.withOpacity(0.8) 
                      : Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(
                        _showSaveSuccess ? Icons.check : Icons.download_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
              ),
            ),
          ),
          
          // Image Counter
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                '${_currentIndex + 1} / ${_images.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          
          // Save Success Toast
          if (_showSaveSuccess)
            Positioned(
              bottom: 120 + bottomPadding,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Image saved to gallery',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Thumbnail Strip at Bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: bottomPadding + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Long press hint text
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Long press image to save',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.6),
                      fontSize: 12,
                    ),
                  ),
                ),
                // Thumbnail scroll view
                SizedBox(
                  height: 64,
                  child: ListView.builder(
                    controller: _thumbnailScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      final isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () => _goToImage(index),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(right: 8),
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isSelected ? Colors.white : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Opacity(
                              opacity: isSelected ? 1.0 : 0.6,
                              child: CachedNetworkImage(
                                imageUrl: _images[index],
                                fit: BoxFit.cover,
                                placeholder: (context, url) => Container(
                                  color: Colors.grey[800],
                                ),
                                errorWidget: (context, url, error) => Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.image_not_supported, 
                                    color: Colors.white54, size: 20),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }
}
