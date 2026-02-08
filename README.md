# Patrimonium

A personal finance management app built with Flutter, featuring local-first data storage, AI-powered insights, and bank connectivity.

## Features

- **PIN Security** — PBKDF2-HMAC-SHA256 hashed PIN with auto-lock on backgrounding
- **Accounts** — Track 18 account types (checking, savings, credit card, investment, etc.) with full CRUD
- **Transactions** — Record income and expenses with category tagging, filtering, and search
- **Dashboard** — At-a-glance summary with charts (fl_chart) showing balances, spending trends, and recent activity
- **Categories** — 16 expense and 7 income parent categories with subcategories, seeded on first launch
- **Data Export** — CSV export for accounts and transactions
- **Material 3 Theming** — Dynamic color support with semantic finance colors (income=green, expense=red)
- **Offline-First** — All data stored locally in SQLite via Drift ORM

## Platforms

- Android
- Linux desktop

> Web builds are not supported due to a `dart:ffi` dependency (sqlite3).

## Architecture

Clean Architecture with three layers:

```
lib/
├── core/          # Constants, DI (Riverpod), extensions, routing (GoRouter), theme
├── data/          # Drift database, repositories, secure storage
├── domain/        # Use cases, business logic, auth
└── presentation/  # Screens, providers, shared widgets
```

**State Management**: Manual Riverpod providers (not riverpod_generator).
**Database**: Drift with 21 tables — money as integer cents, UUIDs for PKs, Unix ms for timestamps.
**Routing**: GoRouter with `StatefulShellRoute.indexedStack` for 5-tab bottom navigation.

See [CLAUDE.md](CLAUDE.md) for detailed architecture documentation, build commands, and development conventions.

## Status

```bash
# Install dependencies
flutter pub get

# Run code generation (Drift)
dart run build_runner build --delete-conflicting-outputs

# Run the app
flutter run

# Run tests
flutter test

# Build release APK
flutter build apk --release
```

## Project Status

| Phase | Status | Description |
|-------|--------|-------------|
| Phase 1 — Foundation | Complete | Database, auth, theme, repositories, routing, settings |
| Phase 2 — Accounts & Transactions | Complete | Accounts CRUD, transactions CRUD, dashboard, category picker |
| Phase 3 — Bank Connectivity | Next | SimpleFIN integration, CSV/OFX import |

## Development Guidelines

Development conventions, testing patterns, performance guidelines, and deployment checklists are documented in [CLAUDE.md](CLAUDE.md). Key points:

- All money values are **integer cents** (never floating point)
- Expenses are stored as **negative** `amountCents`
- Use `flutter analyze` to check for lint issues before committing
- Run `dart run build_runner build --delete-conflicting-outputs` after changing Drift table schemas

## Acknowledgments

Flutter development guidelines in this project were informed by [flutter-claude-code](https://github.com/cleydson/flutter-claude-code) by [@cleydson](https://github.com/cleydson) — a comprehensive Flutter development ecosystem with specialized agent patterns covering architecture, testing, performance optimization, security, API integration, and deployment best practices.
