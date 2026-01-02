import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/category_model.dart' show ProductCategory;
import '../../../core/services/navigation_provider.dart';
import '../../../core/services/category_service.dart';
import '../../../core/utils/image_helper.dart';
import '../../categories/screens/category_products_screen.dart';

/// Categories Section - 2 row horizontally scrollable grid (SHEIN style)
/// Shows subcategories when a parent category is selected from the header
class HomeCategoriesSection extends StatefulWidget {
  final List<ProductCategory> categories;
  final ProductCategory? selectedCategory;
  final bool isLoading;

  const HomeCategoriesSection({
    super.key,
    required this.categories,
    this.selectedCategory,
    this.isLoading = false,
  });

  @override
  State<HomeCategoriesSection> createState() => _HomeCategoriesSectionState();
}

class _HomeCategoriesSectionState extends State<HomeCategoriesSection> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // Load more when near the end (within 100 pixels)
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 100) {
      final categoryService = context.read<CategoryService>();
      if (categoryService.hasMore && !categoryService.isLoading) {
        categoryService.fetchCategories();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.categories.isEmpty) return const SizedBox.shrink();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final categoryService = context.watch<CategoryService>();

    // Show skeleton loading state
    if (widget.isLoading) {
      return _buildSkeletonLoading(isDark);
    }

    // Determine which items to show
    final List<ProductCategory> displayItems;
    final bool showingSubcategories;
    
    if (widget.selectedCategory != null && widget.selectedCategory!.subcategories != null && widget.selectedCategory!.subcategories!.isNotEmpty) {
      // Show subcategories of selected category
      displayItems = widget.selectedCategory!.subcategories!;
      showingSubcategories = true;
    } else if (widget.selectedCategory != null) {
      // Category is selected but has no subcategories - show nothing
      return const SizedBox.shrink();
    } else {
      // Show main categories from CategoryService (has pagination)
      displayItems = List.from(categoryService.categories.isNotEmpty ? categoryService.categories : widget.categories);
      showingSubcategories = false;
    }

    // Add "All" as the last item only when showing main categories
    final itemCount = showingSubcategories ? displayItems.length : displayItems.length + 1;
    
    // If showing subcategories, use vertical scrollable list
    if (showingSubcategories) {
      return _buildVerticalSubcategoriesList(context, displayItems, isDark);
    }
    
    // Dynamic row distribution for better visual balance
    // For small counts, prefer more items on top row
    int topRowCount;
    int bottomRowCount;
    
    if (itemCount <= 1) {
      topRowCount = itemCount;
      bottomRowCount = 0;
    } else if (itemCount <= 3) {
      // 2 items: 2 top, 0 bottom | 3 items: 2 top, 1 bottom
      topRowCount = 2;
      bottomRowCount = itemCount - 2;
    } else if (itemCount <= 6) {
      // 4: 3-1, 5: 3-2, 6: 4-2
      topRowCount = (itemCount * 0.6).ceil();
      bottomRowCount = itemCount - topRowCount;
    } else if (itemCount <= 10) {
      // 7: 4-3, 8: 5-3, 9: 5-4, 10: 6-4
      topRowCount = (itemCount * 0.55).ceil();
      bottomRowCount = itemCount - topRowCount;
    } else {
      // 11+: balanced distribution (roughly equal)
      topRowCount = (itemCount / 2).ceil();
      bottomRowCount = itemCount - topRowCount;
    }
    
    // Add extra columns for loading indicator
    final extraColumns = categoryService.hasMore ? 1 : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // 2-row horizontal scrollable grid with SHEIN-style card container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220, // Height for 2 rows (2 items x 95 + 16 padding + buffer)
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Build columns based on dynamic distribution
                    // Top row items get their own columns, bottom row items fill in
                    ...List.generate(topRowCount, (topIndex) {
                      // Find corresponding bottom index
                      final bottomIndex = topIndex < bottomRowCount ? topRowCount + topIndex : -1;
                      
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Top item
                          _buildCategoryItem(context, topIndex, isDark, displayItems, false),
                          // Bottom item (if exists for this column)
                          if (bottomIndex >= 0 && bottomIndex < itemCount)
                            _buildCategoryItem(context, bottomIndex, isDark, displayItems, false),
                        ],
                      );
                    }),
                    // Loading indicator at end
                    if (extraColumns > 0 && categoryService.isLoading)
                      _buildLoadingColumn(isDark),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }

  /// Builds a vertical scrollable list of subcategories
  Widget _buildVerticalSubcategoriesList(BuildContext context, List<ProductCategory> subcategories, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // View All header - goes to subcategories page
                InkWell(
                  onTap: () {
                    // Navigate to Categories tab with this category pre-selected
                    Provider.of<NavigationProvider>(context, listen: false)
                        .goToCategoriesWithSelection(widget.selectedCategory!.id);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Subcategories',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Row(
                          children: [
                            Text(
                              'View All',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppColors.primary500,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              Iconsax.arrow_right_3,
                              size: 16,
                              color: AppColors.primary500,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
                // Subcategories list
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 260),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: subcategories.map((subcategory) {
                        return _SubcategoryListItem(
                          category: subcategory,
                          isDark: isDark,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CategoryProductsScreen(category: subcategory),
                              ),
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildLoadingColumn(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildSkeletonItem(baseColor, highlightColor),
        _buildSkeletonItem(baseColor, highlightColor),
      ],
    );
  }

  Widget _buildSkeletonLoading(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        // Skeleton grid in card container
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 8),
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
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              height: 220,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(5, (colIndex) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildSkeletonItem(baseColor, highlightColor),
                        _buildSkeletonItem(baseColor, highlightColor),
                      ],
                    );
                  }),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildSkeletonItem(Color baseColor, Color highlightColor) {
    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: 76,
        height: 95,
        margin: const EdgeInsets.only(right: 8, bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circle skeleton
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor,
              ),
            ),
            const SizedBox(height: 6),
            // Text skeleton
            Container(
              width: 50,
              height: 10,
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(BuildContext context, int index, bool isDark, List<ProductCategory> displayItems, bool showingSubcategories) {
    // Last item is "All Categories" button (only when showing main categories)
    if (!showingSubcategories && index == displayItems.length) {
      return _AllCategoriesButton(
        isDark: isDark,
        onTap: () {
          Provider.of<NavigationProvider>(context, listen: false).setIndex(1);
        },
      );
    }

    final category = displayItems[index];
    return _CategoryItem(
      category: category,
      isDark: isDark,
      isSubcategory: showingSubcategories,
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryProductsScreen(category: category),
          ),
        );
      },
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final ProductCategory category;
  final bool isDark;
  final bool isSubcategory;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.isDark,
    this.isSubcategory = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 95,
        margin: const EdgeInsets.only(right: 8, bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circular image
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.grey[800] : Colors.grey[100],
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipOval(
                child: CachedNetworkImage(
                  imageUrl: ImageHelper.parse(category.mainImage) ?? '',
                  fit: BoxFit.cover,
                  memCacheWidth: 120,
                  placeholder: (_, __) => Image.asset(
                    'assets/images/category_loadingorfailbak.png',
                    fit: BoxFit.cover,
                  ),
                  errorWidget: (_, __, ___) => Image.asset(
                    'assets/images/category_loadingorfailbak.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Name
            Flexible(
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white70 : Colors.black87,
                  height: 1.2,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AllCategoriesButton extends StatelessWidget {
  final bool isDark;
  final VoidCallback onTap;

  const _AllCategoriesButton({
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 95,
        margin: const EdgeInsets.only(right: 8, bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary500.withOpacity(0.1),
                border: Border.all(
                  color: AppColors.primary500.withOpacity(0.3),
                  width: 1.5,
                ),
              ),
              child: const Icon(
                Icons.grid_view_rounded,
                size: 22,
                color: AppColors.primary500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppColors.primary500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Subcategory list item for vertical scrollable list
class _SubcategoryListItem extends StatelessWidget {
  final ProductCategory category;
  final bool isDark;
  final VoidCallback onTap;

  const _SubcategoryListItem({
    required this.category,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            // Category image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: ImageHelper.parse(category.mainImage ?? '') ?? '',
                width: 44,
                height: 44,
                fit: BoxFit.cover,
                placeholder: (_, __) => Image.asset(
                  'assets/images/category_loadingorfailbak.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
                errorWidget: (_, __, ___) => Image.asset(
                  'assets/images/category_loadingorfailbak.png',
                  width: 44,
                  height: 44,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Category name
            Expanded(
              child: Text(
                category.name,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // Arrow icon
            Icon(
              Iconsax.arrow_right_3,
              size: 18,
              color: isDark ? Colors.white38 : Colors.black26,
            ),
          ],
        ),
      ),
    );
  }
}
