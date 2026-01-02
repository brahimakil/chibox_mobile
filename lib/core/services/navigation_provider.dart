import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  final List<int> _navigationHistory = [0]; // Start with home
  
  /// Selected category ID when navigating to Categories tab
  int? _selectedCategoryId;

  int get currentIndex => _currentIndex;
  int? get selectedCategoryId => _selectedCategoryId;

  /// Check if we can go back in navigation history
  bool get canGoBack => _navigationHistory.length > 1;

  /// Check if we're on home screen with no history
  bool get isAtRoot => _currentIndex == 0 && _navigationHistory.length <= 1;

  void setIndex(int index) {
    if (_currentIndex != index) {
      _currentIndex = index;
      // Add to history, but avoid duplicates at the end
      if (_navigationHistory.isEmpty || _navigationHistory.last != index) {
        _navigationHistory.add(index);
      }
      notifyListeners();
    }
  }

  /// Navigate to Categories tab with a specific category pre-selected
  void goToCategoriesWithSelection(int categoryId) {
    _selectedCategoryId = categoryId;
    setIndex(1); // Categories tab index
  }

  /// Clear the selected category (call after CategoriesScreen reads it)
  void clearSelectedCategory() {
    _selectedCategoryId = null;
  }

  /// Go back to the previous tab in history
  /// Returns true if navigation happened, false if at root
  bool goBack() {
    if (_navigationHistory.length > 1) {
      _navigationHistory.removeLast(); // Remove current
      _currentIndex = _navigationHistory.last;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Reset to home and clear history
  void resetToHome() {
    _currentIndex = 0;
    _navigationHistory.clear();
    _navigationHistory.add(0);
    notifyListeners();
  }
}
