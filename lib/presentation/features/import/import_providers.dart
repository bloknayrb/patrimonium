import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/local/database/app_database.dart';

/// Watch all import history records, most recent first.
final importHistoryProvider =
    StreamProvider.autoDispose<List<ImportHistoryData>>((ref) {
  return ref.watch(importRepositoryProvider).watchImportHistory();
});
