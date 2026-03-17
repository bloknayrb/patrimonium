import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../dashboard_card_registry.dart';
import '../dashboard_providers.dart';

/// Draft layout state for edit mode — discardable on cancel.
final _draftLayoutProvider =
    StateProvider.autoDispose<List<DashboardCardConfig>?>((ref) => null);

/// Edit mode UI with reorderable card list and visibility toggles.
class DashboardEditMode extends ConsumerStatefulWidget {
  const DashboardEditMode({super.key});

  @override
  ConsumerState<DashboardEditMode> createState() => _DashboardEditModeState();
}

class _DashboardEditModeState extends ConsumerState<DashboardEditMode> {
  @override
  void initState() {
    super.initState();
    // Initialize draft from current layout on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final layout = ref.read(dashboardLayoutProvider).valueOrNull;
      if (layout != null) {
        ref.read(_draftLayoutProvider.notifier).state = List.of(layout);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final draft = ref.watch(_draftLayoutProvider);
    final layoutAsync = ref.watch(dashboardLayoutProvider);

    // Use draft if available, otherwise fall back to current layout
    final layout = draft ?? layoutAsync.valueOrNull ?? defaultDashboardLayout;

    // Split into visible and hidden, filtering out cards removed from registry
    // and cards hidden by condition (no data)
    final visible = <DashboardCardConfig>[];
    final hidden = <DashboardCardConfig>[];

    for (final config in layout) {
      final def = dashboardCardDefinitionsMap[config.id];
      if (def == null) continue;

      // Skip cards that are hidden by condition (no data) — don't show in edit mode
      if (def.condition != null && !ref.watch(def.condition!)) continue;

      if (config.visible) {
        visible.add(config);
      } else {
        hidden.add(config);
      }
    }

    return Column(
      children: [
        // Action bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Text(
                'Drag to reorder • Tap eye to hide',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _save(ref, layout),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('Save'),
              ),
              TextButton(
                onPressed: () => _resetToDefault(ref),
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
        // Reorderable visible cards
        Expanded(
          child: ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            buildDefaultDragHandles: false,
            itemCount: visible.length + (hidden.isNotEmpty ? 1 + hidden.length : 0),
            onReorder: (oldIndex, newIndex) {
              if (oldIndex >= visible.length || newIndex > visible.length) return;
              _reorder(ref, layout, visible, oldIndex, newIndex);
            },
            itemBuilder: (context, index) {
              if (index < visible.length) {
                final config = visible[index];
                final def = dashboardCardDefinitionsMap[config.id]!;
                return _EditCardTile(
                  key: ValueKey(config.id),
                  config: config,
                  def: def,
                  index: index,
                  onToggleVisibility: () =>
                      _toggleVisibility(ref, layout, config.id),
                  onToggleSize: def.supportedSizes.length > 1
                      ? () => _toggleSize(ref, layout, config.id, def)
                      : null,
                );
              }

              // Hidden section header
              if (index == visible.length) {
                return Padding(
                  key: const ValueKey('_hidden_header'),
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    'Hidden',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                );
              }

              // Hidden cards
              final hiddenIndex = index - visible.length - 1;
              final config = hidden[hiddenIndex];
              final def = dashboardCardDefinitionsMap[config.id]!;
              return _EditCardTile(
                key: ValueKey(config.id),
                config: config,
                def: def,
                index: -1, // No drag handle for hidden cards
                onToggleVisibility: () =>
                    _toggleVisibility(ref, layout, config.id),
              );
            },
          ),
        ),
      ],
    );
  }

  void _reorder(
    WidgetRef ref,
    List<DashboardCardConfig> layout,
    List<DashboardCardConfig> visible,
    int oldIndex,
    int newIndex,
  ) {
    if (newIndex > oldIndex) newIndex--;
    final movedId = visible[oldIndex].id;

    // Rebuild the full layout with the moved card in its new position
    final updated = List.of(layout);
    final movedConfig = updated.firstWhere((c) => c.id == movedId);
    updated.remove(movedConfig);

    // Find the target position in the full layout
    if (newIndex >= visible.length - 1) {
      // Moving to end of visible list — find last visible card in full layout
      final lastVisibleId = visible.last.id;
      final lastVisibleIndex = updated.indexWhere((c) => c.id == lastVisibleId);
      updated.insert(lastVisibleIndex + 1, movedConfig);
    } else {
      // Moving before a specific visible card
      final targetId = visible[newIndex >= oldIndex ? newIndex + 1 : newIndex].id;
      final targetIndex = updated.indexWhere((c) => c.id == targetId);
      updated.insert(targetIndex, movedConfig);
    }

    ref.read(_draftLayoutProvider.notifier).state = updated;
  }

  void _toggleVisibility(
    WidgetRef ref,
    List<DashboardCardConfig> layout,
    String cardId,
  ) {
    final updated = layout.map((c) {
      if (c.id == cardId) return c.copyWith(visible: !c.visible);
      return c;
    }).toList();
    ref.read(_draftLayoutProvider.notifier).state = updated;
  }

  void _toggleSize(
    WidgetRef ref,
    List<DashboardCardConfig> layout,
    String cardId,
    DashboardCardDefinition def,
  ) {
    final updated = layout.map((c) {
      if (c.id == cardId) {
        final newSize = c.size == DashboardCardSize.full
            ? DashboardCardSize.half
            : DashboardCardSize.full;
        return c.copyWith(size: newSize);
      }
      return c;
    }).toList();
    ref.read(_draftLayoutProvider.notifier).state = updated;
  }

  Future<void> _save(WidgetRef ref, List<DashboardCardConfig> layout) async {
    final repo = ref.read(dashboardLayoutRepositoryProvider);
    await repo.saveLayout(layout);
    ref.invalidate(dashboardLayoutProvider);
    if (mounted) {
      ref.read(dashboardEditModeProvider.notifier).state = false;
    }
  }

  void _resetToDefault(WidgetRef ref) {
    ref.read(_draftLayoutProvider.notifier).state = defaultDashboardLayout;
  }
}

class _EditCardTile extends StatelessWidget {
  final DashboardCardConfig config;
  final DashboardCardDefinition def;
  final int index;
  final VoidCallback onToggleVisibility;
  final VoidCallback? onToggleSize;

  const _EditCardTile({
    super.key,
    required this.config,
    required this.def,
    required this.index,
    required this.onToggleVisibility,
    this.onToggleSize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVisible = config.visible;

    return Card(
      color: isVisible ? null : theme.colorScheme.surfaceContainerLow,
      child: ListTile(
        leading: index >= 0
            ? ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.drag_handle),
              )
            : Icon(def.icon, color: theme.colorScheme.onSurfaceVariant),
        title: Text(
          def.title,
          style: TextStyle(
            color: isVisible ? null : theme.colorScheme.onSurfaceVariant,
          ),
        ),
        subtitle: onToggleSize != null && isVisible
            ? GestureDetector(
                onTap: onToggleSize,
                child: Text(
                  config.size == DashboardCardSize.full
                      ? 'Full width'
                      : 'Half width',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.primary,
                    decoration: TextDecoration.underline,
                  ),
                ),
              )
            : null,
        trailing: IconButton(
          icon: Icon(
            isVisible ? Icons.visibility : Icons.visibility_off,
            color: isVisible
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurfaceVariant,
          ),
          onPressed: onToggleVisibility,
        ),
      ),
    );
  }
}
