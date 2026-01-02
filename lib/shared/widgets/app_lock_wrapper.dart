import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/security_service.dart';
import '../../features/profile/screens/pin_screen.dart';

class AppLockWrapper extends StatefulWidget {
  final Widget child;

  const AppLockWrapper({super.key, required this.child});

  @override
  State<AppLockWrapper> createState() => _AppLockWrapperState();
}

class _AppLockWrapperState extends State<AppLockWrapper> with WidgetsBindingObserver {
  bool _isLocked = false;
  bool _isAuthenticating = false;
  DateTime? _lastPausedTime;
  late SecurityService _securityService;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _securityService = context.read<SecurityService>();
    _checkSecurity(isColdStart: true);
    
    // Listen for security changes (e.g. PIN removal on logout)
    _securityService.addListener(_onSecurityChanged);
  }

  @override
  void dispose() {
    _securityService.removeListener(_onSecurityChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onSecurityChanged() {
    if (!_securityService.hasPin) {
      _securityService.setSessionActive(false); // Reset session active state
      if (_isLocked && mounted) {
        setState(() => _isLocked = false);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App went to background
      _lastPausedTime = DateTime.now();
      // Persist last active time for cold starts
      context.read<SecurityService>().setLastActiveTime();
    } else if (state == AppLifecycleState.resumed) {
      // App came to foreground
      _checkSecurity(isColdStart: false);
    }
  }

  Future<void> _checkSecurity({required bool isColdStart}) async {
    if (_isAuthenticating) return;

    final securityService = context.read<SecurityService>();
    
    // Wait for security service to initialize if it hasn't already
    // This ensures we have the correct timeout value
    if (isColdStart) {
      await securityService.init();
    }
    
    if (!securityService.hasPin) {
      setState(() => _isLocked = false);
      return;
    }

    final timeout = securityService.lockTimeout;

    // If timeout is -1 (Off), don't lock at all (even on cold start)
    if (timeout == -1) {
      setState(() => _isLocked = false);
      return;
    }

    // Check timeout logic
    if (!isColdStart) {
      // If we don't have a pause time (e.g. cleared after successful auth), don't lock
      if (_lastPausedTime == null) return;

      final difference = DateTime.now().difference(_lastPausedTime!).inSeconds;
      if (difference < timeout) {
        // Within timeout period, don't lock
        return;
      }
    } else {
      // If session is already active (e.g. widget rebuild), don't lock
      if (securityService.isSessionActive) {
        setState(() => _isLocked = false);
        return;
      }

      // Cold start logic - check persisted last active time
      final lastActive = await securityService.getLastActiveTime();
      if (lastActive != null) {
        final difference = DateTime.now().difference(lastActive).inSeconds;
        if (difference < timeout) {
          // Within timeout period from last session, don't lock
          setState(() => _isLocked = false);
          securityService.setSessionActive(true); // Mark session as active
          return;
        }
      }
    }

    setState(() => _isLocked = true);
    _authenticate();
  }

  Future<void> _authenticate() async {
    if (_isAuthenticating) return;
    _isAuthenticating = true;

    final securityService = context.read<SecurityService>();

    // Try biometrics first if enabled
    if (securityService.isBiometricsEnabled) {
      final authenticated = await securityService.authenticateWithBiometrics();
      if (authenticated) {
        if (mounted) {
          securityService.setSessionActive(true);
          setState(() {
            _isLocked = false;
            _isAuthenticating = false;
            _lastPausedTime = null; // Clear pause time to prevent re-locking on resume
          });
        }
        return;
      }
    }

    // Fallback to PIN screen
    if (mounted) {
      // We show the PIN screen as a full-screen dialog or overlay
      // Since we are in a wrapper, we can just render the PinScreen instead of child if locked
      // But PinScreen expects to be pushed.
      // Let's just render PinScreen conditionally.
      setState(() => _isAuthenticating = false); // Reset flag as we are showing UI
    }
  }

  @override
  Widget build(BuildContext context) {
    final securityService = context.watch<SecurityService>();

    // If PIN is removed (e.g. logout), unlock immediately
    if (!securityService.hasPin && _isLocked) {
      // We can't call setState during build, but we can just return the child
      // and schedule a state update for consistency if needed, 
      // or just rely on the fact that we are rendering the child.
      // Ideally we should update _isLocked to false, but we can't do it here.
      // However, since we return widget.child, the user sees the app.
      // The next time _checkSecurity runs, it will see !hasPin and set _isLocked = false.
      return widget.child;
    }

    if (_isLocked) {
      return PinScreen(
        mode: PinMode.verify,
        title: 'Unlock App',
        showBackButton: false,
        onSuccess: () {
          securityService.setSessionActive(true);
          setState(() => _isLocked = false);
        },
        onBiometricAuth: securityService.isBiometricsEnabled
            ? () async {
                final authenticated = await securityService.authenticateWithBiometrics();
                if (authenticated && mounted) {
                  securityService.setSessionActive(true);
                  setState(() {
                    _isLocked = false;
                    _isAuthenticating = false;
                    _lastPausedTime = null;
                  });
                }
              }
            : null,
      );
    }

    return widget.child;
  }
}
