import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
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
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/wishlist_helper.dart';
import '../../../shared/widgets/sheets/product_filter_sheet.dart';
import '../widgets/manual_crop_overlay.dart';
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
  
  // Interactive crop selector (auto-shown after capture)
  bool _showCropSelector = false;
  Rect _cropSelectorRect = Rect.zero; // Normalized (0-1) coordinates
  _CropHandle? _activeCropHandle;
  Offset? _lastCropPanPosition;
  
  // Manual crop mode (full overlay)
  bool _isManualCropMode = false;
  Size? _currentImageSize; // Actual dimensions of the current image
  String? _pendingCropImagePath; // Track the crop that's being searched
  
  // Search progress tracking
  double _searchProgress = 0.0;
  Timer? _progressTimer;
  
  // Quick draw-to-crop feature (tap and drag on image)
  bool _isDrawingCrop = false;
  Offset? _drawStartPoint;
  Offset? _drawCurrentPoint;
  
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
  bool _isSheetExpanded = false; // Track if sheet is expanded beyond minimum
  
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
    
    // Listen to sheet position changes
    _sheetController.addListener(_onSheetPositionChanged);
  }
  
  Future<void> _initObjectDetection() async {
    try {
      await _objectDetection.initialize();
    } catch (e) {
    }
  }

  void _onSheetPositionChanged() {
    if (!_sheetController.isAttached) return;
    final isExpanded = _sheetController.size > 0.15; // Consider expanded if above 15%
    if (isExpanded != _isSheetExpanded) {
      setState(() => _isSheetExpanded = isExpanded);
    }
  }

  @override
  void dispose() {
    _sheetController.removeListener(_onSheetPositionChanged);
    _wishlistSubscription?.cancel();
    _cameraController?.dispose();
    _scanController.dispose();
    _sheetController.dispose();
    _progressTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) return;
    try {
      await _cameraController!.setFlashMode(_isFlashOn ? FlashMode.off : FlashMode.torch);
      setState(() => _isFlashOn = !_isFlashOn);
    } catch (e) {
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
        ResolutionPreset.high, // Higher resolution for better visual search results
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
      
      // Get image dimensions
      final bytes = await File(photo.path).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _currentImageSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      
      setState(() {
        _isSearching = true;
        _isCameraFrozen = true;
        _frozenImage = photo;
        _errorMessage = null;
        _currentPage = 1;
        _hasMorePages = true;
        _detectionResult = null;
        _selectedSuggestionIndex = 0;
        _showCropSelector = false;
        _searchProgress = 0.0;
      });
      
      // Start progress simulation
      _startProgressSimulation();
      
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
        
        // Set crop selector to primary object's bounding box (normalized)
        Rect normalizedRect = const Rect.fromLTWH(0.15, 0.15, 0.7, 0.7); // Default center
        if (result.hasSuggestions && result.primaryObject != null) {
          final box = result.primaryObject!.boundingBox;
          normalizedRect = Rect.fromLTRB(
            box.left / _currentImageSize!.width,
            box.top / _currentImageSize!.height,
            box.right / _currentImageSize!.width,
            box.bottom / _currentImageSize!.height,
          );
        }
        
        setState(() {
          _detectionResult = result;
          _cropSelectorRect = normalizedRect;
          _showCropSelector = true;
        });
        
        if (result.hasSuggestions && result.primaryObject!.croppedImagePath != null) {
          searchImagePath = result.primaryObject!.croppedImagePath!;
        } else {
          final crop = await _objectDetection.generateCenterCrop(photo.path);
          if (crop != null) searchImagePath = crop;
        }
      } catch (e) {
        // Show default center crop selector
        setState(() {
          _cropSelectorRect = const Rect.fromLTWH(0.15, 0.15, 0.7, 0.7);
          _showCropSelector = true;
        });
      }

      await _searchWithImage(File(searchImagePath), searchId: searchId, suggestionIndex: 0);
    } catch (e) {
      _scanController.stop();
      _stopProgressSimulation();
      _resumeCamera();
      setState(() { 
        _errorMessage = 'Capture failed: $e'; 
        _isSearching = false; 
        _isCameraFrozen = false; 
      });
    }
  }
  
  void _startProgressSimulation() {
    _progressTimer?.cancel();
    _searchProgress = 0.0;
    _progressTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (!mounted || !_isSearching) {
        timer.cancel();
        return;
      }
      setState(() {
        // Simulate progress - fast at first, slows down as it approaches 90%
        if (_searchProgress < 0.9) {
          _searchProgress += (0.9 - _searchProgress) * 0.08;
        }
      });
    });
  }
  
  void _stopProgressSimulation() {
    _progressTimer?.cancel();
    if (mounted) {
      setState(() => _searchProgress = 1.0);
    }
  }
  
  Future<void> _searchWithSuggestion(int index) async {
    if (_detectionResult == null || index >= _detectionResult!.suggestions.length) return;
    if (index == _selectedSuggestionIndex && _products.isNotEmpty) return;
    
    final suggestion = _detectionResult!.suggestions[index];
    if (suggestion.croppedImagePath == null) return;
    
    // Update crop selector to match the selected suggestion's bounding box
    if (_currentImageSize != null) {
      final bbox = suggestion.boundingBox;
      final normalizedRect = Rect.fromLTRB(
        (bbox.left / _currentImageSize!.width).clamp(0.0, 1.0),
        (bbox.top / _currentImageSize!.height).clamp(0.0, 1.0),
        (bbox.right / _currentImageSize!.width).clamp(0.0, 1.0),
        (bbox.bottom / _currentImageSize!.height).clamp(0.0, 1.0),
      );
      setState(() {
        _cropSelectorRect = normalizedRect;
        _showCropSelector = true;
      });
    }
    
    // Check if we have cached results for this suggestion + current filter
    final cacheKey = _getCacheKey(index, _filterState);
    if (_searchCache.containsKey(cacheKey)) {
      final cached = _searchCache[cacheKey]!;
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
    
    _startProgressSimulation();
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
      
      // CRITICAL: Convert gallery image to JPEG first
      // Gallery images might be HEIC, PNG, WEBP etc. which TMAPI may not handle
      String normalizedImagePath = pickedFile.path;
      try {
        final tempDir = await getTemporaryDirectory();
        final normalizedPath = '${tempDir.path}/gallery_normalized_${DateTime.now().millisecondsSinceEpoch}.jpg';
        
        final normalizedFile = await FlutterImageCompress.compressAndGetFile(
          pickedFile.path,
          normalizedPath,
          quality: 90, // High quality for better search results
          format: CompressFormat.jpeg, // Force JPEG format
          keepExif: false,
        );
        
        if (normalizedFile != null && await File(normalizedFile.path).exists()) {
          normalizedImagePath = normalizedFile.path;
        } else {
        }
      } catch (e) {
      }
      
      // Get image dimensions from normalized image
      final bytes = await File(normalizedImagePath).readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      _currentImageSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
      frame.image.dispose();
      
      setState(() {
        _isSearching = true;
        _isCameraFrozen = true;
        _frozenImage = pickedFile;
        _errorMessage = null;
        _currentPage = 1;
        _hasMorePages = true;
        _detectionResult = null;
        _selectedSuggestionIndex = 0;
        _showCropSelector = false;
        _searchProgress = 0.0;
      });
      
      // Start progress simulation
      _startProgressSimulation();
      
      // Clear previous cache for new gallery pick
      _searchCache.clear();
      
      _scanController.repeat();
      
      // Use normalized image for detection and search
      String searchImagePath = normalizedImagePath;
      try {
        final result = await _objectDetection.detectObjectsWithSuggestions(
          normalizedImagePath, // Use normalized JPEG
          maxSuggestions: 4, 
          generateCrops: true,
        );
        if (searchId != _currentSearchId) return;
        setState(() => _detectionResult = result);
        
        if (result.hasSuggestions && result.primaryObject!.croppedImagePath != null) {
          searchImagePath = result.primaryObject!.croppedImagePath!;
          
          // Calculate normalized rect for the crop selector based on primary object
          if (result.primaryObject != null && _currentImageSize != null) {
            final bbox = result.primaryObject!.boundingBox;
            final normalizedRect = Rect.fromLTRB(
              (bbox.left / _currentImageSize!.width).clamp(0.0, 1.0),
              (bbox.top / _currentImageSize!.height).clamp(0.0, 1.0),
              (bbox.right / _currentImageSize!.width).clamp(0.0, 1.0),
              (bbox.bottom / _currentImageSize!.height).clamp(0.0, 1.0),
            );
            setState(() {
              _cropSelectorRect = normalizedRect;
              _showCropSelector = true;
            });
          }
        } else {
          // Fallback: use center crop of normalized image
          final crop = await _objectDetection.generateCenterCrop(normalizedImagePath);
          if (crop != null) {
            searchImagePath = crop;
          }
          // searchImagePath already defaults to normalizedImagePath if crop fails
          
          // Show center crop selector
          setState(() {
            _cropSelectorRect = const Rect.fromLTRB(0.15, 0.15, 0.85, 0.85);
            _showCropSelector = true;
          });
        }
      } catch (e) {
        // searchImagePath is already set to normalizedImagePath
        // Show center crop selector on detection failure
        setState(() {
          _cropSelectorRect = const Rect.fromLTRB(0.15, 0.15, 0.85, 0.85);
          _showCropSelector = true;
        });
      }
      
      if (searchId != _currentSearchId) return;
      await _searchWithImage(File(searchImagePath), searchId: searchId, suggestionIndex: 0);
    } catch (e) {
      _scanController.stop();
      _stopProgressSimulation();
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
      File fileToUpload = imageFile;
      final originalSize = await imageFile.length();
      
      // Only compress if image is larger than 100KB to preserve quality for small images
      if (originalSize > 100 * 1024) {
        final tempDir = await getTemporaryDirectory();
        final compressedPath = '${tempDir.path}/visual_search_${DateTime.now().millisecondsSinceEpoch}.jpg';

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          imageFile.absolute.path, 
          compressedPath, 
          quality: 85, // Higher quality for better visual search accuracy
          minWidth: 600, // Minimum width to preserve features
          minHeight: 600, // Minimum height to preserve features
          keepExif: false, // Remove EXIF to reduce size slightly
        );
        
        if (compressedFile != null) {
          final compressedSize = await File(compressedFile.path).length();
          // Only use compressed version if it's still reasonably sized (>10KB)
          if (compressedSize > 10 * 1024) {
            fileToUpload = File(compressedFile.path);
          } else {
          }
        }
      } else {
      }
      
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
      _stopProgressSimulation();
      
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
      _stopProgressSimulation();
      setState(() { 
        _isSearching = false; 
        _errorMessage = 'Search failed: $e'; 
      });
    }
  }
  
  Future<void> _loadMoreProducts() async {
    // Guard against duplicate calls - but allow using prefetched products
    if (_isLoadingMore || !_hasMorePages || _lastSearchedImagePath == null) return;
    if (_consecutiveErrors >= _maxConsecutiveErrors) return;
    
    // Use prefetched products if available
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
    
    // Don't make API call if prefetch is already running for this page
    if (_isPrefetching) return;
    
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
    // Don't prefetch if already loading more, or if prefetch is already running
    if (_isPrefetching || _isLoadingMore || !_hasMorePages || _prefetchedProducts.isNotEmpty || _lastSearchedImagePath == null) return;
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
            _isManualCropMode = false;
            _currentImageSize = null;
            _showCropSelector = false;
            _cropSelectorRect = Rect.zero;
            _searchProgress = 0.0;
          });
          // Clear cache for new search
          _searchCache.clear();
          _stopProgressSimulation();
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
        _isManualCropMode = false;
        _currentImageSize = null;
        _showCropSelector = false;
        _cropSelectorRect = Rect.zero;
        _searchProgress = 0.0;
      });
      _stopProgressSimulation();
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
  
  // Manual crop methods
  void _enterManualCropMode() {
    if (_frozenImage == null || _currentImageSize == null) return;
    setState(() => _isManualCropMode = true);
  }
  
  void _exitManualCropMode() {
    setState(() {
      _isManualCropMode = false;
      _pendingCropImagePath = null;
    });
  }
  
  Future<void> _handleManualCropComplete(String croppedImagePath, Rect cropRect) async {
    // Create a new DetectedObject for the manual crop
    final manualCropObject = DetectedObject(
      boundingBox: cropRect,
      labels: [],
      trackingId: -1, // Use -1 to indicate manual crop
      croppedImagePath: croppedImagePath,
      areaRatio: (cropRect.width * cropRect.height) / 
          (_currentImageSize!.width * _currentImageSize!.height),
    );
    
    _currentSearchId++;
    final searchId = _currentSearchId;
    int newIndex = 0;
    
    // Add manual crop as a new suggestion if detectionResult exists
    if (_detectionResult != null) {
      final newSuggestions = [..._detectionResult!.suggestions, manualCropObject];
      newIndex = newSuggestions.length - 1;
      
      _detectionResult = DetectionResult(
        allObjects: _detectionResult!.allObjects,
        primaryObject: _detectionResult!.primaryObject,
        suggestions: newSuggestions,
        imageSize: _detectionResult!.imageSize,
        originalImagePath: _detectionResult!.originalImagePath,
      );
    } else {
      // No existing detection result - create one with just the manual crop
      _detectionResult = DetectionResult(
        allObjects: [manualCropObject],
        primaryObject: manualCropObject,
        suggestions: [manualCropObject],
        imageSize: _currentImageSize!,
        originalImagePath: _frozenImage!.path,
      );
    }
    
    // Keep overlay visible but show loading state by setting pending crop path
    setState(() {
      _pendingCropImagePath = croppedImagePath;
      _selectedSuggestionIndex = newIndex;
      _isSearching = true;
      _currentPage = 1;
      _hasMorePages = true;
      _products = [];
      _consecutiveErrors = 0;
      _prefetchedProducts = [];
      _convertedImageUrl = null;
    });
    
    _scanController.repeat();
    
    // Search and then dismiss overlay on next frame
    try {
      await _searchWithImage(File(croppedImagePath), searchId: searchId, suggestionIndex: newIndex);
    } finally {
      // Dismiss overlay after search completes (success or failure)
      if (mounted && _pendingCropImagePath == croppedImagePath) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _isManualCropMode = false;
              _pendingCropImagePath = null;
            });
          }
        });
      }
    }
  }
  
  // Quick draw-to-crop handlers
  void _onDrawStart(DragStartDetails details) {
    if (!_isCameraFrozen || _frozenImage == null || _isSearching || _isManualCropMode) return;
    setState(() {
      _isDrawingCrop = true;
      _drawStartPoint = details.localPosition;
      _drawCurrentPoint = details.localPosition;
    });
  }
  
  void _onDrawUpdate(DragUpdateDetails details) {
    if (!_isDrawingCrop) return;
    setState(() => _drawCurrentPoint = details.localPosition);
  }
  
  Future<void> _onDrawEnd(DragEndDetails details) async {
    if (!_isDrawingCrop || _drawStartPoint == null || _drawCurrentPoint == null) {
      setState(() {
        _isDrawingCrop = false;
        _drawStartPoint = null;
        _drawCurrentPoint = null;
      });
      return;
    }
    
    // Calculate the drawn rectangle
    final start = _drawStartPoint!;
    final end = _drawCurrentPoint!;
    final drawRect = Rect.fromPoints(start, end);
    
    // Reset drawing state
    setState(() {
      _isDrawingCrop = false;
      _drawStartPoint = null;
      _drawCurrentPoint = null;
    });
    
    // Minimum size check (at least 50x50 pixels to be a valid selection)
    if (drawRect.width.abs() < 50 || drawRect.height.abs() < 50) {
      return;
    }
    
    // Convert screen coordinates to image coordinates and perform crop
    await _performQuickCrop(drawRect);
  }
  
  Future<void> _performQuickCrop(Rect screenRect) async {
    if (_frozenImage == null || _currentImageSize == null) return;
    
    // We need to map the screen rect to the actual image coordinates
    // The image is displayed with BoxFit.contain, so we need to calculate the transform
    final context = this.context;
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate how the image is displayed (BoxFit.contain)
    final imageAspect = _currentImageSize!.width / _currentImageSize!.height;
    final screenAspect = screenSize.width / screenSize.height;
    
    double displayWidth, displayHeight, offsetX, offsetY;
    
    if (imageAspect > screenAspect) {
      // Image is wider - fits to width
      displayWidth = screenSize.width;
      displayHeight = screenSize.width / imageAspect;
      offsetX = 0;
      offsetY = (screenSize.height - displayHeight) / 2;
    } else {
      // Image is taller - fits to height
      displayHeight = screenSize.height;
      displayWidth = screenSize.height * imageAspect;
      offsetX = (screenSize.width - displayWidth) / 2;
      offsetY = 0;
    }
    
    // Convert screen coordinates to normalized (0-1) coordinates relative to displayed image
    final normalizedRect = Rect.fromLTRB(
      ((screenRect.left - offsetX) / displayWidth).clamp(0.0, 1.0),
      ((screenRect.top - offsetY) / displayHeight).clamp(0.0, 1.0),
      ((screenRect.right - offsetX) / displayWidth).clamp(0.0, 1.0),
      ((screenRect.bottom - offsetY) / displayHeight).clamp(0.0, 1.0),
    );
    
    // Ensure valid rectangle (left < right, top < bottom)
    final validRect = Rect.fromLTRB(
      normalizedRect.left < normalizedRect.right ? normalizedRect.left : normalizedRect.right,
      normalizedRect.top < normalizedRect.bottom ? normalizedRect.top : normalizedRect.bottom,
      normalizedRect.left < normalizedRect.right ? normalizedRect.right : normalizedRect.left,
      normalizedRect.top < normalizedRect.bottom ? normalizedRect.bottom : normalizedRect.top,
    );
    
    // Check if selection is within valid bounds
    if (validRect.width < 0.05 || validRect.height < 0.05) {
      return;
    }
    
    // Convert to actual pixel coordinates
    final pixelRect = Rect.fromLTRB(
      validRect.left * _currentImageSize!.width,
      validRect.top * _currentImageSize!.height,
      validRect.right * _currentImageSize!.width,
      validRect.bottom * _currentImageSize!.height,
    );
    
    // Use the ObjectDetectionService to crop the image
    final croppedPath = await _objectDetection.cropToObject(
      _frozenImage!.path,
      pixelRect,
      paddingPercent: 0.0, // No padding since user drew exact selection
      suffix: 'quick_crop',
    );
    
    if (croppedPath != null) {
      // Trigger the same flow as manual crop complete
      await _handleManualCropComplete(croppedPath, pixelRect);
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
  
  // Crop selector pan handlers (for auto-shown selector)
  void _onCropSelectorPanStart(DragStartDetails details) {
    if (!_showCropSelector || _isSearching || _isManualCropMode) return;
    
    // Calculate display rect to convert screen position
    final context = this.context;
    final screenSize = MediaQuery.of(context).size;
    final imageAspect = _currentImageSize != null 
        ? _currentImageSize!.width / _currentImageSize!.height 
        : 1.0;
    final screenAspect = screenSize.width / screenSize.height;
    
    double displayWidth, displayHeight, offsetX, offsetY;
    if (imageAspect > screenAspect) {
      displayWidth = screenSize.width;
      displayHeight = screenSize.width / imageAspect;
      offsetX = 0;
      offsetY = (screenSize.height - displayHeight) / 2;
    } else {
      displayHeight = screenSize.height;
      displayWidth = screenSize.height * imageAspect;
      offsetX = (screenSize.width - displayWidth) / 2;
      offsetY = 0;
    }
    
    // Convert touch position to normalized coordinates
    final touchX = (details.localPosition.dx - offsetX) / displayWidth;
    final touchY = (details.localPosition.dy - offsetY) / displayHeight;
    
    // Check which handle or if inside the rect
    _activeCropHandle = _getHandleAtPosition(touchX, touchY);
    _lastCropPanPosition = Offset(touchX, touchY);
  }
  
  _CropHandle? _getHandleAtPosition(double x, double y) {
    final rect = _cropSelectorRect;
    const threshold = 0.05; // Handle hit area
    
    // Check corners first
    if ((x - rect.left).abs() < threshold && (y - rect.top).abs() < threshold) {
      return _CropHandle.topLeft;
    }
    if ((x - rect.right).abs() < threshold && (y - rect.top).abs() < threshold) {
      return _CropHandle.topRight;
    }
    if ((x - rect.left).abs() < threshold && (y - rect.bottom).abs() < threshold) {
      return _CropHandle.bottomLeft;
    }
    if ((x - rect.right).abs() < threshold && (y - rect.bottom).abs() < threshold) {
      return _CropHandle.bottomRight;
    }
    
    // Check edges
    if ((x - rect.left).abs() < threshold && y > rect.top && y < rect.bottom) {
      return _CropHandle.left;
    }
    if ((x - rect.right).abs() < threshold && y > rect.top && y < rect.bottom) {
      return _CropHandle.right;
    }
    if ((y - rect.top).abs() < threshold && x > rect.left && x < rect.right) {
      return _CropHandle.top;
    }
    if ((y - rect.bottom).abs() < threshold && x > rect.left && x < rect.right) {
      return _CropHandle.bottom;
    }
    
    // Check if inside (for move)
    if (rect.contains(Offset(x, y))) {
      return _CropHandle.move;
    }
    
    return null;
  }
  
  void _onCropSelectorPanUpdate(DragUpdateDetails details) {
    if (_activeCropHandle == null || _lastCropPanPosition == null) return;
    
    final context = this.context;
    final screenSize = MediaQuery.of(context).size;
    final imageAspect = _currentImageSize != null 
        ? _currentImageSize!.width / _currentImageSize!.height 
        : 1.0;
    final screenAspect = screenSize.width / screenSize.height;
    
    double displayWidth, displayHeight, offsetX, offsetY;
    if (imageAspect > screenAspect) {
      displayWidth = screenSize.width;
      displayHeight = screenSize.width / imageAspect;
      offsetX = 0;
      offsetY = (screenSize.height - displayHeight) / 2;
    } else {
      displayHeight = screenSize.height;
      displayWidth = screenSize.height * imageAspect;
      offsetX = (screenSize.width - displayWidth) / 2;
      offsetY = 0;
    }
    
    final touchX = (details.localPosition.dx - offsetX) / displayWidth;
    final touchY = (details.localPosition.dy - offsetY) / displayHeight;
    
    final dx = touchX - _lastCropPanPosition!.dx;
    final dy = touchY - _lastCropPanPosition!.dy;
    
    setState(() {
      Rect newRect = _cropSelectorRect;
      
      switch (_activeCropHandle!) {
        case _CropHandle.topLeft:
          newRect = Rect.fromLTRB(
            (newRect.left + dx).clamp(0.0, newRect.right - 0.1),
            (newRect.top + dy).clamp(0.0, newRect.bottom - 0.1),
            newRect.right,
            newRect.bottom,
          );
          break;
        case _CropHandle.topRight:
          newRect = Rect.fromLTRB(
            newRect.left,
            (newRect.top + dy).clamp(0.0, newRect.bottom - 0.1),
            (newRect.right + dx).clamp(newRect.left + 0.1, 1.0),
            newRect.bottom,
          );
          break;
        case _CropHandle.bottomLeft:
          newRect = Rect.fromLTRB(
            (newRect.left + dx).clamp(0.0, newRect.right - 0.1),
            newRect.top,
            newRect.right,
            (newRect.bottom + dy).clamp(newRect.top + 0.1, 1.0),
          );
          break;
        case _CropHandle.bottomRight:
          newRect = Rect.fromLTRB(
            newRect.left,
            newRect.top,
            (newRect.right + dx).clamp(newRect.left + 0.1, 1.0),
            (newRect.bottom + dy).clamp(newRect.top + 0.1, 1.0),
          );
          break;
        case _CropHandle.left:
          newRect = Rect.fromLTRB(
            (newRect.left + dx).clamp(0.0, newRect.right - 0.1),
            newRect.top,
            newRect.right,
            newRect.bottom,
          );
          break;
        case _CropHandle.right:
          newRect = Rect.fromLTRB(
            newRect.left,
            newRect.top,
            (newRect.right + dx).clamp(newRect.left + 0.1, 1.0),
            newRect.bottom,
          );
          break;
        case _CropHandle.top:
          newRect = Rect.fromLTRB(
            newRect.left,
            (newRect.top + dy).clamp(0.0, newRect.bottom - 0.1),
            newRect.right,
            newRect.bottom,
          );
          break;
        case _CropHandle.bottom:
          newRect = Rect.fromLTRB(
            newRect.left,
            newRect.top,
            newRect.right,
            (newRect.bottom + dy).clamp(newRect.top + 0.1, 1.0),
          );
          break;
        case _CropHandle.move:
          final width = newRect.width;
          final height = newRect.height;
          double newLeft = (newRect.left + dx).clamp(0.0, 1.0 - width);
          double newTop = (newRect.top + dy).clamp(0.0, 1.0 - height);
          newRect = Rect.fromLTWH(newLeft, newTop, width, height);
          break;
      }
      
      _cropSelectorRect = newRect;
      _lastCropPanPosition = Offset(touchX, touchY);
    });
  }
  
  Future<void> _onCropSelectorPanEnd(DragEndDetails details) async {
    // Just reset the drag state - don't auto-search
    // User will press the search button when ready
    _activeCropHandle = null;
    _lastCropPanPosition = null;
  }
  
  // Search with the current crop selector position
  Future<void> _searchWithCropSelector() async {
    if (!_showCropSelector || _cropSelectorRect.width < 0.05 || _cropSelectorRect.height < 0.05) return;
    if (_currentImageSize == null || _frozenImage == null) return;
    
    final pixelRect = Rect.fromLTRB(
      _cropSelectorRect.left * _currentImageSize!.width,
      _cropSelectorRect.top * _currentImageSize!.height,
      _cropSelectorRect.right * _currentImageSize!.width,
      _cropSelectorRect.bottom * _currentImageSize!.height,
    );
    
    final croppedPath = await _objectDetection.cropToObject(
      _frozenImage!.path,
      pixelRect,
      paddingPercent: 0.0,
      suffix: 'selector_crop',
    );
    
    if (croppedPath != null) {
      // Create a new DetectedObject for the user's manual crop
      final userCropObject = DetectedObject(
        boundingBox: pixelRect,
        labels: [],
        trackingId: -1, // Special ID for user crops
        croppedImagePath: croppedPath,
        areaRatio: (pixelRect.width * pixelRect.height) / 
                   (_currentImageSize!.width * _currentImageSize!.height),
      );
      
      // Update the detection result to include the user's crop as the first suggestion
      if (_detectionResult != null) {
        final updatedSuggestions = [userCropObject, ..._detectionResult!.suggestions];
        // Keep only up to 5 suggestions
        final limitedSuggestions = updatedSuggestions.take(5).toList();
        
        setState(() {
          _detectionResult = DetectionResult(
            allObjects: [userCropObject, ..._detectionResult!.allObjects],
            primaryObject: userCropObject,
            suggestions: limitedSuggestions,
            imageSize: _detectionResult!.imageSize,
            originalImagePath: _detectionResult!.originalImagePath,
          );
          _selectedSuggestionIndex = 0; // Select the new user crop
          _isSearching = true;
          _currentSearchId++;
        });
      } else {
        // No previous detection result, create a new one
        setState(() {
          _detectionResult = DetectionResult(
            allObjects: [userCropObject],
            primaryObject: userCropObject,
            suggestions: [userCropObject],
            imageSize: _currentImageSize!,
            originalImagePath: _frozenImage!.path,
          );
          _selectedSuggestionIndex = 0;
          _isSearching = true;
          _currentSearchId++;
        });
      }
      
      _startProgressSimulation();
      _scanController.repeat();
      await _searchWithImage(File(croppedPath), searchId: _currentSearchId, suggestionIndex: 0);
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
                      searchProgress: _searchProgress, // Show percentage
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
              key: const ValueKey('results_sheet'),
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
              onManualCrop: _enterManualCropMode,
              canManualCrop: _isCameraFrozen && _frozenImage != null && _currentImageSize != null,
            ),
          ),
          
          // Crop Selector Search Button (when selector is shown, not searching, and sheet is collapsed)
          if (_showCropSelector && !_isManualCropMode && !_isSearching && _isCameraFrozen && !_isSheetExpanded)
            Positioned(
              bottom: bottomPadding + 180,
              left: 0,
              right: 0,
              child: Center(
                child: GestureDetector(
                  onTap: _searchWithCropSelector,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.primary500,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary500.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.search_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Search Selection',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          
          // Manual Crop Overlay
          if (_isManualCropMode && _frozenImage != null && _currentImageSize != null)
            Positioned.fill(
              child: ManualCropOverlay(
                imagePath: _frozenImage!.path,
                imageSize: _currentImageSize!,
                onCancel: _exitManualCropMode,
                onCropComplete: _handleManualCropComplete,
                isSearching: _pendingCropImagePath != null,
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
      // Wrap in GestureDetector for draw-to-crop feature
      return GestureDetector(
        onPanStart: _showCropSelector ? _onCropSelectorPanStart : _onDrawStart,
        onPanUpdate: _showCropSelector ? _onCropSelectorPanUpdate : _onDrawUpdate,
        onPanEnd: _showCropSelector ? _onCropSelectorPanEnd : _onDrawEnd,
        child: Container(
          color: Colors.black,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate how the image is displayed with BoxFit.contain
              final imageAspect = _currentImageSize != null 
                  ? _currentImageSize!.width / _currentImageSize!.height 
                  : 1.0;
              final containerAspect = constraints.maxWidth / constraints.maxHeight;
              
              double displayWidth, displayHeight, offsetX, offsetY;
              if (imageAspect > containerAspect) {
                displayWidth = constraints.maxWidth;
                displayHeight = constraints.maxWidth / imageAspect;
                offsetX = 0;
                offsetY = (constraints.maxHeight - displayHeight) / 2;
              } else {
                displayHeight = constraints.maxHeight;
                displayWidth = constraints.maxHeight * imageAspect;
                offsetX = (constraints.maxWidth - displayWidth) / 2;
                offsetY = 0;
              }
              
              return Stack(
                fit: StackFit.expand,
                children: [
                  Center(
                    child: Image.file(
                      File(_frozenImage!.path), 
                      fit: BoxFit.contain,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                  
                  // Detection dots overlay (like Shein)
                  if (_detectionResult != null && _hasResults && !_isSearching)
                    CustomPaint(
                      painter: _DetectionDotsPainter(
                        objects: _detectionResult!.allObjects,
                        displayRect: Rect.fromLTWH(offsetX, offsetY, displayWidth, displayHeight),
                        imageSize: _detectionResult!.imageSize,
                        selectedIndex: _selectedSuggestionIndex,
                      ),
                    ),
                  
                  // Interactive crop selector (auto-shown on primary object)
                  if (_showCropSelector && !_isManualCropMode)
                    CustomPaint(
                      painter: _CropSelectorPainter(
                        normalizedRect: _cropSelectorRect,
                        displayRect: Rect.fromLTWH(offsetX, offsetY, displayWidth, displayHeight),
                        isSearching: _isSearching,
                      ),
                    ),
                  
                  // Draw selection overlay (manual drag)
                  if (_isDrawingCrop && _drawStartPoint != null && _drawCurrentPoint != null)
                    CustomPaint(
                      painter: _DrawSelectionPainter(
                        startPoint: _drawStartPoint!,
                        currentPoint: _drawCurrentPoint!,
                      ),
                    ),
                ],
              );
            },
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

// Painter for draw-to-crop selection rectangle
class _DrawSelectionPainter extends CustomPainter {
  final Offset startPoint;
  final Offset currentPoint;
  
  _DrawSelectionPainter({
    required this.startPoint,
    required this.currentPoint,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromPoints(startPoint, currentPoint);
    
    // Semi-transparent fill
    final fillPaint = Paint()
      ..color = Colors.white.withOpacity(0.2)
      ..style = PaintingStyle.fill;
    
    canvas.drawRect(rect, fillPaint);
    
    // Animated border
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRect(rect, borderPaint);
    
    // Corner handles
    const handleSize = 12.0;
    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    
    final corners = [rect.topLeft, rect.topRight, rect.bottomLeft, rect.bottomRight];
    for (final corner in corners) {
      canvas.drawCircle(corner, handleSize / 2, handlePaint);
    }
    
    // Hint text in center
    if (rect.width.abs() > 80 && rect.height.abs() > 40) {
      final textSpan = TextSpan(
        text: 'Release to search',
        style: TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 4),
          ],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas,
        Offset(
          rect.center.dx - textPainter.width / 2,
          rect.center.dy - textPainter.height / 2,
        ),
      );
    }
  }
  
  @override
  bool shouldRepaint(covariant _DrawSelectionPainter oldDelegate) {
    return oldDelegate.startPoint != startPoint || 
           oldDelegate.currentPoint != currentPoint;
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

// Enum for crop selector handles
enum _CropHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
  left,
  right,
  top,
  bottom,
  move,
}

// Painter for detection dots (like Shein)
class _DetectionDotsPainter extends CustomPainter {
  final List<DetectedObject> objects;
  final Rect displayRect;
  final Size imageSize; // Original image size for coordinate conversion
  final int? selectedIndex;
  
  _DetectionDotsPainter({
    required this.objects,
    required this.displayRect,
    required this.imageSize,
    this.selectedIndex,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    if (objects.isEmpty || imageSize.width == 0 || imageSize.height == 0) return;
    
    for (int i = 0; i < objects.length; i++) {
      final obj = objects[i];
      final bbox = obj.boundingBox;
      
      // Convert from image pixel coordinates to display coordinates
      // bbox is in original image pixel space, we need to map to displayRect
      final normalizedCenterX = ((bbox.left + bbox.right) / 2) / imageSize.width;
      final normalizedCenterY = ((bbox.top + bbox.bottom) / 2) / imageSize.height;
      
      final dotX = displayRect.left + normalizedCenterX * displayRect.width;
      final dotY = displayRect.top + normalizedCenterY * displayRect.height;
      
      // Skip if outside display bounds
      if (dotX < displayRect.left || dotX > displayRect.right ||
          dotY < displayRect.top || dotY > displayRect.bottom) {
        continue;
      }
      
      final isSelected = i == selectedIndex || (selectedIndex == null && i == 0);
      
      // Draw outer glow for selected
      if (isSelected) {
        final glowPaint = Paint()
          ..color = AppColors.primary500.withOpacity(0.25)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
        canvas.drawCircle(Offset(dotX, dotY), 18, glowPaint);
      }
      
      // Draw outer ring
      final ringPaint = Paint()
        ..color = isSelected ? AppColors.primary500 : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 3 : 2;
      
      canvas.drawCircle(Offset(dotX, dotY), isSelected ? 12 : 8, ringPaint);
      
      // Draw inner dot
      final dotPaint = Paint()
        ..color = isSelected ? AppColors.primary500 : Colors.white.withOpacity(0.9)
        ..style = PaintingStyle.fill;
      
      canvas.drawCircle(Offset(dotX, dotY), isSelected ? 6 : 4, dotPaint);
      
      // Draw number label for non-selected dots
      if (!isSelected && objects.length > 1) {
        final textSpan = TextSpan(
          text: '${i + 1}',
          style: TextStyle(
            color: Colors.white,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(color: Colors.black, blurRadius: 2),
            ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        
        textPainter.paint(
          canvas,
          Offset(dotX - textPainter.width / 2, dotY + 14),
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant _DetectionDotsPainter oldDelegate) {
    return oldDelegate.objects != objects || 
           oldDelegate.displayRect != displayRect ||
           oldDelegate.imageSize != imageSize ||
           oldDelegate.selectedIndex != selectedIndex;
  }
}

// Painter for the crop selector overlay
class _CropSelectorPainter extends CustomPainter {
  final Rect normalizedRect; // 0-1 coordinates
  final Rect displayRect; // Screen coordinates of the displayed image
  final bool isSearching;
  
  _CropSelectorPainter({
    required this.normalizedRect,
    required this.displayRect,
    this.isSearching = false,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Convert normalized rect to screen coordinates
    final screenRect = Rect.fromLTRB(
      displayRect.left + normalizedRect.left * displayRect.width,
      displayRect.top + normalizedRect.top * displayRect.height,
      displayRect.left + normalizedRect.right * displayRect.width,
      displayRect.top + normalizedRect.bottom * displayRect.height,
    );
    
    // Draw semi-transparent overlay outside the selection
    final overlayPaint = Paint()
      ..color = Colors.black.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    // Top region
    canvas.drawRect(
      Rect.fromLTRB(0, 0, size.width, screenRect.top),
      overlayPaint,
    );
    // Bottom region
    canvas.drawRect(
      Rect.fromLTRB(0, screenRect.bottom, size.width, size.height),
      overlayPaint,
    );
    // Left region
    canvas.drawRect(
      Rect.fromLTRB(0, screenRect.top, screenRect.left, screenRect.bottom),
      overlayPaint,
    );
    // Right region
    canvas.drawRect(
      Rect.fromLTRB(screenRect.right, screenRect.top, size.width, screenRect.bottom),
      overlayPaint,
    );
    
    // Draw orange border
    final borderPaint = Paint()
      ..color = isSearching ? Colors.white : AppColors.primary500
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    
    canvas.drawRect(screenRect, borderPaint);
    
    // Draw corner handles
    const handleLength = 24.0;
    const handleThickness = 4.0;
    final handlePaint = Paint()
      ..color = isSearching ? Colors.white : AppColors.primary500
      ..style = PaintingStyle.stroke
      ..strokeWidth = handleThickness
      ..strokeCap = StrokeCap.round;
    
    // Top-left corner
    canvas.drawLine(
      Offset(screenRect.left, screenRect.top),
      Offset(screenRect.left + handleLength, screenRect.top),
      handlePaint,
    );
    canvas.drawLine(
      Offset(screenRect.left, screenRect.top),
      Offset(screenRect.left, screenRect.top + handleLength),
      handlePaint,
    );
    
    // Top-right corner
    canvas.drawLine(
      Offset(screenRect.right, screenRect.top),
      Offset(screenRect.right - handleLength, screenRect.top),
      handlePaint,
    );
    canvas.drawLine(
      Offset(screenRect.right, screenRect.top),
      Offset(screenRect.right, screenRect.top + handleLength),
      handlePaint,
    );
    
    // Bottom-left corner
    canvas.drawLine(
      Offset(screenRect.left, screenRect.bottom),
      Offset(screenRect.left + handleLength, screenRect.bottom),
      handlePaint,
    );
    canvas.drawLine(
      Offset(screenRect.left, screenRect.bottom),
      Offset(screenRect.left, screenRect.bottom - handleLength),
      handlePaint,
    );
    
    // Bottom-right corner
    canvas.drawLine(
      Offset(screenRect.right, screenRect.bottom),
      Offset(screenRect.right - handleLength, screenRect.bottom),
      handlePaint,
    );
    canvas.drawLine(
      Offset(screenRect.right, screenRect.bottom),
      Offset(screenRect.right, screenRect.bottom - handleLength),
      handlePaint,
    );
    
    // Draw loading indicator if searching
    if (isSearching) {
      final centerX = screenRect.center.dx;
      final centerY = screenRect.center.dy;
      
      final textSpan = TextSpan(
        text: 'Searching...',
        style: TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          shadows: [
            Shadow(color: Colors.black54, blurRadius: 4),
          ],
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      
      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, centerY - textPainter.height / 2),
      );
    } else {
      // Draw "Drag to adjust" hint
      if (screenRect.width > 100 && screenRect.height > 60) {
        final textSpan = TextSpan(
          text: 'Drag to adjust',
          style: TextStyle(
            color: Colors.white.withOpacity(0.8),
            fontSize: 12,
            fontWeight: FontWeight.w500,
            shadows: [
              Shadow(color: Colors.black54, blurRadius: 4),
            ],
          ),
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout();
        
        textPainter.paint(
          canvas,
          Offset(
            screenRect.center.dx - textPainter.width / 2,
            screenRect.bottom + 8,
          ),
        );
      }
    }
  }
  
  @override
  bool shouldRepaint(covariant _CropSelectorPainter oldDelegate) {
    return oldDelegate.normalizedRect != normalizedRect || 
           oldDelegate.displayRect != displayRect ||
           oldDelegate.isSearching != isSearching;
  }
}
