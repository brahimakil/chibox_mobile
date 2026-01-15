import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_mlkit_object_detection/google_mlkit_object_detection.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

/// Categories relevant for e-commerce product search
/// ML Kit's coarse classifier categories
enum ProductCategory {
  fashionGood,   // Clothing, shoes, bags, accessories
  homeGood,      // Furniture, decor, kitchenware
  food,          // Food items
  plant,         // Plants
  place,         // Backgrounds/places (usually not relevant)
  unknown,       // Unknown category
}

/// Represents a detected object with its bounding box and metadata
class DetectedObject {
  final Rect boundingBox;
  final List<Label> labels;
  final int trackingId;
  final String? croppedImagePath; // Path to cropped image if generated
  final double areaRatio; // Ratio of object area to image area (0-1)
  
  DetectedObject({
    required this.boundingBox,
    required this.labels,
    required this.trackingId,
    this.croppedImagePath,
    this.areaRatio = 0.0,
  });
  
  /// Create a copy with updated fields
  DetectedObject copyWith({
    Rect? boundingBox,
    List<Label>? labels,
    int? trackingId,
    String? croppedImagePath,
    double? areaRatio,
  }) {
    return DetectedObject(
      boundingBox: boundingBox ?? this.boundingBox,
      labels: labels ?? this.labels,
      trackingId: trackingId ?? this.trackingId,
      croppedImagePath: croppedImagePath ?? this.croppedImagePath,
      areaRatio: areaRatio ?? this.areaRatio,
    );
  }
  
  /// Get the primary label (highest confidence)
  String get primaryLabel {
    if (labels.isEmpty) return 'Product';
    final sorted = List<Label>.from(labels)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    
    // Map ML Kit labels to user-friendly names
    final label = sorted.first.text.toLowerCase();
    if (label.contains('fashion')) return 'Fashion Item';
    if (label.contains('home')) return 'Home Item';
    if (label.contains('food')) return 'Food';
    if (label.contains('plant')) return 'Plant';
    if (label.contains('place')) return 'Background';
    return 'Product';
  }
  
  /// Get confidence of primary label
  double get confidence {
    if (labels.isEmpty) return 0.5; // Default confidence for unlabeled
    final sorted = List<Label>.from(labels)
      ..sort((a, b) => b.confidence.compareTo(a.confidence));
    return sorted.first.confidence;
  }
  
  /// Check if this is likely a product (fashion or home goods)
  bool get isLikelyProduct {
    if (labels.isEmpty) return true; // Assume product if no labels
    final label = primaryLabel.toLowerCase();
    // Fashion and home goods are most relevant for e-commerce
    return label.contains('fashion') || 
           label.contains('home') || 
           label.contains('product') ||
           label == 'product';
  }
  
  /// Get the product category
  ProductCategory get category {
    if (labels.isEmpty) return ProductCategory.unknown;
    final label = labels.first.text.toLowerCase();
    if (label.contains('fashion')) return ProductCategory.fashionGood;
    if (label.contains('home')) return ProductCategory.homeGood;
    if (label.contains('food')) return ProductCategory.food;
    if (label.contains('plant')) return ProductCategory.plant;
    if (label.contains('place')) return ProductCategory.place;
    return ProductCategory.unknown;
  }
  
  /// Calculate a relevance score for product search (higher = more relevant)
  double get relevanceScore {
    double score = 0.0;
    
    // Base score from confidence
    score += confidence * 0.3;
    
    // Bonus for product categories
    if (isLikelyProduct) {
      score += 0.4;
    }
    
    // Bonus for good size (not too small, not too large)
    // Ideal: 10-60% of image area
    if (areaRatio >= 0.10 && areaRatio <= 0.60) {
      score += 0.3;
    } else if (areaRatio >= 0.05 && areaRatio <= 0.80) {
      score += 0.15;
    }
    
    // Penalty for "place" category (backgrounds)
    if (category == ProductCategory.place) {
      score -= 0.3;
    }
    
    return score.clamp(0.0, 1.0);
  }
}

/// Result from object detection with multiple suggestions
class DetectionResult {
  final List<DetectedObject> allObjects;
  final DetectedObject? primaryObject; // Best match for product search
  final List<DetectedObject> suggestions; // Top 3 alternatives
  final Size imageSize;
  final String originalImagePath;
  
  DetectionResult({
    required this.allObjects,
    this.primaryObject,
    required this.suggestions,
    required this.imageSize,
    required this.originalImagePath,
  });
  
  bool get hasDetections => allObjects.isNotEmpty;
  bool get hasSuggestions => suggestions.isNotEmpty;
}

/// Service for detecting objects in images using ML Kit
/// Optimized for e-commerce product detection
class ObjectDetectionService {
  static ObjectDetectionService? _instance;
  ObjectDetector? _objectDetector;
  bool _isInitialized = false;
  
  ObjectDetectionService._();
  
  static ObjectDetectionService get instance {
    _instance ??= ObjectDetectionService._();
    return _instance!;
  }
  
  /// Initialize the object detector with optimal settings for product detection
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Use default model with classification enabled
      // This gives us category labels (Fashion, Home, etc.)
      final options = ObjectDetectorOptions(
        mode: DetectionMode.single, // Best for still images
        classifyObjects: true, // Enable category classification
        multipleObjects: true, // Detect multiple objects for suggestions
      );
      
      _objectDetector = ObjectDetector(options: options);
      _isInitialized = true;
      debugPrint('✅ Object detection initialized (with classification)');
    } catch (e) {
      debugPrint('❌ Failed to initialize object detection: $e');
    }
  }
  
  /// Detect objects in an image and return structured results with suggestions
  /// Returns up to 3 suggestions for user to choose from
  Future<DetectionResult> detectObjectsWithSuggestions(
    String imagePath, {
    int maxSuggestions = 3,
    bool generateCrops = true,
  }) async {
    if (!_isInitialized || _objectDetector == null) {
      await initialize();
    }
    
    // Get image dimensions
    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final imageSize = Size(frame.image.width.toDouble(), frame.image.height.toDouble());
    frame.image.dispose();
    
    final imageArea = imageSize.width * imageSize.height;
    
    if (_objectDetector == null) {
      debugPrint('❌ Object detector not available');
      return DetectionResult(
        allObjects: [],
        suggestions: [],
        imageSize: imageSize,
        originalImagePath: imagePath,
      );
    }
    
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final objects = await _objectDetector!.processImage(inputImage);
      
      debugPrint('🔍 ML Kit detected ${objects.length} objects');
      
      // Convert to our DetectedObject format with area ratio
      List<DetectedObject> detectedObjects = objects.map((obj) {
        final box = obj.boundingBox;
        final objectArea = box.width * box.height;
        final areaRatio = objectArea / imageArea;
        
        debugPrint('  📦 Object: ${obj.labels.map((l) => '${l.text}(${(l.confidence * 100).toStringAsFixed(0)}%)').join(', ')} | Area: ${(areaRatio * 100).toStringAsFixed(1)}%');
        
        return DetectedObject(
          boundingBox: box,
          labels: obj.labels,
          trackingId: obj.trackingId ?? 0,
          areaRatio: areaRatio,
        );
      }).toList();
      
      // Filter out very small objects (< 3% of image) and very large (> 95%)
      detectedObjects = detectedObjects.where((obj) {
        return obj.areaRatio >= 0.03 && obj.areaRatio <= 0.95;
      }).toList();
      
      // Sort by relevance score (best products first)
      detectedObjects.sort((a, b) => b.relevanceScore.compareTo(a.relevanceScore));
      
      // Take top suggestions
      final suggestions = detectedObjects.take(maxSuggestions).toList();
      
      // Generate cropped images for suggestions
      if (generateCrops && suggestions.isNotEmpty) {
        for (int i = 0; i < suggestions.length; i++) {
          final croppedPath = await cropToObject(
            imagePath, 
            suggestions[i].boundingBox,
            paddingPercent: 0.12,
            suffix: 'suggestion_$i',
          );
          if (croppedPath != null) {
            suggestions[i] = suggestions[i].copyWith(croppedImagePath: croppedPath);
          }
        }
      }
      
      // Primary object is the first suggestion (highest relevance)
      final primaryObject = suggestions.isNotEmpty ? suggestions.first : null;
      
      debugPrint('✅ Detection complete: ${suggestions.length} suggestions, primary: ${primaryObject?.primaryLabel ?? 'none'}');
      
      return DetectionResult(
        allObjects: detectedObjects,
        primaryObject: primaryObject,
        suggestions: suggestions,
        imageSize: imageSize,
        originalImagePath: imagePath,
      );
    } catch (e) {
      debugPrint('❌ Object detection failed: $e');
      return DetectionResult(
        allObjects: [],
        suggestions: [],
        imageSize: imageSize,
        originalImagePath: imagePath,
      );
    }
  }
  
  /// Legacy method for backward compatibility
  Future<List<DetectedObject>> detectObjects(String imagePath) async {
    final result = await detectObjectsWithSuggestions(imagePath, generateCrops: false);
    return result.allObjects;
  }
  
  /// Crop an image to focus on a specific bounding box with padding
  /// Uses the image package for precise pixel-level cropping
  Future<String?> cropToObject(
    String imagePath,
    Rect boundingBox, {
    double paddingPercent = 0.12,
    String suffix = 'cropped',
  }) async {
    try {
      // Read original image
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      
      // Decode image
      final originalImage = img.decodeImage(bytes);
      if (originalImage == null) {
        debugPrint('❌ Failed to decode image');
        return null;
      }
      
      final imageWidth = originalImage.width.toDouble();
      final imageHeight = originalImage.height.toDouble();
      
      // Calculate padded crop area
      final paddingX = boundingBox.width * paddingPercent;
      final paddingY = boundingBox.height * paddingPercent;
      
      final cropLeft = (boundingBox.left - paddingX).clamp(0.0, imageWidth).toInt();
      final cropTop = (boundingBox.top - paddingY).clamp(0.0, imageHeight).toInt();
      final cropRight = (boundingBox.right + paddingX).clamp(0.0, imageWidth).toInt();
      final cropBottom = (boundingBox.bottom + paddingY).clamp(0.0, imageHeight).toInt();
      
      final cropWidth = cropRight - cropLeft;
      final cropHeight = cropBottom - cropTop;
      
      if (cropWidth <= 10 || cropHeight <= 10) {
        debugPrint('❌ Invalid crop dimensions: ${cropWidth}x$cropHeight');
        return null;
      }
      
      // Perform the crop
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropLeft,
        y: cropTop,
        width: cropWidth,
        height: cropHeight,
      );
      
      // Save cropped image
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/${suffix}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      // Encode as JPEG with good quality
      final encodedBytes = img.encodeJpg(croppedImage, quality: 85);
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(encodedBytes);
      
      debugPrint('✅ Cropped image: ${cropWidth}x$cropHeight -> $outputPath');
      return outputPath;
    } catch (e) {
      debugPrint('❌ Failed to crop image: $e');
      return null;
    }
  }
  
  /// Crop image using display coordinates (for UI interactions)
  Future<String?> cropToObjectPrecise(
    String imagePath,
    Rect boundingBox,
    Size imageDisplaySize,
    Size actualImageSize, {
    double paddingPercent = 0.12,
  }) async {
    try {
      // Scale bounding box from display coordinates to actual image coordinates
      final scaleX = actualImageSize.width / imageDisplaySize.width;
      final scaleY = actualImageSize.height / imageDisplaySize.height;
      
      final scaledBox = Rect.fromLTRB(
        boundingBox.left * scaleX,
        boundingBox.top * scaleY,
        boundingBox.right * scaleX,
        boundingBox.bottom * scaleY,
      );
      
      return await cropToObject(imagePath, scaledBox, paddingPercent: paddingPercent);
    } catch (e) {
      debugPrint('❌ Failed to crop image precisely: $e');
      return null;
    }
  }
  
  /// Generate a center crop (fallback when no objects detected)
  /// Crops to the center 70% of the image
  Future<String?> generateCenterCrop(String imagePath) async {
    try {
      final file = File(imagePath);
      final bytes = await file.readAsBytes();
      final originalImage = img.decodeImage(bytes);
      
      if (originalImage == null) return null;
      
      final w = originalImage.width;
      final h = originalImage.height;
      
      // Crop to center 70%
      final cropW = (w * 0.7).toInt();
      final cropH = (h * 0.7).toInt();
      final cropX = ((w - cropW) / 2).toInt();
      final cropY = ((h - cropH) / 2).toInt();
      
      final croppedImage = img.copyCrop(
        originalImage,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );
      
      final tempDir = await getTemporaryDirectory();
      final outputPath = '${tempDir.path}/center_crop_${DateTime.now().millisecondsSinceEpoch}.jpg';
      
      final encodedBytes = img.encodeJpg(croppedImage, quality: 85);
      await File(outputPath).writeAsBytes(encodedBytes);
      
      debugPrint('✅ Generated center crop: ${cropW}x$cropH');
      return outputPath;
    } catch (e) {
      debugPrint('❌ Failed to generate center crop: $e');
      return null;
    }
  }
  
  /// Dispose the detector
  void dispose() {
    _objectDetector?.close();
    _objectDetector = null;
    _isInitialized = false;
  }
}
