import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../core/services/cart_service.dart';
import '../../core/services/navigation_provider.dart';
import '../../core/theme/theme.dart';
import '../home/screens/home_screen.dart';
import '../categories/screens/categories_screen.dart';
import '../wishlist/screens/wishlist_screen.dart';
import '../cart/screens/cart_screen.dart';
import '../profile/screens/profile_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  static GlobalKey cartKey = GlobalKey();

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  DateTime? _lastBackPressed;

  @override
  void initState() {
    super.initState();
    // Fetch cart data on app start
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<CartService>(context, listen: false).fetchCart();
    });
  }

  /// Handle back button press
  Future<bool> _handleBackPress() async {
    // First, check if the current navigator can pop (e.g., CategoryProductsScreen pushed on top)
    // This handles routes pushed from within tabs
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return false; // Don't exit app
    }
    
    final navigationProvider = Provider.of<NavigationProvider>(context, listen: false);
    
    // If on home tab and a category is selected, clear it first
    if (navigationProvider.currentIndex == 0 && navigationProvider.hasHomeCategorySelected) {
      navigationProvider.clearHomeCategorySelection();
      return false; // Don't exit app
    }
    
    // If we can go back in tab history, do that
    if (navigationProvider.canGoBack) {
      navigationProvider.goBack();
      return false; // Don't exit app
    }
    
    // If not on home, go to home first
    if (navigationProvider.currentIndex != 0) {
      navigationProvider.resetToHome();
      return false; // Don't exit app
    }
    
    // On home with no history - check for double tap to exit
    final now = DateTime.now();
    if (_lastBackPressed == null || now.difference(_lastBackPressed!) > const Duration(seconds: 2)) {
      _lastBackPressed = now;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Press back again to exit'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return false; // Don't exit app yet
    }
    
    // Double tap confirmed - exit app
    SystemNavigator.pop();
    return true;
  }

  final List<_NavItem> _navItems = const [
    _NavItem(icon: Iconsax.home, activeIcon: Iconsax.home_15, label: 'Home'),
    _NavItem(icon: Iconsax.category, activeIcon: Iconsax.category5, label: 'Categories'),
    _NavItem(icon: Iconsax.heart, activeIcon: Iconsax.heart5, label: 'Wishlist'),
    _NavItem(icon: Iconsax.shopping_cart, activeIcon: Iconsax.shopping_cart5, label: 'Cart'),
    _NavItem(icon: Iconsax.user, activeIcon: Iconsax.user, label: 'Profile'),
  ];

  final List<Widget> _screens = const [
    HomeScreen(),
    CategoriesScreen(),
    WishlistScreen(),
    CartScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navigationProvider = Provider.of<NavigationProvider>(context);
    final currentIndex = navigationProvider.currentIndex;

    // Force rebuild of screens when auth state changes
    // This ensures that screens like Wishlist update their state (Guest vs User)
    // when the user logs in or out.
    // 
    // canPop is false so PopScope intercepts all back gestures.
    // _handleBackPress then checks if Navigator can pop (for screens pushed from tabs)
    // before handling tab navigation or exit logic.
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (!didPop) {
          await _handleBackPress();
        }
      },
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: [
            const HomeScreen(),
            const CategoriesScreen(),
            const WishlistScreen(),
            const CartScreen(),
            const ProfileScreen(),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
          color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.xs,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = currentIndex == index;
                
                // Get badge count for Cart
                int? badgeCount;
                if (index == 3) {
                  badgeCount = Provider.of<CartService>(context).itemCount;
                  if (badgeCount == 0) badgeCount = null;
                }

                return _NavBarItem(
                  icon: isSelected ? item.activeIcon : item.icon,
                  label: item.label,
                  isSelected: isSelected,
                  onTap: () => navigationProvider.setIndex(index),
                  badgeCount: badgeCount,
                  iconKey: index == 3 ? MainShell.cartKey : null,
                );
              }),
            ),
          ),
        ),
      ),
    ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final int? badgeCount;
  final GlobalKey? iconKey;

  const _NavBarItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    this.badgeCount,
    this.iconKey,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark ? Colors.white : Colors.black;
    final inactiveColor = isDark ? AppColors.neutral500 : AppColors.neutral400;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(
              key: iconKey,
              width: 28,
              height: 28,
              child: Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: isSelected ? activeColor : inactiveColor,
                    ),
                    if (badgeCount != null && badgeCount! > 0)
                      Positioned(
                        right: -8,
                        top: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 16,
                            minHeight: 14,
                          ),
                          child: Text(
                            badgeCount! > 9 ? '9+' : badgeCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

