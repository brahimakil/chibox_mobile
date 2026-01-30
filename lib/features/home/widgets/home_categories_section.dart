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

    // No "All" button - just show categories with skeleton loading at the end when paginating
    final itemCount = displayItems.length;
    
    // If showing subcategories, use vertical scrollable list
    if (showingSubcategories) {
      return _buildVerticalSubcategoriesList(context, displayItems, isDark);
    }
    
    // Balanced row distribution: 1 above, 1 below (equal columns)
    // This creates pairs: first half on top, second half on bottom
    // 10 items = 5 columns (5 on top, 5 on bottom)
    // 8 items = 4 columns (4 on top, 4 on bottom)
    // 9 items = 5 columns (5 on top, 4 on bottom - last column has no bottom)
    final int columnCount = (itemCount / 2).ceil();
    final int topRowCount = columnCount;
    final int bottomRowCount = itemCount - columnCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
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
              height: 250, // Height for 2 rows (SHEIN style - bigger circles)
              child: SingleChildScrollView(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                    // Skeleton loading at end when more categories available
                    if (categoryService.hasMore)
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

  /// Builds a grid of subcategories (same style as main categories)
  Widget _buildVerticalSubcategoriesList(BuildContext context, List<ProductCategory> subcategories, bool isDark) {
    // Add 1 for "View All" button at the end
    final itemCount = subcategories.length + 1;
    
    // Get screen width to determine if we need scrolling
    final screenWidth = MediaQuery.of(context).size.width - 32; // Subtract margins
    final itemWidth = 64.0; // Width per item
    final maxItemsPerRow = (screenWidth / itemWidth).floor();
    
    // Determine layout based on item count
    final bool needsScrolling = itemCount > maxItemsPerRow * 2; // More than 2 rows worth
    final bool usesTwoRows = itemCount > maxItemsPerRow;
    
    // For scrolling layout
    final int columnCount = (itemCount / 2).ceil();
    final int topRowCount = columnCount;
    final int bottomRowCount = itemCount - columnCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        // Full-width container
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
            child: needsScrolling
                // Many items: use horizontal scrolling
                ? SizedBox(
                    height: 250,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ...List.generate(topRowCount, (topIndex) {
                            final bottomIndex = topIndex < bottomRowCount ? topRowCount + topIndex : -1;
                            return Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildSubcategoryGridItem(context, topIndex, isDark, subcategories, expanded: false),
                                if (bottomIndex >= 0 && bottomIndex < itemCount)
                                  _buildSubcategoryGridItem(context, bottomIndex, isDark, subcategories, expanded: false),
                              ],
                            );
                          }),
                        ],
                      ),
                    ),
                  )
                // Few items: expand to fill width
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                    child: usesTwoRows
                        ? _buildTwoRowGrid(context, subcategories, isDark, (itemCount / 2).ceil(), itemCount - (itemCount / 2).ceil(), itemCount)
                        : _buildSingleRowGrid(context, subcategories, isDark, itemCount),
                  ),
          ),
        ),
        const SizedBox(height: 4),
      ],
    );
  }
  
  /// Single row grid - items expand to fill width evenly
  Widget _buildSingleRowGrid(BuildContext context, List<ProductCategory> subcategories, bool isDark, int itemCount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(itemCount, (index) {
        return Expanded(
          child: _buildSubcategoryGridItem(context, index, isDark, subcategories, expanded: true),
        );
      }),
    );
  }
  
  /// Two row grid - items expand to fill width evenly
  Widget _buildTwoRowGrid(BuildContext context, List<ProductCategory> subcategories, bool isDark, int topRowCount, int bottomRowCount, int itemCount) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Top row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(topRowCount, (index) {
            return Expanded(
              child: _buildSubcategoryGridItem(context, index, isDark, subcategories, expanded: true),
            );
          }),
        ),
        // Bottom row
        if (bottomRowCount > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ...List.generate(bottomRowCount, (index) {
                final actualIndex = topRowCount + index;
                return Expanded(
                  child: _buildSubcategoryGridItem(context, actualIndex, isDark, subcategories, expanded: true),
                );
              }),
              // Add empty spacers to match top row column count
              ...List.generate(topRowCount - bottomRowCount, (_) => const Expanded(child: SizedBox())),
            ],
          ),
      ],
    );
  }
  
  /// Build a single subcategory grid item
  Widget _buildSubcategoryGridItem(BuildContext context, int index, bool isDark, List<ProductCategory> subcategories, {bool expanded = false}) {
    // Last item is "View All" button
    if (index == subcategories.length) {
      return _ViewAllSubcategoriesButton(
        isDark: isDark,
        expanded: expanded,
        onTap: () {
          // Navigate to Categories tab with this category pre-selected
          Provider.of<NavigationProvider>(context, listen: false)
              .goToCategoriesWithSelection(widget.selectedCategory!.id);
        },
      );
    }

    final category = subcategories[index];
    return _CategoryItem(
      category: category,
      isDark: isDark,
      isSubcategory: true,
      expanded: expanded,
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
              height: 250,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
        width: 80,
        height: 105,
        margin: const EdgeInsets.only(right: 8, bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Circle skeleton
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: baseColor,
              ),
            ),
            const SizedBox(height: 6),
            // Text skeleton
            Container(
              width: 54,
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
    // Safety check for index bounds
    if (index >= displayItems.length) {
      return const SizedBox.shrink();
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
            builder: (context) => CategoryProductsScreen(
              category: category,
            ),
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
  final bool expanded;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.isDark,
    this.isSubcategory = false,
    this.expanded = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Circular image
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipOval(
            child: CachedNetworkImage(
              imageUrl: ImageHelper.parse(category.mainImage) ?? '',
              fit: BoxFit.cover,
              memCacheWidth: 140,
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
        Text(
          category.name,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.white70 : Colors.black87,
            height: 1.2,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      ],
    );
    
    return GestureDetector(
      onTap: onTap,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: content,
            )
          : Container(
              width: 80,
              height: 105,
              margin: const EdgeInsets.only(right: 8, bottom: 6),
              child: content,
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
        width: 80,
        height: 105,
        margin: const EdgeInsets.only(right: 8, bottom: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
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
                size: 24,
                color: AppColors.primary500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'All',
              style: TextStyle(
                fontSize: 11,
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

/// "View All" button for subcategories grid (same style as _AllCategoriesButton)
class _ViewAllSubcategoriesButton extends StatelessWidget {
  final bool isDark;
  final bool expanded;
  final VoidCallback onTap;

  const _ViewAllSubcategoriesButton({
    required this.isDark,
    this.expanded = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.primary500.withOpacity(0.1),
            border: Border.all(
              color: AppColors.primary500.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: const Icon(
            Iconsax.arrow_right_3,
            size: 24,
            color: AppColors.primary500,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'View All',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.primary500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
    
    return GestureDetector(
      onTap: onTap,
      child: expanded
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: content,
            )
          : Container(
              width: 80,
              height: 105,
              margin: const EdgeInsets.only(right: 8, bottom: 6),
              child: content,
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
                memCacheWidth: 100,
                memCacheHeight: 100,
                maxWidthDiskCache: 100,
                maxHeightDiskCache: 100,
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
