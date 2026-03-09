import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../domain/usecases/ai/chat_service.dart';
import 'ai_assistant_providers.dart';
import 'widgets/chat_input_bar.dart';
import 'widgets/chat_message_bubble.dart';

/// Full-screen chat view for a single conversation.
class AiChatScreen extends ConsumerStatefulWidget {
  final String conversationId;

  const AiChatScreen({super.key, required this.conversationId});

  @override
  ConsumerState<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends ConsumerState<AiChatScreen> {
  final _scrollController = ScrollController();
  bool _showDisclaimer = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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

  Future<void> _sendMessage(String text) async {
    final clientAsync = ref.read(activeLlmClientProvider);
    final client = clientAsync.valueOrNull;
    if (client == null) return;

    setState(() => _showDisclaimer = false);

    ref.read(isStreamingProvider.notifier).state = true;
    ref.read(streamingTextProvider.notifier).state = '';

    String accumulated = '';

    try {
      final chatService = ref.read(chatServiceProvider);
      await for (final chunk in chatService.sendMessage(
        client: client,
        conversationId: widget.conversationId,
        userMessage: text,
      )) {
        accumulated += chunk;
        ref.read(streamingTextProvider.notifier).state = accumulated;
        _scrollToBottom();
      }
    } on RateLimitException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Daily limit reached. Try again tomorrow.')),
        );
      }
    } catch (e) {
      final msg = e.toString();
      if (mounted) {
        String snackText = 'Something went wrong.';
        if (msg.contains('401') || msg.contains('403')) {
          snackText = 'Invalid API key. Fix in Settings.';
        } else if (msg.contains('429')) {
          snackText = 'Rate limited. Try again later.';
        } else if (msg.contains('connection') || msg.contains('timeout')) {
          snackText = 'No connection.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(snackText)),
        );
      }
    } finally {
      if (mounted) {
        ref.read(isStreamingProvider.notifier).state = false;
        ref.read(streamingTextProvider.notifier).state = '';
        _scrollToBottom();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider(widget.conversationId));
    final isStreaming = ref.watch(isStreamingProvider);
    final streamingText = ref.watch(streamingTextProvider);

    // Auto-scroll when new messages arrive
    ref.listen(messagesProvider(widget.conversationId), (prev, next) {
      _scrollToBottom();
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (msgs) {
                final itemCount = msgs.length +
                    (_showDisclaimer && msgs.isEmpty ? 1 : 0) +
                    (isStreaming && streamingText.isNotEmpty ? 1 : 0);

                if (itemCount == 0) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text(
                        'Ask anything about your finances.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: itemCount,
                  itemBuilder: (context, index) {
                    // Disclaimer as first item when conversation is new
                    if (_showDisclaimer && msgs.isEmpty && index == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'AI responses are for informational purposes only, '
                          'not professional financial advice.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontStyle: FontStyle.italic,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    // Adjust index for disclaimer offset
                    final msgIndex =
                        (_showDisclaimer && msgs.isEmpty) ? index - 1 : index;

                    // Streaming bubble at the end
                    if (isStreaming &&
                        streamingText.isNotEmpty &&
                        msgIndex == msgs.length) {
                      return ChatMessageBubble(
                        role: 'assistant',
                        content: streamingText,
                        isStreaming: true,
                      );
                    }

                    if (msgIndex < 0 || msgIndex >= msgs.length) {
                      return const SizedBox.shrink();
                    }

                    final msg = msgs[msgIndex];
                    return ChatMessageBubble(
                      key: ValueKey(msg.id),
                      role: msg.role,
                      content: msg.content,
                    );
                  },
                );
              },
            ),
          ),
          const Divider(height: 1),
          ChatInputBar(
            isStreaming: isStreaming,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}
