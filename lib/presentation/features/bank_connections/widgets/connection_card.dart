import 'package:flutter/material.dart';

import '../../../../core/extensions/money_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../data/local/database/app_database.dart';
import '../../../../domain/usecases/sync/simplefin_sync_service.dart';

/// Card widget displaying a single bank connection's status.
class ConnectionCard extends StatelessWidget {
  const ConnectionCard({
    super.key,
    required this.connection,
    required this.linkedAccountCount,
    required this.canSync,
    required this.onSync,
    required this.onTap,
  });

  final BankConnection connection;
  final int linkedAccountCount;
  final bool canSync;
  final VoidCallback onSync;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      connection.institutionName,
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  _StatusChip(status: connection.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.account_balance, size: 16,
                      color: theme.colorScheme.outline),
                  const SizedBox(width: 4),
                  Text(
                    '$linkedAccountCount linked account${linkedAccountCount == 1 ? '' : 's'}',
                    style: theme.textTheme.bodySmall,
                  ),
                  const Spacer(),
                  if (connection.lastSyncedAt != null)
                    Text(
                      'Synced ${connection.lastSyncedAt!.toDateTime().toRelative()}',
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
              if (connection.errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  connection.errorMessage!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: canSync ? onSync : null,
                  icon: const Icon(Icons.sync, size: 18),
                  label: const Text('Sync Now'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final finance = theme.finance;

    final (Color color, String label) = switch (status) {
      ConnectionStatus.connected => (finance.income, 'Connected'),
      ConnectionStatus.syncing => (theme.colorScheme.primary, 'Syncing'),
      ConnectionStatus.error => (finance.expense, 'Error'),
      ConnectionStatus.rateLimited => (finance.budgetWarning, 'Rate Limited'),
      ConnectionStatus.disconnected => (theme.colorScheme.outline, 'Disconnected'),
      _ => (theme.colorScheme.outline, status),
    };

    return Chip(
      label: Text(label),
      labelStyle: TextStyle(color: color, fontSize: 12),
      side: BorderSide(color: color),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
