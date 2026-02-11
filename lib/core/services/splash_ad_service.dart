import 'dart:io';
import 'package:chihelo_frontend/core/constants/api_constants.dart';
import 'package:chihelo_frontend/core/models/splash_ad_model.dart';
import 'package:chihelo_frontend/core/services/api_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SplashAdService {
  final ApiService _apiService;
  final Dio _dio = Dio();
  
  static const String _cachedVideoUrlKey = 'cached_splash_video_url';
  static const String _cachedVideoPathKey = 'cached_splash_video_path';

  SplashAdService({ApiService? apiService})
      : _apiService = apiService ?? ApiService();

  /// Fetch the currently active splash ad
  Future<SplashAdModel?> getActiveSplashAd() async {
    try {
      final response = await _apiService.get<Map<String, dynamic>>(ApiConstants.getSplashAd);

      if (response.success && response.data != null) {
        return SplashAdModel.fromJson(response.data!);
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get cached video path if available, otherwise return null
  Future<String?> getCachedVideoPath(String videoUrl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedUrl = prefs.getString(_cachedVideoUrlKey);
      final cachedPath = prefs.getString(_cachedVideoPathKey);
      
      // If URL matches and file exists, return cached path
      if (cachedUrl == videoUrl && cachedPath != null) {
        final file = File(cachedPath);
        if (await file.exists()) {
          return cachedPath;
        }
      }
      
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Download and cache video for future use
  Future<String?> downloadAndCacheVideo(String videoUrl) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final fileName = 'splash_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
      final filePath = '${directory.path}/$fileName';
      
      // Download with progress
      await _dio.download(
        videoUrl,
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(0);
          }
        },
      );
      
      // Save to preferences
      final prefs = await SharedPreferences.getInstance();
      
      // Delete old cached video if exists
      final oldPath = prefs.getString(_cachedVideoPathKey);
      if (oldPath != null) {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      }
      
      await prefs.setString(_cachedVideoUrlKey, videoUrl);
      await prefs.setString(_cachedVideoPathKey, filePath);
      
      return filePath;
    } catch (e) {
      return null;
    }
  }

  /// Pre-cache video in background (call this on app start)
  Future<void> preCacheVideo(SplashAdModel ad) async {
    if (!ad.isVideo) return;
    
    final cachedPath = await getCachedVideoPath(ad.mediaUrl);
    if (cachedPath == null) {
      // Download in background
      await downloadAndCacheVideo(ad.mediaUrl);
    }
  }

  /// Track splash ad interaction
  Future<void> trackSplashAd({
    required int adId,
    required String action, // 'view', 'click', 'skip'
  }) async {
    try {
      await _apiService.post(
        ApiConstants.trackSplashAd,
        body: {
          'id': adId,
          'action': action,
        },
      );
    } catch (e) {
    }
  }

  /// Track view event
  Future<void> trackView(int adId) => trackSplashAd(adId: adId, action: 'view');

  /// Track click event
  Future<void> trackClick(int adId) =>
      trackSplashAd(adId: adId, action: 'click');

  /// Track skip event
  Future<void> trackSkip(int adId) => trackSplashAd(adId: adId, action: 'skip');
}
