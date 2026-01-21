import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';
import 'core/theme/theme.dart';
import 'core/constants/api_constants.dart';
import 'core/services/api_service.dart';
import 'core/services/auth_service.dart';
import 'core/services/home_service.dart';
import 'core/services/product_service.dart';
import 'core/services/cart_service.dart';
import 'core/services/wishlist_service.dart';
import 'core/services/address_service.dart';
import 'core/services/category_service.dart';
import 'core/services/navigation_provider.dart';
import 'core/services/security_service.dart';
import 'core/services/order_service.dart';
import 'core/services/notification_service.dart';
import 'core/services/payment_service.dart';
import 'core/services/shipping_service.dart';
import 'core/services/fcm_service.dart';
import 'features/navigation/main_shell.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/splash/screens/splash_screen.dart';
import 'features/orders/screens/order_details_screen.dart';
import 'shared/widgets/app_lock_wrapper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables from .env file
  await dotenv.load(fileName: ".env");

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Set up background message handler
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  // Initialize services
  debugPrint('🔴🔴🔴 STARTUP DEBUG: Checking API Configuration 🔴🔴🔴');
  debugPrint('🔴 API Base URL: ${ApiConstants.baseUrl}');
  
  await ApiService().init();
  await AuthService().init();
  await SecurityService().init();
  
  // Initialize FCM
  await FcmService().initialize();

  runApp(const LuxeMarketApp());
}

class LuxeMarketApp extends StatelessWidget {
  const LuxeMarketApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()..init()),
        ChangeNotifierProvider(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => HomeService()),
        ChangeNotifierProxyProvider<HomeService, ProductService>(
          create: (_) => ProductService(),
          update: (_, homeService, productService) {
            productService?.setHomeService(homeService);
            return productService ?? ProductService()..setHomeService(homeService);
          },
        ),
        ChangeNotifierProvider(create: (_) => CartService()),
        ChangeNotifierProvider(create: (_) => WishlistService()),
        ChangeNotifierProvider(create: (_) => AddressService()),
        ChangeNotifierProvider(create: (_) => CategoryService()),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => SecurityService()),
        ChangeNotifierProvider(create: (_) => OrderService()),
        ChangeNotifierProvider(create: (_) => NotificationService()),
        ChangeNotifierProvider(create: (_) => PaymentService()),
        ChangeNotifierProvider(create: (_) => ShippingService()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'LuxeMarket',
            debugShowCheckedModeBanner: false,
            navigatorKey: navigatorKey,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.currentThemeMode,
            home: const SplashScreen(),
            routes: {
              '/login': (_) => const LoginScreen(),
              '/home': (_) => const MainShell(),
            },
            onGenerateRoute: (settings) {
              // Handle order details navigation from notifications
              if (settings.name == '/order-details') {
                final orderId = settings.arguments as int?;
                if (orderId != null) {
                  return MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(orderId: orderId),
                  );
                }
              }
              return null;
            },
          );
        },
      ),
    );
  }
}

/// Wrapper to handle auth state
class AppWrapper extends StatelessWidget {
  const AppWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(
      builder: (context, authService, _) {
        if (authService.isAuthenticated) {
          return const AppLockWrapper(child: MainShell());
        }
        return const LoginScreen();
      },
    );
  }
}
