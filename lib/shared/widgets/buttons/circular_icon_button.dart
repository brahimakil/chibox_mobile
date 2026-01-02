import 'package:flutter/material.dart';
import '../../../core/theme/theme.dart';

class CircularIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? iconColor;
  final Color? backgroundColor;
  final double size;
  final double iconSize;

  const CircularIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.iconColor,
    this.backgroundColor,
    this.size = 44,
    this.iconSize = 20,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Use primary color (Blue) for icon to ensure visibility and brand consistency
    // This prevents the "white on white" or "dark on dark" issues
    final effectiveIconColor = iconColor ?? AppColors.primary500;
    
    final effectiveBackgroundColor = backgroundColor ?? (isDark 
        ? const Color(0xFF1E1E1E).withOpacity(0.9) 
        : Colors.white.withOpacity(0.9));

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: effectiveBackgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: iconSize),
        color: effectiveIconColor,
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}
