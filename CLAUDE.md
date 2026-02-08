# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build & Development Commands

```bash
# Flutter SDK location (Windows)
C:\dev\flutter\bin\flutter

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

## Architecture

Clean Architecture with three layers: `data/` (database, storage, repositories), `domain/` (use cases, business logic), `presentation/` (screens, providers, widgets).

### Provider Wiring Pattern

The app uses **manual Riverpod providers** (NOT riverpod_generator — it conflicts with `analyzer_plugin`). The dependency chain is:

1. `databaseProvider` — created in `main.dart` via `AppDatabase.open()`, overridden in `ProviderScope`
2. Repository providers (`accountRepositoryProvider`, etc.) in `core/di/providers.dart` — depend on `databaseProvider`
3. Feature-level providers in each feature's `*_providers.dart` file — depend on repository providers
4. Screens consume feature providers via `ref.watch()`

### Database (Drift)

- 21 tables defined in `data/local/database/app_database.dart` with generated code in `app_database.g.dart`
- **All money values are integer cents** (`$123.45` = `12345`). Never use floating point for money.
- **Primary keys are TEXT UUIDs** (generated with `uuid` package)
- **Timestamps are INTEGER Unix milliseconds** (`DateTime.now().millisecondsSinceEpoch`)
- Drift `.insert()` companion constructors take raw types (e.g., `String id`), while update companions use `Value<T>` wrappers
- After changing any table schema, run `dart run build_runner build --delete-conflicting-outputs`

### Routing

GoRouter with `StatefulShellRoute.indexedStack` for 5-tab bottom navigation. Auth-aware redirect in `core/router/app_router.dart` checks PIN state:
- No PIN set → redirect to `/pin-setup`
- PIN set + on setup page → redirect to `/lock`

The router is created via `createAppRouter(Ref ref)` (needs Ref for auth state checks).

### Security

- PIN hashing: PBKDF2-HMAC-SHA256, 256k iterations, 256-bit salt (`domain/usecases/auth/pin_service.dart`)
- Credentials stored via `flutter_secure_storage` (Android Keystore / Linux libsecret)
- `SecureStorageService` wraps all key names — SimpleFIN tokens, LLM API keys, Supabase sessions

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
- **Account types**: 18 types defined in `core/constants/account_types.dart` with `AccountTypeInfo` metadata and `accountTypeGroups` for UI grouping (re-exported from `accounts_providers.dart`).
- **Expenses stored as negative cents**: Income is positive, expenses are negative in `amountCents`.

## Current Status

- **Phase 1 (Foundation)**: Complete — database, auth, theme, repositories, routing, settings
- **Phase 2 (Accounts & Transactions)**: Complete — accounts CRUD, transactions CRUD, dashboard with real data, category picker
- **Phase 3 (Bank Connectivity & Data Import)**: Next up — SimpleFIN integration, CSV/OFX import
