import 'package:flutter/material.dart';

import '../../../../data/local/database/app_database.dart';

/// Account dropdown and category picker for recurring transaction forms.
class RecurringAccountCategorySection extends StatelessWidget {
  const RecurringAccountCategorySection({
    super.key,
    required this.accounts,
    required this.selectedAccountId,
    required this.selectedCategoryName,
    required this.selectedCategoryId,
    required this.enabled,
    required this.onAccountChanged,
    required this.onCategoryTap,
  });

  final List<Account> accounts;
  final String? selectedAccountId;
  final String? selectedCategoryName;
  final String? selectedCategoryId;
  final bool enabled;
  final ValueChanged<String?> onAccountChanged;
  final VoidCallback onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        // Account dropdown
        if (accounts.isEmpty)
          ListTile(
            leading: const Icon(Icons.warning),
            title: const Text('No accounts'),
            subtitle: const Text('Create an account first'),
            tileColor: colorScheme.errorContainer.withValues(alpha: 0.3),
          )
        else
          DropdownButtonFormField<String>(
            initialValue: selectedAccountId ?? accounts.first.id,
            decoration: const InputDecoration(
              labelText: 'Account *',
              filled: true,
            ),
            items: accounts.map((a) {
              return DropdownMenuItem(
                value: a.id,
                child: Text(a.name),
              );
            }).toList(),
            onChanged: enabled ? onAccountChanged : null,
            validator: (v) => v == null ? 'Select an account' : null,
          ),
        const SizedBox(height: 16),

        // Category picker
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.category),
          title: const Text('Category'),
          subtitle: Text(
            selectedCategoryName ?? 'Uncategorized',
            style: selectedCategoryId == null
                ? TextStyle(color: colorScheme.onSurfaceVariant)
                : null,
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: enabled ? onCategoryTap : null,
        ),
      ],
    );
  }
}
