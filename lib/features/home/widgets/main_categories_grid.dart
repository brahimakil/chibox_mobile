import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/models/category_model.dart';
import '../../../core/services/navigation_provider.dart';
import '../../../core/theme/theme.dart';

/// Displays main categories in a horizontal scrollable row on the home screen.
/// When tapped, navigates to Categories tab with the selected category.
class MainCategoriesGrid extends StatelessWidget {
  final List<ProductCategory> categories;

  const MainCategoriesGrid({
    super.key,
    required this.categories,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Filter to only show main categories (no parent)
    final mainCategories = categories.where((c) => c.parentId == null && c.display).toList();
    
    if (mainCategories.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Shop by Category',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black87,
                  letterSpacing: -0.3,
                ),
              ),
              GestureDetector(
                onTap: () {
                  // Navigate to categories tab
                  context.read<NavigationProvider>().setIndex(1);
                },
                child: Text(
                  'See All',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary500,
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 82,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: mainCategories.length,
            itemBuilder: (context, index) {
              final category = mainCategories[index];
              return _CategoryItem(
                category: category,
                isDark: isDark,
                onTap: () {
                  // Navigate to categories tab with this category selected
                  context.read<NavigationProvider>().goToCategoriesWithSelection(category.id);
                },
              );
            },
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _CategoryItem extends StatelessWidget {
  final ProductCategory category;
  final bool isDark;
  final VoidCallback onTap;

  const _CategoryItem({
    required this.category,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 62,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Category Image
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : Colors.grey[100],
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: category.mainImage != null && category.mainImage!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: category.mainImage!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Shimmer.fromColors(
                          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
                          child: Container(color: Colors.white),
                        ),
                        errorWidget: (context, url, error) => Icon(
                          Icons.category_outlined,
                          size: 22,
                          color: isDark ? Colors.white38 : Colors.grey[400],
                        ),
                      )
                    : Icon(
                        Icons.category_outlined,
                        size: 22,
                        color: isDark ? Colors.white38 : Colors.grey[400],
                      ),
              ),
            ),
            const SizedBox(height: 4),
            // Category Name
            Text(
              category.nameEn ?? category.name,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
