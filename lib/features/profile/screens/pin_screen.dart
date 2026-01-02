import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/services/security_service.dart';
import '../../../core/theme/theme.dart';

enum PinMode { create, verify, confirm }

class PinScreen extends StatefulWidget {
  final PinMode mode;
  final VoidCallback? onSuccess;
  final String? title;
  final bool showBackButton;
  final VoidCallback? onBiometricAuth;

  const PinScreen({
    super.key,
    required this.mode,
    this.onSuccess,
    this.title,
    this.showBackButton = true,
    this.onBiometricAuth,
  });

  @override
  State<PinScreen> createState() => _PinScreenState();
}

class _PinScreenState extends State<PinScreen> {
  String _pin = '';
  String? _firstPin; // Used for confirm mode
  bool _isLoading = false;
  String _error = '';

  void _onDigitPress(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _error = '';
      });

      if (_pin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onDeletePress() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _error = '';
      });
    }
  }

  Future<void> _handlePinComplete() async {
    final securityService = context.read<SecurityService>();

    if (widget.mode == PinMode.create) {
      // Move to confirm step
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _ConfirmPinScreen(
            firstPin: _pin,
            onSuccess: widget.onSuccess,
          ),
        ),
      );
    } else if (widget.mode == PinMode.verify) {
      setState(() => _isLoading = true);
      final isValid = await securityService.verifyPin(_pin);
      setState(() => _isLoading = false);

      if (isValid) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _error = 'Incorrect PIN';
          _pin = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: Text(widget.title ?? (widget.mode == PinMode.create ? 'Set PIN' : 'Enter PIN')),
        leading: widget.showBackButton
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: SafeArea(
        child: Column(
          children: [
            AppSpacing.verticalXxl,
            Text(
              widget.mode == PinMode.create ? 'Create a 4-digit PIN' : 'Enter your PIN',
              style: AppTypography.bodyLarge(
                color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
              ),
            ),
            AppSpacing.verticalLg,
            
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? AppColors.primary500
                        : (isDark ? DarkThemeColors.border : LightThemeColors.border),
                    border: isFilled
                        ? null
                        : Border.all(
                            color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                          ),
                  ),
                );
              }),
            ),
            
            if (_error.isNotEmpty) ...[
              AppSpacing.verticalLg,
              Text(
                _error,
                style: AppTypography.bodyMedium(color: AppColors.error),
              ).animate().shake(),
            ],

            if (widget.onBiometricAuth != null) ...[
              AppSpacing.verticalLg,
              TextButton.icon(
                onPressed: widget.onBiometricAuth,
                icon: const Icon(
                  Icons.fingerprint,
                  color: AppColors.primary500,
                ),
                label: Text(
                  'Use Biometrics',
                  style: AppTypography.bodyMedium(
                    color: AppColors.primary500,
                  ),
                ),
              ),
            ],

            AppSpacing.verticalXxl,

            // Keypad
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3'], isDark),
                  AppSpacing.verticalLg,
                  _buildRow(['4', '5', '6'], isDark),
                  AppSpacing.verticalLg,
                  _buildRow(['7', '8', '9'], isDark),
                  AppSpacing.verticalLg,
                  _buildRow(['', '0', 'del'], isDark),
                ],
              ),
            ),
            AppSpacing.verticalXl,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox(width: 72, height: 72);
        
        if (key == 'del') {
          return GestureDetector(
            onTap: _onDeletePress,
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              child: Icon(
                Iconsax.arrow_left_2,
                size: 32,
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () => _onDigitPress(key),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
              border: Border.all(
                color: isDark ? DarkThemeColors.border : LightThemeColors.border,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              key,
              style: AppTypography.headingMedium(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ConfirmPinScreen extends StatefulWidget {
  final String firstPin;
  final VoidCallback? onSuccess;

  const _ConfirmPinScreen({
    required this.firstPin,
    this.onSuccess,
  });

  @override
  State<_ConfirmPinScreen> createState() => _ConfirmPinScreenState();
}

class _ConfirmPinScreenState extends State<_ConfirmPinScreen> {
  String _pin = '';
  bool _isLoading = false;
  String _error = '';

  void _onDigitPress(String digit) {
    if (_pin.length < 4) {
      setState(() {
        _pin += digit;
        _error = '';
      });

      if (_pin.length == 4) {
        _handlePinComplete();
      }
    }
  }

  void _onDeletePress() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _error = '';
      });
    }
  }

  Future<void> _handlePinComplete() async {
    if (_pin == widget.firstPin) {
      setState(() => _isLoading = true);
      final securityService = context.read<SecurityService>();
      final success = await securityService.setPin(_pin);
      setState(() => _isLoading = false);

      if (success) {
        if (widget.onSuccess != null) {
          widget.onSuccess!();
        } else {
          Navigator.pop(context); // Pop confirm screen
          Navigator.pop(context); // Pop create screen (handled by replacement but just in case)
        }
      } else {
        setState(() {
          _error = 'Failed to set PIN';
          _pin = '';
        });
      }
    } else {
      setState(() {
        _error = 'PINs do not match';
        _pin = '';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Confirm PIN'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            AppSpacing.verticalXxl,
            Text(
              'Re-enter your PIN to confirm',
              style: AppTypography.bodyLarge(
                color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
              ),
            ),
            AppSpacing.verticalLg,
            
            // PIN Dots
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final isFilled = index < _pin.length;
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isFilled
                        ? AppColors.primary500
                        : (isDark ? DarkThemeColors.border : LightThemeColors.border),
                    border: isFilled
                        ? null
                        : Border.all(
                            color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                          ),
                  ),
                );
              }),
            ),
            
            if (_error.isNotEmpty) ...[
              AppSpacing.verticalLg,
              Text(
                _error,
                style: AppTypography.bodyMedium(color: AppColors.error),
              ).animate().shake(),
            ],

            AppSpacing.verticalXxl,

            // Keypad
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  _buildRow(['1', '2', '3'], isDark),
                  AppSpacing.verticalLg,
                  _buildRow(['4', '5', '6'], isDark),
                  AppSpacing.verticalLg,
                  _buildRow(['7', '8', '9'], isDark),
                  AppSpacing.verticalLg,
                  _buildRow(['', '0', 'del'], isDark),
                ],
              ),
            ),
            AppSpacing.verticalXl,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(List<String> keys, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        if (key.isEmpty) return const SizedBox(width: 72, height: 72);
        
        if (key == 'del') {
          return GestureDetector(
            onTap: _onDeletePress,
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              child: Icon(
                Iconsax.arrow_left_2,
                size: 32,
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
          );
        }

        return GestureDetector(
          onTap: () => _onDigitPress(key),
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
              border: Border.all(
                color: isDark ? DarkThemeColors.border : LightThemeColors.border,
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              key,
              style: AppTypography.headingMedium(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
