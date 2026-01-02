import 'package:equatable/equatable.dart';
import 'package:chihelo_frontend/core/utils/image_helper.dart';

/// Category Model
class ProductCategory extends Equatable {
  final int id;
  final String name;
  final String? nameEn;
  final String? nameZh;
  final String? slug;
  final String? mainImage;
  final int? parentId;
  final bool showInNavbar;
  final bool display;
  final int subcategoriesCount;
  final List<ProductCategory>? subcategories;

  const ProductCategory({
    required this.id,
    required this.name,
    this.nameEn,
    this.nameZh,
    this.slug,
    this.mainImage,
    this.parentId,
    this.showInNavbar = true,
    this.display = true,
    this.subcategoriesCount = 0,
    this.subcategories,
  });

  bool get hasSubcategories => subcategoriesCount > 0 || (subcategories?.isNotEmpty ?? false);

  ProductCategory copyWith({
    int? id,
    String? name,
    String? nameEn,
    String? nameZh,
    String? slug,
    String? mainImage,
    int? parentId,
    bool? showInNavbar,
    bool? display,
    int? subcategoriesCount,
    List<ProductCategory>? subcategories,
  }) {
    return ProductCategory(
      id: id ?? this.id,
      name: name ?? this.name,
      nameEn: nameEn ?? this.nameEn,
      nameZh: nameZh ?? this.nameZh,
      slug: slug ?? this.slug,
      mainImage: mainImage ?? this.mainImage,
      parentId: parentId ?? this.parentId,
      showInNavbar: showInNavbar ?? this.showInNavbar,
      display: display ?? this.display,
      subcategoriesCount: subcategoriesCount ?? this.subcategoriesCount,
      subcategories: subcategories ?? this.subcategories,
    );
  }

  factory ProductCategory.fromJson(Map<String, dynamic> json) {
    return ProductCategory(
      id: json['id'] as int,
      name: json['category_name'] ?? json['name'] ?? '',
      nameEn: json['category_name_en'] as String?,
      nameZh: json['category_name_zh'] as String?,
      slug: json['slug'] as String?,
      mainImage: ImageHelper.parse(json['main_image']),
      parentId: json['parent'] as int?,
      showInNavbar: _parseBool(json['show_in_navbar'], defaultValue: true),
      display: _parseBool(json['display'], defaultValue: true),
      subcategoriesCount: json['subcategories_count'] ?? 0,
      subcategories: (json['subcategories'] ?? json['children']) != null
          ? ((json['subcategories'] ?? json['children']) as List)
              .map((s) => ProductCategory.fromJson(s))
              .toList()
          : null,
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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category_name': name,
      'category_name_en': nameEn,
      'category_name_zh': nameZh,
      'slug': slug,
      'main_image': mainImage,
      'parent': parentId,
      'show_in_navbar': showInNavbar,
      'display': display,
      'subcategories_count': subcategoriesCount,
      'subcategories': subcategories?.map((s) => s.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [id, name, slug, mainImage, parentId];
}

