import 'dart:async';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:chihelo_frontend/core/models/splash_ad_model.dart';
import 'package:chihelo_frontend/core/services/splash_ad_service.dart';
import 'package:chihelo_frontend/core/services/category_service.dart';
import 'package:chihelo_frontend/core/services/cart_service.dart';
import 'package:chihelo_frontend/core/services/wishlist_service.dart';
import 'package:chihelo_frontend/core/services/notification_service.dart';
import 'package:chihelo_frontend/core/theme/theme.dart';
import 'package:chihelo_frontend/main.dart';
import 'package:video_player/video_player.dart';
import 'package:lottie/lottie.dart';

class SplashAdScreen extends StatefulWidget {
  final SplashAdModel ad;

  const SplashAdScreen({
    super.key,
    required this.ad,
  });

  @override
  State<SplashAdScreen> createState() => _SplashAdScreenState();
}

class _SplashAdScreenState extends State<SplashAdScreen> with SingleTickerProviderStateMixin {
  final SplashAdService _splashAdService = SplashAdService();
  
  late int _skipCountdown;
  Timer? _skipTimer;
  bool _canSkip = false;
  bool _isCompleted = false;
  
  // Smooth progress animation
  late AnimationController _progressController;
  
  VideoPlayerController? _videoController;
  bool _videoInitialized = false;

  @override
  void initState() {
    super.initState();
    // Skip countdown - 3 seconds (user can skip immediately by pressing Skip button)
    _skipCountdown = 3;
    _canSkip = true; // Allow immediate skip
    
    // Initialize smooth progress animation (minimum 3 seconds)
    final displayDuration = widget.ad.totalDuration < 3 ? 3 : widget.ad.totalDuration;
    _progressController = AnimationController(
      vsync: this,
      duration: Duration(seconds: displayDuration),
    );
    
    // Track view
    _splashAdService.trackView(widget.ad.id);
    
    // Initialize video if needed
    if (widget.ad.isVideo) {
      _initializeVideo();
    }
    
    // Start animations and timers
    _startProgress();
    _startSkipTimer();
  }

  void _startProgress() {
    _progressController.forward();
    _progressController.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_isCompleted) {
        _autoComplete();
      }
    });
  }

  void _startSkipTimer() {
    _skipTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        if (_skipCountdown > 0) {
          _skipCountdown--;
          if (_skipCountdown == 0) {
            _canSkip = true;
            timer.cancel();
          }
        }
      });
    });
  }

  void _initializeVideo() async {
    // TEMPORARILY MODIFIED: Check if using local asset
    final isLocalAsset = widget.ad.mediaUrl.startsWith('assets/');
    String? cachedPath;
    
    if (isLocalAsset) {
      // Use local asset video
      debugPrint('🎬 Playing from local asset: ${widget.ad.mediaUrl}');
      _videoController = VideoPlayerController.asset(widget.ad.mediaUrl);
    } else {
      // Try to use cached video first for instant playback
      cachedPath = await _splashAdService.getCachedVideoPath(widget.ad.mediaUrl);
      
      if (cachedPath != null) {
        // Use cached local file - instant playback!
        debugPrint('🎬 Playing from cache: $cachedPath');
        _videoController = VideoPlayerController.file(File(cachedPath));
      } else {
        // Fallback to network (and cache in background for next time)
        debugPrint('🎬 Playing from network: ${widget.ad.mediaUrl}');
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.ad.mediaUrl),
        );
        // Cache for next time
        _splashAdService.downloadAndCacheVideo(widget.ad.mediaUrl);
      }
    }
    
    try {
      await _videoController!.initialize();
      await _videoController!.setLooping(false);
      await _videoController!.play();
      
      if (mounted) {
        setState(() {
          _videoInitialized = true;
        });
      }
    } catch (e) {
      debugPrint('Error initializing video: $e');
      // If cached file fails, try network (only for non-local assets)
      if (!isLocalAsset && cachedPath != null) {
        debugPrint('🎬 Cache failed, trying network...');
        _videoController?.dispose();
        _videoController = VideoPlayerController.networkUrl(
          Uri.parse(widget.ad.mediaUrl),
        );
        try {
          await _videoController!.initialize();
          await _videoController!.setLooping(false);
          await _videoController!.play();
          if (mounted) {
            setState(() {
              _videoInitialized = true;
            });
          }
        } catch (e2) {
          debugPrint('Network video also failed: $e2');
        }
      }
    }
  }

  void _autoComplete() {
    if (_isCompleted) return;
    _isCompleted = true;
    _skipTimer?.cancel();
    _progressController.stop();
    _videoController?.pause();
    _navigateToHome();
  }

  void _handleSkip() {
    if (_isCompleted) return;
    _isCompleted = true;
    _skipTimer?.cancel();
    _progressController.stop();
    _videoController?.pause();
    
    // Track skip
    _splashAdService.trackSkip(widget.ad.id);
    
    _navigateToHome();
  }

  void _handleTap() {
    // Allow tap to navigate immediately
    if (_isCompleted) return;
    
    _isCompleted = true;
    _skipTimer?.cancel();
    _progressController.stop();
    _videoController?.pause();
    
    // Track click if has link, otherwise track skip
    if (widget.ad.hasLink) {
      _splashAdService.trackClick(widget.ad.id);
      debugPrint('📱 Ad tapped: ${widget.ad.linkType} -> ${widget.ad.linkValue}');
    } else {
      _splashAdService.trackSkip(widget.ad.id);
    }
    
    _navigateToHome();
  }

  void _navigateToHome() {
    if (!mounted) return;
    
    // Load secondary data in background
    _loadSecondaryData();
    
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AppWrapper(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  Future<void> _loadSecondaryData() async {
    try {
      final categoryService = context.read<CategoryService>();
      final cartService = context.read<CartService>();
      final wishlistService = context.read<WishlistService>();
      final notificationService = context.read<NotificationService>();
      
      // Fire and forget - don't await
      Future.wait([
        categoryService.fetchCategories(),
        cartService.fetchCart(silent: true),
        wishlistService.fetchBoards(silent: true),
        notificationService.getUnreadCount(),
      ], eagerError: false).then((_) {
        debugPrint('✅ Secondary data loaded in background!');
      }).catchError((e) {
        debugPrint('⚠️ Secondary preload error (non-blocking): $e');
      });
    } catch (e) {
      debugPrint('⚠️ Secondary preload error: $e');
    }
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _progressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? Colors.black : Colors.white;
    
    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Media Content
          GestureDetector(
            onTap: _handleTap,
            behavior: HitTestBehavior.opaque,
            child: _buildMediaContent(isDark),
          ),
          
          // Skip Button (Top Right)
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: _buildSkipButton(isDark),
          ),
          
          // Progress Indicator (Bottom)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildProgressIndicator(isDark),
          ),
          
          // Tap to explore hint (if has link)
          // TEMPORARILY DISABLED: Hiding tap to explore button
          // if (widget.ad.hasLink)
          //   Positioned(
          //     bottom: MediaQuery.of(context).padding.bottom + 60,
          //     left: 0,
          //     right: 0,
          //     child: _buildTapHint(isDark),
          //   ),
        ],
      ),
    );
  }

  Widget _buildMediaContent(bool isDark) {
    if (widget.ad.isVideo) {
      return _buildVideoContent(isDark);
    } else if (widget.ad.isLottie) {
      return _buildLottieContent(isDark);
    } else {
      return _buildImageContent(isDark);
    }
  }

  Widget _buildImageContent(bool isDark) {
    final backgroundColor = isDark ? Colors.black : Colors.white;
    
    return Container(
      color: backgroundColor,
      alignment: Alignment.center,
      child: CachedNetworkImage(
        imageUrl: widget.ad.mediaUrl,
        fit: BoxFit.fitWidth,
        width: double.infinity,
        // Fast fade for smooth appearance
        fadeInDuration: const Duration(milliseconds: 150),
        fadeOutDuration: Duration.zero,
        placeholder: (context, url) => Container(
          color: backgroundColor,
          // Show brand color shimmer while loading
          child: Center(
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primary500.withOpacity(0.7),
                ),
              ),
            ),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: backgroundColor,
          child: Center(
            child: Icon(
              Icons.error_outline,
              color: isDark ? Colors.white54 : Colors.black38,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVideoContent(bool isDark) {
    final backgroundColor = isDark ? Colors.black : Colors.white;
    
    if (!_videoInitialized || _videoController == null) {
      // Show thumbnail while video loads
      if (widget.ad.thumbnailUrl != null) {
        return Container(
          color: backgroundColor,
          child: CachedNetworkImage(
            imageUrl: widget.ad.thumbnailUrl!,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => _buildLoadingPlaceholder(isDark),
            errorWidget: (context, url, error) => _buildLoadingPlaceholder(isDark),
          ),
        );
      }
      return _buildLoadingPlaceholder(isDark);
    }
    
    // Video fills the screen
    return Container(
      color: backgroundColor,
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: _videoController!.value.size.width,
          height: _videoController!.value.size.height,
          child: VideoPlayer(_videoController!),
        ),
      ),
    );
  }

  Widget _buildLottieContent(bool isDark) {
    final backgroundColor = isDark ? Colors.black : Colors.white;
    
    return Container(
      color: backgroundColor,
      child: Lottie.network(
        widget.ad.mediaUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        repeat: true,
        errorBuilder: (context, error, stackTrace) {
          return _buildLoadingPlaceholder(isDark);
        },
      ),
    );
  }

  Widget _buildLoadingPlaceholder(bool isDark) {
    final backgroundColor = isDark ? Colors.black : Colors.white;
    
    return Container(
      color: backgroundColor,
      child: const Center(
        child: CircularProgressIndicator(
          color: AppColors.primary500,
          strokeWidth: 2,
        ),
      ),
    );
  }

  Widget _buildSkipButton(bool isDark) {
    final buttonBg = isDark ? Colors.black.withOpacity(0.6) : Colors.white.withOpacity(0.9);
    final borderColor = isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.2);
    final textColor = isDark ? Colors.white : Colors.black87;
    
    return GestureDetector(
      onTap: _canSkip ? _handleSkip : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: buttonBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: borderColor,
            width: 1,
          ),
          boxShadow: isDark ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Skip',
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: textColor,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(bool isDark) {
    final trackColor = isDark ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.1);
    
    return AnimatedBuilder(
      animation: _progressController,
      builder: (context, child) {
        return Container(
          height: 3,
          color: trackColor,
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: _progressController.value,
            child: Container(
              color: AppColors.primary500,
            ),
          ),
        );
      },
    );
  }

  Widget _buildTapHint(bool isDark) {
    final hintBg = isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.9);
    final hintColor = isDark ? Colors.white.withOpacity(0.9) : Colors.black87;
    
    return Center(
      child: GestureDetector(
        onTap: _handleTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: hintBg,
            borderRadius: BorderRadius.circular(25),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.touch_app,
                color: hintColor,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Tap to explore',
                style: TextStyle(
                  color: hintColor,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
