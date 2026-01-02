import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToNext();
  }

  Future<void> _navigateToNext() async {
    // Minimum splash duration
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const AppWrapper(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
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
                isDark
                    ? 'assets/images/logo splash screen white text 960x960.png'
                    : 'assets/images/logo splash screen dark text 960x960.png',
                width: size.width * 0.85, // Increased size significantly
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
