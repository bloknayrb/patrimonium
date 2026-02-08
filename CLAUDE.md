# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Patrimonium** is a personal finance management app with AI-powered insights, built with Flutter targeting Android and Linux desktop.

## Coding Guidelines

Behavioral guidelines to reduce common LLM coding mistakes. These bias toward caution over speed — for trivial tasks, use judgment.

### Think Before Coding

Don't assume. Don't hide confusion. Surface tradeoffs.

- State assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### Simplicity First

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### Surgical Changes

Touch only what you must. Clean up only your own mess.

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### Goal-Driven Execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

### Anti-Patterns to Avoid

| Principle | Anti-Pattern | Fix |
|-----------|-------------|-----|
| Think Before Coding | Silently assumes file format, fields, scope | List assumptions explicitly, ask for clarification |
| Simplicity First | Strategy pattern for single calculation | One function until complexity is actually needed |
| Surgical Changes | Reformats quotes, adds type hints while fixing a bug | Only change lines that fix the reported issue |
| Goal-Driven | "I'll review and improve the code" | "Write test for bug X → make it pass → verify no regressions" |

"Overcomplicated" code isn't obviously wrong — it follows design patterns and best practices. The problem is **timing**: adding complexity before it's needed makes code harder to understand, introduces more bugs, takes longer to implement, and is harder to test. Good code solves today's problem simply, not tomorrow's problem prematurely.

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Build & Development Commands

```bash
# Get dependencies
flutter pub get

# Run Drift code generation (required after changing app_database.dart tables)
dart run build_runner build --delete-conflicting-outputs

# Analyze
flutter analyze

# Run all tests
flutter test

# Run a single test file
flutter test test/unit/some_test.dart

# Build for Android
flutter build apk --debug
flutter build apk --release

# Build for Linux desktop
flutter build linux

# Run on connected device/emulator
flutter run
```

## Project Structure

```
lib/
├── core/
│   ├── constants/          # App config, default category seeds
│   ├── di/                 # Riverpod providers (dependency injection)
│   ├── error/              # AppError sealed class hierarchy
│   ├── extensions/         # Money formatting, date helpers
│   ├── router/             # GoRouter with auth-aware redirects
│   └── theme/              # Material 3 theme + FinanceColors extension
├── data/
│   ├── local/
│   │   ├── database/       # Drift database (21 tables + generated code)
│   │   └── secure_storage/ # flutter_secure_storage wrapper
│   └── repositories/       # AccountRepository, TransactionRepository,
│                           # CategoryRepository, BudgetRepository
├── domain/
│   └── usecases/
│       ├── auth/           # PinService, BiometricService
│       ├── categories/     # CategorySeeder
│       └── export/         # CsvExportService
├── presentation/
│   ├── features/
│   │   ├── accounts/       # CRUD screens + accounts_providers.dart
│   │   ├── auth/           # LockScreen, PinSetupScreen
│   │   ├── dashboard/      # DashboardScreen (net worth, cash flow, etc.)
│   │   ├── transactions/   # CRUD screens + transactions_providers.dart
│   │   ├── ai_assistant/   # AiAssistantScreen (stub — no LLM backend yet)
│   │   ├── settings/       # SettingsScreen
│   │   └── onboarding/     # OnboardingScreen (first-launch welcome)
│   └── shared/
│       ├── widgets/        # AppShell (bottom nav), PinNumberPad
│       ├── loading/        # ShimmerLoading skeletons
│       └── empty_states/   # EmptyStateWidget
├── app.dart                # Root MaterialApp, auto-lock lifecycle observer
└── main.dart               # Database init, category seeding, ProviderScope
```

## Architecture

Clean Architecture with three layers:
- **`data/`** — database, secure storage, repository implementations
- **`domain/`** — use cases and business logic services
- **`presentation/`** — screens, Riverpod providers, widgets

### Provider Wiring Pattern

The app uses **manual Riverpod providers** (NOT riverpod_generator — it conflicts with `analyzer_plugin`). All feature-level providers use `.autoDispose` for memory efficiency. The dependency chain is:

1. `databaseProvider` — created in `main.dart` via `AppDatabase.open()`, overridden in `ProviderScope`
2. Repository providers (`accountRepositoryProvider`, etc.) in `core/di/providers.dart` — depend on `databaseProvider`
3. Feature-level providers in each feature's `*_providers.dart` file — depend on repository providers
4. Screens consume feature providers via `ref.watch()`

### Database (Drift)

21 tables defined in `data/local/database/app_database.dart` with generated code in `app_database.g.dart`.

**Core rules:**
- **All money values are integer cents** (`$123.45` = `12345`). Never use floating point for money.
- **Primary keys are TEXT UUIDs** (generated with `uuid` package)
- **Timestamps are INTEGER Unix milliseconds** (`DateTime.now().millisecondsSinceEpoch`)
- Drift `.insert()` companion constructors take raw types (e.g., `String id`), while update companions use `Value<T>` wrappers
- After changing any table schema, run `dart run build_runner build --delete-conflicting-outputs`
- Foreign keys are enabled; core tables have `version` and `syncStatus` fields

**Tables by category:**

| Category | Tables |
|----------|--------|
| **Financial** | `Accounts`, `Transactions`, `Categories`, `Budgets`, `Goals`, `InvestmentHoldings`, `RecurringTransactions` |
| **Connectivity** | `BankConnections`, `ImportHistory` |
| **Categorization** | `AutoCategorizeRules`, `PayeeCategoryCache`, `CategorizationCorrections` |
| **AI** | `Conversations`, `Messages`, `Insights`, `AiMemoryCore`, `AiMemorySemantic`, `InsightFeedback` |
| **Infrastructure** | `SyncState`, `AuditLog`, `AppSettings` |

### Routing

GoRouter with `StatefulShellRoute.indexedStack` for 5-tab bottom navigation. Auth-aware redirect in `core/router/app_router.dart` checks PIN state:
- No PIN set → redirect to `/pin-setup`
- PIN set + on setup page → redirect to `/lock`

Route constants are in `AppRoutes` class. Full-screen routes: `/lock`, `/pin-setup`, `/pin-change`, `/onboarding`. Tab routes: `/dashboard`, `/accounts`, `/transactions`, `/ai`, `/settings`.

The router is created via `createAppRouter(Ref ref)` (needs Ref for auth state checks).

### Security

- **PIN hashing**: PBKDF2-HMAC-SHA256, 256k iterations, 256-bit salt (`domain/usecases/auth/pin_service.dart`). Uses constant-time XOR comparison to prevent timing attacks.
- **Biometric auth**: Wraps `local_auth` plugin with availability checks and preference tracking (`domain/usecases/auth/biometric_service.dart`).
- **Credential storage**: `flutter_secure_storage` (Android Keystore / Linux libsecret). `SecureStorageService` wraps all key names — SimpleFIN tokens, LLM API keys, Supabase sessions.
- **Auto-lock**: `_AutoLockObserver` in `app.dart` monitors app lifecycle. Records pause time, checks elapsed duration on resume against configurable timeout (default 300s). Tracked via `isUnlockedProvider` and `lastPausedAtProvider`.

### Error Handling

Sealed class hierarchy in `core/error/app_error.dart`:
- `NetworkError` — timeouts, no connection, server errors
- `DatabaseError` — corruption, migration failures
- `AuthError` — invalid PIN, biometric failure, lockout, session expired
- `BankSyncError` — connection failed, re-auth required, rate limited, circuit open
- `LLMError` — API errors, timeouts, rate limits, invalid keys, Ollama not running
- `ImportError` — invalid format, parse failures (with row tracking)

`ErrorHandler.handle()` converts raw exceptions to user-friendly `AppError` instances.

### Theme

Material 3 with `dynamic_color` support. Custom `FinanceColors` theme extension provides semantic colors (income=green, expense=red, budget states). Access via `Theme.of(context).finance`.

### Money Extensions

`core/extensions/money_extensions.dart` provides:
- `int.toCurrency()` — `12345` → `"$123.45"`
- `int.toCurrencyValue()` — `12345` → `"123.45"` (no symbol)
- `String.toCents()` — `"123.45"` → `12345`
- `int.toDateTime()` — Unix ms to DateTime
- `DateTime.toRelative()` — "Today", "Yesterday", "Monday", or "Jan 15, 2026"

## Key Conventions

- **Targets**: Android + Linux desktop only. `dart:ffi` dependency means web builds fail.
- **Flutter 3.38+**: `DropdownButtonFormField` uses `initialValue` (not deprecated `value` parameter).
- **Category seeding**: `CategorySeeder` runs on first launch in `main.dart`, populating 16 expense + 7 income parent categories with subcategories.
- **Account types**: 18 types defined in `accounts_providers.dart` with `AccountTypeInfo` metadata and `accountTypeGroups` for UI grouping. Types: checking, savings, credit_card, brokerage, 401k, IRA, roth_ira, HSA, mortgage, auto_loan, student_loan, personal_loan, line_of_credit, real_estate, vehicle, crypto, other_asset, other_liability.
- **Expenses stored as negative cents**: Income is positive, expenses are negative in `amountCents`.
- **autoDispose providers**: All feature-level StreamProviders and FutureProviders use `.autoDispose` for memory efficiency. Core infrastructure providers (database, repositories) do not.
- **No CI/CD**: No GitHub Actions or CI pipeline is configured yet.

## Key Dependencies

| Category | Packages |
|----------|----------|
| **State** | flutter_riverpod, riverpod_annotation |
| **Database** | drift, sqlite3_flutter_libs |
| **Routing** | go_router |
| **HTTP** | dio |
| **Charts** | fl_chart |
| **Security** | flutter_secure_storage, local_auth, crypto |
| **Theme** | dynamic_color |
| **Serialization** | freezed_annotation, json_annotation |
| **Backend** | supabase_flutter (prepared, not yet wired) |
| **Monitoring** | sentry_flutter (imported, init TODO) |
| **Background** | workmanager |
| **Markdown** | flutter_markdown (for AI chat) |
| **Testing** | mocktail (no tests written yet beyond placeholder) |

Note: `riverpod_generator` and `riverpod_lint` are commented out in pubspec.yaml due to `analyzer_plugin` compatibility issues.

## Testing

Test coverage is minimal. Only `test/widget_test.dart` exists with a placeholder smoke test. Repositories, providers, screens, PIN hashing, and CSV export all lack test coverage. `mocktail` is available as a dev dependency for writing tests.

## Current Status

- **Phase 1 (Foundation)**: Complete — database (21 tables), PIN auth with PBKDF2, biometric auth, Material 3 theme, secure storage, error handling, routing with auth redirects, settings screen, auto-lock
- **Phase 2 (Accounts & Transactions)**: Complete — accounts CRUD (18 types), transactions CRUD with filtering/search, category hierarchy with seeding, dashboard (net worth, cash flow, budget health, recent transactions, AI insights cards), onboarding flow, CSV export, account detail with transaction history
- **Phase 3 (Bank Connectivity & Data Import)**: Next up — SimpleFIN integration, CSV/OFX import, auto-categorization rules engine, budget management, recurring transaction detection, goals tracking, investment holdings, AI assistant LLM integration, insights generation, Supabase sync
