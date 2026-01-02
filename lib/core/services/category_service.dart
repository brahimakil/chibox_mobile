import 'package:flutter/foundation.dart';
import '../models/category_model.dart';
import 'api_service.dart';
import '../constants/api_constants.dart';

class CategoryService extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  
  List<ProductCategory> _categories = [];
  bool _isLoading = false;
  String? _error;
  int _currentPage = 1;
  bool _hasMore = true;
  static const int _perPage = 20;

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
      debugPrint('🚫 No more categories to load. Stopping.');
      return;
    }

    _isLoading = true;
    notifyListeners();

    debugPrint('📥 Fetching categories page $_currentPage...');

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
        
        debugPrint('✅ Received ${newCategories.length} categories');

        // Handle pagination
        if (data['pagination'] != null) {
          _hasMore = data['pagination']['has_next'] ?? false;
          debugPrint('📄 Pagination: has_next = $_hasMore');
        } else {
          // Fallback if pagination data is missing
          if (newCategories.length < _perPage) {
            _hasMore = false;
          }
          debugPrint('⚠️ No pagination data. Fallback has_next = $_hasMore');
        }
        
        if (refresh) {
          _categories = newCategories;
        } else {
          _categories.addAll(newCategories);
        }
        
        _currentPage++;
      } else {
        _error = response.message;
        debugPrint('❌ API Error: $_error');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('❌ Exception: $_error');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
