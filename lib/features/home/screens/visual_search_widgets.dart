import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:iconsax/iconsax.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/object_detection_service.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../../../shared/widgets/sheets/product_filter_sheet.dart';
import '../../product/screens/product_details_screen.dart';

// ============ Top Buttons ============

class VSTopButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const VSTopButton({super.key, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black54, 
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ============ Control Buttons ============

class VSControlButton extends StatelessWidget {
  final IconData icon;
  final double size;
  final VoidCallback onTap;

  const VSControlButton({
    super.key, 
    required this.icon, 
    required this.size, 
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.black54, 
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: Colors.white, size: size * 0.45),
      ),
    );
  }
}

class VSCaptureButton extends StatelessWidget {
  final bool isSearching;
  final VoidCallback onTap;

  const VSCaptureButton({
    super.key, 
    required this.isSearching, 
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isSearching ? null : onTap,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
          color: isSearching ? Colors.grey.withOpacity(0.4) : Colors.white.withOpacity(0.15),
        ),
        child: isSearching
            ? const Center(
                child: SizedBox(
                  width: 28, 
                  height: 28, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                ),
              )
            : const Icon(Iconsax.search_normal_1, color: Colors.white, size: 28),
      ),
    );
  }
}

// ============ Suggestions Row ============

class VSSuggestionsRow extends StatelessWidget {
  final List<DetectedObject> suggestions;
  final int selectedIndex;
  final bool isSearching;
  final Function(int) onSelect;
  final bool inSheet;
  final bool isDark;

  const VSSuggestionsRow({
    super.key,
    required this.suggestions,
    required this.selectedIndex,
    required this.isSearching,
    required this.onSelect,
    this.inSheet = false,
    this.isDark = false,
  });

  @override
  Widget build(BuildContext context) {
    final size = inSheet ? 52.0 : 60.0;
    
    return SizedBox(
      height: size + 4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: suggestions.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final s = suggestions[index];
          final isSelected = index == selectedIndex;

          return GestureDetector(
            onTap: isSelected ? null : () => onSelect(index),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              opacity: isSearching && !isSelected ? 0.5 : 1.0,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected 
                        ? AppColors.primary500 
                        : (inSheet 
                            ? (isDark ? Colors.grey[700]! : Colors.grey[300]!) 
                            : Colors.white54),
                    width: isSelected ? 2.5 : 1.5,
                  ),
                  boxShadow: isSelected 
                      ? [BoxShadow(color: AppColors.primary500.withOpacity(0.4), blurRadius: 8)] 
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (s.croppedImagePath != null)
                        Image.file(File(s.croppedImagePath!), fit: BoxFit.cover)
                      else
                        Container(
                          color: Colors.grey[800], 
                          child: const Icon(Icons.image, color: Colors.white38),
                        ),
                      if (isSelected)
                        Positioned(
                          top: 3, 
                          right: 3,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: AppColors.primary500, 
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.check, size: 10, color: Colors.white),
                          ),
                        ),
                      Positioned(
                        left: 0, 
                        right: 0, 
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [Colors.black87, Colors.transparent],
                            ),
                          ),
                          child: Text(
                            s.primaryLabel,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white, 
                              fontSize: 8, 
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ============ Results Sheet ============

class VSResultsSheet extends StatefulWidget {
  final ScrollController scrollController;
  final bool isDark;
  final bool hasResults;
  final bool isSearching;
  final List<Product> products;
  final int totalProducts;
  final bool isLoadingMore;
  final bool hasMorePages;
  final ProductFilterState filterState;
  final DetectionResult? detectionResult;
  final int selectedSuggestionIndex;
  final VoidCallback onStartNewSearch;
  final VoidCallback onShowFilter;
  final Function(ProductFilterState) onApplyFilter;
  final VoidCallback onLoadMore;
  final VoidCallback onPrefetch;
  final Function(int) onSelectSuggestion;
  final VoidCallback onExpandSheet;
  final bool isPrefetching;
  final List<Product> prefetchedProducts;

  const VSResultsSheet({
    super.key,
    required this.scrollController,
    required this.isDark,
    required this.hasResults,
    required this.isSearching,
    required this.products,
    required this.totalProducts,
    required this.isLoadingMore,
    required this.hasMorePages,
    required this.filterState,
    required this.detectionResult,
    required this.selectedSuggestionIndex,
    required this.onStartNewSearch,
    required this.onShowFilter,
    required this.onApplyFilter,
    required this.onLoadMore,
    required this.onPrefetch,
    required this.onSelectSuggestion,
    required this.onExpandSheet,
    required this.isPrefetching,
    required this.prefetchedProducts,
  });

  @override
  State<VSResultsSheet> createState() => _VSResultsSheetState();
}

class _VSResultsSheetState extends State<VSResultsSheet> {
  int _previousSelectedIndex = -1;
  
  @override
  void initState() {
    super.initState();
    _previousSelectedIndex = widget.selectedSuggestionIndex;
  }
  
  @override
  void didUpdateWidget(covariant VSResultsSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // When a new suggestion is selected, scroll products to top
    if (widget.selectedSuggestionIndex != oldWidget.selectedSuggestionIndex) {
      _previousSelectedIndex = widget.selectedSuggestionIndex;
      
      // Scroll products to top when suggestion changes
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && widget.scrollController.hasClients) {
          widget.scrollController.jumpTo(0); // Jump instead of animate to avoid scroll notifications
        }
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final hasSuggestions = widget.detectionResult != null && widget.detectionResult!.suggestions.length > 1;
    final secondaryColor = widget.isDark ? Colors.grey[400]! : Colors.grey[600]!;
    
    return Container(
      decoration: BoxDecoration(
        color: widget.isDark ? const Color(0xFF121212) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2), 
            blurRadius: 20, 
            offset: const Offset(0, -4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          final metrics = notification.metrics;
          
          // Handle pagination - only for products (suggestions stay visible at top)
          if (metrics.maxScrollExtent > 0 && widget.products.isNotEmpty) {
            final pct = (metrics.pixels / metrics.maxScrollExtent * 100).clamp(0, 100);
            if (pct >= 50 && pct < 75 && !widget.isPrefetching && !widget.isLoadingMore && widget.hasMorePages && widget.prefetchedProducts.isEmpty) {
              widget.onPrefetch();
            }
            if (pct >= 75) widget.onLoadMore();
          }
          return false;
        },
        child: CustomScrollView(
          controller: widget.scrollController,
          slivers: [
            // Drag handle - part of the scrollview so whole surface drags the sheet
            SliverToBoxAdapter(
              child: GestureDetector(
                onTap: widget.onExpandSheet,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Container(
                        width: 40, 
                        height: 4,
                        decoration: BoxDecoration(
                          color: widget.isDark ? Colors.grey[600] : Colors.grey[400], 
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      if (widget.hasResults && widget.products.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.keyboard_arrow_up_rounded, size: 18, color: secondaryColor),
                              Text(
                                '${widget.totalProducts} results',
                                style: TextStyle(fontSize: 12, color: secondaryColor, fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Suggestions row - ALWAYS visible when there are suggestions (pinned at top)
            // This should never hide when loading new suggestion results
            if (hasSuggestions)
              SliverToBoxAdapter(
                child: Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: widget.isDark ? const Color(0xFF121212) : Colors.white,
                  ),
                  child: VSSuggestionsRow(
                    suggestions: widget.detectionResult!.suggestions,
                    selectedIndex: widget.selectedSuggestionIndex,
                    isSearching: widget.isSearching,
                    onSelect: widget.onSelectSuggestion,
                    inSheet: true,
                    isDark: widget.isDark,
                  ),
                ),
              ),
            
            // Content slivers (products grid, empty states, etc.)
            ..._buildContentSlivers(context, hasSuggestions, secondaryColor, bottomPadding),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildContentSlivers(
    BuildContext context, 
    bool hasSuggestions, 
    Color secondaryColor, 
    double bottomPadding,
  ) {
    // Empty state - no search done yet
    if (!widget.hasResults && !widget.isSearching) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.camera, size: 48, color: secondaryColor),
                const SizedBox(height: 12),
                Text('Point at a product & tap search', style: TextStyle(color: secondaryColor, fontSize: 14)),
              ],
            ),
          ),
        ),
      ];
    }

    // Loading skeleton
    if (widget.isSearching && widget.products.isEmpty) {
      return [
        SliverPadding(
          padding: EdgeInsets.only(left: 12, right: 12, bottom: bottomPadding),
          sliver: SliverMasonryGrid.count(
            crossAxisCount: 2,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            childCount: 6,
            itemBuilder: (_, __) => _SkeletonCard(isDark: widget.isDark),
          ),
        ),
      ];
    }

    // No results found
    if (widget.products.isEmpty && widget.hasResults) {
      return [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Iconsax.search_normal, size: 48, color: secondaryColor),
                const SizedBox(height: 12),
                Text('No products found', style: TextStyle(color: secondaryColor, fontSize: 14)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: widget.onStartNewSearch,
                  icon: const Icon(Iconsax.refresh),
                  label: const Text('New Search'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary500, foregroundColor: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ];
    }

    // Products with results
    return [
      // Header row with actions
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Text(
                '${widget.totalProducts} results',
                style: TextStyle(fontSize: 13, color: secondaryColor, fontWeight: FontWeight.w500),
              ),
              const Spacer(),
              _ActionChip(icon: Iconsax.camera, label: 'New Search', onTap: widget.onStartNewSearch, isDark: widget.isDark),
              const SizedBox(width: 8),
              _ActionChip(icon: Iconsax.filter, label: 'Filter', isActive: widget.filterState.hasActiveFilters, onTap: widget.onShowFilter, isDark: widget.isDark),
            ],
          ),
        ),
      ),
      
      // Active filter chips
      if (widget.filterState.hasActiveFilters)
        SliverToBoxAdapter(
          child: SizedBox(
            height: 32,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                if (widget.filterState.sortBy != ProductSortOption.newest)
                  _FilterChip(label: widget.filterState.sortBy.displayName, onRemove: () => widget.onApplyFilter(widget.filterState.copyWith(sortBy: ProductSortOption.newest)), isDark: widget.isDark),
                if (widget.filterState.minPrice != null)
                  _FilterChip(label: 'Min: \$${widget.filterState.minPrice!.toInt()}', onRemove: () => widget.onApplyFilter(widget.filterState.copyWith(clearMinPrice: true)), isDark: widget.isDark),
                if (widget.filterState.maxPrice != null)
                  _FilterChip(label: 'Max: \$${widget.filterState.maxPrice!.toInt()}', onRemove: () => widget.onApplyFilter(widget.filterState.copyWith(clearMaxPrice: true)), isDark: widget.isDark),
              ],
            ),
          ),
        ),
      
      // Products Grid
      SliverPadding(
        padding: EdgeInsets.only(left: 12, right: 12, top: 8, bottom: bottomPadding + 20),
        sliver: SliverMasonryGrid.count(
          crossAxisCount: 2,
          mainAxisSpacing: 4,
          crossAxisSpacing: 4,
          childCount: widget.products.length + (widget.isLoadingMore ? 2 : 0),
          itemBuilder: (context, index) {
            if (index >= widget.products.length) {
              return _SkeletonCard(isDark: widget.isDark);
            }
            final product = widget.products[index];
            
            // Precache images
            if (product.mainImage.isNotEmpty && product.mainImage.startsWith('http')) {
              precacheImage(CachedNetworkImageProvider(product.mainImage), context);
            }
            if (product.images != null) {
              for (final img in product.images!) {
                if (img.isNotEmpty && img.startsWith('http')) {
                  precacheImage(CachedNetworkImageProvider(img), context);
                }
              }
            }
            
            return RepaintBoundary(
              child: ProductCard.fromProduct(
                product,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetailsScreen(product: product))),
              ),
            );
          },
        ),
      ),
    ];
  }
}

// ============ Helper Widgets ============

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;
  final bool isDark;

  const _ActionChip({
    required this.icon, 
    required this.label, 
    required this.onTap, 
    this.isActive = false, 
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive 
        ? AppColors.primary500 
        : (isDark ? Colors.white : Colors.black87);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          border: Border.all(
            color: isActive 
                ? AppColors.primary500 
                : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
          ),
          borderRadius: BorderRadius.circular(8),
          color: isActive ? AppColors.primary500.withOpacity(0.1) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;
  final bool isDark;

  const _FilterChip({
    required this.label, 
    required this.onRemove, 
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary500.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.primary500.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label, 
            style: const TextStyle(
              fontSize: 11, 
              color: AppColors.primary500, 
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close, size: 14, color: AppColors.primary500),
          ),
        ],
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final bool isDark;

  const _SkeletonCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset(
        'assets/images/productfailbackorskeleton_loading.png',
        fit: BoxFit.cover,
      ),
    );
  }
}

// ============ Painters ============

class ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final cx = size.width / 2;
    final cy = size.height / 2 - 80;
    final boxSize = size.width * 0.72;
    final half = boxSize / 2;
    const corner = 28.0;

    // Top-left corner
    canvas.drawLine(Offset(cx - half, cy - half), Offset(cx - half + corner, cy - half), paint);
    canvas.drawLine(Offset(cx - half, cy - half), Offset(cx - half, cy - half + corner), paint);
    
    // Top-right corner
    canvas.drawLine(Offset(cx + half, cy - half), Offset(cx + half - corner, cy - half), paint);
    canvas.drawLine(Offset(cx + half, cy - half), Offset(cx + half, cy - half + corner), paint);
    
    // Bottom-left corner
    canvas.drawLine(Offset(cx - half, cy + half), Offset(cx - half + corner, cy + half), paint);
    canvas.drawLine(Offset(cx - half, cy + half), Offset(cx - half, cy + half - corner), paint);
    
    // Bottom-right corner
    canvas.drawLine(Offset(cx + half, cy + half), Offset(cx + half - corner, cy + half), paint);
    canvas.drawLine(Offset(cx + half, cy + half), Offset(cx + half, cy + half - corner), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class ScanLinePainter extends CustomPainter {
  final double progress;
  final bool fullScreen;
  
  ScanLinePainter(this.progress, {this.fullScreen = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (fullScreen) {
      // Full screen scan - covers the entire image area
      // Use horizontal padding for better visual appearance
      final padding = size.width * 0.05;
      final scanWidth = size.width - (padding * 2);
      final y = size.height * progress;

      // Draw the scan line
      final paint = Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.transparent, 
            Colors.white.withOpacity(0.8), 
            Colors.white.withOpacity(0.9),
            Colors.white.withOpacity(0.8), 
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ).createShader(Rect.fromLTWH(padding, y - 3, scanWidth, 6));

      canvas.drawRect(Rect.fromLTWH(padding, y - 3, scanWidth, 6), paint);
      
      // Draw a subtle glow effect above the scan line
      final glowPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.transparent,
            AppColors.primary500.withOpacity(0.15),
            AppColors.primary500.withOpacity(0.05),
            Colors.transparent,
          ],
          stops: const [0.0, 0.5, 0.8, 1.0],
        ).createShader(Rect.fromLTWH(padding, y - 60, scanWidth, 60));
      
      canvas.drawRect(Rect.fromLTWH(padding, y - 60, scanWidth, 60), glowPaint);
    } else {
      // Viewfinder mode - centered box (original behavior)
      final cx = size.width / 2;
      final cy = size.height / 2 - 80;
      final boxSize = size.width * 0.72;
      final half = boxSize / 2;
      final y = cy - half + (boxSize * progress);

      final paint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.transparent, Colors.white.withOpacity(0.7), Colors.transparent],
        ).createShader(Rect.fromLTWH(cx - half, y - 2, boxSize, 4));

      canvas.drawRect(Rect.fromLTWH(cx - half, y - 2, boxSize, 4), paint);
    }
  }

  @override
  bool shouldRepaint(covariant ScanLinePainter old) => old.progress != progress || old.fullScreen != fullScreen;
}
