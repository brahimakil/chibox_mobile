import 'package:equatable/equatable.dart';
import '../constants/api_constants.dart';
import '../utils/image_helper.dart';

/// Product Model
class Product extends Equatable {
  final int id;
  final String name;
  final String? displayName;
  final String? description;
  final String? slug;
  final String mainImage;
  final double price;
  final double? originalPrice;
  final String currencySymbol;
  final bool isLiked;
  final int cartQuantity;
  final List<ProductVariant>? variants;
  final List<String>? images;
  final double? rating;
  final int? reviewCount;
  final int? categoryId;
  final String? productCode;
  final String? originalName;
  final String? videoUrl;
  final List<ProductOption>? options;
  final List<String>? serviceTags;
  final List<Map<String, String>>? productProps;
  final List<Product>? relatedProducts;
  final int? favoriteId;

  const Product({
    required this.id,
    required this.name,
    this.displayName,
    this.description,
    this.slug,
    required this.mainImage,
    required this.price,
    this.originalPrice,
    this.currencySymbol = '\$',
    this.isLiked = false,
    this.cartQuantity = 0,
    this.variants,
    this.images,
    this.rating,
    this.reviewCount,
    this.categoryId,
    this.productCode,
    this.originalName,
    this.videoUrl,
    this.options,
    this.serviceTags,
    this.productProps,
    this.relatedProducts,
    this.favoriteId,
  });

  double? get discountPercentage {
    if (originalPrice != null && originalPrice! > price) {
      return ((originalPrice! - price) / originalPrice! * 100);
    }
    return null;
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as int,
      name: json['product_name'] ?? json['name'] ?? '',
      displayName: json['display_name'] as String?,
      description: json['description'] as String?,
      slug: json['slug'] as String?,
      mainImage: ImageHelper.parse(json['main_image']),
      price: _parseDouble(json['price']),
      originalPrice: json['original_price'] != null 
          ? _parseDouble(json['original_price']) 
          : null,
      currencySymbol: json['currency_symbol'] ?? '\$',
      isLiked: json['is_liked'] == true || json['is_liked'] == 1,
      cartQuantity: json['cart_quantity'] ?? 0,
      variants: (json['variants'] ?? json['variations']) != null
          ? ((json['variants'] ?? json['variations']) as List)
              .map((v) => ProductVariant.fromJson(v))
              .toList()
          : null,
      images: json['images'] != null
          ? (json['images'] as List).map((e) => ImageHelper.parse(e)).toList()
          : null,
      rating: json['rating'] != null ? _parseDouble(json['rating']) : null,
      reviewCount: json['review_count'] as int?,
      categoryId: json['category_id'] as int?,
      productCode: json['product_code'] as String?,
      originalName: json['original_name'] as String?,
      videoUrl: json['video_url'] as String?,
      options: json['options'] != null
          ? (json['options'] as List)
              .map((o) => ProductOption.fromJson(o))
              .toList()
          : null,
      serviceTags: json['service_tags'] != null
          ? (json['service_tags'] as List).cast<String>()
          : null,
      productProps: json['product_props'] != null
          ? (json['product_props'] as List).map((e) {
              final map = e as Map<String, dynamic>;
              return map.map((key, value) => MapEntry(key, value.toString()));
            }).toList()
          : null,
      relatedProducts: json['related_products'] != null
          ? (json['related_products'] as List)
              .map((p) => Product.fromJson(p))
              .toList()
          : null,
    );
  }

  static double _parseDouble(dynamic value) {
    if (value == null) return 0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }



  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'display_name': displayName,
      'description': description,
      'slug': slug,
      'main_image': mainImage,
      'price': price,
      'original_price': originalPrice,
      'currency_symbol': currencySymbol,
      'is_liked': isLiked,
      'cart_quantity': cartQuantity,
      'variants': variants?.map((v) => v.toJson()).toList(),
      'images': images,
      'rating': rating,
      'review_count': reviewCount,
      'category_id': categoryId,
      'product_code': productCode,
      'original_name': originalName,
      'video_url': videoUrl,
      'options': options?.map((o) => o.toJson()).toList(),
      'service_tags': serviceTags,
      'product_props': productProps,
      'related_products': relatedProducts?.map((p) => p.toJson()).toList(),
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? displayName,
    String? description,
    String? slug,
    String? mainImage,
    double? price,
    double? originalPrice,
    String? currencySymbol,
    bool? isLiked,
    int? cartQuantity,
    List<ProductVariant>? variants,
    List<String>? images,
    double? rating,
    int? reviewCount,
    String? productCode,
    String? originalName,
    String? videoUrl,
    List<ProductOption>? options,
    List<String>? serviceTags,
    List<Map<String, String>>? productProps,
    List<Product>? relatedProducts,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      displayName: displayName ?? this.displayName,
      description: description ?? this.description,
      slug: slug ?? this.slug,
      mainImage: mainImage ?? this.mainImage,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      isLiked: isLiked ?? this.isLiked,
      cartQuantity: cartQuantity ?? this.cartQuantity,
      variants: variants ?? this.variants,
      images: images ?? this.images,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      productCode: productCode ?? this.productCode,
      originalName: originalName ?? this.originalName,
      videoUrl: videoUrl ?? this.videoUrl,
      options: options ?? this.options,
      serviceTags: serviceTags ?? this.serviceTags,
      productProps: productProps ?? this.productProps,
      relatedProducts: relatedProducts ?? this.relatedProducts,
    );
  }

  @override
  List<Object?> get props => [id, name, mainImage, price, isLiked, cartQuantity];
}

/// Product Variant Model
class ProductVariant extends Equatable {
  final int id;
  final String name;
  final double price;
  final String? sku;
  final String? image;
  final int? stock;
  final String? propsIds;
  final String? status;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    this.sku,
    this.image,
    this.stock,
    this.propsIds,
    this.status,
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: json['id'] as int,
      name: json['name'] ?? json['variation_name'] ?? '',
      price: Product._parseDouble(json['price']),
      sku: json['sku'] ?? json['sku_id'] as String?,
      image: ImageHelper.parse(json['image'] ?? json['variation_image']),
      stock: json['stock'] as int?,
      propsIds: json['props_ids'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'sku': sku,
      'image': image,
      'stock': stock,
      'props_ids': propsIds,
      'status': status,
    };
  }

  @override
  List<Object?> get props => [id, name, price, sku, propsIds, status];
}

/// Product Option Model
class ProductOption extends Equatable {
  final int id;
  final String? pid; // 1688 Property ID
  final String name;
  final List<ProductOptionValue> values;

  const ProductOption({
    required this.id,
    this.pid,
    required this.name,
    required this.values,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      id: json['id'] as int,
      pid: json['pid']?.toString(),
      name: json['name'] as String,
      values: (json['values'] as List)
          .map((v) => ProductOptionValue.fromJson(v))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'pid': pid,
      'name': name,
      'values': values.map((v) => v.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [id, pid, name, values];
}

/// Product Option Value Model
class ProductOptionValue extends Equatable {
  final int id;
  final String? vid; // 1688 Value ID
  final String name;
  final String? imageUrl;
  final String? color;

  const ProductOptionValue({
    required this.id,
    required this.name,
    this.vid,
    this.imageUrl,
    this.color,
  });

  factory ProductOptionValue.fromJson(Map<String, dynamic> json) {
    return ProductOptionValue(
      id: json['id'] as int,
      name: json['name'] as String,
      vid: json['vid']?.toString(),
      imageUrl: ImageHelper.parse(json['image_url']),
      color: json['color'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'vid': vid,
      'image_url': imageUrl,
      'color': color,
    };
  }

  @override
  List<Object?> get props => [id, vid, name, imageUrl, color];
}

