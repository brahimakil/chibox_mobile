import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'dart:async';
import '../../../core/theme/theme.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/product_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/navigation_provider.dart';
import '../../../core/models/home_data_model.dart' show GridElement;
import '../../../core/models/product_model.dart';
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
import '../widgets/hot_sellings_section.dart';
import '../widgets/category_products_grid.dart';
import '../widgets/quick_actions_row.dart';
import '../widgets/promo_banner_widget.dart';
import '../../../shared/widgets/widgets.dart';
import 'all_products_screen.dart';
import 'unified_products_grid_screen.dart';

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
    
    // Listen for home reset requests and register category clear callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navProvider = context.read<NavigationProvider>();
      navProvider.addListener(_onNavigationChange);
      
      // Register callback to clear category selection (for back button handling)
      navProvider.registerHomeCategoryClearCallback(_clearCategorySelection);
    });
    
    // Listen for category selection changes to update NavigationProvider
    _selectedCategoryNotifier.addListener(_onCategorySelectionChanged);
  }
  
  void _onCategorySelectionChanged() {
    final navProvider = context.read<NavigationProvider>();
    navProvider.setHomeCategorySelected(_selectedCategoryNotifier.value != null);
  }
  
  void _clearCategorySelection() {
    _selectedCategoryNotifier.value = null;
    // Scroll to top when clearing category
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }
  
  void _onNavigationChange() {
    final navProvider = context.read<NavigationProvider>();
    if (navProvider.consumeResetHomeFlag()) {
      _resetHome();
    }
  }
  
  void _resetHome() {
    // Scroll to top
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
    // Clear selected category
    _selectedCategoryNotifier.value = null;
  }

  @override
  void dispose() {
    // Remove navigation listener and unregister callback
    try {
      final navProvider = context.read<NavigationProvider>();
      navProvider.removeListener(_onNavigationChange);
      navProvider.unregisterHomeCategoryClearCallback();
      navProvider.setHomeCategorySelected(false);
    } catch (_) {}
    _selectedCategoryNotifier.removeListener(_onCategorySelectionChanged);
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
      final homeService = context.read<HomeService>();
      final categoryService = context.read<CategoryService>();
      
      // Only fetch if data wasn't preloaded during splash
      if (homeService.homeData == null) {
        homeService.fetchHomeData();
      }
      if (categoryService.categories.isEmpty) {
        categoryService.fetchCategories();
      }
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
      // Prefetch at 50% - loads in background silently
      if (scrollPercentage >= 50) {
        context.read<HomeService>().prefetchNextPage();
      }
      // Load more at 80% - triggers skeleton and fetches next page
      if (scrollPercentage >= 80) {
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

    // Loading state - show skeleton instead of blocking animation
    if (homeService.isLoading && homeService.homeData == null) {
      return Scaffold(
        backgroundColor: isDark ? Colors.black : Colors.white,
        body: SafeArea(
          child: _buildSkeletonLoading(isDark),
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

                // Promo Banner - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return const SliverToBoxAdapter(
                      child: PromoBannerWidget(),
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

                // Hot Sellings - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    // Show section with skeleton during loading, or with products when loaded
                    final isLoading = homeService.isLoading && homeService.hotSellings.isEmpty;
                    if (homeService.hotSellings.isEmpty && !isLoading) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: HotSellingsSection(
                          products: homeService.hotSellings,
                          isLoading: isLoading,
                        ),
                      ),
                    );
                  },
                ),

                // Price Deals Sections ($1, $2, $5, $7) - hide when category selected
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    // Show section with skeleton during loading
                    final isLoading = homeService.isLoading && homeService.oneDollarProducts.isEmpty;
                    if (homeService.oneDollarProducts.isEmpty && !isLoading) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    return SliverToBoxAdapter(
                      child: RepaintBoundary(
                        child: _PriceDealsTabsSection(
                          products: homeService.oneDollarProducts,
                          isLoading: isLoading,
                        ),
                      ),
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

                // Products Grid Sliver - lazy loading for performance
                ValueListenableBuilder<ProductCategory?>(
                  valueListenable: _selectedCategoryNotifier,
                  builder: (context, selectedCategory, _) {
                    if (selectedCategory != null) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    if (homeService.allProducts.isEmpty) return const SliverToBoxAdapter(child: SizedBox.shrink());
                    
                    // Show skeleton when loading more products or prefetching
                    final showSkeleton = homeService.isLoadingMore || homeService.isPrefetching;
                    final skeletonCount = showSkeleton ? 4 : 0;
                    
                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 2, 12, 0),
                      sliver: SliverMasonryGrid.count(
                        crossAxisCount: 2,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                        childCount: homeService.allProducts.length + skeletonCount,
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

  /// Build skeleton loading for initial app load - shows immediately
  Widget _buildSkeletonLoading(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search bar skeleton
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: baseColor,
                  borderRadius: BorderRadius.circular(22),
                ),
              ),
            ),
          ),
          
          // Category tabs skeleton
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 36,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: List.generate(5, (index) => Container(
                  width: 60,
                  height: 28,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    color: baseColor,
                    borderRadius: BorderRadius.circular(14),
                  ),
                )),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Banner skeleton
          Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              height: 180,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Quick actions skeleton
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Shimmer.fromColors(
              baseColor: baseColor,
              highlightColor: highlightColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(4, (index) => Column(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: baseColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      width: 50,
                      height: 10,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                )),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Categories section skeleton with fallback images
          Container(
            height: 220,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: List.generate(5, (colIndex) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(2, (rowIndex) => Container(
                      width: 76,
                      height: 95,
                      margin: const EdgeInsets.only(right: 8, bottom: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Category image with fallback
                          Container(
                            width: 54,
                            height: 54,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark ? Colors.grey[800] : Colors.grey[100],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/category_loadingorfailbak.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Text skeleton
                          Shimmer.fromColors(
                            baseColor: baseColor,
                            highlightColor: highlightColor,
                            child: Container(
                              width: 50,
                              height: 10,
                              decoration: BoxDecoration(
                                color: baseColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )),
                  )),
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Products grid skeleton with fallback images
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: MasonryGridView.count(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              itemBuilder: (context, index) {
                final heights = [200.0, 240.0, 220.0, 260.0, 180.0, 230.0];
                final height = heights[index % heights.length];
                
                return Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image with fallback
                      Expanded(
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(7)),
                          child: Image.asset(
                            'assets/images/productfailbackorskeleton_loading.png',
                            fit: BoxFit.cover,
                            width: double.infinity,
                          ),
                        ),
                      ),
                      // Text skeleton
                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Shimmer.fromColors(
                          baseColor: baseColor,
                          highlightColor: highlightColor,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: double.infinity,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: baseColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                width: 60,
                                height: 14,
                                decoration: BoxDecoration(
                                  color: baseColor,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
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
      margin: const EdgeInsets.fromLTRB(8, 4, 8, 0),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
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

/// Price Deals Tabs Section - Shows $1, $2, $5, $7 deal tabs
class _PriceDealsTabsSection extends StatefulWidget {
  final List<Product> products;
  final bool isLoading;

  const _PriceDealsTabsSection({
    required this.products,
    this.isLoading = false,
  });

  @override
  State<_PriceDealsTabsSection> createState() => _PriceDealsTabsSectionState();
}

class _PriceDealsTabsSectionState extends State<_PriceDealsTabsSection> {
  int _selectedTab = 0;

  // Price ranges for tabs
  static const List<Map<String, dynamic>> _priceRanges = [
    {'label': '\$1', 'min': 0.01, 'max': 1.0, 'color': Color(0xFF00C853)},
    {'label': '\$2', 'min': 1.01, 'max': 2.0, 'color': Color(0xFF2196F3)},
    {'label': '\$5', 'min': 2.01, 'max': 5.0, 'color': Color(0xFF9C27B0)},
    {'label': '\$7', 'min': 5.01, 'max': 7.0, 'color': Color(0xFFFF9800)},
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final range = _priceRanges[_selectedTab];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with tabs
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [range['color'] as Color, (range['color'] as Color).withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Icon(
                    Iconsax.dollar_circle,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Price Deals',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                ),
                const Spacer(),
                // See All button
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => UnifiedProductsGridScreen(
                          config: ProductGridConfig.priceDeals(
                            title: '${range['label']} Deals',
                            minPrice: range['min'] as double,
                            maxPrice: range['max'] as double,
                          ),
                        ),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        'See All',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary500,
                        ),
                      ),
                      const SizedBox(width: 3),
                      Icon(
                        Iconsax.arrow_right_3,
                        size: 14,
                        color: AppColors.primary500,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Price Range Tabs
          SizedBox(
            height: 32,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              itemCount: _priceRanges.length,
              itemBuilder: (context, index) {
                final isSelected = _selectedTab == index;
                final tabRange = _priceRanges[index];
                final color = tabRange['color'] as Color;

                return GestureDetector(
                  onTap: () => setState(() => _selectedTab = index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: EdgeInsets.only(right: index < _priceRanges.length - 1 ? 8 : 0),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: isSelected
                          ? LinearGradient(
                              colors: [color, color.withOpacity(0.8)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : (isDark ? Colors.grey[800] : Colors.grey[200]),
                      borderRadius: BorderRadius.circular(16),
                      border: isSelected
                          ? null
                          : Border.all(
                              color: color.withOpacity(0.3),
                              width: 1,
                            ),
                    ),
                    child: Text(
                      'Under ${tabRange['label']}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected
                            ? Colors.white
                            : (isDark ? Colors.white70 : Colors.black87),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),

          // Products for selected tab (using PriceDealsSection's product cards)
          SizedBox(
            height: 200,
            child: widget.isLoading
                ? _buildSkeletonList(isDark)
                : _PriceDealsProductList(
                    key: ValueKey('price_deals_${range['min']}_${range['max']}'),
                    minPrice: range['min'] as double,
                    maxPrice: range['max'] as double,
                    accentColor: range['color'] as Color,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 0 : 4,
            right: index == 4 ? 0 : 4,
          ),
          child: Shimmer.fromColors(
            baseColor: baseColor,
            highlightColor: highlightColor,
            child: Container(
              width: 130,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Image placeholder
                  Container(
                    height: 130,
                    decoration: BoxDecoration(
                      color: baseColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Title placeholder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      height: 12,
                      width: 100,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Price placeholder
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Container(
                      height: 14,
                      width: 60,
                      decoration: BoxDecoration(
                        color: baseColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Product list that fetches from API based on price range
class _PriceDealsProductList extends StatefulWidget {
  final double minPrice;
  final double maxPrice;
  final Color accentColor;

  const _PriceDealsProductList({
    super.key,
    required this.minPrice,
    required this.maxPrice,
    required this.accentColor,
  });

  @override
  State<_PriceDealsProductList> createState() => _PriceDealsProductListState();
}

class _PriceDealsProductListState extends State<_PriceDealsProductList> {
  List<Product> _products = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void didUpdateWidget(covariant _PriceDealsProductList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minPrice != widget.minPrice || oldWidget.maxPrice != widget.maxPrice) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      final result = await homeService.getOneDollarProductsPaginated(
        page: 1,
        perPage: 15,
        minPrice: widget.minPrice,
        maxPrice: widget.maxPrice,
      );

      if (mounted) {
        setState(() {
          _products = (result['products'] as List<Product>?) ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        physics: const NeverScrollableScrollPhysics(),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 4,
              right: index == 4 ? 0 : 4,
            ),
            child: SizedBox(
              width: 130,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark 
                        ? Colors.white.withOpacity(0.08) 
                        : Colors.black.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Image placeholder with the man image
                    Expanded(
                      child: ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                        child: Image.asset(
                          'assets/images/productfailbackorskeleton_loading.png',
                          width: double.infinity,
                          height: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    // Product Info placeholder
                    Padding(
                      padding: const EdgeInsets.all(6),
                      child: Shimmer.fromColors(
                        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              height: 10,
                              width: 100,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 10,
                              width: 60,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.grey[800] : Colors.grey[300],
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    if (_error != null || _products.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.box_remove,
              size: 32,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
            const SizedBox(height: 8),
            Text(
              'No products found',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.black54,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      itemCount: _products.length,
      itemBuilder: (context, index) {
        final product = _products[index];
        return Padding(
          padding: EdgeInsets.only(
            left: index == 0 ? 0 : 4,
            right: index == _products.length - 1 ? 0 : 4,
          ),
          child: SizedBox(
            width: 130,
            child: _PriceDealsProductCard(
              product: product,
              accentColor: widget.accentColor,
            ),
          ),
        );
      },
    );
  }
}

/// Individual product card for price deals
class _PriceDealsProductCard extends StatelessWidget {
  final Product product;
  final Color accentColor;

  const _PriceDealsProductCard({
    required this.product,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark 
                ? Colors.white.withOpacity(0.08) 
                : Colors.black.withOpacity(0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(9)),
                child: CachedNetworkImage(
                  imageUrl: product.mainImage,
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Image.asset(
                    'assets/images/productfailbackorskeleton_loading.png',
                    fit: BoxFit.cover,
                  ),
                  errorWidget: (context, url, error) => Image.asset(
                    'assets/images/productfailbackorskeleton_loading.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            // Product Info
            Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.displayName ?? product.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Price with deal highlight
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.2),
                          accentColor.withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '\$${product.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
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
