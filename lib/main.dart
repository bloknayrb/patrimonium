import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/di/providers.dart';
import 'data/local/database/app_database.dart';
import 'data/repositories/category_repository.dart';
import 'domain/usecases/categories/category_seeder.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Open the database
  final database = await AppDatabase.open();

  // Seed default categories if this is a fresh install
  final categoryRepo = CategoryRepository(database);
  final seeder = CategorySeeder(categoryRepo);
  try {
    await seeder.seedIfEmpty();
  } catch (e) {
    if (kDebugMode) debugPrint('Category seeding failed: $e');
  }

  // TODO: Initialize Sentry
  // await SentryFlutter.init(
  //   (options) {
  //     options.dsn = 'YOUR_SENTRY_DSN';
  //     options.tracesSampleRate = 0.1;
  //   },
  //   appRunner: () => _runApp(database),
  // );

  _runApp(database);
}

void _runApp(AppDatabase database) {
  runApp(
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(database),
      ],
      child: const PatrimoniumApp(),
    ),
  );
}
