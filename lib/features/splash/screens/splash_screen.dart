import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
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
    
    // TEMPORARILY HARDCODED: Use local video asset instead of fetching from server
    _splashAd = SplashAdModel(
      id: 0,
      title: 'ChiHelo Intro',
      mediaType: 'video',
      mediaUrl: 'assets/animations/vidforchihelo.mp4', // Local asset
      linkType: 'none',
      skipDuration: 3,
      totalDuration: 10,
    );
    
    debugPrint('✅ Splash ad ready (using local video)');

    if (!mounted) return;

    // Wait for first frame to complete before navigating
    // This prevents the "!_debugLocked" assertion error
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      // Let the Lottie animation play for a moment (1.5 seconds)
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!mounted) return;
      
      // Navigate to video IMMEDIATELY - don't wait for home data!
      // Home data will load in background while video plays
      _showSplashAd();
      
      // Start loading home data in background (non-blocking)
      // This runs while the video is playing
      homeService.fetchHomeData().then((_) {
        debugPrint('✅ Home data loaded in background during video playback');
      }).catchError((e) {
        debugPrint('⚠️ Home data preload error (non-blocking): $e');
      });
    });
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
        transitionDuration: const Duration(milliseconds: 150), // Faster transition
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

    // Animated splash screen - shows briefly while setting up video screen
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF),
      body: Center(
        child: Lottie.asset(
          'assets/animations/ChiBox logo animation.json',
          width: 200,
          height: 200,
          fit: BoxFit.contain,
          repeat: false, // Don't repeat - we navigate immediately
        ),
      ),
    );
  }
}
