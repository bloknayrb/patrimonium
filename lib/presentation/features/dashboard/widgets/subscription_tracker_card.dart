import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder — will be implemented in Step 4.
class SubscriptionTrackerCard extends ConsumerWidget {
  const SubscriptionTrackerCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Text('Subscriptions — TODO'),
      ),
    );
  }
}
