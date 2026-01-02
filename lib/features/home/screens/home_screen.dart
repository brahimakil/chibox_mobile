import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:async';
import '../../../core/theme/theme.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/models/home_data_model.dart' show GridElement;
import '../../../core/models/category_model.dart' show ProductCategory;
import '../../../core/utils/image_helper.dart';
import '../../product/screens/product_details_screen.dart';
import '../widgets/floating_header.dart';
import '../widgets/home_categories_section.dart';
import '../widgets/product_section_widget.dart';
import '../widgets/legacy_banner_carousel.dart';
import '../widgets/product_ad_banner_widget.dart';
import '../widgets/home_error_state.dart';
import '../widgets/flash_sale_section.dart';
import '../widgets/category_products_grid.dart';
import '../widgets/quick_actions_row.dart';
import '../../../shared/widgets/widgets.dart';
import 'all_products_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageController _bannerPageController = PageController();
  final ValueNotifier<int> _bannerIndexNotifier = ValueNotifier(0);
  final ValueNotifier<double> _scrollOffsetNotifier = ValueNotifier(0.0);
  final ValueNotifier<bool> _showScrollTopNotifier = ValueNotifier(false);
  final ValueNotifier<ProductCategory?> _selectedCategoryNotifier = ValueNotifier(null);
  final ValueNotifier<bool> _isCategoriesLoadingNotifier = ValueNotifier(false);
  Timer? _bannerTimer;

  // Constants - banner no longer includes header space
  static const double _bannerHeight = 220.0;
  static const double _headerHeight = 110.0; // Status bar + search + categories
  static const double _scrollThreshold = 80.0;

  @override
  void initState() {
    super.initState();
    _loadData();
    _scrollController.addListener(_onScroll);
    _startBannerAutoPlay();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _bannerPageController.dispose();
    _bannerIndexNotifier.dispose();
    _scrollOffsetNotifier.dispose();
    _showScrollTopNotifier.dispose();
    _selectedCategoryNotifier.dispose();
    _isCategoriesLoadingNotifier.dispose();
    _bannerTimer?.cancel();
    super.dispose();
  }

  void _startBannerAutoPlay() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      final homeService = context.read<HomeService>();
      if (homeService.gridElements.isEmpty) return;
      
      final nextPage = (_bannerIndexNotifier.value + 1) % homeService.gridElements.length;
      if (_bannerPageController.hasClients) {
        _bannerPageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
        );
      }
    });
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HomeService>().fetchHomeData(refresh: true);
      // Also load full categories with subcategories from CategoryService
      context.read<CategoryService>().fetchCategories(refresh: true);
    });
  }

  void _onScroll() {
    final currentScroll = _scrollController.position.pixels;
    
    // Update scroll offset only if changed significantly (reduces rebuilds)
    if ((currentScroll - _scrollOffsetNotifier.value).abs() > 2) {
      _scrollOffsetNotifier.value = currentScroll;
    }

    // Scroll to top button
    final shouldShow = currentScroll > 500;
    if (shouldShow != _showScrollTopNotifier.value) {
      _showScrollTopNotifier.value = shouldShow;
    }

    // Smart prefetch & load more
    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll > 0) {
      final scrollPercentage = (currentScroll / maxScroll * 100).clamp(0, 100);
      if (scrollPercentage >= 70 && scrollPercentage < 80) {
        context.read<HomeService>().prefetchNextPage();
      }
      if (currentScroll >= maxScroll - 200) {
        context.read<HomeService>().loadMoreProducts();
      }
    }
  }

  Future<void> _onRefresh() async {
    context.read<ProductService>().clearCache();
    await context.read<HomeService>().refresh();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeService = context.watch<HomeService>();
    final statusBarHeight = MediaQuery.of(context).padding.top;

    // Loading state
    if (homeService.isLoading && homeService.homeData == null) {
      return Scaffold(
        body: Center(
          child: Lottie.asset('assets/animations/loadingproducts.json', width: 200, height: 200),
        ),
      );
    }

    // Error state
    if (homeService.error != null && homeService.homeData == null) {
      return Scaffold(
        body: SafeArea(child: HomeErrorState(error: homeService.error!, onRetry: _loadData)),
      );
    }

    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.white,
      floatingActionButton: _buildScrollToTopButton(),
      body: Stack(
        children: [
          // Main Scrollable Content using CustomScrollView for better performance
          RefreshIndicator(
            onRefresh: _onRefresh,
            color: AppColors.primary500,
            backgroundColor: isDark ? const Color(0xFF2A2A2A) : Colors.white,
            displacement: 60,
            strokeWidth: 2.5,
            child: CustomScrollView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              slivers: [
                // Use ValueListenableBuilder to conditionally show/hide content
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    final isCategorySelected = selectedCategory != null;
                    
                    return SliverList(
                      delegate: SliverChildListDelegate([
                        // Banner - hidden when category selected, show just header space
                        if (!isCategorySelected)
                          _BannerSection(
                            homeService: homeService,
                            bannerHeight: _bannerHeight,
                            headerHeight: _headerHeight,
                            pageController: _bannerPageController,
                            indexNotifier: _bannerIndexNotifier,
                          )
                        else
                          // When category selected, just add space for header
                          SizedBox(height: _headerHeight + 16),
                      ]),
                    );
                  },
                ),

                // Error Banner
                if (homeService.error != null)
                  SliverToBoxAdapter(child: _buildErrorBanner(homeService.error!)),

                // Legacy Banners - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    if (homeService.banners.isEmpty || homeService.gridElements.isNotEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: LegacyBannerCarousel(
                          banners: homeService.banners,
                          currentIndex: _bannerIndexNotifier.value,
                          onIndexChanged: (i) => _bannerIndexNotifier.value = i,
                        ),
                      ),
                    );
                  },
                ),

                // Quick Actions Row (Orders, Wallet, Tracking, Rewards) - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return const SliverToBoxAdapter(
                      child: QuickActionsRow(),
                    );
                  },
                ),

                // Categories - always visible
                if (homeService.categories.isNotEmpty)
                  SliverToBoxAdapter(
                    child: RepaintBoundary(
                      child: ValueListenableBuilder<bool>(
                        valueListenable: _isCategoriesLoadingNotifier,
                        builder: (context, isLoading, _) {
                          return ValueListenableBuilder<ProductCategory?>(
                            valueListenable: _selectedCategoryNotifier,
                            builder: (context, selectedCategory, _) {
                              return HomeCategoriesSection(
                                categories: homeService.categories,
                                selectedCategory: selectedCategory,
                                isLoading: isLoading,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),

                // Category Products Grid - shown when category is selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory == null) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return CategoryProductsGrid(
                      key: ValueKey(selectedCategory.id),
                      category: selectedCategory,
                      parentScrollController: _scrollController,
                    );
                  },
                ),

                // Flash Sales - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final flashSales = homeService.flashSales.where((f) => f.isActive).toList();
                          if (index >= flashSales.length) return null;
                          return RepaintBoundary(child: FlashSaleSection(flashSale: flashSales[index]));
                        },
                        childCount: homeService.flashSales.where((f) => f.isActive).length,
                      ),
                    );
                  },
                ),

                // Spacer - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return const SliverToBoxAdapter(child: SizedBox(height: 4));
                  },
                ),

                // Product Sections - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          if (index >= homeService.productSections.length) return null;
                          final section = homeService.productSections[index];
                          return RepaintBoundary(
                            child: Column(
                              children: [
                                ProductSectionWidget(section: section),
                                if ((index + 1) % 2 == 0 && homeService.allProducts.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                                    child: ProductAdBannerWidget(
                                      product: homeService.allProducts[index % homeService.allProducts.length],
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                        childCount: homeService.productSections.length,
                      ),
                    );
                  },
                ),

                // All Products Header - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    if (homeService.allProducts.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverToBoxAdapter(
                      child: _AllProductsHeader(isDark: isDark),
                    );
                  },
                ),

                // Products Grid - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    if (homeService.allProducts.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    
                    // Add skeleton items when loading more
                    final isLoadingMore = homeService.isLoadingMore || homeService.isPrefetching;
                    final skeletonCount = isLoadingMore ? 2 : 0;
                    
                    return SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(12),
                            bottomRight: Radius.circular(12),
                          ),
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
                        child: MasonryGridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 2,
                          mainAxisSpacing: 4,
                          crossAxisSpacing: 4,
                          addAutomaticKeepAlives: false,
                          addRepaintBoundaries: true,
                          itemCount: homeService.allProducts.length + skeletonCount,
                          itemBuilder: (context, index) {
                            // Show skeleton cards at the end when loading
                            if (index >= homeService.allProducts.length) {
                              return _buildPaginationSkeleton(isDark, index);
                            }
                            
                            final product = homeService.allProducts[index];
                            return RepaintBoundary(
                              child: ProductCard.fromProduct(
                                product,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product)),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),

                // End message - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    if (homeService.hasMoreProducts || homeService.allProducts.isEmpty) {
                      return const SliverToBoxAdapter(child: SizedBox.shrink());
                    }
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Center(
                          child: Text(
                            'You\'ve seen it all!',
                            style: AppTypography.bodyMedium(
                              color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Bottom padding
                const SliverToBoxAdapter(child: SizedBox(height: 32)),
              ],
            ),
          ),

          // Fixed Floating Header - uses ValueListenableBuilder to avoid rebuilding entire tree
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: ValueListenableBuilder<ProductCategory?>(
              valueListenable: _selectedCategoryNotifier,
              builder: (context, selectedCategory, _) {
                return ValueListenableBuilder<double>(
                  valueListenable: _scrollOffsetNotifier,
                  builder: (context, scrollOffset, _) {
                    // Force opacity to 1.0 when category is selected (simulates scrolled state)
                    final isCategorySelected = selectedCategory != null;
                    final opacity = isCategorySelected 
                        ? 1.0 
                        : scrollOffset <= 0 
                            ? 0.0 
                            : scrollOffset >= _scrollThreshold 
                                ? 1.0 
                                : (scrollOffset / _scrollThreshold).clamp(0.0, 1.0);
                    
                    // Orange tint for header when at top (light orange in dark mode, strong orange in light mode)
                    final orangeTint = isDark 
                        ? const Color(0xFFFFB366) // Light orange for dark mode
                        : const Color(0xFFFF6B00); // Strong orange for light mode
                    final brandColor = isDark ? const Color(0xFF1A1A1A) : Colors.white;
                    
                    // When at top, use orange tint; when scrolled, use solid brand color
                    final headerBgColor = Color.lerp(orangeTint.withOpacity(0.85), brandColor, opacity)!;
                    // Icons white on orange, transition to dark/white based on theme when scrolled
                    final iconColor = Color.lerp(Colors.white, isDark ? Colors.white : Colors.black87, opacity)!;

                    return FloatingHeader(
                      headerBgColor: headerBgColor,
                      iconColor: iconColor,
                      statusBarHeight: statusBarHeight,
                      opacity: opacity,
                      categories: homeService.categories,
                      selectedCategory: selectedCategory,
                      bannerColor: orangeTint,
                      onCategorySelected: (category) async {
                        if (category == null) {
                          // "All" selected - brief loading then show main categories
                          _isCategoriesLoadingNotifier.value = true;
                          await Future.delayed(const Duration(milliseconds: 200));
                          _selectedCategoryNotifier.value = null;
                          _isCategoriesLoadingNotifier.value = false;
                        } else {
                          // Brief loading feedback for UX
                          _isCategoriesLoadingNotifier.value = true;
                          await Future.delayed(const Duration(milliseconds: 200));
                          // Find the full category with subcategories from CategoryService
                          final categoryService = context.read<CategoryService>();
                          final fullCategory = categoryService.categories.firstWhere(
                            (c) => c.id == category.id,
                            orElse: () => category,
                          );
                          _selectedCategoryNotifier.value = fullCategory;
                          _isCategoriesLoadingNotifier.value = false;
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToTopButton() {
    return ValueListenableBuilder<bool>(
      valueListenable: _showScrollTopNotifier,
      builder: (context, show, _) {
        if (!show) return const SizedBox.shrink();
        return FloatingActionButton(
          onPressed: () {
            _scrollController.animateTo(0, duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
          },
          backgroundColor: AppColors.primary500,
          elevation: 4,
          shape: const CircleBorder(),
          child: const Icon(Iconsax.arrow_up_2, color: Colors.white),
        );
      },
    );
  }

  Widget _buildErrorBanner(String error) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.errorLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.warning_2, color: AppColors.error, size: 20),
          const SizedBox(width: 8),
          Expanded(child: Text(error, style: AppTypography.bodySmall(color: AppColors.error))),
        ],
      ),
    );
  }

  /// Build skeleton loading card for pagination (same style as search results)
  Widget _buildPaginationSkeleton(bool isDark, int index) {
    // Height variation for masonry effect
    final heights = [200.0, 240.0, 220.0, 260.0, 180.0, 230.0, 250.0, 210.0];
    final randomHeight = heights[index % heights.length];
    
    return Container(
      height: randomHeight,
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isDark 
              ? AppColors.neutral800.withOpacity(0.5) 
              : AppColors.neutral200.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image placeholder with fallback image
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                child: Image.asset(
                  'assets/images/productfailbackorskeleton_loading.png',
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),
          ),
          // Text placeholder
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 12,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.neutral700 : AppColors.neutral200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 10,
                  width: 60,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.neutral700 : AppColors.neutral200,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget for banner to avoid rebuilds
class _BannerSection extends StatelessWidget {
  final HomeService homeService;
  final double bannerHeight;
  final double headerHeight;
  final PageController pageController;
  final ValueNotifier<int> indexNotifier;

  const _BannerSection({
    required this.homeService,
    required this.bannerHeight,
    required this.headerHeight,
    required this.pageController,
    required this.indexNotifier,
  });

  @override
  Widget build(BuildContext context) {
    if (homeService.gridElements.isEmpty) {
      return SizedBox(height: headerHeight + bannerHeight);
    }

    // Banner is entirely below the header now
    final totalHeight = headerHeight + bannerHeight;

    return SizedBox(
      height: totalHeight,
      child: Stack(
        children: [
          // Position the banner below the header
          Positioned(
            top: headerHeight,
            left: 0,
            right: 0,
            height: bannerHeight,
            child: PageView.builder(
              controller: pageController,
              itemCount: homeService.gridElements.length,
              onPageChanged: (index) => indexNotifier.value = index,
              itemBuilder: (context, index) {
                final element = homeService.gridElements[index];
                final imageUrl = element is GridElement ? element.imageUrl : '';

                return CachedNetworkImage(
                  imageUrl: ImageHelper.parse(imageUrl) ?? '',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: bannerHeight,
                  memCacheWidth: 800,
                  placeholder: (_, __) => Container(color: AppColors.neutral100),
                  errorWidget: (_, __, ___) => Container(
                    color: AppColors.neutral200,
                    child: const Icon(Iconsax.image, size: 48, color: AppColors.neutral400),
                  ),
                );
              },
            ),
          ),

          // Gradient overlay - subtle (positioned within the banner area)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: 50,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.2)],
                ),
              ),
            ),
          ),

          // Page Indicator (positioned within the banner area)
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: ValueListenableBuilder<int>(
                valueListenable: indexNotifier,
                builder: (context, currentIndex, _) {
                  return AnimatedSmoothIndicator(
                    activeIndex: currentIndex,
                    count: homeService.gridElements.length,
                    effect: const ExpandingDotsEffect(
                      dotHeight: 6,
                      dotWidth: 6,
                      activeDotColor: Colors.white,
                      dotColor: Colors.white54,
                      spacing: 6,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Separate widget for All Products header
class _AllProductsHeader extends StatelessWidget {
  final bool isDark;

  const _AllProductsHeader({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'All Products',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          GestureDetector(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const AllProductsScreen()));
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
                Icon(Iconsax.arrow_right_3, size: 16, color: AppColors.primary500),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
