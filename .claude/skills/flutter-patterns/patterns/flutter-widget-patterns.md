---
name: flutter-widget-patterns
description: Common Flutter widget composition patterns and reusable layouts. Use this skill when you need quick reference for standard UI patterns like cards, lists, forms, dialogs, bottom sheets, and navigation patterns.
---

# Flutter Widget Patterns - Quick Reference

This skill provides battle-tested widget patterns for common UI components.

## Card Patterns

### Basic Card

```dart
// Simple card with shadow and padding
Card(
  elevation: 4,
  margin: EdgeInsets.all(16),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  child: Padding(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Title', style: Theme.of(context).textTheme.titleLarge),
        SizedBox(height: 8),
        Text('Description'),
      ],
    ),
  ),
)
```

### Image Card

```dart
Card(
  clipBehavior: Clip.antiAlias,
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Image.network(
        imageUrl,
        height: 200,
        fit: BoxFit.cover,
      ),
      Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Title', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 4),
            Text('Subtitle'),
          ],
        ),
      ),
    ],
  ),
)
```

## List Patterns

### Lazy Loading List

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return ListTile(
      leading: CircleAvatar(child: Text(item.initial)),
      title: Text(item.title),
      subtitle: Text(item.subtitle),
      trailing: Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, route),
    );
  },
)
```

### Sectioned List

```dart
ListView.builder(
  itemCount: sections.length,
  itemBuilder: (context, index) {
    final section = sections[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            section.title,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
        ),
        ...section.items.map((item) => ListTile(
          title: Text(item.name),
          onTap: () {},
        )),
      ],
    );
  },
)
```

## Form Patterns

### Basic Form

```dart
class MyForm extends StatefulWidget {
  @override
  _MyFormState createState() => _MyFormState();
}

class _MyFormState extends State<MyForm> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _emailController,
            decoration: InputDecoration(labelText: 'Email'),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please enter email';
              }
              return null;
            },
          ),
          SizedBox(height: 16),
          TextFormField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: 'Password'),
            obscureText: true,
            validator: (value) {
              if (value == null || value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                // Process data
              }
            },
            child: Text('Submit'),
          ),
        ],
      ),
    );
  }
}
```

## Dialog Patterns

### Alert Dialog

```dart
Future<bool?> showConfirmDialog(BuildContext context, String message) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Confirm'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text('Confirm'),
        ),
      ],
    ),
  );
}
```

### Custom Dialog

```dart
Future<T?> showCustomDialog<T>(BuildContext context, Widget child) {
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: child,
      ),
    ),
  );
}
```

## Bottom Sheet Patterns

### Modal Bottom Sheet

```dart
void showOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => Padding(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.edit),
            title: Text('Edit'),
            onTap: () {
              Navigator.pop(context);
              // Handle edit
            },
          ),
          ListTile(
            leading: Icon(Icons.delete),
            title: Text('Delete'),
            onTap: () {
              Navigator.pop(context);
              // Handle delete
            },
          ),
        ],
      ),
    ),
  );
}
```

## Loading Patterns

### Center Loading

```dart
Widget buildLoading() {
  return Center(
    child: CircularProgressIndicator(),
  );
}
```

### Overlay Loading

```dart
Widget buildWithOverlayLoading({
  required Widget child,
  required bool isLoading,
}) {
  return Stack(
    children: [
      child,
      if (isLoading)
        Container(
          color: Colors.black54,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
    ],
  );
}
```

## Empty State Pattern

```dart
Widget buildEmptyState({
  required IconData icon,
  required String message,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          message,
          style: TextStyle(fontSize: 18, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
        if (actionLabel != null && onAction != null) ...[
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: onAction,
            child: Text(actionLabel),
          ),
        ],
      ],
    ),
  );
}
```

## Error State Pattern

```dart
Widget buildErrorState({
  required String message,
  VoidCallback? onRetry,
}) {
  return Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red),
          SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16),
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(Icons.refresh),
              label: Text('Retry'),
              onPressed: onRetry,
            ),
          ],
        ],
      ),
    ),
  );
}
```

## Grid Patterns

### Responsive Grid

```dart
GridView.builder(
  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: MediaQuery.of(context).size.width > 600 ? 3 : 2,
    crossAxisSpacing: 16,
    mainAxisSpacing: 16,
    childAspectRatio: 0.75,
  ),
  padding: EdgeInsets.all(16),
  itemCount: items.length,
  itemBuilder: (context, index) {
    final item = items[index];
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Image.network(item.imageUrl, fit: BoxFit.cover),
          ),
          Padding(
            padding: EdgeInsets.all(8),
            child: Text(item.title),
          ),
        ],
      ),
    );
  },
)
```

## Navigation Patterns

### Push with Result

```dart
// Push and wait for result
final result = await Navigator.push<bool>(
  context,
  MaterialPageRoute(builder: (context) => DetailPage(item)),
);

if (result == true) {
  // Handle result
}

// In DetailPage, pop with result
Navigator.pop(context, true);
```

### Named Route with Arguments

```dart
// Navigate with arguments
Navigator.pushNamed(
  context,
  '/details',
  arguments: {'id': '123', 'title': 'Item'},
);

// In route
class DetailsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final id = args['id'];
    final title = args['title'];

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(child: Text('ID: $id')),
    );
  }
}
```

## Responsive Layout Pattern

```dart
class ResponsiveLayout extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;

  const ResponsiveLayout({
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 1200) {
          return desktop ?? tablet ?? mobile;
        } else if (constraints.maxWidth >= 600) {
          return tablet ?? mobile;
        } else {
          return mobile;
        }
      },
    );
  }
}
```

## Usage Examples

### Complete List Page

```dart
class ProductsPage extends StatelessWidget {
  final List<Product> products;
  final bool isLoading;
  final String? error;

  const ProductsPage({
    required this.products,
    required this.isLoading,
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return buildLoading();
    }

    if (error != null) {
      return buildErrorState(
        message: error!,
        onRetry: () {
          // Reload products
        },
      );
    }

    if (products.isEmpty) {
      return buildEmptyState(
        icon: Icons.shopping_bag_outlined,
        message: 'No products found',
        actionLabel: 'Add Product',
        onAction: () {
          // Navigate to add product
        },
      );
    }

    return ListView.builder(
      itemCount: products.length,
      itemBuilder: (context, index) {
        final product = products[index];
        return Card(
          margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundImage: NetworkImage(product.imageUrl),
            ),
            title: Text(product.name),
            subtitle: Text('\$${product.price}'),
            trailing: Icon(Icons.chevron_right),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProductDetailsPage(product),
                ),
              );

              if (result == true) {
                // Refresh list
              }
            },
          ),
        );
      },
    );
  }
}
```

These patterns provide production-ready, reusable components for common Flutter UI needs.
