import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/models/home_data_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/cards/product_card.dart';
import '../../../shared/widgets/common/section_header.dart';
import '../../product/screens/product_details_screen.dart';
import '../screens/flash_sale_products_screen.dart';

class FlashSaleSection extends StatelessWidget {
  final FlashSale flashSale;

  const FlashSaleSection({
    super.key,
    required this.flashSale,
  });

  Color _parseColor(String? hexColor, Color defaultColor) {
    if (hexColor == null || hexColor.isEmpty) return defaultColor;
    try {
      return Color(int.parse(hexColor.replaceAll('#', '0xFF')));
    } catch (_) {
      return defaultColor;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (flashSale.products.isEmpty) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Parse colors from backend or use defaults
    final bgGradientStart = _parseColor(flashSale.color1, isDark ? AppColors.primary900 : AppColors.primary50);
    final bgGradientEnd = _parseColor(flashSale.color2, isDark ? AppColors.neutral900 : Colors.white);
    final accentColor = _parseColor(flashSale.color3, AppColors.primary500);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bgGradientStart, bgGradientEnd],
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.5) 
                : Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(AppSpacing.base),
            child: Row(
              children: [
                // Title & Icon
                Icon(Iconsax.flash_15, color: accentColor, size: 24)
                    .animate(onPlay: (c) => c.repeat())
                    .shimmer(duration: 1500.ms, color: Colors.white),
                AppSpacing.horizontalSm,
                Text(
                  flashSale.title,
                  style: AppTypography.headingSmall(
                    color: accentColor,
                  ).copyWith(fontWeight: FontWeight.w800, fontStyle: FontStyle.italic),
                ),
                
                const Spacer(),
                
                // Countdown
                _FlashSaleTimer(endTime: flashSale.endTime, color: accentColor),
                
                AppSpacing.horizontalSm,
                
                // See All
                SectionAction(
                  text: 'See All',
                  icon: Iconsax.arrow_right_3,
                  color: accentColor,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FlashSaleProductsScreen(flashSale: flashSale),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Products List
          if (flashSale.sliderType?.toLowerCase() == 'swiper' || flashSale.sliderType == '2')
            _buildSwiperLayout(context)
          else
            _buildStandardLayout(context),
        ],
      ),
    );
  }

  Widget _buildStandardLayout(BuildContext context) {
    return SizedBox(
      height: 280, // Compact height for cards
      child: ListView.separated(
        padding: const EdgeInsets.only(left: AppSpacing.base, right: AppSpacing.base, bottom: 8),
        scrollDirection: Axis.horizontal,
        itemCount: flashSale.products.length,
        separatorBuilder: (context, index) => AppSpacing.horizontalMd,
        itemBuilder: (context, index) {
          final product = flashSale.products[index];
          return SizedBox(
            width: 160,
            child: ProductCard.fromProduct(
              product,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(product: product),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSwiperLayout(BuildContext context) {
    // A more prominent, larger card layout for "swiper" type
    return SizedBox(
      height: 320,
      child: PageView.builder(
        controller: PageController(viewportFraction: 0.85),
        padEnds: false,
        itemCount: flashSale.products.length,
        itemBuilder: (context, index) {
          final product = flashSale.products[index];
          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: ProductCard.fromProduct(
              product,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ProductDetailsScreen(product: product),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FlashSaleTimer extends StatefulWidget {
  final DateTime endTime;
  final Color color;

  const _FlashSaleTimer({
    required this.endTime,
    required this.color,
  });

  @override
  State<_FlashSaleTimer> createState() => _FlashSaleTimerState();
}

class _FlashSaleTimerState extends State<_FlashSaleTimer> {
  late Timer _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    if (now.isAfter(widget.endTime)) {
      _remaining = Duration.zero;
      _timer.cancel();
    } else {
      setState(() {
        _remaining = widget.endTime.difference(now);
      });
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_remaining == Duration.zero) return const SizedBox.shrink();

    return Row(
      children: [
        _buildTimeBox(_remaining.inHours.toString().padLeft(2, '0')),
        _buildSeparator(),
        _buildTimeBox((_remaining.inMinutes % 60).toString().padLeft(2, '0')),
        _buildSeparator(),
        _buildTimeBox((_remaining.inSeconds % 60).toString().padLeft(2, '0')),
      ],
    );
  }

  Widget _buildTimeBox(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: widget.color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildSeparator() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Text(
        ':',
        style: TextStyle(
          color: widget.color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
