import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';
import 'api_service.dart';
import 'fcm_service.dart';
import '../models/user_model.dart';

/// Authentication Service
class AuthService extends ChangeNotifier {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final ApiService _api = ApiService();
  
  User? _currentUser;
  bool _isLoading = false;
  bool _isGuest = false;
  String? _error;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => (_currentUser != null && _api.isAuthenticated) || _isGuest;
  bool get isGuest => _isGuest;
  String? get error => _error;

  /// Initialize auth service
  Future<void> init() async {
    await _api.init();
    await _loadUser();
  }

  /// Load user from storage
  Future<void> _loadUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Check for guest mode
      _isGuest = prefs.getBool('is_guest') ?? false;
      
      if (!_isGuest) {
        final userData = prefs.getString(AppConstants.userKey);
        if (userData != null) {
          _currentUser = User.fromJson(jsonDecode(userData));
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading user: $e');
    }
  }

  /// Continue as Guest
  Future<void> continueAsGuest() async {
    _isGuest = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_guest', true);
    notifyListeners();
  }

  /// Save user to storage
  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, jsonEncode(user.toJson()));
    await prefs.remove('is_guest');
  }

  /// Register new user
  Future<ApiResponse<int>> register({
    required String countryCode,
    required String phoneNumber,
    required String firstName,
    required String lastName,
    String? email,
    String? gender,
    int? languageId,
    String? deviceId,
    String? deviceType,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.post(ApiConstants.register, body: {
        'country_code': countryCode.replaceAll('+', ''),
        'phone_number': phoneNumber,
        'first_name': firstName,
        'last_name': lastName,
        if (email != null) 'email': email,
        if (gender != null) 'gender': gender,
        if (languageId != null) 'language_id': languageId,
        if (deviceId != null) 'device_id': deviceId,
        if (deviceType != null) 'device_type': deviceType,
      });

      _setLoading(false);

      if (response.success && response.data != null) {
        final userId = response.data!['user_id'] as int;
        return ApiResponse.success(userId, message: response.message);
      }

      _error = response.message;
      return ApiResponse.error(response.message);
    } catch (e) {
      _setLoading(false);
      _error = e.toString();
      return ApiResponse.error(_error!);
    }
  }

  /// Login - Request OTP
  Future<ApiResponse<int>> login({
    required String countryCode,
    required String phoneNumber,
    String? deviceId,
    String? deviceType,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.post(ApiConstants.login, body: {
        'country_code': countryCode.replaceAll('+', ''),
        'phone_number': phoneNumber,
        if (deviceId != null) 'device_id': deviceId,
        if (deviceType != null) 'device_type': deviceType,
      });

      _setLoading(false);

      if (response.success && response.data != null) {
        final userId = response.data!['user_id'] as int;
        return ApiResponse.success(userId, message: response.message);
      }

      _error = response.message;
      return ApiResponse.error(response.message, statusCode: response.statusCode);
    } catch (e) {
      _setLoading(false);
      _error = e.toString();
      return ApiResponse.error(_error!);
    }
  }

  /// Login or Register - Auto-registers if user not found
  Future<ApiResponse<Map<String, dynamic>>> loginOrRegister({
    required String countryCode,
    required String phoneNumber,
    String? deviceId,
    String? deviceType,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // First try to login
      final loginResponse = await _api.post(ApiConstants.login, body: {
        'country_code': countryCode.replaceAll('+', ''),
        'phone_number': phoneNumber,
        if (deviceId != null) 'device_id': deviceId,
        if (deviceType != null) 'device_type': deviceType,
      });

      if (loginResponse.success && loginResponse.data != null) {
        final userId = loginResponse.data!['user_id'] as int;
        _setLoading(false);
        return ApiResponse.success({
          'user_id': userId,
          'is_new_user': false,
        }, message: loginResponse.message);
      }

      // If user not found (404), auto-register them
      if (loginResponse.statusCode == 404) {
        final registerResponse = await _api.post(ApiConstants.register, body: {
          'country_code': countryCode.replaceAll('+', ''),
          'phone_number': phoneNumber,
          'first_name': 'User', // Placeholder, will be updated later
          if (deviceId != null) 'device_id': deviceId,
          if (deviceType != null) 'device_type': deviceType,
        });

        _setLoading(false);

        if (registerResponse.success && registerResponse.data != null) {
          final userId = registerResponse.data!['user_id'] as int;
          return ApiResponse.success({
            'user_id': userId,
            'is_new_user': true,
          }, message: registerResponse.message);
        }

        _error = registerResponse.message;
        return ApiResponse.error(registerResponse.message);
      }

      _setLoading(false);
      _error = loginResponse.message;
      return ApiResponse.error(loginResponse.message);
    } catch (e) {
      _setLoading(false);
      _error = e.toString();
      return ApiResponse.error(_error!);
    }
  }

  /// Verify OTP
  Future<ApiResponse<User>> verifyOtp({
    required int userId,
    required String otp,
    String? fcmToken,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      // Auto-get FCM token if not provided
      final token = fcmToken ?? await FcmService().getToken();
      
      final response = await _api.post(ApiConstants.verifyOtp, body: {
        'user_id': userId,
        'otp': otp,
        if (token != null) 'fcm_token': token,
      });

      _setLoading(false);

      if (response.success && response.data != null) {
        // Extract user and token
        final userData = response.data!['user'] as Map<String, dynamic>;
        final accessToken = response.data!['access_token'] as String;

        // Create user object
        final user = User.fromJson(userData);
        
        // Save token and user
        await _api.setToken(accessToken);
        await _saveUser(user);
        
        _currentUser = user;
        _isGuest = false;
        notifyListeners();

        return ApiResponse.success(user, message: response.message);
      }

      _error = response.message;
      return ApiResponse.error(response.message);
    } catch (e) {
      _setLoading(false);
      _error = e.toString();
      return ApiResponse.error(_error!);
    }
  }

  /// Resend OTP
  Future<ApiResponse<int>> resendOtp({
    required String countryCode,
    required String phoneNumber,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.post(ApiConstants.resendOtp, body: {
        'country_code': countryCode.replaceAll('+', ''),
        'phone_number': phoneNumber,
      });

      _setLoading(false);

      if (response.success && response.data != null) {
        final userId = response.data!['user_id'] as int;
        return ApiResponse.success(userId, message: response.message);
      }

      _error = response.message;
      return ApiResponse.error(response.message);
    } catch (e) {
      _setLoading(false);
      _error = e.toString();
      return ApiResponse.error(_error!);
    }
  }

  /// Edit Profile
  Future<ApiResponse<User>> editProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? gender,
    String? profileImagePath,
  }) async {
    _setLoading(true);
    _error = null;

    try {
      ApiResponse response;
      
      if (profileImagePath != null) {
        // Use multipart request for profile image upload
        response = await _api.postMultipart(
          ApiConstants.editProfile,
          filePath: profileImagePath,
          fileField: 'profile_image',
          fields: {
            if (firstName != null) 'first_name': firstName,
            if (lastName != null) 'last_name': lastName,
            if (email != null) 'email': email,
            if (gender != null) 'gender': gender,
          },
        );
      } else {
        // Regular POST request without file
        response = await _api.post(ApiConstants.editProfile, body: {
          if (firstName != null) 'first_name': firstName,
          if (lastName != null) 'last_name': lastName,
          if (email != null) 'email': email,
          if (gender != null) 'gender': gender,
        });
      }

      _setLoading(false);

      if (response.success && response.data != null) {
        final userData = response.data!['user'];
        final user = User.fromJson(userData);
        _currentUser = user;
        await _saveUser(user);
        notifyListeners();
        return ApiResponse.success(user, message: response.message);
      }

      _error = response.message;
      return ApiResponse.error(response.message);
    } catch (e) {
      _setLoading(false);
      _error = e.toString();
      return ApiResponse.error(_error!);
    }
  }

  /// Delete Account
  Future<ApiResponse<void>> deleteAccount() async {
    _setLoading(true);
    _error = null;

    try {
      final response = await _api.post(ApiConstants.deleteAccount);

      if (response.success) {
        // Clear local data
        await _api.clearToken();
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(AppConstants.userKey);
        await prefs.remove('is_guest');
        
        _currentUser = null;
        _isGuest = false;
        _setLoading(false);
        notifyListeners();
        return ApiResponse.success(null, message: response.message);
      }

      _setLoading(false);
      _error = response.message;
      return ApiResponse.error(response.message);
    } catch (e) {
      _setLoading(false);
      _error = e.toString();
      return ApiResponse.error(_error!);
    }
  }

  /// Logout
  Future<void> logout() async {
    _setLoading(true);

    try {
      await _api.post(ApiConstants.logout);
    } catch (e) {
      debugPrint('Logout API error: $e');
    }

    // Clear local data regardless of API response
    await _api.clearToken();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userKey);
    await prefs.remove('is_guest');
    
    _currentUser = null;
    _isGuest = false;
    _setLoading(false);
    notifyListeners();
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}

