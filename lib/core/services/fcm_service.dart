import 'dart:convert';
import 'dart:typed_data';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import '../constants/api_constants.dart';
import '../models/notification_model.dart';
import '../utils/notification_navigation_helper.dart';
import 'api_service.dart';

/// Global navigator key for handling navigation from FCM notifications
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// FCM Service - Handles Firebase Cloud Messaging for Push Notifications
class FcmService {
  static final FcmService _instance = FcmService._internal();
  factory FcmService() => _instance;
  FcmService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final ApiService _apiService = ApiService();
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  String? _fcmToken;
  bool _isInitialized = false;
  
  /// Pending notification data to handle after app is ready
  Map<String, dynamic>? _pendingNotificationData;

  /// Get the current FCM token
  String? get fcmToken => _fcmToken;
  bool get isInitialized => _isInitialized;
  Map<String, dynamic>? get pendingNotificationData => _pendingNotificationData;
  
  /// Clear pending notification
  void clearPendingNotification() {
    _pendingNotificationData = null;
  }

  /// Initialize Firebase and FCM
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Initialize Firebase (should already be done in main.dart)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      // Request notification permissions (iOS & Android 13+)
      await _requestPermissions();

      // Initialize local notifications
      await _initializeLocalNotifications();

      // Get FCM token
      await _getToken();

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) async {
        _fcmToken = newToken;
        await _updateTokenOnBackend(newToken);
      });

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

      // Handle background/terminated message taps
      FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageOpenedApp);

      // Check if app was opened from a notification
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        _handleMessageOpenedApp(initialMessage);
      }

      // Subscribe to the global topic for broadcast notifications
      await subscribeToTopic('global');

      _isInitialized = true;
    } catch (e) {
    }
  }

  /// Request notification permissions
  Future<void> _requestPermissions() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
      announcement: true,
      carPlay: false,
      criticalAlert: false,
    );
  }

  /// Initialize local notifications plugin
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/launcher_icon');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create Android notification channel
    const androidChannel = AndroidNotificationChannel(
      'chibox_notifications',
      'Chibox Notifications',
      description: 'Notifications for orders, promotions, and updates',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle notification tap
  void _onNotificationTapped(NotificationResponse response) {
    _handleNotificationNavigation(response.payload);
  }
  
  /// Handle navigation based on notification data - UNIVERSAL NAVIGATION
  void _handleNotificationNavigation(String? payload) {
    if (payload == null || payload.isEmpty) return;
    
    try {
      Map<String, dynamic>? data;
      
      // Try parsing as JSON first
      try {
        data = json.decode(payload);
      } catch (_) {
        // If not JSON, try parsing as Dart map string representation
        if (payload.startsWith('{') && payload.endsWith('}')) {
          final cleanPayload = payload.substring(1, payload.length - 1);
          data = {};
          for (final part in cleanPayload.split(', ')) {
            final keyValue = part.split(': ');
            if (keyValue.length == 2) {
              data[keyValue[0].trim()] = keyValue[1].trim();
            }
          }
        }
      }
      
      if (data == null) return;
      
      // Use Universal Navigation Helper
      final context = navigatorKey.currentContext;
      if (context == null) {
        // Store for later navigation if context not available
        _pendingNotificationData = data;
        return;
      }
      
      // Navigate using the universal helper
      NotificationNavigationHelper.navigateFromPushData(context, data);
      
    } catch (e) {
    }
  }
  
  /// Process any pending notification navigation (call after app is ready)
  void processPendingNotification(BuildContext context) {
    if (_pendingNotificationData != null) {
      NotificationNavigationHelper.navigateFromPushData(context, _pendingNotificationData!);
      _pendingNotificationData = null;
    }
  }

  /// Show local notification (with optional big image)
  Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    // Try to get image URL from notification or data payload
    final String? imageUrl = notification.android?.imageUrl 
        ?? notification.apple?.imageUrl 
        ?? message.data['image_url'];

    // Build Android details — with big picture if image available
    AndroidNotificationDetails androidDetails;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      try {
        final bigPicture = BigPictureStyleInformation(
          ByteArrayAndroidBitmap.fromBase64String(
            await _downloadImageAsBase64(imageUrl),
          ),
          contentTitle: notification.title,
          summaryText: notification.body,
          hideExpandedLargeIcon: true,
        );
        androidDetails = AndroidNotificationDetails(
          'chibox_notifications',
          'Chibox Notifications',
          channelDescription: 'Notifications for orders, promotions, and updates',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/launcher_icon',
          styleInformation: bigPicture,
        );
      } catch (_) {
        // Fallback to regular notification if image download fails
        androidDetails = const AndroidNotificationDetails(
          'chibox_notifications',
          'Chibox Notifications',
          channelDescription: 'Notifications for orders, promotions, and updates',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/launcher_icon',
        );
      }
    } else {
      androidDetails = const AndroidNotificationDetails(
        'chibox_notifications',
        'Chibox Notifications',
        channelDescription: 'Notifications for orders, promotions, and updates',
        importance: Importance.high,
        priority: Priority.high,
        playSound: true,
        icon: '@mipmap/launcher_icon',
      );
    }

    final iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.active,
    );

    final details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      message.hashCode,
      notification.title,
      notification.body,
      details,
      payload: json.encode(message.data),
    );
  }

  /// Get FCM device token
  Future<String?> _getToken() async {
    try {
      _fcmToken = await _messaging.getToken();
      if (_fcmToken != null) {
      }
      return _fcmToken;
    } catch (e) {
      return null;
    }
  }

  /// Get token (public method for auth service)
  Future<String?> getToken() async {
    if (_fcmToken == null) {
      await _getToken();
    }
    return _fcmToken;
  }

  /// Handle foreground messages
  void _handleForegroundMessage(RemoteMessage message) {
    // Show local notification when app is in foreground
    _showLocalNotification(message);
  }

  /// Handle when user taps on notification (background/terminated)
  void _handleMessageOpenedApp(RemoteMessage message) {
    // Handle navigation based on notification data
    _handleNotificationNavigation(json.encode(message.data));
  }

  /// Subscribe to a topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
    } catch (e) {
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
    } catch (e) {
    }
  }

  /// Update FCM token on backend
  Future<void> _updateTokenOnBackend(String token) async {
    try {
      if (!_apiService.isAuthenticated) {
        return;
      }
      
      final response = await _apiService.post(
        ApiConstants.updateFcmToken,
        body: {'fcm_token': token},
      );
      
      if (response.success) {
      } else {
      }
    } catch (e) {
    }
  }

  /// Download an image from URL and return as base64 string
  Future<String> _downloadImageAsBase64(String url) async {
    final response = await http.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
    );
    if (response.statusCode == 200) {
      return base64Encode(response.bodyBytes);
    }
    throw Exception('Failed to download image: ${response.statusCode}');
  }

  /// Manually trigger token update (call after user logs in)
  Future<void> updateTokenOnBackend() async {
    if (_fcmToken != null) {
      await _updateTokenOnBackend(_fcmToken!);
    }
  }
}

/// Background message handler (must be top-level function)
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
}
