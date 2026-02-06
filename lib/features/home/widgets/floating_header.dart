import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../../core/theme/theme.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/category_service.dart' show CategoryService, CategorySearchResult;
import '../../../core/services/navigation_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/category_model.dart' show ProductCategory;
import '../../../core/utils/wishlist_helper.dart';
import '../../categories/screens/category_products_screen.dart';
import '../../product/screens/product_details_screen.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../screens/search_results_screen.dart';
import '../screens/visual_search_screen.dart';

/// SHEIN-style Floating Header with transparent-to-solid transition
class FloatingHeader extends StatefulWidget {
  final Color headerBgColor;
  final Color iconColor;
  final double statusBarHeight;
  final double opacity;
  final List<ProductCategory> categories;
  final ProductCategory? selectedCategory;
  final void Function(ProductCategory?)? onCategorySelected;
  final VoidCallback? onLogoTap;
  final Color? bannerColor; // Color from current banner for blur tint

  const FloatingHeader({
    super.key,
    required this.headerBgColor,
    required this.iconColor,
    required this.statusBarHeight,
    required this.opacity,
    required this.categories,
    this.selectedCategory,
    this.onCategorySelected,
    this.onLogoTap,
    this.bannerColor,
  });

  @override
  State<FloatingHeader> createState() => _FloatingHeaderState();
}

class _FloatingHeaderState extends State<FloatingHeader> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  final FocusNode _overlayFocusNode = FocusNode();
  final ScrollController _categoryScrollController = ScrollController();
  bool _isSearching = false;
  int _selectedCategoryIndex = 0;
  
  // Search Overlay variables
  OverlayEntry? _overlayEntry;
  Timer? _debounce;
  List<Product> _searchResults = [];
  List<CategorySearchResult> _categoryResults = [];
  List<CategorySearchResult> _similarCategoryResults = []; // Fuzzy matches for typos
  List<String> _searchHistory = [];
  bool _isLoading = false;
  final HomeService _homeService = HomeService();
  StreamSubscription? _wishlistSubscription;
  
  // ValueNotifier to trigger rebuilds in the overlay page
  final ValueNotifier<int> _searchStateNotifier = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
    
    // Add scroll listener for category pagination
    _categoryScrollController.addListener(_onCategoryScroll);
    
    _wishlistSubscription = WishlistHelper.onStatusChanged.listen((update) {
      if (!mounted) return;
      final index = _searchResults.indexWhere((p) => p.id == update.id);
      if (index != -1) {
        setState(() {
          _searchResults[index] = _searchResults[index].copyWith(isLiked: update.isLiked);
        });
      }
    });

    _searchFocusNode.addListener(() {
      setState(() {
        _isSearching = _searchFocusNode.hasFocus;
      });
    });
    
    // Sync with external selected category
    _syncSelectedCategory();
  }

  @override
  void didUpdateWidget(FloatingHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync when selectedCategory changes externally
    if (oldWidget.selectedCategory?.id != widget.selectedCategory?.id) {
      _syncSelectedCategory();
    }
  }

  // Store scroll position before category selection to restore it
  double? _savedScrollPosition;

  void _syncSelectedCategory() {
    // If we have a saved scroll position from user tap, just restore it
    // and don't do any automatic scrolling
    if (_savedScrollPosition != null) {
      _restoreScrollPosition();
      if (widget.selectedCategory == null) {
        setState(() => _selectedCategoryIndex = 0);
      } else {
        final categoryService = context.read<CategoryService>();
        final categories = categoryService.categories.isNotEmpty 
            ? categoryService.categories 
            : widget.categories;
        final idx = categories.indexWhere((c) => c.id == widget.selectedCategory!.id);
        if (idx >= 0) {
          setState(() => _selectedCategoryIndex = idx + 1);
        }
      }
      return;
    }
    
    // External selection change (not from user tap) - scroll to show the category
    if (widget.selectedCategory == null) {
      setState(() => _selectedCategoryIndex = 0);
      _restoreOrScrollToCategory(0);
    } else {
      final categoryService = context.read<CategoryService>();
      final categories = categoryService.categories.isNotEmpty 
          ? categoryService.categories 
          : widget.categories;
      final idx = categories.indexWhere((c) => c.id == widget.selectedCategory!.id);
      if (idx >= 0) {
        setState(() => _selectedCategoryIndex = idx + 1);
        _restoreOrScrollToCategory(idx + 1);
      }
    }
  }

  /// Save current scroll position before triggering category change
  void _saveScrollPosition() {
    if (_categoryScrollController.hasClients) {
      _savedScrollPosition = _categoryScrollController.offset;
    }
  }

  /// Restore the saved scroll position after widget rebuild
  void _restoreScrollPosition() {
    if (_savedScrollPosition != null && _categoryScrollController.hasClients) {
      final savedPos = _savedScrollPosition!;
      _savedScrollPosition = null; // Clear after use
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_categoryScrollController.hasClients) {
          // Jump directly without animation to avoid visual shift
          _categoryScrollController.jumpTo(savedPos.clamp(
            0.0, 
            _categoryScrollController.position.maxScrollExtent,
          ));
        }
      });
    }
  }

  /// Scroll to a specific category (used when category is off-screen)
  void _restoreOrScrollToCategory(int index) {
    if (!_categoryScrollController.hasClients) return;
    
    // Each category tab is approximately 80 pixels wide
    const double tabWidth = 80.0;
    const double padding = 12.0;
    
    // Calculate the position of the selected tab
    final double tabStart = (index * tabWidth) + padding;
    final double tabEnd = tabStart + tabWidth;
    
    // Get the current visible range
    final double viewportStart = _categoryScrollController.offset;
    final double viewportEnd = viewportStart + MediaQuery.of(context).size.width - (padding * 2);
    
    // Check if the tab is already fully visible
    if (tabStart >= viewportStart && tabEnd <= viewportEnd) {
      // Tab is already visible, don't scroll
      return;
    }
    
    // Calculate scroll offset to bring the tab into view
    double targetOffset;
    if (tabStart < viewportStart) {
      // Tab is to the left, scroll left to show it
      targetOffset = tabStart - padding;
    } else {
      // Tab is to the right, scroll right to show it (with some padding)
      targetOffset = tabEnd - MediaQuery.of(context).size.width + (padding * 2);
    }
    
    // Clamp to valid scroll range
    final double maxScroll = _categoryScrollController.position.maxScrollExtent;
    final double clampedOffset = targetOffset.clamp(0.0, maxScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_categoryScrollController.hasClients) {
        _categoryScrollController.animateTo(
          clampedOffset,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Future<void> _loadSearchHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory = prefs.getStringList('search_history') ?? [];
    });
  }

  Future<void> _addToHistory(String query) async {
    if (query.trim().isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory.remove(query);
      _searchHistory.insert(0, query);
      if (_searchHistory.length > 10) _searchHistory.removeLast();
    });
    await prefs.setStringList('search_history', _searchHistory);
  }

  Future<void> _removeFromHistory(String query) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory.remove(query);
    });
    await prefs.setStringList('search_history', _searchHistory);
    _notifySearchStateChanged();
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory.clear();
    });
    await prefs.setStringList('search_history', _searchHistory);
    _notifySearchStateChanged();
  }

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    _removeOverlay();
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _overlayFocusNode.dispose();
    _categoryScrollController.removeListener(_onCategoryScroll);
    _categoryScrollController.dispose();
    _searchStateNotifier.dispose();
    super.dispose();
  }

  void _onCategoryScroll() {
    if (_categoryScrollController.position.pixels >= 
        _categoryScrollController.position.maxScrollExtent - 100) {
      final categoryService = context.read<CategoryService>();
      if (!categoryService.isLoading && categoryService.hasMore) {
        categoryService.fetchCategories();
      }
    }
  }

  /// Clears search state (results, loading, etc.) and rebuilds overlay
  void _clearSearchState() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    setState(() {
      _searchResults = [];
      _categoryResults = [];
      _similarCategoryResults = [];
      _isLoading = false;
    });
    _notifySearchStateChanged();
  }
  
  void _notifySearchStateChanged() {
    _searchStateNotifier.value++;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _categoryResults = [];
        _similarCategoryResults = [];
        _isLoading = false;
      });
      _notifySearchStateChanged();
      return;
    }

    // Show loading and debounce the category search
    setState(() {
      _isLoading = true;
    });
    _notifySearchStateChanged();
    
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || query != _searchController.text) return;
      
      try {
        final categoryService = Provider.of<CategoryService>(context, listen: false);
        final response = await categoryService.searchCategoriesWithSimilar(query, limit: 5);
        
        if (mounted && query == _searchController.text) {
          setState(() {
            _categoryResults = response.results;
            _similarCategoryResults = response.similarResults;
            _isLoading = false;
          });
          _notifySearchStateChanged();
        }
      } catch (e) {
        debugPrint('Error searching categories: $e');
        if (mounted) {
          setState(() {
            _categoryResults = [];
            _similarCategoryResults = [];
            _isLoading = false;
          });
          _notifySearchStateChanged();
        }
      }
    });
  }

  void _showOverlay() {
    // If already showing, just request focus
    if (_overlayEntry != null) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_overlayFocusNode.hasFocus) {
          _overlayFocusNode.requestFocus();
        }
      });
      return;
    }

    // Mark that overlay is open
    _overlayEntry = OverlayEntry(builder: (_) => const SizedBox.shrink()); // Placeholder to track state
    
    // Use Navigator.push for proper gesture handling (swipe back works)
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        barrierColor: Colors.transparent,
        pageBuilder: (context, animation, secondaryAnimation) {
          return _SearchOverlayPage(
            searchController: _searchController,
            overlayFocusNode: _overlayFocusNode,
            searchStateNotifier: _searchStateNotifier,
            onClose: () {
              _searchController.clear();
              _clearSearchState();
              _overlayFocusNode.unfocus();
              _removeOverlay();
              Navigator.of(context).pop();
            },
            onSearchChanged: _onSearchChanged,
            onSubmitSearch: (query) async {
              await _submitSearch(query);
            },
            buildSearchContent: _buildSearchContent,
            pickImage: _pickImage,
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, -0.05),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              )),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    ).then((_) {
      // Ensure overlay state is cleared when route is popped
      _overlayEntry = null;
    });
    
    // Request focus after navigation
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        _overlayFocusNode.requestFocus();
      }
    });
  }

  Widget _buildSearchContent() {
    if (_isLoading) {
      return Center(
        child: Lottie.asset(
          'assets/animations/loadingproducts.json',
          width: 200,
          height: 200,
        ),
      );
    }

    if (_searchController.text.isEmpty) {
      if (_searchHistory.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.search_normal, size: 48, color: AppColors.neutral300),
              const SizedBox(height: 12),
              Text('Search for products', style: TextStyle(fontSize: 14, color: AppColors.neutral400, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Searches', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: _clearHistory,
                  child: const Text('Clear All', style: TextStyle(color: AppColors.error, fontSize: 12)),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.zero,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              itemCount: _searchHistory.length,
              itemBuilder: (context, index) {
                final historyItem = _searchHistory[index];
                return ListTile(
                  leading: const Icon(Iconsax.clock, color: AppColors.neutral400),
                  title: Text(historyItem),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18, color: AppColors.neutral400),
                    onPressed: () => _removeFromHistory(historyItem),
                  ),
                  onTap: () {
                    _submitSearch(historyItem);
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    // When user has typed something, show search button and category suggestions
    return SingleChildScrollView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search button
          InkWell(
            onTap: () {
              _submitSearch(_searchController.text);
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary500.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary500.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: AppColors.primary500, borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Iconsax.search_normal, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text('Search for "${_searchController.text}"', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                  const Icon(Iconsax.arrow_right_3, size: 20),
                ],
              ),
            ),
          ),
          
          // Category suggestions
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary500,
                  ),
                ),
              ),
            )
          else ...[
            // Exact matches
            if (_categoryResults.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text(
                'Categories',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.neutral500,
                ),
              ),
              const SizedBox(height: 8),
              ...(_categoryResults.map((result) => _buildCategorySuggestion(result))),
            ],
            
            // Similar categories (fuzzy matches) - "Did you mean?"
            if (_similarCategoryResults.isNotEmpty) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(Iconsax.info_circle, size: 14, color: AppColors.neutral400),
                  const SizedBox(width: 6),
                  Text(
                    _categoryResults.isEmpty ? 'Did you mean?' : 'Similar categories',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.neutral400,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ...(_similarCategoryResults.map((result) => _buildCategorySuggestion(result, isSimilar: true))),
            ],
          ],
          
          const SizedBox(height: 16),
          // Hint text
          Center(
            child: Text(
              'Press Enter or tap above to search products',
              style: TextStyle(fontSize: 12, color: AppColors.neutral400),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCategorySuggestion(CategorySearchResult result, {bool isSimilar = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = result.category;
    final parent = result.parentCategory;
    
    return InkWell(
      onTap: () {
        _overlayFocusNode.unfocus();
        _removeOverlay();
        
        // Navigate to the category - the screen will load its children hierarchically
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CategoryProductsScreen(
              category: category,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSimilar 
                    ? (isDark ? AppColors.neutral700 : AppColors.neutral50)
                    : (isDark ? AppColors.neutral800 : AppColors.neutral100),
                borderRadius: BorderRadius.circular(8),
                border: isSimilar ? Border.all(
                  color: AppColors.neutral300,
                  style: BorderStyle.solid,
                ) : null,
              ),
              child: Icon(
                Iconsax.category,
                size: 18,
                color: isSimilar ? AppColors.neutral400 : AppColors.primary500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isSimilar ? (isDark ? AppColors.neutral300 : AppColors.neutral600) : null,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (parent != null)
                    Text(
                      'in ${parent.name}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.neutral400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_right_3,
              size: 18,
              color: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );
  }

  void _removeOverlay() {
    _overlayEntry = null;
  }

  Future<void> _submitSearch(String query) async {
    _overlayFocusNode.unfocus();
    
    if (query.trim().isEmpty) return;

    _addToHistory(query);

    // Pop the search overlay first, then navigate to results
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    _removeOverlay();

    // Navigate directly - let the screen handle loading
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(
          title: '"$query"',
          searchQuery: query,
        ),
      ),
    );

    // Only show overlay again if not navigating away (e.g., to cart)
    if (mounted) {
      final navProvider = Provider.of<NavigationProvider>(context, listen: false);
      if (!navProvider.consumeCloseSearchFlag()) {
        _showOverlay();
      }
    }
  }

  /// Launch SHEIN-style Visual Search Screen
  Future<void> _pickImage() async {
    if (!mounted) return;
    
    // Launch the SHEIN-style visual search screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const VisualSearchScreen(),
      ),
    );
  }

  /// Legacy: Pick from gallery only (accessible from visual search screen)
  Future<void> _pickFromGalleryOnly() async {
    final ImagePicker picker = ImagePicker();
    
    try {
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100,
        maxWidth: 2048,
        maxHeight: 2048,
      );
      
      if (image != null && mounted) {
        String imagePath = image.path;
        
        // Normalize with flutter_image_compress
        try {
          final tempDir = await getTemporaryDirectory();
          final fileName = 'gallery_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final targetPath = '${tempDir.path}/$fileName';
          
          final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
            image.path,
            targetPath,
            quality: 75,
            minWidth: 800,
            minHeight: 800,
            autoCorrectionAngle: true,
            keepExif: false,
            format: CompressFormat.jpeg,
          );
          
          if (compressedFile != null) {
            imagePath = compressedFile.path;
          }
        } catch (e) {
          debugPrint('⚠️ Failed to normalize image: $e');
        }

        // Navigate to search results
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SearchResultsScreen(
                title: 'Image Search Results',
                imagePath: imagePath,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }

  /// Crop the image using image_cropper
  Future<String?> _cropImage(String imagePath) async {
    try {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imagePath,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary500,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'Crop Image',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
        ],
      );
      return croppedFile?.path;
    } catch (e) {
      debugPrint('Error cropping image: $e');
      return null;
    }
  }

  /// Perform the image search
  Future<void> _performImageSearch(String imagePath) async {
    if (!mounted) return;
    
    try {
      String finalPath = imagePath;
      final originalSize = File(imagePath).lengthSync();
      debugPrint('🔍 Original image size: $originalSize bytes');
      
      // Check if file is already JPEG
      final isJpeg = imagePath.toLowerCase().endsWith('.jpg') || 
                     imagePath.toLowerCase().endsWith('.jpeg');
      
      // Always convert to JPEG if not already, or compress if over 900KB
      // This ensures HEIC, PNG, WEBP etc. are converted for TMAPI compatibility
      if (!isJpeg || originalSize > 900000) {
        debugPrint('🔄 Converting/compressing image to JPEG...');
        try {
          final tempDir = await getTemporaryDirectory();
          final compressPath = '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          // Choose quality based on file size
          var quality = originalSize > 2000000 ? 50 : (originalSize > 900000 ? 65 : 85);
          var compressed = await FlutterImageCompress.compressAndGetFile(
            imagePath,
            compressPath,
            quality: quality,
            minWidth: 800,
            minHeight: 800,
            autoCorrectionAngle: true,
            keepExif: false,
            format: CompressFormat.jpeg,
          );
          
          if (compressed != null) {
            var compressedSize = File(compressed.path).lengthSync();
            debugPrint('📏 Processed to: $compressedSize bytes (quality: $quality)');
            
            // If still over 900KB, compress more
            if (compressedSize > 900000) {
              final recompressPath = '${tempDir.path}/upload2_${DateTime.now().millisecondsSinceEpoch}.jpg';
              compressed = await FlutterImageCompress.compressAndGetFile(
                compressed.path,
                recompressPath,
                quality: 40,
                minWidth: 600,
                minHeight: 600,
                autoCorrectionAngle: true,
                keepExif: false,
                format: CompressFormat.jpeg,
              );
              if (compressed != null) {
                compressedSize = File(compressed.path).lengthSync();
                debugPrint('📏 Re-compressed to: $compressedSize bytes');
              }
            }
            
            if (compressed != null) {
              finalPath = compressed.path;
            }
          }
        } catch (e) {
          debugPrint('⚠️ Image processing failed: $e');
        }
      }
      
      debugPrint('🔍 Navigating with image: $finalPath');
      debugPrint('📁 File exists: ${File(finalPath).existsSync()}');
      debugPrint('📏 File size: ${File(finalPath).lengthSync()} bytes');
      
      if (!mounted) return;

      // Navigate directly - let the screen handle loading
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => SearchResultsScreen(
            title: 'Image Search Results',
            imagePath: finalPath,
          ),
        ),
      );
    } catch (e) {
      debugPrint('❌ Image search error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error searching image: $e')),
      );
    }
  }

  Widget _buildImageSourceOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required ImageSource source,
  }) {
    return InkWell(
      onTap: () => Navigator.pop(context, source),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: AppColors.primary500),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Snap opacity to discrete values to reduce rebuilds (0, 0.25, 0.5, 0.75, 1.0)
    final snappedOpacity = (widget.opacity * 4).round() / 4.0;
    
    // Search bar: white background with orange border
    final searchBarBgColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;

    final searchIconColor = AppColors.primary500; // Orange icon color

    final boxShadow = widget.opacity > 0.5
        ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 2))]
        : <BoxShadow>[];

    // Blur intensity - use discrete steps (0, 7, 15) to reduce GPU recalculation
    final rawBlur = (1.0 - widget.opacity) * 15.0;
    final blurAmount = rawBlur < 3 ? 0.0 : (rawBlur < 10 ? 7.0 : 15.0);
    
    // Blur tint color from banner or default
    final blurTintColor = widget.bannerColor ?? (isDark ? Colors.black : Colors.white);
    final blurOverlayColor = blurTintColor.withOpacity((1.0 - snappedOpacity) * 0.3);

    Widget headerContent = SafeArea(
      bottom: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Top Row: Logo + Search + Icons
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                // Chibox Logo - tap to go home
                GestureDetector(
                  onTap: widget.onLogoTap,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: SvgPicture.asset(
                      'assets/animations/chibox logo box.svg',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                Expanded(
                  child: GestureDetector(
                      onTap: _showOverlay,
                      child: Container(
                        height: 36,
                        decoration: BoxDecoration(
                          color: searchBarBgColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: AppColors.primary500.withOpacity(0.6), // Orange border
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            Icon(Iconsax.search_normal_1, color: searchIconColor, size: 16),
                            const SizedBox(width: 8),
                            Text('Search products...', style: TextStyle(color: AppColors.neutral400, fontSize: 12)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 10),
                  _FloatingIconButton(icon: Iconsax.camera, color: widget.iconColor, bgOpacity: widget.opacity, onPressed: _pickImage),
                  const SizedBox(width: 6),
                  Consumer<NotificationService>(
                    builder: (context, notificationService, _) {
                      return _FloatingIconButton(
                        icon: Iconsax.notification, 
                        color: widget.iconColor, 
                        bgOpacity: widget.opacity,
                        badgeCount: notificationService.unreadCount,
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),

            // Horizontal Category Bar with Pagination
            // Use HomeService categories (widget.categories) as fallback for instant loading
            Consumer<CategoryService>(
              builder: (context, categoryService, _) {
                // Prioritize CategoryService if loaded, fallback to HomeService categories for instant display
                final categories = categoryService.categories.isNotEmpty 
                    ? categoryService.categories 
                    : widget.categories;
                
                // Only hide if BOTH sources are empty and not loading
                if (categories.isEmpty && !categoryService.isLoading) {
                  return const SizedBox.shrink();
                }
                
                // Show loading indicator only when CategoryService is loading AND we have no fallback
                final showLoading = categoryService.isLoading && categoryService.categories.isEmpty && widget.categories.isEmpty;
                
                return Container(
                  height: 32,
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListView.builder(
                    controller: _categoryScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    itemCount: categories.length + 1 + (showLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      final isSelected = _selectedCategoryIndex == index;
                      
                      // "All" tab at index 0
                      if (index == 0) {
                        return _CategoryTab(
                          label: 'All',
                          isSelected: isSelected,
                          textColor: widget.iconColor,
                          opacity: widget.opacity,
                          onTap: () {
                            _saveScrollPosition(); // Save position before triggering rebuild
                            setState(() => _selectedCategoryIndex = 0);
                            widget.onCategorySelected?.call(null);
                          },
                        );
                      }
                      
                      // Loading indicator at the end
                      if (index == categories.length + 1) {
                        return Container(
                          width: 40,
                          alignment: Alignment.center,
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: widget.iconColor.withOpacity(0.5),
                            ),
                          ),
                        );
                      }
                      
                      final category = categories[index - 1];
                      return _CategoryTab(
                        label: category.name,
                        isSelected: isSelected,
                        textColor: widget.iconColor,
                        opacity: widget.opacity,
                        onTap: () {
                          _saveScrollPosition(); // Save position before triggering rebuild
                          if (isSelected) {
                            // Toggle off - go back to All
                            setState(() => _selectedCategoryIndex = 0);
                            widget.onCategorySelected?.call(null);
                          } else {
                            setState(() => _selectedCategoryIndex = index);
                            widget.onCategorySelected?.call(category);
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      );

    // Determine status bar icon brightness based on theme
    // Since header is always white/light now, use dark icons in light mode
    final statusBarStyle = SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark, // Dark icons on white header
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light, // For iOS
    );

    // Apply blur when over banner (opacity < 1) - use RepaintBoundary for performance
    if (blurAmount > 0.5) {
      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: statusBarStyle,
        child: RepaintBoundary(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: blurAmount, sigmaY: blurAmount),
              child: Container(
                decoration: BoxDecoration(
                  color: widget.headerBgColor,
                  boxShadow: boxShadow,
                ),
                child: headerContent,
              ),
            ),
          ),
        ),
      );
    }

    // Solid background when scrolled
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: statusBarStyle,
      child: Container(
        decoration: BoxDecoration(
          color: widget.headerBgColor,
          boxShadow: boxShadow,
        ),
        child: headerContent,
      ),
    );
  }
}

class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double bgOpacity;
  final VoidCallback onPressed;
  final int badgeCount;

  const _FloatingIconButton({
    required this.icon,
    required this.color,
    required this.bgOpacity,
    required this.onPressed,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    // Subtle orange tinted background when at top for visibility, transparent when scrolled
    final bgColor = bgOpacity < 0.5 
        ? AppColors.primary500.withOpacity(0.1) 
        : Colors.transparent;

    return GestureDetector(
      onTap: onPressed,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 18),
          ),
          if (badgeCount > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 16,
                  minHeight: 16,
                ),
                child: Text(
                  badgeCount > 99 ? '99+' : badgeCount.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color textColor;
  final double opacity;
  final VoidCallback onTap;

  const _CategoryTab({
    required this.label,
    required this.isSelected,
    required this.textColor,
    required this.opacity,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Text color follows the theme color passed from parent (dark on white header)
    final effectiveTextColor = textColor;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : effectiveTextColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}

/// Full-screen image preview for camera/gallery search
class _ImagePreviewScreen extends StatefulWidget {
  final String imagePath;
  final Function(String) onSearch;
  final Future<String?> Function(String) onCrop;

  const _ImagePreviewScreen({
    required this.imagePath,
    required this.onSearch,
    required this.onCrop,
  });

  @override
  State<_ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<_ImagePreviewScreen> {
  late String _currentPath;
  bool _isLoading = false;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _currentPath = widget.imagePath;
    _loadImageBytes();
  }

  Future<void> _loadImageBytes() async {
    try {
      final file = File(_currentPath);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        if (mounted) {
          setState(() {
            _imageBytes = bytes;
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading image bytes: $e');
    }
  }

  Future<void> _handleCrop() async {
    setState(() => _isLoading = true);
    try {
      final croppedPath = await widget.onCrop(_currentPath);
      if (croppedPath != null && mounted) {
        setState(() {
          _currentPath = croppedPath;
          _imageBytes = null; // Reset bytes to force reload from new path
        });
        _loadImageBytes();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildErrorWidget() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Iconsax.image, size: 64, color: Colors.grey[400]),
        const SizedBox(height: 16),
        Text(
          'Could not load image',
          style: TextStyle(color: Colors.grey[600], fontSize: 16),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: isDark ? Colors.black : Colors.grey[100],
      body: Stack(
        children: [
          // Image preview - takes full screen
          Positioned.fill(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: _imageBytes != null
                    ? Image.memory(
                        _imageBytes!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Image.memory error: $error');
                          return _buildErrorWidget();
                        },
                      )
                    : Image.file(
                        File(_currentPath),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint('Image.file error: $error');
                          return _buildErrorWidget();
                        },
                      ),
              ),
            ),
          ),
          
          // Top bar with close button
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Iconsax.close_circle, color: Colors.white, size: 28),
                      ),
                      const Expanded(
                        child: Text(
                          'Search by Image',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48), // Balance the close button
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Bottom action bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                  child: Row(
                    children: [
                      // Retake / Cancel
                      // Expanded(
                      //   child: _ActionButton(
                      //     icon: Iconsax.refresh,
                      //     label: 'Retake',
                      //     onTap: () => Navigator.pop(context),
                      //     outlined: true,
                      //   ),
                      // ),
                      const SizedBox(width: 12),
                      
                      // Crop
                      Expanded(
                        child: _ActionButton(
                          icon: Iconsax.crop,
                          label: 'Crop',
                          onTap: _isLoading ? null : _handleCrop,
                          outlined: true,
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Search
                      Expanded(
                        flex: 2,
                        child: _ActionButton(
                          icon: Iconsax.search_normal,
                          label: 'Search',
                          onTap: _isLoading ? null : () => widget.onSearch(_currentPath),
                          isPrimary: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Loading overlay
          if (_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black54,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Action button for image preview screen
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool outlined;
  final bool isPrimary;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.outlined = false,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary500,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          elevation: 0,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          ],
        ),
      );
    }
    
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: const BorderSide(color: Colors.white54),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
        ],
      ),
    );
  }
}

/// Search Overlay Page - A proper route for swipe-back gesture support
class _SearchOverlayPage extends StatefulWidget {
  final TextEditingController searchController;
  final FocusNode overlayFocusNode;
  final ValueNotifier<int> searchStateNotifier;
  final VoidCallback onClose;
  final Function(String) onSearchChanged;
  final Future<void> Function(String) onSubmitSearch;
  final Widget Function() buildSearchContent;
  final VoidCallback pickImage;

  const _SearchOverlayPage({
    required this.searchController,
    required this.overlayFocusNode,
    required this.searchStateNotifier,
    required this.onClose,
    required this.onSearchChanged,
    required this.onSubmitSearch,
    required this.buildSearchContent,
    required this.pickImage,
  });

  @override
  State<_SearchOverlayPage> createState() => _SearchOverlayPageState();
}

class _SearchOverlayPageState extends State<_SearchOverlayPage> {
  @override
  void initState() {
    super.initState();
    widget.searchController.addListener(_onTextChanged);
    widget.searchStateNotifier.addListener(_onSearchStateChanged);
  }

  @override
  void dispose() {
    widget.searchController.removeListener(_onTextChanged);
    widget.searchStateNotifier.removeListener(_onSearchStateChanged);
    super.dispose();
  }

  void _onTextChanged() {
    setState(() {}); // Rebuild to show/hide X button
  }
  
  void _onSearchStateChanged() {
    if (mounted) {
      setState(() {}); // Rebuild when search state changes
    }
  }

  void _clearSearch() {
    widget.searchController.clear();
    widget.onSearchChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true, // Allow swipe back
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          widget.searchController.clear();
          widget.onSearchChanged('');
          widget.overlayFocusNode.unfocus();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (widget.overlayFocusNode.hasFocus) {
            widget.overlayFocusNode.unfocus();
          } else {
            widget.onClose();
          }
        },
        child: Material(
          color: Colors.black.withOpacity(0.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: Column(
                children: [
                  Material(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    elevation: 8,
                    child: SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Back button
                            GestureDetector(
                              onTap: widget.onClose,
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.primary500.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Iconsax.arrow_left,
                                  size: 20,
                                  color: AppColors.primary500,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Container(
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: AppColors.primary500.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: TextField(
                                  controller: widget.searchController,
                                  focusNode: widget.overlayFocusNode,
                                  autofocus: true,
                                  textInputAction: TextInputAction.search,
                                  onChanged: widget.onSearchChanged,
                                  textAlignVertical: TextAlignVertical.center,
                                  decoration: InputDecoration(
                                    hintText: 'Search products...',
                                    prefixIcon: const Icon(Iconsax.search_normal_1, color: AppColors.primary500, size: 20),
                                    suffixIcon: widget.searchController.text.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.close, size: 20),
                                            onPressed: _clearSearch,
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                          )
                                        : null,
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                    isDense: true,
                                  ),
                                  onSubmitted: (value) {
                                    widget.onSubmitSearch(value);
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            // Camera button for visual search
                            GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const VisualSearchScreen(),
                                  ),
                                );
                              },
                              child: Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.primary500.withOpacity(0.1),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.primary500.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: const Icon(
                                  Iconsax.camera,
                                  size: 20,
                                  color: AppColors.primary500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {}, // Prevent taps from closing when tapping content
                      child: Container(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        child: widget.buildSearchContent(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
