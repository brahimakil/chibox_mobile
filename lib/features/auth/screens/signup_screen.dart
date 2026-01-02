import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/widgets.dart';
import 'otp_verification_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _countryCode = '+961';
  String? _selectedGender;
  bool _agreedToTerms = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_firstNameController.text.isEmpty) {
      _showError('First name is required');
      return false;
    }
    if (_lastNameController.text.isEmpty) {
      _showError('Last name is required');
      return false;
    }
    if (_phoneController.text.isEmpty) {
      _showError('Phone number is required');
      return false;
    }
    if (_phoneController.text.length < 8) {
      _showError('Please enter a valid phone number');
      return false;
    }
    if (!_agreedToTerms) {
      _showError('Please agree to the Terms & Conditions');
      return false;
    }
    return true;
  }

  Future<void> _handleSignup() async {
    if (!_validateForm()) return;

    final authService = context.read<AuthService>();
    final response = await authService.register(
      countryCode: _countryCode,
      phoneNumber: _phoneController.text,
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      email: _emailController.text.isNotEmpty ? _emailController.text : null,
      gender: _selectedGender,
    );

    if (mounted) {
      if (response.success) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpVerificationScreen(
              userId: response.data!,
              countryCode: _countryCode,
              phoneNumber: _phoneController.text,
              isNewUser: true,
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
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Iconsax.arrow_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: AppSpacing.paddingHorizontalBase,
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                AppSpacing.verticalLg,
                
                // Header
                Text(
                  'Join LuxeMarket',
                  style: AppTypography.headingLarge(
                    color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                  ),
                )
                    .animate()
                    .fadeIn()
                    .slideY(begin: 0.3, end: 0),
                AppSpacing.verticalSm,
                Text(
                  'Create your account to start shopping',
                  style: AppTypography.bodyMedium(
                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 100.ms),
                AppSpacing.verticalXxl,

                // Name Row
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        label: 'First Name',
                        hint: 'John',
                        controller: _firstNameController,
                        prefixIcon: Iconsax.user,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                    AppSpacing.horizontalMd,
                    Expanded(
                      child: AppTextField(
                        label: 'Last Name',
                        hint: 'Doe',
                        controller: _lastNameController,
                        prefixIcon: Iconsax.user,
                        textInputAction: TextInputAction.next,
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideX(begin: -0.1, end: 0),
                AppSpacing.verticalBase,

                // Email
                AppTextField(
                  label: 'Email (Optional)',
                  hint: 'john@example.com',
                  controller: _emailController,
                  prefixIcon: Iconsax.sms,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                )
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideX(begin: -0.1, end: 0),
                AppSpacing.verticalBase,

                // Phone
                Text(
                  'Phone Number',
                  style: AppTypography.labelMedium(
                    color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                  ),
                ),
                AppSpacing.verticalSm,
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? DarkThemeColors.inputBackground : LightThemeColors.inputBackground,
                    borderRadius: AppSpacing.borderRadiusBase,
                    border: Border.all(
                      color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                    ),
                  ),
                  child: Row(
                    children: [
                      CountryCodePicker(
                        selectedCode: _countryCode,
                        onChanged: (code) => setState(() => _countryCode = code),
                      ),
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
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 400.ms)
                    .slideX(begin: -0.1, end: 0),
                AppSpacing.verticalBase,

                // Gender
                AppDropdown<String>(
                  label: 'Gender (Optional)',
                  hint: 'Select gender',
                  value: _selectedGender,
                  items: const [
                    DropdownItem(value: 'male', label: 'Male'),
                    DropdownItem(value: 'female', label: 'Female'),
                  ],
                  onChanged: (value) => setState(() => _selectedGender = value),
                )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideX(begin: -0.1, end: 0),
                AppSpacing.verticalXl,

                // Terms & Conditions
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: _agreedToTerms ? AppColors.primary500 : Colors.transparent,
                          borderRadius: AppSpacing.borderRadiusSm,
                          border: Border.all(
                            color: _agreedToTerms
                                ? AppColors.primary500
                                : (isDark ? DarkThemeColors.border : LightThemeColors.border),
                            width: 2,
                          ),
                        ),
                        child: _agreedToTerms
                            ? const Icon(Icons.check, size: 16, color: Colors.white)
                            : null,
                      ),
                    ),
                    AppSpacing.horizontalMd,
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: 'I agree to the ',
                          style: AppTypography.bodySmall(
                            color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                          ),
                          children: [
                            TextSpan(
                              text: 'Terms of Service',
                              style: AppTypography.labelMedium(color: AppColors.primary500),
                            ),
                            const TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: AppTypography.labelMedium(color: AppColors.primary500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 600.ms),
                AppSpacing.verticalXl,

                // Sign Up Button
                AppButton(
                  text: 'Create Account',
                  onPressed: _handleSignup,
                  isLoading: authService.isLoading,
                  rightIcon: Iconsax.arrow_right_3,
                )
                    .animate()
                    .fadeIn(delay: 700.ms)
                    .slideY(begin: 0.3, end: 0),
                AppSpacing.verticalXxl,

                // Login Link
                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Already have an account? ',
                        style: AppTypography.bodyMedium(
                          color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Text(
                          'Sign In',
                          style: AppTypography.labelLarge(color: AppColors.primary500),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(delay: 800.ms),
                AppSpacing.verticalXxl,
              ],
            ),
          ),
        ),
        ),
      ),
    );
  }
}

