import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/widgets.dart';
import 'otp_verification_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  String _countryCode = '+961';
  String? _phoneError;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool _validatePhone() {
    if (_phoneController.text.isEmpty) {
      setState(() => _phoneError = 'Phone number is required');
      return false;
    }
    if (_phoneController.text.length < 8) {
      setState(() => _phoneError = 'Please enter a valid phone number');
      return false;
    }
    setState(() => _phoneError = null);
    return true;
  }

  Future<void> _handleContinue() async {
    if (!_validatePhone()) return;

    final authService = context.read<AuthService>();
    final response = await authService.loginOrRegister(
      countryCode: _countryCode,
      phoneNumber: _phoneController.text,
    );

    if (mounted) {
      if (response.success && response.data != null) {
        final userId = response.data!['user_id'] as int;
        final isNewUser = response.data!['is_new_user'] as bool;
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              userId: userId,
              countryCode: _countryCode,
              phoneNumber: _phoneController.text,
              isNewUser: isNewUser,
            ),
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

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingHorizontalBase,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AppSpacing.verticalXxxl,
                
                // Logo & Welcome
                Center(
                  child: Column(
                    children: [
                      // Logo
                      SizedBox(
                        width: 100,
                        height: 100,
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/animations/chibox logo box.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      )
                          .animate()
                          .scale(delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),
                      AppSpacing.verticalXl,
                      
                      Text(
                        'Welcome',
                      style: AppTypography.displaySmall(
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 200.ms)
                        .slideY(begin: 0.3, end: 0),
                    AppSpacing.verticalSm,
                    Text(
                      'Enter your phone number to continue',
                      style: AppTypography.bodyMedium(
                        color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                      ),
                    )
                        .animate()
                        .fadeIn(delay: 300.ms)
                        .slideY(begin: 0.3, end: 0),
                  ],
                ),
              ),
              AppSpacing.verticalXxxl,
              
              // Phone Input
              Text(
                'Phone Number',
                style: AppTypography.labelMedium(
                  color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                ),
              )
                  .animate()
                  .fadeIn(delay: 400.ms),
              AppSpacing.verticalSm,
              Container(
                decoration: BoxDecoration(
                  color: isDark ? DarkThemeColors.inputBackground : LightThemeColors.inputBackground,
                  borderRadius: AppSpacing.borderRadiusBase,
                  border: Border.all(
                    color: _phoneError != null
                        ? AppColors.error
                        : (isDark ? DarkThemeColors.border : LightThemeColors.border),
                  ),
                ),
                child: Row(
                  children: [
                    // Country Code
                    CountryCodePicker(
                      selectedCode: _countryCode,
                      onChanged: (code) => setState(() => _countryCode = code),
                    ),
                    // Phone Number
                    Expanded(
                      child: TextField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: AppTypography.bodyMedium(
                          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Enter phone number',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          hintStyle: TextStyle(
                            color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                          ),
                        ),
                        onChanged: (_) {
                          if (_phoneError != null) setState(() => _phoneError = null);
                        },
                      ),
                    ),
                  ],
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms)
                  .slideX(begin: -0.1, end: 0),
              if (_phoneError != null) ...[
                AppSpacing.verticalXs,
                Text(
                  _phoneError!,
                  style: AppTypography.caption(color: AppColors.error),
                ),
              ],
              AppSpacing.verticalXl,
              
              // Continue Button
              AppButton(
                text: 'Continue',
                onPressed: _handleContinue,
                isLoading: authService.isLoading,
                rightIcon: Iconsax.arrow_right_3,
              )
                  .animate()
                  .fadeIn(delay: 600.ms)
                  .slideY(begin: 0.3, end: 0),
              AppSpacing.verticalXl,

              // Continue as Guest
              Center(
                child: TextButton(
                  onPressed: () async {
                    await authService.continueAsGuest();
                    if (context.mounted) {
                      if (Navigator.canPop(context)) {
                        Navigator.pop(context);
                      } else {
                        Navigator.pushReplacementNamed(context, '/home');
                      }
                    }
                  },
                  child: Text(
                    'Continue as Guest',
                    style: AppTypography.bodyMedium(
                      color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                    ).copyWith(decoration: TextDecoration.underline),
                  ),
                ),
              ).animate().fadeIn(delay: 700.ms),
              
              AppSpacing.verticalXxl,
            ],
          ),
        ),
        ),
      ),
    );
  }
}