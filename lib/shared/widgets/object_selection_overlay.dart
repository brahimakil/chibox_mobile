import 'dart:io';
import 'package:flutter/material.dart';
import '../../core/services/object_detection_service.dart';

/// Widget for displaying detected objects and allowing user to select one
class ObjectSelectionOverlay extends StatefulWidget {
  final String imagePath;
  final List<DetectedObject> detectedObjects;
  final Function(DetectedObject? selectedObject, Rect? customCrop) onObjectSelected;
  final VoidCallback onCancel;
  final VoidCallback onSearchFullImage;
  
  const ObjectSelectionOverlay({
    super.key,
    required this.imagePath,
    required this.detectedObjects,
    required this.onObjectSelected,
    required this.onCancel,
    required this.onSearchFullImage,
  });

  @override
  State<ObjectSelectionOverlay> createState() => _ObjectSelectionOverlayState();
}

class _ObjectSelectionOverlayState extends State<ObjectSelectionOverlay> 
    with SingleTickerProviderStateMixin {
  DetectedObject? _selectedObject;
  bool _isCustomCrop = false;
  Offset? _cropStart;
  Offset? _cropEnd;
  late AnimationController _pulseController;
  final GlobalKey _imageKey = GlobalKey();
  Size? _imageSize;
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Auto-select the largest object if only one detected
    if (widget.detectedObjects.length == 1) {
      _selectedObject = widget.detectedObjects.first;
    }
  }
  
  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }
  
  Rect? get _customCropRect {
    if (_cropStart == null || _cropEnd == null) return null;
    return Rect.fromPoints(_cropStart!, _cropEnd!);
  }
  
  void _handlePanStart(DragStartDetails details) {
    if (_isCustomCrop) {
      setState(() {
        _cropStart = details.localPosition;
        _cropEnd = details.localPosition;
        _selectedObject = null;
      });
    }
  }
  
  void _handlePanUpdate(DragUpdateDetails details) {
    if (_isCustomCrop && _cropStart != null) {
      setState(() {
        _cropEnd = details.localPosition;
      });
    }
  }
  
  void _handleTap(TapUpDetails details) {
    if (_isCustomCrop) return;
    
    // Check if tapped inside any detected object
    for (final obj in widget.detectedObjects) {
      if (_getScaledRect(obj.boundingBox).contains(details.localPosition)) {
        setState(() {
          _selectedObject = (_selectedObject == obj) ? null : obj;
        });
        return;
      }
    }
    
    // Tapped outside all objects - deselect
    setState(() {
      _selectedObject = null;
    });
  }
  
  Rect _getScaledRect(Rect original) {
    if (_imageSize == null) return original;
    
    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return original;
    
    final displaySize = renderBox.size;
    final scaleX = displaySize.width / _imageSize!.width;
    final scaleY = displaySize.height / _imageSize!.height;
    
    return Rect.fromLTRB(
      original.left * scaleX,
      original.top * scaleY,
      original.right * scaleX,
      original.bottom * scaleY,
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.9),
      child: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context),
            
            // Image with detection boxes
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  GestureDetector(
                    onTapUp: _handleTap,
                    onPanStart: _handlePanStart,
                    onPanUpdate: _handlePanUpdate,
                    child: Center(
                      child: Image.file(
                        File(widget.imagePath),
                        key: _imageKey,
                        fit: BoxFit.contain,
                        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                          if (frame != null) {
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _loadImageSize();
                            });
                          }
                          return child;
                        },
                      ),
                    ),
                  ),
                  
                  // Detection boxes overlay
                  if (_imageSize != null && !_isCustomCrop)
                    ..._buildDetectionBoxes(),
                  
                  // Custom crop rectangle
                  if (_isCustomCrop && _customCropRect != null)
                    _buildCustomCropRect(),
                  
                  // Instructions
                  Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: _buildInstructions(),
                  ),
                ],
              ),
            ),
            
            // Bottom actions
            _buildBottomActions(context),
          ],
        ),
      ),
    );
  }
  
  Future<void> _loadImageSize() async {
    final file = File(widget.imagePath);
    final bytes = await file.readAsBytes();
    final image = await decodeImageFromList(bytes);
    if (mounted) {
      setState(() {
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
      });
    }
  }
  
  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.detectedObjects.isEmpty 
                  ? 'No objects detected' 
                  : 'Tap to select object (${widget.detectedObjects.length} found)',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          // Toggle custom crop mode
          TextButton.icon(
            onPressed: () {
              setState(() {
                _isCustomCrop = !_isCustomCrop;
                if (!_isCustomCrop) {
                  _cropStart = null;
                  _cropEnd = null;
                }
              });
            },
            icon: Icon(
              _isCustomCrop ? Icons.auto_fix_high : Icons.crop,
              color: _isCustomCrop ? Colors.amber : Colors.white,
              size: 20,
            ),
            label: Text(
              _isCustomCrop ? 'Auto' : 'Manual',
              style: TextStyle(
                color: _isCustomCrop ? Colors.amber : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  List<Widget> _buildDetectionBoxes() {
    final renderBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return [];
    
    final imageOffset = renderBox.localToGlobal(Offset.zero);
    final screenOffset = Offset(0, MediaQuery.of(context).padding.top + 56 + 16);
    final relativeOffset = imageOffset - screenOffset;
    
    return widget.detectedObjects.asMap().entries.map((entry) {
      final index = entry.key;
      final obj = entry.value;
      final isSelected = _selectedObject == obj;
      final scaledRect = _getScaledRect(obj.boundingBox);
      
      // Offset the rect to account for image position
      final adjustedRect = scaledRect.translate(relativeOffset.dx, relativeOffset.dy);
      
      return Positioned(
        left: adjustedRect.left,
        top: adjustedRect.top,
        width: adjustedRect.width,
        height: adjustedRect.height,
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, child) {
            final pulseValue = isSelected ? (1.0 + _pulseController.value * 0.1) : 1.0;
            return Transform.scale(
              scale: pulseValue,
              child: GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedObject = isSelected ? null : obj;
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected 
                          ? Colors.greenAccent 
                          : Colors.white.withOpacity(0.8),
                      width: isSelected ? 3 : 2,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: isSelected 
                        ? Colors.greenAccent.withOpacity(0.2) 
                        : Colors.transparent,
                  ),
                  child: Stack(
                    children: [
                      // Label
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.greenAccent : Colors.black87,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${index + 1}. ${obj.primaryLabel}',
                            style: TextStyle(
                              color: isSelected ? Colors.black : Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      // Selection indicator
                      if (isSelected)
                        const Positioned(
                          top: 4,
                          right: 4,
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.greenAccent,
                            size: 20,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }).toList();
  }
  
  Widget _buildCustomCropRect() {
    final rect = _customCropRect!;
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width.abs(),
      height: rect.height.abs(),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.amber, width: 2),
          color: Colors.amber.withOpacity(0.2),
        ),
        child: const Center(
          child: Icon(Icons.crop, color: Colors.amber, size: 32),
        ),
      ),
    );
  }
  
  Widget _buildInstructions() {
    String text;
    if (_isCustomCrop) {
      text = 'Drag to draw a rectangle around the item you want to search';
    } else if (widget.detectedObjects.isEmpty) {
      text = 'No objects detected. Use manual crop or search the full image.';
    } else if (_selectedObject != null) {
      text = 'Selected: ${_selectedObject!.primaryLabel}. Tap "Search Selected" to continue.';
    } else {
      text = 'Tap on a detected object to select it for search';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 13,
        ),
      ),
    );
  }
  
  Widget _buildBottomActions(BuildContext context) {
    final hasSelection = _selectedObject != null || 
                         (_isCustomCrop && _customCropRect != null && _customCropRect!.width > 50);
    
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // Search full image button
          Expanded(
            child: OutlinedButton.icon(
              onPressed: widget.onSearchFullImage,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white54),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.search, size: 20),
              label: const Text('Full Image'),
            ),
          ),
          const SizedBox(width: 12),
          // Search selected button
          Expanded(
            flex: 2,
            child: ElevatedButton.icon(
              onPressed: hasSelection
                  ? () {
                      if (_selectedObject != null) {
                        widget.onObjectSelected(_selectedObject, null);
                      } else if (_customCropRect != null) {
                        widget.onObjectSelected(null, _customCropRect);
                      }
                    }
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.greenAccent,
                foregroundColor: Colors.black,
                disabledBackgroundColor: Colors.grey[700],
                disabledForegroundColor: Colors.grey[500],
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.crop_free, size: 20),
              label: Text(hasSelection ? 'Search Selected' : 'Select Object'),
            ),
          ),
        ],
      ),
    );
  }
}
