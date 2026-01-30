import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/theme/theme.dart';

/// A dialog that allows users to type a specific quantity
/// instead of using +/- buttons repeatedly.
/// 
/// Returns the new quantity if confirmed, or null if cancelled.
class QuantityInputDialog extends StatefulWidget {
  final int currentQuantity;
  final int minQuantity;
  final int maxQuantity;
  final String? productName;

  const QuantityInputDialog({
    super.key,
    required this.currentQuantity,
    this.minQuantity = 1,
    this.maxQuantity = 100,
    this.productName,
  });

  /// Shows the quantity input dialog and returns the selected quantity
  /// Returns null if cancelled, or the new quantity if confirmed
  static Future<int?> show(
    BuildContext context, {
    required int currentQuantity,
    int minQuantity = 1,
    int maxQuantity = 100,
    String? productName,
  }) {
    return showDialog<int>(
      context: context,
      builder: (context) => QuantityInputDialog(
        currentQuantity: currentQuantity,
        minQuantity: minQuantity,
        maxQuantity: maxQuantity,
        productName: productName,
      ),
    );
  }

  @override
  State<QuantityInputDialog> createState() => _QuantityInputDialogState();
}

class _QuantityInputDialogState extends State<QuantityInputDialog> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentQuantity.toString());
    _focusNode = FocusNode();
    
    // Select all text when dialog opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _validateAndSubmit() {
    final text = _controller.text.trim();
    
    if (text.isEmpty) {
      setState(() => _errorMessage = 'Please enter a quantity');
      return;
    }

    final quantity = int.tryParse(text);
    
    if (quantity == null) {
      setState(() => _errorMessage = 'Please enter a valid number');
      return;
    }

    if (quantity < widget.minQuantity) {
      setState(() => _errorMessage = 'Minimum quantity is ${widget.minQuantity}');
      return;
    }

    if (quantity > widget.maxQuantity) {
      setState(() => _errorMessage = 'Maximum quantity is ${widget.maxQuantity}');
      return;
    }

    Navigator.of(context).pop(quantity);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? DarkThemeColors.surface : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Enter Quantity',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          if (widget.productName != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.productName!,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: isDark ? Colors.white54 : Colors.black45,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Quantity input field
          TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(3), // Max 999
            ],
            decoration: InputDecoration(
              hintText: '1-${widget.maxQuantity}',
              hintStyle: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.white30 : Colors.black26,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? Colors.white24 : Colors.black12,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: AppColors.primary500,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Colors.red,
                ),
              ),
            ),
            onSubmitted: (_) => _validateAndSubmit(),
          ),
          
          // Error message
          if (_errorMessage != null) ...[
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.red,
              ),
            ),
          ],
          
          // Quick quantity buttons
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [1, 5, 10, 25, 50].where((q) => q <= widget.maxQuantity).map((qty) {
              return _QuickQuantityButton(
                quantity: qty,
                isSelected: _controller.text == qty.toString(),
                onTap: () {
                  setState(() {
                    _controller.text = qty.toString();
                    _errorMessage = null;
                  });
                },
                isDark: isDark,
              );
            }).toList(),
          ),
          
          // Hint text
          const SizedBox(height: 12),
          Text(
            'Min: ${widget.minQuantity} • Max: ${widget.maxQuantity}',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: _validateAndSubmit,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary500,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}

class _QuickQuantityButton extends StatelessWidget {
  final int quantity;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _QuickQuantityButton({
    required this.quantity,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary500.withOpacity(0.2)
              : (isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? AppColors.primary500
                : (isDark ? Colors.white24 : Colors.black12),
          ),
        ),
        child: Text(
          '$quantity',
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? AppColors.primary500
                : (isDark ? Colors.white70 : Colors.black54),
          ),
        ),
      ),
    );
  }
}
