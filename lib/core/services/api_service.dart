import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/api_constants.dart';
import '../constants/app_constants.dart';

/// API Response wrapper
class ApiResponse<T> {
  final bool success;
  final String message;
  final T? data;
  final int? statusCode;

  ApiResponse({
    required this.success,
    required this.message,
    this.data,
    this.statusCode,
  });

  factory ApiResponse.success(T data, {String message = 'Success'}) {
    return ApiResponse(success: true, message: message, data: data);
  }

  factory ApiResponse.error(String message, {int? statusCode}) {
    return ApiResponse(success: false, message: message, statusCode: statusCode);
  }
}

/// API Service for making HTTP requests
class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  final http.Client _client = http.Client();
  String? _accessToken;
  String? _cookie;

  /// Initialize the service and load token from storage
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _accessToken = prefs.getString(AppConstants.accessTokenKey);
    _cookie = prefs.getString('app_cookie');
  }

  /// Set access token
  Future<void> setToken(String token) async {
    _accessToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.accessTokenKey, token);
  }

  /// Clear access token
  Future<void> clearToken() async {
    _accessToken = null;
    // Don't clear cookie on logout as we might want to keep guest session or create new one
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.accessTokenKey);
  }

  /// Check if user is authenticated
  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  /// Get headers
  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    if (_cookie != null) {
      headers['Cookie'] = _cookie!;
      debugPrint('🍪 Sending Cookie: $_cookie');
    } else {
      debugPrint('⚠️ No Cookie to send');
    }
    return headers;
  }

  /// Build full URL
  String _buildUrl(String endpoint, [Map<String, dynamic>? queryParams]) {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');
    if (queryParams != null && queryParams.isNotEmpty) {
      return uri.replace(queryParameters: queryParams.map((k, v) => MapEntry(k, v.toString()))).toString();
    }
    return uri.toString();
  }

  /// GET request
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    Map<String, dynamic>? queryParams,
    int retries = 2,
  }) async {
    int attempts = 0;
    while (attempts <= retries) {
      attempts++;
      try {
        final url = _buildUrl(endpoint, queryParams);
        debugPrint('API GET (Attempt $attempts): $url');
        
        final response = await _client
            .get(Uri.parse(url), headers: _headers)
            .timeout(ApiConstants.connectionTimeout);

        debugPrint('API Response Status: ${response.statusCode}');
        
        return _handleResponse<T>(response);
      } catch (e) {
        debugPrint('API GET Error (Attempt $attempts): $e');
        
        // Only retry on network-related errors
        bool shouldRetry = e.toString().contains('ClientException') || 
                           e.toString().contains('SocketException') ||
                           e.toString().contains('Connection closed');
                           
        if (attempts > retries || !shouldRetry) {
          return ApiResponse.error(_getErrorMessage(e));
        }
        
        // Wait before retrying
        await Future.delayed(Duration(milliseconds: 500 * attempts));
      }
    }
    return ApiResponse.error('Request failed after $retries retries');
  }

  /// POST request
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final url = _buildUrl(endpoint, queryParams);
      final response = await _client
          .post(
            Uri.parse(url),
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConstants.connectionTimeout);

      return _handleResponse<T>(response);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  /// PUT request
  Future<ApiResponse<T>> put<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final url = _buildUrl(endpoint, queryParams);
      final response = await _client
          .put(
            Uri.parse(url),
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConstants.connectionTimeout);

      return _handleResponse<T>(response);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  /// DELETE request
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final url = _buildUrl(endpoint, queryParams);
      final response = await _client
          .delete(
            Uri.parse(url), 
            headers: _headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConstants.connectionTimeout);

      return _handleResponse<T>(response);
    } catch (e) {
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  /// Multipart POST request (for file uploads)
  Future<ApiResponse<T>> postMultipart<T>(
    String endpoint, {
    required String filePath,
    required String fileField,
    Map<String, String>? fields,
    Map<String, dynamic>? queryParams,
  }) async {
    try {
      final url = _buildUrl(endpoint, queryParams);
      debugPrint('API Multipart POST: $url');
      debugPrint('📁 File path: $filePath');
      
      // Verify file exists
      final file = File(filePath);
      if (!await file.exists()) {
        debugPrint('❌ File does not exist: $filePath');
        return ApiResponse.error('File does not exist');
      }
      
      final fileSize = await file.length();
      debugPrint('📏 File size: $fileSize bytes');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      
      // Add headers
      request.headers.addAll(_headers);
      // Remove Content-Type as MultipartRequest sets it automatically
      request.headers.remove('Content-Type');

      // Add fields
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Add file with explicit content type for images
      final mimeType = _getMimeType(filePath);
      debugPrint('📷 MIME type: $mimeType');
      
      request.files.add(await http.MultipartFile.fromPath(
        fileField, 
        filePath,
        contentType: mimeType != null ? MediaType.parse(mimeType) : null,
      ));

      debugPrint('📤 Sending multipart request...');
      
      // Send request
      final streamedResponse = await request.send().timeout(ApiConstants.connectionTimeout);
      final response = await http.Response.fromStream(streamedResponse);

      debugPrint('API Response Status: ${response.statusCode}');
      debugPrint('API Response Body: ${response.body.substring(0, response.body.length > 500 ? 500 : response.body.length)}...');
      
      return _handleResponse<T>(response);
    } catch (e) {
      debugPrint('API Multipart Error: $e');
      return ApiResponse.error(_getErrorMessage(e));
    }
  }

  /// Get MIME type from file extension
  String? _getMimeType(String filePath) {
    final ext = filePath.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg'; // Default to JPEG
    }
  }

  /// Handle HTTP response
  ApiResponse<T> _handleResponse<T>(http.Response response) {
    // Save cookie if present
    String? rawCookie = response.headers['set-cookie'];
    if (rawCookie != null) {
      debugPrint('🍪 Received Set-Cookie: $rawCookie');
      int index = rawCookie.indexOf(';');
      _cookie = (index == -1) ? rawCookie : rawCookie.substring(0, index);
      SharedPreferences.getInstance().then((prefs) {
        prefs.setString('app_cookie', _cookie!);
      });
    }

    try {
      if (response.body.isEmpty) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Return null for data if body is empty
          return ApiResponse(success: true, message: 'Success', data: null, statusCode: response.statusCode);
        }
        return ApiResponse.error('Empty response', statusCode: response.statusCode);
      }

      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final success = body['success'] ?? body['status'] ?? false;
      final message = body['message'] ?? 'Unknown error';

      if (response.statusCode >= 200 && response.statusCode < 300) {
        dynamic rawData = body['data'];
        T? data;
        
        if (rawData is T) {
          data = rawData;
        } else if (rawData is List && rawData.isEmpty) {
          // Handle empty list case
          try {
            data = rawData as T;
          } catch (_) {
            data = null;
          }
        } else if (rawData != null) {
          // Try to cast
          try {
            data = rawData as T;
          } catch (_) {
            debugPrint('⚠️ Warning: Unexpected data format: $rawData');
            data = null;
          }
        }

        return ApiResponse(
          success: success,
          message: message,
          data: data,
          statusCode: response.statusCode,
        );
      }

      return ApiResponse.error(message, statusCode: response.statusCode);
    } catch (e) {
      debugPrint('API Parse Error: $e');
      debugPrint('Response Body: ${response.body}');
      return ApiResponse.error('Failed to parse response', statusCode: response.statusCode);
    }
  }

  /// Get error message from exception
  String _getErrorMessage(dynamic e) {
    if (e.toString().contains('SocketException')) {
      return 'No internet connection';
    }
    if (e.toString().contains('TimeoutException')) {
      return 'Request timeout. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }
}

