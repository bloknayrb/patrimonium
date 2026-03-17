import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/extensions/money_extensions.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../recurring/recurring_providers.dart';

/// Shows detected subscriptions with monthly total.
class SubscriptionTrackerCard extends ConsumerWidget {
  const SubscriptionTrackerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final finance = theme.finance;
    final recurringAsync = ref.watch(recurringTransactionsProvider);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.recurring),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Subscriptions',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              recurringAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, _) => const Text('Unable to load subscriptions'),
                data: (recurring) {
                  final subs =
                      recurring.where((r) => r.isSubscription).toList()
                        ..sort((a, b) =>
                            b.amountCents.abs().compareTo(a.amountCents.abs()));

                  if (subs.isEmpty) {
                    return Text(
                      'No subscriptions detected',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    );
                  }

                  // Calculate monthly total (normalize non-monthly frequencies)
                  var monthlyTotalCents = 0;
                  for (final sub in subs) {
                    monthlyTotalCents += _toMonthlyCents(
                      sub.amountCents.abs(),
                      sub.frequency,
                    );
                  }

                  return Column(
                    children: [
                      // Monthly total header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Monthly total',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            monthlyTotalCents.toCurrency(),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: finance.expense,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Divider(height: 1),
                      const SizedBox(height: 8),
                      // Subscription list
                      for (final sub in subs.take(5))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  sub.payee,
                                  style: theme.textTheme.bodyMedium,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _frequencyLabel(sub.frequency),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                sub.amountCents.abs().toCurrency(),
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (subs.length > 5)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '+${subs.length - 5} more',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Normalize amount to monthly equivalent.
  static int _toMonthlyCents(int amountCents, String frequency) {
    switch (frequency) {
      case 'weekly':
        return (amountCents * 52 / 12).round();
      case 'biweekly':
        return (amountCents * 26 / 12).round();
      case 'monthly':
        return amountCents;
      case 'quarterly':
        return (amountCents / 3).round();
      case 'annual':
        return (amountCents / 12).round();
      default:
        return amountCents;
    }
  }

  static String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'weekly':
        return '/wk';
      case 'biweekly':
        return '/2wk';
      case 'monthly':
        return '/mo';
      case 'quarterly':
        return '/qtr';
      case 'annual':
        return '/yr';
      default:
        return '';
    }
  }
}
