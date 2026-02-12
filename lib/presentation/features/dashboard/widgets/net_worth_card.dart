import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/money_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../accounts/accounts_providers.dart';

class NetWorthCard extends ConsumerWidget {
  const NetWorthCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final finance = theme.finance;
    final netWorthAsync = ref.watch(netWorthProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Net Worth',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            netWorthAsync.when(
              data: (nw) => Text(
                nw.toCurrency(),
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: nw >= 0 ? finance.netWorthPositive : theme.colorScheme.error,
                ),
              ),
              loading: () => Text(
                '...',
                style: theme.textTheme.headlineMedium,
              ),
              error: (_, _) => Text(
                '--',
                style: theme.textTheme.headlineMedium,
              ),
            ),
            const SizedBox(height: 4),
            accountsAsync.when(
              data: (accounts) {
                if (accounts.isEmpty) {
                  return Row(
                    children: [
                      Icon(Icons.info_outline, size: 16, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        'Add accounts to track your net worth',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                }
                return Text(
                  '${accounts.length} account${accounts.length == 1 ? '' : 's'}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}
