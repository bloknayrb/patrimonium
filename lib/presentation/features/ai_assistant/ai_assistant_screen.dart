import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/empty_states/empty_state_widget.dart';

/// AI Assistant chat screen — placeholder until LLM backend is wired.
class AiAssistantScreen extends ConsumerWidget {
  const AiAssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Assistant'),
      ),
      body: const EmptyStateWidget(
        icon: Icons.smart_toy,
        title: 'Coming Soon',
        description:
            'Your personal financial assistant is on the way. '
            'Configure an LLM provider in Settings once this feature is ready.',
      ),
    );
  }
}
