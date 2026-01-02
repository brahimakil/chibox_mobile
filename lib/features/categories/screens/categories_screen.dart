import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/navigation_provider.dart';
import '../../../core/models/category_model.dart';
import '../../../shared/widgets/widgets.dart';
import 'category_products_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  String _searchQuery = '';
  int _selectedCategoryIndex = 0;
  final ScrollController _leftPanelScrollController = ScrollController();
  final ScrollController _rightPanelScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryService>(context, listen: false).fetchCategories(refresh: true);
    });
    
    _leftPanelScrollController.addListener(_onLeftPanelScroll);
  }

  @override
  void dispose() {
    _leftPanelScrollController.dispose();
    _rightPanelScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onLeftPanelScroll() {
    if (_leftPanelScrollController.position.pixels >= _leftPanelScrollController.position.maxScrollExtent - 100) {
      Provider.of<CategoryService>(context, listen: false).fetchCategories();
    }
  }

  // --- Search Logic (Kept from previous implementation) ---
  List<ProductCategory> _filterCategories(List<ProductCategory> categories, String query) {
    if (query.isEmpty) return categories;
    
    final queryWords = query.trim().toLowerCase().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).toList();
    if (queryWords.isEmpty) return categories;

    final List<ProductCategory> filtered = [];

    for (var category in categories) {
      final categoryNameLower = category.name.toLowerCase();
      final bool mainMatches = queryWords.every((word) => categoryNameLower.contains(word));
      
      List<ProductCategory>? matchingSubs;
      if (category.subcategories != null) {
        matchingSubs = category.subcategories!.where((sub) {
          final subNameLower = sub.name.toLowerCase();
          return queryWords.every((word) => subNameLower.contains(word));
        }).toList();
      }

      if (mainMatches) {
        if (matchingSubs != null && matchingSubs.isNotEmpty) {
          final otherSubs = category.subcategories!
              .where((sub) => !matchingSubs!.contains(sub))
              .toList();
          
          filtered.add(category.copyWith(
            subcategories: [...matchingSubs, ...otherSubs],
            subcategoriesCount: category.subcategories!.length,
          ));
        } else {
          filtered.add(category);
        }
      } else if (matchingSubs != null && matchingSubs.isNotEmpty) {
        filtered.add(category.copyWith(
          subcategories: matchingSubs,
          subcategoriesCount: matchingSubs.length,
        ));
      }
    }
    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final categoryService = Provider.of<CategoryService>(context);
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final categories = categoryService.categories;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Check if we should auto-select a category from navigation
    if (navigationProvider.selectedCategoryId != null && categories.isNotEmpty) {
      final targetId = navigationProvider.selectedCategoryId;
      final index = categories.indexWhere((c) => c.id == targetId);
      if (index != -1 && _selectedCategoryIndex != index) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() => _selectedCategoryIndex = index);
          navigationProvider.clearSelectedCategory();
          // Scroll to the selected category in the left panel
          if (_leftPanelScrollController.hasClients) {
            final targetScroll = (index * 80.0).clamp(0.0, _leftPanelScrollController.position.maxScrollExtent);
            _leftPanelScrollController.animateTo(
              targetScroll,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.neutral900 : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // --- Search Bar ---
            Padding(
              padding: const EdgeInsets.all(AppSpacing.base),
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.neutral800 : AppColors.neutral50,
                  borderRadius: BorderRadius.circular(24), // More rounded like SHEIN
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.transparent,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: 'Search categories...',
                    hintStyle: AppTypography.bodyMedium(
                      color: AppColors.neutral400,
                    ),
                    prefixIcon: const Icon(
                      Iconsax.search_normal,
                      color: AppColors.neutral400,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Iconsax.close_circle,
                              color: AppColors.neutral400,
                              size: 20,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _searchQuery = '';
                              });
                              _searchFocusNode.unfocus();
                            },
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            // --- Main Content ---
            Expanded(
              child: _searchQuery.isNotEmpty
                  ? _buildSearchResults(categories, isDark, categoryService)
                  : _buildSplitLayout(categories, isDark, categoryService),
            ),
          ],
        ),
      ),
    );
  }

  // --- Split Layout (SHEIN Style) ---
  Widget _buildSplitLayout(List<ProductCategory> categories, bool isDark, CategoryService service) {
    if (service.isLoading && categories.isEmpty) {
      return Center(
        child: Lottie.asset(
          'assets/animations/loadingproducts.json',
          width: 150,
          height: 150,
        ),
      );
    }

    if (service.error != null && categories.isEmpty) {
      return _ErrorState(
        error: service.error!,
        onRetry: () => service.fetchCategories(refresh: true),
      );
    }

    if (categories.isEmpty) {
      return Center(child: Text('No categories available'));
    }

    // Ensure selected index is valid
    if (_selectedCategoryIndex >= categories.length) {
      _selectedCategoryIndex = 0;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Left Panel (Categories) ---
        Container(
          width: 100, // Fixed width
          color: isDark ? AppColors.neutral900 : const Color(0xFFF6F6F6), // Light grey background
          child: ListView.builder(
            controller: _leftPanelScrollController,
            itemCount: categories.length + (service.hasMore ? 1 : 0),
            physics: const BouncingScrollPhysics(),
            itemBuilder: (context, index) {
              if (index == categories.length) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
                );
              }

              final category = categories[index];
              final isSelected = index == _selectedCategoryIndex;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedCategoryIndex = index;
                  });
                  // Reset right panel scroll
                  if (_rightPanelScrollController.hasClients) {
                    _rightPanelScrollController.jumpTo(0);
                  }
                },
                child: Container(
                  // Removed fixed height to allow expansion
                  color: isSelected 
                      ? (isDark ? AppColors.neutral800 : Colors.white) 
                      : Colors.transparent,
                  child: Stack(
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 4.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Category Icon or Fallback
                            category.mainImage != null && category.mainImage!.trim().isNotEmpty
                                ? CachedNetworkImage(
                                    imageUrl: category.mainImage!.trim(),
                                    width: 24, // Smaller icon size
                                    height: 24,
                                    fit: BoxFit.cover,
                                    httpHeaders: const {
                                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                    },
                                    errorWidget: (context, url, error) => Image.asset(
                                      'assets/images/category_loadingorfailbak.png',
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                    ),
                                  )
                                : Image.asset(
                                    'assets/images/category_loadingorfailbak.png',
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                  ),
                            const SizedBox(height: 4),
                            Text(
                              category.name,
                              textAlign: TextAlign.center,
                              // Removed maxLines to allow full expansion
                              style: isSelected
                                  ? AppTypography.bodySmall(color: isDark ? Colors.white : Colors.black).copyWith(fontWeight: FontWeight.bold, fontSize: 10) // Smaller font
                                  : AppTypography.bodySmall(color: isDark ? AppColors.neutral400 : AppColors.neutral600).copyWith(fontSize: 10), // Smaller font
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: 4,
                            color: AppColors.primary500, // Highlight strip
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // --- Right Panel (Subcategories) ---
        Expanded(
          child: Container(
            color: isDark ? AppColors.neutral800 : Colors.white,
            child: _buildRightPanelContent(categories[_selectedCategoryIndex], isDark),
          ),
        ),
      ],
    );
  }

  Widget _buildRightPanelContent(ProductCategory category, bool isDark) {
    final subcategories = category.subcategories ?? [];

    return ListView(
      controller: _rightPanelScrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Header Image & Title (Optional, like SHEIN often has a banner)
        if (category.mainImage != null && category.mainImage!.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: category.mainImage!.trim(),
                height: 100,
                width: double.infinity,
                fit: BoxFit.cover,
                httpHeaders: const {
                  'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                },
                errorWidget: (context, url, error) => Image.asset(
                  'assets/images/category_loadingorfailbak.png',
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                category.name,
                style: AppTypography.headingSmall(color: isDark ? Colors.white : Colors.black),
              ),
            ),
            TextButton(
              onPressed: () {
                 Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryProductsScreen(category: category),
                  ),
                );
              },
              child: Text(
                'View All >',
                style: AppTypography.bodySmall(color: AppColors.neutral500),
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 16),

        if (subcategories.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: [
                  Icon(Iconsax.category_2, size: 48, color: AppColors.neutral300),
                  const SizedBox(height: 8),
                  Text(
                    'No subcategories',
                    style: AppTypography.bodyMedium(color: AppColors.neutral400),
                  ),
                ],
              ),
            ),
          )
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 columns like SHEIN
              childAspectRatio: 0.75,
              crossAxisSpacing: 12,
              mainAxisSpacing: 16,
            ),
            itemCount: subcategories.length,
            itemBuilder: (context, index) {
              final sub = subcategories[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque, // Ensure taps are caught even on empty space
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryProductsScreen(category: sub),
                    ),
                  );
                },
                child: Column(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.neutral900 : AppColors.neutral50,
                          shape: BoxShape.circle, // Circular images often look good
                        ),
                        child: ClipOval(
                          child: sub.mainImage != null && sub.mainImage!.trim().isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: sub.mainImage!.trim(),
                                  fit: BoxFit.cover,
                                  httpHeaders: const {
                                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                  },
                                  placeholder: (context, url) => Image.asset(
                                    'assets/images/category_loadingorfailbak.png',
                                    fit: BoxFit.cover,
                                  ),
                                  errorWidget: (context, url, error) => Image.asset(
                                    'assets/images/category_loadingorfailbak.png',
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/category_loadingorfailbak.png',
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Flexible(
                      child: Text(
                        sub.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(
                          color: isDark ? AppColors.neutral300 : AppColors.neutral700,
                        ).copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          
          const SizedBox(height: 40), // Bottom padding
      ],
    );
  }

  // --- Search Results (Flat List) ---
  Widget _buildSearchResults(List<ProductCategory> categories, bool isDark, CategoryService service) {
    final filteredCategories = _filterCategories(categories, _searchQuery);

    if (filteredCategories.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Lottie.asset(
              'assets/animations/search_empty.json',
              width: 200,
              height: 200,
              errorBuilder: (context, error, stackTrace) {
                return Icon(
                  Iconsax.search_status,
                  size: 64,
                  color: isDark ? AppColors.neutral600 : AppColors.neutral300,
                );
              },
            ),
            const SizedBox(height: 16),
            Text(
              'No categories found',
              style: AppTypography.bodyLarge(
                color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.base),
      itemCount: filteredCategories.length,
      itemBuilder: (context, index) {
        final category = filteredCategories[index];
        return _CategoryListItem(
          category: category,
          index: index,
          isSearching: true,
        );
      },
    );
  }
}

// --- Reused List Item for Search Results ---
class _CategoryListItem extends StatelessWidget {
  final ProductCategory category;
  final int index;
  final bool isSearching;

  const _CategoryListItem({
    required this.category,
    required this.index,
    this.isSearching = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasSubcategories = category.subcategories != null && category.subcategories!.isNotEmpty;

    // Generate a consistent color based on index for the ring
    final List<Color> ringColors = [
      const Color(0xFFFF6B6B), // Red
      const Color(0xFF4ECDC4), // Teal
      const Color(0xFFFFD93D), // Yellow
      const Color(0xFF6C5CE7), // Purple
      const Color(0xFFA8E6CF), // Mint
      const Color(0xFFFF8B94), // Pink
    ];
    final ringColor = ringColors[index % ringColors.length];

    Widget buildLeading() {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: ringColor.withOpacity(0.5),
            width: 2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.black : AppColors.neutral50,
          ),
          child: ClipOval(
            child: category.mainImage != null && category.mainImage!.trim().isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: category.mainImage!.trim(),
                    httpHeaders: const {
                      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                    },
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Image.asset(
                      'assets/images/category_loadingorfailbak.png',
                      fit: BoxFit.cover,
                    ),
                    errorWidget: (context, url, error) => Image.asset(
                      'assets/images/category_loadingorfailbak.png',
                      fit: BoxFit.cover,
                    ),
                  )
                : Image.asset(
                    'assets/images/category_loadingorfailbak.png',
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      );
    }

    if (!hasSubcategories) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.neutral800 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? Colors.white10 : AppColors.neutral200,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: buildLeading(),
            title: Text(
              category.name,
              style: AppTypography.bodyLarge(
                color: isDark ? Colors.white : AppColors.neutral900,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            trailing: Icon(
              Iconsax.arrow_right_3,
              size: 16,
              color: isDark ? AppColors.neutral400 : AppColors.neutral500,
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CategoryProductsScreen(
                    category: category,
                  ),
                ),
              );
            },
          ),
        ),
      ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.neutral800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white10 : AppColors.neutral200,
          ),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            key: ValueKey('${category.id}_$isSearching'), // Force rebuild when search state changes
            initiallyExpanded: isSearching,
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: buildLeading(),
            title: Text(
              category.name,
              style: AppTypography.bodyLarge(
                color: isDark ? Colors.white : AppColors.neutral900,
              ).copyWith(fontWeight: FontWeight.w600),
            ),
            childrenPadding: EdgeInsets.zero,
            children: [
              // "All Products" option
              ListTile(
                contentPadding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                title: Text(
                  'All ${category.name}',
                  style: AppTypography.bodyMedium(
                    color: AppColors.primary500,
                  ).copyWith(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(
                  Iconsax.arrow_right_3,
                  size: 14,
                  color: AppColors.primary500,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryProductsScreen(
                        category: category,
                      ),
                    ),
                  );
                },
              ),
              // Subcategories
              ...category.subcategories!.map((sub) {
                return ListTile(
                  contentPadding: const EdgeInsets.only(left: 72, right: 16, bottom: 8),
                  title: Text(
                    sub.name,
                    style: AppTypography.bodyMedium(
                      color: isDark ? AppColors.neutral300 : AppColors.neutral700,
                    ),
                  ),
                  trailing: Icon(
                    Iconsax.arrow_right_3,
                    size: 14,
                    color: isDark ? AppColors.neutral600 : AppColors.neutral400,
                  ),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => CategoryProductsScreen(
                          category: sub,
                        ),
                      ),
                    );
                  },
                );
              }).toList(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(delay: Duration(milliseconds: 50 * index)).slideX();
  }
}

// Error State Widget
class _ErrorState extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;

  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SingleChildScrollView(
      padding: AppSpacing.paddingHorizontalBase,
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: isDark ? AppColors.error.withOpacity(0.15) : AppColors.errorLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.wifi_square,
                size: 48,
                color: AppColors.error,
              ),
            )
                .animate()
                .scale(duration: 500.ms, curve: Curves.elasticOut),
            AppSpacing.verticalXl,
            Text(
              'Oops! Something went wrong',
              style: AppTypography.headingMedium(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 200.ms),
            AppSpacing.verticalSm,
            Text(
              error,
              style: AppTypography.bodyMedium(
                color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            )
                .animate()
                .fadeIn(delay: 300.ms),
            AppSpacing.verticalXxl,
            AppButton(
              text: 'Try Again',
              onPressed: onRetry,
              leftIcon: Iconsax.refresh,
              fullWidth: false,
            )
                .animate()
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.3, end: 0),
          ],
        ),
      ),
    );
  }
}
