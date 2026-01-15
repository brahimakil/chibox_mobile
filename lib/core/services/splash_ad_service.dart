import 'package:chihelo_frontend/core/constants/api_constants.dart';
import 'package:chihelo_frontend/core/models/splash_ad_model.dart';
import 'package:chihelo_frontend/core/services/api_service.dart';
import 'package:flutter/foundation.dart';

class SplashAdService {
  final ApiService _apiService;

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
      debugPrint('Error fetching splash ad: $e');
      return null;
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
          'ad_id': adId,
          'action': action,
        },
      );
    } catch (e) {
      debugPrint('Error tracking splash ad: $e');
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
