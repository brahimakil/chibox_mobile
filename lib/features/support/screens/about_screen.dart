import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      body: CustomScrollView(
        slivers: [
          // App Bar with Hero Image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
            leading: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.3),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Gradient Background
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.primary500,
                          AppColors.primary700,
                          AppColors.primary900,
                        ],
                      ),
                    ),
                  ),
                  // Pattern Overlay
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _PatternPainter(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                  ),
                  // Content
                  Positioned(
                    bottom: 40,
                    left: 24,
                    right: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Iconsax.shopping_bag5,
                            size: 40,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'ChiHelo',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your Premium Shopping Destination',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // App Version Card
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Iconsax.mobile,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'App Version',
                                style: AppTypography.labelSmall(
                                  color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'v1.0.0 (Build 2026.01.03)',
                                style: AppTypography.labelLarge(
                                  color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'Latest',
                            style: TextStyle(
                              color: AppColors.success,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn().slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 24),

                  // Our Story Section
                  Text(
                    'Our Story',
                    style: AppTypography.headingSmall(
                      color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                    ),
                  ).animate().fadeIn(delay: 100.ms),
                  const SizedBox(height: 12),
                  Text(
                    'ChiHelo was founded with a simple mission: to make quality products accessible to everyone. We believe that shopping should be a seamless, enjoyable experience from browse to delivery.',
                    style: AppTypography.bodyMedium(
                      color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 150.ms),
                  const SizedBox(height: 12),
                  Text(
                    'Our curated selection brings together the best products from around the world, all carefully vetted to ensure the highest quality standards. Whether you\'re looking for everyday essentials or something special, we\'ve got you covered.',
                    style: AppTypography.bodyMedium(
                      color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                    ),
                  ).animate().fadeIn(delay: 200.ms),

                  const SizedBox(height: 32),

                  // Stats Grid
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Iconsax.box,
                          value: '10K+',
                          label: 'Products',
                          color: const Color(0xFF3B82F6),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Iconsax.people,
                          value: '50K+',
                          label: 'Customers',
                          color: const Color(0xFF10B981),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 250.ms).slideY(begin: 0.1, end: 0),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StatCard(
                          icon: Iconsax.global,
                          value: '25+',
                          label: 'Countries',
                          color: const Color(0xFF8B5CF6),
                          isDark: isDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatCard(
                          icon: Iconsax.star1,
                          value: '4.9',
                          label: 'Rating',
                          color: const Color(0xFFF59E0B),
                          isDark: isDark,
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1, end: 0),

                  const SizedBox(height: 32),

                  // Our Values Section
                  Text(
                    'Our Values',
                    style: AppTypography.headingSmall(
                      color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                    ),
                  ).animate().fadeIn(delay: 350.ms),
                  const SizedBox(height: 16),

                  _ValueCard(
                    icon: Iconsax.verify,
                    title: 'Quality First',
                    description: 'Every product goes through rigorous quality checks before reaching you.',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 12),

                  _ValueCard(
                    icon: Iconsax.heart,
                    title: 'Customer Love',
                    description: 'Your satisfaction is our priority. We\'re here to help 24/7.',
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                  ).animate().fadeIn(delay: 450.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 12),

                  _ValueCard(
                    icon: Iconsax.truck_fast,
                    title: 'Fast Delivery',
                    description: 'Get your orders delivered quickly and reliably, every time.',
                    color: const Color(0xFF3B82F6),
                    isDark: isDark,
                  ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1, end: 0),
                  const SizedBox(height: 12),

                  _ValueCard(
                    icon: Iconsax.shield_tick,
                    title: 'Secure Shopping',
                    description: 'Your data and payments are protected with enterprise-grade security.',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ).animate().fadeIn(delay: 550.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 32),

                  // Team Section
                  Text(
                    'Meet Our Team',
                    style: AppTypography.headingSmall(
                      color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                    ),
                  ).animate().fadeIn(delay: 600.ms),
                  const SizedBox(height: 16),

                  SizedBox(
                    height: 140,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _TeamMemberCard(
                          name: 'Alex Chen',
                          role: 'CEO & Founder',
                          isDark: isDark,
                        ),
                        _TeamMemberCard(
                          name: 'Sarah Johnson',
                          role: 'Head of Design',
                          isDark: isDark,
                        ),
                        _TeamMemberCard(
                          name: 'Mike Williams',
                          role: 'CTO',
                          isDark: isDark,
                        ),
                        _TeamMemberCard(
                          name: 'Emma Davis',
                          role: 'Customer Success',
                          isDark: isDark,
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 650.ms),

                  const SizedBox(height: 32),

                  // Legal Links
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        _LegalLink(
                          icon: Iconsax.document_text,
                          title: 'Terms of Service',
                          isDark: isDark,
                          onTap: () {},
                        ),
                        Divider(
                          color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                          height: 24,
                        ),
                        _LegalLink(
                          icon: Iconsax.shield,
                          title: 'Privacy Policy',
                          isDark: isDark,
                          onTap: () {},
                        ),
                        Divider(
                          color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                          height: 24,
                        ),
                        _LegalLink(
                          icon: Iconsax.security_safe,
                          title: 'Cookie Policy',
                          isDark: isDark,
                          onTap: () {},
                        ),
                        Divider(
                          color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                          height: 24,
                        ),
                        _LegalLink(
                          icon: Iconsax.document_code,
                          title: 'Open Source Licenses',
                          isDark: isDark,
                          onTap: () {
                            showLicensePage(
                              context: context,
                              applicationName: 'ChiHelo',
                              applicationVersion: '1.0.0',
                            );
                          },
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 700.ms),

                  const SizedBox(height: 32),

                  // Footer
                  Center(
                    child: Column(
                      children: [
                        Text(
                          'Made with ❤️ in Dubai',
                          style: AppTypography.bodyMedium(
                            color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '© 2026 ChiHelo. All rights reserved.',
                          style: AppTypography.bodySmall(
                            color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ).animate().fadeIn(delay: 750.ms),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;
  final bool isDark;

  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? DarkThemeColors.border : LightThemeColors.border,
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.labelSmall(
              color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValueCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final bool isDark;

  const _ValueCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? DarkThemeColors.border : LightThemeColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.labelLarge(
                    color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTypography.bodySmall(
                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TeamMemberCard extends StatelessWidget {
  final String name;
  final String role;
  final bool isDark;

  const _TeamMemberCard({
    required this.name,
    required this.role,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? DarkThemeColors.border : LightThemeColors.border,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.split(' ').map((e) => e[0]).join(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            name,
            textAlign: TextAlign.center,
            style: AppTypography.labelMedium(
              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            role,
            textAlign: TextAlign.center,
            style: AppTypography.bodySmall(
              color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

class _LegalLink extends StatelessWidget {
  final IconData icon;
  final String title;
  final bool isDark;
  final VoidCallback onTap;

  const _LegalLink({
    required this.icon,
    required this.title,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? DarkThemeColors.icon : LightThemeColors.icon,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: AppTypography.bodyMedium(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
          ),
          Icon(
            Iconsax.arrow_right_3,
            size: 16,
            color: isDark ? DarkThemeColors.icon : LightThemeColors.icon,
          ),
        ],
      ),
    );
  }
}

class _PatternPainter extends CustomPainter {
  final Color color;

  _PatternPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    const spacing = 30.0;
    for (double i = 0; i < size.width + size.height; i += spacing) {
      canvas.drawLine(
        Offset(i, 0),
        Offset(0, i),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
