import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/category_icons.dart';
import '../../../../core/di/providers.dart';
import '../../../../data/local/database/models.dart';
import 'category_edit_sheet.dart';

class CategoryList extends ConsumerWidget {
  final List<Category> categories;
  final String type;

  const CategoryList({
    super.key,
    required this.categories,
    required this.type,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parents = categories
        .where((c) => c.parentId == null && c.type == type)
        .toList();

    if (parents.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No categories yet. Tap + to add one.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 80),
      itemCount: parents.length,
      itemBuilder: (context, index) {
        final parent = parents[index];
        final children =
            categories.where((c) => c.parentId == parent.id).toList();
        return ParentCategoryTile(
          parent: parent,
          children: children,
        );
      },
    );
  }
}

class ParentCategoryTile extends ConsumerWidget {
  final Category parent;
  final List<Category> children;

  const ParentCategoryTile({
    super.key,
    required this.parent,
    required this.children,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ExpansionTile(
      leading: CircleAvatar(
        backgroundColor: Color(parent.color).withValues(alpha: 0.15),
        child: Icon(
          getCategoryIcon(parent.icon),
          color: Color(parent.color),
          size: 20,
        ),
      ),
      title: Text(
        parent.name,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: children.isNotEmpty
          ? Text('${children.length} subcategories',
              style: theme.textTheme.bodySmall)
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit',
            onPressed: () => showDialog(
              context: context,
              builder: (_) => CategoryEditSheet(category: parent),
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: theme.colorScheme.error),
            tooltip: 'Delete',
            onPressed: () => _confirmDelete(context, ref, parent),
          ),
          const Icon(Icons.expand_more),
        ],
      ),
      children: [
        for (final child in children)
          ListTile(
            contentPadding: const EdgeInsets.only(left: 72, right: 16),
            leading: Icon(
              getCategoryIcon(child.icon),
              color: Color(child.color),
              size: 18,
            ),
            title: Text(child.name),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  tooltip: 'Edit',
                  onPressed: () => showDialog(
                    context: context,
                    builder: (_) => CategoryEditSheet(
                      category: child,
                      parentCategory: parent,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      size: 18, color: theme.colorScheme.error),
                  tooltip: 'Delete',
                  onPressed: () => _confirmDelete(context, ref, child),
                ),
              ],
            ),
          ),
        // Add subcategory button
        ListTile(
          contentPadding: const EdgeInsets.only(left: 72, right: 16),
          leading: Icon(Icons.add, color: theme.colorScheme.primary, size: 18),
          title: Text(
            'Add Subcategory',
            style: TextStyle(color: theme.colorScheme.primary),
          ),
          onTap: () => showDialog(
            context: context,
            builder: (_) => CategoryEditSheet(
              parentCategory: parent,
              defaultType: parent.type,
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Category category) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Category'),
        content: Text(
          'Delete "${category.name}"? Transactions using this category '
          'will become uncategorized.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await ref.read(categoryRepositoryProvider).deleteCategory(category.id);
    }
  }
}
