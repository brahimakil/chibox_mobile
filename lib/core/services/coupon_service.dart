import 'package:flutter/foundation.dart';
import '../models/coupon_model.dart';
import '../constants/api_constants.dart';
import 'api_service.dart';

/// Service for managing coupons and discounts
class CouponService extends ChangeNotifier {
  final ApiService _apiService = ApiService();

  // Public coupons (for Deals screen)
  List<Coupon> _publicCoupons = [];
  List<Coupon> get publicCoupons => _publicCoupons;

  // User's claimed coupons (wallet)
  List<Coupon> _myCoupons = [];
  List<Coupon> get myCoupons => _myCoupons;

  // Currently applied coupon in checkout
  Coupon? _appliedCoupon;
  Coupon? get appliedCoupon => _appliedCoupon;

  // Validation result
  CouponValidationResult? _validationResult;
  CouponValidationResult? get validationResult => _validationResult;

  // Loading states
  bool _isLoadingPublic = false;
  bool get isLoadingPublic => _isLoadingPublic;

  bool _isLoadingMyCoupons = false;
  bool get isLoadingMyCoupons => _isLoadingMyCoupons;

  bool _isValidating = false;
  bool get isValidating => _isValidating;

  bool _isClaiming = false;
  bool get isClaiming => _isClaiming;

  // Error
  String? _error;
  String? get error => _error;

  CouponService();

  /// Fetch public coupons for Deals screen
  Future<void> fetchPublicCoupons() async {
    _isLoadingPublic = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.getPublicCoupons);

      if (response.success && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : [];
        _publicCoupons = data.map((json) => Coupon.fromJson(json)).toList();
      } else {
        _error = response.message ?? 'Failed to fetch coupons';
      }
    } catch (e) {
      _error = 'Error fetching coupons: $e';
    }

    _isLoadingPublic = false;
    notifyListeners();
  }

  /// Fetch user's claimed coupons (wallet)
  Future<void> fetchMyCoupons() async {
    _isLoadingMyCoupons = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.get(ApiConstants.getMyCoupons);

      if (response.success && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : [];
        _myCoupons = data.map((json) => Coupon.fromJson(json)).toList();
      } else {
        _error = response.message ?? 'Failed to fetch your coupons';
      }
    } catch (e) {
      _error = 'Error fetching your coupons: $e';
    }

    _isLoadingMyCoupons = false;
    notifyListeners();
  }

  /// Claim a coupon (add to wallet)
  Future<bool> claimCoupon(int couponId) async {
    _isClaiming = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConstants.claimCoupon,
        body: {'coupon_id': couponId},
      );

      if (response.success) {
        // Update local state - mark coupon as claimed
        final index = _publicCoupons.indexWhere((c) => c.id == couponId);
        if (index != -1) {
          _publicCoupons[index] = _publicCoupons[index].copyWith(status: 'claimed');
        }
        _isClaiming = false;
        notifyListeners();
        return true;
      } else {
        _error = response.message ?? 'Failed to claim coupon';
      }
    } catch (e) {
      _error = 'Error claiming coupon: $e';
    }

    _isClaiming = false;
    notifyListeners();
    return false;
  }

  /// Validate coupon by code (manual entry)
  Future<bool> validateCouponByCode(String code, double subtotal) async {
    _isValidating = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConstants.validateCoupon,
        body: {
          'code': code,
          'subtotal': subtotal,
        },
      );

      if (response.success && response.data != null) {
        _validationResult = CouponValidationResult.fromJson(response.data);
        _appliedCoupon = Coupon(
          id: _validationResult!.couponId,
          code: _validationResult!.code,
          isPercentage: false, // Will be calculated from result
          value: _validationResult!.discountAmount,
          label: '-\$${_validationResult!.discountAmount.toStringAsFixed(2)}',
          status: 'applied',
          usageId: _validationResult!.usageId,
        );
        _isValidating = false;
        notifyListeners();
        return true;
      } else {
        _error = response.message ?? 'Invalid coupon code';
      }
    } catch (e) {
      _error = 'Error validating coupon: $e';
    }

    _isValidating = false;
    notifyListeners();
    return false;
  }

  /// Validate coupon by usage ID (from wallet selection)
  Future<bool> validateCouponByUsageId(int usageId, double subtotal) async {
    _isValidating = true;
    _error = null;
    notifyListeners();

    try {
      final response = await _apiService.post(
        ApiConstants.validateCoupon,
        body: {
          'usage_id': usageId,
          'subtotal': subtotal,
        },
      );

      if (response.success && response.data != null) {
        _validationResult = CouponValidationResult.fromJson(response.data);
        
        // Find the coupon in wallet to get full details
        final walletCoupon = _myCoupons.firstWhere(
          (c) => c.usageId == usageId,
          orElse: () => Coupon(
            id: _validationResult!.couponId,
            code: _validationResult!.code,
            isPercentage: false,
            value: _validationResult!.discountAmount,
            label: '-\$${_validationResult!.discountAmount.toStringAsFixed(2)}',
            status: 'applied',
            usageId: usageId,
          ),
        );
        
        _appliedCoupon = walletCoupon.copyWith(status: 'applied');
        _isValidating = false;
        notifyListeners();
        return true;
      } else {
        _error = response.message ?? 'Invalid coupon';
      }
    } catch (e) {
      _error = 'Error validating coupon: $e';
    }

    _isValidating = false;
    notifyListeners();
    return false;
  }

  /// Apply a coupon from wallet directly
  Future<bool> applyCouponFromWallet(Coupon coupon, double subtotal) async {
    if (coupon.usageId != null) {
      return validateCouponByUsageId(coupon.usageId!, subtotal);
    }
    return false;
  }

  /// Remove applied coupon / clear applied coupon
  void clearAppliedCoupon() {
    _appliedCoupon = null;
    _validationResult = null;
    _error = null;
    notifyListeners();
  }

  /// Clear all state (e.g., on logout)
  void clear() {
    _publicCoupons = [];
    _myCoupons = [];
    _appliedCoupon = null;
    _validationResult = null;
    _error = null;
    notifyListeners();
  }

  /// Get discount amount (0 if no coupon applied)
  double get discountAmount => _validationResult?.discountAmount ?? 0.0;

  /// Get coupon ID for checkout (null if no coupon)
  int? get appliedCouponId => _appliedCoupon?.id;

  /// Get usage ID for checkout (null if manual code entry)
  int? get appliedUsageId => _validationResult?.usageId;
}
