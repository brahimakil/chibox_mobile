/// Invoice Model for ChiHelo App
/// Matches the backend Invoice PHP model

class InvoiceItem {
  final String productName;
  final String? productCode;
  final String? variationName;
  final String? mainImage;
  final int quantity;
  final double unitPrice;
  final double total;

  InvoiceItem({
    required this.productName,
    this.productCode,
    this.variationName,
    this.mainImage,
    required this.quantity,
    required this.unitPrice,
    required this.total,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      productName: json['product_name'] ?? 'Unknown',
      productCode: json['product_code'],
      variationName: json['variation_name'],
      mainImage: json['main_image'],
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

class InvoiceBillingAddress {
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? address;
  final String? city;
  final String? country;
  final String? state;
  final String? routeName;
  final String? buildingName;
  final String? floorNumber;

  InvoiceBillingAddress({
    this.firstName,
    this.lastName,
    this.phone,
    this.address,
    this.city,
    this.country,
    this.state,
    this.routeName,
    this.buildingName,
    this.floorNumber,
  });

  factory InvoiceBillingAddress.fromJson(Map<String, dynamic> json) {
    return InvoiceBillingAddress(
      firstName: json['first_name']?.toString(),
      lastName: json['last_name']?.toString(),
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      state: json['state']?.toString(),
      routeName: json['route_name']?.toString(),
      buildingName: json['building_name']?.toString(),
      floorNumber: json['floor_number']?.toString(),
    );
  }

  String get fullName => '${firstName ?? ''} ${lastName ?? ''}'.trim();

  String get formattedAddress {
    final parts = <String>[];
    if (address != null && address!.isNotEmpty) parts.add(address!);
    if (buildingName != null && buildingName!.isNotEmpty) parts.add(buildingName!);
    if (routeName != null && routeName!.isNotEmpty) parts.add(routeName!);
    if (floorNumber != null && floorNumber!.isNotEmpty) parts.add('Floor $floorNumber');
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (country != null && country!.isNotEmpty) parts.add(country!);
    return parts.join(', ');
  }
}

class Invoice {
  final int id;
  final int orderId;
  final String invoiceNumber;
  final String type;
  final String typeLabel;
  final double subtotal;
  final double shippingAmount;
  final double taxAmount;
  final double discountAmount;
  final double total;
  final String currency;
  final List<InvoiceItem> items;
  final InvoiceBillingAddress? billingAddress;
  final String? paymentMethod;
  final String? paymentReference;
  final String status;
  final String statusLabel;
  final String? notes;
  final String orderNumber;
  final String viewUrl;
  final String createdAt;
  final String? updatedAt;

  Invoice({
    required this.id,
    required this.orderId,
    required this.invoiceNumber,
    required this.type,
    required this.typeLabel,
    required this.subtotal,
    required this.shippingAmount,
    required this.taxAmount,
    required this.discountAmount,
    required this.total,
    required this.currency,
    required this.items,
    this.billingAddress,
    this.paymentMethod,
    this.paymentReference,
    required this.status,
    required this.statusLabel,
    this.notes,
    required this.orderNumber,
    required this.viewUrl,
    required this.createdAt,
    this.updatedAt,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // Parse items
    List<InvoiceItem> items = [];
    if (json['items'] != null && json['items'] is List) {
      items = (json['items'] as List)
          .map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // Parse billing address
    InvoiceBillingAddress? billingAddress;
    if (json['billing_address'] != null && json['billing_address'] is Map) {
      billingAddress = InvoiceBillingAddress.fromJson(
          json['billing_address'] as Map<String, dynamic>);
    }

    return Invoice(
      id: json['id'] ?? 0,
      orderId: json['order_id'] ?? 0,
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      type: json['type']?.toString() ?? 'product',
      typeLabel: json['type_label']?.toString() ?? 'Product Payment',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      shippingAmount: (json['shipping_amount'] ?? 0).toDouble(),
      taxAmount: (json['tax_amount'] ?? 0).toDouble(),
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      currency: json['currency']?.toString() ?? 'USD',
      items: items,
      billingAddress: billingAddress,
      paymentMethod: json['payment_method']?.toString(),
      paymentReference: json['payment_reference']?.toString(),
      status: json['status']?.toString() ?? 'generated',
      statusLabel: json['status_label']?.toString() ?? 'Generated',
      notes: json['notes']?.toString(),
      orderNumber: json['order_number']?.toString() ?? '',
      viewUrl: json['view_url']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString(),
    );
  }

  bool get isProduct => type == 'product';
  bool get isShipping => type == 'shipping';
  bool get isVoid => status == 'void';
}
