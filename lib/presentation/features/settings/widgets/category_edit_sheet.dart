import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/constants/category_icons.dart';
import '../../../../core/di/providers.dart';
import '../../../../data/local/database/models.dart';

/// Dialog for adding or editing a category with icon and color pickers.
class CategoryEditSheet extends ConsumerStatefulWidget {
  final Category? category;
  final Category? parentCategory;
  final String? defaultType;

  const CategoryEditSheet({
    super.key,
    this.category,
    this.parentCategory,
    this.defaultType,
  });

  @override
  ConsumerState<CategoryEditSheet> createState() => _CategoryEditSheetState();
}

class _CategoryEditSheetState extends ConsumerState<CategoryEditSheet> {
  late final TextEditingController _nameController;
  late String _type;
  late String _icon;
  late int _color;
  String? _parentId;

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _nameController = TextEditingController(text: cat?.name ?? '');
    _type = cat?.type ?? widget.defaultType ?? widget.parentCategory?.type ?? 'expense';
    _icon = cat?.icon ?? 'category';
    _color = cat?.color ?? 0xFF9E9E9E;
    _parentId = cat?.parentId ?? widget.parentCategory?.id;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allCategories =
        ref.watch(allCategoriesProvider).valueOrNull ?? [];
    final parents = allCategories
        .where((c) => c.parentId == null && c.type == _type)
        .toList();

    return AlertDialog(
      title: Text(_isEditing ? 'Edit Category' : 'Add Category'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            // Type selector (only for new top-level categories)
            if (!_isEditing && widget.parentCategory == null)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'expense', label: Text('Expense')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                ],
                selected: {_type},
                onSelectionChanged: (selected) {
                  setState(() {
                    _type = selected.first;
                    _parentId = null;
                  });
                },
              ),
            if (!_isEditing && widget.parentCategory == null)
              const SizedBox(height: 16),
            // Parent selector (only for new categories without a preset parent)
            if (!_isEditing && widget.parentCategory == null)
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
                  for (final parent in parents)
                    DropdownMenuItem(
                      value: parent.id,
                      child: Text(parent.name),
                    ),
                ],
                onChanged: (value) => setState(() => _parentId = value),
              ),
            if (!_isEditing && widget.parentCategory == null)
              const SizedBox(height: 16),
            // Icon picker
            Text('Icon', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            IconPicker(
              selectedIcon: _icon,
              color: _color,
              onChanged: (icon) => setState(() => _icon = icon),
            ),
            const SizedBox(height: 16),
            // Color picker
            Text('Color', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            ColorPicker(
              selectedColor: _color,
              onChanged: (color) => setState(() => _color = color),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is required')),
      );
      return;
    }

    final repo = ref.read(categoryRepositoryProvider);
    final now = DateTime.now().millisecondsSinceEpoch;

    if (_isEditing) {
      await repo.updateCategory(CategoriesCompanion(
        id: Value(widget.category!.id),
        name: Value(name),
        icon: Value(_icon),
        color: Value(_color),
        updatedAt: Value(now),
      ));
    } else {
      await repo.insertCategory(CategoriesCompanion.insert(
        id: const Uuid().v4(),
        name: name,
        parentId: Value(_parentId),
        type: _type,
        icon: _icon,
        color: _color,
        displayOrder: 999,
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (mounted) Navigator.pop(context);
  }
}

class IconPicker extends StatelessWidget {
  final String selectedIcon;
  final int color;
  final ValueChanged<String> onChanged;

  const IconPicker({
    super.key,
    required this.selectedIcon,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: pickableIconNames.map((name) {
        final isSelected = name == selectedIcon;
        return InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onChanged(name),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: isSelected
                  ? Color(color).withValues(alpha: 0.2)
                  : null,
              border: isSelected
                  ? Border.all(color: Color(color), width: 2)
                  : Border.all(
                      color: theme.colorScheme.outlineVariant,
                      width: 1,
                    ),
            ),
            child: Icon(
              getCategoryIcon(name),
              size: 20,
              color: isSelected ? Color(color) : theme.colorScheme.onSurface,
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ColorPicker extends StatelessWidget {
  final int selectedColor;
  final ValueChanged<int> onChanged;

  const ColorPicker({
    super.key,
    required this.selectedColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: pickableColors.map((colorValue) {
        final isSelected = colorValue == selectedColor;
        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => onChanged(colorValue),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Color(colorValue),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 3,
                    )
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }).toList(),
    );
  }
}
