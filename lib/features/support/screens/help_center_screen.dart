import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';

class HelpCenterScreen extends StatefulWidget {
  const HelpCenterScreen({super.key});

  @override
  State<HelpCenterScreen> createState() => _HelpCenterScreenState();
}

class _HelpCenterScreenState extends State<HelpCenterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  final List<_FAQCategory> _categories = [
    _FAQCategory(
      icon: Iconsax.box,
      title: 'Orders & Shipping',
      color: const Color(0xFF3B82F6),
      faqs: [
        _FAQ(
          question: 'How can I track my order?',
          answer: 'You can track your order by going to "My Orders" in your profile. Click on any order to see its current status and tracking information.',
        ),
        _FAQ(
          question: 'What are the shipping options?',
          answer: 'We offer standard shipping (5-7 business days) and express shipping (2-3 business days). Shipping costs vary based on your location and order total.',
        ),
        _FAQ(
          question: 'Can I change my delivery address?',
          answer: 'You can change your delivery address before the order is shipped. Go to "My Orders", select the order, and tap "Edit Address" if available.',
        ),
      ],
    ),
    _FAQCategory(
      icon: Iconsax.card,
      title: 'Payments & Refunds',
      color: const Color(0xFF10B981),
      faqs: [
        _FAQ(
          question: 'What payment methods do you accept?',
          answer: 'We accept Cash on Delivery, Credit/Debit Cards (Visa, Mastercard, Amex), and Digital Wallets (Apple Pay, Google Pay). More options coming soon!',
        ),
        _FAQ(
          question: 'How do I get a refund?',
          answer: 'To request a refund, go to "My Orders", select the order, and tap "Request Refund". Refunds are processed within 5-7 business days.',
        ),
        _FAQ(
          question: 'Is my payment information secure?',
          answer: 'Yes! We use industry-standard encryption to protect your payment information. We never store your full card details.',
        ),
      ],
    ),
    _FAQCategory(
      icon: Iconsax.user,
      title: 'Account & Profile',
      color: const Color(0xFF8B5CF6),
      faqs: [
        _FAQ(
          question: 'How do I update my profile?',
          answer: 'Go to Profile > Edit Profile. You can update your name, email, phone number, and profile picture.',
        ),
        _FAQ(
          question: 'How do I change my password?',
          answer: 'Go to Profile > Security > Change Password. You\'ll need to enter your current password and then your new password.',
        ),
        _FAQ(
          question: 'Can I delete my account?',
          answer: 'Yes, you can delete your account by going to Profile > Security > Delete Account. Please note this action is irreversible.',
        ),
      ],
    ),
    _FAQCategory(
      icon: Iconsax.box_remove,
      title: 'Returns & Exchanges',
      color: const Color(0xFFF59E0B),
      faqs: [
        _FAQ(
          question: 'What is your return policy?',
          answer: 'We accept returns within 30 days of delivery for most items. Products must be unused and in original packaging.',
        ),
        _FAQ(
          question: 'How do I initiate a return?',
          answer: 'Go to "My Orders", select the order, and tap "Return Item". Follow the instructions to print a return label.',
        ),
        _FAQ(
          question: 'Can I exchange an item?',
          answer: 'Yes! You can exchange items for a different size or color. Go to your order and select "Exchange" option.',
        ),
      ],
    ),
  ];

  List<_FAQCategory> get _filteredCategories {
    if (_searchQuery.isEmpty) return _categories;
    
    return _categories.map((category) {
      final filteredFaqs = category.faqs.where((faq) =>
        faq.question.toLowerCase().contains(_searchQuery.toLowerCase()) ||
        faq.answer.toLowerCase().contains(_searchQuery.toLowerCase())
      ).toList();
      
      return _FAQCategory(
        icon: category.icon,
        title: category.title,
        color: category.color,
        faqs: filteredFaqs,
      );
    }).where((category) => category.faqs.isNotEmpty).toList();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? DarkThemeColors.background : LightThemeColors.background,
      appBar: AppBar(
        title: Text(
          'Help Center',
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
                      ? [AppColors.primary900, AppColors.primary950]
                      : [AppColors.primary500, AppColors.primary700],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary500.withOpacity(0.3),
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
                      Iconsax.message_question,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'How can we help you?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Search for answers or browse topics below',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ).animate().fadeIn().slideY(begin: -0.1, end: 0),

            const SizedBox(height: 20),

            // Search Bar
            Container(
              decoration: BoxDecoration(
                color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (value) => setState(() => _searchQuery = value),
                style: TextStyle(
                  color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                ),
                decoration: InputDecoration(
                  hintText: 'Search for help...',
                  hintStyle: TextStyle(
                    color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                  ),
                  prefixIcon: Icon(
                    Iconsax.search_normal,
                    color: isDark ? DarkThemeColors.icon : LightThemeColors.icon,
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(
                            Iconsax.close_circle,
                            color: isDark ? DarkThemeColors.icon : LightThemeColors.icon,
                          ),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                ),
              ),
            ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),

            const SizedBox(height: 24),

            // Quick Actions
            if (_searchQuery.isEmpty) ...[
              Text(
                'Quick Actions',
                style: AppTypography.labelLarge(
                  color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _QuickActionCard(
                      icon: Iconsax.message,
                      title: 'Chat with us',
                      subtitle: 'Get instant help',
                      color: const Color(0xFF3B82F6),
                      isDark: isDark,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Chat feature coming soon!')),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _QuickActionCard(
                      icon: Iconsax.call,
                      title: 'Call us',
                      subtitle: '+1 800 123 456',
                      color: const Color(0xFF10B981),
                      isDark: isDark,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Calling feature coming soon!')),
                        );
                      },
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1, end: 0),
              const SizedBox(height: 24),
            ],

            // FAQ Categories
            Text(
              _searchQuery.isEmpty ? 'Browse Topics' : 'Search Results',
              style: AppTypography.labelLarge(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
            const SizedBox(height: 12),

            if (_filteredCategories.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Column(
                    children: [
                      Icon(
                        Iconsax.search_status,
                        size: 64,
                        color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No results found',
                        style: AppTypography.bodyLarge(
                          color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Try different keywords',
                        style: AppTypography.bodySmall(
                          color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...List.generate(_filteredCategories.length, (index) {
                return _FAQCategoryCard(
                  category: _filteredCategories[index],
                  isDark: isDark,
                ).animate().fadeIn(delay: Duration(milliseconds: 300 + (index * 100))).slideX(begin: -0.1, end: 0);
              }),

            const SizedBox(height: 24),

            // Still need help section
            if (_searchQuery.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary500.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Iconsax.headphone,
                        color: AppColors.primary500,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Still need help?',
                            style: AppTypography.labelLarge(
                              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Our support team is here for you',
                            style: AppTypography.bodySmall(
                              color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Iconsax.arrow_right_3,
                      color: isDark ? DarkThemeColors.icon : LightThemeColors.icon,
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms),
          ],
        ),
      ),
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
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
              style: AppTypography.labelMedium(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: AppTypography.bodySmall(
                color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQCategoryCard extends StatelessWidget {
  final _FAQCategory category;
  final bool isDark;

  const _FAQCategoryCard({
    required this.category,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? DarkThemeColors.border : LightThemeColors.border,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          leading: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: category.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(category.icon, color: category.color, size: 20),
          ),
          title: Text(
            category.title,
            style: AppTypography.labelLarge(
              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
            ),
          ),
          subtitle: Text(
            '${category.faqs.length} articles',
            style: AppTypography.bodySmall(
              color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
            ),
          ),
          children: category.faqs.map((faq) => _FAQItem(faq: faq, isDark: isDark)).toList(),
        ),
      ),
    );
  }
}

class _FAQItem extends StatelessWidget {
  final _FAQ faq;
  final bool isDark;

  const _FAQItem({required this.faq, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: isDark ? DarkThemeColors.backgroundSecondary : LightThemeColors.backgroundSecondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          title: Text(
            faq.question,
            style: AppTypography.bodyMedium(
              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
            ),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                faq.answer,
                style: AppTypography.bodySmall(
                  color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FAQCategory {
  final IconData icon;
  final String title;
  final Color color;
  final List<_FAQ> faqs;

  _FAQCategory({
    required this.icon,
    required this.title,
    required this.color,
    required this.faqs,
  });
}

class _FAQ {
  final String question;
  final String answer;

  _FAQ({required this.question, required this.answer});
}
