import 'package:flutter/material.dart';

import '../../../../core/constants/account_types.dart';
import '../../../../core/extensions/money_extensions.dart';
import '../../../../data/local/database/app_database.dart';
import '../../../../data/remote/simplefin/simplefin_models.dart';

enum LinkAction { createNew, linkExisting, skip }

class AccountLinkChoice {
  final LinkAction action;
  final String? existingAccountId;
  const AccountLinkChoice(this.action, [this.existingAccountId]);
}

/// Card widget for linking a SimpleFIN account to a local account.
class AccountLinkCard extends StatelessWidget {
  const AccountLinkCard({
    super.key,
    required this.sfAccount,
    required this.choice,
    required this.existingAccounts,
    required this.selectedAccountType,
    required this.onChoiceChanged,
    required this.onAccountTypeChanged,
  });

  final SimplefinAccount sfAccount;
  final AccountLinkChoice choice;
  final List<Account> existingAccounts;
  final String selectedAccountType;
  final ValueChanged<AccountLinkChoice> onChoiceChanged;
  final ValueChanged<String> onAccountTypeChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final institution = sfAccount.orgName ?? sfAccount.orgDomain ?? '';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sfAccount.name, style: theme.textTheme.titleMedium),
            if (institution.isNotEmpty)
              Text(institution, style: theme.textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              sfAccount.balanceCents.toCurrency(),
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _choiceToValue(choice),
              decoration: const InputDecoration(
                labelText: 'Action',
                isDense: true,
              ),
              items: [
                const DropdownMenuItem(
                  value: 'create_new',
                  child: Text('Create New Account'),
                ),
                ...existingAccounts.map((a) => DropdownMenuItem(
                      value: 'link_${a.id}',
                      child: Text('Link to: ${a.name}'),
                    )),
                const DropdownMenuItem(
                  value: 'skip',
                  child: Text('Skip'),
                ),
              ],
              onChanged: (value) {
                if (value == null) return;
                if (value == 'create_new') {
                  onChoiceChanged(const AccountLinkChoice(LinkAction.createNew));
                } else if (value == 'skip') {
                  onChoiceChanged(const AccountLinkChoice(LinkAction.skip));
                } else if (value.startsWith('link_')) {
                  final accountId = value.substring(5);
                  onChoiceChanged(
                      AccountLinkChoice(LinkAction.linkExisting, accountId));
                }
              },
            ),
            if (choice.action == LinkAction.createNew) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedAccountType,
                decoration: const InputDecoration(
                  labelText: 'Account Type',
                  isDense: true,
                ),
                items: accountTypes
                    .where((t) => sfAccount.balanceCents < 0
                        ? !t.isAsset
                        : t.isAsset)
                    .map((t) => DropdownMenuItem(
                          value: t.key,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) onAccountTypeChanged(value);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _choiceToValue(AccountLinkChoice c) {
    switch (c.action) {
      case LinkAction.createNew:
        return 'create_new';
      case LinkAction.skip:
        return 'skip';
      case LinkAction.linkExisting:
        return 'link_${c.existingAccountId}';
    }
  }
}
