import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';

/// All conversations ordered by most recent.
final conversationsProvider =
    StreamProvider.autoDispose<List<Conversation>>((ref) {
  return ref.watch(conversationRepositoryProvider).watchAllConversations();
});

/// Messages for a specific conversation.
final messagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>(
        (ref, conversationId) {
  return ref.watch(conversationRepositoryProvider).watchMessages(conversationId);
});

/// The partial text being streamed from the LLM right now. Null means idle.
final streamingMessageProvider =
    StateProvider.autoDispose<String?>((ref) => null);

/// Whether the AI is currently generating a response.
final isGeneratingProvider = StateProvider.autoDispose<bool>((ref) => false);
