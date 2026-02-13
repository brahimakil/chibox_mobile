/// Order Status Constants (matching backend)
class OrderStatus {
  static const int pending = 9;
  static const int confirmed = 1;
  static const int processing = 2;
  static const int shipped = 3;
  static const int delivered = 4;
  static const int cancelled = 5;
  static const int refunded = 6;
  static const int failed = 7;
  static const int onHold = 8;
  
  static String getName(int status) {
    switch (status) {
      case pending: return 'Pending';
      case confirmed: return 'Confirmed';
      case processing: return 'Processing';
      case shipped: return 'Shipped';
      case delivered: return 'Delivered';
      case cancelled: return 'Cancelled';
      case refunded: return 'Refunded';
      case failed: return 'Failed';
      case onHold: return 'On Hold';
      default: return 'Unknown';
    }
  }
}

/// Payment Type Constants (matching backend)
class PaymentType {
  static const int cash = 1;
  static const int card = 2;
  static const int paypal = 3;
  static const int stripe = 4;
  static const int online = 5;
  static const int whishMoney = 6;
  
  static String getName(int type) {
    switch (type) {
      case cash: return 'Cash on Delivery';
      case card: return 'Credit/Debit Card';
      case paypal: return 'PayPal';
      case stripe: return 'Stripe';
      case online: return 'Online Payment';
      case whishMoney: return 'Whish Money';
      default: return 'Unknown';
    }
  }
}

/// Shipping Status Constants (Deferred Payment - matching backend)
class ShippingStatus {
  static const int pendingCalculation = 0; // AI estimated, awaiting Admin confirmation
  static const int readyToPay = 1;         // Admin confirmed price, user can pay
  static const int paid = 2;               // Shipping fully paid
  
  static String getName(int status) {
    switch (status) {
      case pendingCalculation: return 'Pending Review';
      case readyToPay: return 'Ready to Pay';
      case paid: return 'Paid';
      default: return 'Unknown';
    }
  }
  
  static String getDescription(int status) {
    switch (status) {
      case pendingCalculation: return 'Shipping cost is being calculated';
      case readyToPay: return 'Shipping confirmed. Tap to pay.';
      case paid: return 'Shipping paid';
      default: return '';
    }
  }
}

/// Order Summary Model (for list view)
class OrderSummary {
  final int id;
  final String orderNumber;
  final String status;
  final int statusId;
  final double total;
  final String currencySymbol;
  final int quantity;
  final int isPaid;
  final String paymentType;
  final String createdAt;
  final String? updatedAt;

  OrderSummary({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusId,
    required this.total,
    required this.currencySymbol,
    required this.quantity,
    required this.isPaid,
    required this.paymentType,
    required this.createdAt,
    this.updatedAt,
  });

  factory OrderSummary.fromJson(Map<String, dynamic> json) {
    return OrderSummary(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'Unknown',
      statusId: json['status_id'] ?? 0,
      total: (json['total'] ?? 0).toDouble(),
      currencySymbol: json['currency_symbol'] ?? '\$',
      quantity: json['quantity'] ?? 0,
      isPaid: json['is_paid'] ?? 0,
      paymentType: json['payment_type'] ?? 'Unknown',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'],
    );
  }
}

/// Order Address Model
class OrderAddress {
  final String firstName;
  final String lastName;
  final String countryCode;
  final String phoneNumber;
  final String address;
  final String country;
  final String city;
  final String? state;
  final String routeName;
  final String buildingName;
  final int floorNumber;

  OrderAddress({
    required this.firstName,
    required this.lastName,
    required this.countryCode,
    required this.phoneNumber,
    required this.address,
    required this.country,
    required this.city,
    this.state,
    required this.routeName,
    required this.buildingName,
    required this.floorNumber,
  });

  factory OrderAddress.fromJson(Map<String, dynamic> json) {
    return OrderAddress(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      countryCode: json['country_code'] ?? '',
      phoneNumber: json['phone_number'] ?? '',
      address: json['address'] ?? '',
      country: json['country'] ?? '',
      city: json['city'] ?? '',
      state: json['state'],
      routeName: json['route_name'] ?? '',
      buildingName: json['building_name'] ?? '',
      floorNumber: json['floor_number'] ?? 0,
    );
  }

  String get fullName => '$firstName $lastName';
  String get fullPhone => '+$countryCode $phoneNumber';
  String get fullAddress => '$address, $buildingName, Floor $floorNumber, $routeName, $city, $country';
}

/// Order Product Variation Model
class OrderProductVariation {
  final String optionName;
  final String valueName;
  final int isColor;
  final String? color;
  final String? imageUrl;
  final String? pid;
  final String? vid;

  OrderProductVariation({
    required this.optionName,
    required this.valueName,
    required this.isColor,
    this.color,
    this.imageUrl,
    this.pid,
    this.vid,
  });

  factory OrderProductVariation.fromJson(Map<String, dynamic> json) {
    return OrderProductVariation(
      optionName: json['option_name'] ?? '',
      valueName: json['value_name'] ?? '',
      isColor: json['is_color'] ?? 0,
      color: json['color'],
      imageUrl: json['image_url'],
      pid: json['pid'],
      vid: json['vid'],
    );
  }
}

/// Order Product Model
class OrderProduct {
  final int id;
  final int productId;
  final String productCode;
  final String productName;
  final String? sourceProductId;
  final String? skuId;
  final String? variationName;
  final String? propsIds;
  final String? mainImage;
  final String? variationImage;
  final int quantity;
  final double price;
  final double total;
  final List<OrderProductVariation> variations;

  OrderProduct({
    required this.id,
    required this.productId,
    required this.productCode,
    required this.productName,
    this.sourceProductId,
    this.skuId,
    this.variationName,
    this.propsIds,
    this.mainImage,
    this.variationImage,
    required this.quantity,
    required this.price,
    required this.total,
    required this.variations,
  });

  factory OrderProduct.fromJson(Map<String, dynamic> json) {
    // Parse product name with fallbacks (same as CartItem)
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
    
    return OrderProduct(
      id: json['id'] ?? 0,
      productId: json['product_id'] ?? 0,
      productCode: json['product_code'] ?? '',
      productName: productName,
      sourceProductId: json['source_product_id'],
      skuId: json['sku_id'],
      variationName: json['variation_name'],
      propsIds: json['props_ids'],
      mainImage: json['main_image'],
      variationImage: json['variation_image'],
      quantity: json['quantity'] ?? 0,
      price: (json['price'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      variations: (json['variations'] as List<dynamic>?)
              ?.map((v) => OrderProductVariation.fromJson(v))
              .toList() ??
          [],
    );
  }

  /// Get the display image (variation image first, then main image)
  String? get displayImage => variationImage ?? mainImage;
}

/// Order Tracking Model
class OrderTracking {
  final String status;
  final int statusId;
  final String date;

  OrderTracking({
    required this.status,
    required this.statusId,
    required this.date,
  });

  factory OrderTracking.fromJson(Map<String, dynamic> json) {
    return OrderTracking(
      status: json['status'] ?? 'Unknown',
      statusId: json['status_id'] ?? 0,
      date: json['date'] ?? '',
    );
  }
}

/// Full Order Details Model
class OrderDetails {
  final int id;
  final String orderNumber;
  final String status;
  final int statusId;
  final double subtotal;
  final double shippingAmount;
  final String? shippingMethod; // 'air' or 'sea'
  final int shippingStatus; // 0: Pending, 1: Ready to Pay, 2: Paid
  final String? shippingPaymentId;
  final double taxAmount;
  final double discountAmount;
  final bool isFirstOrderDiscount;
  final double total;
  final int currencyId;
  final String currencySymbol;
  final int quantity;
  final int isPaid;
  final String paymentType;
  final int paymentTypeId;
  final String? paymentId;
  final OrderAddress address;
  final String? clientNotes;
  final String createdAt;
  final String? updatedAt;
  final List<OrderProduct> products;
  final List<OrderTracking> tracking;

  OrderDetails({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.statusId,
    required this.subtotal,
    required this.shippingAmount,
    this.shippingMethod,
    required this.shippingStatus,
    this.shippingPaymentId,
    required this.taxAmount,
    required this.discountAmount,
    this.isFirstOrderDiscount = false,
    required this.total,
    required this.currencyId,
    required this.currencySymbol,
    required this.quantity,
    required this.isPaid,
    required this.paymentType,
    required this.paymentTypeId,
    this.paymentId,
    required this.address,
    this.clientNotes,
    required this.createdAt,
    this.updatedAt,
    required this.products,
    required this.tracking,
  });

  factory OrderDetails.fromJson(Map<String, dynamic> json) {
    return OrderDetails(
      id: json['id'] ?? 0,
      orderNumber: json['order_number'] ?? '',
      status: json['status'] ?? 'Unknown',
      statusId: json['status_id'] ?? 0,
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      shippingAmount: (json['shipping_amount'] ?? 0).toDouble(),
      shippingMethod: json['shipping_method'],
      shippingStatus: json['shipping_status'] ?? 0,
      shippingPaymentId: json['shipping_payment_id'],
      taxAmount: (json['tax_amount'] ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      isFirstOrderDiscount: json['first_order_discount'] ?? false,
      total: (json['total'] ?? 0).toDouble(),
      currencyId: json['currency_id'] ?? 6,
      currencySymbol: json['currency_symbol'] ?? '\$',
      quantity: json['quantity'] ?? 0,
      isPaid: json['is_paid'] ?? 0,
      paymentType: json['payment_type'] ?? 'Unknown',
      paymentTypeId: json['payment_type_id'] ?? 0,
      paymentId: json['payment_id'],
      address: OrderAddress.fromJson(json['address'] ?? {}),
      clientNotes: json['client_notes'],
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'],
      products: (json['products'] as List<dynamic>?)
              ?.map((p) => OrderProduct.fromJson(p))
              .toList() ??
          [],
      tracking: (json['tracking'] as List<dynamic>?)
              ?.map((t) => OrderTracking.fromJson(t))
              .toList() ??
          [],
    );
  }
  
  /// Get human readable shipping method name
  String get shippingMethodName {
    switch (shippingMethod) {
      case 'air': return 'Air Freight ✈️';
      case 'sea': return 'Sea Freight 🚢';
      case 'both': return 'Air & Sea ✈️🚢';
      default: return 'Standard';
    }
  }

  /// Check if order can be cancelled
  bool get canCancel =>
      statusId == OrderStatus.pending ||
      statusId == OrderStatus.confirmed ||
      statusId == OrderStatus.processing;
  
  /// Check if shipping payment is pending review (Admin hasn't confirmed yet)
  bool get isShippingPendingReview => shippingStatus == ShippingStatus.pendingCalculation;
  
  /// Check if shipping is ready to be paid by user
  bool get isShippingReadyToPay => shippingStatus == ShippingStatus.readyToPay;
  
  /// Check if shipping has been paid
  bool get isShippingPaid => shippingStatus == ShippingStatus.paid;
  
  /// Get the amount user paid for products (total minus shipping)
  double get productAmountPaid => total - shippingAmount;
  
  /// Get shipping status name
  String get shippingStatusName => ShippingStatus.getName(shippingStatus);
}
