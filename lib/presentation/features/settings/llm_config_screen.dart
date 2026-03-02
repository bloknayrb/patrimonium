import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../data/remote/dio_client.dart';
import '../../../data/remote/llm/llm_client.dart';

/// Screen for configuring the LLM provider (Claude, OpenAI, or Ollama).
class LlmConfigScreen extends ConsumerStatefulWidget {
  const LlmConfigScreen({super.key});

  @override
  ConsumerState<LlmConfigScreen> createState() => _LlmConfigScreenState();
}

class _LlmConfigScreenState extends ConsumerState<LlmConfigScreen> {
  String _selectedProvider = 'claude';
  final _apiKeyController = TextEditingController();
  final _ollamaUrlController = TextEditingController(text: 'http://localhost:11434');
  bool _obscureKey = true;
  bool _testing = false;
  String? _testResult;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final storage = ref.read(secureStorageProvider);
    final provider = await storage.getActiveLlmProvider();
    if (provider != null) {
      _selectedProvider = provider;
      final key = await storage.getLlmApiKey(provider);
      if (provider == 'ollama') {
        _ollamaUrlController.text = key ?? 'http://localhost:11434';
      } else {
        _apiKeyController.text = key ?? '';
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _ollamaUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('LLM Provider')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('LLM Provider')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Provider selector
          Text(
            'Provider',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'claude', label: Text('Claude')),
              ButtonSegment(value: 'openai', label: Text('OpenAI')),
              ButtonSegment(value: 'ollama', label: Text('Ollama')),
            ],
            selected: {_selectedProvider},
            onSelectionChanged: (selected) {
              setState(() {
                _selectedProvider = selected.first;
                _testResult = null;
              });
              // Load existing key for this provider
              _loadKeyForProvider(selected.first);
            },
          ),

          const SizedBox(height: 24),

          // API key or URL field
          if (_selectedProvider == 'ollama') ...[
            TextField(
              controller: _ollamaUrlController,
              decoration: const InputDecoration(
                labelText: 'Ollama URL',
                hintText: 'http://localhost:11434',
                helperText: 'On Android, use your machine\'s LAN IP instead of localhost',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
            ),
          ] else ...[
            TextField(
              controller: _apiKeyController,
              decoration: InputDecoration(
                labelText: '${_selectedProvider == 'claude' ? 'Anthropic' : 'OpenAI'} API Key',
                hintText: _selectedProvider == 'claude'
                    ? 'sk-ant-api03-...'
                    : 'sk-...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                  onPressed: () => setState(() => _obscureKey = !_obscureKey),
                ),
              ),
              obscureText: _obscureKey,
            ),
          ],

          const SizedBox(height: 16),

          // Test connection button
          OutlinedButton.icon(
            onPressed: _testing ? null : _testConnection,
            icon: _testing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.wifi_tethering),
            label: Text(_testing ? 'Testing...' : 'Test Connection'),
          ),

          // Test result
          if (_testResult != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _testResult == 'success' ? Icons.check_circle : Icons.error,
                  color: _testResult == 'success' ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _testResult == 'success'
                        ? 'Connection successful!'
                        : _testResult!,
                    style: TextStyle(
                      color: _testResult == 'success' ? Colors.green : Colors.red,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Save button
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _loadKeyForProvider(String provider) async {
    final storage = ref.read(secureStorageProvider);
    final key = await storage.getLlmApiKey(provider);
    if (provider == 'ollama') {
      _ollamaUrlController.text = key ?? 'http://localhost:11434';
    } else {
      _apiKeyController.text = key ?? '';
    }
  }

  String get _currentKeyOrUrl {
    return _selectedProvider == 'ollama'
        ? _ollamaUrlController.text.trim()
        : _apiKeyController.text.trim();
  }

  Future<void> _testConnection() async {
    final keyOrUrl = _currentKeyOrUrl;
    if (keyOrUrl.isEmpty) {
      setState(() => _testResult = 'Please enter ${_selectedProvider == 'ollama' ? 'a URL' : 'an API key'}');
      return;
    }

    setState(() {
      _testing = true;
      _testResult = null;
    });

    try {
      final client = createLlmClient(_selectedProvider, keyOrUrl, createLlmDioClient());
      final error = await client.testConnection();
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = error ?? 'success';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _testing = false;
          _testResult = e.toString();
        });
      }
    }
  }

  Future<void> _save() async {
    final keyOrUrl = _currentKeyOrUrl;
    if (keyOrUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enter ${_selectedProvider == 'ollama' ? 'a URL' : 'an API key'}'),
        ),
      );
      return;
    }

    final storage = ref.read(secureStorageProvider);
    await storage.setLlmApiKey(_selectedProvider, keyOrUrl);
    await storage.setActiveLlmProvider(_selectedProvider);

    // Invalidate providers so they pick up the new config
    ref.invalidate(llmClientProvider);
    ref.invalidate(activeLlmProviderNameProvider);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('LLM provider saved')),
      );
      Navigator.of(context).pop();
    }
  }
}
