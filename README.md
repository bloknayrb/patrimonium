# Patrimonium

Personal finance management app built with Flutter. Tracks accounts, transactions, budgets, and provides AI-assisted insights. Targets Android and Linux desktop.

## Status

- **Accounts & transactions**: Working. CRUD for 18 account types, transaction filtering/search, category hierarchy, CSV export.
- **Dashboard**: Net worth, cash flow, budget health, recent transactions.
- **Auth**: PIN login (PBKDF2-hashed), biometric unlock, auto-lock on background.
- **Not yet built**: Bank sync (SimpleFIN), CSV/OFX import, budgets, recurring transactions, goals, investment tracking, AI assistant backend, Supabase sync.

## Requirements

- Flutter 3.38+
- Android SDK or Linux desktop toolchain
- No web support (`dart:ffi` dependency)

## Setup

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Build & Run

```bash
# Run on connected device/emulator
flutter run

# Android
flutter build apk --debug
flutter build apk --release

# Linux desktop
flutter build linux
```

## Tests

```bash
flutter test
flutter test test/unit/some_test.dart  # single file
```

Test coverage is minimal. Only a placeholder smoke test exists.

## Analysis

```bash
flutter analyze
```

## Code Generation

After changing any Drift table definition in `lib/data/local/database/app_database.dart`:

```bash
dart run build_runner build --delete-conflicting-outputs
```

## Project Layout

```
lib/
├── core/           # Config, DI (Riverpod providers), errors, extensions, routing, theme
├── data/           # Drift database (21 tables), secure storage, repositories
├── domain/         # Use cases: PIN auth, biometrics, category seeding, CSV export
├── presentation/   # Screens and widgets organized by feature
├── app.dart        # Root MaterialApp, auto-lock lifecycle observer
└── main.dart       # Database init, category seeding, ProviderScope
```

## Architecture

Three-layer clean architecture:

- **data/** — Drift SQLite database, `flutter_secure_storage`, repository implementations
- **domain/** — Business logic services (PIN hashing, biometrics, export)
- **presentation/** — Screens, Riverpod providers, widgets

State management uses manual Riverpod providers (not `riverpod_generator`). Feature providers use `.autoDispose`. GoRouter handles navigation with auth-aware redirects.

## Conventions

- All money stored as **integer cents** (e.g., `$123.45` = `12345`). No floating point.
- Expenses are **negative**, income is **positive**.
- Primary keys are text UUIDs.
- Timestamps are integer Unix milliseconds.

## Dependencies

| Area | Packages |
|------|----------|
| State | flutter_riverpod |
| Database | drift, sqlite3_flutter_libs |
| Routing | go_router |
| HTTP | dio |
| Charts | fl_chart |
| Security | flutter_secure_storage, local_auth, crypto |
| Theme | dynamic_color |
| Testing | mocktail |
