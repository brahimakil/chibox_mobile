import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
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
    // Helper to check if a string contains Chinese characters
    bool containsChinese(String text) {
      return RegExp(r'[\u4e00-\u9fff]').hasMatch(text);
    }
    
    // Parse name with fallbacks - prioritize English text
    // Priority: title_en > product_name (non-Chinese) > display_name (non-Chinese) > name (non-Chinese)
    String name = '';
    
    // 1. First check title_en - this is the translated English name from backend
    if (json['title_en'] != null && json['title_en'].toString().trim().isNotEmpty) {
      final titleEn = json['title_en'].toString().trim();
      if (!containsChinese(titleEn)) {
        name = titleEn;
      }
    }
    // 2. Then check product_name (only if non-Chinese)
    if (name.isEmpty && json['product_name'] != null && json['product_name'].toString().trim().isNotEmpty) {
      final productName = json['product_name'].toString().trim();
      if (!containsChinese(productName)) {
        name = productName;
      }
    }
    // 3. Then check display_name (only if non-Chinese)
    if (name.isEmpty && json['display_name'] != null && json['display_name'].toString().trim().isNotEmpty) {
      final fallbackName = json['display_name'].toString().trim();
      if (!containsChinese(fallbackName)) {
        name = fallbackName;
      }
    }
    // 4. Finally check generic 'name' field (only if non-Chinese)
    if (name.isEmpty && json['name'] != null && json['name'].toString().trim().isNotEmpty) {
      final fallbackName = json['name'].toString().trim();
      if (!containsChinese(fallbackName)) {
        name = fallbackName;
      }
    }
    // Skip original_name fallback entirely as it's always Chinese from 1688
    // If no English name available, name stays empty - ProductCard handles this
    
    // Parse display_name (only if non-Chinese)
    String? displayName;
    if (json['display_name'] != null && json['display_name'].toString().trim().isNotEmpty) {
      final dn = json['display_name'].toString().trim();
      if (!containsChinese(dn)) {
        displayName = dn;
      }
    }
    // Check title_en as displayName fallback for related products
    if (displayName == null && json['title_en'] != null && json['title_en'].toString().trim().isNotEmpty) {
      final titleEn = json['title_en'].toString().trim();
      if (!containsChinese(titleEn)) {
        displayName = titleEn;
      }
    }
    
    // Parse originalName (Chinese) - check title_zh for related products
    String? originalName;
    if (json['original_name'] != null && json['original_name'].toString().trim().isNotEmpty) {
      originalName = json['original_name'].toString().trim();
    } else if (json['title_zh'] != null && json['title_zh'].toString().trim().isNotEmpty) {
      originalName = json['title_zh'].toString().trim();
    }
    
    // Parse variants first so we can use them for price fallback
    final variants = (json['variants'] ?? json['variations']) != null
        ? ((json['variants'] ?? json['variations']) as List)
            .map((v) => ProductVariant.fromJson(v))
            .toList()
        : null;
    
    // Parse price - ALWAYS prefer variant prices when available
    // Base product price is often outdated, variant prices are the actual purchasable prices
    double price = _parseDouble(json['price']);
    if (variants != null && variants.isNotEmpty) {
      // Get the minimum variant price that's greater than 0
      final variantPrices = variants
          .map((v) => v.price)
          .where((p) => p > 0)
          .toList();
      if (variantPrices.isNotEmpty) {
        variantPrices.sort();
        final minVariantPrice = variantPrices.first;
        // Always use variant price as it's the actual purchasable price
        if (minVariantPrice > 0) {
          price = minVariantPrice;
        }
      }
    }
    
    return Product(
      id: json['id'] as int,
      name: name,
      displayName: displayName,
      description: json['description'] as String?,
      slug: json['slug'] as String?,
      mainImage: ImageHelper.parse(json['main_image']),
      price: price,
      originalPrice: json['original_price'] != null 
          ? _parseDouble(json['original_price']) 
          : null,
      currencySymbol: json['currency_symbol'] ?? '\$',
      isLiked: json['is_liked'] == true || json['is_liked'] == 1,
      cartQuantity: json['cart_quantity'] ?? 0,
      variants: variants,
      images: json['images'] != null
          ? (json['images'] as List).map((e) => ImageHelper.parse(e)).toList()
          : null,
      rating: json['rating'] != null ? _parseDouble(json['rating']) : null,
      reviewCount: json['review_count'] as int?,
      categoryId: json['category_id'] as int?,
      productCode: json['product_code'] as String?,
      originalName: originalName,
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
    int? categoryId,
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
      categoryId: categoryId ?? this.categoryId,
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
  final List<SelectedOption>? selectedOptions;

  const ProductVariant({
    required this.id,
    required this.name,
    required this.price,
    this.sku,
    this.image,
    this.stock,
    this.propsIds,
    this.status,
    this.selectedOptions,
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
      selectedOptions: json['selected_options'] != null
          ? (json['selected_options'] as List)
              .map((o) => SelectedOption.fromJson(o))
              .toList()
          : null,
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
      'selected_options': selectedOptions?.map((o) => o.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [id, name, price, sku, propsIds, status, selectedOptions];
}

/// Selected Option for a Variant
class SelectedOption extends Equatable {
  final int optionId;
  final int valueId;
  final String? valueName;
  final String? imageUrl;

  const SelectedOption({
    required this.optionId,
    required this.valueId,
    this.valueName,
    this.imageUrl,
  });

  factory SelectedOption.fromJson(Map<String, dynamic> json) {
    return SelectedOption(
      optionId: json['option_id'] ?? json['r_product_option_id'] ?? 0,
      valueId: json['value_id'] ?? 0,
      valueName: json['value_name'] as String?,
      imageUrl: json['image_url'] != null ? ImageHelper.parse(json['image_url']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'option_id': optionId,
      'value_id': valueId,
      'value_name': valueName,
      'image_url': imageUrl,
    };
  }

  @override
  List<Object?> get props => [optionId, valueId, valueName, imageUrl];
}

/// Product Option Model
class ProductOption extends Equatable {
  final int id;
  final String? pid; // 1688 Property ID
  final String name;
  final bool isColor;
  final List<ProductOptionValue> values;

  const ProductOption({
    required this.id,
    this.pid,
    required this.name,
    this.isColor = false,
    required this.values,
  });

  factory ProductOption.fromJson(Map<String, dynamic> json) {
    return ProductOption(
      id: json['id'] as int,
      pid: json['pid']?.toString(),
      name: json['name'] as String,
      isColor: json['is_color'] == true || json['is_color'] == 1,
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
      'is_color': isColor,
      'values': values.map((v) => v.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [id, pid, name, isColor, values];
}

/// Product Option Value Model
class ProductOptionValue extends Equatable {
  final int id;
  final String? vid; // 1688 Value ID
  final String name;
  final String? imageUrl;
  final String? color;
  final bool isColor;

  const ProductOptionValue({
    required this.id,
    required this.name,
    this.vid,
    this.imageUrl,
    this.color,
    this.isColor = false,
  });

  factory ProductOptionValue.fromJson(Map<String, dynamic> json) {
    return ProductOptionValue(
      id: json['id'] as int,
      name: json['name'] as String,
      vid: json['vid']?.toString(),
      imageUrl: ImageHelper.parse(json['image_url']),
      color: json['color'] as String?,
      isColor: json['is_color'] == true || json['is_color'] == 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'vid': vid,
      'image_url': imageUrl,
      'color': color,
      'is_color': isColor,
    };
  }

  @override
  List<Object?> get props => [id, vid, name, imageUrl, color, isColor];
}

