import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/auto_categorize_repository.dart';
import '../../../data/repositories/category_repository.dart';
import 'default_rules_data.dart';

/// Seeds default auto-categorization rules for well-known merchants.
///
/// Runs once after category seeding. Looks up category IDs by name since
/// they are random UUIDs generated at runtime.
class RuleSeeder {
  RuleSeeder(this._categoryRepo, this._autoCatRepo);

  final CategoryRepository _categoryRepo;
  final AutoCategorizeRepository _autoCatRepo;

  static const _uuid = Uuid();

  /// Seed default rules if none exist, and backfill any new rules
  /// (e.g. investment rules) for existing users.
  ///
  /// Returns true if rules were seeded.
  Future<bool> seedIfEmpty() async {
    if (await _autoCatRepo.hasRules()) {
      return _backfillInvestmentRules();
    }

    final categories = await _categoryRepo.getAllCategories();

    // Build name → ID lookup. Parents are added first so they win on
    // duplicate names (e.g. "Insurance" exists as both a parent category
    // and a subcategory under Housing/Healthcare). Unique subcategory names
    // like "Utilities", "Gas", "Pharmacy" are unaffected.
    final catByName = <String, String>{};
    final parents = categories.where((c) => c.parentId == null);
    final children = categories.where((c) => c.parentId != null);
    for (final c in parents) {
      catByName.putIfAbsent(c.name, () => c.id);
    }
    for (final c in children) {
      catByName.putIfAbsent(c.name, () => c.id);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final rules = <AutoCategorizeRulesCompanion>[];
    var priority = 0;

    for (final (payeeContains, categoryName) in defaultMerchantMappings) {
      final categoryId = catByName[categoryName];
      if (categoryId == null) continue;

      rules.add(AutoCategorizeRulesCompanion.insert(
        id: _uuid.v4(),
        name: '$payeeContains → $categoryName',
        priority: priority++,
        categoryId: categoryId,
        payeeContains: Value(payeeContains),
        isEnabled: const Value(true),
        createdAt: now,
        updatedAt: now,
      ));
    }

    // Seed investment-specific rules (account type scoped)
    for (final (payeeContains, categoryName, accountType)
        in investmentMerchantMappings) {
      final categoryId = catByName[categoryName];
      if (categoryId == null) continue;

      rules.add(AutoCategorizeRulesCompanion.insert(
        id: _uuid.v4(),
        name: '$payeeContains → $categoryName ($accountType)',
        priority: priority++,
        categoryId: categoryId,
        payeeContains: Value(payeeContains),
        accountType: Value(accountType),
        isEnabled: const Value(true),
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (rules.isNotEmpty) {
      await _autoCatRepo.insertRules(rules);
    }

    return true;
  }

  /// Backfill missing investment rules for existing users.
  ///
  /// Uses set-based dedup: builds a set of existing (payeeContains, accountType)
  /// combos and only inserts rules that don't already exist. This is
  /// self-healing — any time investmentMerchantMappings grows, the next
  /// startup backfills only the missing entries.
  Future<bool> _backfillInvestmentRules() async {
    final existingRules = await _autoCatRepo.getEnabledRules();

    // Build set of existing investment rule signatures
    final existingKeys = <String>{};
    for (final r in existingRules) {
      if (r.accountType != null && r.payeeContains != null) {
        existingKeys.add('${r.payeeContains!.toUpperCase()}|${r.accountType}');
      }
    }

    // Check which mappings are missing before loading categories
    final missing = investmentMerchantMappings.where((m) =>
        !existingKeys.contains('${m.$1.toUpperCase()}|${m.$3}'));
    if (missing.isEmpty) return false;

    final categories = await _categoryRepo.getAllCategories();
    final catByName = <String, String>{};
    for (final c in categories) {
      catByName.putIfAbsent(c.name, () => c.id);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    var priority = existingRules.length;
    final rules = <AutoCategorizeRulesCompanion>[];

    for (final (payeeContains, categoryName, accountType) in missing) {
      final categoryId = catByName[categoryName];
      if (categoryId == null) continue;

      rules.add(AutoCategorizeRulesCompanion.insert(
        id: _uuid.v4(),
        name: '$payeeContains → $categoryName ($accountType)',
        priority: priority++,
        categoryId: categoryId,
        payeeContains: Value(payeeContains),
        accountType: Value(accountType),
        isEnabled: const Value(true),
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (rules.isEmpty) return false;
    await _autoCatRepo.insertRules(rules);
    return true;
  }
}
