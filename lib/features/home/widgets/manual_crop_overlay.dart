import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:chihelo_frontend/core/theme/app_colors.dart';

/// A full-screen overlay that allows users to manually select a region of an image
/// Similar to Alibaba/1688's crop-to-search feature
class ManualCropOverlay extends StatefulWidget {
  final String imagePath;
  final Size imageSize;
  final VoidCallback onCancel;
  final Function(String croppedImagePath, Rect cropRect) onCropComplete;
  final bool isSearching; // Shows loading state when search is in progress
  
  const ManualCropOverlay({
    super.key,
    required this.imagePath,
    required this.imageSize,
    required this.onCancel,
    required this.onCropComplete,
    this.isSearching = false,
  });

  @override
  State<ManualCropOverlay> createState() => _ManualCropOverlayState();
}

class _ManualCropOverlayState extends State<ManualCropOverlay> with SingleTickerProviderStateMixin {
  // Crop rect in normalized coordinates (0-1)
  Rect _cropRect = const Rect.fromLTWH(0.15, 0.15, 0.7, 0.7);
  
  // Track which handle is being dragged
  _DragHandle? _activeHandle;
  Offset? _lastPanPosition;
  
  // Image display rect (calculated based on BoxFit.contain)
  Rect _imageDisplayRect = Rect.zero;
  
  bool _isCropping = false;
  
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  
  // Minimum crop size (in normalized coordinates)
  static const double _minCropSize = 0.1;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  void _calculateImageDisplayRect(Size containerSize) {
    // Calculate how the image is displayed with BoxFit.contain
    final imageAspect = widget.imageSize.width / widget.imageSize.height;
    final containerAspect = containerSize.width / containerSize.height;
    
    double displayWidth, displayHeight;
    double offsetX, offsetY;
    
    if (imageAspect > containerAspect) {
      // Image is wider than container - fit to width
      displayWidth = containerSize.width;
      displayHeight = containerSize.width / imageAspect;
      offsetX = 0;
      offsetY = (containerSize.height - displayHeight) / 2;
    } else {
      // Image is taller than container - fit to height
      displayHeight = containerSize.height;
      displayWidth = containerSize.height * imageAspect;
      offsetX = (containerSize.width - displayWidth) / 2;
      offsetY = 0;
    }
    
    _imageDisplayRect = Rect.fromLTWH(offsetX, offsetY, displayWidth, displayHeight);
  }
  
  Rect _getNormalizedCropRectInDisplayCoords() {
    // Convert normalized crop rect to display coordinates
    return Rect.fromLTWH(
      _imageDisplayRect.left + _cropRect.left * _imageDisplayRect.width,
      _imageDisplayRect.top + _cropRect.top * _imageDisplayRect.height,
      _cropRect.width * _imageDisplayRect.width,
      _cropRect.height * _imageDisplayRect.height,
    );
  }
  
  _DragHandle? _getHandleAtPosition(Offset position) {
    final cropDisplayRect = _getNormalizedCropRectInDisplayCoords();
    const handleHitRadius = 24.0;
    
    // Check corners first (priority over edges)
    final corners = {
      _DragHandle.topLeft: cropDisplayRect.topLeft,
      _DragHandle.topRight: cropDisplayRect.topRight,
      _DragHandle.bottomLeft: cropDisplayRect.bottomLeft,
      _DragHandle.bottomRight: cropDisplayRect.bottomRight,
    };
    
    for (final entry in corners.entries) {
      if ((position - entry.value).distance <= handleHitRadius) {
        return entry.key;
      }
    }
    
    // Check edges
    final edges = {
      _DragHandle.top: Offset(cropDisplayRect.center.dx, cropDisplayRect.top),
      _DragHandle.bottom: Offset(cropDisplayRect.center.dx, cropDisplayRect.bottom),
      _DragHandle.left: Offset(cropDisplayRect.left, cropDisplayRect.center.dy),
      _DragHandle.right: Offset(cropDisplayRect.right, cropDisplayRect.center.dy),
    };
    
    for (final entry in edges.entries) {
      if ((position - entry.value).distance <= handleHitRadius) {
        return entry.key;
      }
    }
    
    // Check if inside the crop area (for moving the entire selection)
    if (cropDisplayRect.contains(position)) {
      return _DragHandle.move;
    }
    
    return null;
  }
  
  void _handlePanStart(DragStartDetails details) {
    _activeHandle = _getHandleAtPosition(details.localPosition);
    _lastPanPosition = details.localPosition;
  }
  
  void _handlePanUpdate(DragUpdateDetails details) {
    if (_activeHandle == null || _lastPanPosition == null) return;
    
    final delta = details.localPosition - _lastPanPosition!;
    _lastPanPosition = details.localPosition;
    
    // Convert delta to normalized coordinates
    final normalizedDeltaX = delta.dx / _imageDisplayRect.width;
    final normalizedDeltaY = delta.dy / _imageDisplayRect.height;
    
    setState(() {
      switch (_activeHandle!) {
        case _DragHandle.move:
          // Move the entire crop rect
          var newLeft = _cropRect.left + normalizedDeltaX;
          var newTop = _cropRect.top + normalizedDeltaY;
          
          // Clamp to image bounds
          newLeft = newLeft.clamp(0.0, 1.0 - _cropRect.width);
          newTop = newTop.clamp(0.0, 1.0 - _cropRect.height);
          
          _cropRect = Rect.fromLTWH(newLeft, newTop, _cropRect.width, _cropRect.height);
          break;
          
        case _DragHandle.topLeft:
          _resizeFromCorner(normalizedDeltaX, normalizedDeltaY, true, true);
          break;
        case _DragHandle.topRight:
          _resizeFromCorner(normalizedDeltaX, normalizedDeltaY, false, true);
          break;
        case _DragHandle.bottomLeft:
          _resizeFromCorner(normalizedDeltaX, normalizedDeltaY, true, false);
          break;
        case _DragHandle.bottomRight:
          _resizeFromCorner(normalizedDeltaX, normalizedDeltaY, false, false);
          break;
          
        case _DragHandle.top:
          _resizeFromEdge(0, normalizedDeltaY, false, true);
          break;
        case _DragHandle.bottom:
          _resizeFromEdge(0, normalizedDeltaY, false, false);
          break;
        case _DragHandle.left:
          _resizeFromEdge(normalizedDeltaX, 0, true, false);
          break;
        case _DragHandle.right:
          _resizeFromEdge(normalizedDeltaX, 0, false, false);
          break;
      }
    });
  }
  
  void _resizeFromCorner(double dx, double dy, bool isLeft, bool isTop) {
    double newLeft = _cropRect.left;
    double newTop = _cropRect.top;
    double newRight = _cropRect.right;
    double newBottom = _cropRect.bottom;
    
    if (isLeft) {
      newLeft = (newLeft + dx).clamp(0.0, newRight - _minCropSize);
    } else {
      newRight = (newRight + dx).clamp(newLeft + _minCropSize, 1.0);
    }
    
    if (isTop) {
      newTop = (newTop + dy).clamp(0.0, newBottom - _minCropSize);
    } else {
      newBottom = (newBottom + dy).clamp(newTop + _minCropSize, 1.0);
    }
    
    _cropRect = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
  }
  
  void _resizeFromEdge(double dx, double dy, bool isLeftEdge, bool isTopEdge) {
    double newLeft = _cropRect.left;
    double newTop = _cropRect.top;
    double newRight = _cropRect.right;
    double newBottom = _cropRect.bottom;
    
    if (dx != 0) {
      if (isLeftEdge) {
        newLeft = (newLeft + dx).clamp(0.0, newRight - _minCropSize);
      } else {
        newRight = (newRight + dx).clamp(newLeft + _minCropSize, 1.0);
      }
    }
    
    if (dy != 0) {
      if (isTopEdge) {
        newTop = (newTop + dy).clamp(0.0, newBottom - _minCropSize);
      } else {
        newBottom = (newBottom + dy).clamp(newTop + _minCropSize, 1.0);
      }
    }
    
    _cropRect = Rect.fromLTRB(newLeft, newTop, newRight, newBottom);
  }
  
  void _handlePanEnd(DragEndDetails details) {
    _activeHandle = null;
    _lastPanPosition = null;
  }
  
  Future<void> _performCrop() async {
    setState(() => _isCropping = true);
    
    try {
      // Read the original image
      final file = File(widget.imagePath);
      final bytes = await file.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) {
        throw Exception('Failed to decode image');
      }
      
      // Convert normalized crop rect to actual pixel coordinates
      final cropLeft = (_cropRect.left * originalImage.width).round();
      final cropTop = (_cropRect.top * originalImage.height).round();
      final cropWidth = (_cropRect.width * originalImage.width).round();
      final cropHeight = (_cropRect.height * originalImage.height).round();
      
      // Perform the crop
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropLeft,
        y: cropTop,
        width: cropWidth,
        height: cropHeight,
      );
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/manual_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final encodedBytes = img.encodeJpg(croppedImage, quality: 90);
      await File(outputPath).writeAsBytes(encodedBytes);
      
      debugPrint('✅ Manual crop complete: ${cropWidth}x$cropHeight -> $outputPath');
      
      // Return the actual pixel rect for display purposes
      final actualCropRect = Rect.fromLTWH(
        cropLeft.toDouble(),
        cropTop.toDouble(),
        cropWidth.toDouble(),
        cropHeight.toDouble(),
      );
      
      widget.onCropComplete(outputPath, actualCropRect);
    } catch (e) {
      debugPrint('❌ Manual crop failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to crop image: $e'), backgroundColor: Colors.red),
      );
      setState(() => _isCropping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _calculateImageDisplayRect(Size(constraints.maxWidth, constraints.maxHeight));
        
        // Disable interaction when searching
        final canInteract = !widget.isSearching && !_isCropping;
        
        return Stack(
          fit: StackFit.expand,
          children: [
            // Semi-transparent background
            Container(color: Colors.black.withOpacity(0.85)),
            
            // Image with crop overlay
            GestureDetector(
              onPanStart: canInteract ? _handlePanStart : null,
              onPanUpdate: canInteract ? _handlePanUpdate : null,
              onPanEnd: canInteract ? _handlePanEnd : null,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Original image (dimmed)
                  Center(
                    child: Image.file(
                      File(widget.imagePath),
                      fit: BoxFit.contain,
                      color: Colors.black.withOpacity(0.5),
                      colorBlendMode: BlendMode.darken,
                    ),
                  ),
                  
                  // Crop preview and handles
                  CustomPaint(
                    painter: _CropOverlayPainter(
                      imageDisplayRect: _imageDisplayRect,
                      cropRect: _cropRect,
                      pulseValue: _pulseAnimation.value,
                    ),
                  ),
                  
                  // Bright image only inside crop area
                  ClipPath(
                    clipper: _CropClipper(
                      imageDisplayRect: _imageDisplayRect,
                      cropRect: _cropRect,
                    ),
                    child: Center(
                      child: Image.file(
                        File(widget.imagePath),
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  
                  // Drag handles (hide when searching)
                  if (!widget.isSearching) ..._buildDragHandles(),
                ],
              ),
            ),
            
            // Top instruction bar
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      widget.isSearching ? Icons.search : Icons.crop, 
                      color: Colors.white, 
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.isSearching 
                            ? 'Searching for products...'
                            : 'Drag corners or edges to select product',
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                      ),
                    ),
                    if (!widget.isSearching)
                      GestureDetector(
                        onTap: widget.onCancel,
                        child: const Icon(Icons.close, color: Colors.white70, size: 24),
                      ),
                    if (widget.isSearching)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                  ],
                ),
              ),
            ),
            
            // Bottom action buttons (hide when searching)
            if (!widget.isSearching)
              Positioned(
                bottom: MediaQuery.of(context).padding.bottom + 24,
                left: 24,
                right: 24,
                child: Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: GestureDetector(
                        onTap: widget.onCancel,
                        child: Container(
                          height: 48,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white54),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Center(
                            child: Text(
                              'Cancel',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Search button
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTap: _isCropping ? null : _performCrop,
                      child: AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (context, child) => Container(
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                AppColors.primary500,
                                AppColors.primary500.withOpacity(0.8 + _pulseAnimation.value * 0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary500.withOpacity(0.4),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: _isCropping
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.search, color: Colors.white, size: 20),
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
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  List<Widget> _buildDragHandles() {
    final cropDisplayRect = _getNormalizedCropRectInDisplayCoords();
    const handleSize = 20.0;
    
    final handles = <Widget>[];
    
    // Corner handles
    final corners = [
      (cropDisplayRect.topLeft, _DragHandle.topLeft),
      (cropDisplayRect.topRight, _DragHandle.topRight),
      (cropDisplayRect.bottomLeft, _DragHandle.bottomLeft),
      (cropDisplayRect.bottomRight, _DragHandle.bottomRight),
    ];
    
    for (final (position, handle) in corners) {
      handles.add(
        Positioned(
          left: position.dx - handleSize / 2,
          top: position.dy - handleSize / 2,
          child: _CornerHandle(
            size: handleSize,
            isActive: _activeHandle == handle,
          ),
        ),
      );
    }
    
    // Edge handles
    final edges = [
      (Offset(cropDisplayRect.center.dx, cropDisplayRect.top), _DragHandle.top, true),
      (Offset(cropDisplayRect.center.dx, cropDisplayRect.bottom), _DragHandle.bottom, true),
      (Offset(cropDisplayRect.left, cropDisplayRect.center.dy), _DragHandle.left, false),
      (Offset(cropDisplayRect.right, cropDisplayRect.center.dy), _DragHandle.right, false),
    ];
    
    for (final (position, handle, isHorizontal) in edges) {
      handles.add(
        Positioned(
          left: position.dx - (isHorizontal ? 16 : 4),
          top: position.dy - (isHorizontal ? 4 : 16),
          child: _EdgeHandle(
            isHorizontal: isHorizontal,
            isActive: _activeHandle == handle,
          ),
        ),
      );
    }
    
    return handles;
  }
}

enum _DragHandle {
  topLeft, topRight, bottomLeft, bottomRight,
  top, bottom, left, right,
  move,
}

class _CornerHandle extends StatelessWidget {
  final double size;
  final bool isActive;
  
  const _CornerHandle({required this.size, this.isActive = false});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary500 : Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.primary500, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _EdgeHandle extends StatelessWidget {
  final bool isHorizontal;
  final bool isActive;
  
  const _EdgeHandle({required this.isHorizontal, this.isActive = false});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: isHorizontal ? 32 : 8,
      height: isHorizontal ? 8 : 32,
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary500 : Colors.white,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.primary500, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 4,
          ),
        ],
      ),
    );
  }
}

class _CropOverlayPainter extends CustomPainter {
  final Rect imageDisplayRect;
  final Rect cropRect;
  final double pulseValue;
  
  _CropOverlayPainter({
    required this.imageDisplayRect,
    required this.cropRect,
    required this.pulseValue,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Calculate crop rect in display coordinates
    final displayCropRect = Rect.fromLTWH(
      imageDisplayRect.left + cropRect.left * imageDisplayRect.width,
      imageDisplayRect.top + cropRect.top * imageDisplayRect.height,
      cropRect.width * imageDisplayRect.width,
      cropRect.height * imageDisplayRect.height,
    );
    
    // Draw border
    final borderPaint = Paint()
      ..color = AppColors.primary500.withOpacity(0.8 + pulseValue * 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    
    canvas.drawRect(displayCropRect, borderPaint);
    
    // Draw grid lines (rule of thirds)
    final gridPaint = Paint()
      ..color = Colors.white.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;
    
    final thirdW = displayCropRect.width / 3;
    final thirdH = displayCropRect.height / 3;
    
    // Vertical lines
    canvas.drawLine(
      Offset(displayCropRect.left + thirdW, displayCropRect.top),
      Offset(displayCropRect.left + thirdW, displayCropRect.bottom),
      gridPaint,
    );
    canvas.drawLine(
      Offset(displayCropRect.left + thirdW * 2, displayCropRect.top),
      Offset(displayCropRect.left + thirdW * 2, displayCropRect.bottom),
      gridPaint,
    );
    
    // Horizontal lines
    canvas.drawLine(
      Offset(displayCropRect.left, displayCropRect.top + thirdH),
      Offset(displayCropRect.right, displayCropRect.top + thirdH),
      gridPaint,
    );
    canvas.drawLine(
      Offset(displayCropRect.left, displayCropRect.top + thirdH * 2),
      Offset(displayCropRect.right, displayCropRect.top + thirdH * 2),
      gridPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant _CropOverlayPainter oldDelegate) {
    return oldDelegate.cropRect != cropRect || 
           oldDelegate.imageDisplayRect != imageDisplayRect ||
           oldDelegate.pulseValue != pulseValue;
  }
}

class _CropClipper extends CustomClipper<Path> {
  final Rect imageDisplayRect;
  final Rect cropRect;
  
  _CropClipper({required this.imageDisplayRect, required this.cropRect});
  
  @override
  Path getClip(Size size) {
    final displayCropRect = Rect.fromLTWH(
      imageDisplayRect.left + cropRect.left * imageDisplayRect.width,
      imageDisplayRect.top + cropRect.top * imageDisplayRect.height,
      cropRect.width * imageDisplayRect.width,
      cropRect.height * imageDisplayRect.height,
    );
    
    return Path()..addRect(displayCropRect);
  }
  
  @override
  bool shouldReclip(covariant _CropClipper oldClipper) {
    return oldClipper.cropRect != cropRect || oldClipper.imageDisplayRect != imageDisplayRect;
  }
}
