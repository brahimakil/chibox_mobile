import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';
import '../../../core/constants/country_codes.dart';

/// Dropdown Item Model
class DropdownItem<T> {
  final T value;
  final String label;
  final IconData? icon;
  final String? imageUrl;

  const DropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.imageUrl,
  });
}

/// Custom App Dropdown
class AppDropdown<T> extends StatefulWidget {
  final String? label;
  final String? hint;
  final T? value;
  final List<DropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final String? errorText;
  final bool enabled;

  const AppDropdown({
    super.key,
    this.label,
    this.hint,
    this.value,
    required this.items,
    this.onChanged,
    this.errorText,
    this.enabled = true,
  });

  @override
  State<AppDropdown<T>> createState() => _AppDropdownState<T>();
}

class _AppDropdownState<T> extends State<AppDropdown<T>> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedItem = widget.items.where((item) => item.value == widget.value).firstOrNull;

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
        GestureDetector(
          onTap: widget.enabled
              ? () {
                  setState(() => _isOpen = !_isOpen);
                  _showDropdown(context);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.base,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: isDark ? DarkThemeColors.inputBackground : LightThemeColors.inputBackground,
              borderRadius: AppSpacing.borderRadiusBase,
              border: Border.all(
                color: widget.errorText != null
                    ? AppColors.error
                    : (isDark ? DarkThemeColors.border : LightThemeColors.border),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    selectedItem?.label ?? widget.hint ?? 'Select an option',
                    style: AppTypography.bodyMedium(
                      color: selectedItem != null
                          ? (isDark ? DarkThemeColors.text : LightThemeColors.text)
                          : (isDark ? AppColors.neutral500 : AppColors.neutral400),
                    ),
                  ),
                ),
                AnimatedRotation(
                  turns: _isOpen ? 0.5 : 0,
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    Iconsax.arrow_down_1,
                    size: 20,
                    color: isDark ? AppColors.neutral500 : AppColors.neutral400,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (widget.errorText != null) ...[
          AppSpacing.verticalXs,
          Text(
            widget.errorText!,
            style: AppTypography.caption(color: AppColors.error),
          ),
        ],
      ],
    );
  }

  void _showDropdown(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.neutral700 : AppColors.neutral300,
                  borderRadius: AppSpacing.borderRadiusFull,
                ),
              ),
              AppSpacing.verticalMd,

              // Title
              if (widget.label != null)
                Padding(
                  padding: AppSpacing.paddingHorizontalBase,
                  child: Text(
                    widget.label!,
                    style: AppTypography.headingSmall(
                      color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                    ),
                  ),
                ),
              AppSpacing.verticalBase,

              // Items
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: widget.items.length,
                  itemBuilder: (context, index) {
                    final item = widget.items[index];
                    final isSelected = item.value == widget.value;

                    return ListTile(
                      leading: item.icon != null
                          ? Icon(
                              item.icon,
                              color: isSelected
                                  ? AppColors.primary500
                                  : (isDark ? DarkThemeColors.text : LightThemeColors.text),
                            )
                          : null,
                      title: Text(
                        item.label,
                        style: AppTypography.bodyMedium(
                          color: isSelected
                              ? AppColors.primary500
                              : (isDark ? DarkThemeColors.text : LightThemeColors.text),
                        ),
                      ),
                      trailing: isSelected
                          ? const Icon(Iconsax.tick_circle5, color: AppColors.primary500)
                          : null,
                      onTap: () {
                        widget.onChanged?.call(item.value);
                        Navigator.pop(context);
                        setState(() => _isOpen = false);
                      },
                    );
                  },
                ),
              ),
              AppSpacing.verticalBase,
            ],
          ),
        );
      },
    ).then((_) {
      setState(() => _isOpen = false);
    });
  }
}

/// Country Code Picker
class CountryCodePicker extends StatelessWidget {
  final String selectedCode;
  final ValueChanged<String>? onChanged;

  const CountryCodePicker({
    super.key,
    this.selectedCode = '+961',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selected = supportedCountryCodes.firstWhere(
      (c) => c['code'] == selectedCode,
      orElse: () => supportedCountryCodes.first,
    );

    return GestureDetector(
      onTap: () => _showPicker(context),
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
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              selected['flag']!,
              style: const TextStyle(fontSize: 18),
            ),
            AppSpacing.horizontalXs,
            Text(
              selected['code']!,
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
    );
  }

  void _showPicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.radiusXl)),
      ),
      builder: (context) {
        return _CountryPickerSheet(
          onSelect: (code) {
            onChanged?.call(code);
            Navigator.pop(context);
          },
        );
      },
    );
  }
}

class _CountryPickerSheet extends StatefulWidget {
  final ValueChanged<String> onSelect;

  const _CountryPickerSheet({required this.onSelect});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  String _searchQuery = '';
  late List<Map<String, String>> _filteredCodes;

  @override
  void initState() {
    super.initState();
    _filteredCodes = supportedCountryCodes;
  }

  void _filter(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredCodes = supportedCountryCodes;
      } else {
        _filteredCodes = supportedCountryCodes.where((country) {
          final name = country['name']!.toLowerCase();
          final code = country['code']!.toLowerCase();
          final q = query.toLowerCase();
          return name.contains(q) || code.contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Handle
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: AppSpacing.sm),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.neutral700 : AppColors.neutral300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: TextField(
                onChanged: _filter,
                decoration: InputDecoration(
                  hintText: 'Search country or code',
                  prefixIcon: const Icon(Iconsax.search_normal),
                  filled: true,
                  fillColor: isDark ? AppColors.neutral800 : AppColors.neutral100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                ),
              ),
            ),

            // List
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: _filteredCodes.length,
                itemBuilder: (context, index) {
                  final country = _filteredCodes[index];
                  return ListTile(
                    leading: Text(
                      country['flag']!,
                      style: const TextStyle(fontSize: 24),
                    ),
                    title: Text(
                      country['name']!,
                      style: AppTypography.bodyLarge(
                        color: isDark ? DarkThemeColors.text : LightThemeColors.text,
                      ),
                    ),
                    trailing: Text(
                      country['code']!,
                      style: AppTypography.bodyMedium(
                        color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
                      ),
                    ),
                    onTap: () => widget.onSelect(country['code']!),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

