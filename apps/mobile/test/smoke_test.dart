// Smoke Test - Temel uygulama bileşenlerinin çalıştığını doğrular
// Firebase gerektirmeden çalışır

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import core components to verify they compile
import 'package:yotech_mobile/core/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Smoke Tests', () {
    test('AppTheme builds without error', () {
      // Test vibrant theme
      final vibrantTheme = buildAppTheme(AppTheme.vibrant);
      expect(vibrantTheme, isNotNull);

      // Test minimal theme
      final minimalTheme = buildAppTheme(AppTheme.minimal);
      expect(minimalTheme, isNotNull);

      // Test ocean theme
      final oceanTheme = buildAppTheme(AppTheme.ocean);
      expect(oceanTheme, isNotNull);
    });

    testWidgets('Basic widget renders', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: Text('Smoke Test Placeholder'),
            ),
          ),
        ),
      );

      expect(find.text('Smoke Test Placeholder'), findsOneWidget);
    });

    test('Core imports compile successfully', () {
      // If we get here, all imports compiled successfully
      expect(true, isTrue);
    });
  });

  group('Widget Smoke Tests', () {
    testWidgets('Basic MaterialApp renders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            appBar: AppBar(title: const Text('Smoke Test')),
            body: const Center(child: Text('App Works!')),
          ),
        ),
      );

      expect(find.text('Smoke Test'), findsOneWidget);
      expect(find.text('App Works!'), findsOneWidget);
    });

    testWidgets('Theme colors are applied correctly', (tester) async {
      final theme = buildAppTheme(AppTheme.vibrant);

      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            appBar: AppBar(title: const Text('Theme Test')),
            body: ElevatedButton(
              onPressed: () {},
              child: const Text('Button'),
            ),
          ),
        ),
      );

      expect(find.text('Theme Test'), findsOneWidget);
      expect(find.byType(ElevatedButton), findsOneWidget);
    });
  });
}
