import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import 'package:drift/drift.dart' show Value;
import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';
import 'category_picker_sheet.dart';

/// Shows a bottom sheet to create a new category.
///
/// Returns a [CategoryPickerResult] with the newly created category,
/// or null if dismissed.
Future<CategoryPickerResult?> showAddCategorySheet({
  required BuildContext context,
  required WidgetRef ref,
  String? initialName,
  String defaultType = 'expense',
}) {
  return showModalBottomSheet<CategoryPickerResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _AddCategoryForm(
        ref: ref,
        initialName: initialName,
        defaultType: defaultType,
      ),
    ),
  );
}

class _AddCategoryForm extends StatefulWidget {
  final WidgetRef ref;
  final String? initialName;
  final String defaultType;

  const _AddCategoryForm({
    required this.ref,
    this.initialName,
    required this.defaultType,
  });

  @override
  State<_AddCategoryForm> createState() => _AddCategoryFormState();
}

class _AddCategoryFormState extends State<_AddCategoryForm> {
  late final TextEditingController _nameController;
  late String _type;
  String? _parentId;
  bool _isSaving = false;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _type = widget.defaultType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<Category> _getParents(List<Category> categories) {
    return categories
        .where((c) => c.parentId == null && c.type == _type)
        .toList();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorText = 'Name is required');
      return;
    }
    if (name.length > 50) {
      setState(() => _errorText = 'Name must be 50 characters or less');
      return;
    }

    // Duplicate check
    final categories =
        widget.ref.read(allCategoriesProvider).valueOrNull ?? [];
    final duplicate = categories.any(
      (c) =>
          c.name.toLowerCase() == name.toLowerCase() &&
          c.parentId == _parentId &&
          c.type == _type,
    );
    if (duplicate) {
      setState(() => _errorText = 'Category already exists');
      return;
    }

    setState(() {
      _isSaving = true;
      _errorText = null;
    });

    try {
      final id = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      await widget.ref.read(categoryRepositoryProvider).insertCategory(
            CategoriesCompanion.insert(
              id: id,
              name: name,
              parentId: Value(_parentId),
              type: _type,
              icon: 'category',
              color: 0xFF9E9E9E,
              displayOrder: 999,
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (!mounted) return;
      Navigator.pop(context, CategoryPickerResult(id: id, name: name));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create category: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categories =
        widget.ref.read(allCategoriesProvider).valueOrNull ?? [];
    final parents = _getParents(categories);

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('New Category', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              autofocus: true,
              maxLength: 50,
              decoration: InputDecoration(
                labelText: 'Name',
                errorText: _errorText,
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) {
                if (_errorText != null) setState(() => _errorText = null);
              },
            ),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (selected) {
                setState(() {
                  _type = selected.first;
                  // Reset parent if it was for the other type
                  if (_parentId != null) {
                    final stillValid =
                        parents.any((p) => p.id == _parentId);
                    if (!stillValid) _parentId = null;
                  }
                });
              },
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String?>(
              initialValue: _parentId,
              decoration: const InputDecoration(
                labelText: 'Parent Category',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('None (top-level)'),
                ),
                for (final parent in _getParents(categories))
                  DropdownMenuItem(
                    value: parent.id,
                    child: Text(parent.name),
                  ),
              ],
              onChanged: (value) => setState(() => _parentId = value),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _save,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save & Select'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
