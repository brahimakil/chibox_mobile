import 'package:flutter/foundation.dart';
import '../constants/api_constants.dart';
import '../models/notification_model.dart';
import 'api_service.dart';

/// Notification Service - Handles all notification-related API calls
/// Maps exactly to backend NotificationController endpoints
class NotificationService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  List<AppNotification> _notifications = [];
  NotificationPagination _pagination = NotificationPagination.empty();
  int _unreadCount = 0;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isMarkingAllRead = false; // NEW: Prevent concurrent operations
  String? _error;
  
  // Track last fetch time to prevent rapid re-fetches
  DateTime? _lastFetchTime;
  static const _minFetchInterval = Duration(seconds: 2);

  // Getters
  List<AppNotification> get notifications => _notifications;
  NotificationPagination get pagination => _pagination;
  int get unreadCount => _unreadCount;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get isMarkingAllRead => _isMarkingAllRead;
  String? get error => _error;
  bool get hasMore => _pagination.hasNext;

  /// Clear error state
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Fetch notifications with pagination
  /// Matches backend: GET /v3_0_0-notification/get-notifications
  Future<void> fetchNotifications({
    int page = 1,
    int perPage = 20,
    int? isSeen, // Optional filter: 0 = unread, 1 = read
    bool refresh = false,
    bool force = false, // Force fetch even if recently fetched
  }) async {
    // Prevent concurrent fetches and rapid re-fetches
    if (_isLoading || _isLoadingMore || _isMarkingAllRead) return;
    
    // Prevent rapid re-fetches unless forced
    if (!force && _lastFetchTime != null && !refresh) {
      final timeSinceLastFetch = DateTime.now().difference(_lastFetchTime!);
      if (timeSinceLastFetch < _minFetchInterval) {
        return;
      }
    }

    if (refresh) {
      _notifications = [];
      _pagination = NotificationPagination.empty();
      page = 1;
    }

    _isLoading = page == 1;
    _isLoadingMore = page > 1;
    _error = null; // Clear any previous error
    notifyListeners();

    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      
      if (isSeen != null) {
        queryParams['is_seen'] = isSeen;
      }

      final response = await _apiService.get(
        ApiConstants.getNotifications,
        queryParams: queryParams,
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        
        // Parse notifications
        final notificationsJson = data['notifications'] as List<dynamic>? ?? [];
        final newNotifications = notificationsJson
            .map((json) => AppNotification.fromJson(json as Map<String, dynamic>))
            .toList();

        // Parse pagination
        final paginationJson = data['pagination'] as Map<String, dynamic>? ?? {};
        _pagination = NotificationPagination.fromJson(paginationJson);
        
        // Update unread count from response
        _unreadCount = data['unread_count'] as int? ?? 0;

        // Append or replace
        if (page == 1) {
          _notifications = newNotifications;
        } else {
          _notifications.addAll(newNotifications);
        }

        _lastFetchTime = DateTime.now(); // Track successful fetch time
      } else {
        _error = response.message ?? 'Failed to load notifications';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  /// Load more notifications (pagination)
  Future<void> loadMore() async {
    if (_isLoadingMore || _isLoading || _isMarkingAllRead || !_pagination.hasNext) return;
    await fetchNotifications(page: _pagination.currentPage + 1, force: true);
  }

  /// Refresh notifications
  Future<void> refresh() async {
    if (_isMarkingAllRead) return; // Don't refresh while marking all as read
    await fetchNotifications(refresh: true, force: true);
  }

  /// Mark notification(s) as seen
  /// Matches backend: POST /v3_0_0-notification/mark-as-seen
  /// @param notificationIds - Single ID or list of IDs
  Future<bool> markAsSeen(dynamic notificationIds) async {
    if (_isMarkingAllRead) return false; // Don't allow while marking all
    
    try {
      final ids = notificationIds is List ? notificationIds : [notificationIds];
      
      // Optimistically update UI first
      _notifications = _notifications.map((n) {
        if (ids.contains(n.id) && !n.isSeen) {
          _unreadCount = (_unreadCount - 1).clamp(0, _unreadCount);
          return n.copyWith(isSeen: true);
        }
        return n;
      }).toList();
      notifyListeners();
      
      final response = await _apiService.post(
        ApiConstants.markAsSeen,
        body: {'notification_id': ids},
      );

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        _unreadCount = data['unread_count'] as int? ?? _unreadCount;
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Mark all notifications as seen
  /// Matches backend: POST /v3_0_0-notification/mark-all-as-seen
  Future<bool> markAllAsSeen() async {
    // Prevent concurrent operations
    if (_isMarkingAllRead || _isLoading || _isLoadingMore) {
      return false;
    }
    
    _isMarkingAllRead = true;
    _error = null; // Clear any existing error
    notifyListeners();
    
    try {
      // Optimistically update UI FIRST for instant feedback
      final previousUnreadCount = _unreadCount;
      final previousNotifications = List<AppNotification>.from(_notifications);
      
      _unreadCount = 0;
      _notifications = _notifications.map((n) => n.copyWith(isSeen: true)).toList();
      notifyListeners();
      
      final response = await _apiService.post(ApiConstants.markAllAsSeen);

      if (response.success) {
        return true;
      } else {
        // Revert on failure
        _unreadCount = previousUnreadCount;
        _notifications = previousNotifications;
        return false;
      }
    } catch (e) {
      // Don't set _error here - just return false and let UI handle it
      return false;
    } finally {
      _isMarkingAllRead = false;
      notifyListeners();
    }
  }

  /// Get unread notification count
  /// Matches backend: GET /v3_0_0-notification/get-unread-count
  Future<int> getUnreadCount() async {
    if (_isMarkingAllRead) return _unreadCount; // Don't fetch while marking
    
    try {
      final response = await _apiService.get(ApiConstants.getUnreadCount);

      if (response.success && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        _unreadCount = data['unread_count'] as int? ?? 0;
        notifyListeners();
        return _unreadCount;
      }
      return _unreadCount;
    } catch (e) {
      return _unreadCount;
    }
  }

  /// Clear all cached data
  void clear() {
    _notifications = [];
    _pagination = NotificationPagination.empty();
    _unreadCount = 0;
    _error = null;
    _isLoading = false;
    _isLoadingMore = false;
    _isMarkingAllRead = false;
    _lastFetchTime = null;
    notifyListeners();
  }
}
