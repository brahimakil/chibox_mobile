import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import '../../../core/services/security_service.dart';
import '../../../core/theme/theme.dart';
import 'pin_screen.dart';

class SecuritySettingsScreen extends StatelessWidget {
  const SecuritySettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final securityService = context.watch<SecurityService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Access Security',
              style: AppTypography.headingSmall(
                color: isDark ? DarkThemeColors.text : LightThemeColors.text,
              ),
            ),
            AppSpacing.verticalLg,

            // PIN Settings
            _SecurityOption(
              title: 'PIN Code',
              subtitle: securityService.hasPin ? 'Change or remove your PIN' : 'Set a PIN to secure your account',
              icon: Iconsax.lock,
              onTap: () {
                if (securityService.hasPin) {
                  _showPinOptions(context, securityService);
                } else {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PinScreen(
                        mode: PinMode.create,
                        onSuccess: () {
                          Navigator.pop(context); // Close PinScreen
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN set successfully')),
                          );
                        },
                      ),
                    ),
                  );
                }
              },
            ),
            AppSpacing.verticalBase,

            // Biometrics
            if (securityService.canCheckBiometrics) ...[
              _SecuritySwitch(
                title: 'Biometrics',
                subtitle: 'Use fingerprint or face ID to login',
                icon: Iconsax.finger_scan,
                value: securityService.isBiometricsEnabled,
                enabled: securityService.hasPin,
                onChanged: (value) async {
                  if (!securityService.hasPin) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Please set a PIN first')),
                    );
                    return;
                  }

                  final success = await securityService.setBiometricsEnabled(value);
                  if (!success && value) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Failed to enable biometrics')),
                      );
                    }
                  }
                },
              ),
              AppSpacing.verticalBase,
            ],

            // Auto-Lock Timeout
            if (securityService.hasPin)
              _SecurityOption(
                title: 'Auto-Lock',
                subtitle: _getTimeoutLabel(securityService.lockTimeout),
                icon: Iconsax.timer,
                onTap: () => _showTimeoutOptions(context, securityService),
              ),
          ],
        ),
      ),
    );
  }

  String _getTimeoutLabel(int seconds) {
    if (seconds == 0) return 'Immediately';
    if (seconds == -1) return 'Turn Off';
    if (seconds == 60) return 'After 1 minute';
    if (seconds == 300) return 'After 5 minutes';
    if (seconds == 600) return 'After 10 minutes';
    return 'After ${seconds ~/ 60} minutes';
  }

  void _showTimeoutOptions(BuildContext context, SecurityService securityService) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTimeoutOption(context, securityService, 0, 'Immediately'),
            _buildTimeoutOption(context, securityService, 60, '1 minute'),
            _buildTimeoutOption(context, securityService, 300, '5 minutes'),
            _buildTimeoutOption(context, securityService, 600, '10 minutes'),
            _buildTimeoutOption(context, securityService, -1, 'Turn Off'),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeoutOption(
    BuildContext context,
    SecurityService service,
    int value,
    String label,
  ) {
    final isSelected = service.lockTimeout == value;
    return ListTile(
      title: Text(label),
      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary500) : null,
      onTap: () {
        service.setLockTimeout(value);
        Navigator.pop(context);
      },
    );
  }

  void _showPinOptions(BuildContext context, SecurityService securityService) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Iconsax.edit),
              title: const Text('Change PIN'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PinScreen(
                      mode: PinMode.verify,
                      title: 'Enter Current PIN',
                      onSuccess: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PinScreen(
                              mode: PinMode.create,
                              title: 'Set New PIN',
                              onSuccess: () {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('PIN changed successfully')),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.trash, color: AppColors.error),
              title: const Text('Remove PIN', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove PIN'),
                    content: const Text('Are you sure? This will also disable biometrics.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Remove', style: TextStyle(color: AppColors.error)),
                      ),
                    ],
                  ),
                );

                if (confirmed == true) {
                  await securityService.removePin();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SecurityOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SecurityOption({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
          borderRadius: AppSpacing.borderRadiusBase,
          border: Border.all(
            color: isDark ? DarkThemeColors.border : LightThemeColors.border,
          ),
        ),
        child: Icon(
          icon,
          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
        ),
      ),
      title: Text(
        title,
        style: AppTypography.bodyLarge(
          color: isDark ? DarkThemeColors.text : LightThemeColors.text,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall(
          color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: isDark ? AppColors.neutral600 : AppColors.neutral400,
      ),
      onTap: onTap,
    );
  }
}

class _SecuritySwitch extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _SecuritySwitch({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? DarkThemeColors.surface : LightThemeColors.surface,
            borderRadius: AppSpacing.borderRadiusBase,
            border: Border.all(
              color: isDark ? DarkThemeColors.border : LightThemeColors.border,
            ),
          ),
          child: Icon(
            icon,
            color: isDark ? DarkThemeColors.text : LightThemeColors.text,
          ),
        ),
        title: Text(
          title,
          style: AppTypography.bodyLarge(
            color: isDark ? DarkThemeColors.text : LightThemeColors.text,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AppTypography.bodySmall(
            color: isDark ? DarkThemeColors.textSecondary : LightThemeColors.textSecondary,
          ),
        ),
        trailing: Switch.adaptive(
          value: value,
          onChanged: enabled ? onChanged : null,
          activeColor: AppColors.primary500,
        ),
      ),
    );
  }
}
