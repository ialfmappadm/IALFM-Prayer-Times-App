
// test/widget_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Use a relative import so we don't depend on pubspec name.
import '../lib/main.dart';

void main() {
  testWidgets('BootstrapApp renders without crashing', (WidgetTester tester) async {
    // Pump the root app widget used in your project
    await tester.pumpWidget(const BootstrapApp());

    // Basic sanity check: look for MaterialApp in the tree
    expect(find.byType(MaterialApp), findsOneWidget);

    // Optionally, verify splash elements
    // (depends on what shows first in your _BootstrapScreen)
    // expect(find.text('Starting up…'), findsOneWidget);
  });
}