import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';
import '../../../domain/usecases/sync/simplefin_sync_service.dart';

/// Watch all bank connections.
final bankConnectionsProvider =
    StreamProvider.autoDispose<List<BankConnection>>((ref) {
  return ref.watch(bankConnectionRepositoryProvider).watchAllConnections();
});

/// Watch a single connection by ID.
final bankConnectionByIdProvider =
    StreamProvider.autoDispose.family<BankConnection?, String>((ref, id) {
  return ref.watch(bankConnectionRepositoryProvider).watchConnectionById(id);
});

/// Watch accounts linked to a specific connection.
final linkedAccountsProvider = FutureProvider.autoDispose
    .family<List<Account>, String>((ref, connectionId) {
  return ref
      .watch(accountRepositoryProvider)
      .getAccountsByConnection(connectionId);
});

/// Watch unlinked accounts (no bankConnectionId).
final unlinkedAccountsProvider =
    StreamProvider.autoDispose<List<Account>>((ref) {
  return ref.watch(accountRepositoryProvider).watchAllAccounts().map(
        (accounts) =>
            accounts.where((a) => a.bankConnectionId == null).toList(),
      );
});

/// Whether a sync is in progress for a connection.
final syncInProgressProvider =
    StateProvider.autoDispose.family<bool, String>((ref, connectionId) {
  return false;
});

/// Last sync result for a connection.
final lastSyncResultProvider = StateProvider.autoDispose
    .family<SyncResult?, String>((ref, connectionId) {
  return null;
});
