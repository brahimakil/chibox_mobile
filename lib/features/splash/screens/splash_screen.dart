import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/wishlist_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/splash_ad_service.dart';
import '../../../core/models/splash_ad_model.dart';
import '../../../main.dart';
import 'splash_ad_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  SplashAdModel? _splashAd;
  final SplashAdService _splashAdService = SplashAdService();
  
  // Store services before navigation to avoid context issues
  late CategoryService _categoryService;
  late CartService _cartService;
  late WishlistService _wishlistService;
  late NotificationService _notificationService;
  
  @override
  void initState() {
    super.initState();
    _preloadAndNavigate();
  }

  Future<void> _preloadAndNavigate() async {
    debugPrint('🚀 Starting splash preload...');
    
    // Get services from context and store them BEFORE any navigation
    final homeService = context.read<HomeService>();
    _categoryService = context.read<CategoryService>();
    _cartService = context.read<CartService>();
    _wishlistService = context.read<WishlistService>();
    _notificationService = context.read<NotificationService>();
    
    // PRIORITY 1: Fetch HOME DATA and SPLASH AD simultaneously
    final homeDataFuture = homeService.fetchHomeData();
    final splashAdFuture = _splashAdService.getActiveSplashAd();
    final minSplashFuture = Future.delayed(const Duration(milliseconds: 1200));
    
    // Wait for ALL: home data, splash ad check, AND minimum splash time
    final results = await Future.wait([
      homeDataFuture,
      splashAdFuture,
      minSplashFuture,
    ]);
    
    // Get splash ad result
    _splashAd = results[1] as SplashAdModel?;
    
    debugPrint('✅ Home data loaded! Splash ad: ${_splashAd != null ? "YES" : "NO"}');

    if (!mounted) return;

    // If splash ad exists, show it first
    if (_splashAd != null) {
      _showSplashAd();
    } else {
      _navigateToHome();
    }
  }

  void _showSplashAd() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => SplashAdScreen(
          ad: _splashAd!,
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AppWrapper(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
    
    // PRIORITY 2: Load secondary data AFTER navigation (non-blocking background)
    _loadSecondaryData();
  }

  /// Load secondary data in background after home is shown
  /// Uses stored service references to avoid context issues after navigation
  Future<void> _loadSecondaryData() async {
    try {
      // These load in background - user already sees home screen
      // Using stored references instead of context.read to avoid unmounted widget errors
      await Future.wait([
        _categoryService.fetchCategories(),
        _cartService.fetchCart(silent: true),
        _wishlistService.fetchBoards(silent: true),
        _notificationService.getUnreadCount(),
      ], eagerError: false);
      
      debugPrint('✅ Secondary data loaded in background!');
    } catch (e) {
      debugPrint('⚠️ Secondary preload error (non-blocking): $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [const Color(0xFF1A1A1A), const Color(0xFF000000)]
                : [const Color(0xFFFFFFFF), const Color(0xFFFFF8F0)],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background Glow (Top Right)
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary500.withOpacity(isDark ? 0.15 : 0.1),
                ),
              ).animate().scale(duration: 2.seconds, curve: Curves.easeInOut).blur(begin: const Offset(60, 60), end: const Offset(60, 60)),
            ),
            
            // Background Glow (Bottom Left)
            Positioned(
              bottom: -50,
              left: -50,
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary500.withOpacity(isDark ? 0.1 : 0.05),
                ),
              ).animate().scale(delay: 500.ms, duration: 2.seconds, curve: Curves.easeInOut).blur(begin: const Offset(60, 60), end: const Offset(60, 60)),
            ),

            // Center Logo
            Center(
              child: Image.asset(
                'assets/images/applogo.png',
                width: size.width * 0.5,
                fit: BoxFit.contain,
              )
              .animate()
              .fadeIn(duration: 800.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 800.ms, curve: Curves.easeOutBack),
            ),

            // Bottom Branding
            Positioned(
              bottom: AppSpacing.xxl, // Moved up slightly
              left: 0,
              right: 0,
              child: Center(
                child: Image.asset(
                  isDark
                      ? 'assets/images/bottom_of_the_loading_screen_darkmode.png'
                      : 'assets/images/bottom_of_the_loading_screen_lightmode.png',
                  width: size.width * 0.5, // Increased size
                  fit: BoxFit.contain,
                )
                .animate()
                .fadeIn(delay: 400.ms, duration: 600.ms)
                .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOut),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
