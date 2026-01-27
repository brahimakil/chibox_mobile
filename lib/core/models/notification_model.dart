import 'package:equatable/equatable.dart';

/// Notification Types - matches backend Notifications::TYPE_* constants
class NotificationType {
  static const String order = 'order';
  static const String product = 'product';
  static const String category = 'category';
  static const String cart = 'cart';
  static const String web = 'web';
  static const String promo = 'promo';
  static const String shipping = 'shipping';
  static const String general = 'general';
}

/// Notification Model
/// Maps exactly to backend notification response
class AppNotification extends Equatable {
  final int id;
  final String subject;
  final String body;
  final bool isSeen;
  final int? tableId;
  final int? rowId;
  final String? notificationType; // Universal Navigation type
  final String? actionUrl;        // For web redirects
  final String? imageUrl;         // Optional notification image
  final DateTime createdAt;
  final DateTime? updatedAt;

  const AppNotification({
    required this.id,
    required this.subject,
    required this.body,
    required this.isSeen,
    this.tableId,
    this.rowId,
    this.notificationType,
    this.actionUrl,
    this.imageUrl,
    required this.createdAt,
    this.updatedAt,
  });

  /// Check if this notification has a navigation target
  bool get hasNavigationTarget => 
      notificationType != null && 
      notificationType != NotificationType.general &&
      (rowId != null || actionUrl != null);

  /// Get the target ID for navigation (order_id, product_id, etc.)
  int? get targetId => rowId;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as int,
      subject: json['subject'] as String? ?? '',
      body: json['body'] as String? ?? '',
      isSeen: json['is_seen'] == true || json['is_seen'] == 1,
      tableId: json['table_id'] as int?,
      rowId: json['row_id'] as int?,
      notificationType: json['notification_type'] as String?,
      actionUrl: json['action_url'] as String?,
      imageUrl: json['image_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null 
          ? DateTime.parse(json['updated_at'] as String) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject': subject,
      'body': body,
      'is_seen': isSeen,
      'table_id': tableId,
      'row_id': rowId,
      'notification_type': notificationType,
      'action_url': actionUrl,
      'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  AppNotification copyWith({
    int? id,
    String? subject,
    String? body,
    bool? isSeen,
    int? tableId,
    int? rowId,
    String? notificationType,
    String? actionUrl,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      subject: subject ?? this.subject,
      body: body ?? this.body,
      isSeen: isSeen ?? this.isSeen,
      tableId: tableId ?? this.tableId,
      rowId: rowId ?? this.rowId,
      notificationType: notificationType ?? this.notificationType,
      actionUrl: actionUrl ?? this.actionUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id, subject, body, isSeen, tableId, rowId, 
    notificationType, actionUrl, imageUrl, createdAt, updatedAt
  ];
}

/// Notification Pagination
class NotificationPagination {
  final int total;
  final int perPage;
  final int currentPage;
  final int lastPage;
  final int? from;
  final int? to;
  final int? nextPage;
  final int? prevPage;
  final bool hasNext;
  final bool hasPrev;
  final bool isFirstPage;
  final bool isLastPage;

  const NotificationPagination({
    required this.total,
    required this.perPage,
    required this.currentPage,
    required this.lastPage,
    this.from,
    this.to,
    this.nextPage,
    this.prevPage,
    required this.hasNext,
    required this.hasPrev,
    required this.isFirstPage,
    required this.isLastPage,
  });

  factory NotificationPagination.fromJson(Map<String, dynamic> json) {
    return NotificationPagination(
      total: json['total'] as int? ?? 0,
      perPage: json['per_page'] as int? ?? 20,
      currentPage: json['current_page'] as int? ?? 1,
      lastPage: json['last_page'] as int? ?? 1,
      from: json['from'] as int?,
      to: json['to'] as int?,
      nextPage: json['next_page'] as int?,
      prevPage: json['prev_page'] as int?,
      hasNext: json['has_next'] == true,
      hasPrev: json['has_prev'] == true,
      isFirstPage: json['is_first_page'] == true,
      isLastPage: json['is_last_page'] == true,
    );
  }

  static NotificationPagination empty() {
    return const NotificationPagination(
      total: 0,
      perPage: 20,
      currentPage: 1,
      lastPage: 1,
      hasNext: false,
      hasPrev: false,
      isFirstPage: true,
      isLastPage: true,
    );
  }
}
