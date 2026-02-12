import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/extensions/money_extensions.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../domain/usecases/import/csv_import_service.dart';
import '../../accounts/accounts_providers.dart';

/// Preview & Import step of the CSV import flow.
///
/// Shows parsed transaction preview, errors, and account selector
/// for executing the import.
class PreviewStep extends ConsumerWidget {
  const PreviewStep({
    super.key,
    required this.preview,
    required this.selectedAccountId,
    required this.isImporting,
    required this.onAccountChanged,
    required this.onImportPressed,
    required this.onBackPressed,
  });

  final CsvImportPreview? preview;
  final String? selectedAccountId;
  final bool isImporting;
  final ValueChanged<String?> onAccountChanged;
  final VoidCallback onImportPressed;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = preview;
    if (p == null) {
      return const Text('No data parsed. Go back and configure column mapping.');
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final accountsAsync = ref.watch(accountsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Summary card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('File: ${p.fileName}',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text('Total rows: ${p.totalRows}'),
                Text('Valid transactions: ${p.transactions.length}'),
                Text('Duplicates: ${p.duplicateCount}'),
                if (p.errors.isNotEmpty)
                  Text(
                    'Errors: ${p.errors.length}',
                    style: TextStyle(color: colorScheme.error),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Errors (if any)
        if (p.errors.isNotEmpty) ...[
          Text('Errors:', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.error,
          )),
          const SizedBox(height: 4),
          ...p.errors.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Row ${e.rowNumber}: ${e.message}',
                  style: TextStyle(fontSize: 12, color: colorScheme.error),
                ),
              )),
          if (p.errors.length > 5)
            Text(
              '... and ${p.errors.length - 5} more errors',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 16),
        ],

        // Transaction preview list
        Text('Preview (first 20):', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...p.transactions.take(20).map((t) => ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: t.isDuplicate
                  ? Icon(Icons.content_copy, color: colorScheme.onSurfaceVariant, size: 20)
                  : Icon(
                      t.amountCents < 0 ? Icons.arrow_upward : Icons.arrow_downward,
                      color: t.amountCents < 0
                          ? theme.finance.expense
                          : theme.finance.income,
                      size: 20,
                    ),
              title: Text(t.payee, style: const TextStyle(fontSize: 14)),
              subtitle: Text(
                '${t.date.toMediumDate()}${t.isDuplicate ? " (duplicate)" : ""}',
                style: TextStyle(
                  fontSize: 12,
                  color: t.isDuplicate
                      ? colorScheme.onSurfaceVariant
                      : null,
                ),
              ),
              trailing: Text(
                t.amountCents.toCurrency(),
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: t.isDuplicate
                      ? colorScheme.onSurfaceVariant
                      : t.amountCents < 0
                          ? theme.finance.expense
                          : theme.finance.income,
                ),
              ),
            )),

        const SizedBox(height: 20),

        // Account selector
        accountsAsync.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => Text('Error loading accounts',
              style: TextStyle(color: colorScheme.error)),
          data: (accounts) {
            if (accounts.isEmpty) {
              return Card(
                color: colorScheme.errorContainer,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No accounts found. Create an account first.'),
                ),
              );
            }

            return DropdownButtonFormField<String>(
              initialValue: selectedAccountId ?? accounts.first.id,
              decoration: const InputDecoration(
                labelText: 'Import to Account *',
                filled: true,
              ),
              items: accounts
                  .map((a) => DropdownMenuItem(
                        value: a.id,
                        child: Text(a.name),
                      ))
                  .toList(),
              onChanged: onAccountChanged,
            );
          },
        ),
        const SizedBox(height: 16),

        if (p.validCount > 0)
          FilledButton(
            onPressed: isImporting ? null : onImportPressed,
            child: isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Import ${p.validCount} Transactions'),
          ),

        if (p.validCount == 0)
          Card(
            color: colorScheme.errorContainer,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text('No new transactions to import. All rows are either '
                  'duplicates or have errors.'),
            ),
          ),

        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onBackPressed,
          child: const Text('Back'),
        ),
      ],
    );
  }
}
