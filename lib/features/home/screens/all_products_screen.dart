import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/home_service.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/wishlist_service.dart';
import '../../../shared/widgets/widgets.dart';
import '../../product/screens/product_details_screen.dart';

class AllProductsScreen extends StatefulWidget {
  const AllProductsScreen({super.key});

  @override
  State<AllProductsScreen> createState() => _AllProductsScreenState();
}

enum SortOption { newest, priceLowToHigh, priceHighToLow, nameAZ }

class _AllProductsScreenState extends State<AllProductsScreen> {
  SortOption _selectedSort = SortOption.newest;
  RangeValues _priceRange = const RangeValues(0, 10000);
  double _maxPrice = 10000;
  bool _filtersInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_filtersInitialized) {
      final homeService = Provider.of<HomeService>(context, listen: false);
      if (homeService.allProducts.isNotEmpty) {
        double max = 0;
        for (var p in homeService.allProducts) {
          if (p.price > max) max = p.price;
        }
        // Round up to nearest 100
        _maxPrice = (max / 100).ceil() * 100.0;
        if (_maxPrice == 0) _maxPrice = 1000;
        _priceRange = RangeValues(0, _maxPrice);
      }
      _filtersInitialized = true;
    }
  }

  List<Product> _getFilteredProducts(List<Product> allProducts) {
    List<Product> filtered = List.from(allProducts);

    // Filter by Price
    filtered = filtered.where((p) => 
      p.price >= _priceRange.start && p.price <= _priceRange.end
    ).toList();

    // Sort
    switch (_selectedSort) {
      case SortOption.priceLowToHigh:
        filtered.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceHighToLow:
        filtered.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.nameAZ:
        filtered.sort((a, b) => (a.displayName ?? a.name).compareTo(b.displayName ?? b.name));
        break;
      case SortOption.newest:
      default:
        // Assuming original list is sorted by newest or default order
        break;
    }

    return filtered;
  }

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        currentSort: _selectedSort,
        currentRange: _priceRange,
        maxPrice: _maxPrice,
        onApply: (sort, range) {
          setState(() {
            _selectedSort = sort;
            _priceRange = range;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final homeService = Provider.of<HomeService>(context);
    final filteredProducts = _getFilteredProducts(homeService.allProducts);

    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      appBar: AppBar(
        backgroundColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: isDark ? Colors.white : Colors.black,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'All Products',
          style: AppTypography.headingMedium(
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(
              Iconsax.filter,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: _showFilterModal,
          ),
        ],
      ),
      body: filteredProducts.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Iconsax.search_status,
                    size: 64,
                    color: isDark ? AppColors.neutral700 : AppColors.neutral300,
                  ),
                  AppSpacing.verticalMd,
                  Text(
                    'No products found',
                    style: AppTypography.bodyLarge(
                      color: isDark ? AppColors.neutral400 : AppColors.neutral500,
                    ),
                  ),
                  AppSpacing.verticalSm,
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _priceRange = RangeValues(0, _maxPrice);
                        _selectedSort = SortOption.newest;
                      });
                    },
                    child: const Text('Clear Filters'),
                  ),
                ],
              ),
            )
          : MasonryGridView.count(
              padding: const EdgeInsets.all(8),
              crossAxisCount: 2,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
              itemCount: filteredProducts.length,
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return ProductCard.fromProduct(
                  product,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProductDetailsScreen(product: product),
                      ),
                    );
                    // Removed .then(() => fetchHomeData()) - it was overwriting wishlist state
                    // ProductCard already syncs state via WishlistHelper.onStatusChanged stream
                  },
                )

                    .animate()
                    .fadeIn(delay: Duration(milliseconds: 50 * (index % 10)))
                    .slideY(begin: 0.1, end: 0);
              },
            ),
    );
  }
}

class _FilterBottomSheet extends StatefulWidget {
  final SortOption currentSort;
  final RangeValues currentRange;
  final double maxPrice;
  final Function(SortOption, RangeValues) onApply;

  const _FilterBottomSheet({
    required this.currentSort,
    required this.currentRange,
    required this.maxPrice,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late SortOption _selectedSort;
  late RangeValues _currentRange;

  @override
  void initState() {
    super.initState();
    _selectedSort = widget.currentSort;
    _currentRange = widget.currentRange;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter & Sort',
                style: AppTypography.headingSmall(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          AppSpacing.verticalLg,
          
          // Sort Options
          Text(
            'Sort By',
            style: AppTypography.labelLarge(
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          AppSpacing.verticalSm,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildSortChip('Newest', SortOption.newest, isDark),
              _buildSortChip('Price: Low to High', SortOption.priceLowToHigh, isDark),
              _buildSortChip('Price: High to Low', SortOption.priceHighToLow, isDark),
              _buildSortChip('Name: A-Z', SortOption.nameAZ, isDark),
            ],
          ),
          
          AppSpacing.verticalLg,

          // Price Range
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Price Range',
                style: AppTypography.labelLarge(
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                '\$${_currentRange.start.toInt()} - \$${_currentRange.end.toInt()}',
                style: AppTypography.bodyMedium(
                  color: AppColors.primary500,
                ).copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          RangeSlider(
            values: _currentRange,
            min: 0,
            max: widget.maxPrice,
            activeColor: AppColors.primary500,
            inactiveColor: isDark ? AppColors.neutral700 : AppColors.neutral200,
            onChanged: (values) {
              setState(() => _currentRange = values);
            },
          ),

          AppSpacing.verticalXl,

          // Apply Button
          AppButton(
            text: 'Apply Filters',
            onPressed: () {
              widget.onApply(_selectedSort, _currentRange);
              Navigator.pop(context);
            },
          ),
          AppSpacing.verticalMd,
        ],
      ),
    );
  }

  Widget _buildSortChip(String label, SortOption option, bool isDark) {
    final isSelected = _selectedSort == option;
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected 
            ? Colors.white 
            : (isDark ? Colors.white : Colors.black),
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _selectedSort = option);
      },
      backgroundColor: isDark ? AppColors.neutral800 : AppColors.neutral100,
      selectedColor: AppColors.primary500,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? Colors.transparent : (isDark ? AppColors.neutral700 : AppColors.neutral300),
      ),
    );
  }
}
