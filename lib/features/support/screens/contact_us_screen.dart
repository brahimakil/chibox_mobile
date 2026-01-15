import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';

class ContactUsScreen extends StatefulWidget {
  const ContactUsScreen({super.key});

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _subjectController = TextEditingController();
  final _messageController = TextEditingController();
  String _selectedCategory = 'General Inquiry';
  bool _isLoading = false;

  final List<String> _categories = [
    'General Inquiry',
    'Order Issue',
    'Payment Problem',
    'Product Question',
    'Return/Refund',
    'Technical Support',
    'Feedback',
    'Other',
  ];

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _subjectController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Simulate API call
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() => _isLoading = false);
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Iconsax.tick_circle,
                color: AppColors.success,
                size: 48,
              ),
            ).animate().scale(duration: 300.ms, curve: Curves.elasticOut),
            const SizedBox(height: 20),
            Text(
              'Message Sent!',
              style: AppTypography.headingSmall(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Thank you for contacting us. We\'ll get back to you within 24 hours.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium(
                color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Done', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      appBar: AppBar(
        title: Text(
          'Contact Us',
          style: AppTypography.headingSmall(
            color: isDark ? DarkThemeColors.text : LightThemeColors.text,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: isDark ? DarkThemeColors.text : LightThemeColors.text,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [const Color(0xFF1E3A5F), const Color(0xFF0D1B2A)]
                      : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF3B82F6).withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Iconsax.message,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Get in Touch',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We\'d love to hear from you!',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1, end: 0),

            const SizedBox(height: 24),

            // Contact Options
            Row(
              children: [
                Expanded(
                  child: _ContactCard(
                    icon: Iconsax.call,
                    title: 'Phone',
                    subtitle: '+1 800 123 456',
                    color: const Color(0xFF10B981),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ContactCard(
                    icon: Iconsax.sms,
                    title: 'Email',
                    subtitle: 'support@chihelo.com',
                    color: const Color(0xFFF59E0B),
                    isDark: isDark,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: _ContactCard(
                    icon: Iconsax.location,
                    title: 'Address',
                    subtitle: 'Dubai, UAE',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ContactCard(
                    icon: Iconsax.clock,
                    title: 'Hours',
                    subtitle: '9AM - 6PM',
                    color: const Color(0xFFEF4444),
                    isDark: isDark,
                  ),
                ),
              ],
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 32),

            // Contact Form
            Text(
              'Send us a Message',
              style: AppTypography.headingSmall(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ).animate().fadeIn(delay: 300.ms),

            const SizedBox(height: 16),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  // Name Field
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    icon: Iconsax.user,
                    isDark: isDark,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ).animate().fadeIn(delay: 350.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  // Email Field
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    icon: Iconsax.sms,
                    isDark: isDark,
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!value.contains('@')) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  // Category Dropdown
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        icon: Icon(Iconsax.category),
                      ),
                      dropdownColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                      style: TextStyle(
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ),
                      items: _categories.map((category) {
                        return DropdownMenuItem(
                          value: category,
                          child: Text(category),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _selectedCategory = value);
                        }
                      },
                    ),
                  ).animate().fadeIn(delay: 450.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  // Subject Field
                  _buildTextField(
                    controller: _subjectController,
                    label: 'Subject',
                    icon: Iconsax.document_text,
                    isDark: isDark,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a subject';
                      }
                      return null;
                    },
                  ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 16),

                  // Message Field
                  _buildTextField(
                    controller: _messageController,
                    label: 'Your Message',
                    icon: Iconsax.message_text,
                    isDark: isDark,
                    maxLines: 5,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your message';
                      }
                      if (value.length < 10) {
                        return 'Message must be at least 10 characters';
                      }
                      return null;
                    },
                  ).animate().fadeIn(delay: 550.ms).slideX(begin: -0.1, end: 0),

                  const SizedBox(height: 24),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary500,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        disabledBackgroundColor: AppColors.primary500.withOpacity(0.5),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Iconsax.send_1, color: Colors.white, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Send Message',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.1, end: 0),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Social Media Section
            Center(
              child: Column(
                children: [
                  Text(
                    'Follow us on Social Media',
                    style: AppTypography.labelMedium(
                      color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _SocialButton(
                        icon: Icons.facebook,
                        color: const Color(0xFF1877F2),
                        isDark: isDark,
                        onTap: () {},
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        icon: Icons.camera_alt,
                        color: const Color(0xFFE4405F),
                        isDark: isDark,
                        onTap: () {},
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        icon: Icons.message,
                        color: const Color(0xFF1DA1F2),
                        isDark: isDark,
                        onTap: () {},
                      ),
                      const SizedBox(width: 16),
                      _SocialButton(
                        icon: Icons.play_arrow,
                        color: const Color(0xFFFF0000),
                        isDark: isDark,
                        onTap: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ).animate().fadeIn(delay: 700.ms),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
        ),
        prefixIcon: maxLines == 1 ? Icon(icon, color: isDark ? DarkThemeColors.icon : LightThemeColors.icon) : null,
        filled: true,
        fillColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? DarkThemeColors.border : LightThemeColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? DarkThemeColors.border : LightThemeColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary500, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;

  const _ContactCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? DarkThemeColors.border : LightThemeColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: AppTypography.labelSmall(
              color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTypography.labelMedium(
              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
            ),
          ),
        ],
      ),
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? DarkThemeColors.border : LightThemeColors.border,
          ),
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }
}
