import 'package:flutter/material.dart';

class NavigationProvider extends ChangeNotifier {
  int _currentIndex = 0;
  final List<int> _navigationHistory = [0]; // Start with home
  
  /// Selected category ID when navigating to Categories tab
  int? _selectedCategoryId;
  
  /// Flag to indicate search overlay should be closed
  bool _shouldCloseSearch = false;
  
  /// Flag to indicate home screen should reset (scroll to top, clear category)
  bool _shouldResetHome = false;
  
  /// Flag to indicate a category is selected in home screen (for back handling)
  bool _hasHomeCategorySelected = false;
  
  /// Callback to clear home category selection
  VoidCallback? _clearHomeCategoryCallback;

  int get currentIndex => _currentIndex;
  int? get selectedCategoryId => _selectedCategoryId;
  bool get shouldCloseSearch => _shouldCloseSearch;
  bool get shouldResetHome => _shouldResetHome;
  bool get hasHomeCategorySelected => _hasHomeCategorySelected;
  
  /// Register callback to clear home category (called by HomeScreen)
  void registerHomeCategoryClearCallback(VoidCallback callback) {
    _clearHomeCategoryCallback = callback;
  }
  
  /// Unregister callback (called when HomeScreen disposes)
  void unregisterHomeCategoryClearCallback() {
    _clearHomeCategoryCallback = null;
  }
  
  /// Set home category selected state (called by HomeScreen)
  void setHomeCategorySelected(bool selected) {
    if (_hasHomeCategorySelected != selected) {
      _hasHomeCategorySelected = selected;
      // Don't notify - this is just for back button handling
    }
  }
  
  /// Clear home category selection and return true if it was cleared
  bool clearHomeCategorySelection() {
    if (_hasHomeCategorySelected && _clearHomeCategoryCallback != null) {
      _clearHomeCategoryCallback!();
      _hasHomeCategorySelected = false;
      return true;
    }
    return false;
  }
  
  /// Consume the close search flag (returns value and resets it)
  bool consumeCloseSearchFlag() {
    final value = _shouldCloseSearch;
    _shouldCloseSearch = false;
    return value;
  }
  
  /// Consume the reset home flag (returns value and resets it)
  bool consumeResetHomeFlag() {
    final value = _shouldResetHome;
    _shouldResetHome = false;
    return value;
  }
  
  /// Request to close any active search overlay
  void requestCloseSearch() {
    _shouldCloseSearch = true;
    notifyListeners();
  }
  
  /// Request to reset home screen (scroll to top, clear category)
  void requestResetHome() {
    _shouldResetHome = true;
    notifyListeners();
  }

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
    } else if (index == 0) {
      // Already on home, request reset
      requestResetHome();
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
