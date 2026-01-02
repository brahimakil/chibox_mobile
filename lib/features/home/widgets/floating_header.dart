import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:ui';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import '../../../core/theme/theme.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/models/product_model.dart';
import '../../../core/models/category_model.dart' show ProductCategory;
import '../../../core/utils/wishlist_helper.dart';
import '../../categories/screens/category_products_screen.dart';
import '../../product/screens/product_details_screen.dart';
import '../screens/search_results_screen.dart';

/// SHEIN-style Floating Header with transparent-to-solid transition
class FloatingHeader extends StatefulWidget {
  final Color headerBgColor;
  final Color iconColor;
  final double statusBarHeight;
  final double opacity;
  final List<ProductCategory> categories;
  final ProductCategory? selectedCategory;
  final void Function(ProductCategory?)? onCategorySelected;
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
  List<String> _searchHistory = [];
  bool _isLoading = false;
  final HomeService _homeService = HomeService();
  StreamSubscription? _wishlistSubscription;

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
    _overlayEntry?.markNeedsBuild();
  }

  Future<void> _clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _searchHistory.clear();
    });
    await prefs.setStringList('search_history', _searchHistory);
    _overlayEntry?.markNeedsBuild();
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

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
      _overlayEntry?.markNeedsBuild();
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (!mounted) return;
      setState(() => _isLoading = true);
      _showOverlay();
      
      try {
        final results = await _homeService.searchProducts(query);
        if (mounted) {
          setState(() {
            _searchResults = results;
            _isLoading = false;
          });
          _overlayEntry?.markNeedsBuild();
        }
      } catch (e) {
        debugPrint('Search error: $e');
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    });
  }

  void _showOverlay() {
    if (_overlayEntry != null) {
      _overlayEntry!.markNeedsBuild();
      // Request focus again to ensure keyboard shows
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && !_overlayFocusNode.hasFocus) {
          _overlayFocusNode.requestFocus();
        }
      });
      return;
    }

    final overlay = Overlay.of(context);

    _overlayEntry = OverlayEntry(
      builder: (context) => _buildSearchOverlay(context),
    );

    overlay.insert(_overlayEntry!);
    
    // Request focus after overlay is shown to trigger keyboard
    Future.delayed(const Duration(milliseconds: 150), () {
      if (mounted) {
        _overlayFocusNode.requestFocus();
      }
    });
  }

  Widget _buildSearchOverlay(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: () {
        if (_overlayFocusNode.hasFocus) {
          _overlayFocusNode.unfocus();
        } else {
          _removeOverlay();
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
                                controller: _searchController,
                                focusNode: _overlayFocusNode,
                                autofocus: true,
                                textInputAction: TextInputAction.search,
                                onChanged: _onSearchChanged,
                                textAlignVertical: TextAlignVertical.center,
                                decoration: InputDecoration(
                                  hintText: 'Search products...',
                                  prefixIcon: const Icon(Iconsax.search_normal_1, color: AppColors.primary500, size: 20),
                                  suffixIcon: _searchController.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.close, size: 20),
                                          onPressed: () => _searchController.clear(),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                  isDense: true,
                                ),
                                onSubmitted: (value) {
                                  _submitSearch(value);
                                  _removeOverlay();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          TextButton(
                            onPressed: () {
                              _searchController.clear();
                              _overlayFocusNode.unfocus();
                              _removeOverlay();
                            },
                            child: const Text('Cancel', style: TextStyle(color: AppColors.primary500, fontWeight: FontWeight.w600, fontSize: 16)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: _buildSearchContent(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ).animate()
        .fadeIn(duration: 200.ms, curve: Curves.easeOut)
        .slideY(begin: -0.05, end: 0, duration: 300.ms, curve: Curves.easeOutCubic);
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
              Icon(Iconsax.search_normal, size: 64, color: AppColors.neutral300),
              const SizedBox(height: 16),
              Text('Search for products', style: TextStyle(fontSize: 18, color: AppColors.neutral400, fontWeight: FontWeight.w500)),
            ],
          ),
        );
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent Searches', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                TextButton(
                  onPressed: _clearHistory,
                  child: const Text('Clear All', style: TextStyle(color: AppColors.error, fontSize: 14)),
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
                    _searchController.text = historyItem;
                    _overlayFocusNode.unfocus();
                    _onSearchChanged(historyItem);
                  },
                );
              },
            ),
          ),
        ],
      );
    }

    return ListView(
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      padding: const EdgeInsets.all(16),
      children: [
        InkWell(
          onTap: () {
            _submitSearch(_searchController.text);
            _removeOverlay();
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
                Expanded(child: Text('View all results for "${_searchController.text}"', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15))),
                const Icon(Iconsax.arrow_right_3, size: 20),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (_searchResults.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                children: [
                  Icon(Iconsax.search_status, size: 48, color: AppColors.neutral300),
                  const SizedBox(height: 12),
                  Text('No results found', style: TextStyle(fontSize: 16, color: AppColors.neutral400)),
                ],
              ),
            ),
          )
        else
          ...List.generate(_searchResults.length, (index) {
            final product = _searchResults[index];
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2))],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(product.mainImage, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.grey[200], width: 60, height: 60)),
                ),
                title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 15)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 4), child: Text('\$${product.price}', style: const TextStyle(color: AppColors.primary500, fontWeight: FontWeight.bold, fontSize: 16))),
                trailing: const Icon(Iconsax.arrow_right_3, size: 20),
                onTap: () {
                  _overlayFocusNode.unfocus();
                  _addToHistory(_searchController.text);
                  _removeOverlay();
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen(product: product))).then((_) {
                    if (mounted) _showOverlay();
                  });
                },
              ),
            );
          }),
      ],
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _submitSearch(String query) async {
    _overlayFocusNode.unfocus();
    _removeOverlay();
    
    if (query.trim().isEmpty) return;

    _addToHistory(query);

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

    if (mounted) _showOverlay();
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    
    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 8),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 24),
                const Text('Search by Image', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildImageSourceOption(context, icon: Iconsax.camera, label: 'Camera', source: ImageSource.camera),
                    _buildImageSourceOption(context, icon: Iconsax.gallery, label: 'Gallery', source: ImageSource.gallery),
                  ],
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        );
      },
    );

    if (source == null) return;

    try {
      // Use same quality for both - we'll normalize later
      final XFile? image = await picker.pickImage(
        source: source,
        imageQuality: 100, // Get full quality, we'll compress properly
        maxWidth: 2048,
        maxHeight: 2048,
      );
      
      if (image != null && mounted) {
        String imagePath = image.path;
        
        // For ALL images (especially camera), normalize with flutter_image_compress
        // This fixes EXIF orientation issues that cause AI recognition to fail
        try {
          final tempDir = await getTemporaryDirectory();
          final fileName = '${source == ImageSource.camera ? 'camera' : 'gallery'}_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final targetPath = '${tempDir.path}/$fileName';
          
          debugPrint('📷 Original image: ${image.path}');
          debugPrint('📏 Original size: ${File(image.path).lengthSync()} bytes');
          
          // Compress and fix EXIF orientation
          // flutter_image_compress automatically rotates based on EXIF
          // Target: under 1MB (backend limit), good quality for AI recognition
          final XFile? compressedFile = await FlutterImageCompress.compressAndGetFile(
            image.path,
            targetPath,
            quality: 75, // Lower quality to stay under 1MB
            minWidth: 800,
            minHeight: 800,
            rotate: 0, // Auto-rotate based on EXIF
            autoCorrectionAngle: true, // KEY: This fixes EXIF orientation!
            keepExif: false, // Remove EXIF after applying rotation
            format: CompressFormat.jpeg,
          );
          
          if (compressedFile != null) {
            imagePath = compressedFile.path;
            final fileSize = File(imagePath).lengthSync();
            debugPrint('✅ Image normalized to: $imagePath');
            debugPrint('📏 Normalized size: $fileSize bytes');
            
            // If still over 900KB, compress more aggressively
            if (fileSize > 900000) {
              debugPrint('⚠️ Image still too large, compressing further...');
              final recompressPath = '${tempDir.path}/recomp_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final recompressed = await FlutterImageCompress.compressAndGetFile(
                imagePath,
                recompressPath,
                quality: 50, // More aggressive compression
                minWidth: 600,
                minHeight: 600,
                autoCorrectionAngle: true,
                keepExif: false,
                format: CompressFormat.jpeg,
              );
              if (recompressed != null) {
                imagePath = recompressed.path;
                debugPrint('✅ Re-compressed to: ${File(imagePath).lengthSync()} bytes');
              }
            }
          } else {
            debugPrint('⚠️ Compression returned null, using original');
          }
        } catch (e) {
          debugPrint('⚠️ Failed to normalize image: $e');
          // Fallback: just copy the file
          if (source == ImageSource.camera) {
            try {
              final tempDir = await getTemporaryDirectory();
              final fileName = 'camera_${DateTime.now().millisecondsSinceEpoch}.jpg';
              final newPath = '${tempDir.path}/$fileName';
              await File(image.path).copy(newPath);
              imagePath = newPath;
            } catch (copyError) {
              debugPrint('⚠️ Failed to copy: $copyError');
            }
          }
        }

        // Sanitize path (remove file:// prefix if present)
        if (imagePath.startsWith('file://')) {
          try {
            imagePath = Uri.parse(imagePath).toFilePath();
          } catch (e) {
            debugPrint('⚠️ Failed to parse URI, stripping prefix manually: $e');
            imagePath = imagePath.replaceFirst('file://', '');
          }
        }
        
        // Navigate to full-screen preview
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => _ImagePreviewScreen(
                imagePath: imagePath,
                onSearch: (path) {
                  Navigator.pop(context);
                  _performImageSearch(path);
                },
                onCrop: _cropImage,
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
        aspectRatioPresets: [
          CropAspectRatioPreset.original,
          CropAspectRatioPreset.square,
          CropAspectRatioPreset.ratio4x3,
        ],
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primary500,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
          ),
          IOSUiSettings(
            title: 'Crop Image',
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
      // Ensure image is under 1MB before upload (backend limit)
      String finalPath = imagePath;
      final originalSize = File(imagePath).lengthSync();
      debugPrint('🔍 Original image size: $originalSize bytes');
      
      if (originalSize > 900000) { // If over 900KB, compress
        debugPrint('⚠️ Image too large, compressing before upload...');
        try {
          final tempDir = await getTemporaryDirectory();
          final compressPath = '${tempDir.path}/upload_${DateTime.now().millisecondsSinceEpoch}.jpg';
          
          // First pass: moderate compression
          var quality = originalSize > 2000000 ? 50 : 65; // More aggressive for very large files
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
            debugPrint('📏 Compressed to: $compressedSize bytes (quality: $quality)');
            
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
          debugPrint('⚠️ Compression failed: $e');
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
    
    final searchBarBgColor = Color.lerp(
      Colors.black.withOpacity(0.3),
      isDark ? const Color(0xFF2A2A2A) : Colors.white,
      snappedOpacity,
    )!;

    final searchIconColor = Color.lerp(
      Colors.white70,
      AppColors.neutral400,
      snappedOpacity,
    )!;

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
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                if (widget.opacity < 0.5)
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: Image.asset(
                      'assets/images/chihelo dark color  2363x2363.png',
                      width: 36,
                      height: 36,
                      fit: BoxFit.contain,
                    ),
                  ),

                Expanded(
                  child: GestureDetector(
                      onTap: _showOverlay,
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: searchBarBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: widget.opacity > 0.5
                              ? Border.all(color: AppColors.neutral200, width: 1)
                              : null,
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 16),
                            Icon(Iconsax.search_normal_1, color: searchIconColor, size: 18),
                            const SizedBox(width: 10),
                            Text('Search products...', style: TextStyle(color: searchIconColor, fontSize: 14)),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),
                  _FloatingIconButton(icon: Iconsax.camera, color: widget.iconColor, bgOpacity: widget.opacity, onPressed: _pickImage),
                  const SizedBox(width: 8),
                  _FloatingIconButton(icon: Iconsax.notification, color: widget.iconColor, bgOpacity: widget.opacity, onPressed: () {}),
                ],
              ),
            ),

            // Horizontal Category Bar with Pagination
            Consumer<CategoryService>(
              builder: (context, categoryService, _) {
                final categories = categoryService.categories;
                if (categories.isEmpty && !categoryService.isLoading) {
                  return const SizedBox.shrink();
                }
                
                return Container(
                  height: 36,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListView.builder(
                    controller: _categoryScrollController,
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    itemCount: categories.length + 1 + (categoryService.isLoading ? 1 : 0),
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

    // Apply blur when over banner (opacity < 1) - use RepaintBoundary for performance
    if (blurAmount > 0.5) {
      return RepaintBoundary(
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
      );
    }

    // Solid background when scrolled
    return Container(
      decoration: BoxDecoration(
        color: widget.headerBgColor,
        boxShadow: boxShadow,
      ),
      child: headerContent,
    );
  }
}

class _FloatingIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double bgOpacity;
  final VoidCallback onPressed;

  const _FloatingIconButton({
    required this.icon,
    required this.color,
    required this.bgOpacity,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = bgOpacity < 0.5 ? Colors.black.withOpacity(0.2) : Colors.transparent;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
        child: Icon(icon, color: color, size: 20),
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
    // When not scrolled (opacity < 0.5), text is white (over banner)
    // When scrolled (opacity >= 0.5), text follows the theme (white in dark, black in light)
    final isScrolled = opacity >= 0.5;
    final effectiveTextColor = isScrolled ? textColor : Colors.white;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary500 : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : effectiveTextColor,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              fontSize: 13,
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
