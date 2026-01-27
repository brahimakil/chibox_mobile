import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/app_colors.dart';

/// Callback type that receives BuildContext
typedef ContextCallback = void Function(BuildContext context);

/// Screen shown after payment completion
class PaymentResultScreen extends StatelessWidget {
  final bool success;
  final String? message;
  final int? orderId;
  final double? amount;
  final String? currency;
  final ContextCallback? onViewOrder;
  final ContextCallback? onRetryPayment;
  final ContextCallback? onGoHome;

  const PaymentResultScreen({
    super.key,
    required this.success,
    this.message,
    this.orderId,
    this.amount,
    this.currency,
    this.onViewOrder,
    this.onRetryPayment,
    this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // On back press, trigger the same action as "Continue Shopping" / "Go Home"
        if (onGoHome != null) {
          onGoHome!(context);
        } else {
          // Fallback: just pop to first route
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(flex: 2),
              
              // Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: success 
                      ? AppColors.success.withOpacity(0.1)
                      : AppColors.error.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  success ? Iconsax.tick_circle5 : Iconsax.close_circle5,
                  size: 60,
                  color: success ? AppColors.success : AppColors.error,
                ),
              )
                  .animate()
                  .scale(
                    begin: const Offset(0.5, 0.5),
                    end: const Offset(1.0, 1.0),
                    duration: 400.ms,
                    curve: Curves.elasticOut,
                  )
                  .fadeIn(),
              
              const SizedBox(height: 32),
              
              // Title
              Text(
                success ? 'Payment Successful!' : 'Payment Failed',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideY(begin: 0.3, end: 0),
              
              const SizedBox(height: 12),
              
              // Amount (if success)
              if (success && amount != null)
                Text(
                  '${currency ?? '\$'}${amount!.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w700,
                    color: AppColors.success,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.3, end: 0),
              
              const SizedBox(height: 16),
              
              // Message
              Text(
                message ?? (success 
                    ? 'Your payment has been processed successfully. Thank you for your purchase!'
                    : 'Something went wrong with your payment. Please try again or contact support.'),
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 400.ms),
              
              // Order ID
              if (orderId != null) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? DarkThemeColors.border : LightThemeColors.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Iconsax.receipt_2,
                        size: 20,
                        color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Order #${orderId.toString().padLeft(8, '0')}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideY(begin: 0.2, end: 0),
              ],
              
              const Spacer(flex: 3),
              
              // Buttons
              if (success) ...[
                // View Order Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onViewOrder != null ? () => onViewOrder!(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Order',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 12),
                
                // Continue Shopping
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onGoHome != null ? () => onGoHome!(context) : null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? DarkThemeColors.border : LightThemeColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Continue Shopping',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 700.ms)
                    .slideY(begin: 0.2, end: 0),
              ] else ...[
                // Retry Payment Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: onRetryPayment != null ? () => onRetryPayment!(context) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Retry Payment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 600.ms)
                    .slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 12),
                
                // View Order Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: onViewOrder != null ? () => onViewOrder!(context) : null,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: isDark ? DarkThemeColors.border : LightThemeColors.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'View Order Details',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 700.ms)
                    .slideY(begin: 0.2, end: 0),
                
                const SizedBox(height: 12),
                
                // Go Home
                TextButton(
                  onPressed: onGoHome != null ? () => onGoHome!(context) : null,
                  child: Text(
                    'Back to Home',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 800.ms),
              ],
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
