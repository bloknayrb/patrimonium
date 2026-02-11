import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../data/local/database/app_database.dart';
import '../../../data/remote/simplefin/simplefin_models.dart';
import 'bank_connections_providers.dart';

const _uuid = Uuid();

enum _LinkAction { createNew, linkExisting, skip }

class _LinkChoice {
  final _LinkAction action;
  final String? existingAccountId;
  const _LinkChoice(this.action, [this.existingAccountId]);
}

/// Screen for linking discovered SimpleFIN accounts to local accounts.
class AccountLinkingScreen extends ConsumerStatefulWidget {
  const AccountLinkingScreen({super.key, required this.connectionId});

  final String connectionId;

  @override
  ConsumerState<AccountLinkingScreen> createState() =>
      _AccountLinkingScreenState();
}

class _AccountLinkingScreenState extends ConsumerState<AccountLinkingScreen> {
  List<SimplefinAccount>? _discoveredAccounts;
  bool _isLoading = true;
  bool _isSaving = false;
  String? _errorMessage;
  final Map<String, _LinkChoice> _choices = {};

  @override
  void initState() {
    super.initState();
    _fetchAccounts();
  }

  Future<void> _fetchAccounts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final secureStorage = ref.read(secureStorageProvider);
      final tokenString = await secureStorage.getSimplefinToken();
      if (tokenString == null) {
        setState(() {
          _errorMessage = 'No SimpleFIN credentials found.';
          _isLoading = false;
        });
        return;
      }

      final accessUrl = SimplefinAccessUrl.parse(tokenString);
      final client = ref.read(simplefinClientProvider);
      final response =
          await client.getAccounts(accessUrl, balancesOnly: true);

      setState(() {
        _discoveredAccounts = response.accounts;
        for (final account in response.accounts) {
          _choices[account.id] = const _LinkChoice(_LinkAction.createNew);
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to fetch accounts. Please try again.';
        _isLoading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_discoveredAccounts == null) return;

    setState(() => _isSaving = true);

    try {
      final accountRepo = ref.read(accountRepositoryProvider);
      final existingCount = await accountRepo.getAccountCount();
      var displayOrder = existingCount;
      var linkedCount = 0;

      for (final sfAccount in _discoveredAccounts!) {
        final choice = _choices[sfAccount.id];
        if (choice == null || choice.action == _LinkAction.skip) continue;

        if (choice.action == _LinkAction.createNew) {
          final newId = _uuid.v4();
          final now = DateTime.now().millisecondsSinceEpoch;

          await accountRepo.insertAccount(AccountsCompanion.insert(
            id: newId,
            name: sfAccount.name,
            institutionName: Value(sfAccount.orgName ?? sfAccount.orgDomain),
            accountType: 'checking',
            balanceCents: sfAccount.balanceCents,
            isAsset: true,
            displayOrder: displayOrder++,
            bankConnectionId: Value(widget.connectionId),
            externalId: Value(sfAccount.id),
            createdAt: now,
            updatedAt: now,
          ));
          linkedCount++;
        } else if (choice.action == _LinkAction.linkExisting &&
            choice.existingAccountId != null) {
          await accountRepo.linkToBank(
            choice.existingAccountId!,
            widget.connectionId,
            sfAccount.id,
          );
          linkedCount++;
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$linkedCount account(s) linked.')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unlinkedAccounts = ref.watch(unlinkedAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Link Accounts')),
      body: _buildBody(unlinkedAccounts),
      bottomNavigationBar: _discoveredAccounts != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Save'),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildBody(AsyncValue<List<Account>> unlinkedAccounts) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_errorMessage!, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _fetchAccounts,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_discoveredAccounts == null || _discoveredAccounts!.isEmpty) {
      return const Center(child: Text('No accounts found.'));
    }

    final existingAccounts = unlinkedAccounts.valueOrNull ?? [];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _discoveredAccounts!.length,
      itemBuilder: (context, index) {
        final sfAccount = _discoveredAccounts![index];
        return _AccountLinkCard(
          sfAccount: sfAccount,
          choice: _choices[sfAccount.id] ??
              const _LinkChoice(_LinkAction.createNew),
          existingAccounts: existingAccounts,
          onChoiceChanged: (choice) {
            setState(() => _choices[sfAccount.id] = choice);
          },
        );
      },
    );
  }
}

class _AccountLinkCard extends StatelessWidget {
  const _AccountLinkCard({
    required this.sfAccount,
    required this.choice,
    required this.existingAccounts,
    required this.onChoiceChanged,
  });

  final SimplefinAccount sfAccount;
  final _LinkChoice choice;
  final List<Account> existingAccounts;
  final ValueChanged<_LinkChoice> onChoiceChanged;

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
                  onChoiceChanged(const _LinkChoice(_LinkAction.createNew));
                } else if (value == 'skip') {
                  onChoiceChanged(const _LinkChoice(_LinkAction.skip));
                } else if (value.startsWith('link_')) {
                  final accountId = value.substring(5);
                  onChoiceChanged(
                      _LinkChoice(_LinkAction.linkExisting, accountId));
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  String _choiceToValue(_LinkChoice c) {
    switch (c.action) {
      case _LinkAction.createNew:
        return 'create_new';
      case _LinkAction.skip:
        return 'skip';
      case _LinkAction.linkExisting:
        return 'link_${c.existingAccountId}';
    }
  }
}
