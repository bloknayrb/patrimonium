import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../shared/widgets/pin_number_pad.dart';

/// Lock screen with PIN entry and optional biometric authentication.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _isError = false;
  bool _isVerifying = false;
  int _failedAttempts = 0;
  bool _isLockedOut = false;

  static const int pinLength = 6;

  @override
  void initState() {
    super.initState();
    // Try biometric auth on screen load after a short delay
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryBiometricAuth();
    });
  }

  void _addDigit(String digit) {
    if (_pin.length >= pinLength || _isVerifying || _isLockedOut) return;

    setState(() {
      _pin += digit;
      _isError = false;
    });

    if (_pin.length == pinLength) {
      _verifyPin();
    }
  }

  void _removeDigit() {
    if (_pin.isEmpty || _isVerifying) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _isError = false;
    });
  }

  Future<void> _verifyPin() async {
    setState(() => _isVerifying = true);

    final pinService = ref.read(pinServiceProvider);
    final isValid = await pinService.verifyPin(_pin);

    if (!mounted) return;

    if (isValid) {
      // Mark as unlocked and navigate to dashboard
      ref.read(isUnlockedProvider.notifier).state = true;
      context.go(AppRoutes.dashboard);
    } else {
      setState(() {
        _isError = true;
        _pin = '';
        _failedAttempts++;
        _isVerifying = false;
      });

      HapticFeedback.mediumImpact();

      // Lockout after max attempts
      if (_failedAttempts >= AppConstants.maxPinAttempts) {
        _startLockout();
      }
    }
  }

  void _startLockout() {
    final lockoutSeconds = _failedAttempts >= 10
        ? AppConstants.longLockoutSeconds
        : AppConstants.shortLockoutSeconds;

    setState(() => _isLockedOut = true);

    Future.delayed(Duration(seconds: lockoutSeconds), () {
      if (mounted) {
        setState(() {
          _isLockedOut = false;
          _failedAttempts = 0;
        });
      }
    });
  }

  Future<void> _tryBiometricAuth() async {
    final biometricService = ref.read(biometricServiceProvider);
    final success = await biometricService.authenticate();

    if (!mounted) return;

    if (success) {
      ref.read(isUnlockedProvider.notifier).state = true;
      context.go(AppRoutes.dashboard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final biometricAvailable = ref.watch(biometricAvailableProvider);
    final biometricEnabled = ref.watch(biometricEnabledProvider);
    final showBiometric = biometricAvailable.valueOrNull == true &&
        biometricEnabled.valueOrNull == true;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            children: [
              const Spacer(flex: 2),

              // App icon / logo
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance,
                  size: 40,
                  color: colorScheme.primary,
                ),
              ),
              const SizedBox(height: 16),

              // App name
              Text(
                AppConstants.appName,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),

              // Instruction
              Text(
                _isLockedOut
                    ? 'Too many attempts. Please wait.'
                    : _isError
                        ? 'Incorrect PIN. Try again.'
                        : 'Enter your PIN',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: _isError || _isLockedOut
                      ? colorScheme.error
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 32),

              // PIN dots
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(pinLength, (index) {
                  final isFilled = index < _pin.length;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isError
                            ? colorScheme.error
                            : isFilled
                                ? colorScheme.primary
                                : Colors.transparent,
                        border: Border.all(
                          color: _isError
                              ? colorScheme.error
                              : colorScheme.outline,
                          width: 2,
                        ),
                      ),
                    ),
                  );
                }),
              ),

              if (_isVerifying) ...[
                const SizedBox(height: 16),
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],

              const Spacer(),

              // Number pad
              PinNumberPad(
                onDigit: _addDigit,
                onDelete: _removeDigit,
                onBiometric: showBiometric ? _tryBiometricAuth : null,
                isDisabled: _isLockedOut || _isVerifying,
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

