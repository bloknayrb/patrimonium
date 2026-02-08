import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared number pad widget for PIN entry screens.
///
/// Used by both LockScreen and PinSetupScreen.
class PinNumberPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final bool isDisabled;

  const PinNumberPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.onBiometric,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PadButton(digit: '1', onTap: () => onDigit('1'), isDisabled: isDisabled),
            _PadButton(digit: '2', onTap: () => onDigit('2'), isDisabled: isDisabled),
            _PadButton(digit: '3', onTap: () => onDigit('3'), isDisabled: isDisabled),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PadButton(digit: '4', onTap: () => onDigit('4'), isDisabled: isDisabled),
            _PadButton(digit: '5', onTap: () => onDigit('5'), isDisabled: isDisabled),
            _PadButton(digit: '6', onTap: () => onDigit('6'), isDisabled: isDisabled),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _PadButton(digit: '7', onTap: () => onDigit('7'), isDisabled: isDisabled),
            _PadButton(digit: '8', onTap: () => onDigit('8'), isDisabled: isDisabled),
            _PadButton(digit: '9', onTap: () => onDigit('9'), isDisabled: isDisabled),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            if (onBiometric != null)
              _PadButton(
                icon: Icons.fingerprint,
                onTap: onBiometric!,
                isDisabled: isDisabled,
              )
            else
              const SizedBox(width: 72, height: 72),
            _PadButton(digit: '0', onTap: () => onDigit('0'), isDisabled: isDisabled),
            _PadButton(
              icon: Icons.backspace_outlined,
              onTap: onDelete,
              isDisabled: isDisabled,
            ),
          ],
        ),
      ],
    );
  }
}

class _PadButton extends StatelessWidget {
  final String? digit;
  final IconData? icon;
  final VoidCallback onTap;
  final bool isDisabled;

  const _PadButton({
    this.digit,
    this.icon,
    required this.onTap,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      width: 72,
      height: 72,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDisabled
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
          child: Center(
            child: digit != null
                ? Text(
                    digit!,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDisabled
                          ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                          : null,
                    ),
                  )
                : Icon(
                    icon,
                    size: 28,
                    color: isDisabled
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
                        : null,
                  ),
          ),
        ),
      ),
    );
  }
}
