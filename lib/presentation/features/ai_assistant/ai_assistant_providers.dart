import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';

/// All conversations, most recent first.
final conversationsProvider =
    StreamProvider.autoDispose<List<Conversation>>((ref) {
  return ref.watch(conversationRepositoryProvider).watchAllConversations();
});

/// Messages for a specific conversation, ordered oldest first.
final messagesProvider =
    StreamProvider.autoDispose.family<List<Message>, String>((ref, id) {
  return ref.watch(conversationRepositoryProvider).watchMessages(id);
});

/// Whether the LLM is currently generating a response.
final isStreamingProvider = StateProvider.autoDispose<bool>((ref) => false);

/// Accumulated streaming text chunks for live display before DB save.
final streamingTextProvider =
    StateProvider.autoDispose<String>((ref) => '');
