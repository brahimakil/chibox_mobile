import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/constants/api_constants.dart';
import '../../../shared/widgets/widgets.dart';

class OtpVerificationScreen extends StatefulWidget {
  final int userId;
  final String countryCode;
  final String phoneNumber;
  final bool isNewUser;

  const OtpVerificationScreen({
    super.key,
    required this.userId,
    required this.countryCode,
    required this.phoneNumber,
    this.isNewUser = false,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _otp = '';
  int _remainingSeconds = ApiConstants.otpExpirySeconds;
  Timer? _timer;
  bool _canResend = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _remainingSeconds = ApiConstants.otpExpirySeconds;
    _canResend = false;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_remainingSeconds > 0) {
        setState(() => _remainingSeconds--);
      } else {
        setState(() => _canResend = true);
        timer.cancel();
      }
    });
  }

  String get _formattedTime {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _handleVerify() async {
    if (_otp.length != ApiConstants.otpLength) {
      _showError('Please enter the complete OTP');
      return;
    }

    final authService = context.read<AuthService>();
    final response = await authService.verifyOtp(
      userId: widget.userId,
      otp: _otp,
    );

    if (mounted) {
      if (response.success) {
        // Navigate to main app
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
      } else {
        _showError(response.message);
      }
    }
  }

  Future<void> _handleResend() async {
    if (!_canResend) return;

    final authService = context.read<AuthService>();
    final response = await authService.resendOtp(
      countryCode: widget.countryCode,
      phoneNumber: widget.phoneNumber,
    );

    if (mounted) {
      if (response.success) {
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('OTP sent successfully'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
          ),
        );
      } else {
        _showError(response.message);
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = context.watch<AuthService>();
    final maskedPhone = '${widget.countryCode} ${'*' * (widget.phoneNumber.length - 4)}${widget.phoneNumber.substring(widget.phoneNumber.length - 4)}';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: AppSpacing.paddingHorizontalBase,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AppSpacing.verticalXl,
              
              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primary100,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.sms5,
                  size: 40,
                  color: AppColors.primary500,
                ),
              )
                  .animate()
                  .scale(delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),
              AppSpacing.verticalXl,

              // Title
              Text(
                'Verify Your Phone',
                style: AppTypography.headingLarge(
                  color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms),
              AppSpacing.verticalSm,

              // Subtitle
              Text(
                'We sent a verification code to',
                style: AppTypography.bodyMedium(
                  color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 300.ms),
              AppSpacing.verticalXs,
              Text(
                maskedPhone,
                style: AppTypography.labelLarge(
                  color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms),
              AppSpacing.verticalXxxl,

              // OTP Input
              OtpInputField(
                length: ApiConstants.otpLength,
                onCompleted: (otp) {
                  setState(() => _otp = otp);
                  _handleVerify();
                },
                onChanged: (otp) => setState(() => _otp = otp),
              )
                  .animate()
                  .fadeIn(delay: 500.ms)
                  .slideY(begin: 0.2, end: 0),
              AppSpacing.verticalXxl,

              // Timer
              if (!_canResend)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Iconsax.timer,
                      size: 18,
                      color: AppColors.secondary500,
                    ),
                    AppSpacing.horizontalSm,
                    Text(
                      'Expires in $_formattedTime',
                      style: AppTypography.bodyMedium(
                        color: AppColors.secondary500,
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 600.ms),

              // Resend
              if (_canResend)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "Didn't receive the code? ",
                      style: AppTypography.bodyMedium(
                        color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                      ),
                    ),
                    GestureDetector(
                      onTap: _handleResend,
                      child: Text(
                        'Resend',
                        style: AppTypography.labelLarge(color: AppColors.primary500),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(),
              
              AppSpacing.verticalXxl,

              // Verify Button
              AppButton(
                text: 'Verify',
                onPressed: _handleVerify,
                isLoading: authService.isLoading,
                isDisabled: _otp.length != ApiConstants.otpLength,
              )
                  .animate()
                  .fadeIn(delay: 700.ms)
                  .slideY(begin: 0.3, end: 0),
              AppSpacing.verticalXl,

              // Change Number
              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Text(
                    'Change phone number',
                    style: AppTypography.labelMedium(
                      color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                    ),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 800.ms),
              AppSpacing.verticalXxl,
            ],
          ),
        ),
      ),
    );
  }
}

