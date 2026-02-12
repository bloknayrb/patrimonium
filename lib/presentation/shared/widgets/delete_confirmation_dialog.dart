import 'package:flutter/material.dart';

/// Show a delete confirmation dialog.
///
/// Returns `true` if the user confirms deletion, `false` otherwise.
Future<bool> showDeleteConfirmation(
  BuildContext context, {
  required String itemName,
  String? message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Delete $itemName'),
      content: Text(message ?? 'Delete "$itemName"? This cannot be undone.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
          child: const Text('Delete'),
        ),
      ],
    ),
  );
  return result ?? false;
}
