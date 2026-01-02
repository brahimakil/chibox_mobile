import 'package:flutter/material.dart';
import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/home_data_model.dart' show GridElement;
import '../../../core/utils/image_helper.dart';

/// SHEIN-style Full Width Banner Carousel
class FullWidthBannerCarousel extends StatefulWidget {
  final List<dynamic> elements;
  final PageController pageController;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;
  final double height;

  const FullWidthBannerCarousel({
    super.key,
    required this.elements,
    required this.pageController,
    required this.currentIndex,
    required this.onIndexChanged,
    required this.height,
  });

  @override
  State<FullWidthBannerCarousel> createState() => _FullWidthBannerCarouselState();
}

class _FullWidthBannerCarouselState extends State<FullWidthBannerCarousel> {
  Timer? _autoPlayTimer;

  @override
  void initState() {
    super.initState();
    _startAutoPlay();
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    super.dispose();
  }

  void _startAutoPlay() {
    _autoPlayTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (!mounted) return;
      if (widget.elements.isEmpty) return;
      final nextPage = (widget.currentIndex + 1) % widget.elements.length;
      widget.pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.elements.isEmpty) {
      return SizedBox(height: widget.height);
    }

    return Stack(
      children: [
        // Full-width PageView banner
        PageView.builder(
          controller: widget.pageController,
          itemCount: widget.elements.length,
          onPageChanged: widget.onIndexChanged,
          itemBuilder: (context, index) {
            final element = widget.elements[index];
            final imageUrl = element is GridElement
                ? element.imageUrl
                : (element as dynamic).imageUrl ?? '';
            
            return Container(
              width: double.infinity,
              height: widget.height,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.3),
                    Colors.transparent,
                    Colors.black.withOpacity(0.5),
                  ],
                ),
              ),
              child: CachedNetworkImage(
                imageUrl: ImageHelper.parse(imageUrl) ?? '',
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  color: AppColors.neutral100,
                  child: const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary500,
                    ),
                  ),
                ),
                errorWidget: (context, url, error) => Container(
                  color: AppColors.neutral100,
                  child: const Icon(Iconsax.image, size: 48, color: AppColors.neutral400),
                ),
              ),
            );
          },
        ),
        
        // Gradient overlay at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withOpacity(0.6),
                ],
              ),
            ),
          ),
        ),

        // Page Indicator
        Positioned(
          bottom: 16,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedSmoothIndicator(
              activeIndex: widget.currentIndex,
              count: widget.elements.length,
              effect: const ExpandingDotsEffect(
                dotHeight: 6,
                dotWidth: 6,
                activeDotColor: Colors.white,
                dotColor: Colors.white54,
                spacing: 6,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
