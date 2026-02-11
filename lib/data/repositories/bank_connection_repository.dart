import 'package:drift/drift.dart';

import '../local/database/app_database.dart';

/// Repository for bank connection CRUD operations.
class BankConnectionRepository {
  BankConnectionRepository(this._db);

  final AppDatabase _db;

  /// Watch all bank connections ordered by creation date.
  Stream<List<BankConnection>> watchAllConnections() {
    return (_db.select(_db.bankConnections)
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .watch();
  }

  /// Get all connections (one-shot).
  Future<List<BankConnection>> getAllConnections() {
    return (_db.select(_db.bankConnections)
          ..orderBy([(c) => OrderingTerm.desc(c.createdAt)]))
        .get();
  }

  /// Get a single connection by ID.
  Future<BankConnection?> getConnectionById(String id) {
    return (_db.select(_db.bankConnections)
          ..where((c) => c.id.equals(id)))
        .getSingleOrNull();
  }

  /// Watch a single connection by ID.
  Stream<BankConnection?> watchConnectionById(String id) {
    return (_db.select(_db.bankConnections)
          ..where((c) => c.id.equals(id)))
        .watchSingleOrNull();
  }

  /// Insert a new connection.
  Future<void> insertConnection(BankConnectionsCompanion connection) {
    return _db.into(_db.bankConnections).insert(connection);
  }

  /// Update an existing connection.
  Future<bool> updateConnection(BankConnectionsCompanion connection) {
    return (_db.update(_db.bankConnections)
          ..where((c) => c.id.equals(connection.id.value)))
        .write(connection)
        .then((rows) => rows > 0);
  }

  /// Update connection status and optional error message.
  Future<void> updateStatus(
    String id,
    String status, {
    String? errorMessage,
  }) {
    return (_db.update(_db.bankConnections)
          ..where((c) => c.id.equals(id)))
        .write(BankConnectionsCompanion(
      status: Value(status),
      errorMessage: Value(errorMessage),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Update the last synced timestamp.
  Future<void> updateLastSyncedAt(String id, int timestamp) {
    return (_db.update(_db.bankConnections)
          ..where((c) => c.id.equals(id)))
        .write(BankConnectionsCompanion(
      lastSyncedAt: Value(timestamp),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));
  }

  /// Delete a connection by ID.
  Future<int> deleteConnection(String id) {
    return (_db.delete(_db.bankConnections)
          ..where((c) => c.id.equals(id)))
        .go();
  }

  /// Get count of connections.
  Future<int> getConnectionCount() async {
    final count = _db.bankConnections.id.count();
    final result = await (_db.selectOnly(_db.bankConnections)
          ..addColumns([count]))
        .getSingle();
    return result.read(count) ?? 0;
  }
}
