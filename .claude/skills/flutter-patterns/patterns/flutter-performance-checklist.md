---
name: flutter-performance-checklist
description: Pre-deployment performance checklist for Flutter apps. Comprehensive verification steps to ensure 60fps performance, optimized builds, and production readiness.
---

# Flutter Performance Checklist

Complete pre-deployment checklist to ensure optimal app performance.

## Build Performance

### ✅ Release Build Configuration

- [ ] Using `flutter build --release` (not debug)
- [ ] ProGuard/R8 enabled for Android (minifyEnabled true)
- [ ] Code shrinking enabled (shrinkResources true)
- [ ] Obfuscation configured (proguard-rules.pro)
- [ ] Tree shaking enabled (automatic in release builds)
- [ ] No debug logging in production
- [ ] No print statements (use logger with levels)

```dart
// ❌ Bad
print('Debug message');

// ✅ Good
import 'package:logger/logger.dart';
final logger = Logger();
logger.d('Debug message'); // Only in debug builds
```

### ✅ App Size Optimization

- [ ] APK/AAB size < 20MB (ideal)
- [ ] Remove unused assets
- [ ] Optimize image sizes (use appropriate resolutions)
- [ ] Use vector graphics (SVG) when possible
- [ ] Split APKs per ABI (--split-per-abi)
- [ ] Lazy load heavy dependencies
- [ ] Use deferred loading for large features

```dart
// Deferred loading
import 'package:heavy_feature.dart' deferred as heavy;

Future<void> loadHeavyFeature() async {
  await heavy.loadLibrary();
  heavy.showHeavyWidget();
}
```

## Widget Performance

### ✅ Const Constructors

- [ ] All static widgets use `const`
- [ ] Text widgets with static text are const
- [ ] Icons are const
- [ ] Padding/SizedBox with fixed values are const
- [ ] No unnecessary rebuilds of const widgets

```dart
// ❌ Bad
Text('Static text')
Icon(Icons.home)
Padding(padding: EdgeInsets.all(16))

// ✅ Good
const Text('Static text')
const Icon(Icons.home)
const Padding(padding: EdgeInsets.all(16))
```

### ✅ List Performance

- [ ] Using ListView.builder (not ListView with children)
- [ ] GridView.builder for grids
- [ ] Infinite scroll uses pagination
- [ ] List items have keys (when reorderable)
- [ ] Complex list items use RepaintBoundary
- [ ] itemExtent specified (when items same height)

```dart
// ✅ Good
ListView.builder(
  itemExtent: 60, // Fixed height optimization
  itemCount: items.length,
  itemBuilder: (context, index) {
    return RepaintBoundary(
      key: ValueKey(items[index].id),
      child: ItemWidget(items[index]),
    );
  },
)
```

### ✅ Image Optimization

- [ ] Images resized to display dimensions
- [ ] Using cacheWidth/cacheHeight for network images
- [ ] Placeholder for slow-loading images
- [ ] Error handling for failed image loads
- [ ] Image caching strategy implemented
- [ ] Using appropriate image formats (WebP recommended)

```dart
// ✅ Good
Image.network(
  imageUrl,
  cacheWidth: 300,
  cacheHeight: 300,
  fit: BoxFit.cover,
  loadingBuilder: (context, child, loadingProgress) {
    if (loadingProgress == null) return child;
    return CircularProgressIndicator();
  },
  errorBuilder: (context, error, stackTrace) {
    return Icon(Icons.error);
  },
)
```

### ✅ Widget Tree Optimization

- [ ] No deep nesting (max 4-5 levels recommended)
- [ ] Extract complex widgets into separate classes
- [ ] Use Widgets (not functions) for composition
- [ ] Avoid unnecessary Opacity widgets
- [ ] Use AnimatedOpacity instead of Opacity
- [ ] RepaintBoundary for expensive widgets

```dart
// ❌ Bad - Function returns widget
Widget _buildHeader() {
  return Container(child: Text('Header'));
}

// ✅ Good - Separate widget class
class Header extends StatelessWidget {
  const Header();

  @override
  Widget build(BuildContext context) {
    return const Text('Header');
  }
}
```

## State Management Performance

### ✅ Rebuild Optimization

- [ ] Using const constructors to prevent rebuilds
- [ ] Widgets rebuild only when necessary
- [ ] Provider/BLoC listeners scoped appropriately
- [ ] Using select/Selector for specific field updates
- [ ] No setState called in loops
- [ ] Heavy computations moved outside build()

```dart
// ✅ Good - Selective rebuild
Consumer<CartProvider>(
  builder: (context, cart, child) => Text('${cart.itemCount}'),
)

// ✅ Better - Only rebuild on itemCount change
Selector<CartProvider, int>(
  selector: (context, cart) => cart.itemCount,
  builder: (context, itemCount, child) => Text('$itemCount'),
)
```

### ✅ Computation Optimization

- [ ] Expensive calculations cached/memoized
- [ ] Heavy operations run in isolates
- [ ] Synchronous operations < 16ms
- [ ] No blocking operations on UI thread
- [ ] Using compute() for heavy processing

```dart
// ✅ Good - Heavy work in isolate
Future<List<Product>> filterProducts(List<Product> products) async {
  return await compute(_filterProducts, products);
}

List<Product> _filterProducts(List<Product> products) {
  // Heavy filtering logic
  return products.where((p) => p.isActive).toList();
}
```

## Animation Performance

### ✅ Animation Optimization

- [ ] Animations run at 60fps (frames < 16ms)
- [ ] Using AnimatedBuilder for custom animations
- [ ] Complex animations use RepaintBoundary
- [ ] Disposal of animation controllers
- [ ] Avoid animating layout (use Transform instead)
- [ ] GPU rendering for heavy animations

```dart
// ✅ Good - Isolate animation with RepaintBoundary
RepaintBoundary(
  child: AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      return Transform.rotate(
        angle: _controller.value * 2 * pi,
        child: child,
      );
    },
    child: const Icon(Icons.refresh, size: 50),
  ),
)
```

### ✅ Implicit vs Explicit Animations

- [ ] Using implicit animations when possible
- [ ] AnimatedContainer, AnimatedOpacity for simple transitions
- [ ] Explicit animations only when needed
- [ ] Animation durations 200-500ms (not too long)

## Network Performance

### ✅ API Optimization

- [ ] Implementing pagination for large datasets
- [ ] Request debouncing for search
- [ ] Caching API responses
- [ ] Retry logic with exponential backoff
- [ ] Timeout configurations (5-10 seconds)
- [ ] Connection pooling enabled
- [ ] gzip compression enabled

```dart
// ✅ Good - Debounced search
Timer? _debounce;

void onSearchChanged(String query) {
  _debounce?.cancel();
  _debounce = Timer(Duration(milliseconds: 300), () {
    performSearch(query);
  });
}

@override
void dispose() {
  _debounce?.cancel();
  super.dispose();
}
```

### ✅ Data Loading

- [ ] Lazy loading for large lists
- [ ] Infinite scroll implemented
- [ ] Pull-to-refresh with cache invalidation
- [ ] Offline mode with local cache
- [ ] Background data sync

## Memory Performance

### ✅ Memory Management

- [ ] No memory leaks detected
- [ ] Controllers disposed properly
- [ ] Stream subscriptions cancelled
- [ ] Listeners removed in dispose()
- [ ] Image cache size limited
- [ ] Memory usage monitored in DevTools

```dart
// ✅ Good - Proper disposal
class MyWidget extends StatefulWidget {
  @override
  _MyWidgetState createState() => _MyWidgetState();
}

class _MyWidgetState extends State<MyWidget> {
  late TextEditingController _controller;
  late StreamSubscription _subscription;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _subscription = stream.listen((data) {
      // Handle data
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(controller: _controller);
  }
}
```

### ✅ Cache Management

- [ ] Image cache cleared when needed
- [ ] Data cache has expiration
- [ ] Cache size limits configured
- [ ] LRU cache for frequently accessed data

## Profiling Checks

### ✅ DevTools Analysis

- [ ] Timeline shows no jank (all frames < 16ms)
- [ ] No red frames in performance overlay
- [ ] CPU usage reasonable (< 50% idle)
- [ ] Memory stable (no continuous growth)
- [ ] Shader compilation issues resolved
- [ ] No layout/paint issues in Timeline

```bash
# Enable performance overlay
flutter run --profile --trace-skia

# Run profiling
flutter run --profile
# Press 'p' to toggle performance overlay
# Press 'v' to open DevTools
```

### ✅ Performance Metrics

- [ ] Cold start < 3 seconds
- [ ] Warm start < 1 second
- [ ] Hot reload < 500ms
- [ ] Frame rendering time < 16ms (60fps)
- [ ] Scrolling smooth at 60fps
- [ ] Animations smooth at 60fps

## Platform-Specific

### ✅ Android Performance

- [ ] R8/ProGuard optimized
- [ ] Multidex configured (if needed)
- [ ] minSdkVersion appropriate (21+)
- [ ] targetSdkVersion latest stable
- [ ] No ANRs (Application Not Responding)

## Pre-Deployment

### ✅ Final Checks

- [ ] Tested on physical devices (Android)
- [ ] Tested on low-end devices
- [ ] Tested on different screen sizes
- [ ] Tested with slow network (throttled)
- [ ] Tested offline functionality
- [ ] Battery usage acceptable
- [ ] App size meets targets
- [ ] All performance issues resolved

### ✅ Production Configuration

```yaml
# pubspec.yaml - Remove dev dependencies
dependencies:
  # Production only

dev_dependencies:
  # Development/testing only
```

```dart
// Remove all debug code
assert(() {
  // This code only runs in debug mode
  return true;
}());

if (kDebugMode) {
  // Debug-only code
}
```

## Performance Score Card

Rate your app in each category (0-10):

- [ ] Build Size: __/10
- [ ] Startup Time: __/10
- [ ] UI Responsiveness: __/10
- [ ] Animation Smoothness: __/10
- [ ] Memory Usage: __/10
- [ ] Network Efficiency: __/10
- [ ] Battery Usage: __/10

**Target**: All categories ≥ 8/10 before release

## Tools for Profiling

```bash
# Performance profiling
flutter run --profile
flutter run --release --trace-skia

# Analyze app size
flutter build apk --analyze-size
flutter build appbundle --analyze-size

# Check for unused code
dart pub global activate dart_code_metrics
dart pub global run dart_code_metrics:metrics analyze lib

# Memory profiling
# Use DevTools Memory tab during runtime
```

## Quick Performance Wins

1. **Add const everywhere possible**
2. **Use ListView.builder instead of ListView**
3. **Optimize images with cacheWidth/cacheHeight**
4. **Move heavy computation to isolates**
5. **Add RepaintBoundary to expensive widgets**
6. **Use AnimatedBuilder for animations**
7. **Implement pagination for lists**
8. **Cache network responses**
9. **Dispose all controllers and subscriptions**
10. **Test on real devices, not just simulators**

This checklist ensures your Flutter app meets production performance standards.
