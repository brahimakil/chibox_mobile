import 'package:chihelo_frontend/core/utils/image_helper.dart';

class CartItem {
  final int id;
  final int productId;
  final int? variantId;
  final int quantity;
  final String productName;
  final String slug;
  final String mainImage;
  final String? variationName;
  final String? propsIds;
  final String? skuId;
  final double price;
  final String currencySymbol;
  final double taxAmount;
  final double subtotal;

  CartItem({
    required this.id,
    required this.productId,
    this.variantId,
    required this.quantity,
    required this.productName,
    required this.slug,
    required this.mainImage,
    this.variationName,
    this.propsIds,
    this.skuId,
    required this.price,
    required this.currencySymbol,
    required this.taxAmount,
    required this.subtotal,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    // Parse product name with fallbacks
    String productName = '';
    if (json['product_name'] != null && json['product_name'].toString().trim().isNotEmpty) {
      productName = json['product_name'].toString().trim();
    } else if (json['name'] != null && json['name'].toString().trim().isNotEmpty) {
      productName = json['name'].toString().trim();
    } else if (json['display_name'] != null && json['display_name'].toString().trim().isNotEmpty) {
      productName = json['display_name'].toString().trim();
    } else if (json['original_name'] != null && json['original_name'].toString().trim().isNotEmpty) {
      productName = json['original_name'].toString().trim();
    } else {
      productName = 'Product #${json['product_id'] ?? json['id'] ?? ''}';
    }
    
    return CartItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      productId: json['product_id'] is int ? json['product_id'] : int.parse(json['product_id'].toString()),
      variantId: json['variant_id'] != null 
          ? (json['variant_id'] is int ? json['variant_id'] : int.parse(json['variant_id'].toString())) 
          : null,
      quantity: json['quantity'] is int ? json['quantity'] : int.parse(json['quantity'].toString()),
      productName: productName,
      slug: json['slug'] ?? '',
      mainImage: ImageHelper.parse(json['main_image']),
      variationName: json['variation_name'],
      propsIds: json['props_ids'],
      skuId: json['sku_id'],
      price: json['price'] is num ? (json['price'] as num).toDouble() : double.parse(json['price'].toString()),
      currencySymbol: json['currency_symbol'] ?? '\$',
      taxAmount: json['tax_amount'] is num ? (json['tax_amount'] as num).toDouble() : double.tryParse(json['tax_amount']?.toString() ?? '0') ?? 0.0,
      subtotal: json['subtotal'] is num ? (json['subtotal'] as num).toDouble() : double.parse(json['subtotal'].toString()),
    );
  }
}

class CartData {
  final List<CartItem> items;
  final int totalItems;
  final int totalQuantity;
  final double subtotal;
  final double totalTax;
  final double total;
  final String currencySymbol;

  CartData({
    required this.items,
    required this.totalItems,
    required this.totalQuantity,
    required this.subtotal,
    required this.totalTax,
    required this.total,
    required this.currencySymbol,
  });

  factory CartData.fromJson(Map<String, dynamic> json) {
    return CartData(
      items: (json['cart_items'] as List?)
              ?.map((item) => CartItem.fromJson(item))
              .toList() ??
          [],
      totalItems: json['total_items'] is int ? json['total_items'] : int.parse(json['total_items'].toString()),
      totalQuantity: json['total_quantity'] is int ? json['total_quantity'] : int.parse(json['total_quantity'].toString()),
      subtotal: json['subtotal'] is num ? (json['subtotal'] as num).toDouble() : double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      totalTax: json['total_tax'] is num ? (json['total_tax'] as num).toDouble() : double.tryParse(json['total_tax']?.toString() ?? '0') ?? 0.0,
      total: json['total'] is num ? (json['total'] as num).toDouble() : double.parse(json['total'].toString()),
      currencySymbol: json['currency_symbol'] ?? '\$',
    );
  }
}
