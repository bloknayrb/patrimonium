import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../transactions/add_edit_transaction_screen.dart';
import 'widgets/net_worth_card.dart';
import 'widgets/cash_flow_card.dart';
import 'widgets/budget_health_card.dart';
import 'widgets/recent_transactions_card.dart';
import 'widgets/ai_insights_card.dart';

/// Dashboard home screen with financial overview cards.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Patrimonium'),
        actions: [
          IconButton(
            icon: const Icon(Icons.sync),
            tooltip: 'Sync accounts',
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text(
                    'No bank connections configured. Add one in Settings.',
                  ),
                  action: SnackBarAction(
                    label: 'Settings',
                    onPressed: () {
                      StatefulNavigationShell.of(context).goBranch(4);
                    },
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Insights',
            onPressed: () {
              StatefulNavigationShell.of(context).goBranch(3);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          NetWorthCard(),
          SizedBox(height: 16),
          CashFlowCard(),
          SizedBox(height: 16),
          BudgetHealthCard(),
          SizedBox(height: 16),
          RecentTransactionsCard(),
          SizedBox(height: 16),
          AiInsightsCard(),
          SizedBox(height: 80), // Space for FAB
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const AddEditTransactionScreen(),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Transaction'),
      ),
    );
  }
}
