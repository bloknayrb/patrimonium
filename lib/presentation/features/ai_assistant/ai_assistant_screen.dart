import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/router/app_router.dart';
import '../../../data/local/database/app_database.dart';
import '../../shared/empty_states/empty_state_widget.dart';
import '../../shared/loading/shimmer_loading.dart';
import '../../shared/widgets/delete_confirmation_dialog.dart' show showDeleteConfirmation;
import 'ai_assistant_providers.dart';

/// Conversation list screen — root of the AI assistant tab.
class AiAssistantScreen extends ConsumerWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(activeLlmClientProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
        actions: [
          if (clientAsync.valueOrNull != null)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'New conversation',
              onPressed: () => _newConversation(context, ref),
            ),
        ],
      ),
      body: clientAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => EmptyStateWidget(
          icon: Icons.smart_toy,
          title: 'Set Up AI Assistant',
          description: 'Configure an LLM provider to get started.',
          actionLabel: 'Configure',
          actionIcon: Icons.settings,
          onAction: () => context.push(AppRoutes.llmSettings),
        ),
        data: (client) {
          if (client == null) {
            return EmptyStateWidget(
              icon: Icons.smart_toy,
              title: 'Set Up AI Assistant',
              description:
                  'Connect to Gemini, Claude, OpenAI, or a local Ollama '
                  'server to analyze your finances.',
              actionLabel: 'Configure',
              actionIcon: Icons.settings,
              onAction: () => context.push(AppRoutes.llmSettings),
            );
          }
          return _ConversationList(onNewConversation: () => _newConversation(context, ref));
        },
      ),
    );
  }

  Future<void> _newConversation(BuildContext context, WidgetRef ref) async {
    final clientAsync = ref.read(activeLlmClientProvider);
    final client = clientAsync.valueOrNull;
    if (client == null) return;

    final repo = ref.read(conversationRepositoryProvider);
    final conversationId =
        await repo.createConversation(client.providerName, client.modelName);

    if (context.mounted) {
      context.push('${AppRoutes.aiChat}/$conversationId');
    }
  }
}

class _ConversationList extends ConsumerWidget {
  final VoidCallback onNewConversation;

  const _ConversationList({required this.onNewConversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversations = ref.watch(conversationsProvider);

    return conversations.when(
      loading: () => const ShimmerTransactionList(itemCount: 4),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (items) {
        if (items.isEmpty) {
          return EmptyStateWidget(
            icon: Icons.chat_bubble_outline,
            title: 'No Conversations Yet',
            description: 'Start a conversation to get AI insights on your finances.',
            actionLabel: 'Start Conversation',
            onAction: onNewConversation,
          );
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final conversation = items[index];
            return _ConversationTile(
              conversation: conversation,
              onDelete: () => _deleteConversation(context, ref, conversation),
            );
          },
        );
      },
    );
  }

  Future<void> _deleteConversation(
      BuildContext context, WidgetRef ref, Conversation c) async {
    final confirmed = await showDeleteConfirmation(
      context,
      itemName: 'Conversation',
      message: 'This conversation and all its messages will be deleted.',
    );
    if (confirmed) {
      await ref.read(conversationRepositoryProvider).deleteConversation(c.id);
    }
  }
}

class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onDelete;

  const _ConversationTile({
    required this.conversation,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final title = conversation.title ?? 'New Conversation';
    final date = DateTime.fromMillisecondsSinceEpoch(conversation.updatedAt);
    final dateLabel = _formatDate(date);

    return Dismissible(
      key: ValueKey(conversation.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        color: Theme.of(context).colorScheme.error,
        child: const Icon(Icons.delete, color: Colors.white),
      ),
      confirmDismiss: (_) async {
        onDelete();
        return false; // Let the repo update handle list refresh
      },
      child: ListTile(
        leading: const Icon(Icons.chat_bubble_outline),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          conversation.model,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          dateLabel,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        onTap: () {
          context.push('${AppRoutes.aiChat}/${conversation.id}');
        },
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.day == now.day &&
        date.month == now.month &&
        date.year == now.year) {
      final h = date.hour.toString().padLeft(2, '0');
      final m = date.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return '${date.month}/${date.day}';
  }
}
