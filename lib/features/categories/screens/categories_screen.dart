import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:lottie/lottie.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'dart:async';
import '../../../core/theme/theme.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/navigation_provider.dart';
import '../../../core/models/category_model.dart';
import '../../../core/utils/image_helper.dart';
import '../../../shared/widgets/widgets.dart';
import '../../home/widgets/floating_header.dart';
import 'category_products_screen.dart';

class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  int _selectedCategoryIndex = 0;
  final ScrollController _leftPanelScrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  List<CategorySearchResult> _searchResults = [];
  bool _isSearching = false;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CategoryService>(context, listen: false).fetchCategories(refresh: true);
    });
    
    _leftPanelScrollController.addListener(_onLeftPanelScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _leftPanelScrollController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
  
  void _onSearchChanged() {
    final query = _searchController.text.trim();
    if (query != _searchQuery) {
      setState(() {
        _searchQuery = query;
        if (query.isEmpty) {
          _searchResults = [];
          _isSearching = false;
          _searchDebounce?.cancel();
        } else {
          _isSearching = true;
          // Debounce server-side search to avoid too many API calls
          _searchDebounce?.cancel();
          _searchDebounce = Timer(const Duration(milliseconds: 300), () {
            _performServerSearch(query);
          });
        }
      });
    }
  }
  
  Future<void> _performServerSearch(String query) async {
    if (query.isEmpty || query != _searchQuery) return;
    
    final categoryService = Provider.of<CategoryService>(context, listen: false);
    final results = await categoryService.searchCategories(query, limit: 30);
    
    // Only update if the query hasn't changed while we were searching
    if (mounted && query == _searchQuery) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }
  
  void _clearSearch() {
    _searchDebounce?.cancel();
    _searchController.clear();
    _searchFocusNode.unfocus();
    setState(() {
      _searchQuery = '';
      _searchResults = [];
      _isSearching = false;
    });
  }

  void _onLeftPanelScroll() {
    if (_leftPanelScrollController.position.pixels >= _leftPanelScrollController.position.maxScrollExtent - 100) {
      Provider.of<CategoryService>(context, listen: false).fetchCategories();
    }
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
      if (index != -1) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_selectedCategoryIndex != index) {
            setState(() => _selectedCategoryIndex = index);
          }
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
      } else {
        // Category not found in list, clear the selection
        navigationProvider.clearSelectedCategory();
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark, // Dark icons on light bg
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // For iOS
      ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.neutral900 : Colors.white,
        body: Column(
          children: [
            // --- Safe Area + Search Bar ---
            Container(
              color: isDark ? AppColors.neutral900 : Colors.white,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.neutral800 : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocusNode,
                            textAlignVertical: TextAlignVertical.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Search categories...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                              ),
                              prefixIcon: Icon(
                                Iconsax.search_normal_1,
                                size: 20,
                                color: isDark ? AppColors.neutral400 : AppColors.neutral500,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: Icon(
                                        Icons.close,
                                        size: 20,
                                        color: isDark ? AppColors.neutral400 : AppColors.neutral500,
                                      ),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ),

          // --- Main Content ---
          Expanded(
            child: _searchQuery.isNotEmpty 
                ? _buildSearchResults(isDark)
                : _buildSplitLayout(categories, isDark, categoryService),
          ),
        ],
      ),
      ),
    );
  }
  
  Widget _buildSearchResults(bool isDark) {
    // Show loading indicator while searching
    if (_isSearching) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.primary400 : AppColors.primary500,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching...',
              style: AppTypography.bodyMedium(
                color: isDark ? AppColors.neutral400 : AppColors.neutral500,
              ),
            ),
          ],
        ),
      );
    }
    
    if (_searchResults.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.search_normal,
              size: 64,
              color: isDark ? AppColors.neutral600 : AppColors.neutral300,
            ),
            const SizedBox(height: 16),
            Text(
              'No categories found',
              style: AppTypography.bodyLarge(
                color: isDark ? AppColors.neutral400 : AppColors.neutral500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try a different search term',
              style: AppTypography.bodySmall(
                color: isDark ? AppColors.neutral500 : AppColors.neutral400,
              ),
            ),
          ],
        ),
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSearchResultItem(result, isDark);
      },
    );
  }
  
  Widget _buildSearchResultItem(CategorySearchResult result, bool isDark) {
    return InkWell(
      onTap: () async {
        _clearSearch();
        
        // Get siblings for the category - MUST fetch from server if not cached
        final categoryService = Provider.of<CategoryService>(context, listen: false);
        List<ProductCategory> siblings = [];
        
        if (result.isSubcategory && result.parentCategory != null) {
          // For subcategories, get siblings from the parent (other subcategories of same parent)
          siblings = categoryService.getCachedSubcategories(result.parentCategory!.id) ?? [];
          
          // If not cached, fetch from server
          if (siblings.isEmpty) {
            final response = await categoryService.fetchSubcategories(result.parentCategory!.id);
            siblings = response['subcategories'] as List<ProductCategory>? ?? [];
          }
        } else {
          // For main categories, get its subcategories to show at the top
          siblings = categoryService.getCachedSubcategories(result.category.id) ?? [];
          
          // If not cached, fetch from server
          if (siblings.isEmpty) {
            final response = await categoryService.fetchSubcategories(result.category.id);
            siblings = response['subcategories'] as List<ProductCategory>? ?? [];
          }
        }
        
        if (!mounted) return;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryProductsScreen(
              category: result.category,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.neutral800 : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.neutral700 : AppColors.neutral200,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            // Category image
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ImageHelper.parse(result.category.mainImage).isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: ImageHelper.parse(result.category.mainImage),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Image.asset(
                        'assets/images/category_loadingorfailbak.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                      errorWidget: (_, __, ___) => Image.asset(
                        'assets/images/category_loadingorfailbak.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Image.asset(
                      'assets/images/category_loadingorfailbak.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                    ),
            ),
            const SizedBox(width: 12),
            // Category info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.category.name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.isSubcategory && result.parentCategory != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Iconsax.arrow_right_3,
                          size: 12,
                          color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            'in ${result.parentCategory!.name}',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.neutral400 : AppColors.neutral500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Arrow
            Icon(
              Iconsax.arrow_right_3,
              size: 20,
              color: isDark ? AppColors.neutral500 : AppColors.neutral400,
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
                  // Right panel will auto-reset via ValueKey when category changes
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
                        padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Category name only (no images)
                            Text(
                              category.name,
                              textAlign: TextAlign.left,
                              // Removed maxLines to allow full expansion
                              style: isSelected
                                  ? AppTypography.bodySmall(color: isDark ? Colors.white : Colors.black).copyWith(fontWeight: FontWeight.bold, fontSize: 10) // Smaller font
                                  : AppTypography.bodySmall(color: isDark ? AppColors.neutral400 : AppColors.neutral600).copyWith(fontSize: 10), // Smaller font
                            ),
                          ],
                        ),
                      ),
                      // Left orange line (existing)
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
                      // Top orange line (new)
                      if (isSelected)
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Container(
                            height: 1,
                            color: AppColors.primary500,
                          ),
                        ),
                      // Bottom orange line (new)
                      if (isSelected)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          child: Container(
                            height: 1,
                            color: AppColors.primary500,
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),

        // --- Right Panel (Subcategories with lazy loading) ---
        Expanded(
          child: Container(
            color: isDark ? AppColors.neutral800 : Colors.white,
            child: _SubcategoriesPanel(
              key: ValueKey(categories[_selectedCategoryIndex].id),
              category: categories[_selectedCategoryIndex],
              isDark: isDark,
            ),
          ),
        ),
      ],
    );
  }
}

/// Stateful widget for the right panel with lazy loading subcategories
class _SubcategoriesPanel extends StatefulWidget {
  final ProductCategory category;
  final bool isDark;

  const _SubcategoriesPanel({
    super.key,
    required this.category,
    required this.isDark,
  });

  @override
  State<_SubcategoriesPanel> createState() => _SubcategoriesPanelState();
}

class _SubcategoriesPanelState extends State<_SubcategoriesPanel> {
  final ScrollController _scrollController = ScrollController();
  List<ProductCategory> _subcategories = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _currentPage = 1;
  static const int _perPage = 30;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadSubcategories(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) {
        _loadSubcategories();
      }
    }
  }

  Future<void> _loadSubcategories({bool refresh = false}) async {
    if (!mounted) return;
    
    final categoryService = Provider.of<CategoryService>(context, listen: false);
    
    if (refresh) {
      _currentPage = 1;
      _hasMore = true;
      setState(() => _isLoading = true);
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    final result = await categoryService.fetchSubcategories(
      widget.category.id,
      page: _currentPage,
      perPage: _perPage,
    );

    if (mounted) {
      final newSubcategories = result['subcategories'] as List<ProductCategory>;
      final pagination = result['pagination'] as Map<String, dynamic>;
      final fromCache = result['fromCache'] == true;

      setState(() {
        if (refresh) {
          _subcategories = newSubcategories;
          // If data came from cache, move to page 2 for next fetch
          _currentPage = fromCache ? 2 : 2;
        } else {
          _subcategories.addAll(newSubcategories);
          _currentPage++;
        }

        _hasMore = pagination['has_next'] == true;

        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return ListView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(16),
      children: [
        // Header Image
        if (ImageHelper.parse(widget.category.mainImage).isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CachedNetworkImage(
                imageUrl: ImageHelper.parse(widget.category.mainImage),
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

        // Title and View All button
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                widget.category.name,
                style: AppTypography.headingSmall(color: widget.isDark ? Colors.white : Colors.black),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CategoryProductsScreen(
                      category: widget.category,
                    ),
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

        const SizedBox(height: 3),

        // Subcategories grid or empty state
        if (_subcategories.isEmpty)
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
          // SHEIN-style grid: 3 columns, same height, max 3 lines with ellipsis
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 16,
              crossAxisSpacing: 12,
              childAspectRatio: 0.72, // Fixed aspect ratio for uniform height
            ),
            itemCount: _subcategories.length,
            itemBuilder: (context, index) {
              final sub = _subcategories[index];
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Fixed size circle container for consistent shape
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: widget.isDark ? AppColors.neutral900 : AppColors.neutral50,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 64,
                          height: 64,
                          child: ImageHelper.parse(sub.mainImage).isNotEmpty
                              ? CachedNetworkImage(
                                  imageUrl: ImageHelper.parse(sub.mainImage),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                  httpHeaders: const {
                                    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
                                  },
                                  placeholder: (context, url) => Image.asset(
                                    'assets/images/category_loadingorfailbak.png',
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                  errorWidget: (context, url, error) => Image.asset(
                                    'assets/images/category_loadingorfailbak.png',
                                    width: 64,
                                    height: 64,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : Image.asset(
                                  'assets/images/category_loadingorfailbak.png',
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // SHEIN-style: max 3 lines with ellipsis for professional look
                    Expanded(
                      child: Text(
                        sub.name,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySmall(
                          color: widget.isDark ? AppColors.neutral300 : AppColors.neutral700,
                        ).copyWith(fontSize: 11, height: 1.3),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

        // Loading indicator at bottom
        if (_isLoadingMore)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),

        const SizedBox(height: 40),
      ],
    );
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
