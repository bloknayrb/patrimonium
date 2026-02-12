import 'package:flutter/material.dart';

import '../add_edit_goal_screen.dart';
import '../goals_screen.dart';

/// Icon and color picker section for goal forms.
class GoalAppearanceSection extends StatelessWidget {
  const GoalAppearanceSection({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.enabled,
    required this.onIconChanged,
    required this.onColorChanged,
  });

  final String selectedIcon;
  final Color selectedColor;
  final bool enabled;
  final ValueChanged<String> onIconChanged;
  final ValueChanged<Color> onColorChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Icon picker
        Text('Icon', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: goalIconOptions.map((option) {
            final isSelected = option.$1 == selectedIcon;
            return InkWell(
              onTap: enabled ? () => onIconChanged(option.$1) : null,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest
                          .withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: colorScheme.primary, width: 2)
                      : null,
                ),
                child: Icon(
                  option.$2,
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),

        // Color picker
        Text('Color', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: goalColorOptions.map((color) {
            final isSelected = color.toARGB32() == selectedColor.toARGB32();
            return InkWell(
              onTap: enabled ? () => onColorChanged(color) : null,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: colorScheme.onSurface, width: 3)
                      : null,
                ),
                child: isSelected
                    ? Icon(Icons.check,
                        color: ThemeData.estimateBrightnessForColor(color) ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                        size: 20)
                    : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
