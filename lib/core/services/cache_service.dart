import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Cache Service for storing and retrieving data with TTL
class CacheService {
  static const String _homeDataKey = 'cached_home_data';
  static const String _homeDataTimestampKey = 'cached_home_data_timestamp';
  static const String _categoriesKey = 'cached_categories';
  static const String _categoriesTimestampKey = 'cached_categories_timestamp';
  static const String _categoryProductsPrefix = 'cached_category_products_';
  static const String _categoryProductsTimestampPrefix = 'cached_category_products_timestamp_';
  static const String _subcategoriesPrefix = 'cached_subcategories_';
  static const String _subcategoriesTimestampPrefix = 'cached_subcategories_timestamp_';
  
  static const Duration cacheDuration = Duration(minutes: 15); // Extended for stale-while-revalidate
  static const Duration categoryProductsCacheDuration = Duration(minutes: 10); // Longer cache for category products
  static const Duration subcategoriesCacheDuration = Duration(minutes: 30); // Even longer for subcategories (rarely change)

  /// Save home data to cache
  static Future<void> cacheHomeData(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setString(_homeDataKey, jsonString);
      await prefs.setInt(_homeDataTimestampKey, timestamp);
    } catch (e) {
    }
  }

  /// Get cached home data if valid
  static Future<Map<String, dynamic>?> getCachedHomeData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_homeDataKey);
      final timestamp = prefs.getInt(_homeDataTimestampKey);

      if (jsonString == null || timestamp == null) {
        return null;
      }

      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final age = now.difference(cachedTime);

      if (age > cacheDuration) {
        return null;
      }

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
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
    } catch (e) {
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
    } catch (e) {
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
        return null;
      }

      final decoded = jsonDecode(jsonString) as List;
      return decoded.map((e) => e as Map<String, dynamic>).toList();
    } catch (e) {
      return null;
    }
  }

  // ============== SUBCATEGORIES CACHING ==============
  
  /// Cache subcategories for a specific parent category
  static Future<void> cacheSubcategories(int categoryId, List<Map<String, dynamic>> subcategories, Map<String, dynamic> pagination) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_subcategoriesPrefix$categoryId';
      final timestampKey = '$_subcategoriesTimestampPrefix$categoryId';
      
      final data = {
        'subcategories': subcategories,
        'pagination': pagination,
      };
      final jsonString = jsonEncode(data);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setString(key, jsonString);
      await prefs.setInt(timestampKey, timestamp);
    } catch (e) {
    }
  }

  /// Get cached subcategories for a parent category if valid
  static Future<Map<String, dynamic>?> getCachedSubcategories(int categoryId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_subcategoriesPrefix$categoryId';
      final timestampKey = '$_subcategoriesTimestampPrefix$categoryId';
      
      final jsonString = prefs.getString(key);
      final timestamp = prefs.getInt(timestampKey);

      if (jsonString == null || timestamp == null) {
        return null;
      }

      final cachedTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      final age = now.difference(cachedTime);

      if (age > subcategoriesCacheDuration) {
        return null;
      }

      return jsonDecode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  /// Append more subcategories to existing cache (for pagination)
  static Future<void> appendSubcategoriesToCache(int categoryId, List<Map<String, dynamic>> newSubcategories, Map<String, dynamic> pagination) async {
    try {
      final existing = await getCachedSubcategories(categoryId);
      if (existing != null) {
        final existingList = (existing['subcategories'] as List).cast<Map<String, dynamic>>();
        existingList.addAll(newSubcategories);
        await cacheSubcategories(categoryId, existingList, pagination);
      } else {
        await cacheSubcategories(categoryId, newSubcategories, pagination);
      }
    } catch (e) {
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
      
      // Clear all category products and subcategories cache
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_categoryProductsPrefix) || 
            key.startsWith(_categoryProductsTimestampPrefix) ||
            key.startsWith(_subcategoriesPrefix) ||
            key.startsWith(_subcategoriesTimestampPrefix)) {
          await prefs.remove(key);
        }
      }
    } catch (e) {
    }
  }

  /// Clear all category products cache
  static Future<void> clearCategoryProductsCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      int count = 0;
      for (final key in keys) {
        if (key.startsWith(_categoryProductsPrefix) || key.startsWith(_categoryProductsTimestampPrefix)) {
          await prefs.remove(key);
          count++;
        }
      }
    } catch (e) {
    }
  }

  /// Clear only home data cache
  static Future<void> clearHomeDataCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_homeDataKey);
      await prefs.remove(_homeDataTimestampKey);
    } catch (e) {
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

