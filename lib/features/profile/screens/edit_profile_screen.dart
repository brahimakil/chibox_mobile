import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/theme.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _emailController;
  String? _selectedGender;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _selectedGender = user?.gender;
    
    // Handle empty gender string if necessary
    if (_selectedGender == '') _selectedGender = null;

    // Validate gender against allowed values to prevent DropdownButton error
    const allowedGenders = ['male', 'female'];
    if (_selectedGender != null) {
      // Try to match case-insensitive
      final lowerGender = _selectedGender!.toLowerCase();
      if (allowedGenders.contains(lowerGender)) {
        _selectedGender = lowerGender;
      } else {
        _selectedGender = null;
      }
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final authService = context.read<AuthService>();
    final response = await authService.editProfile(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      email: _emailController.text.trim(),
      gender: _selectedGender,
    );

    setState(() => _isLoading = false);

    if (!mounted) return;

    if (response.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.message ?? 'Failed to update profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Personal Information',
                style: AppTypography.headingSmall(
                  color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                ),
              ),
              AppSpacing.verticalLg,
              
              // First Name
              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icon(Iconsax.user),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your first name';
                  }
                  return null;
                },
              ),
              AppSpacing.verticalMd,

              // Last Name
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: Icon(Iconsax.user),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your last name';
                  }
                  return null;
                },
              ),
              AppSpacing.verticalMd,

              // Email
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Iconsax.sms),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!value.contains('@')) {
                      return 'Please enter a valid email';
                    }
                  }
                  return null;
                },
              ),
              AppSpacing.verticalMd,

              // Gender
              DropdownButtonFormField<String>(
                value: _selectedGender,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Iconsax.profile_2user),
                ),
                dropdownColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                icon: Icon(
                  Icons.keyboard_arrow_down,
                  color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'male', 
                    child: Text(
                      'Male',
                      style: AppTypography.bodyMedium(
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ),
                    ),
                  ),
                  DropdownMenuItem(
                    value: 'female', 
                    child: Text(
                      'Female',
                      style: AppTypography.bodyMedium(
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ),
                    ),
                  ),
                ],
                onChanged: (value) {
                  setState(() => _selectedGender = value);
                },
              ),
              AppSpacing.verticalXl,

              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary500,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppSpacing.borderRadiusBase,
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Save Changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
