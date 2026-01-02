class Board {
  final int id;
  final String name;
  final int orderNumber;
  final int favoritesCount;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Board({
    required this.id,
    required this.name,
    required this.orderNumber,
    required this.favoritesCount,
    this.createdAt,
    this.updatedAt,
  });

  factory Board.fromJson(Map<String, dynamic> json) {
    return Board(
      id: json['id'] as int,
      name: json['name'] as String,
      orderNumber: json['order_number'] as int? ?? 0,
      favoritesCount: json['favorites_count'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : null,
    );
  }
}
