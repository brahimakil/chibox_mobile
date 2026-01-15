import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:camera/camera.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/object_detection_service.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../shared/widgets/sheets/product_filter_sheet.dart';
import 'visual_search_widgets.dart';

class VisualSearchScreen extends StatefulWidget {
  const VisualSearchScreen({super.key});

  @override
  State<VisualSearchScreen> createState() => _VisualSearchScreenState();
}

class _VisualSearchScreenState extends State<VisualSearchScreen>
    with SingleTickerProviderStateMixin {
  // Camera
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  bool _isCameraFrozen = false;
  bool _isFlashOn = false;
  XFile? _frozenImage;
  
  // Search state
  bool _isSearching = false;
  bool _hasResults = false;
  String? _errorMessage;
  final ImagePicker _imagePicker = ImagePicker();
  final ObjectDetectionService _objectDetection = ObjectDetectionService.instance;
  
  // Products
  List<Product> _products = [];
  String? _lastSearchedImagePath;
  String? _convertedImageUrl;
  
  // Detection suggestions
  DetectionResult? _detectionResult;
  int _selectedSuggestionIndex = 0;
  
  // Cache for search results (key = "suggestionIndex_sortBy_minPrice_maxPrice")
  final Map<String, _SuggestionCache> _searchCache = {};
  
  // Helper to generate cache key
  String _getCacheKey(int suggestionIndex, ProductFilterState filter) {
    return '${suggestionIndex}_${filter.sortBy.apiValue}_${filter.minPrice ?? 'null'}_${filter.maxPrice ?? 'null'}';
  }
  
  // Filter & Pagination
  ProductFilterState _filterState = const ProductFilterState();
  int _currentPage = 1;
  bool _isLoadingMore = false;
  bool _hasMorePages = true;
  int _totalProducts = 0;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;
  
  // Prefetch
  bool _isPrefetching = false;
  List<Product> _prefetchedProducts = [];
  
  // Search ID for cancellation
  int _currentSearchId = 0;
  
  // Sheet controller
  final DraggableScrollableController _sheetController = DraggableScrollableController();
  
  // Back press tracking for double-tap exit
  DateTime? _lastBackPress;
  
  // Scan animation
  late AnimationController _scanController;
  
  // Wishlist sync
  StreamSubscription? _wishlistSubscription;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _initObjectDetection();
    
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _wishlistSubscription = WishlistHelper.onStatusChanged.listen((update) {
      if (!mounted) return;
      final index = _products.indexWhere((p) => p.id == update.id);
      if (index != -1) {
        setState(() {
          _products[index] = _products[index].copyWith(isLiked: update.isLiked);
        });
      }
    });
  }
  
  Future<void> _initObjectDetection() async {
    try {
      await _objectDetection.initialize();
    } catch (e) {
      debugPrint('⚠️ Object detection init failed: $e');
    }
  }

  @override
  void dispose() {
    _wishlistSubscription?.cancel();
    _cameraController?.dispose();
    _scanController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.off : FlashMode.torch);
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
      debugPrint('Flash toggle failed: $e');
    }
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _errorMessage = 'No cameras available');
        return;
      }

      final backCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        backCamera, 
        ResolutionPreset.medium, 
        enableAudio: false, 
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await _cameraController!.initialize();
      if (mounted) setState(() => _isCameraInitialized = true);
    } catch (e) {
      setState(() => _errorMessage = 'Camera init failed: $e');
    }
  }

  Future<void> _captureAndSearch() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized || _isSearching) return;

    try {
      final XFile photo = await _cameraController!.takePicture();
      _currentSearchId++;
      final searchId = _currentSearchId;
      
      setState(() {
        _isSearching = true;
        _isCameraFrozen = true;
        _frozenImage = photo;
        _errorMessage = null;
        _currentPage = 1;
        _hasMorePages = true;
        _detectionResult = null;
        _selectedSuggestionIndex = 0;
      });
      
      // Clear previous cache for new capture
      _searchCache.clear();
      
      _scanController.repeat();
      await _cameraController!.pausePreview();

      String searchImagePath = photo.path;
      try {
        final result = await _objectDetection.detectObjectsWithSuggestions(
          photo.path, 
          maxSuggestions: 4, 
          generateCrops: true,
        );
        if (searchId != _currentSearchId) return;
        setState(() => _detectionResult = result);
        
        if (result.hasSuggestions && result.primaryObject!.croppedImagePath != null) {
          searchImagePath = result.primaryObject!.croppedImagePath!;
        } else {
          final crop = await _objectDetection.generateCenterCrop(photo.path);
          if (crop != null) searchImagePath = crop;
        }
      } catch (e) {
        debugPrint('⚠️ Detection failed: $e');
      }

      await _searchWithImage(File(searchImagePath), searchId: searchId, suggestionIndex: 0);
    } catch (e) {
      _scanController.stop();
      _resumeCamera();
      setState(() { 
        _errorMessage = 'Capture failed: $e'; 
        _isSearching = false; 
        _isCameraFrozen = false; 
      });
    }
  }
  
  Future<void> _searchWithSuggestion(int index) async {
    if (_detectionResult == null || index >= _detectionResult!.suggestions.length) return;
    if (index == _selectedSuggestionIndex && _products.isNotEmpty) return;
    
    final suggestion = _detectionResult!.suggestions[index];
    if (suggestion.croppedImagePath == null) return;
    
    // Check if we have cached results for this suggestion + current filter
    final cacheKey = _getCacheKey(index, _filterState);
    if (_searchCache.containsKey(cacheKey)) {
      final cached = _searchCache[cacheKey]!;
      debugPrint('📦 Using cached results for key: $cacheKey (${cached.products.length} products)');
      setState(() {
        _selectedSuggestionIndex = index;
        _products = cached.products;
        _totalProducts = cached.totalProducts;
        _hasMorePages = cached.hasMorePages;
        _currentPage = cached.currentPage;
        _convertedImageUrl = cached.convertedImageUrl;
        _lastSearchedImagePath = suggestion.croppedImagePath;
        _hasResults = true;
        _isSearching = false;
      });
      return;
    }
    
    _currentSearchId++;
    final searchId = _currentSearchId;
    
    setState(() {
      _selectedSuggestionIndex = index;
      _isSearching = true;
      _currentPage = 1;
      _hasMorePages = true;
      _products = [];
      _consecutiveErrors = 0;
      _prefetchedProducts = [];
      _convertedImageUrl = null;
    });
    
    _scanController.repeat();
    await _searchWithImage(File(suggestion.croppedImagePath!), searchId: searchId, suggestionIndex: index);
  }
  
  Future<void> _resumeCamera({bool clearDetections = true}) async {
    if (_cameraController != null && _cameraController!.value.isInitialized) {
      try {
        await _cameraController!.resumePreview();
        setState(() { 
          _isCameraFrozen = false; 
          _frozenImage = null; 
          if (clearDetections) _detectionResult = null;
        });
      } catch (e) {
        debugPrint('Resume camera failed: $e');
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery, 
        imageQuality: 85,
      );
      if (pickedFile == null) return;

      if (_cameraController != null && _cameraController!.value.isInitialized) {
        await _cameraController!.pausePreview();
      }
      
      _currentSearchId++;
      final searchId = _currentSearchId;
      
      setState(() {
        _isSearching = true;
        _isCameraFrozen = true;
        _frozenImage = pickedFile;
        _errorMessage = null;
        _currentPage = 1;
        _hasMorePages = true;
        _detectionResult = null;
        _selectedSuggestionIndex = 0;
      });
      
      // Clear previous cache for new gallery pick
      _searchCache.clear();
      
      _scanController.repeat();
      
      String searchImagePath = pickedFile.path;
      try {
        final result = await _objectDetection.detectObjectsWithSuggestions(
          pickedFile.path, 
          maxSuggestions: 4, 
          generateCrops: true,
        );
        if (searchId != _currentSearchId) return;
        setState(() => _detectionResult = result);
        
        if (result.hasSuggestions && result.primaryObject!.croppedImagePath != null) {
          searchImagePath = result.primaryObject!.croppedImagePath!;
        } else {
          final crop = await _objectDetection.generateCenterCrop(pickedFile.path);
          if (crop != null) searchImagePath = crop;
        }
      } catch (e) {
        debugPrint('⚠️ Detection failed: $e');
      }
      
      if (searchId != _currentSearchId) return;
      await _searchWithImage(File(searchImagePath), searchId: searchId, suggestionIndex: 0);
    } catch (e) {
      _scanController.stop();
      _resumeCamera();
      setState(() { 
        _errorMessage = 'Gallery pick failed: $e'; 
        _isSearching = false; 
      });
    }
  }

  Future<void> _searchWithImage(File imageFile, {int? searchId, int? suggestionIndex}) async {
    final thisSearchId = searchId ?? _currentSearchId;
    
    try {
      final tempDir = await getTemporaryDirectory();
      final compressedPath = '${tempDir.path}/visual_search_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final compressedFile = await FlutterImageCompress.compressAndGetFile(
        imageFile.absolute.path, 
        compressedPath, 
        quality: 70, 
        minWidth: 800, 
        minHeight: 800,
      );

      final fileToUpload = compressedFile != null ? File(compressedFile.path) : imageFile;
      _lastSearchedImagePath = fileToUpload.path;
      _convertedImageUrl = null;
      _prefetchedProducts = [];

      final homeService = Provider.of<HomeService>(context, listen: false);
      final response = await homeService.searchByImagePaginated(
        fileToUpload.path, 
        page: 1, 
        perPage: 30,
        sortBy: _filterState.sortBy.apiValue, 
        minPrice: _filterState.minPrice, 
        maxPrice: _filterState.maxPrice,
      );
      
      if (thisSearchId != _currentSearchId) return;

      final products = response['products'] as List<Product>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>?;
      _convertedImageUrl = response['converted_url'] as String?;
      
      _scanController.stop();
      _scanController.reset();
      
      if (products.isNotEmpty) {
        bool hasMore = pagination != null 
            ? (pagination['current_page'] ?? 1) < (pagination['last_page'] ?? 1)
            : products.length >= 20;
        
        final totalProducts = pagination?['total'] ?? products.length;
        
        // Cache results if this was a suggestion search
        if (suggestionIndex != null) {
          final cacheKey = _getCacheKey(suggestionIndex, _filterState);
          _searchCache[cacheKey] = _SuggestionCache(
            products: products,
            totalProducts: totalProducts,
            hasMorePages: hasMore,
            currentPage: 1,
            convertedImageUrl: _convertedImageUrl,
          );
          debugPrint('💾 Cached results for key: $cacheKey (${products.length} products)');
        }
        
        setState(() {
          _products = products;
          _hasResults = true;
          _isSearching = false;
          _currentPage = 1;
          _totalProducts = totalProducts;
          _hasMorePages = hasMore;
        });
        
        WidgetsBinding.instance.addPostFrameCallback((_) => _expandSheet());
        return;
      }

      setState(() { 
        _products = []; 
        _hasResults = true; 
        _isSearching = false; 
        _errorMessage = 'No products found'; 
      });
    } catch (e) {
      _scanController.stop();
      _scanController.reset();
      setState(() { 
        _isSearching = false; 
        _errorMessage = 'Search failed: $e'; 
      });
    }
  }
  
  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore || !_hasMorePages || _lastSearchedImagePath == null) return;
    if (_consecutiveErrors >= _maxConsecutiveErrors) return;
    
    if (_prefetchedProducts.isNotEmpty) {
      setState(() {
        _products.addAll(_prefetchedProducts);
        _currentPage++;
        _hasMorePages = _prefetchedProducts.length >= 20;
      });
      _prefetchedProducts = [];
      _consecutiveErrors = 0;
      return;
    }
    
    setState(() => _isLoadingMore = true);
    
    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      final response = await homeService.searchByImagePaginated(
        _lastSearchedImagePath!, 
        page: _currentPage + 1, 
        perPage: 30,
        sortBy: _filterState.sortBy.apiValue, 
        minPrice: _filterState.minPrice, 
        maxPrice: _filterState.maxPrice,
        imageUrl: _convertedImageUrl,
      );
      
      final newProducts = response['products'] as List<Product>? ?? [];
      final pagination = response['pagination'] as Map<String, dynamic>?;
      
      if (response['converted_url'] != null) {
        _convertedImageUrl = response['converted_url'] as String;
      }
      
      if (newProducts.isEmpty) {
        _consecutiveErrors++;
        if (_consecutiveErrors >= _maxConsecutiveErrors) {
          setState(() { _hasMorePages = false; _isLoadingMore = false; });
          return;
        }
      } else {
        _consecutiveErrors = 0;
      }
      
      setState(() {
        _products.addAll(newProducts);
        _currentPage++;
        _isLoadingMore = false;
        _hasMorePages = pagination != null 
            ? (pagination['current_page'] ?? _currentPage) < (pagination['last_page'] ?? 1)
            : newProducts.length >= 20;
      });
    } catch (e) {
      _consecutiveErrors++;
      setState(() { 
        _isLoadingMore = false; 
        if (_consecutiveErrors >= _maxConsecutiveErrors) _hasMorePages = false; 
      });
    }
  }
  
  Future<void> _prefetchNextPage() async {
    if (_isPrefetching || !_hasMorePages || _prefetchedProducts.isNotEmpty || _lastSearchedImagePath == null) return;
    if (_consecutiveErrors >= _maxConsecutiveErrors) return;
    
    _isPrefetching = true;
    
    try {
      final homeService = Provider.of<HomeService>(context, listen: false);
      final response = await homeService.searchByImagePaginated(
        _lastSearchedImagePath!, 
        page: _currentPage + 1, 
        perPage: 30,
        sortBy: _filterState.sortBy.apiValue, 
        minPrice: _filterState.minPrice, 
        maxPrice: _filterState.maxPrice,
        imageUrl: _convertedImageUrl,
      );
      
      final newProducts = response['products'] as List<Product>? ?? [];
      if (newProducts.isNotEmpty) {
        _prefetchedProducts = newProducts;
        if (response['converted_url'] != null) {
          _convertedImageUrl = response['converted_url'] as String;
        }
      }
    } catch (e) {
      debugPrint('Prefetch error: $e');
    }
    
    _isPrefetching = false;
  }

  void _collapseSheet() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.08, 
        duration: const Duration(milliseconds: 250), 
        curve: Curves.easeOut,
      );
    }
  }
  
  void _expandSheet() {
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.85, 
        duration: const Duration(milliseconds: 300), 
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _startNewSearch() {
    // First collapse the sheet with animation
    if (_sheetController.isAttached) {
      _sheetController.animateTo(
        0.08,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      ).then((_) {
        // Then reset state after animation completes
        _resumeCamera(clearDetections: true);
        if (mounted) {
          setState(() {
            _hasResults = false;
            _products = [];
            _lastSearchedImagePath = null;
            _filterState = const ProductFilterState();
            _errorMessage = null;
            _currentPage = 1;
            _hasMorePages = true;
            _detectionResult = null;
            _selectedSuggestionIndex = 0;
            _totalProducts = 0;
          });
          // Clear cache for new search
          _searchCache.clear();
        }
      });
    } else {
      // Fallback if sheet not attached
      _resumeCamera(clearDetections: true);
      setState(() {
        _hasResults = false;
        _products = [];
        _lastSearchedImagePath = null;
        _filterState = const ProductFilterState();
        _errorMessage = null;
        _currentPage = 1;
        _hasMorePages = true;
        _detectionResult = null;
        _selectedSuggestionIndex = 0;
        _totalProducts = 0;
      });
      // Clear cache for new search
      _searchCache.clear();
    }
  }

  Future<void> _showFilterSheet() async {
    final result = await ProductFilterSheet.show(context, currentFilter: _filterState);
    if (result != null) _applyFilter(result);
  }
  
  Future<void> _applyFilter(ProductFilterState newFilter) async {
    if (newFilter == _filterState) return;
    
    // Check cache first for this filter + current suggestion
    final cacheKey = _getCacheKey(_selectedSuggestionIndex, newFilter);
    if (_searchCache.containsKey(cacheKey)) {
      final cached = _searchCache[cacheKey]!;
      debugPrint('📦 Using cached filtered results for key: $cacheKey (${cached.products.length} products)');
      setState(() {
        _filterState = newFilter;
        _products = cached.products;
        _totalProducts = cached.totalProducts;
        _hasMorePages = cached.hasMorePages;
        _currentPage = cached.currentPage;
        _convertedImageUrl = cached.convertedImageUrl;
        _isSearching = false;
      });
      return;
    }
    
    // IMMEDIATELY clear products and show loading skeleton
    setState(() { 
      _filterState = newFilter; 
      _currentPage = 1; 
      _hasMorePages = true; 
      _isSearching = true;
      _products = []; // Clear to show skeleton immediately
      _prefetchedProducts = [];
    });
    
    if (_lastSearchedImagePath != null) {
      final homeService = Provider.of<HomeService>(context, listen: false);
      try {
        final response = await homeService.searchByImagePaginated(
          _lastSearchedImagePath!, 
          page: 1, 
          perPage: 30,
          sortBy: newFilter.sortBy.apiValue, 
          minPrice: newFilter.minPrice, 
          maxPrice: newFilter.maxPrice,
        );
        
        final products = response['products'] as List<Product>? ?? [];
        final pagination = response['pagination'] as Map<String, dynamic>?;
        final convertedUrl = response['converted_url'] as String?;
        final totalProducts = pagination?['total'] ?? products.length;
        final hasMore = pagination != null 
            ? (pagination['current_page'] ?? 1) < (pagination['last_page'] ?? 1) 
            : products.length >= 20;
        
        // Cache the filtered results
        _searchCache[cacheKey] = _SuggestionCache(
          products: products,
          totalProducts: totalProducts,
          hasMorePages: hasMore,
          currentPage: 1,
          convertedImageUrl: convertedUrl,
        );
        debugPrint('💾 Cached filtered results for key: $cacheKey (${products.length} products)');
        
        setState(() {
          _products = products;
          _totalProducts = totalProducts;
          _isSearching = false;
          _hasMorePages = hasMore;
          _convertedImageUrl = convertedUrl;
        });
      } catch (e) {
        setState(() => _isSearching = false);
      }
    }
  }
  
  void _handleBack() {
    // If results are showing, close sheet and start new search (return to camera)
    if (_hasResults) {
      _startNewSearch();
      return;
    }
    
    // Camera mode - double tap to exit
    final now = DateTime.now();
    if (_lastBackPress != null && now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      // Second tap within 2 seconds - exit
      Navigator.pop(context);
    } else {
      // First tap - show hint and track time
      _lastBackPress = now;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // White icons on dark camera background
        statusBarBrightness: Brightness.dark, // For iOS
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // Background: Camera / Frozen Image
            Positioned.fill(child: _buildCameraView()),

            // Viewfinder overlay
            if (_isCameraInitialized && !_hasResults && !_isCameraFrozen)
              Positioned.fill(child: CustomPaint(painter: ViewfinderPainter())),

            // Scan animation
            if (_isSearching)
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, _) => CustomPaint(
                    painter: ScanLinePainter(
                      _scanController.value,
                      fullScreen: _isCameraFrozen, // Full screen scan when image is frozen (gallery/captured)
                    ),
                  ),
                ),
              ),

            // Top bar
            Positioned(
              top: topPadding + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  VSTopButton(icon: Icons.arrow_back_ios_new_rounded, onTap: _handleBack),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                    child: const Text('Visual Search', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                  VSTopButton(icon: _isFlashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded, onTap: _toggleFlash),
                ],
              ),
            ),

            // Bottom camera controls (only when NOT showing results)
            if (!_hasResults)
              Positioned(
                left: 0, 
                right: 0, 
                bottom: bottomPadding + 140,
                child: _buildCameraControls(),
              ),

            // Results Sheet
            DraggableScrollableSheet(
              controller: _sheetController,
              initialChildSize: 0.08,
            minChildSize: 0.08,
            maxChildSize: 0.92,
            snap: true,
            snapSizes: const [0.08, 0.5, 0.92],
            builder: (context, scrollController) => VSResultsSheet(
              scrollController: scrollController,
              isDark: isDark,
              hasResults: _hasResults,
              isSearching: _isSearching,
              products: _products,
              totalProducts: _totalProducts,
              isLoadingMore: _isLoadingMore,
              hasMorePages: _hasMorePages,
              filterState: _filterState,
              detectionResult: _detectionResult,
              selectedSuggestionIndex: _selectedSuggestionIndex,
              onStartNewSearch: _startNewSearch,
              onShowFilter: _showFilterSheet,
              onApplyFilter: _applyFilter,
              onLoadMore: _loadMoreProducts,
              onPrefetch: _prefetchNextPage,
              onSelectSuggestion: _searchWithSuggestion,
              onExpandSheet: _expandSheet,
              isPrefetching: _isPrefetching,
              prefetchedProducts: _prefetchedProducts,
            ),
          ),
        ],
      ),
      ),
    );
  }
  
  Widget _buildCameraView() {
    if (_isCameraFrozen && _frozenImage != null) {
      // Show the full uploaded/captured image with proper aspect ratio
      // Use BoxFit.contain so the entire image is visible (no cropping)
      return Container(
        color: Colors.black,
        child: Center(
          child: Image.file(
            File(_frozenImage!.path), 
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      );
    }
    
    if (_isCameraInitialized && _cameraController != null) {
      return ClipRect(
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _cameraController!.value.previewSize!.height,
            height: _cameraController!.value.previewSize!.width,
            child: CameraPreview(_cameraController!),
          ),
        ),
      );
    }
    
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.white)));
    }
    
    return const Center(child: CircularProgressIndicator(color: Colors.white));
  }
  
  Widget _buildCameraControls() {
    final hasSuggestions = _detectionResult != null && _detectionResult!.suggestions.length > 1;
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasSuggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: VSSuggestionsRow(
              suggestions: _detectionResult!.suggestions,
              selectedIndex: _selectedSuggestionIndex,
              isSearching: _isSearching,
              onSelect: _searchWithSuggestion,
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              VSControlButton(icon: Iconsax.gallery, size: 52, onTap: _pickFromGallery),
              VSCaptureButton(isSearching: _isSearching, onTap: _captureAndSearch),
              const SizedBox(width: 52),
            ],
          ),
        ),
      ],
    );
  }
}

// Cache class for suggestion search results
class _SuggestionCache {
  final List<Product> products;
  final int totalProducts;
  final bool hasMorePages;
  final int currentPage;
  final String? convertedImageUrl;
  
  _SuggestionCache({
    required this.products,
    required this.totalProducts,
    required this.hasMorePages,
    required this.currentPage,
    this.convertedImageUrl,
  });
}
