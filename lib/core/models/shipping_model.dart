/// Shipping Models for ChiHelo
/// Handles shipping method selection and cost calculation

/// Shipping method type
enum ShippingMethodType {
  air,
  sea,
}

extension ShippingMethodTypeExtension on ShippingMethodType {
  String get value {
    switch (this) {
      case ShippingMethodType.air:
        return 'air';
      case ShippingMethodType.sea:
        return 'sea';
    }
  }

  static ShippingMethodType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'sea':
        return ShippingMethodType.sea;
      case 'air':
      default:
        return ShippingMethodType.air;
    }
  }
}

/// Represents a shipping method option
class ShippingMethod {
  final String id;
  final String name;
  final String icon;
  final String description;
  final String estimatedDays;
  final double? pricePerKg; // For air
  final double? pricePerCbm; // For sea
  final String pricingInfo;

  const ShippingMethod({
    required this.id,
    required this.name,
    required this.icon,
    required this.description,
    required this.estimatedDays,
    this.pricePerKg,
    this.pricePerCbm,
    required this.pricingInfo,
  });

  factory ShippingMethod.fromJson(Map<String, dynamic> json) {
    return ShippingMethod(
      id: json['id']?.toString() ?? 'air',
      name: json['name'] ?? 'Shipping',
      icon: json['icon'] ?? '📦',
      description: json['description'] ?? '',
      estimatedDays: json['estimated_days'] ?? '',
      pricePerKg: json['price_per_kg'] != null
          ? (json['price_per_kg'] is num
              ? (json['price_per_kg'] as num).toDouble()
              : double.tryParse(json['price_per_kg'].toString()))
          : null,
      pricePerCbm: json['price_per_cbm'] != null
          ? (json['price_per_cbm'] is num
              ? (json['price_per_cbm'] as num).toDouble()
              : double.tryParse(json['price_per_cbm'].toString()))
          : null,
      pricingInfo: json['pricing_info'] ?? '',
    );
  }

  bool get isAir => id == 'air';
  bool get isSea => id == 'sea';
}

/// Shipping calculation result for a single item
class ShippingItemResult {
  final int productId;
  final int quantity;
  final String status; // 'calculated', 'pending_estimation'
  final double? unitCost;
  final double? totalCost;
  final bool isAiProcessing;
  final int? cartItemId;
  
  // Debug/Display data
  final double? weightKg;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final double? confidenceScore;
  final bool? isAiDetected;
  final double? pricePerKg; // For air shipping
  final double? pricePerCbm; // For sea shipping
  final double? cbm; // Cubic meters
  
  // Category Surcharge data (percentage of product price added to shipping)
  final double? surchargePercent;
  final double? surchargeAmount;
  final double? baseShippingCost; // Shipping cost before surcharge

  const ShippingItemResult({
    required this.productId,
    required this.quantity,
    required this.status,
    this.unitCost,
    this.totalCost,
    this.isAiProcessing = false,
    this.cartItemId,
    this.weightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.confidenceScore,
    this.isAiDetected,
    this.pricePerKg,
    this.pricePerCbm,
    this.cbm,
    this.surchargePercent,
    this.surchargeAmount,
    this.baseShippingCost,
  });

  factory ShippingItemResult.fromJson(Map<String, dynamic> json) {
    // Parse dimensions - may be nested in 'dimensions' object or at top level
    // API sends in meters, convert to cm for display
    final dimensions = json['dimensions'] as Map<String, dynamic>?;
    
    double? lengthCm, widthCm, heightCm, weightKg;
    
    // Try nested dimensions object first, then top level
    if (dimensions != null) {
      if (dimensions['length_m'] != null) {
        lengthCm = _parseDouble(dimensions['length_m'])! * 100; // m to cm
      }
      if (dimensions['width_m'] != null) {
        widthCm = _parseDouble(dimensions['width_m'])! * 100;
      }
      if (dimensions['height_m'] != null) {
        heightCm = _parseDouble(dimensions['height_m'])! * 100;
      }
      if (dimensions['weight_kg'] != null) {
        weightKg = _parseDouble(dimensions['weight_kg']);
      }
    }
    
    // Fallback to top-level values
    if (lengthCm == null) {
      if (json['length_m'] != null) {
        lengthCm = _parseDouble(json['length_m'])! * 100;
      } else if (json['length_cm'] != null) {
        lengthCm = _parseDouble(json['length_cm']);
      }
    }
    if (widthCm == null) {
      if (json['width_m'] != null) {
        widthCm = _parseDouble(json['width_m'])! * 100;
      } else if (json['width_cm'] != null) {
        widthCm = _parseDouble(json['width_cm']);
      }
    }
    if (heightCm == null) {
      if (json['height_m'] != null) {
        heightCm = _parseDouble(json['height_m'])! * 100;
      } else if (json['height_cm'] != null) {
        heightCm = _parseDouble(json['height_cm']);
      }
    }
    if (weightKg == null) {
      weightKg = _parseDouble(json['weight_kg']);
    }
    
    // Parse surcharge data - check both top-level and nested in details object
    double? surchargePercent, surchargeAmount, baseShippingCost;
    
    // First check top-level (new format from calculateForCart)
    surchargePercent = _parseDouble(json['surcharge_percent']);
    surchargeAmount = _parseDouble(json['surcharge_amount']);
    baseShippingCost = _parseDouble(json['base_shipping_cost']);
    
    // Fallback to details object (calculateFromDimensions raw response format)
    if (surchargePercent == null) {
      final details = json['details'] as Map<String, dynamic>?;
      if (details != null) {
        surchargePercent = _parseDouble(details['surcharge_percent']);
        surchargeAmount = _parseDouble(details['surcharge_amount']);
        baseShippingCost = _parseDouble(details['base_shipping_cost']);
      }
    }
    
    return ShippingItemResult(
      productId: json['product_id'] is int
          ? json['product_id']
          : int.parse(json['product_id'].toString()),
      quantity: json['quantity'] is int
          ? json['quantity']
          : int.parse(json['quantity'].toString()),
      status: json['status'] ?? 'pending_estimation',
      unitCost: _parseDouble(json['unit_cost']),
      totalCost: _parseDouble(json['total_cost']),
      isAiProcessing: json['ai_processing'] == 1 || json['ai_processing'] == true,
      cartItemId: json['cart_item_id'],
      weightKg: weightKg, // Use parsed value from dimensions object
      lengthCm: lengthCm,
      widthCm: widthCm,
      heightCm: heightCm,
      confidenceScore: _parseDouble(json['confidence_score']),
      // AI detected if: explicit flag, source=ai, OR has a confidence score (AI estimation)
      isAiDetected: json['is_ai_detected'] == true || 
                    json['is_ai_detected'] == 1 || 
                    json['source'] == 'ai' ||
                    (_parseDouble(json['confidence_score']) != null && _parseDouble(json['confidence_score'])! > 0),
      pricePerKg: _parseDouble(json['price_per_kg']),
      pricePerCbm: _parseDouble(json['price_per_cbm']),
      cbm: _parseDouble(json['cbm']),
      surchargePercent: surchargePercent,
      surchargeAmount: surchargeAmount,
      baseShippingCost: baseShippingCost,
    );
  }
  
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool get isCalculated => status == 'calculated';
  bool get isPending => status == 'pending_estimation';
  
  /// Get dimensions as a formatted string (LxWxH cm)
  String? get dimensionsString {
    if (lengthCm != null && widthCm != null && heightCm != null) {
      return '${lengthCm!.toStringAsFixed(1)}×${widthCm!.toStringAsFixed(1)}×${heightCm!.toStringAsFixed(1)} cm';
    }
    return null;
  }
}

/// Summary of shipping calculation for cart
class ShippingSummary {
  final int totalItems;
  final int itemsCalculated;
  final int itemsPending;
  final double totalShippingCost;
  final bool allCalculated;

  const ShippingSummary({
    required this.totalItems,
    required this.itemsCalculated,
    required this.itemsPending,
    required this.totalShippingCost,
    required this.allCalculated,
  });

  factory ShippingSummary.fromJson(Map<String, dynamic> json) {
    return ShippingSummary(
      totalItems: json['total_items'] is int
          ? json['total_items']
          : int.tryParse(json['total_items']?.toString() ?? '0') ?? 0,
      itemsCalculated: json['items_calculated'] is int
          ? json['items_calculated']
          : int.tryParse(json['items_calculated']?.toString() ?? '0') ?? 0,
      itemsPending: json['items_pending'] is int
          ? json['items_pending']
          : int.tryParse(json['items_pending']?.toString() ?? '0') ?? 0,
      totalShippingCost: json['total_shipping_cost'] is num
          ? (json['total_shipping_cost'] as num).toDouble()
          : double.tryParse(json['total_shipping_cost']?.toString() ?? '0') ?? 0.0,
      allCalculated: json['all_calculated'] == true || json['all_calculated'] == 1,
    );
  }

  /// Empty summary for initial state
  factory ShippingSummary.empty() {
    return const ShippingSummary(
      totalItems: 0,
      itemsCalculated: 0,
      itemsPending: 0,
      totalShippingCost: 0.0,
      allCalculated: true,
    );
  }
}

/// Full shipping calculation result
class ShippingCalculation {
  final bool success;
  final String method;
  final List<ShippingItemResult> items;
  final ShippingSummary summary;
  final String? error;

  const ShippingCalculation({
    required this.success,
    required this.method,
    required this.items,
    required this.summary,
    this.error,
  });

  factory ShippingCalculation.fromJson(Map<String, dynamic> json) {
    // Handle data wrapper
    final data = json['data'] ?? json;
    
    return ShippingCalculation(
      success: data['success'] == true || json['success'] == true,
      method: data['method'] ?? 'air',
      items: (data['items'] as List?)
              ?.map((item) => ShippingItemResult.fromJson(item))
              .toList() ??
          [],
      summary: data['summary'] != null
          ? ShippingSummary.fromJson(data['summary'])
          : ShippingSummary.empty(),
      error: json['message'],
    );
  }

  /// Empty calculation for initial state
  factory ShippingCalculation.empty() {
    return ShippingCalculation(
      success: true,
      method: 'air',
      items: [],
      summary: ShippingSummary.empty(),
    );
  }

  /// Error state
  factory ShippingCalculation.error(String message) {
    return ShippingCalculation(
      success: false,
      method: 'air',
      items: [],
      summary: ShippingSummary.empty(),
      error: message,
    );
  }
}

/// Comparison of shipping methods
class ShippingComparison {
  final ShippingMethodComparison air;
  final ShippingMethodComparison sea;
  final String recommended;
  final bool allItemsCalculated;
  final bool hasProcessingItems;
  final List<int> processingProductIds;
  final double minimumShippingCost;

  const ShippingComparison({
    required this.air,
    required this.sea,
    required this.recommended,
    required this.allItemsCalculated,
    this.hasProcessingItems = false,
    this.processingProductIds = const [],
    this.minimumShippingCost = 0.50,
  });

  factory ShippingComparison.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final methods = data['methods'] ?? {};
    
    // Parse processing product IDs
    final processingIds = <int>[];
    if (data['processing_product_ids'] != null && data['processing_product_ids'] is List) {
      for (final id in data['processing_product_ids']) {
        if (id is int) {
          processingIds.add(id);
        } else if (id != null) {
          processingIds.add(int.parse(id.toString()));
        }
      }
    }
    
    return ShippingComparison(
      air: ShippingMethodComparison.fromJson(methods['air'] ?? {}),
      sea: ShippingMethodComparison.fromJson(methods['sea'] ?? {}),
      recommended: data['recommended'] ?? 'air',
      allItemsCalculated: data['all_items_calculated'] == true,
      hasProcessingItems: data['has_processing_items'] == true,
      processingProductIds: processingIds,
      minimumShippingCost: (data['minimum_shipping_cost'] ?? 0.50).toDouble(),
    );
  }

  /// Empty comparison for initial state
  factory ShippingComparison.empty() {
    return ShippingComparison(
      air: ShippingMethodComparison.empty('air'),
      sea: ShippingMethodComparison.empty('sea'),
      recommended: 'air',
      allItemsCalculated: false,
      hasProcessingItems: false,
      processingProductIds: const [],
      minimumShippingCost: 0.50,
    );
  }
  
  /// Check if a specific product is currently being processed by AI
  bool isProductProcessing(int productId) {
    // Check if in the processing list
    if (processingProductIds.contains(productId)) {
      return true;
    }
    
    // Also check item-level ai_processing flag
    final airItem = air.items.where((i) => i.productId == productId).firstOrNull;
    final seaItem = sea.items.where((i) => i.productId == productId).firstOrNull;
    
    final airProcessing = airItem?.isAiProcessing ?? false;
    final seaProcessing = seaItem?.isAiProcessing ?? false;
    
    return airProcessing || seaProcessing;
  }
  
  /// Get lowest shipping cost and method for a specific product
  /// Returns a record with (cost, method, methodIcon)
  ({double cost, String method, String icon})? getLowestCostForProduct(int productId) {
    final airCost = air.getCostForProduct(productId);
    final seaCost = sea.getCostForProduct(productId);
    
    if (airCost == null && seaCost == null) return null;
    if (airCost == null) return (cost: seaCost!, method: 'sea', icon: '🚢');
    if (seaCost == null) return (cost: airCost, method: 'air', icon: '✈️');
    
    if (seaCost <= airCost) {
      return (cost: seaCost, method: 'sea', icon: '🚢');
    } else {
      return (cost: airCost, method: 'air', icon: '✈️');
    }
  }
  
  /// Get detailed shipping debug info for a product
  /// Returns all the shipping data for debugging display
  ShippingDebugInfo? getDebugInfoForProduct(int productId) {
    final airItem = air.items.where((i) => i.productId == productId).firstOrNull;
    final seaItem = sea.items.where((i) => i.productId == productId).firstOrNull;
    
    // Use air item data as primary source (both should have same dimensions/weight)
    final item = airItem ?? seaItem;
    if (item == null) return null;
    
    return ShippingDebugInfo(
      weightKg: item.weightKg,
      lengthCm: item.lengthCm,
      widthCm: item.widthCm,
      heightCm: item.heightCm,
      isAiDetected: item.isAiDetected ?? false,
      confidenceScore: item.confidenceScore,
      airPricePerKg: airItem?.pricePerKg,
      airCost: airItem?.totalCost,
      seaPricePerCbm: seaItem?.pricePerCbm,
      seaCost: seaItem?.totalCost,
      cbm: item.cbm,
      isProcessing: isProductProcessing(productId),
    );
  }
}

/// Debug info for shipping display on cart cards
class ShippingDebugInfo {
  final double? weightKg;
  final double? lengthCm;
  final double? widthCm;
  final double? heightCm;
  final bool isAiDetected;
  final double? confidenceScore;
  final double? airPricePerKg;
  final double? airCost;
  final double? seaPricePerCbm;
  final double? seaCost;
  final double? cbm;
  final bool isProcessing;
  
  const ShippingDebugInfo({
    this.weightKg,
    this.lengthCm,
    this.widthCm,
    this.heightCm,
    this.isAiDetected = false,
    this.confidenceScore,
    this.airPricePerKg,
    this.airCost,
    this.seaPricePerCbm,
    this.seaCost,
    this.cbm,
    this.isProcessing = false,
  });
  
  /// Get dimensions as a formatted string (LxWxH cm)
  String? get dimensionsString {
    if (lengthCm != null && widthCm != null && heightCm != null) {
      return '${lengthCm!.toStringAsFixed(1)}×${widthCm!.toStringAsFixed(1)}×${heightCm!.toStringAsFixed(1)}';
    }
    return null;
  }
  
  /// Get confidence as percentage string
  String? get confidenceString {
    if (confidenceScore != null) {
      return '${(confidenceScore! * 100).toStringAsFixed(0)}%';
    }
    return null;
  }
}

/// Single method comparison data
class ShippingMethodComparison {
  final String method;
  final String name;
  final double totalCost;
  final bool allCalculated;
  final String estimatedDays;
  final List<ShippingItemResult> items;

  const ShippingMethodComparison({
    required this.method,
    required this.name,
    required this.totalCost,
    required this.allCalculated,
    required this.estimatedDays,
    this.items = const [],
  });

  factory ShippingMethodComparison.fromJson(Map<String, dynamic> json) {
    // Parse items list
    final itemsList = <ShippingItemResult>[];
    if (json['items'] != null && json['items'] is List) {
      for (final item in json['items']) {
        itemsList.add(ShippingItemResult.fromJson(item));
      }
    }
    
    return ShippingMethodComparison(
      method: json['method'] ?? 'air',
      name: json['name'] ?? 'Shipping',
      totalCost: json['total_cost'] is num
          ? (json['total_cost'] as num).toDouble()
          : double.tryParse(json['total_cost']?.toString() ?? '0') ?? 0.0,
      allCalculated: json['all_calculated'] == true,
      estimatedDays: json['estimated_days'] ?? '',
      items: itemsList,
    );
  }

  factory ShippingMethodComparison.empty(String method) {
    return ShippingMethodComparison(
      method: method,
      name: method == 'air' ? 'Air Shipping ✈️' : 'Sea Shipping 🚢',
      totalCost: 0.0,
      allCalculated: false,
      estimatedDays: method == 'air' ? '14-21 days' : '45-60 days',
      items: const [],
    );
  }
  
  /// Get shipping cost for a specific product
  double? getCostForProduct(int productId) {
    final item = items.where((i) => i.productId == productId).firstOrNull;
    return item?.totalCost;
  }
  
  /// Get total surcharge amount across all items
  double get totalSurchargeAmount {
    return items.fold(0.0, (sum, item) => sum + (item.surchargeAmount ?? 0.0));
  }
  
  /// Check if any items have a surcharge
  bool get hasSurcharge {
    return items.any((item) => (item.surchargePercent ?? 0) > 0);
  }
  
  /// Get list of items with surcharges (for display)
  List<ShippingItemResult> get itemsWithSurcharge {
    return items.where((item) => (item.surchargePercent ?? 0) > 0).toList();
  }
  
  /// Get total CBM across all items
  double get totalCbm {
    return items.fold(0.0, (sum, item) => sum + ((item.cbm ?? 0.0) * item.quantity));
  }
  
  /// Get unique CBM rates and their totals (for sea shipping)
  /// Returns a map of {rate: totalCbmAtThatRate}
  Map<double, double> get cbmBreakdownByRate {
    final breakdown = <double, double>{};
    for (final item in items) {
      if (item.pricePerCbm != null && item.cbm != null) {
        final rate = item.pricePerCbm!;
        final itemCbm = item.cbm! * item.quantity;
        breakdown[rate] = (breakdown[rate] ?? 0) + itemCbm;
      }
    }
    return breakdown;
  }
  
  /// Check if all items have the same CBM rate
  bool get hasSingleCbmRate {
    return cbmBreakdownByRate.keys.length <= 1;
  }
  
  /// Get the single CBM rate (if all items share it), else null
  double? get singlePricePerCbm {
    final rates = cbmBreakdownByRate.keys.toList();
    if (rates.length == 1) return rates.first;
    return null;
  }
  
  /// Get total weight across all items
  double get totalWeightKg {
    return items.fold(0.0, (sum, item) => sum + ((item.weightKg ?? 0.0) * item.quantity));
  }
  
  /// Get unique weight rates and their totals (for air shipping)
  /// Returns a map of {rate: totalWeightAtThatRate}
  Map<double, double> get weightBreakdownByRate {
    final breakdown = <double, double>{};
    for (final item in items) {
      if (item.pricePerKg != null && item.weightKg != null) {
        final rate = item.pricePerKg!;
        final itemWeight = item.weightKg! * item.quantity;
        breakdown[rate] = (breakdown[rate] ?? 0) + itemWeight;
      }
    }
    return breakdown;
  }
  
  /// Check if all items have the same kg rate
  bool get hasSingleKgRate {
    return weightBreakdownByRate.keys.length <= 1;
  }
  
  /// Get the single kg rate (if all items share it), else null
  double? get singlePricePerKg {
    final rates = weightBreakdownByRate.keys.toList();
    if (rates.length == 1) return rates.first;
    return null;
  }
  
  /// Get surcharge breakdown by percentage
  /// Returns a list of (percent, amount) for items with surcharges
  List<({double percent, double amount, int productId})> get surchargeBreakdown {
    final breakdown = <({double percent, double amount, int productId})>[];
    for (final item in items) {
      if (item.surchargePercent != null && item.surchargePercent! > 0 && item.surchargeAmount != null) {
        breakdown.add((
          percent: item.surchargePercent!,
          amount: item.surchargeAmount!,
          productId: item.productId,
        ));
      }
    }
    return breakdown;
  }
  
  /// Check if all surcharge items have the same percentage
  bool get hasSingleSurchargePercent {
    final percents = surchargeBreakdown.map((e) => e.percent).toSet();
    return percents.length <= 1;
  }
  
  /// Get single surcharge percent if all items share it
  double? get singleSurchargePercent {
    final percents = surchargeBreakdown.map((e) => e.percent).toSet();
    if (percents.length == 1) return percents.first;
    return null;
  }
}

/// Product shipping status
class ProductShippingStatus {
  final int productId;
  final String status; // 'complete', 'processing', 'partial', 'missing'
  final bool hasWeight;
  final bool hasDimensions;
  final bool isAiProcessing;
  final ShippingData? shippingData;

  const ProductShippingStatus({
    required this.productId,
    required this.status,
    required this.hasWeight,
    required this.hasDimensions,
    required this.isAiProcessing,
    this.shippingData,
  });

  factory ProductShippingStatus.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    
    return ProductShippingStatus(
      productId: data['product_id'] is int
          ? data['product_id']
          : int.parse(data['product_id'].toString()),
      status: data['status'] ?? 'missing',
      hasWeight: data['has_weight'] == true,
      hasDimensions: data['has_dimensions'] == true,
      isAiProcessing: data['ai_processing'] == 1 || data['ai_processing'] == true,
      shippingData: data['shipping_data'] != null
          ? ShippingData.fromJson(data['shipping_data'])
          : null,
    );
  }

  bool get isComplete => status == 'complete';
  bool get isProcessing => status == 'processing';
  bool get isMissing => status == 'missing';
  bool get isPartial => status == 'partial';
}

/// Product shipping data
class ShippingData {
  final double? weightKg;
  final double? lengthM;
  final double? widthM;
  final double? heightM;
  final double? confidenceScore;
  final String? source;

  const ShippingData({
    this.weightKg,
    this.lengthM,
    this.widthM,
    this.heightM,
    this.confidenceScore,
    this.source,
  });

  factory ShippingData.fromJson(Map<String, dynamic> json) {
    return ShippingData(
      weightKg: json['weight_kg'] != null
          ? (json['weight_kg'] is num
              ? (json['weight_kg'] as num).toDouble()
              : double.tryParse(json['weight_kg'].toString()))
          : null,
      lengthM: json['length_m'] != null
          ? (json['length_m'] is num
              ? (json['length_m'] as num).toDouble()
              : double.tryParse(json['length_m'].toString()))
          : null,
      widthM: json['width_m'] != null
          ? (json['width_m'] is num
              ? (json['width_m'] as num).toDouble()
              : double.tryParse(json['width_m'].toString()))
          : null,
      heightM: json['height_m'] != null
          ? (json['height_m'] is num
              ? (json['height_m'] as num).toDouble()
              : double.tryParse(json['height_m'].toString()))
          : null,
      confidenceScore: json['confidence_score'] != null
          ? (json['confidence_score'] is num
              ? (json['confidence_score'] as num).toDouble()
              : double.tryParse(json['confidence_score'].toString()))
          : null,
      source: json['source'],
    );
  }

  /// Calculate CBM (Cubic Meters)
  double? get cbm {
    if (lengthM != null && widthM != null && heightM != null) {
      return lengthM! * widthM! * heightM!;
    }
    return null;
  }
}
