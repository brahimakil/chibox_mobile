import 'package:chihelo_frontend/core/utils/image_helper.dart';
import 'category_model.dart' show ProductCategory;
import 'product_model.dart';

/// Home Screen Data Model
class HomeData {
  final List<HomeBanner> banners;
  final List<GridElement> gridElements;
  final List<ProductCategory> categories;
  final List<ProductSection> productSections;
  final List<Product> randomProducts;
  final List<FlashSale> flashSales;
  final List<Product> hotSellings; // Hot selling products with SHEIN-like rotation
  final List<Product> oneDollarProducts; // Products priced $1 or less
  final PaginationInfo pagination;

  const HomeData({
    this.banners = const [],
    this.gridElements = const [],
    this.categories = const [],
    this.productSections = const [],
    this.randomProducts = const [],
    this.flashSales = const [],
    this.hotSellings = const [],
    this.oneDollarProducts = const [],
    required this.pagination,
  });

  // Backward compatibility getter
  FlashSale? get flashSale => flashSales.isNotEmpty ? flashSales.first : null;

  factory HomeData.fromJson(Map<String, dynamic> json) {
    // Handle random_products which might be a list or a paginated object
    List<Product> parsedRandomProducts = [];
    PaginationInfo parsedPagination = const PaginationInfo();

    if (json['random_products'] != null) {
      if (json['random_products'] is List) {
        parsedRandomProducts = (json['random_products'] as List)
            .map((p) => Product.fromJson(p))
            .toList();
      } else if (json['random_products'] is Map) {
        final rpMap = json['random_products'] as Map<String, dynamic>;
        if (rpMap['data'] != null && rpMap['data'] is List) {
           parsedRandomProducts = (rpMap['data'] as List)
              .map((p) => Product.fromJson(p))
              .toList();
        } else if (rpMap['products'] != null && rpMap['products'] is List) {
           parsedRandomProducts = (rpMap['products'] as List)
              .map((p) => Product.fromJson(p))
              .toList();
        }
        
        // Try to extract pagination from random_products object
        if (rpMap['pagination'] != null) {
          parsedPagination = PaginationInfo.fromJson(rpMap['pagination']);
        } else {
          // Fallback if pagination fields are directly in random_products
          parsedPagination = PaginationInfo.fromJson(rpMap);
        }
      }
    }

    // Handle flash_sales (list)
    List<FlashSale> parsedFlashSales = [];
    if (json['flash_sales'] != null && json['flash_sales'] is List) {
      parsedFlashSales = (json['flash_sales'] as List)
          .map((f) => FlashSale.fromJson(f))
          .toList();
    } else if (json['flash_sale'] != null) {
      // Handle legacy single flash_sale field
      parsedFlashSales = [FlashSale.fromJson(json['flash_sale'])];
    }

    // Handle hot_sellings (list of hot selling products with SHEIN-like rotation)
    List<Product> parsedHotSellings = [];
    if (json['hot_sellings'] != null && json['hot_sellings'] is List) {
      parsedHotSellings = (json['hot_sellings'] as List)
          .map((p) => Product.fromJson(p))
          .toList();
    }

    // Handle one_dollar_products (products priced $1 or less)
    List<Product> parsedOneDollarProducts = [];
    if (json['one_dollar_products'] != null && json['one_dollar_products'] is List) {
      parsedOneDollarProducts = (json['one_dollar_products'] as List)
          .map((p) => Product.fromJson(p))
          .toList();
    }

    return HomeData(
      banners: json['banners'] != null 
          ? (json['banners'] as List).map((b) => HomeBanner.fromJson(b)).toList() 
          : [],
      gridElements: json['grid_elements'] != null
          ? (json['grid_elements'] as List).map((g) => GridElement.fromJson(g)).toList()
          : [],
      categories: json['categories'] != null
          ? (json['categories'] as List).map((c) => ProductCategory.fromJson(c)).toList()
          : [],
      productSections: json['product_sections'] != null
          ? (json['product_sections'] as List)
              .map((s) => ProductSection.fromJson(s))
              .toList()
          : [],
      randomProducts: parsedRandomProducts,
      flashSales: parsedFlashSales,
      hotSellings: parsedHotSellings,
      oneDollarProducts: parsedOneDollarProducts,
      pagination: parsedPagination,
    );
  }
}

/// Grid Element Model (Mobile Banners)
class GridElement {
  final int id;
  final int gridId;
  final int positionX;
  final int positionY;
  final int width;
  final int height;
  final String imageUrl;
  final Map<String, dynamic>? actions;

  const GridElement({
    required this.id,
    required this.gridId,
    required this.positionX,
    required this.positionY,
    required this.width,
    required this.height,
    required this.imageUrl,
    this.actions,
  });

  factory GridElement.fromJson(Map<String, dynamic> json) {
    return GridElement(
      id: _parseInt(json['id']),
      gridId: _parseInt(json['grid_id']),
      positionX: _parseInt(json['position_x']),
      positionY: _parseInt(json['position_y']),
      width: _parseInt(json['width']),
      height: _parseInt(json['height']),
      imageUrl: ImageHelper.parse(json['image']),
      actions: json['actions'] is Map ? json['actions'] as Map<String, dynamic> : null,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }
}

/// Banner Model
class HomeBanner {
  final int id;
  final String imageUrl;
  final String? title;
  final String? subtitle;
  final String? buttonText;
  final String? linkType;
  final int? linkId;
  final String? linkUrl;

  const HomeBanner({
    required this.id,
    required this.imageUrl,
    this.title,
    this.subtitle,
    this.buttonText,
    this.linkType,
    this.linkId,
    this.linkUrl,
  });

  factory HomeBanner.fromJson(Map<String, dynamic> json) {
    // Handle actions from grid_elements
    String? linkType;
    int? linkId;
    String? linkUrl;
    
    if (json['actions'] != null) {
      if (json['actions'] is Map) {
        final actions = json['actions'] as Map<String, dynamic>;
        linkType = actions['type'] as String?;
        linkId = actions['id'] is int ? actions['id'] : int.tryParse(actions['id']?.toString() ?? '');
        linkUrl = actions['url'] as String?;
      } else if (json['actions'] is List && (json['actions'] as List).isNotEmpty) {
        // If actions is a list, take the first one
        final action = (json['actions'] as List).first;
        if (action is Map) {
           linkType = action['type'] as String?;
           linkId = action['id'] is int ? action['id'] : int.tryParse(action['id']?.toString() ?? '');
           linkUrl = action['url'] as String?;
        }
      }
    }

    return HomeBanner(
      id: _parseInt(json['id']),
      imageUrl: ImageHelper.parse(json['image_url'] ?? json['image']),
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      buttonText: json['button_text'] as String?,
      linkType: linkType ?? json['link_type'] as String?,
      linkId: linkId ?? _parseInt(json['link_id']),
      linkUrl: linkUrl ?? json['link_url'] as String?,
    );
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }
}

/// Product Section Model
class ProductSection {
  final int id;
  final String title;
  final String? subtitle;
  final String sectionType;
  final List<Product> products;
  final int? categoryId;
  final String? sliderType;

  const ProductSection({
    required this.id,
    required this.title,
    this.subtitle,
    required this.sectionType,
    this.products = const [],
    this.categoryId,
    this.sliderType,
  });

  factory ProductSection.fromJson(Map<String, dynamic> json) {
    return ProductSection(
      id: json['id'] as int,
      title: json['title'] ?? json['section_title'] ?? '',
      subtitle: json['subtitle'] as String?,
      sectionType: json['section_type'] ?? 'products',
      products: json['products'] != null
          ? (json['products'] as List).map((p) => Product.fromJson(p)).toList()
          : [],
      categoryId: json['category_id'] as int?,
      sliderType: json['slider_type']?.toString(),
    );
  }
}

/// Flash Sale Model
class FlashSale {
  final int id;
  final String title;
  final DateTime? startTime;
  final DateTime endTime;
  final List<Product> products;
  final String? color1;
  final String? color2;
  final String? color3;
  final double? discount;
  final String? sliderType;

  const FlashSale({
    required this.id,
    required this.title,
    this.startTime,
    required this.endTime,
    this.products = const [],
    this.color1,
    this.color2,
    this.color3,
    this.discount,
    this.sliderType,
  });

  bool get isActive {
    final now = DateTime.now();
    if (startTime != null && now.isBefore(startTime!)) return false;
    return now.isBefore(endTime);
  }

  Duration get timeRemaining {
    final now = DateTime.now();
    if (now.isBefore(endTime)) {
      return endTime.difference(now);
    }
    return Duration.zero;
  }

  factory FlashSale.fromJson(Map<String, dynamic> json) {
    return FlashSale(
      id: json['id'] as int? ?? 0,
      title: json['title'] ?? 'Flash Sale',
      startTime: json['start_time'] != null ? DateTime.tryParse(json['start_time']) : null,
      endTime: json['end_time'] != null 
          ? (DateTime.tryParse(json['end_time']) ?? DateTime.now()) 
          : DateTime.now(),
      products: json['products'] != null
          ? (json['products'] as List).map((p) => Product.fromJson(p)).toList()
          : [],
      color1: json['color_1'],
      color2: json['color_2'],
      color3: json['color_3'],
      discount: json['discount'] != null ? (json['discount'] as num).toDouble() : null,
      sliderType: json['slider_type']?.toString(),
    );
  }
}

/// Pagination Info Model
class PaginationInfo {
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

  const PaginationInfo({
    this.total = 0,
    this.perPage = 20,
    this.currentPage = 1,
    this.lastPage = 1,
    this.from,
    this.to,
    this.nextPage,
    this.prevPage,
    this.hasNext = false,
    this.hasPrev = false,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      total: json['total'] ?? 0,
      perPage: json['per_page'] ?? 20,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
      from: json['from'] as int?,
      to: json['to'] as int?,
      nextPage: json['next_page'] as int?,
      prevPage: json['prev_page'] as int?,
      hasNext: _parseBool(json['has_next'], defaultValue: false),
      hasPrev: _parseBool(json['has_prev'], defaultValue: false),
    );
  }

  /// Helper to parse boolean from int or bool
  static bool _parseBool(dynamic value, {bool defaultValue = false}) {
    if (value == null) return defaultValue;
    if (value is bool) return value;
    if (value is int) return value == 1;
    if (value is String) return value == '1' || value.toLowerCase() == 'true';
    return defaultValue;
  }
}

/// Badge Count Model (for navbar badges)
class BadgeCount {
  final int cartCount;
  final int favoritesCount;
  final int ordersCount;
  final int activeOrdersCount;
  final int notificationsCount;
  final int unreadNotificationsCount;

  const BadgeCount({
    this.cartCount = 0,
    this.favoritesCount = 0,
    this.ordersCount = 0,
    this.activeOrdersCount = 0,
    this.notificationsCount = 0,
    this.unreadNotificationsCount = 0,
  });

  factory BadgeCount.fromJson(Map<String, dynamic> json) {
    return BadgeCount(
      cartCount: json['cart_count'] ?? 0,
      favoritesCount: json['favorites_count'] ?? 0,
      ordersCount: json['orders_count'] ?? 0,
      activeOrdersCount: json['active_orders_count'] ?? 0,
      notificationsCount: json['notifications_count'] ?? 0,
      unreadNotificationsCount: json['unread_notifications_count'] ?? 0,
    );
  }
}

