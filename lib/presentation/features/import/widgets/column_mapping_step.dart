import 'package:flutter/material.dart';

import '../../../../domain/usecases/import/csv_import_service.dart';

/// Column mapping step of the CSV import flow.
///
/// Displays a data preview table and dropdowns for mapping CSV columns
/// to transaction fields.
class ColumnMappingStep extends StatelessWidget {
  const ColumnMappingStep({
    super.key,
    required this.previewRows,
    required this.headers,
    required this.hasHeader,
    required this.dateColumn,
    required this.dateFormat,
    required this.amountColumn,
    required this.payeeColumn,
    required this.categoryColumn,
    required this.notesColumn,
    required this.negativeIsExpense,
    required this.isParsing,
    required this.onDateColumnChanged,
    required this.onDateFormatChanged,
    required this.onAmountColumnChanged,
    required this.onPayeeColumnChanged,
    required this.onCategoryColumnChanged,
    required this.onNotesColumnChanged,
    required this.onNegativeIsExpenseChanged,
    required this.onParsePressed,
    required this.onBackPressed,
  });

  final List<List<String>> previewRows;
  final List<String> headers;
  final bool hasHeader;
  final int dateColumn;
  final String dateFormat;
  final int amountColumn;
  final int payeeColumn;
  final int? categoryColumn;
  final int? notesColumn;
  final bool negativeIsExpense;
  final bool isParsing;
  final ValueChanged<int?> onDateColumnChanged;
  final ValueChanged<String?> onDateFormatChanged;
  final ValueChanged<int?> onAmountColumnChanged;
  final ValueChanged<int?> onPayeeColumnChanged;
  final ValueChanged<int?> onCategoryColumnChanged;
  final ValueChanged<int?> onNotesColumnChanged;
  final ValueChanged<bool?> onNegativeIsExpenseChanged;
  final VoidCallback onParsePressed;
  final VoidCallback onBackPressed;

  @override
  Widget build(BuildContext context) {
    if (previewRows.isEmpty) {
      return const Text('No data loaded. Go back and select a file.');
    }

    final dataRows = hasHeader ? previewRows.skip(1).toList() : previewRows;
    final colCount = previewRows.first.length;
    final columnOptions = List.generate(
      colCount,
      (i) => DropdownMenuItem(
        value: i,
        child: Text(
          hasHeader && i < headers.length
              ? 'Col $i: ${headers[i]}'
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
                  hasHeader && i < headers.length
                      ? headers[i]
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
          initialValue: dateColumn,
          decoration: const InputDecoration(
            labelText: 'Date Column *',
            filled: true,
            isDense: true,
          ),
          items: columnOptions,
          onChanged: onDateColumnChanged,
        ),
        const SizedBox(height: 12),

        // Date format
        DropdownButtonFormField<String>(
          initialValue: dateFormat,
          decoration: const InputDecoration(
            labelText: 'Date Format *',
            filled: true,
            isDense: true,
          ),
          items: dateFormats
              .map((f) => DropdownMenuItem(value: f.$1, child: Text(f.$2)))
              .toList(),
          onChanged: onDateFormatChanged,
        ),
        const SizedBox(height: 12),

        // Amount column
        DropdownButtonFormField<int>(
          initialValue: amountColumn,
          decoration: const InputDecoration(
            labelText: 'Amount Column *',
            filled: true,
            isDense: true,
          ),
          items: columnOptions,
          onChanged: onAmountColumnChanged,
        ),
        const SizedBox(height: 12),

        // Payee column
        DropdownButtonFormField<int>(
          initialValue: payeeColumn,
          decoration: const InputDecoration(
            labelText: 'Payee Column *',
            filled: true,
            isDense: true,
          ),
          items: columnOptions,
          onChanged: onPayeeColumnChanged,
        ),
        const SizedBox(height: 12),

        // Category column (optional)
        DropdownButtonFormField<int?>(
          initialValue: categoryColumn,
          decoration: const InputDecoration(
            labelText: 'Category Column',
            filled: true,
            isDense: true,
          ),
          items: optionalColumnOptions,
          onChanged: onCategoryColumnChanged,
        ),
        const SizedBox(height: 12),

        // Notes column (optional)
        DropdownButtonFormField<int?>(
          initialValue: notesColumn,
          decoration: const InputDecoration(
            labelText: 'Notes Column',
            filled: true,
            isDense: true,
          ),
          items: optionalColumnOptions,
          onChanged: onNotesColumnChanged,
        ),
        const SizedBox(height: 12),

        // Sign convention
        CheckboxListTile(
          title: const Text('Negative amounts are expenses'),
          subtitle: const Text('Uncheck if your bank uses positive for expenses'),
          value: negativeIsExpense,
          onChanged: onNegativeIsExpenseChanged,
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 16),

        FilledButton(
          onPressed: isParsing ? null : onParsePressed,
          child: isParsing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Parse & Preview'),
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
