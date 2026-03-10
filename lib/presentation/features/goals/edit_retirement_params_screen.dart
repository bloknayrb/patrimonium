import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/extensions/money_extensions.dart';
import '../../../data/local/database/app_database.dart';
import '../../shared/utils/snackbar_helpers.dart';

/// Focused edit screen for the 4 retirement parameters + desired income.
class EditRetirementParamsScreen extends ConsumerStatefulWidget {
  const EditRetirementParamsScreen({super.key, required this.goal});

  final Goal goal;

  @override
  ConsumerState<EditRetirementParamsScreen> createState() =>
      _EditRetirementParamsScreenState();
}

class _EditRetirementParamsScreenState
    extends ConsumerState<EditRetirementParamsScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _contributionController;
  late final TextEditingController _returnController;
  late final TextEditingController _volatilityController;
  late final TextEditingController _yearController;
  late final TextEditingController _incomeController;

  @override
  void initState() {
    super.initState();
    final g = widget.goal;
    _contributionController = TextEditingController(
      text: g.monthlyContributionCents?.toCurrencyValue() ?? '',
    );
    _returnController = TextEditingController(
      text: g.annualReturnBps != null
          ? (g.annualReturnBps! / 100).toStringAsFixed(1)
          : '',
    );
    _volatilityController = TextEditingController(
      text: g.annualVolatilityBps != null
          ? (g.annualVolatilityBps! / 100).toStringAsFixed(1)
          : '',
    );
    _yearController = TextEditingController(
      text: g.retirementYear?.toString() ?? '',
    );
    _incomeController = TextEditingController(
      text: g.desiredMonthlyIncomeCents?.toCurrencyValue() ?? '',
    );
  }

  @override
  void dispose() {
    _contributionController.dispose();
    _returnController.dispose();
    _volatilityController.dispose();
    _yearController.dispose();
    _incomeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final contributionCents = _contributionController.text.toCents() ?? 0;
    final returnBps = (double.parse(_returnController.text) * 100).round();
    final volBps = (double.parse(_volatilityController.text) * 100).round();
    final year = int.parse(_yearController.text);
    final incomeCents = _incomeController.text.toCents() ?? 0;

    // 25x rule: annual income * 25 = target
    final targetAmountCents = incomeCents * 12 * 25;

    final repo = ref.read(goalRepositoryProvider);
    await repo.updateGoal(GoalsCompanion(
      id: Value(widget.goal.id),
      monthlyContributionCents: Value(contributionCents),
      annualReturnBps: Value(returnBps),
      annualVolatilityBps: Value(volBps),
      retirementYear: Value(year),
      desiredMonthlyIncomeCents: Value(incomeCents),
      targetAmountCents: Value(targetAmountCents),
      updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
    ));

    if (mounted) {
      showSuccessSnackbar(context, 'Retirement plan updated');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Retirement Parameters')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _contributionController,
              decoration: const InputDecoration(
                labelText: 'Monthly Contribution',
                prefixText: '\$',
                helperText: 'How much you contribute each month',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final cents = v.toCents();
                if (cents == null || cents <= 0) return 'Must be positive';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _incomeController,
              decoration: const InputDecoration(
                labelText: 'Desired Monthly Retirement Income',
                prefixText: '\$',
                helperText: 'Target amount computed via 25x annual rule (4% withdrawal)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final cents = v.toCents();
                if (cents == null || cents <= 0) return 'Must be positive';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _yearController,
              decoration: const InputDecoration(
                labelText: 'Target Retirement Year',
                helperText: 'e.g. 2055',
              ),
              keyboardType: TextInputType.number,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final year = int.tryParse(v);
                if (year == null) return 'Enter a valid year';
                final current = DateTime.now().year;
                if (year <= current) return 'Must be in the future';
                if (year > current + 60) return 'Too far in the future';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _returnController,
              decoration: const InputDecoration(
                labelText: 'Expected Annual Return (%)',
                suffixText: '%',
                helperText: 'Real return after inflation (e.g. 4.5)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final val = double.tryParse(v);
                if (val == null) return 'Enter a valid number';
                if (val < 1 || val > 12) return '1%–12% range';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _volatilityController,
              decoration: const InputDecoration(
                labelText: 'Annual Volatility (%)',
                suffixText: '%',
                helperText: 'How much returns vary year-to-year (e.g. 15)',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Required';
                final val = double.tryParse(v);
                if (val == null) return 'Enter a valid number';
                if (val < 3 || val > 30) return '3%–30% range';
                return null;
              },
            ),
            const SizedBox(height: 16),
            _RiskToleranceGuide(),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RiskToleranceGuide extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Risk Tolerance Guide',
              style: theme.textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Conservative: 2.5% return, 8% volatility\n'
              'Moderate: 4.5% return, 15% volatility\n'
              'Aggressive: 6.5% return, 20% volatility\n\n'
              'All returns are real (inflation-adjusted).',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
