import 'package:flutter/material.dart';

import '../../../../core/extensions/money_extensions.dart';
import '../../../../data/local/database/app_database.dart';

/// Widget displaying a single sync history entry.
class SyncHistoryCard extends StatelessWidget {
  const SyncHistoryCard({super.key, required this.record});

  final ImportHistoryData record;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final date = record.createdAt.toDateTime();

    return ListTile(
      dense: true,
      leading: Icon(
        record.status == 'completed' ? Icons.check_circle : Icons.error,
        color: record.status == 'completed'
            ? theme.colorScheme.primary
            : theme.colorScheme.error,
        size: 20,
      ),
      title: Text(
        '${record.importedCount} imported, ${record.skippedCount} skipped',
        style: theme.textTheme.bodyMedium,
      ),
      subtitle: Text(
        date.toRelative(),
        style: theme.textTheme.bodySmall,
      ),
      trailing: record.errorMessage != null
          ? Tooltip(
              message: record.errorMessage!,
              child: Icon(Icons.info_outline,
                  size: 18, color: theme.colorScheme.error),
            )
          : null,
    );
  }
}
