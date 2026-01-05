import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/models/product_model.dart';
import '../../../core/theme/theme.dart';

class ProductVariantSheet extends StatefulWidget {
  final Product product;
  final Map<String, String> selectedOptions;
  final ProductVariant? selectedVariant;
  final Function(String optionName, String value) onOptionSelected;
  final Function(List<Map<String, dynamic>> cartItems) onAddToCart;
  final int initialQuantity;

  const ProductVariantSheet({
    super.key,
    required this.product,
    required this.selectedOptions,
    required this.selectedVariant,
    required this.onOptionSelected,
    required this.onAddToCart,
    this.initialQuantity = 1,
  });

  @override
  State<ProductVariantSheet> createState() => _ProductVariantSheetState();
}

class _ProductVariantSheetState extends State<ProductVariantSheet> {
  // Map<VariantId, Quantity>
  final Map<int, int> _quantities = {};
  late Map<String, String> _selectedOptions;
  
  // For single option products or no options
  int _singleQuantity = 1;

  @override
  void initState() {
    super.initState();
    _selectedOptions = Map.from(widget.selectedOptions);
    _singleQuantity = widget.initialQuantity;
  }

  /// Parse a color string to Flutter Color
  Color? _parseColor(String colorStr) {
    final trimmed = colorStr.trim().toLowerCase();
    
    // Handle hex colors
    if (colorStr.startsWith('#')) {
      try {
        String hex = colorStr.replaceFirst('#', '');
        if (hex.length == 6) hex = 'FF$hex'; // Add alpha
        if (hex.length == 3) hex = 'FF${hex[0]}${hex[0]}${hex[1]}${hex[1]}${hex[2]}${hex[2]}'; // Handle shorthand
        return Color(int.parse(hex, radix: 16));
      } catch (_) {
        return null;
      }
    }
    
    // Handle rgb/rgba colors
    final rgbMatch = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)').firstMatch(colorStr);
    if (rgbMatch != null) {
      try {
        return Color.fromARGB(
          255,
          int.parse(rgbMatch.group(1)!),
          int.parse(rgbMatch.group(2)!),
          int.parse(rgbMatch.group(3)!),
        );
      } catch (_) {
        return null;
      }
    }
    
    // Named colors - English
    final namedColors = <String, Color>{
      'red': Colors.red,
      'blue': Colors.blue,
      'green': Colors.green,
      'yellow': Colors.yellow,
      'orange': Colors.orange,
      'purple': Colors.purple,
      'pink': Colors.pink,
      'brown': Colors.brown,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'black': Colors.black,
      'white': Colors.white,
      'cyan': Colors.cyan,
      'teal': Colors.teal,
      'indigo': Colors.indigo,
      'amber': Colors.amber,
      'lime': Colors.lime,
      'navy': const Color(0xFF000080),
      'beige': const Color(0xFFF5F5DC),
      'khaki': const Color(0xFFC3B091),
      'gold': const Color(0xFFFFD700),
      'silver': const Color(0xFFC0C0C0),
      'maroon': const Color(0xFF800000),
      'olive': const Color(0xFF808000),
      'coral': const Color(0xFFFF7F50),
      'salmon': const Color(0xFFFA8072),
      'turquoise': const Color(0xFF40E0D0),
      'magenta': Colors.pink,
      'violet': const Color(0xFFEE82EE),
      'lavender': const Color(0xFFE6E6FA),
      'cream': const Color(0xFFFFFDD0),
      'ivory': const Color(0xFFFFFFF0),
      'tan': const Color(0xFFD2B48C),
      'chocolate': const Color(0xFFD2691E),
      'coffee': const Color(0xFF6F4E37),
      'caramel': const Color(0xFFFFD59A),
      'rose': const Color(0xFFFF007F),
      'burgundy': const Color(0xFF800020),
      'wine': const Color(0xFF722F37),
      'mint': const Color(0xFF98FF98),
      'aqua': const Color(0xFF00FFFF),
      'sky': const Color(0xFF87CEEB),
      'royal': const Color(0xFF4169E1),
      'nude': const Color(0xFFE3BC9A),
      'apricot': const Color(0xFFFBCEB1),
      'peach': const Color(0xFFFFDAB9),
      'plum': const Color(0xFFDDA0DD),
      // Chinese color names
      '红': Colors.red,
      '红色': Colors.red,
      '蓝': Colors.blue,
      '蓝色': Colors.blue,
      '绿': Colors.green,
      '绿色': Colors.green,
      '黄': Colors.yellow,
      '黄色': Colors.yellow,
      '橙': Colors.orange,
      '橙色': Colors.orange,
      '紫': Colors.purple,
      '紫色': Colors.purple,
      '粉': Colors.pink,
      '粉色': Colors.pink,
      '粉红': Colors.pink,
      '棕': Colors.brown,
      '棕色': Colors.brown,
      '咖啡': const Color(0xFF6F4E37),
      '咖啡色': const Color(0xFF6F4E37),
      '灰': Colors.grey,
      '灰色': Colors.grey,
      '黑': Colors.black,
      '黑色': Colors.black,
      '白': Colors.white,
      '白色': Colors.white,
      '米': const Color(0xFFF5F5DC),
      '米色': const Color(0xFFF5F5DC),
      '米白': const Color(0xFFFFFFF0),
      '卡其': const Color(0xFFC3B091),
      '卡其色': const Color(0xFFC3B091),
      '金': const Color(0xFFFFD700),
      '金色': const Color(0xFFFFD700),
      '银': const Color(0xFFC0C0C0),
      '银色': const Color(0xFFC0C0C0),
      '深蓝': const Color(0xFF000080),
      '藏青': const Color(0xFF000080),
      '浅蓝': const Color(0xFF87CEEB),
      '天蓝': const Color(0xFF87CEEB),
      '深绿': const Color(0xFF006400),
      '浅绿': const Color(0xFF90EE90),
      '墨绿': const Color(0xFF013220),
      '军绿': const Color(0xFF4B5320),
      '酒红': const Color(0xFF722F37),
      '玫红': const Color(0xFFFF007F),
      '玫瑰': const Color(0xFFFF007F),
      '杏': const Color(0xFFFBCEB1),
      '杏色': const Color(0xFFFBCEB1),
      '驼色': const Color(0xFFC19A6B),
      '裸色': const Color(0xFFE3BC9A),
      '肤色': const Color(0xFFE3BC9A),
      '透明': Colors.transparent,
      '彩色': Colors.purple, // multi-color default
      '混色': Colors.purple,
    };
    
    // Direct match
    if (namedColors.containsKey(trimmed)) {
      return namedColors[trimmed];
    }
    
    // Partial match - check if any color name is contained in the string
    for (var entry in namedColors.entries) {
      if (trimmed.contains(entry.key)) {
        return entry.value;
      }
    }
    
    return null;
  }

  /// Check if a color is light (for choosing check icon color)
  bool _isLightColor(Color color) {
    final luminance = (0.299 * color.red + 0.587 * color.green + 0.114 * color.blue) / 255;
    return luminance > 0.5;
  }

  ProductVariant? _getVariantForCombination(Map<String, String> options) {
    if (widget.product.variants == null || widget.product.variants!.isEmpty) return null;
    if (widget.product.options == null) return null;

    // Try the new selectedOptions-based matching first (most reliable)
    final variantByOptions = _getVariantBySelectedOptions(options);
    if (variantByOptions != null) {
      return variantByOptions;
    }

    // Fallback to legacy props_ids matching
    // 1. Prepare initial criteria from selected options
    List<Map<String, dynamic>> allCriteria = [];
    for (var option in widget.product.options!) {
      // Find matching selected value (case-insensitive key)
      String? selectedValue;
      for (var entry in options.entries) {
        if (entry.key.trim().toLowerCase() == option.name.trim().toLowerCase()) {
          selectedValue = entry.value;
          break;
        }
      }

      if (selectedValue != null) {
        try {
          final valueObj = option.values.firstWhere(
            (v) => v.name.trim().toLowerCase() == selectedValue!.trim().toLowerCase(),
          );
          allCriteria.add({
            'id': valueObj.id.toString(),
            'pid': option.pid,
            'vid': valueObj.vid,
            'name': valueObj.name.trim().toLowerCase(),
            'tokens': valueObj.name.toLowerCase().split(RegExp(r'[\s\-\(\)\/]+')).where((t) => t.isNotEmpty).toList(),
          });
        } catch (_) {}
      }
    }

    if (allCriteria.isEmpty) return null;

    // 2. Filter criteria: Only keep criteria that match AT LEAST ONE variant.
    List<Map<String, dynamic>> effectiveCriteria = [];
    
    for (var criterion in allCriteria) {
      bool matchesAtLeastOne = false;
      final id = criterion['id'] as String;
      final pid = criterion['pid'] as String?;
      final vid = criterion['vid'] as String?;
      final valName = criterion['name'] as String;
      final tokens = criterion['tokens'] as List<String>;

      for (var variant in widget.product.variants!) {
        final props = variant.propsIds ?? '';
        final name = variant.name.toLowerCase();
        
        bool match = false;
        
        // PID:VID Match (Exact 1688 Match)
        if (pid != null && vid != null && props.contains('$pid:$vid')) match = true;
        // ID Match
        else if (RegExp(r'(^|[^0-9])' + RegExp.escape(id) + r'([^0-9]|$)').hasMatch(props)) match = true;
        // Name Match
        else if (name.contains(valName)) match = true;
        // Props Name Match
        else if (props.toLowerCase().contains(valName)) match = true;
        // Token Match (at least one token)
        else {
           for (var token in tokens) {
             if (name.contains(token)) {
               match = true; 
               break;
             }
           }
        }

        if (match) {
          matchesAtLeastOne = true;
          break;
        }
      }
      
      if (matchesAtLeastOne) {
        effectiveCriteria.add(criterion);
      }
    }

    ProductVariant? bestMatch;
    int bestScore = 0;

    // 3. Find best match using effective criteria
    for (var variant in widget.product.variants!) {
      int currentScore = 0;
      int matchedOptionsCount = 0;
      
      final props = variant.propsIds ?? '';
      final name = variant.name.toLowerCase();

      for (var criterion in effectiveCriteria) {
        int optionScore = 0;
        final id = criterion['id'] as String;
        final pid = criterion['pid'] as String?;
        final vid = criterion['vid'] as String?;
        final valName = criterion['name'] as String;
        final tokens = criterion['tokens'] as List<String>;

        // 0. PID:VID Match (Absolute Best: 200 points)
        if (pid != null && vid != null && props.contains('$pid:$vid')) {
          optionScore = 200;
        }
        // 1. ID Match (Strongest: 100 points)
        else if (RegExp(r'(^|[^0-9])' + RegExp.escape(id) + r'([^0-9]|$)').hasMatch(props)) {
          optionScore = 100;
        }
        // 2. Exact Name Match in Variant Name (50 points)
        else if (name.contains(valName)) {
          optionScore = 50;
        }
        // 3. Exact Name Match in Props (20 points)
        else if (props.toLowerCase().contains(valName)) {
          optionScore = 20;
        }
        // 4. Token Match (Fuzzy: 10 points per token)
        else {
          for (var token in tokens) {
            if (name.contains(token)) {
              optionScore += 10;
            }
          }
        }

        if (optionScore > 0) {
          currentScore += optionScore;
          matchedOptionsCount++;
        }
      }

      // Only consider variants that matched ALL effective criteria
      if (matchedOptionsCount == effectiveCriteria.length) {
        if (currentScore > bestScore) {
          bestScore = currentScore;
          bestMatch = variant;
        }
      }
    }

    return bestMatch;
  }

  void _handleOptionSelected(String optionName, String value) {
    setState(() {
      _selectedOptions[optionName] = value;
    });
    widget.onOptionSelected(optionName, value);
  }

  double get _totalPrice {
    double total = 0;
    if (widget.product.options == null || widget.product.options!.isEmpty) {
      return widget.product.price * _singleQuantity;
    }

    // If we have options, sum up quantities * variant prices
    if (_quantities.isEmpty) return 0;

    _quantities.forEach((variantId, qty) {
      final variant = widget.product.variants?.firstWhere((v) => v.id == variantId);
      if (variant != null) {
        total += variant.price * qty;
      }
    });
    
    return total;
  }

  int get _totalItems {
    if (widget.product.options == null || widget.product.options!.isEmpty) {
      return _singleQuantity;
    }
    return _quantities.values.fold(0, (sum, qty) => sum + qty);
  }

  String? _findImageForOptionValue(String optionName, String valueName) {
    // Try to find image using selectedOptions first (most reliable)
    if (widget.product.variants != null && widget.product.options != null) {
      // Find the option and value IDs
      int? optionId;
      int? valueId;
      for (var option in widget.product.options!) {
        if (option.name.toLowerCase() == optionName.toLowerCase()) {
          optionId = option.id;
          for (var value in option.values) {
            if (value.name.toLowerCase() == valueName.toLowerCase()) {
              valueId = value.id;
              // If value has image_url, return it directly
              if (value.imageUrl != null && value.imageUrl!.isNotEmpty) {
                return value.imageUrl;
              }
              break;
            }
          }
          break;
        }
      }

      // Now find a variant with matching selectedOption
      if (optionId != null && valueId != null) {
        for (var variant in widget.product.variants!) {
          if (variant.selectedOptions != null) {
            for (var selOpt in variant.selectedOptions!) {
              if (selOpt.optionId == optionId && selOpt.valueId == valueId) {
                // Return variant image or selectedOption image
                if (selOpt.imageUrl != null && selOpt.imageUrl!.isNotEmpty) {
                  return selOpt.imageUrl;
                }
                if (variant.image != null && variant.image!.isNotEmpty) {
                  return variant.image;
                }
              }
            }
          }
        }
      }
    }

    // Fallback: Simple name containment check
    if (widget.product.variants != null) {
      for (var variant in widget.product.variants!) {
        final name = variant.name.toLowerCase();
        final valName = valueName.toLowerCase();
        
        if (name.contains(valName)) {
          if (variant.image != null && variant.image!.isNotEmpty) {
            return variant.image;
          }
        }
      }
    }
    return null;
  }

  /// Find variant using selectedOptions (most reliable method)
  ProductVariant? _getVariantBySelectedOptions(Map<String, String> options) {
    if (widget.product.variants == null || widget.product.variants!.isEmpty) return null;
    if (widget.product.options == null || widget.product.options!.isEmpty) return null;

    // Build a map of optionId -> valueId from the user's selection
    Map<int, int> selectedOptionValueIds = {};
    for (var option in widget.product.options!) {
      final selectedValueName = options[option.name];
      if (selectedValueName != null) {
        for (var value in option.values) {
          if (value.name.toLowerCase() == selectedValueName.toLowerCase()) {
            selectedOptionValueIds[option.id] = value.id;
            break;
          }
        }
      }
    }

    if (selectedOptionValueIds.isEmpty) return null;

    // Find variant where ALL selected options match
    for (var variant in widget.product.variants!) {
      if (variant.selectedOptions == null) continue;
      
      bool allMatch = true;
      int matchCount = 0;
      
      for (var entry in selectedOptionValueIds.entries) {
        bool found = false;
        for (var selOpt in variant.selectedOptions!) {
          if (selOpt.optionId == entry.key && selOpt.valueId == entry.value) {
            found = true;
            matchCount++;
            break;
          }
        }
        if (!found) {
          allMatch = false;
          break;
        }
      }

      // Return variant if all selected options match
      if (allMatch && matchCount == selectedOptionValueIds.length) {
        return variant;
      }
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasOptions = widget.product.options != null && widget.product.options!.isNotEmpty;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.neutral900 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Select Options',
                  style: AppTypography.headingSmall(color: isDark ? Colors.white : Colors.black).copyWith(fontSize: 16),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Product Info Header - Compact
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Product Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: widget.product.mainImage.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: widget.product.mainImage,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                          placeholder: (context, url) => Container(
                            width: 60,
                            height: 60,
                            color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                          errorWidget: (context, url, error) => Container(
                            width: 60,
                            height: 60,
                            color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                            child: const Icon(Iconsax.image, color: Colors.grey, size: 20),
                          ),
                        )
                      : Container(
                          width: 60,
                          height: 60,
                          color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                          child: const Icon(Iconsax.image, color: Colors.grey, size: 20),
                        ),
                ),
                const SizedBox(width: 12),
                // Product Name & Price
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.product.name.isNotEmpty 
                            ? widget.product.name 
                            : (widget.product.displayName ?? 'Product #${widget.product.id}'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyMedium(
                          color: isDark ? Colors.white : Colors.black,
                        ).copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.product.currencySymbol}${widget.product.price.toStringAsFixed(2)}',
                        style: AppTypography.bodyLarge(
                          color: AppColors.primary500,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 12),
            
            // Options
            if (hasOptions)
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Render all options except the last one as filters
                      ...List.generate(widget.product.options!.length - 1, (index) {
                        final option = widget.product.options![index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              option.name,
                              style: AppTypography.bodyLarge().copyWith(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const SizedBox(height: 12),
                            SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: option.values.map((value) {
                                  final isSelected = _selectedOptions[option.name] == value.name;
                                  
                                  // PRIORITY 1: Try to get image (most reliable for product variants)
                                  String? imageUrl = value.imageUrl;
                                  if (imageUrl == null || imageUrl.isEmpty) {
                                    imageUrl = _findImageForOptionValue(option.name, value.name);
                                  }
                                  final hasImage = imageUrl != null && imageUrl.isNotEmpty;
                                  
                                  // PRIORITY 2: Only show color swatch if NO image and it's a color option
                                  final isColorOption = option.isColor || 
                                      option.name.toLowerCase().contains('color') ||
                                      option.name.toLowerCase().contains('colour');
                                  
                                  Color? colorValue;
                                  // Only try color if no image available
                                  if (!hasImage && isColorOption) {
                                    // Skip placeholder colors like #CCCCCC
                                    if (value.color != null && 
                                        value.color!.isNotEmpty && 
                                        value.color!.toUpperCase() != '#CCCCCC' &&
                                        value.color!.toUpperCase() != '#CCC' &&
                                        value.color!.toUpperCase() != 'CCCCCC') {
                                      colorValue = _parseColor(value.color!);
                                    }
                                    // Fallback: try parsing color from value name
                                    colorValue ??= _parseColor(value.name);
                                  }
                                  
                                  // For color options: always show circle swatch, use fallback color if needed
                                  final showColorSwatch = !hasImage && isColorOption;
                                  // Use a neutral fallback color when we can't parse the actual color
                                  final displayColor = colorValue ?? (isColorOption ? const Color(0xFFD4A574) : null);
                                  
                                  return GestureDetector(
                                    onTap: () => _handleOptionSelected(option.name, value.name),
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Column(
                                        children: [
                                          Container(
                                            padding: (hasImage || showColorSwatch)
                                                ? const EdgeInsets.all(3)
                                                : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                            decoration: BoxDecoration(
                                              color: (!showColorSwatch && !hasImage)
                                                  ? (isSelected 
                                                      ? AppColors.primary500 
                                                      : (isDark ? AppColors.neutral800 : AppColors.neutral100))
                                                  : Colors.transparent,
                                              borderRadius: BorderRadius.circular(showColorSwatch ? 30 : 8),
                                              border: Border.all(
                                                color: isSelected 
                                                    ? AppColors.primary500 
                                                    : (isDark ? AppColors.neutral700 : AppColors.neutral300),
                                                width: isSelected ? 2.5 : 1.5,
                                              ),
                                            ),
                                            child: hasImage 
                                              // SHOW IMAGE (preferred - actual product photos)
                                              ? Stack(
                                                  children: [
                                                    ClipRRect(
                                                      borderRadius: BorderRadius.circular(6),
                                                      child: CachedNetworkImage(
                                                        imageUrl: imageUrl!,
                                                        width: 70,
                                                        height: 70,
                                                        fit: BoxFit.cover,
                                                        placeholder: (context, url) => Container(
                                                          width: 70,
                                                          height: 70,
                                                          color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                                          child: const Center(
                                                            child: SizedBox(
                                                              width: 20,
                                                              height: 20,
                                                              child: CircularProgressIndicator(strokeWidth: 2),
                                                            ),
                                                          ),
                                                        ),
                                                        errorWidget: (context, url, error) => Container(
                                                          width: 70,
                                                          height: 70,
                                                          color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                                          child: const Icon(Iconsax.image, size: 24),
                                                        ),
                                                      ),
                                                    ),
                                                    if (isSelected)
                                                      Positioned(
                                                        right: 4,
                                                        top: 4,
                                                        child: Container(
                                                          padding: const EdgeInsets.all(2),
                                                          decoration: const BoxDecoration(
                                                            color: AppColors.primary500,
                                                            shape: BoxShape.circle,
                                                          ),
                                                          child: const Icon(
                                                            Icons.check,
                                                            color: Colors.white,
                                                            size: 14,
                                                          ),
                                                        ),
                                                      ),
                                                  ],
                                                )
                                              : showColorSwatch
                                              // SHOW COLOR SWATCH (for color options - circle with color or fallback)
                                              ? Container(
                                                  width: 48,
                                                  height: 48,
                                                  decoration: BoxDecoration(
                                                    // Use gradient if no real color (fallback for "light skin tone" etc)
                                                    gradient: colorValue == null ? LinearGradient(
                                                      begin: Alignment.topLeft,
                                                      end: Alignment.bottomRight,
                                                      colors: [
                                                        displayColor!.withOpacity(0.8),
                                                        displayColor.withOpacity(0.5),
                                                      ],
                                                    ) : null,
                                                    color: colorValue,
                                                    shape: BoxShape.circle,
                                                    border: (colorValue != null && _isLightColor(colorValue)) || colorValue == null
                                                        ? Border.all(color: Colors.grey.shade400, width: 1) 
                                                        : null,
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: displayColor!.withOpacity(0.4),
                                                        blurRadius: 4,
                                                        offset: const Offset(0, 2),
                                                      ),
                                                    ],
                                                  ),
                                                  child: isSelected 
                                                      ? Icon(
                                                          Icons.check,
                                                          color: (colorValue != null && _isLightColor(colorValue)) || colorValue == null 
                                                              ? Colors.black 
                                                              : Colors.white,
                                                          size: 24,
                                                        )
                                                      : null,
                                                )
                                              // SHOW TEXT (for options without image/color)
                                              : Text(
                                                  value.name,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: isSelected 
                                                        ? Colors.white 
                                                        : (isDark ? Colors.white : Colors.black87),
                                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                                  ),
                                                ),
                                          ),
                                          // Show name below image/swatch
                                          if (hasImage || showColorSwatch) ...[
                                            const SizedBox(height: 4),
                                            ConstrainedBox(
                                              constraints: const BoxConstraints(maxWidth: 80),
                                              child: Text(
                                                value.name,
                                                textAlign: TextAlign.center,
                                                softWrap: true,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  height: 1.2,
                                                  color: isSelected 
                                                      ? AppColors.primary500
                                                      : (isDark ? Colors.white70 : Colors.black54),
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        );
                      }),

                      // Last Option: Render as List with Counters
                      Builder(
                        builder: (context) {
                          final lastOption = widget.product.options!.last;
                          
                          // Check if previous options are selected
                          bool previousSelected = true;
                          for (int i = 0; i < widget.product.options!.length - 1; i++) {
                            if (!_selectedOptions.containsKey(widget.product.options![i].name)) {
                              previousSelected = false;
                              break;
                            }
                          }

                          if (!previousSelected) {
                            return Center(
                              child: Text(
                                'Please select options above first',
                                style: TextStyle(color: Colors.grey),
                              ),
                            );
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lastOption.name,
                                style: AppTypography.bodyLarge().copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              ...lastOption.values.map((value) {
                                // Construct temp options map for this row
                                final currentOptions = Map<String, String>.from(_selectedOptions);
                                currentOptions[lastOption.name] = value.name;
                                
                                final variant = _getVariantForCombination(currentOptions);
                                final isVariantFound = variant != null;
                                
                                bool hasStock = true;
                                if (variant != null) {
                                  if (variant.status == 'out_of_stock') {
                                    hasStock = false;
                                  } else if (variant.stock != null && variant.stock! <= 0) {
                                    hasStock = false;
                                  }
                                }
                                
                                final isAvailable = isVariantFound && hasStock;
                                final qty = _quantities[variant?.id] ?? 0;

                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: Row(
                                    children: [
                                      if (variant?.image != null && variant!.image!.isNotEmpty)
                                         Padding(
                                           padding: const EdgeInsets.only(right: 12.0),
                                           child: ClipRRect(
                                             borderRadius: BorderRadius.circular(4),
                                             child: CachedNetworkImage(
                                               imageUrl: variant!.image!,
                                               width: 40,
                                               height: 40,
                                               fit: BoxFit.cover,
                                               placeholder: (context, url) => Image.asset(
                                                 'assets/images/productfailbackorskeleton_loading.png',
                                                 width: 40,
                                                 height: 40,
                                                 fit: BoxFit.cover,
                                               ),
                                               errorWidget: (context, url, error) => Image.asset(
                                                 'assets/images/productfailbackorskeleton_loading.png',
                                                 width: 40,
                                                 height: 40,
                                                 fit: BoxFit.cover,
                                               ),
                                             ),
                                           ),
                                         )
                                      else
                                         Padding(
                                           padding: const EdgeInsets.only(right: 12.0),
                                           child: ClipRRect(
                                             borderRadius: BorderRadius.circular(4),
                                             child: Image.asset(
                                               'assets/images/productfailbackorskeleton_loading.png',
                                               width: 40,
                                               height: 40,
                                               fit: BoxFit.cover,
                                             ),
                                           ),
                                         ),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              value.name,
                                              style: TextStyle(
                                                fontSize: 16,
                                                color: isAvailable ? (isDark ? Colors.white : Colors.black) : Colors.grey,
                                              ),
                                            ),
                                            if (variant != null)
                                              Text(
                                                '${widget.product.currencySymbol}${variant.price.toStringAsFixed(2)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      if (isAvailable)
                                        Container(
                                          decoration: BoxDecoration(
                                            border: Border.all(color: isDark ? AppColors.neutral700 : AppColors.neutral300),
                                            borderRadius: BorderRadius.circular(24),
                                            color: qty > 0 ? AppColors.primary500.withOpacity(0.1) : null,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (qty > 0) ...[
                                                IconButton(
                                                  onPressed: () => setState(() {
                                                    if (qty > 0) _quantities[variant!.id] = qty - 1;
                                                    if (_quantities[variant!.id] == 0) _quantities.remove(variant.id);
                                                  }),
                                                  icon: const Icon(Icons.remove, size: 18),
                                                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                  padding: EdgeInsets.zero,
                                                  color: AppColors.primary500,
                                                ),
                                                Text(
                                                  '$qty',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: AppColors.primary500,
                                                  ),
                                                ),
                                              ],
                                              IconButton(
                                                onPressed: () => setState(() {
                                                  _quantities[variant!.id] = qty + 1;
                                                }),
                                                icon: const Icon(Icons.add, size: 18),
                                                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                                                padding: EdgeInsets.zero,
                                                color: qty > 0 ? AppColors.primary500 : (isDark ? Colors.white : Colors.black),
                                              ),
                                            ],
                                          ),
                                        )
                                      else
                                        Text(
                                          isVariantFound ? 'Out of Stock' : 'Unavailable',
                                          style: const TextStyle(color: Colors.red, fontSize: 12)
                                        ),
                                    ],
                                  ),
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              )
            else
              // No Options - Single Quantity
              Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Quantity',
                        style: AppTypography.bodyLarge().copyWith(fontWeight: FontWeight.bold),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: isDark ? AppColors.neutral700 : AppColors.neutral300),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: _singleQuantity > 1 ? () => setState(() => _singleQuantity--) : null,
                              icon: const Icon(Icons.remove, size: 20),
                            ),
                            Text(
                              '$_singleQuantity',
                              style: AppTypography.bodyLarge().copyWith(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              onPressed: () => setState(() => _singleQuantity++),
                              icon: const Icon(Icons.add, size: 20),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Total Price
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total (${_totalItems} items)',
                  style: AppTypography.bodyLarge().copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.product.currencySymbol}${_totalPrice.toStringAsFixed(2)}',
                  style: AppTypography.headingMedium(color: AppColors.primary500),
                ),
              ],
            ),
            const SizedBox(height: 16),
        
            // Add to Cart Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _totalItems > 0 ? () {
                  List<Map<String, dynamic>> items = [];
                  if (hasOptions) {
                    _quantities.forEach((variantId, qty) {
                      if (qty > 0) {
                        final variant = widget.product.variants!.firstWhere((v) => v.id == variantId);
                        items.add({
                          'variant': variant,
                          'quantity': qty,
                        });
                      }
                    });
                  } else {
                    items.add({
                      'variant': null,
                      'quantity': _singleQuantity,
                    });
                  }
                  widget.onAddToCart(items);
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
                child: const Text(
                  'Add to Cart',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
