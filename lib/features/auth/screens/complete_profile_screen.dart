import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/auth_service.dart';
import '../../../shared/widgets/widgets.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  String? _nameError;
  String? _selectedGender;
  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _validateForm() {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Please enter your name');
      return false;
    }
    setState(() => _nameError = null);
    return true;
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    
    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _handleSave() async {
    if (!_validateForm()) return;

    final authService = context.read<AuthService>();
    
    // Split name into first and last name
    final nameParts = _nameController.text.trim().split(' ');
    final firstName = nameParts.first;
    final lastName = nameParts.length > 1 ? nameParts.sublist(1).join(' ') : firstName;

    final response = await authService.editProfile(
      firstName: firstName,
      lastName: lastName,
      email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
      gender: _selectedGender,
      profileImagePath: _selectedImage?.path,
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
                AppSpacing.verticalXxl,
                
                // Profile Picture
                GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: AppColors.primary500.withOpacity(0.1),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary500.withOpacity(0.3),
                            width: 3,
                          ),
                          image: _selectedImage != null
                              ? DecorationImage(
                                  image: FileImage(_selectedImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _selectedImage == null
                            ? const Icon(
                                Iconsax.user,
                                color: AppColors.primary500,
                                size: 40,
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: AppColors.primary500,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? DarkThemeColors.background : LightThemeColors.background,
                              width: 2,
                            ),
                          ),
                          child: const Icon(
                            Iconsax.camera,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .scale(delay: 100.ms, duration: 500.ms, curve: Curves.elasticOut),
                AppSpacing.verticalSm,
                Text(
                  'Tap to add photo',
                  style: AppTypography.caption(
                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  ),
                ).animate().fadeIn(delay: 150.ms),
                AppSpacing.verticalLg,
                
                // Title
                Text(
                  'Complete Your Profile',
                  style: AppTypography.headingLarge(
                    color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms)
                    .slideY(begin: 0.3, end: 0),
                AppSpacing.verticalSm,
                Text(
                  'Tell us a bit about yourself',
                  style: AppTypography.bodyMedium(
                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 300.ms)
                    .slideY(begin: 0.3, end: 0),
                AppSpacing.verticalXxl,
                
                // Name Input
                Text(
                  'Your Name *',
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
                      color: _nameError != null
                          ? AppColors.error
                          : (isDark ? DarkThemeColors.border : LightThemeColors.border),
                    ),
                  ),
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    style: AppTypography.bodyMedium(
                      color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your full name',
                      prefixIcon: Icon(
                        Iconsax.user,
                        color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                      ),
                    ),
                    onChanged: (_) {
                      if (_nameError != null) setState(() => _nameError = null);
                    },
                  ),
                )
                    .animate()
                    .fadeIn(delay: 500.ms)
                    .slideX(begin: -0.1, end: 0),
                if (_nameError != null) ...[
                  AppSpacing.verticalXs,
                  Text(
                    _nameError!,
                    style: AppTypography.caption(color: AppColors.error),
                  ),
                ],
                AppSpacing.verticalLg,
                
                // Email Input (Optional)
                Text(
                  'Email (Optional)',
                  style: AppTypography.labelMedium(
                    color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 600.ms),
                AppSpacing.verticalSm,
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? DarkThemeColors.inputBackground : LightThemeColors.inputBackground,
                    borderRadius: AppSpacing.borderRadiusBase,
                    border: Border.all(
                      color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                    ),
                  ),
                  child: TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    style: AppTypography.bodyMedium(
                      color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your email address',
                      prefixIcon: Icon(
                        Iconsax.sms,
                        color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.md,
                      ),
                      hintStyle: TextStyle(
                        color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                      ),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 700.ms)
                    .slideX(begin: -0.1, end: 0),
                AppSpacing.verticalLg,
                
                // Gender Selection
                Text(
                  'Gender (Optional)',
                  style: AppTypography.labelMedium(
                    color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 750.ms),
                AppSpacing.verticalSm,
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'male'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: _selectedGender == 'male'
                                ? AppColors.primary500.withOpacity(0.1)
                                : (isDark ? DarkThemeColors.inputBackground : LightThemeColors.inputBackground),
                            borderRadius: AppSpacing.borderRadiusBase,
                            border: Border.all(
                              color: _selectedGender == 'male'
                                  ? AppColors.primary500
                                  : (isDark ? DarkThemeColors.border : LightThemeColors.border),
                              width: _selectedGender == 'male' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.man,
                                color: _selectedGender == 'male'
                                    ? AppColors.primary500
                                    : (isDark ? AppColors.neutral500 : AppColors.neutral400),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Male',
                                style: AppTypography.bodyMedium(
                                  color: _selectedGender == 'male'
                                      ? AppColors.primary500
                                      : (isDark ? DarkThemeColors.text : LightThemeColors.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedGender = 'female'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                          decoration: BoxDecoration(
                            color: _selectedGender == 'female'
                                ? AppColors.primary500.withOpacity(0.1)
                                : (isDark ? DarkThemeColors.inputBackground : LightThemeColors.inputBackground),
                            borderRadius: AppSpacing.borderRadiusBase,
                            border: Border.all(
                              color: _selectedGender == 'female'
                                  ? AppColors.primary500
                                  : (isDark ? DarkThemeColors.border : LightThemeColors.border),
                              width: _selectedGender == 'female' ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Iconsax.woman,
                                color: _selectedGender == 'female'
                                    ? AppColors.primary500
                                    : (isDark ? AppColors.neutral500 : AppColors.neutral400),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Female',
                                style: AppTypography.bodyMedium(
                                  color: _selectedGender == 'female'
                                      ? AppColors.primary500
                                      : (isDark ? DarkThemeColors.text : LightThemeColors.text),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                )
                    .animate()
                    .fadeIn(delay: 780.ms)
                    .slideX(begin: -0.1, end: 0),
                AppSpacing.verticalXxl,
                
                // Save Button
                AppButton(
                  text: 'Get Started',
                  onPressed: _handleSave,
                  isLoading: authService.isLoading,
                  rightIcon: Iconsax.arrow_right_3,
                )
                    .animate()
                    .fadeIn(delay: 800.ms)
                    .slideY(begin: 0.3, end: 0),
                AppSpacing.verticalLg,
                
                // Skip Button
                Center(
                  child: TextButton(
                    onPressed: () {
                      // Skip profile completion, go to main app
                      Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
                    },
                    child: Text(
                      'Skip for now',
                      style: AppTypography.bodyMedium(
                        color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                      ).copyWith(decoration: TextDecoration.underline),
                    ),
                  ),
                ).animate().fadeIn(delay: 900.ms),
                
                AppSpacing.verticalXxl,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
