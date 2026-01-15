/// Payment Status Constants (matching backend PaymentTransaction model)
class PaymentStatus {
  static const String pending = 'pending';
  static const String processing = 'processing';
  static const String success = 'success';
  static const String failed = 'failed';
  static const String cancelled = 'cancelled';
  static const String expired = 'expired';

  static String getDisplayName(String status) {
    switch (status.toLowerCase()) {
      case pending:
        return 'Pending';
      case processing:
        return 'Processing';
      case success:
        return 'Successful';
      case failed:
        return 'Failed';
      case cancelled:
        return 'Cancelled';
      case expired:
        return 'Expired';
      default:
        return 'Unknown';
    }
  }

  static bool isSuccess(String status) => status.toLowerCase() == success;
  static bool isPending(String status) =>
      status.toLowerCase() == pending || status.toLowerCase() == processing;
  static bool isFailed(String status) =>
      status.toLowerCase() == failed ||
      status.toLowerCase() == cancelled ||
      status.toLowerCase() == expired;
}

/// Payment Gateway Constants
class PaymentGateway {
  static const String whishMoney = 'whish_money';
  static const String stripe = 'stripe';
  static const String paypal = 'paypal';

  static String getDisplayName(String gateway) {
    switch (gateway.toLowerCase()) {
      case whishMoney:
        return 'Whish Money';
      case stripe:
        return 'Stripe';
      case paypal:
        return 'PayPal';
      default:
        return gateway;
    }
  }
}

/// Payment Transaction Model
class PaymentTransaction {
  final int id;
  final String externalId;
  final String status;
  final String statusLabel;
  final double amount;
  final String currency;
  final bool isProcessed;
  final String? createdAt;
  final String? processedAt;

  PaymentTransaction({
    required this.id,
    required this.externalId,
    required this.status,
    required this.statusLabel,
    required this.amount,
    required this.currency,
    required this.isProcessed,
    this.createdAt,
    this.processedAt,
  });

  factory PaymentTransaction.fromJson(Map<String, dynamic> json) {
    return PaymentTransaction(
      id: json['id'] ?? 0,
      externalId: json['external_id'] ?? '',
      status: json['status'] ?? 'unknown',
      statusLabel: json['status_label'] ?? 'Unknown',
      amount: (json['amount'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      isProcessed: json['is_processed'] == 1 || json['is_processed'] == true,
      createdAt: json['created_at'],
      processedAt: json['processed_at'],
    );
  }

  bool get isPending => PaymentStatus.isPending(status);
  bool get isSuccess => PaymentStatus.isSuccess(status);
  bool get isFailed => PaymentStatus.isFailed(status);
}

/// Payment Initiation Response
class PaymentInitResponse {
  final bool success;
  final String message;
  final String? paymentUrl;
  final String? externalId;
  final int? transactionId;
  final double? amount;
  final String? currency;
  final String? invoice;
  final bool existing;

  PaymentInitResponse({
    required this.success,
    required this.message,
    this.paymentUrl,
    this.externalId,
    this.transactionId,
    this.amount,
    this.currency,
    this.invoice,
    this.existing = false,
  });

  factory PaymentInitResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return PaymentInitResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      paymentUrl: data?['payment_url'],
      externalId: data?['external_id'],
      transactionId: data?['transaction_id'],
      amount: data?['amount']?.toDouble(),
      currency: data?['currency'],
      invoice: data?['invoice'],
      existing: data?['existing'] ?? false,
    );
  }

  factory PaymentInitResponse.error(String message) {
    return PaymentInitResponse(success: false, message: message);
  }
}

/// Payment Status Response
class PaymentStatusResponse {
  final bool success;
  final String message;
  final PaymentTransaction? transaction;
  final PaymentOrderInfo? order;
  final String? paymentUrl;

  PaymentStatusResponse({
    required this.success,
    required this.message,
    this.transaction,
    this.order,
    this.paymentUrl,
  });

  factory PaymentStatusResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return PaymentStatusResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      transaction: data?['transaction'] != null
          ? PaymentTransaction.fromJson(data!['transaction'])
          : null,
      order: data?['order'] != null
          ? PaymentOrderInfo.fromJson(data!['order'])
          : null,
      paymentUrl: data?['payment_url'],
    );
  }

  factory PaymentStatusResponse.error(String message) {
    return PaymentStatusResponse(success: false, message: message);
  }
}

/// Payment Order Info (embedded in status response)
class PaymentOrderInfo {
  final int id;
  final String status;
  final int statusId;
  final bool isPaid;
  final double total;

  PaymentOrderInfo({
    required this.id,
    required this.status,
    required this.statusId,
    required this.isPaid,
    required this.total,
  });

  factory PaymentOrderInfo.fromJson(Map<String, dynamic> json) {
    return PaymentOrderInfo(
      id: json['id'] ?? 0,
      status: json['status'] ?? 'Unknown',
      statusId: json['status_id'] ?? 0,
      isPaid: json['is_paid'] == 1 || json['is_paid'] == true,
      total: (json['total'] ?? 0).toDouble(),
    );
  }
}

/// Payment Verification Response
class PaymentVerifyResponse {
  final bool success;
  final String message;
  final bool verified;
  final String status;
  final int? orderId;
  final String? orderStatus;

  PaymentVerifyResponse({
    required this.success,
    required this.message,
    required this.verified,
    required this.status,
    this.orderId,
    this.orderStatus,
  });

  factory PaymentVerifyResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] as Map<String, dynamic>?;
    return PaymentVerifyResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      verified: data?['verified'] ?? false,
      status: data?['status'] ?? 'unknown',
      orderId: data?['order_id'],
      orderStatus: data?['order_status'],
    );
  }

  factory PaymentVerifyResponse.error(String message) {
    return PaymentVerifyResponse(
      success: false,
      message: message,
      verified: false,
      status: 'error',
    );
  }

  bool get isPaymentSuccess => status.toLowerCase() == 'success';
  bool get isPaymentPending => status.toLowerCase() == 'pending';
  bool get isPaymentFailed => status.toLowerCase() == 'failed';
}
