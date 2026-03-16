/// Result of a sync operation.
class SyncResult {
  final String connectionId;
  final int accountsUpdated;
  final int transactionsImported;
  final int transactionsSkipped;
  final int apiTransactionsReceived;
  final String? errorMessage;
  final bool rateLimited;

  const SyncResult({
    required this.connectionId,
    this.accountsUpdated = 0,
    this.transactionsImported = 0,
    this.transactionsSkipped = 0,
    this.apiTransactionsReceived = 0,
    this.errorMessage,
    this.rateLimited = false,
  });
}

/// Connection status constants.
class ConnectionStatus {
  ConnectionStatus._();

  static const String connected = 'connected';
  static const String syncing = 'syncing';
  static const String error = 'error';
  static const String disconnected = 'disconnected';
  static const String rateLimited = 'rate_limited';
}
