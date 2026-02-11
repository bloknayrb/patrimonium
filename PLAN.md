# Plan: Multi-Login Same Bank Support (SimpleFIN)

## Problem

Two Chase logins — one for your mortgage, one for your wife's credit card. The app must sync transaction data from both, keep them distinct, and handle edge cases like shared/joint accounts.

## Key SimpleFIN Protocol Facts

These constrain the design:

- **One access URL = ALL institutions** linked in a SimpleFIN Bridge account. `GET /accounts` returns every account across every bank, tagged with `org.name`.
- **Two Chase logins likely need two Bridge accounts** — Bridge may not support linking the same institution twice with different credentials. Each Bridge account produces one access URL.
- **Accounts + transactions come in one API call** (`GET /accounts`). No separate transactions endpoint. Transactions are nested inside each account object.
- **Transaction IDs are unique per-account, NOT globally.** Dedup must use `(accountId, transactionId)` composite key.
- **Date filtering** via `start-date` / `end-date` query params (Unix epoch seconds).
- **Rate limit**: ~24 requests/day. Data refreshes once/day upstream.
- **Access URL contains embedded HTTP Basic Auth credentials** — must be stored in secure storage, never logged.
- **Error handling**: 403 = access revoked (re-link needed), 402 = subscription lapsed. `errors` array in 200 responses may contain warnings.

## Design Decisions

### One BankConnection per Access URL

Each `BankConnection` row represents one SimpleFIN Bridge account (one access URL). A single connection may return accounts from multiple institutions. For the user's case with two Chase logins on two Bridge accounts, that's two `BankConnection` rows.

### All accounts come from sync

No manual account creation. The "Add Account" flow becomes "Add Bank Connection" (enter SimpleFIN setup token). Account records are created/updated by the sync service.

### Account ownership

Each synced account belongs to exactly one `BankConnection`. If a joint account appears in both connections, the user picks which connection owns it (or hides the duplicate).

## Schema Changes

### Migration (schema version 1 → 2)

**Add to `BankConnections`:**
- `displayLabel` TEXT nullable — user-assigned label ("Chase - Mortgage", "Chase - Sarah's CC")
- `lastSyncCursor` INTEGER nullable — Unix epoch seconds of last successful sync's most recent transaction date, used as `start-date` on next sync

**Add unique index on `Accounts`:**
- `UNIQUE(bankConnectionId, externalId)` where both are non-null — prevents duplicate synced accounts per connection

**Add real foreign key:**
- `Accounts.bankConnectionId` → `BankConnections.id` with `ON DELETE SET NULL` — preserves account history if connection is deleted

No changes to `Transactions` table.

## New Files

### 1. `data/remote/simplefin_client.dart` — HTTP client

In `data/` because it does I/O (HTTP calls via dio).

```
class SimplefinClient {
  SimplefinClient(Dio dio);

  /// Base64-decode setupToken → claim URL, POST to it → access URL.
  /// One-time use. Throws on 403 (already claimed).
  Future<String> claimAccessUrl(String setupToken);

  /// GET {accessUrl}/accounts with optional filters.
  /// Returns all accounts + nested transactions in one call.
  Future<SimplefinAccountSet> fetchAccountSet(
    String accessUrl, {
    int? startDate,     // Unix epoch seconds
    int? endDate,
    bool pending = false,
  });
}
```

### 2. `data/remote/simplefin_models.dart` — DTOs

Lightweight models for API responses, decoupled from Drift:

```
class SimplefinAccountSet {
  final List<SimplefinAccount> accounts;
  final List<String> errors;  // warnings from Bridge
}

class SimplefinAccount {
  final String id;           // unique per-org
  final String name;
  final String orgName;      // institution name
  final String? orgUrl;
  final String currency;
  final String balance;      // decimal string
  final int balanceDate;     // Unix epoch
  final List<SimplefinTransaction> transactions;
}

class SimplefinTransaction {
  final String id;           // unique per-account only
  final int posted;          // Unix epoch (0 = pending)
  final String amount;       // decimal string
  final String description;
  final String? payee;
  final String? memo;
}
```

### 3. `data/repositories/bank_connection_repository.dart` — CRUD

```
class BankConnectionRepository {
  BankConnectionRepository(AppDatabase db);

  Stream<List<BankConnection>> watchAll();
  Future<BankConnection?> getById(String id);
  Future<void> insert(BankConnectionsCompanion connection);
  Future<void> update(BankConnectionsCompanion connection);
  Future<void> delete(String id);
  Future<void> updateSyncStatus(String id, {
    required String status,
    int? lastSyncedAt,
    int? lastSyncCursor,
    String? errorMessage,
  });
}
```

### 4. `domain/usecases/bank_sync/bank_sync_service.dart` — orchestrator

This is business logic (coordinates client, repos, secure storage):

```
class BankSyncService {
  BankSyncService({
    required SimplefinClient client,
    required BankConnectionRepository connectionRepo,
    required AccountRepository accountRepo,
    required TransactionRepository transactionRepo,
    required SecureStorageService secureStorage,
  });

  /// Set up a new connection: claim access URL, store it, create DB row.
  /// Order: store token first → then create DB row (crash-safe).
  Future<String> setupConnection({
    required String setupToken,
    required String displayLabel,
  });

  /// Sync one connection: fetch account set, upsert accounts,
  /// insert new transactions (dedup by accountId + externalId).
  Future<SyncResult> syncConnection(String connectionId);

  /// Sync all active connections independently.
  /// Returns per-connection results. One failure doesn't block others.
  Future<Map<String, SyncResult>> syncAll();

  /// Delete connection: remove DB row, delete token from secure storage,
  /// optionally delete associated accounts/transactions.
  Future<void> deleteConnection(String connectionId, {bool keepHistory = false});
}
```

**Sync logic for `syncConnection`:**
1. Read access URL from secure storage by connection ID
2. Read `lastSyncCursor` from connection — use as `startDate` (or null for first sync)
3. Call `SimplefinClient.fetchAccountSet(accessUrl, startDate: lastSyncCursor)`
4. Surface any `errors` from the response (log + update connection status if needed)
5. For each account in response:
   - Upsert into `Accounts` table: match by `(bankConnectionId, externalId)`. Create if new, update balance/name if existing.
   - Set `institutionName` from `org.name`, `accountType` inferred from account metadata
6. For each transaction in each account:
   - Build composite dedup key: check `existsByExternalIdAndAccount(externalId, accountId)`
   - Skip if exists, insert if new
   - Map `amount` to integer cents, `posted` to date, `description`/`payee` to payee field
7. Update connection: `lastSyncedAt = now`, `lastSyncCursor = max(transaction dates)`, `status = 'connected'`
8. On error: update `status = 'error'`, store `errorMessage`. On 403: `status = 'reauth_required'`. On 402: `status = 'subscription_lapsed'`.

### 5. Provider wiring

**`core/di/providers.dart`** — add:
```
dioProvider → Dio instance
simplefinClientProvider → SimplefinClient(dio)
bankConnectionRepositoryProvider → BankConnectionRepository(db)
bankSyncServiceProvider → BankSyncService(client, repos, secureStorage)
```

**`presentation/features/bank_connections/bank_connections_providers.dart`** — add:
```
bankConnectionsProvider — autoDispose stream of all connections
syncConnectionProvider(id) — trigger sync, return AsyncValue<SyncResult>
setupConnectionProvider — handle setup flow
```

### 6. Secure storage changes

In `SecureStorageService`:
- Replace single-token methods with per-connection methods:
  - `getSimplefinAccessUrl(String connectionId)`
  - `setSimplefinAccessUrl(String connectionId, String accessUrl)`
  - `clearSimplefinAccessUrl(String connectionId)`
- Add `clearAllSimplefinAccessUrls(List<String> connectionIds)` for reset flow
- Remove old `getSimplefinToken()` / `setSimplefinToken()` / `getSimplefinSetupUrl()` (unused)

### 7. Transaction dedup fix

In `TransactionRepository`, change:
```dart
// Before: global lookup
Future<bool> existsByExternalId(String externalId)

// After: scoped to account
Future<bool> existsByExternalIdAndAccount(String externalId, String accountId)
```

Keep the old method for backward compat if other code uses it, or remove if unused.

### 8. UI — Bank Connections screen

New route: `/settings/bank-connections` (sub-route under settings tab).

**List view:**
- Each connection shows: displayLabel, status badge, last synced time, account count
- Per-connection actions: Sync Now, Edit Label, Delete

**Add connection flow:**
- Enter SimpleFIN setup token (or claim URL)
- App exchanges for access URL
- User enters display label
- First sync runs automatically
- Show discovered accounts

**Settings tile update:**
- Wire the existing "Bank Connections" ListTile in settings_screen.dart to navigate to this screen

### 9. Account list changes

Since all accounts come from sync:
- Remove "Add Account" FAB (or repurpose to "Add Connection")
- Show connection label as subtitle for each account (e.g., "via Chase - Mortgage")
- Show last synced timestamp
- Synced fields (name, balance, type) are read-only — editable fields: displayOrder, color, icon, isHidden

## What Does NOT Change

- `Transactions` table schema (externalId field already exists)
- Dashboard / reports (they aggregate all accounts regardless of source)
- Category system
- PIN auth / auto-lock
- Router structure (just adding one sub-route)

## Verification Criteria

1. Can create two BankConnections with the same institutionName ("Chase") and different labels
2. Each connection has its own access URL in secure storage
3. Syncing connection A does not affect connection B
4. Accounts from connection A have bankConnectionId pointing to A
5. Transaction dedup uses (accountId, externalId) — same transaction ID on different accounts both get imported
6. Deleting a connection cleans up its secure storage token
7. Connection with status 'error' doesn't block syncing other connections
8. UI clearly shows which connection each account belongs to
9. Rate limiting: don't sync more than once per connection per hour (upstream data only refreshes daily)

## Implementation Order

1. Schema migration (displayLabel, lastSyncCursor, unique index, FK)
2. SimpleFIN DTOs + client
3. BankConnectionRepository
4. Secure storage per-connection methods
5. Transaction dedup fix (scope to account)
6. BankSyncService
7. Provider wiring
8. Bank Connections screen + route
9. Account list UI updates (read-only synced fields, connection labels)
