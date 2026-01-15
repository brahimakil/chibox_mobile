import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
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
  File? _selectedImage;
  String? _currentImageUrl;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthService>().currentUser;
    _firstNameController = TextEditingController(text: user?.firstName ?? '');
    _lastNameController = TextEditingController(text: user?.lastName ?? '');
    _emailController = TextEditingController(text: user?.email ?? '');
    _selectedGender = user?.gender;
    _currentImageUrl = user?.mainImage;
    
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

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    
    if (pickedFile != null) {
      // Crop the image
      final croppedFile = await _cropImage(pickedFile.path);
      if (croppedFile != null) {
        setState(() {
          _selectedImage = File(croppedFile.path);
        });
      }
    }
  }

  Future<CroppedFile?> _cropImage(String imagePath) async {
    return await ImageCropper().cropImage(
      sourcePath: imagePath,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Photo',
          toolbarColor: AppColors.primary500,
          toolbarWidgetColor: Colors.white,
          activeControlsWidgetColor: AppColors.primary500,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: false,
          hideBottomControls: false,
        ),
        IOSUiSettings(
          title: 'Crop Profile Photo',
          aspectRatioLockEnabled: false,
          resetAspectRatioEnabled: true,
        ),
      ],
    );
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
      profileImagePath: _selectedImage?.path,
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
              // Profile Picture
              Center(
                child: GestureDetector(
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
                        ),
                        child: ClipOval(
                          child: _selectedImage != null
                              ? Image.file(
                                  _selectedImage!,
                                  fit: BoxFit.cover,
                                  width: 100,
                                  height: 100,
                                )
                              : _currentImageUrl != null && _currentImageUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _currentImageUrl!,
                                      fit: BoxFit.cover,
                                      width: 100,
                                      height: 100,
                                      placeholder: (context, url) => const Center(
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                      errorWidget: (context, url, error) => Icon(
                                        Iconsax.user,
                                        color: AppColors.primary500,
                                        size: 40,
                                      ),
                                    )
                                  : Icon(
                                      Iconsax.user,
                                      color: AppColors.primary500,
                                      size: 40,
                                    ),
                        ),
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
                ),
              ),
              AppSpacing.verticalSm,
              Center(
                child: Text(
                  'Tap to change photo',
                  style: AppTypography.caption(
                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  ),
                ),
              ),
              AppSpacing.verticalXl,
              
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
                textCapitalization: TextCapitalization.words,
                inputFormatters: [_CapitalizeWordsFormatter()],
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
                textCapitalization: TextCapitalization.words,
                inputFormatters: [_CapitalizeWordsFormatter()],
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

/// TextInputFormatter that capitalizes the first letter of each word
class _CapitalizeWordsFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    // Capitalize the first letter of each word
    final words = newValue.text.split(' ');
    final capitalizedWords = words.map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1);
    }).join(' ');

    return TextEditingValue(
      text: capitalizedWords,
      selection: newValue.selection,
    );
  }
}