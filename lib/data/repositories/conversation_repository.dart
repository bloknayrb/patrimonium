import 'package:drift/drift.dart';

import '../local/database/app_database.dart';

/// Repository for conversation and message CRUD operations.
class ConversationRepository {
  ConversationRepository(this._db);

  final AppDatabase _db;

  // ─── Conversations ──────────────────────────────────────────────────

  /// Watch all conversations ordered by most recent update.
  Stream<List<Conversation>> watchAllConversations() {
    return (_db.select(_db.conversations)
          ..orderBy([(c) => OrderingTerm.desc(c.updatedAt)]))
        .watch();
  }

  /// Get a conversation by ID.
  Future<Conversation?> getConversationById(String id) {
    return (_db.select(_db.conversations)..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Insert a new conversation.
  Future<void> insertConversation(ConversationsCompanion conversation) {
    return _db.into(_db.conversations).insert(conversation);
  }

  /// Update conversation title.
  Future<void> updateConversationTitle(String id, String title) {
    return (_db.update(_db.conversations)..where((c) => c.id.equals(id)))
        .write(ConversationsCompanion(
      title: Value(title),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(String id) {
    return _db.transaction(() async {
      await (_db.delete(_db.messages)
            ..where((m) => m.conversationId.equals(id)))
          .go();
      await (_db.delete(_db.conversations)..where((c) => c.id.equals(id)))
          .go();
    });
  }

  // ─── Messages ───────────────────────────────────────────────────────

  /// Watch messages for a conversation, ordered chronologically.
  Stream<List<Message>> watchMessages(String conversationId) {
    return (_db.select(_db.messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  /// Get messages for a conversation (one-shot, for building LLM context).
  Future<List<Message>> getMessages(String conversationId) {
    return (_db.select(_db.messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
  }

  /// Insert a message.
  Future<void> insertMessage(MessagesCompanion message) {
    return _db.into(_db.messages).insert(message);
  }

  /// Update the content of an existing message (used after streaming completes).
  Future<void> updateMessageContent(String id, String content) {
    return (_db.update(_db.messages)..where((m) => m.id.equals(id)))
        .write(MessagesCompanion(content: Value(content)));
  }

  /// Touch the conversation's updatedAt timestamp.
  Future<void> touchConversation(String id) {
    return (_db.update(_db.conversations)..where((c) => c.id.equals(id)))
        .write(ConversationsCompanion(
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }
}
