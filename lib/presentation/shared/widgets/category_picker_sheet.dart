import 'package:flutter/material.dart';

import '../../../data/local/database/app_database.dart';

/// Result returned when a category is selected.
class CategoryPickerResult {
  final String id;
  final String name;

  const CategoryPickerResult({required this.id, required this.name});
}

/// Shows a hierarchical category picker bottom sheet.
///
/// Returns the selected [CategoryPickerResult], or null if cleared/dismissed.
Future<CategoryPickerResult?> showCategoryPickerSheet({
  required BuildContext context,
  required List<Category> categories,
  String? selectedCategoryId,
  String title = 'Select Category',
  bool showClear = true,
}) {
  final parents = categories.where((c) => c.parentId == null).toList();

  return showModalBottomSheet<CategoryPickerResult>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, scrollController) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                if (showClear && selectedCategoryId != null)
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, null),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              controller: scrollController,
              children: [
                for (final parent in parents) ...[
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          Color(parent.color).withValues(alpha: 0.15),
                      child: Icon(Icons.category,
                          color: Color(parent.color), size: 20),
                    ),
                    title: Text(parent.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    selected: selectedCategoryId == parent.id,
                    onTap: () => Navigator.pop(
                      ctx,
                      CategoryPickerResult(id: parent.id, name: parent.name),
                    ),
                  ),
                  for (final child
                      in categories.where((c) => c.parentId == parent.id))
                    ListTile(
                      contentPadding:
                          const EdgeInsets.only(left: 56, right: 16),
                      title: Text(child.name),
                      selected: selectedCategoryId == child.id,
                      onTap: () => Navigator.pop(
                        ctx,
                        CategoryPickerResult(id: child.id, name: child.name),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
