import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../dashboard_card_registry.dart';
import '../dashboard_providers.dart';

/// Edit mode UI — placeholder for Step 3 implementation.
class DashboardEditMode extends ConsumerWidget {
  const DashboardEditMode({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layoutAsync = ref.watch(dashboardLayoutProvider);

    return layoutAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => const Center(child: Text('Error loading layout')),
      data: (layout) => _buildEditList(context, ref, layout),
    );
  }

  Widget _buildEditList(
    BuildContext context,
    WidgetRef ref,
    List<DashboardCardConfig> layout,
  ) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Drag to reorder, toggle visibility',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        for (final config in layout)
          if (dashboardCardDefinitionsMap.containsKey(config.id))
            _EditCardTile(config: config),
      ],
    );
  }
}

class _EditCardTile extends StatelessWidget {
  final DashboardCardConfig config;

  const _EditCardTile({required this.config});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final def = dashboardCardDefinitionsMap[config.id]!;

    return Card(
      child: ListTile(
        leading: Icon(def.icon),
        title: Text(def.title),
        trailing: Icon(
          config.visible ? Icons.visibility : Icons.visibility_off,
          color: config.visible
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
