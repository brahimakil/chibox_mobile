import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

/// Cache Service for storing and retrieving data with TTL
class CacheService {
  static const String _homeDataKey = 'cached_home_data';
  static const String _homeDataTimestampKey = 'cached_home_data_timestamp';
  static const String _categoriesKey = 'cached_categories';
  static const String _categoriesTimestampKey = 'cached_categories_timestamp';
  static const String _categoryProductsPrefix = 'cached_category_products_';
  static const String _categoryProductsTimestampPrefix = 'cached_category_products_timestamp_';
  
  static const Duration cacheDuration = Duration(minutes: 5);
  static const Duration categoryProductsCacheDuration = Duration(minutes: 10); // Longer cache for category products

  /// Save home data to cache
  static Future<void> cacheHomeData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setString(_homeDataKey, jsonString);
      await prefs.setInt(_homeDataTimestampKey, timestamp);
      
      debugPrint('✅ Home data cached successfully');
    } catch (e) {
      debugPrint('❌ Error caching home data: $e');
    }
  }

  /// Get cached home data if valid
  static Future<Map<String, dynamic>?> getCachedHomeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_homeDataKey);
      final timestamp = prefs.getInt(_homeDataTimestampKey);

      if (jsonString == null || timestamp == null) {
        debugPrint('⚠️ No cached home data found');
        return null;
      }

      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final age = now.difference(cachedTime);

      if (age > cacheDuration) {
        debugPrint('⚠️ Cache expired (age: ${age.inMinutes}m ${age.inSeconds % 60}s)');
        return null;
      }

      debugPrint('✅ Using cached data (age: ${age.inMinutes}m ${age.inSeconds % 60}s)');
      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('❌ Error reading cached home data: $e');
      return null;
    }
  }

  /// Save categories to cache
  static Future<void> cacheCategories(List<Map<String, dynamic>> categories) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(categories);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setString(_categoriesKey, jsonString);
      await prefs.setInt(_categoriesTimestampKey, timestamp);
      
      debugPrint('✅ Categories cached successfully');
    } catch (e) {
      debugPrint('❌ Error caching categories: $e');
    }
  }

  /// Get cached categories if valid
  static Future<List<Map<String, dynamic>>?> getCachedCategories() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_categoriesKey);
      final timestamp = prefs.getInt(_categoriesTimestampKey);

      if (jsonString == null || timestamp == null) {
        return null;
      }

      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final age = now.difference(cachedTime);

      if (age > cacheDuration) {
        return null;
      }

      final decoded = jsonDecode(jsonString) as List;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Error reading cached categories: $e');
      return null;
    }
  }

  // ============== CATEGORY PRODUCTS CACHING ==============
  
  /// Cache products for a specific category (first page only, no filters)
  static Future<void> cacheCategoryProducts(int categoryId, List<Map<String, dynamic>> products) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_categoryProductsPrefix$categoryId';
      final timestampKey = '$_categoryProductsTimestampPrefix$categoryId';
      
      final jsonString = jsonEncode(products);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setString(key, jsonString);
      await prefs.setInt(timestampKey, timestamp);
      
      debugPrint('✅ Category $categoryId products cached: ${products.length} items');
    } catch (e) {
      debugPrint('❌ Error caching category products: $e');
    }
  }

  /// Get cached products for a category if valid
  static Future<List<Map<String, dynamic>>?> getCachedCategoryProducts(int categoryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_categoryProductsPrefix$categoryId';
      final timestampKey = '$_categoryProductsTimestampPrefix$categoryId';
      
      final jsonString = prefs.getString(key);
      final timestamp = prefs.getInt(timestampKey);

      if (jsonString == null || timestamp == null) {
        return null;
      }

      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final age = now.difference(cachedTime);

      if (age > categoryProductsCacheDuration) {
        debugPrint('⚠️ Category $categoryId cache expired');
        return null;
      }

      debugPrint('✅ Using cached products for category $categoryId (age: ${age.inMinutes}m)');
      final decoded = jsonDecode(jsonString) as List;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('❌ Error reading cached category products: $e');
      return null;
    }
  }

  /// Clear all cached data
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_homeDataKey);
      await prefs.remove(_homeDataTimestampKey);
      await prefs.remove(_categoriesKey);
      await prefs.remove(_categoriesTimestampKey);
      
      debugPrint('🗑️ Cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Clear only home data cache
  static Future<void> clearHomeDataCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_homeDataKey);
      await prefs.remove(_homeDataTimestampKey);
      
      debugPrint('🗑️ Home data cache cleared');
    } catch (e) {
      debugPrint('❌ Error clearing home data cache: $e');
    }
  }

  /// Check if cache is still valid
  static Future<bool> isCacheValid(String timestampKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final timestamp = prefs.getInt(timestampKey);

      if (timestamp == null) return false;

      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final age = now.difference(cachedTime);

      return age <= cacheDuration;
    } catch (e) {
      return false;
    }
  }
}

