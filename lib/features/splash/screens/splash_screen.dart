import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lottie/lottie.dart';
import '../../../core/services/home_service.dart';
import '../../../core/services/category_service.dart';
import '../../../core/services/cart_service.dart';
import '../../../core/services/wishlist_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/splash_ad_service.dart';
import '../../../core/services/fcm_service.dart';
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
  bool _isReady = false; // true once splash ad media is ready to show
  
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
    // Get services from context and store them BEFORE any navigation
    final homeService = context.read<HomeService>();
    _categoryService = context.read<CategoryService>();
    _cartService = context.read<CartService>();
    _wishlistService = context.read<WishlistService>();
    _notificationService = context.read<NotificationService>();
    
    // Try to fetch active splash ad from the server
    try {
      final serverAd = await _splashAdService.getActiveSplashAd();
      if (serverAd != null) {
        _splashAd = serverAd;
      }
    } catch (_) {
      // No server ad — will skip splash ad screen entirely
    }

    if (!mounted) return;

    // Pre-buffer video ads BEFORE leaving the logo screen
    if (_splashAd != null && _splashAd!.isVideo && !_splashAd!.mediaUrl.startsWith('assets/')) {
      try {
        final cachedPath = await _splashAdService.getCachedVideoPath(_splashAd!.mediaUrl);
        if (cachedPath == null) {
          await _splashAdService.downloadAndCacheVideo(_splashAd!.mediaUrl);
        }
      } catch (_) {
        // If pre-cache fails, still proceed — SplashAdScreen will handle it
      }
    }

    if (!mounted) return;
    _isReady = true;

    // Wait for first frame to complete before navigating
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      
      // If the app was opened from a push notification tap,
      // skip everything and go straight to the app.
      if (FcmService().pendingNotificationData != null) {
        _navigateToHome();
        homeService.fetchHomeData().catchError((e) {});
        return;
      }
      
      // Let the Lottie animation play for a minimum of 1.5 seconds
      await Future.delayed(const Duration(milliseconds: 1500));
      
      if (!mounted) return;
      
      // If we have a server splash ad, show it; otherwise go straight to app
      if (_splashAd != null) {
        _showSplashAd();
      } else {
        _navigateToHome();
      }
      
      // Start loading home data in background
      homeService.fetchHomeData().catchError((e) {});
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
    } catch (e) {
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
          repeat: !_isReady, // Keep looping until media is ready
        ),
      ),
    );
  }
}
