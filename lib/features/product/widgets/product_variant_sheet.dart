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

  ProductVariant? _getVariantForCombination(Map<String, String> options) {
    if (widget.product.variants == null || widget.product.variants!.isEmpty) return null;
    if (widget.product.options == null) return null;

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
    // 1. Try to find a variant that matches this option value and has an image
    if (widget.product.variants != null) {
      for (var variant in widget.product.variants!) {
        final name = variant.name.toLowerCase();
        final valName = valueName.toLowerCase();
        
        // Simple containment check
        if (name.contains(valName)) {
             if (variant.image != null && variant.image!.isNotEmpty) {
               return variant.image;
             }
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasOptions = widget.product.options != null && widget.product.options!.isNotEmpty;
    
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      padding: const EdgeInsets.all(16),
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
            const SizedBox(height: 16),
            
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
                                  
                                  // Try to get image from value, or fallback to variant search
                                  String? imageUrl = value.imageUrl;
                                  if (imageUrl == null || imageUrl.isEmpty) {
                                    imageUrl = _findImageForOptionValue(option.name, value.name);
                                  }
                                  
                                  final hasImage = imageUrl != null && imageUrl.isNotEmpty;
                                  
                                  return GestureDetector(
                                    onTap: () => _handleOptionSelected(option.name, value.name),
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      padding: hasImage 
                                          ? const EdgeInsets.all(2) 
                                          : const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: hasImage 
                                            ? (isSelected ? AppColors.primary500 : Colors.transparent)
                                            : (isSelected 
                                                ? AppColors.primary500 
                                                : (isDark ? AppColors.neutral800 : AppColors.neutral100)),
                                        borderRadius: BorderRadius.circular(hasImage ? 8 : 8), // Uniform radius
                                        border: hasImage 
                                            ? Border.all(
                                                color: isSelected ? AppColors.primary500 : (isDark ? AppColors.neutral700 : AppColors.neutral300),
                                                width: 2,
                                              )
                                            : Border.all(
                                                color: isSelected ? AppColors.primary500 : Colors.transparent,
                                              ),
                                      ),
                                      child: hasImage 
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: CachedNetworkImage(
                                              imageUrl: imageUrl!,
                                              width: 50, // Smaller
                                              height: 50, // Smaller
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                width: 50,
                                                height: 50,
                                                color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                                child: Image.asset(
                                                  'assets/images/productfailbackorskeleton_loading.png',
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                              errorWidget: (context, url, error) => Container(
                                                width: 50,
                                                height: 50,
                                                color: isDark ? AppColors.neutral800 : AppColors.neutral100,
                                                child: Image.asset(
                                                  'assets/images/productfailbackorskeleton_loading.png',
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            ),
                                          )
                                        : Text(
                                            value.name,
                                            style: TextStyle(
                                              fontSize: 13, // Smaller
                                              color: isSelected 
                                                  ? Colors.white 
                                                  : (isDark ? Colors.white70 : Colors.black87),
                                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                            ),
                                          ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),
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
