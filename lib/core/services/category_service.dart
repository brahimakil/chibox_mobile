import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import 'api_service.dart';
import '../constants/api_constants.dart';
import 'cache_service.dart';

class CategoryService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<ProductCategory> _categories = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _perPage = 30;
  
  // In-memory cache for subcategories (faster than disk cache)
  final Map<int, List<ProductCategory>> _subcategoriesCache = {};
  final Map<int, Map<String, dynamic>> _subcategoriesPaginationCache = {};

  List<ProductCategory> get categories => _categories;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasMore => _hasMore;

  Future<void> fetchCategories({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      _currentPage = 1;
      _categories = [];
      _hasMore = true;
      _error = null;
    }
    
    if (!_hasMore) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiConstants.getAllCategories,
        queryParams: {
          'page': _currentPage.toString(),
          'per_page': _perPage.toString(),
        },
      );

      if (response.success && response.data != null) {
        final Map<String, dynamic> data = response.data!;
        
        // Handle categories list
        final List<dynamic> categoriesList = data['categories'] ?? [];
        final newCategories = categoriesList.map((json) => ProductCategory.fromJson(json)).toList();

        // Handle pagination
        if (data['pagination'] != null) {
          _hasMore = data['pagination']['has_next'] ?? false;
        } else {
          // Fallback if pagination data is missing
          if (newCategories.length < _perPage) {
            _hasMore = false;
          }
        }
        
        if (refresh) {
          _categories = newCategories;
        } else {
          _categories.addAll(newCategories);
        }
        
        _currentPage++;
      } else {
        _error = response.message;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Fetch subcategories for a specific category with pagination
  /// Returns a map with 'subcategories' list and 'pagination' info
  /// Uses in-memory cache and persistent cache for fast subsequent loads
  Future<Map<String, dynamic>> fetchSubcategories(int categoryId, {int page = 1, int perPage = 30, bool forceRefresh = false}) async {
    // Check in-memory cache first (fastest)
    if (!forceRefresh && page == 1 && _subcategoriesCache.containsKey(categoryId)) {
      return {
        'subcategories': _subcategoriesCache[categoryId]!,
        'pagination': _subcategoriesPaginationCache[categoryId] ?? {},
        'fromCache': true,
      };
    }

    // Check persistent cache (fast)
    if (!forceRefresh && page == 1) {
      final cachedData = await CacheService.getCachedSubcategories(categoryId);
      if (cachedData != null) {
        final subcatList = cachedData['subcategories'] as List;
        final subcategories = subcatList.map((json) => ProductCategory.fromJson(json as Map<String, dynamic>)).toList();
        final pagination = cachedData['pagination'] as Map<String, dynamic>? ?? {};
        
        // Store in memory cache too
        _subcategoriesCache[categoryId] = subcategories;
        _subcategoriesPaginationCache[categoryId] = pagination;
        
        return {
          'subcategories': subcategories,
          'pagination': pagination,
          'fromCache': true,
        };
      }
    }

    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiConstants.getSubcategories,
        queryParams: {
          'id': categoryId.toString(),
          'page': page.toString(),
          'per_page': perPage.toString(),
        },
      );

      if (response.success && response.data != null) {
        final Map<String, dynamic> data = response.data!;
        
        final List<dynamic> subcatList = data['subcategories'] ?? [];
        final subcategories = subcatList.map((json) => ProductCategory.fromJson(json)).toList();
        final pagination = data['pagination'] as Map<String, dynamic>? ?? {};

        // Update caches
        if (page == 1) {
          // First page: replace cache
          _subcategoriesCache[categoryId] = subcategories;
          _subcategoriesPaginationCache[categoryId] = pagination;
          
          // Save to persistent cache (fire and forget - don't block UI)
          CacheService.cacheSubcategories(
            categoryId, 
            subcatList.map((e) => e as Map<String, dynamic>).toList(),
            pagination,
          );
        } else {
          // Subsequent pages: append to in-memory cache only (skip disk for speed)
          _subcategoriesCache[categoryId]?.addAll(subcategories);
          _subcategoriesPaginationCache[categoryId] = pagination;
        }

        return {
          'subcategories': subcategories,
          'pagination': pagination,
        };
      } else {
        return {'subcategories': <ProductCategory>[], 'pagination': {}};
      }
    } catch (e) {
      return {'subcategories': <ProductCategory>[], 'pagination': {}};
    }
  }
  
  /// Get cached subcategories for a category (in-memory only, no API call)
  List<ProductCategory>? getCachedSubcategories(int categoryId) {
    return _subcategoriesCache[categoryId];
  }
  
  /// Clear subcategories cache for a specific category or all
  void clearSubcategoriesCache([int? categoryId]) {
    if (categoryId != null) {
      _subcategoriesCache.remove(categoryId);
      _subcategoriesPaginationCache.remove(categoryId);
    } else {
      _subcategoriesCache.clear();
      _subcategoriesPaginationCache.clear();
    }
  }

  /// Search categories by keyword (server-side search with fuzzy matching)
  /// Returns exact matches and similar categories (for typos)
  Future<CategorySearchResponse> searchCategoriesWithSimilar(String keyword, {int limit = 20}) async {
    if (keyword.trim().isEmpty) {
      return CategorySearchResponse(results: [], similarResults: []);
    }
    
    try {
      final response = await _apiService.get<Map<String, dynamic>>(
        ApiConstants.searchCategories,
        queryParams: {
          'keyword': keyword.trim(),
          'limit': limit.toString(),
        },
      );

      if (response.success && response.data != null) {
        // Parse exact matches
        final List<dynamic> resultsList = response.data!['results'] ?? [];
        final results = _parseSearchResults(resultsList);
        
        // Parse similar categories (fuzzy matches)
        final List<dynamic> similarList = response.data!['similar_categories'] ?? [];
        final similarResults = _parseSearchResults(similarList);
        
        return CategorySearchResponse(
          results: results,
          similarResults: similarResults,
          keyword: keyword,
        );
      } else {
        return CategorySearchResponse(results: [], similarResults: []);
      }
    } catch (e) {
      return CategorySearchResponse(results: [], similarResults: []);
    }
  }
  
  /// Legacy method - returns combined results (exact + similar)
  /// For backwards compatibility
  Future<List<CategorySearchResult>> searchCategories(String keyword, {int limit = 20}) async {
    final response = await searchCategoriesWithSimilar(keyword, limit: limit);
    // Return exact matches first, then similar ones
    return [...response.results, ...response.similarResults];
  }
  
  List<CategorySearchResult> _parseSearchResults(List<dynamic> list) {
    return list.map((json) {
      final categoryJson = json['category'] as Map<String, dynamic>;
      final parentJson = json['parent_category'] as Map<String, dynamic>?;
      final isSubcategory = json['is_subcategory'] as bool? ?? false;
      
      return CategorySearchResult(
        category: ProductCategory.fromJson(categoryJson),
        parentCategory: parentJson != null ? ProductCategory.fromJson(parentJson) : null,
        isSubcategory: isSubcategory,
      );
    }).toList();
  }
}

/// Response from category search API with both exact and similar results
class CategorySearchResponse {
  final List<CategorySearchResult> results;
  final List<CategorySearchResult> similarResults;
  final String? keyword;
  
  const CategorySearchResponse({
    required this.results,
    required this.similarResults,
    this.keyword,
  });
  
  /// Check if there are any similar (fuzzy) matches
  bool get hasSimilarResults => similarResults.isNotEmpty;
  
  /// Get all results combined (exact first, then similar)
  List<CategorySearchResult> get allResults => [...results, ...similarResults];
  
  /// Total count of all results
  int get totalCount => results.length + similarResults.length;
}

/// Result from category search API
class CategorySearchResult {
  final ProductCategory category;
  final ProductCategory? parentCategory;
  final bool isSubcategory;

  const CategorySearchResult({
    required this.category,
    this.parentCategory,
    this.isSubcategory = false,
  });
}
