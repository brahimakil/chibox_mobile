import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme.dart';

/// Custom Text Field Widget
class AppTextField extends StatefulWidget {
  final String? label;
  final String? hint;
  final String? errorText;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final int maxLines;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool autofocus;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final AutovalidateMode? autovalidateMode;

  const AppTextField({
    super.key,
    this.label,
    this.hint,
    this.errorText,
    this.controller,
    this.focusNode,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.maxLines = 1,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.autofocus = false,
    this.inputFormatters,
    this.onChanged,
    this.onTap,
    this.onSubmitted,
    this.validator,
    this.autovalidateMode,
  });

  @override
  State<AppTextField> createState() => _AppTextFieldState();
}

class _AppTextFieldState extends State<AppTextField> {
  late bool _obscureText;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _obscureText = widget.obscureText;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          Text(
            widget.label!,
            style: AppTypography.labelMedium(
              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
            ),
          ),
          AppSpacing.verticalSm,
        ],
        Focus(
          onFocusChange: (hasFocus) => setState(() => _isFocused = hasFocus),
          child: TextFormField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            obscureText: _obscureText,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            maxLines: widget.obscureText ? 1 : widget.maxLines,
            maxLength: widget.maxLength,
            autofocus: widget.autofocus,
            inputFormatters: widget.inputFormatters,
            onChanged: widget.onChanged,
            onTap: widget.onTap,
            onFieldSubmitted: widget.onSubmitted,
            validator: widget.validator,
            autovalidateMode: widget.autovalidateMode,
            style: AppTypography.bodyMedium(
              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              errorText: widget.errorText,
              prefixIcon: widget.prefixIcon != null
                  ? Icon(
                      widget.prefixIcon,
                      color: _isFocused
                          ? AppColors.primary500
                          : (isDark ? AppColors.neutral500 : AppColors.neutral400),
                      size: 20,
                    )
                  : null,
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _obscureText ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscureText = !_obscureText),
                    )
                  : widget.suffix,
              counterText: '',
            ),
          ),
        ),
      ],
    );
  }
}

/// Phone Input Field with country code
class PhoneInputField extends StatelessWidget {
  final TextEditingController? phoneController;
  final String? countryCode;
  final VoidCallback? onCountryCodeTap;
  final ValueChanged<String>? onPhoneChanged;
  final String? errorText;
  final String? label;

  const PhoneInputField({
    super.key,
    this.phoneController,
    this.countryCode = '+971',
    this.onCountryCodeTap,
    this.onPhoneChanged,
    this.errorText,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          Text(
            label!,
            style: AppTypography.labelMedium(
              color: isDark ? DarkThemeColors.text : LightThemeColors.text,
            ),
          ),
          AppSpacing.verticalSm,
        ],
        Container(
          decoration: BoxDecoration(
            color: isDark ? DarkThemeColors.inputBackground : LightThemeColors.inputBackground,
            borderRadius: AppSpacing.borderRadiusBase,
            border: Border.all(
              color: errorText != null
                  ? AppColors.error
                  : (isDark ? DarkThemeColors.border : LightThemeColors.border),
            ),
          ),
          child: Row(
            children: [
              // Country Code Selector
              InkWell(
                onTap: onCountryCodeTap,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(AppSpacing.radiusBase),
                  bottomLeft: Radius.circular(AppSpacing.radiusBase),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      right: BorderSide(
                        color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        countryCode ?? '+971',
                        style: AppTypography.bodyMedium(
                          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                        ),
                      ),
                      AppSpacing.horizontalXs,
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                      ),
                    ],
                  ),
                ),
              ),
              // Phone Number Input
              Expanded(
                child: TextField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  onChanged: onPhoneChanged,
                  style: AppTypography.bodyMedium(
                    color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                    hintStyle: TextStyle(
                      color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(15),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (errorText != null) ...[
          AppSpacing.verticalXs,
          Text(
            errorText!,
            style: AppTypography.caption(color: AppColors.error),
          ),
        ],
      ],
    );
  }
}

/// OTP Input Field
class OtpInputField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;

  const OtpInputField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
  });

  @override
  State<OtpInputField> createState() => _OtpInputFieldState();
}

class _OtpInputFieldState extends State<OtpInputField> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(widget.length, (_) => TextEditingController());
    _focusNodes = List.generate(widget.length, (_) => FocusNode());
  }

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  void _onChanged(int index, String value) {
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < digits.length; i++) {
        if (index + i < widget.length) {
          _controllers[index + i].text = digits[i];
          _controllers[index + i].selection = TextSelection.fromPosition(
            TextPosition(offset: digits[i].length),
          );
        }
      }
      int nextIndex = index + digits.length;
      if (nextIndex >= widget.length) nextIndex = widget.length - 1;
      _focusNodes[nextIndex].requestFocus();
    } else if (value.isNotEmpty && index < widget.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    widget.onChanged?.call(_otp);

    if (_otp.length == widget.length) {
      widget.onCompleted(_otp);
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: 48,
          height: 56,
          child: KeyboardListener(
            focusNode: FocusNode(),
            onKeyEvent: (event) => _onKeyEvent(index, event),
            child: TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: AppTypography.headingMedium(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: isDark ? DarkThemeColors.inputBackground : LightThemeColors.inputBackground,
                border: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusMd,
                  borderSide: BorderSide(
                    color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusMd,
                  borderSide: BorderSide(
                    color: isDark ? DarkThemeColors.border : LightThemeColors.border,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: AppSpacing.borderRadiusMd,
                  borderSide: const BorderSide(
                    color: AppColors.primary500,
                    width: 2,
                  ),
                ),
              ),
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              onChanged: (value) => _onChanged(index, value),
            ),
          ),
        );
      }),
    );
  }
}

