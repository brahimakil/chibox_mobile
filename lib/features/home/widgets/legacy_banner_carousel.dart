import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/models/home_data_model.dart' show HomeBanner;
import '../../../shared/widgets/widgets.dart';

/// Legacy Banner Carousel using CarouselSlider
class LegacyBannerCarousel extends StatelessWidget {
  final List<HomeBanner> banners;
  final int currentIndex;
  final ValueChanged<int> onIndexChanged;

  const LegacyBannerCarousel({
    super.key,
    required this.banners,
    required this.currentIndex,
    required this.onIndexChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (banners.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        CarouselSlider.builder(
          itemCount: banners.length,
          options: CarouselOptions(
            height: 220,
            viewportFraction: 0.96,
            enlargeCenterPage: false,
            autoPlay: true,
            autoPlayInterval: const Duration(seconds: 5),
            onPageChanged: (index, _) => onIndexChanged(index),
          ),
          itemBuilder: (context, index, _) {
            final banner = banners[index];
            return BannerCard(
              imageUrl: banner.imageUrl,
              title: banner.title,
              subtitle: banner.subtitle,
              buttonText: banner.buttonText ?? 'Shop Now',
              onTap: () {},
            );
          },
        ),
        AppSpacing.verticalMd,
        AnimatedSmoothIndicator(
          activeIndex: currentIndex,
          count: banners.length,
          effect: ExpandingDotsEffect(
            dotHeight: 8,
            dotWidth: 8,
            activeDotColor: AppColors.primary500,
            dotColor: AppColors.neutral300,
            spacing: 6,
          ),
        ),
      ],
    );
  }
}
