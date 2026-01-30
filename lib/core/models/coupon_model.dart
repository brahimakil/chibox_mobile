/// Coupon model for discount system
class Coupon {
  final int id;
  final String code;
  final bool isPercentage;
  final double value; // percentage value OR fixed amount
  final String label; // e.g., "20% OFF" or "$10 OFF"
  final String? startDate;
  final String? endDate;
  final String status; // 'available', 'claimed', 'locked', 'redeemed'
  final int? usageId; // For claimed coupons, the usage record ID

  Coupon({
    required this.id,
    required this.code,
    required this.isPercentage,
    required this.value,
    required this.label,
    this.startDate,
    this.endDate,
    required this.status,
    this.usageId,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] ?? 0,
      code: json['code'] ?? '',
      isPercentage: json['is_percentage'] ?? false,
      value: (json['value'] ?? 0).toDouble(),
      label: json['label'] ?? '',
      startDate: json['start_date'],
      endDate: json['end_date'],
      status: json['status'] ?? 'available',
      usageId: json['usage_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'is_percentage': isPercentage,
      'value': value,
      'label': label,
      'start_date': startDate,
      'end_date': endDate,
      'status': status,
      'usage_id': usageId,
    };
  }

  /// Check if coupon is claimable (not already claimed/used)
  bool get isClaimable => status == 'available';

  /// Check if coupon is in user's wallet (claimed but not used)
  bool get isInWallet => status == 'claimed';

  /// Check if coupon is currently being used in a pending order
  bool get isLocked => status == 'locked';

  /// Check if coupon has been fully redeemed
  bool get isRedeemed => status == 'redeemed';

  /// Get formatted expiry text
  String get expiryText {
    if (endDate == null) return 'No Expiry';
    try {
      final date = DateTime.parse(endDate!);
      final now = DateTime.now();
      final diff = date.difference(now);
      
      if (diff.isNegative) return 'Expired';
      if (diff.inDays > 30) {
        return 'Expires ${date.day}/${date.month}/${date.year}';
      } else if (diff.inDays > 0) {
        return '${diff.inDays} days left';
      } else if (diff.inHours > 0) {
        return '${diff.inHours} hours left';
      } else {
        return 'Expires soon';
      }
    } catch (_) {
      return 'No Expiry';
    }
  }

  /// Calculate discount amount for a given subtotal
  double calculateDiscount(double subtotal) {
    if (isPercentage) {
      return subtotal * (value / 100);
    } else {
      // Fixed amount - cap at subtotal
      return value > subtotal ? subtotal : value;
    }
  }

  Coupon copyWith({
    int? id,
    String? code,
    bool? isPercentage,
    double? value,
    String? label,
    String? startDate,
    String? endDate,
    String? status,
    int? usageId,
  }) {
    return Coupon(
      id: id ?? this.id,
      code: code ?? this.code,
      isPercentage: isPercentage ?? this.isPercentage,
      value: value ?? this.value,
      label: label ?? this.label,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      usageId: usageId ?? this.usageId,
    );
  }
}

/// Response model for coupon validation
class CouponValidationResult {
  final bool valid;
  final int couponId;
  final String code;
  final double discountAmount;
  final double finalSubtotal;
  final int? usageId;

  CouponValidationResult({
    required this.valid,
    required this.couponId,
    required this.code,
    required this.discountAmount,
    required this.finalSubtotal,
    this.usageId,
  });

  factory CouponValidationResult.fromJson(Map<String, dynamic> json) {
    return CouponValidationResult(
      valid: json['valid'] ?? false,
      couponId: json['coupon_id'] ?? 0,
      code: json['code'] ?? '',
      discountAmount: (json['discount_amount'] ?? 0).toDouble(),
      finalSubtotal: (json['final_subtotal'] ?? 0).toDouble(),
      usageId: json['usage_id'],
    );
  }
}
