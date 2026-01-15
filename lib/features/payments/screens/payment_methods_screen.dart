import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/theme.dart';

/// Model for a payment card
class PaymentCard {
  final String id;
  final String cardNumber;
  final String cardHolderName;
  final String expiryDate;
  final String cvv;
  final String cardType; // visa, mastercard, amex
  final bool isDefault;

  PaymentCard({
    required this.id,
    required this.cardNumber,
    required this.cardHolderName,
    required this.expiryDate,
    required this.cvv,
    required this.cardType,
    this.isDefault = false,
  });

  String get maskedNumber {
    if (cardNumber.length < 4) return cardNumber;
    return '**** **** **** ${cardNumber.substring(cardNumber.length - 4)}';
  }

  String get formattedNumber {
    final cleaned = cardNumber.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < cleaned.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(cleaned[i]);
    }
    return buffer.toString();
  }
}

class PaymentMethodsScreen extends StatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  // Mock data - will be replaced with backend later
  List<PaymentCard> _cards = [
    PaymentCard(
      id: '1',
      cardNumber: '4532015112830366',
      cardHolderName: 'John Doe',
      expiryDate: '12/28',
      cvv: '123',
      cardType: 'visa',
      isDefault: true,
    ),
    PaymentCard(
      id: '2',
      cardNumber: '5425233430109903',
      cardHolderName: 'John Doe',
      expiryDate: '09/27',
      cvv: '456',
      cardType: 'mastercard',
      isDefault: false,
    ),
  ];

  void _setDefaultCard(String cardId) {
    setState(() {
      _cards = _cards.map((card) {
        return PaymentCard(
          id: card.id,
          cardNumber: card.cardNumber,
          cardHolderName: card.cardHolderName,
          expiryDate: card.expiryDate,
          cvv: card.cvv,
          cardType: card.cardType,
          isDefault: card.id == cardId,
        );
      }).toList();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Default payment method updated'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _deleteCard(String cardId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card'),
        content: const Text('Are you sure you want to remove this card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _cards.removeWhere((card) => card.id == cardId);
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Card removed'),
                  backgroundColor: AppColors.error,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _addNewCard() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddCardScreen(
        onCardAdded: (card) {
          setState(() {
            _cards.add(card);
          });
        },
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Payment Methods',
          style: AppTypography.headingSmall(
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: _cards.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.card, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(
                    'No payment methods',
                    style: AppTypography.bodyLarge(color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Add a card to get started',
                    style: AppTypography.bodySmall(color: Colors.grey[400]),
                  ),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _cards.length,
              itemBuilder: (context, index) {
                final card = _cards[index];
                return _CreditCardWidget(
                  card: card,
                  onSetDefault: () => _setDefaultCard(card.id),
                  onDelete: () => _deleteCard(card.id),
                ).animate(delay: Duration(milliseconds: 100 * index))
                 .fadeIn()
                 .slideX(begin: 0.1, end: 0);
              },
            ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: _addNewCard,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary500,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.add, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Add New Card',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Credit Card Visual Widget
class _CreditCardWidget extends StatelessWidget {
  final PaymentCard card;
  final VoidCallback onSetDefault;
  final VoidCallback onDelete;

  const _CreditCardWidget({
    required this.card,
    required this.onSetDefault,
    required this.onDelete,
  });

  Color get _cardGradientStart {
    switch (card.cardType.toLowerCase()) {
      case 'visa':
        return const Color(0xFF1A1F71);
      case 'mastercard':
        return const Color(0xFFEB001B);
      case 'amex':
        return const Color(0xFF006FCF);
      default:
        return const Color(0xFF434343);
    }
  }

  Color get _cardGradientEnd {
    switch (card.cardType.toLowerCase()) {
      case 'visa':
        return const Color(0xFF2E3B8F);
      case 'mastercard':
        return const Color(0xFFF79E1B);
      case 'amex':
        return const Color(0xFF0099DF);
      default:
        return const Color(0xFF1C1C1C);
    }
  }

  String get _cardTypeIcon {
    switch (card.cardType.toLowerCase()) {
      case 'visa':
        return 'VISA';
      case 'mastercard':
        return 'MC';
      case 'amex':
        return 'AMEX';
      default:
        return 'CARD';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        children: [
          // The Card Visual
          Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_cardGradientStart, _cardGradientEnd],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _cardGradientStart.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: [
                // Background Pattern
                Positioned(
                  right: -50,
                  top: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.1),
                    ),
                  ),
                ),
                Positioned(
                  left: -30,
                  bottom: -30,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                ),
                // Card Content
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row - Card Type & Default Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Chip
                          Container(
                            width: 45,
                            height: 35,
                            decoration: BoxDecoration(
                              color: Colors.amber[300],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Center(
                              child: Container(
                                width: 35,
                                height: 25,
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.amber[700]!, width: 1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                          if (card.isDefault)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text(
                                    'DEFAULT',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      // Card Number
                      Text(
                        card.formattedNumber,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Bottom Row - Name, Expiry, Card Type
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CARD HOLDER',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                card.cardHolderName.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'EXPIRES',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.7),
                                  fontSize: 10,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                card.expiryDate,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          // Card Type Logo
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _cardTypeIcon,
                              style: TextStyle(
                                color: _cardGradientStart,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Action Buttons
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Row(
              children: [
                if (!card.isDefault)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onSetDefault,
                      icon: const Icon(Iconsax.tick_circle, size: 18),
                      label: const Text('Set as Default'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary500,
                        side: BorderSide(color: AppColors.primary500.withOpacity(0.5)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                if (!card.isDefault) const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onDelete,
                    icon: const Icon(Iconsax.trash, size: 18),
                    label: const Text('Remove'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Add Card Screen
class AddCardScreen extends StatefulWidget {
  final Function(PaymentCard) onCardAdded;

  const AddCardScreen({super.key, required this.onCardAdded});

  @override
  State<AddCardScreen> createState() => _AddCardScreenState();
}

class _AddCardScreenState extends State<AddCardScreen> {
  final _formKey = GlobalKey<FormState>();
  final _cardNumberController = TextEditingController();
  final _cardHolderController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  
  String _cardType = 'unknown';
  bool _isFlipped = false;

  @override
  void initState() {
    super.initState();
    _cardNumberController.addListener(_detectCardType);
  }

  @override
  void dispose() {
    _cardNumberController.dispose();
    _cardHolderController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  void _detectCardType() {
    final number = _cardNumberController.text.replaceAll(' ', '');
    if (number.isEmpty) {
      setState(() => _cardType = 'unknown');
      return;
    }

    if (number.startsWith('4')) {
      setState(() => _cardType = 'visa');
    } else if (number.startsWith('5') || number.startsWith('2')) {
      setState(() => _cardType = 'mastercard');
    } else if (number.startsWith('3')) {
      setState(() => _cardType = 'amex');
    } else {
      setState(() => _cardType = 'unknown');
    }
  }

  void _saveCard() {
    if (_formKey.currentState!.validate()) {
      final newCard = PaymentCard(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        cardNumber: _cardNumberController.text.replaceAll(' ', ''),
        cardHolderName: _cardHolderController.text,
        expiryDate: _expiryController.text,
        cvv: _cvvController.text,
        cardType: _cardType == 'unknown' ? 'visa' : _cardType,
        isDefault: false,
      );
      
      widget.onCardAdded(newCard);
      Navigator.pop(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Card added successfully'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Color get _previewCardColor {
    switch (_cardType) {
      case 'visa':
        return const Color(0xFF1A1F71);
      case 'mastercard':
        return const Color(0xFFEB001B);
      case 'amex':
        return const Color(0xFF006FCF);
      default:
        return const Color(0xFF434343);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Add Card',
          style: AppTypography.headingSmall(
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      resizeToAvoidBottomInset: true,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card Preview
              GestureDetector(
                onTap: () => setState(() => _isFlipped = !_isFlipped),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 180,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _previewCardColor,
                        _previewCardColor.withOpacity(0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: _previewCardColor.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: _isFlipped ? _buildCardBack() : _buildCardFront(),
                  ),
                ),
              ),
              
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Tap card to flip',
                  style: AppTypography.bodySmall(color: Colors.grey),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Card Number Field
              Text('Card Number', style: AppTypography.labelLarge(
                color: isDark ? Colors.white : Colors.black87,
              )),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cardNumberController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(16),
                  _CardNumberFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: '0000 0000 0000 0000',
                  prefixIcon: Icon(
                    Iconsax.card,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  suffixIcon: _cardType != 'unknown' 
                      ? Padding(
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: _previewCardColor,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _cardType.toUpperCase(),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary500, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter card number';
                  }
                  if (value.replaceAll(' ', '').length < 16) {
                    return 'Please enter a valid card number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Card Holder Name
              Text('Card Holder Name', style: AppTypography.labelLarge(
                color: isDark ? Colors.white : Colors.black87,
              )),
              const SizedBox(height: 8),
              TextFormField(
                controller: _cardHolderController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'JOHN DOE',
                  prefixIcon: Icon(
                    Iconsax.user,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? Colors.white24 : Colors.grey.shade300,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.primary500, width: 2),
                  ),
                  filled: true,
                  fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter card holder name';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Expiry and CVV Row
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Expiry Date', style: AppTypography.labelLarge(
                          color: isDark ? Colors.white : Colors.black87,
                        )),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _expiryController,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                            _ExpiryDateFormatter(),
                          ],
                          decoration: InputDecoration(
                            hintText: 'MM/YY',
                            prefixIcon: Icon(
                              Iconsax.calendar,
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary500, width: 2),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (value.length < 5) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('CVV', style: AppTypography.labelLarge(
                          color: isDark ? Colors.white : Colors.black87,
                        )),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _cvvController,
                          keyboardType: TextInputType.number,
                          obscureText: true,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(4),
                          ],
                          onTap: () => setState(() => _isFlipped = true),
                          decoration: InputDecoration(
                            hintText: '***',
                            prefixIcon: Icon(
                              Iconsax.lock,
                              color: isDark ? Colors.white54 : Colors.grey,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey.shade300),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: isDark ? Colors.white24 : Colors.grey.shade300,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: AppColors.primary500, width: 2),
                            ),
                            filled: true,
                            fillColor: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Required';
                            }
                            if (value.length < 3) {
                              return 'Invalid';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveCard,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary500,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Save Card',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Security Note
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.info.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Iconsax.shield_tick, color: AppColors.info, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Your card details are securely encrypted and stored.',
                        style: AppTypography.bodySmall(color: AppColors.info),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Chip
          Container(
            width: 40,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.amber[300],
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(height: 20),
          // Card Number
          Text(
            _cardNumberController.text.isEmpty 
                ? '**** **** **** ****' 
                : _formatPreviewNumber(_cardNumberController.text),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
            ),
          ),
          const SizedBox(height: 16),
          // Bottom Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'CARD HOLDER',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _cardHolderController.text.isEmpty 
                        ? 'YOUR NAME' 
                        : _cardHolderController.text.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'EXPIRES',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 9,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _expiryController.text.isEmpty ? 'MM/YY' : _expiryController.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              if (_cardType != 'unknown')
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    _cardType.toUpperCase(),
                    style: TextStyle(
                      color: _previewCardColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        // Magnetic Strip
        Container(
          height: 40,
          color: Colors.black87,
        ),
        const SizedBox(height: 12),
        // CVV Strip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.grey[200],
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              bottomLeft: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 60,
                        alignment: Alignment.center,
                        child: Text(
                          _cvvController.text.isEmpty ? '***' : _cvvController.text,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            'This card is property of ChiHelo. If found, please return.',
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 10,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  String _formatPreviewNumber(String number) {
    final cleaned = number.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < 16; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      if (i < cleaned.length) {
        buffer.write(cleaned[i]);
      } else {
        buffer.write('*');
      }
    }
    return buffer.toString();
  }
}

/// Input formatter for card number (adds spaces every 4 digits)
class _CardNumberFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll(' ', '');
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(text[i]);
    }
    return TextEditingValue(
      text: buffer.toString(),
      selection: TextSelection.collapsed(offset: buffer.length),
    );
  }
}

/// Input formatter for expiry date (MM/YY format)
class _ExpiryDateFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text.replaceAll('/', '');
    if (text.length >= 2) {
      return TextEditingValue(
        text: '${text.substring(0, 2)}/${text.substring(2)}',
        selection: TextSelection.collapsed(offset: text.length + 1),
      );
    }
    return newValue;
  }
}
