import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:go_router/go_router.dart';

import 'core/constants/app_constants.dart';
import 'core/di/providers.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';

/// Provider for the current theme mode.
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// Provider for the app router (needs Ref for auth redirect logic).
final appRouterProvider = Provider<GoRouter>((ref) {
  return createAppRouter(ref);
});

/// Whether the app is currently unlocked (past the lock screen).
final isUnlockedProvider = StateProvider<bool>((ref) => false);

/// Tracks the last time the app was paused (backgrounded).
final lastPausedAtProvider = StateProvider<DateTime?>((ref) => null);

/// Root application widget.
class PatrimoniumApp extends ConsumerWidget {
  const PatrimoniumApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final router = ref.watch(appRouterProvider);

    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          title: AppConstants.appName,
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: AppTheme.light(lightDynamic),
          darkTheme: AppTheme.dark(darkDynamic),
          routerConfig: router,
          builder: (context, child) {
            return _AutoLockObserver(child: child ?? const SizedBox.shrink());
          },
        );
      },
    );
  }
}

/// Observes app lifecycle to auto-lock after the configured timeout.
class _AutoLockObserver extends ConsumerStatefulWidget {
  final Widget child;

  const _AutoLockObserver({required this.child});

  @override
  ConsumerState<_AutoLockObserver> createState() => _AutoLockObserverState();
}

class _AutoLockObserverState extends ConsumerState<_AutoLockObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    final isUnlocked = ref.read(isUnlockedProvider);
    if (!isUnlocked) return; // Only track if app is unlocked

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      // App went to background — record the time
      ref.read(lastPausedAtProvider.notifier).state = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      // App came back — check if timeout has elapsed
      _checkAutoLock();
    }
  }

  Future<void> _checkAutoLock() async {
    final lastPaused = ref.read(lastPausedAtProvider);
    if (lastPaused == null) return;

    final timeoutSeconds =
        await ref.read(secureStorageProvider).getAutoLockTimeoutSeconds();
    final elapsed = DateTime.now().difference(lastPaused);

    if (elapsed.inSeconds >= timeoutSeconds) {
      // Lock the app
      ref.read(isUnlockedProvider.notifier).state = false;
      ref.read(lastPausedAtProvider.notifier).state = null;

      // Navigate to lock screen
      final router = ref.read(appRouterProvider);
      router.go(AppRoutes.lock);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
