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
- **SimpleFIN provides investment holdings** (undocumented): `symbol`, `shares`, `cost_basis`, `market_value` for brokerage accounts. Not in the formal spec — could change without notice.

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

**Modify `InvestmentHoldings`:**
- Make `symbol` nullable — 401k/CIT funds often have no ticker symbol
- Add `description` TEXT nullable — fund name for tickerless holdings
- Add `proxySymbol` TEXT nullable — optional equivalent public fund symbol for price tracking

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
  final List<SimplefinHolding>? holdings;  // undocumented, brokerage only
}

class SimplefinTransaction {
  final String id;           // unique per-account only
  final int posted;          // Unix epoch (0 = pending)
  final String amount;       // decimal string
  final String description;
  final String? payee;
  final String? memo;
}

class SimplefinHolding {
  final String id;
  final String? symbol;
  final String description;
  final String shares;       // decimal string
  final String? costBasis;   // decimal string
  final String? marketValue; // decimal string
  final String currency;
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
   - If holdings are present, upsert into `InvestmentHoldings`: match by `(accountId, symbol/id)`. Map `shares` → `quantity`, `cost_basis` → `costBasisCents`, `market_value` → `currentValueCents`.
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

1. Schema migration (displayLabel, lastSyncCursor, unique index, FK, InvestmentHoldings changes)
2. SimpleFIN DTOs + client
3. BankConnectionRepository
4. Secure storage per-connection methods
5. Transaction dedup fix (scope to account)
6. BankSyncService (including holdings sync)
7. Provider wiring
8. Bank Connections screen + route
9. Account list UI updates (read-only synced fields, connection labels)

---

# Cross-Cutting Research: Phase 3 Feature Findings

Research conducted across all planned Phase 3 features to identify incorrect assumptions, protocol mismatches, and schema gaps before implementation.

## CSV/OFX Import

### Key Findings

- **OFX 1.x (SGML) vs 2.x (XML)**: Must handle both. Many banks still export 1.x which has no closing tags. Need a pre-processor to convert SGML → valid XML before parsing.
- **QFX = OFX + Intuit tags**: Treat `.qfx` identically to `.ofx`. Ignore `<INTU.*>` tags.
- **FITID is unreliable for dedup**: Spec says unique per account, but some banks change FITIDs between downloads or assign non-unique ones. Need fallback composite key (`date + amount + payee hash`).
- **CSV has no standard format**: Every bank exports differently. Need a column-mapping UI, not auto-detection. Save mappings per bank for reuse.
- **No good Dart OFX package**: The `ofx` package on pub.dev likely only handles 2.x. Will need a custom SGML pre-processor or port from Python's `ofxtools`.

### Gotchas

- **OFX date timezone trap**: Dates without timezone default to GMT, causing off-by-one-day errors for US users. Treat date-only values as noon GMT.
- **Amount signs**: OFX `TRNAMT` sign determines direction (positive = inflow, negative = outflow), regardless of `TRNTYPE`. Maps directly to the app's negative-cents-for-expenses convention.
- **CSV ambiguities**: Date format (`01/02/2024` — Jan 2 or Feb 1?), negative amounts (`-45.00` vs `(45.00)` vs `45.00-`), BOM in UTF-8 files from Excel, locale-dependent decimal separators.
- **Encoding**: Some OFX files declare CP1252 but contain UTF-8 (or vice versa). Read as bytes and detect encoding rather than trusting headers.
- **SGML parsing traps**: Unescaped ampersands in payee names (`AT&T`), self-closing XML tags in SGML files, commas as decimal separators from European banks.

### Schema Impact

- Transaction dedup needs a fallback composite key for OFX import (not just `externalId`).

## Supabase Sync

### Key Findings

- **No official offline-first solution**: Must build custom sync engine or use third-party (PowerSync, Brick). PowerSync conflicts with Drift (uses its own SQLite). Brick or custom is more compatible with keeping Drift as the local layer.
- **Supabase Realtime is NOT a sync engine**: It's a signal layer for live WebSocket subscriptions. Doesn't deliver initial state, doesn't queue offline, loses events during disconnection. Useful only as "something changed, trigger a pull."
- **LWW with version field works**: Since this is a single-user app, true conflicts are rare. Last-write-wins with `modified_at` timestamp is sufficient. Keep `version` as an extra safety check.
- **SyncState table approach is correct**: Per-row `syncStatus` + entity operation tracking is the standard pattern. Push local changes before pulling remote.

### Critical Requirements

- **Soft deletes required**: Hard deletes can't be synced. Need `isDeleted BOOL` + `deletedAt INT` on all synced tables. This is a schema change that should be planned now even if Supabase isn't wired yet.
- **`user_id` on every Supabase table**: Required for RLS. Index it. Use `(SELECT auth.uid())` pattern for query optimization.
- **Timestamp conversion at sync boundary**: App uses Unix ms integers, Supabase uses `timestamptz`. Convert in Dart — no local schema changes needed.
- **`supabase_flutter` coexists with Drift**: No known conflicts. They occupy different layers.

### Schema Impact

- All synced tables will eventually need `isDeleted` BOOL and `deletedAt` INT columns. Consider adding these proactively.

## LLM Integration (Claude/OpenAI/Ollama)

### Key Findings

- **No official Dart SDKs** from Anthropic or OpenAI. Best unified option: `llm_dart` package (pub.dev) — covers Claude, OpenAI, Ollama with streaming, tool calling, type-safe API. Alternative: individual community packages (`anthropic_sdk_dart`, `openai_dart`).
- **API format mismatch**: Claude uses separate `system` field + strict message alternation + required `max_tokens`. OpenAI/Ollama are mutually compatible. Need an abstraction layer (or `llm_dart` handles this).
- **All three support SSE streaming**: Use `llm_dart` built-in streams. Avoid raw Dio for SSE (known issues with Dio's SSE support).

### Ollama on Android

- **Requires `network_security_config.xml`** for cleartext HTTP to localhost (Android 9+ blocks it by default). Must whitelist `localhost`, `127.0.0.1`, `10.0.2.2` (emulator).
- **On-device performance is poor**: Only practical for small models (7B). Most users will run Ollama on a LAN server. App should accept arbitrary `host:port`.

### Cost Control for Automated Insights

- Use haiku/mini-tier models (~$0.001-0.004 per insight).
- **Pre-compute all math in Dart** — send only summaries to LLM for narrative generation. Don't let the LLM do arithmetic.
- Use prompt caching (90% discount on repeated system prompts).
- Generate insights on a schedule (daily/weekly), not on every app open.
- Offer Ollama as free tier for cost-conscious users.

### Schema Impact

- No schema changes needed. Existing `Conversations`, `Messages`, `AiMemoryCore`, `AiMemorySemantic` tables are adequate.

## Investment Holdings

### Key Findings

- **SimpleFIN DOES provide holdings** (undocumented): Returns `symbol`, `shares`, `cost_basis`, `market_value` for brokerage accounts via MX backend. This means `InvestmentHoldings` can be populated from SimpleFIN — no separate integration needed for basic holdings.
- **IEX Cloud is DEAD** (shut down Aug 2024). Do not plan around it.
- **Price update APIs**: Finnhub (60 req/min free, best for daily updates) or Alpha Vantage (25 req/day free, best data quality). Both callable via `dio` directly — no Dart package needed.
- **OFX investment statements are dying**: Schwab discontinued, Fidelity transitioning away, Vanguard broken. Skip OFX/INVSTMTMSGSRSV1 parsing entirely.

### 401k/CIT Fund Problem

- Many 401k plans use Collective Investment Trusts or private share classes with no public ticker symbol.
- **Make `symbol` nullable**. Support manual price entry. Add optional `proxySymbol` field for equivalent public fund tracking.
- SimpleFIN/Plaid may return `market_value` even without a ticker — calculate implied price from `market_value / shares`.

### Schema Impact

- `InvestmentHoldings.symbol` must become nullable (currently non-null TEXT).
- Add `description` TEXT nullable for fund names.
- Add `proxySymbol` TEXT nullable for proxy tracking.

## Recurring Detection + Auto-Categorization

### Key Findings

- **Exact payee+amount matching is insufficient.** Bank payee strings contain noise (dates, store numbers, reference codes). Need fuzzy/normalized matching.
- **No open-source payee→category database exists.** The mapping must be built from user behavior, seeded with a hand-curated list of common merchants.

### Payee Normalization Pipeline

1. **Regex strip**: Remove dates (`\d{6}`), card numbers (`\d{4,}`), common suffixes (`AUTOPAY`, `PURCHASE`, `POS`), store numbers (`#\d+`)
2. **Trim and collapse whitespace**
3. **Fuzzy match** against known payees using `fuzzywuzzy` Dart package (`tokenSetRatio` handles word reordering and partial matches)
4. **Store user corrections** as rules for future matching

### Frequency Detection

- **Monthly tolerance: +/- 5 days** (23-36 day intervals)
- Use **median** of inter-transaction intervals (robust to outliers), not mean
- Require **3+ occurrences** before classifying as recurring
- Buckets: weekly (7d ±2), biweekly (14d ±3), monthly (30d ±5), quarterly (91d ±10), annual (365d ±15)

### Auto-Categorization Pattern

Priority-ordered rules evaluated in sequence (most specific wins) is the standard approach. Matches what YNAB, Actual Budget, and Mint all do.

### Schema Impact

- `PayeeCategoryCache` needs additional fields for proper confidence scoring:
  - `hitCount` INT — times this payee was categorized to this category
  - `missCount` INT — times this payee was categorized to a different category
  - `lastUsedAt` INT — for recency weighting
- Confidence thresholds: >=0.95 auto-apply silently, 0.80-0.94 auto-apply + flag for review, <0.80 require manual categorization.

## Summary: All Schema Changes Needed

| Table | Change | Reason |
|-------|--------|--------|
| `BankConnections` | Add `displayLabel` TEXT nullable | User disambiguation |
| `BankConnections` | Add `lastSyncCursor` INT nullable | Incremental sync |
| `Accounts` | Add unique index on `(bankConnectionId, externalId)` | Prevent duplicate synced accounts |
| `Accounts` | Add real FK `bankConnectionId` → `BankConnections.id` ON DELETE SET NULL | Data integrity |
| `InvestmentHoldings` | Make `symbol` nullable | 401k/CIT funds have no ticker |
| `InvestmentHoldings` | Add `description` TEXT nullable | Fund name for tickerless holdings |
| `InvestmentHoldings` | Add `proxySymbol` TEXT nullable | Proxy tracking |
| `PayeeCategoryCache` | Add `hitCount` INT, `missCount` INT, `lastUsedAt` INT | Confidence scoring |
| All synced tables (future) | Add `isDeleted` BOOL, `deletedAt` INT | Supabase sync requires soft deletes |
