import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../core/router/app_router.dart';
import '../../../data/local/database/app_database.dart';
import '../../../domain/usecases/retirement/retirement_params_extractor.dart';
import '../../../domain/usecases/retirement/retirement_prompts.dart';
import '../../shared/utils/snackbar_helpers.dart';
import 'ai_assistant_providers.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_bubble.dart';

/// Full-screen chat view for a single conversation.
class AiChatScreen extends ConsumerStatefulWidget {
  const AiChatScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _scrollController = ScrollController();
  int _prevMessageCount = 0;
  bool _isCreatingPlan = false;
  String _purpose = ConversationPurpose.general;

  @override
  void initState() {
    super.initState();
    // Load purpose once — it's immutable after creation
    _loadPurpose();
    // Show financial disclaimer on first open (once per screen instance)
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowDisclaimer());
  }

  Future<void> _loadPurpose() async {
    final convRepo = ref.read(conversationRepositoryProvider);
    final purpose = await convRepo.getConversationPurpose(widget.conversationId);
    if (mounted) setState(() => _purpose = purpose);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _maybeShowDisclaimer() {
    // Disclaimer is shown when messages list is empty (new conversation)
    final messages =
        ref.read(messagesProvider(widget.conversationId)).valueOrNull ?? [];
    if (messages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI responses are for informational purposes only, not professional financial advice.',
          ),
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  /// Get the system prompt override for retirement conversations.
  String? _getSystemPromptOverride(String purpose) {
    if (purpose == ConversationPurpose.retirement) {
      return retirementInterviewPrompt;
    }
    return null;
  }

  Future<void> _sendMessage(String text, {String? purpose}) async {
    final clientAsync = ref.read(activeLlmClientProvider);
    final client = clientAsync.valueOrNull;
    if (client == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No AI provider configured.'),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => context.push(AppRoutes.llmSettings),
            ),
          ),
        );
      }
      return;
    }

    ref.read(isStreamingProvider.notifier).state = true;
    ref.read(streamingTextProvider.notifier).state = '';

    final chatService = ref.read(chatServiceProvider);

    try {
      await for (final chunk in chatService.sendMessage(
        client: client,
        conversationId: widget.conversationId,
        userMessage: text,
        systemPromptOverride: _getSystemPromptOverride(purpose ?? ''),
      )) {
        ref.read(streamingTextProvider.notifier).state += chunk;
        _scrollToBottom();
      }
    } on LLMError catch (e) {
      if (!mounted) return;
      final message = e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          action: message.contains('key') || message.contains('provider')
              ? SnackBarAction(
                  label: 'Fix in Settings',
                  onPressed: () => context.push(AppRoutes.llmSettings),
                )
              : null,
        ),
      );
      ref.read(isStreamingProvider.notifier).state = false;
      ref.read(streamingTextProvider.notifier).state = '';
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      ref.read(isStreamingProvider.notifier).state = false;
      ref.read(streamingTextProvider.notifier).state = '';
    }
  }

  Future<void> _createRetirementPlan() async {
    final clientAsync = ref.read(activeLlmClientProvider);
    final client = clientAsync.valueOrNull;
    if (client == null) {
      if (mounted) {
        showErrorSnackbar(context, 'Configure an AI provider first');
      }
      return;
    }

    setState(() => _isCreatingPlan = true);

    try {
      final extractor = ref.read(retirementParamsExtractorProvider);
      final params = await extractor.extract(client, widget.conversationId);

      if (!mounted) return;

      if (params == null) {
        showErrorSnackbar(
          context,
          "Couldn't extract your retirement details — try answering a few more questions",
        );
        return;
      }

      // Create the retirement goal
      final goalId = const Uuid().v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      final goalRepo = ref.read(goalRepositoryProvider);
      await goalRepo.insertGoal(GoalsCompanion(
        id: Value(goalId),
        name: Value(params.goalName),
        goalType: const Value('retirement'),
        targetAmountCents: Value(params.targetAmountCents),
        currentAmountCents: const Value(0),
        icon: const Value('trending_up'),
        color: Value(Colors.teal.toARGB32()),
        monthlyContributionCents: Value(params.monthlyContributionCents),
        annualReturnBps: Value(params.annualReturnBps),
        annualVolatilityBps: Value(params.annualVolatilityBps),
        retirementYear: Value(params.retirementYear),
        desiredMonthlyIncomeCents: Value(params.desiredMonthlyIncomeCents),
        createdAt: Value(now),
        updatedAt: Value(now),
      ));

      if (mounted) {
        showSuccessSnackbar(context, 'Retirement plan created!');
        context.push('${AppRoutes.retirementGoal}/$goalId');
      }
    } catch (e) {
      if (mounted) {
        showErrorSnackbar(context, 'Error creating plan: $e');
      }
    } finally {
      if (mounted) setState(() => _isCreatingPlan = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.conversationId));
    final isStreaming = ref.watch(isStreamingProvider);
    final streamingText = ref.watch(streamingTextProvider);
    final isRetirement = _purpose == ConversationPurpose.retirement;

    // Clear streaming state once the DB message arrives
    ref.listen(messagesProvider(widget.conversationId), (prev, next) {
      final prevCount = prev?.valueOrNull?.length ?? 0;
      final nextMessages = next.valueOrNull ?? [];
      if (isStreaming &&
          nextMessages.length > prevCount &&
          nextMessages.isNotEmpty &&
          nextMessages.last.role == 'assistant') {
        ref.read(isStreamingProvider.notifier).state = false;
        ref.read(streamingTextProvider.notifier).state = '';
      }
    });

    // Auto-scroll when messages arrive
    final messageCount = messagesAsync.valueOrNull?.length ?? 0;
    if (messageCount > _prevMessageCount) {
      _prevMessageCount = messageCount;
      _scrollToBottom();
    }

    // Show "Create Plan" button after 4+ messages in retirement mode
    final showCreatePlan = isRetirement && messageCount >= 4;

    return Scaffold(
      appBar: AppBar(
        title: messagesAsync.when(
          loading: () => Text(isRetirement ? 'Retirement Planning' : 'Chat'),
          error: (_, _) => Text(isRetirement ? 'Retirement Planning' : 'Chat'),
          data: (msgs) {
            if (isRetirement) return const Text('Retirement Planning');
            final conversations = ref.read(conversationsProvider).valueOrNull;
            final conv = conversations
                ?.where((c) => c.id == widget.conversationId)
                .firstOrNull;
            return Text(conv?.title ?? 'New Chat');
          },
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (_, _) =>
                  const Center(child: Text('Failed to load messages')),
              data: (messages) {
                final itemCount =
                    messages.length + (isStreaming ? 1 : 0);

                if (itemCount == 0) {
                  return Center(
                    child: Text(
                      isRetirement
                          ? "Let's plan your retirement! Send a message to start."
                          : 'Ask anything about your finances',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    // Streaming bubble is always last
                    if (isStreaming && index == messages.length) {
                      return ChatMessageBubble(
                        role: 'assistant',
                        content: streamingText.isEmpty
                            ? '…'
                            : streamingText,
                        isStreaming: true,
                      );
                    }
                    final msg = messages[index];
                    return ChatMessageBubble(
                      role: msg.role,
                      content: msg.content,
                    );
                  },
                );
              },
            ),
          ),
          if (showCreatePlan) ...[
            const Divider(height: 1),
            _CreatePlanBar(
              isCreating: _isCreatingPlan,
              onCreatePlan: _createRetirementPlan,
            ),
          ],
          const Divider(height: 1),
          ChatInputBar(
            isStreaming: isStreaming,
            onSend: (text) => _sendMessage(text, purpose: _purpose),
          ),
        ],
      ),
    );
  }
}

class _CreatePlanBar extends StatelessWidget {
  const _CreatePlanBar({
    required this.isCreating,
    required this.onCreatePlan,
  });

  final bool isCreating;
  final VoidCallback onCreatePlan;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: isCreating ? null : onCreatePlan,
          icon: isCreating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.auto_graph),
          label: Text(
            isCreating ? 'Creating Plan…' : 'Create Retirement Plan',
          ),
        ),
      ),
    );
  }
}
