import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    
    // PRIORITY 1: Fetch SPLASH AD FIRST (fast, small request)
    // Home data loads in BACKGROUND while splash ad is showing
    _splashAd = await _splashAdService.getActiveSplashAd();
    
    debugPrint('✅ Splash ad check complete: ${_splashAd != null ? "YES" : "NO"}');

    if (!mounted) return;

    // If splash ad exists, show it IMMEDIATELY (image loads inside the screen)
    // Start home data fetch in background
    if (_splashAd != null) {
      // Start home data loading in background (don't wait)
      homeService.fetchHomeData().then((_) {
        debugPrint('✅ Home data loaded in background!');
      });
      
      _showSplashAd();
    } else {
      // No splash ad - wait for home data then go to home
      await homeService.fetchHomeData();
      if (!mounted) return;
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

    // Minimal loading screen while fetching splash ad from database
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      body: const SizedBox.shrink(), // Empty body - just wait for splash ad
    );
  }
}
