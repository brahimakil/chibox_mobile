import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

/// Filter options for product sorting
enum ProductSortOption {
  newest,
  priceLowToHigh,
  priceHighToLow,
}

/// Extension to get display name and API value for sort options
extension ProductSortOptionX on ProductSortOption {
  String get displayName {
    switch (this) {
      case ProductSortOption.newest:
        return 'Newest';
      case ProductSortOption.priceLowToHigh:
        return 'Price: Low to High';
      case ProductSortOption.priceHighToLow:
        return 'Price: High to Low';
    }
  }

  /// Returns the API value for this sort option.
  /// Returns null for 'newest' (default) to avoid sending unnecessary params.
  String? get apiValue {
    switch (this) {
      case ProductSortOption.newest:
        return null; // Don't send sort_by for default sorting
      case ProductSortOption.priceLowToHigh:
        return 'price_asc';
      case ProductSortOption.priceHighToLow:
        return 'price_desc';
    }
  }

  static ProductSortOption fromApiValue(String? value) {
    switch (value) {
      case 'price_asc':
        return ProductSortOption.priceLowToHigh;
      case 'price_desc':
        return ProductSortOption.priceHighToLow;
      case 'newest':
      default:
        return ProductSortOption.newest;
    }
  }
}

/// Represents the current filter state
class ProductFilterState {
  final ProductSortOption sortBy;
  final double? minPrice;
  final double? maxPrice;

  const ProductFilterState({
    this.sortBy = ProductSortOption.newest,
    this.minPrice,
    this.maxPrice,
  });

  ProductFilterState copyWith({
    ProductSortOption? sortBy,
    double? minPrice,
    double? maxPrice,
    bool clearMinPrice = false,
    bool clearMaxPrice = false,
  }) {
    return ProductFilterState(
      sortBy: sortBy ?? this.sortBy,
      minPrice: clearMinPrice ? null : (minPrice ?? this.minPrice),
      maxPrice: clearMaxPrice ? null : (maxPrice ?? this.maxPrice),
    );
  }

  bool get hasActiveFilters =>
      sortBy != ProductSortOption.newest || minPrice != null || maxPrice != null;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProductFilterState &&
        other.sortBy == sortBy &&
        other.minPrice == minPrice &&
        other.maxPrice == maxPrice;
  }

  @override
  int get hashCode => Object.hash(sortBy, minPrice, maxPrice);
}

/// A reusable bottom sheet for product filtering
/// Matches the design from CategoryProductsScreen
class ProductFilterSheet extends StatefulWidget {
  final ProductFilterState initialFilter;
  final ValueChanged<ProductFilterState> onApply;
  final VoidCallback? onReset;

  const ProductFilterSheet({
    super.key,
    required this.initialFilter,
    required this.onApply,
    this.onReset,
  });

  /// Show the filter sheet as a modal bottom sheet
  static Future<ProductFilterState?> show(
    BuildContext context, {
    required ProductFilterState currentFilter,
  }) async {
    return showModalBottomSheet<ProductFilterState>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProductFilterSheet(
        initialFilter: currentFilter,
        onApply: (filter) => Navigator.pop(context, filter),
      ),
    );
  }

  @override
  State<ProductFilterSheet> createState() => _ProductFilterSheetState();
}

class _ProductFilterSheetState extends State<ProductFilterSheet> {
  late ProductSortOption _sortBy;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initialFilter.sortBy;
    _minPriceController = TextEditingController(
      text: widget.initialFilter.minPrice?.toString() ?? '',
    );
    _maxPriceController = TextEditingController(
      text: widget.initialFilter.maxPrice?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  void _applyFilters() {
    final minPrice = double.tryParse(_minPriceController.text);
    final maxPrice = double.tryParse(_maxPriceController.text);
    
    widget.onApply(ProductFilterState(
      sortBy: _sortBy,
      minPrice: minPrice,
      maxPrice: maxPrice,
    ));
  }

  void _resetFilters() {
    setState(() {
      _sortBy = ProductSortOption.newest;
      _minPriceController.clear();
      _maxPriceController.clear();
    });
    widget.onReset?.call();
  }

  Widget _buildSortChip(ProductSortOption option, bool isDark) {
    final isSelected = _sortBy == option;
    return FilterChip(
      label: Text(option.displayName),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          _sortBy = option;
        });
      },
      backgroundColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
      selectedColor: AppColors.primary500,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
      ),
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary500 : Colors.transparent,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      expand: false,
      snap: true,
      snapSizes: const [0.3, 0.6, 0.85],
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          controller: scrollController,
          physics: const ClampingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle - at the very top
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Content with padding
              Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  bottom: MediaQuery.of(context).viewInsets.bottom + MediaQuery.of(context).padding.bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Filters',
                        style: AppTypography.headingSmall(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      Row(
                        children: [
                          // Reset button
                          TextButton(
                            onPressed: _resetFilters,
                            child: Text(
                              'Reset',
                              style: TextStyle(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: Icon(
                              Icons.close,
                              color: isDark ? Colors.white : Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Sort By
                  Text(
                    'Sort By',
                    style: AppTypography.labelLarge(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ProductSortOption.values.map((option) {
                      return _buildSortChip(option, isDark);
                    }).toList(),
                  ),

                  const SizedBox(height: 24),

                  // Price Range
                  Text(
                    'Price Range',
                    style: AppTypography.labelLarge(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Min',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            filled: true,
                            fillColor: isDark 
                                ? Colors.white.withOpacity(0.05) 
                                : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          '-',
                          style: TextStyle(
                            color: isDark ? Colors.white : Colors.black,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(color: isDark ? Colors.white : Colors.black),
                          decoration: InputDecoration(
                            hintText: 'Max',
                            hintStyle: TextStyle(
                              color: isDark ? Colors.white38 : Colors.black38,
                            ),
                            prefixText: '\$ ',
                            prefixStyle: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                            filled: true,
                            fillColor: isDark 
                                ? Colors.white.withOpacity(0.05) 
                                : Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Apply Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _applyFilters,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Apply Filters',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}