import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../shared/empty_states/empty_state_widget.dart';
import 'import_providers.dart';

/// Screen showing past import records.
class ImportHistoryScreen extends ConsumerWidget {
  const ImportHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(importHistoryProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Import History')),
      body: historyAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (records) {
          if (records.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.file_upload_outlined,
              title: 'No Imports Yet',
              description: 'Import history will appear here after you import '
                  'transactions from a CSV file.',
            );
          }

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final date = record.createdAt.toDateTime();

              final statusColor = switch (record.status) {
                'completed' => theme.finance.income,
                'failed' => colorScheme.error,
                'partial' => theme.finance.budgetWarning,
                _ => colorScheme.onSurfaceVariant,
              };

              final statusLabel = switch (record.status) {
                'completed' => 'Completed',
                'failed' => 'Failed',
                'partial' => 'Partial',
                _ => record.status,
              };

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: statusColor.withValues(alpha: 0.15),
                  child: Icon(
                    record.status == 'failed'
                        ? Icons.error_outline
                        : Icons.file_upload,
                    color: statusColor,
                    size: 20,
                  ),
                ),
                title: Text(record.fileName),
                subtitle: Text(
                  '${record.importedCount}/${record.rowCount} imported'
                  ' \u00B7 ${date.toMediumDate()}',
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: statusColor,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
