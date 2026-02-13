import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/error/app_error.dart';
import '../../../core/router/app_router.dart';

/// Wizard screen for claiming a SimpleFIN setup token.
class SimplefinSetupScreen extends ConsumerStatefulWidget {
  const SimplefinSetupScreen({super.key});

  @override
  ConsumerState<SimplefinSetupScreen> createState() =>
      _SimplefinSetupScreenState();
}

class _SimplefinSetupScreenState extends ConsumerState<SimplefinSetupScreen> {
  final _tokenController = TextEditingController();
  int _currentStep = 0;
  bool _isLoading = false;
  String? _errorMessage;
  String? _connectionId;
  String _institutionName = '';

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _claimToken() async {
    final token = _tokenController.text.trim();
    if (token.isEmpty) return;

    setState(() {
      _currentStep = 1;
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final syncService = ref.read(simplefinSyncServiceProvider);
      final connectionId = await syncService.claimAndConnect(token);

      // Get institution name from the connection
      final connectionRepo = ref.read(bankConnectionRepositoryProvider);
      final connection = await connectionRepo.getConnectionById(connectionId);

      // Auto-enable background sync on first connection
      final storage = ref.read(secureStorageProvider);
      await storage.setAutoSyncEnabled(true);
      final syncManager = ref.read(backgroundSyncManagerProvider);
      await syncManager.register(syncCallback: () async {});

      setState(() {
        _connectionId = connectionId;
        _institutionName = connection?.institutionName ?? 'Your Bank';
        _isLoading = false;
        _currentStep = 2;
      });
    } on AppError catch (e) {
      setState(() {
        _errorMessage = e.message;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Connection failed. Please check your token and try again.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connect Bank')),
      body: Stepper(
        currentStep: _currentStep,
        controlsBuilder: (context, details) => const SizedBox.shrink(),
        steps: [
          // Step 1: Enter Token
          Step(
            title: const Text('Enter Setup Token'),
            isActive: _currentStep >= 0,
            state: _currentStep > 0 ? StepState.complete : StepState.indexed,
            content: _buildTokenStep(),
          ),

          // Step 2: Claiming
          Step(
            title: const Text('Connecting'),
            isActive: _currentStep >= 1,
            state: _currentStep > 1
                ? StepState.complete
                : _currentStep == 1
                    ? StepState.indexed
                    : StepState.disabled,
            content: _buildClaimingStep(),
          ),

          // Step 3: Success
          Step(
            title: const Text('Connected'),
            isActive: _currentStep >= 2,
            state: _currentStep == 2 ? StepState.complete : StepState.disabled,
            content: _buildSuccessStep(),
          ),
        ],
      ),
    );
  }

  Widget _buildTokenStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SimpleFIN connects to 11,000+ bank institutions and provides '
          'automatic account balance and transaction syncing.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 8),
        Text(
          'Get a setup token from simplefin.org (\$1.50/month), '
          'then paste it below.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _tokenController,
          decoration: const InputDecoration(
            labelText: 'Setup Token',
            hintText: 'Paste your base64 setup token here',
          ),
          maxLines: 2,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _tokenController.text.trim().isNotEmpty ? _claimToken : null,
          child: const Text('Connect'),
        ),
      ],
    );
  }

  Widget _buildClaimingStep() {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _currentStep = 0;
                _errorMessage = null;
              });
            },
            child: const Text('Try Again'),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildSuccessStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.check_circle,
          color: Theme.of(context).colorScheme.primary,
          size: 48,
        ),
        const SizedBox(height: 12),
        Text(
          'Successfully connected to $_institutionName!',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        const Text('Link your bank accounts to start syncing transactions.'),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(Icons.sync, color: Theme.of(context).colorScheme.onPrimaryContainer),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Auto-sync enabled — accounts will sync every 8 hours.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton(
              onPressed: () {
                context.push('${AppRoutes.accountLinking}/$_connectionId');
              },
              child: const Text('Link Accounts'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: () => context.pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }
}
