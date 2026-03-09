import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../local/database/app_database.dart';

/// Repository for AI conversation and message persistence.
class ConversationRepository {
  ConversationRepository(this._db);

  final AppDatabase _db;
  final _uuid = const Uuid();

  // ─── Conversations ────────────────────────────────────────────────

  /// Watch all conversations ordered by most recently updated.
  Stream<List<Conversation>> watchAllConversations() {
    return (_db.select(_db.conversations)
          ..orderBy([
            (c) => OrderingTerm.desc(c.updatedAt),
          ]))
        .watch();
  }

  /// Create a new conversation. Returns the new conversation's ID.
  Future<String> createConversation(String provider, String model) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.into(_db.conversations).insert(
          ConversationsCompanion.insert(
            id: id,
            provider: provider,
            model: model,
            createdAt: now,
            updatedAt: now,
          ),
        );
    return id;
  }

  /// Update the title of a conversation.
  Future<void> updateConversationTitle(String id, String title) async {
    await (_db.update(_db.conversations)..where((c) => c.id.equals(id)))
        .write(ConversationsCompanion(
      title: Value(title),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Delete a conversation and all its messages.
  Future<void> deleteConversation(String id) async {
    await (_db.delete(_db.messages)
          ..where((m) => m.conversationId.equals(id)))
        .go();
    await (_db.delete(_db.conversations)..where((c) => c.id.equals(id))).go();
  }

  // ─── Messages ─────────────────────────────────────────────────────

  /// Watch messages for a conversation ordered by creation time (oldest first).
  Stream<List<Message>> watchMessages(String conversationId) {
    return (_db.select(_db.messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .watch();
  }

  /// Add a message to a conversation. Returns the new message.
  Future<Message> addMessage(
    String conversationId,
    String role,
    String content, {
    int? tokenCount,
  }) async {
    final id = _uuid.v4();
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.into(_db.messages).insert(
          MessagesCompanion.insert(
            id: id,
            conversationId: conversationId,
            role: role,
            content: content,
            tokenCount: Value(tokenCount),
            createdAt: now,
          ),
        );

    // Bump updatedAt on the parent conversation
    await (_db.update(_db.conversations)
          ..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(
      updatedAt: Value(now),
    ));

    return (_db.select(_db.messages)..where((m) => m.id.equals(id)))
        .getSingle();
  }

  /// Delete a single message (used for retry/regenerate support).
  Future<void> deleteMessage(String id) async {
    await (_db.delete(_db.messages)..where((m) => m.id.equals(id))).go();
  }

  /// Load messages for a conversation as a one-shot list.
  Future<List<Message>> getMessages(String conversationId) {
    return (_db.select(_db.messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAt)]))
        .get();
  }
}
