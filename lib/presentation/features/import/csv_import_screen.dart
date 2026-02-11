import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/usecases/import/csv_import_service.dart';
import '../accounts/accounts_providers.dart';

/// Multi-step CSV import flow.
class CsvImportScreen extends ConsumerStatefulWidget {
  const CsvImportScreen({super.key});

  @override
  ConsumerState<CsvImportScreen> createState() => _CsvImportScreenState();
}

class _CsvImportScreenState extends ConsumerState<CsvImportScreen> {
  int _currentStep = 0;

  // Step 1: File selection
  final _filePathController = TextEditingController();

  // Step 2: Column mapping
  List<List<String>> _previewRows = [];
  List<String> _headers = [];
  int _dateColumn = 0;
  int _amountColumn = 1;
  int _payeeColumn = 2;
  int? _categoryColumn;
  int? _notesColumn;
  String _dateFormat = 'MM/dd/yyyy';
  bool _hasHeader = true;
  bool _negativeIsExpense = true;

  // Step 3: Preview
  CsvImportPreview? _preview;
  bool _isParsing = false;

  // Step 4: Import
  String? _selectedAccountId;
  bool _isImporting = false;
  CsvImportResult? _result;

  @override
  void dispose() {
    _filePathController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step 1: Load file and read preview rows
  // ---------------------------------------------------------------------------

  Future<void> _loadFile() async {
    final path = _filePathController.text.trim();
    if (path.isEmpty) {
      _showError('Please enter a file path');
      return;
    }

    final file = File(path);
    if (!await file.exists()) {
      if (mounted) _showError('File not found: $path');
      return;
    }

    try {
      final lines = await file.readAsLines();
      if (lines.isEmpty) {
        if (mounted) _showError('File is empty');
        return;
      }

      final rows = lines.take(6).map(_parseCsvLine).toList();

      setState(() {
        _previewRows = rows;
        _headers = _hasHeader && rows.isNotEmpty ? rows.first : [];
        // Auto-detect column count and reset mappings
        final colCount = rows.isNotEmpty ? rows.first.length : 0;
        _dateColumn = 0.clamp(0, (colCount - 1).clamp(0, 999));
        _amountColumn = colCount > 1 ? 1 : 0;
        _payeeColumn = colCount > 2 ? 2 : 0;
        _categoryColumn = null;
        _notesColumn = null;
        _currentStep = 1;
      });
    } catch (e) {
      if (mounted) _showError('Error reading file: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Step 2 → 3: Parse file with config
  // ---------------------------------------------------------------------------

  Future<void> _parseWithConfig() async {
    setState(() => _isParsing = true);

    final config = CsvImportConfig(
      dateColumn: _dateColumn,
      amountColumn: _amountColumn,
      payeeColumn: _payeeColumn,
      categoryColumn: _categoryColumn,
      notesColumn: _notesColumn,
      dateFormat: _dateFormat,
      hasHeader: _hasHeader,
      negativeIsExpense: _negativeIsExpense,
    );

    try {
      final service = ref.read(csvImportServiceProvider);
      final preview =
          await service.parseFile(_filePathController.text.trim(), config);

      if (!mounted) return;
      setState(() {
        _preview = preview;
        _isParsing = false;
        _currentStep = 2;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isParsing = false);
        _showError('Parse error: $e');
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Step 3 → 4: Execute import
  // ---------------------------------------------------------------------------

  Future<void> _executeImport() async {
    if (_selectedAccountId == null) {
      _showError('Please select an account');
      return;
    }
    if (_preview == null) return;

    setState(() => _isImporting = true);

    try {
      final service = ref.read(csvImportServiceProvider);
      final result = await service.executeImport(_preview!, _selectedAccountId!);

      if (!mounted) return;
      setState(() {
        _result = result;
        _isImporting = false;
        _currentStep = 3;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isImporting = false);
        _showError('Import error: $e');
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CSV line parser (same logic as service, for preview)
  // ---------------------------------------------------------------------------

  List<String> _parseCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (inQuotes) {
        if (char == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            buffer.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          buffer.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == ',') {
          fields.add(buffer.toString());
          buffer.clear();
        } else {
          buffer.write(char);
        }
      }
    }
    fields.add(buffer.toString());
    return fields;
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Import CSV')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: null, // handled by custom buttons
        onStepCancel: _currentStep > 0 && _currentStep < 3
            ? () => setState(() => _currentStep--)
            : null,
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        steps: [
          Step(
            title: const Text('Select File'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildFileStep(),
          ),
          Step(
            title: const Text('Map Columns'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1 ? StepState.complete : StepState.indexed,
            content: _buildMappingStep(),
          ),
          Step(
            title: const Text('Preview & Import'),
            isActive: _currentStep >= 2,
            state: _currentStep > 2 ? StepState.complete : StepState.indexed,
            content: _buildPreviewStep(),
          ),
          Step(
            title: const Text('Results'),
            isActive: _currentStep >= 3,
            state: _currentStep == 3 ? StepState.complete : StepState.indexed,
            content: _buildResultStep(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: File Selection
  // ---------------------------------------------------------------------------

  Widget _buildFileStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _filePathController,
          decoration: const InputDecoration(
            labelText: 'File Path',
            hintText: '/path/to/transactions.csv',
            filled: true,
            prefixIcon: Icon(Icons.file_present),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: CheckboxListTile(
                title: const Text('Has header row'),
                value: _hasHeader,
                onChanged: (v) => setState(() => _hasHeader = v ?? true),
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loadFile,
          icon: const Icon(Icons.upload_file),
          label: const Text('Load File'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 2: Column Mapping
  // ---------------------------------------------------------------------------

  Widget _buildMappingStep() {
    if (_previewRows.isEmpty) {
      return const Text('No data loaded. Go back and select a file.');
    }

    final dataRows = _hasHeader ? _previewRows.skip(1).toList() : _previewRows;
    final colCount = _previewRows.first.length;
    final columnOptions = List.generate(
      colCount,
      (i) => DropdownMenuItem(
        value: i,
        child: Text(
          _hasHeader && i < _headers.length
              ? 'Col $i: ${_headers[i]}'
              : 'Column $i',
        ),
      ),
    );

    final optionalColumnOptions = [
      const DropdownMenuItem<int?>(value: null, child: Text('None')),
      ...columnOptions.map((item) => DropdownMenuItem<int?>(
            value: item.value,
            child: item.child,
          )),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // CSV preview table
        const Text('File Preview:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowHeight: 36,
            dataRowMinHeight: 32,
            dataRowMaxHeight: 32,
            columnSpacing: 16,
            columns: List.generate(
              colCount,
              (i) => DataColumn(
                label: Text(
                  _hasHeader && i < _headers.length
                      ? _headers[i]
                      : 'Col $i',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ),
            ),
            rows: dataRows.take(3).map((row) {
              return DataRow(
                cells: List.generate(
                  colCount,
                  (i) => DataCell(Text(
                    i < row.length ? row[i] : '',
                    style: const TextStyle(fontSize: 12),
                  )),
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 20),
        const Text('Column Mapping:', style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),

        // Date column
        DropdownButtonFormField<int>(
          initialValue: _dateColumn,
          decoration: const InputDecoration(
            labelText: 'Date Column *',
            filled: true,
            isDense: true,
          ),
          items: columnOptions,
          onChanged: (v) => setState(() => _dateColumn = v ?? 0),
        ),
        const SizedBox(height: 12),

        // Date format
        DropdownButtonFormField<String>(
          initialValue: _dateFormat,
          decoration: const InputDecoration(
            labelText: 'Date Format *',
            filled: true,
            isDense: true,
          ),
          items: dateFormats
              .map((f) => DropdownMenuItem(value: f.$1, child: Text(f.$2)))
              .toList(),
          onChanged: (v) => setState(() => _dateFormat = v ?? 'MM/dd/yyyy'),
        ),
        const SizedBox(height: 12),

        // Amount column
        DropdownButtonFormField<int>(
          initialValue: _amountColumn,
          decoration: const InputDecoration(
            labelText: 'Amount Column *',
            filled: true,
            isDense: true,
          ),
          items: columnOptions,
          onChanged: (v) => setState(() => _amountColumn = v ?? 1),
        ),
        const SizedBox(height: 12),

        // Payee column
        DropdownButtonFormField<int>(
          initialValue: _payeeColumn,
          decoration: const InputDecoration(
            labelText: 'Payee Column *',
            filled: true,
            isDense: true,
          ),
          items: columnOptions,
          onChanged: (v) => setState(() => _payeeColumn = v ?? 2),
        ),
        const SizedBox(height: 12),

        // Category column (optional)
        DropdownButtonFormField<int?>(
          initialValue: _categoryColumn,
          decoration: const InputDecoration(
            labelText: 'Category Column',
            filled: true,
            isDense: true,
          ),
          items: optionalColumnOptions,
          onChanged: (v) => setState(() => _categoryColumn = v),
        ),
        const SizedBox(height: 12),

        // Notes column (optional)
        DropdownButtonFormField<int?>(
          initialValue: _notesColumn,
          decoration: const InputDecoration(
            labelText: 'Notes Column',
            filled: true,
            isDense: true,
          ),
          items: optionalColumnOptions,
          onChanged: (v) => setState(() => _notesColumn = v),
        ),
        const SizedBox(height: 12),

        // Sign convention
        CheckboxListTile(
          title: const Text('Negative amounts are expenses'),
          subtitle: const Text('Uncheck if your bank uses positive for expenses'),
          value: _negativeIsExpense,
          onChanged: (v) => setState(() => _negativeIsExpense = v ?? true),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),

        FilledButton(
          onPressed: _isParsing ? null : _parseWithConfig,
          child: _isParsing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Parse & Preview'),
        ),

        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => setState(() => _currentStep = 0),
          child: const Text('Back'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: Preview & Import
  // ---------------------------------------------------------------------------

  Widget _buildPreviewStep() {
    final preview = _preview;
    if (preview == null) {
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
                Text('File: ${preview.fileName}',
                    style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Text('Total rows: ${preview.totalRows}'),
                Text('Valid transactions: ${preview.transactions.length}'),
                Text('Duplicates: ${preview.duplicateCount}'),
                if (preview.errors.isNotEmpty)
                  Text(
                    'Errors: ${preview.errors.length}',
                    style: TextStyle(color: colorScheme.error),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Errors (if any)
        if (preview.errors.isNotEmpty) ...[
          Text('Errors:', style: TextStyle(
            fontWeight: FontWeight.bold,
            color: colorScheme.error,
          )),
          const SizedBox(height: 4),
          ...preview.errors.take(5).map((e) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(
                  'Row ${e.rowNumber}: ${e.message}',
                  style: TextStyle(fontSize: 12, color: colorScheme.error),
                ),
              )),
          if (preview.errors.length > 5)
            Text(
              '... and ${preview.errors.length - 5} more errors',
              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            ),
          const SizedBox(height: 16),
        ],

        // Transaction preview list
        Text('Preview (first 20):', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        ...preview.transactions.take(20).map((t) => ListTile(
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

            _selectedAccountId ??= accounts.first.id;

            return DropdownButtonFormField<String>(
              initialValue: _selectedAccountId,
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
              onChanged: (v) => setState(() => _selectedAccountId = v),
            );
          },
        ),
        const SizedBox(height: 16),

        if (preview.validCount > 0)
          FilledButton(
            onPressed: _isImporting ? null : _executeImport,
            child: _isImporting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text('Import ${preview.validCount} Transactions'),
          ),

        if (preview.validCount == 0)
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
          onPressed: () => setState(() => _currentStep = 1),
          child: const Text('Back'),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4: Results
  // ---------------------------------------------------------------------------

  Widget _buildResultStep() {
    final result = _result;
    if (result == null) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final hasError = result.errorMessage != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Icon(
          hasError ? Icons.warning_amber_rounded : Icons.check_circle,
          size: 64,
          color: hasError ? colorScheme.error : theme.finance.income,
        ),
        const SizedBox(height: 16),
        Text(
          hasError ? 'Import Failed' : 'Import Complete',
          style: theme.textTheme.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _resultRow('Imported', '${result.importedCount}'),
                _resultRow('Skipped (duplicates)', '${result.skippedCount}'),
                _resultRow('Errors', '${result.errorCount}'),
                if (result.errorMessage != null) ...[
                  const Divider(),
                  Text(
                    result.errorMessage!,
                    style: TextStyle(color: colorScheme.error, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }

  Widget _resultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
