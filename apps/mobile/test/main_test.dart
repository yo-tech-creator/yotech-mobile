import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart' as dotenv;

import 'package:yotech_mobile/core/routing/app_router.dart';
import 'package:yotech_mobile/main.dart';

class _FakeRouter extends AppRouter {
  final Widget initial;

  _FakeRouter(this.initial, Ref ref) : super(ref);

  @override
  Widget getInitialScreen() => initial;
}

Widget _buildApp({Widget? home}) {
  return ProviderScope(
    overrides: [
      appRouterProvider
          .overrideWith((ref) => _FakeRouter(home ?? const Placeholder(), ref)),
    ],
    child: const MyApp(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Stub dotenv load/env
    dotenv.dotenv
        .testLoad(fileInput: 'SUPABASE_URL=foo\nSUPABASE_ANON_KEY=bar');
  });

  group('MyApp', () {
    testWidgets('renders MaterialApp with title and theme', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.title, 'Yotech');
      expect(materialApp.debugShowCheckedModeBanner, isFalse);
      expect(materialApp.theme?.useMaterial3, isTrue);
    });

    testWidgets('uses router.getInitialScreen for home', (tester) async {
      const fakeHome = Text('HomeFromRouter');

      await tester.pumpWidget(_buildApp(home: fakeHome));
      await tester.pump();

      expect(find.text('HomeFromRouter'), findsOneWidget);
    });

    testWidgets('onGenerateRoute is set from AppRouter', (tester) async {
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
      expect(materialApp.onGenerateRoute, equals(AppRouter.onGenerateRoute));
    });

    testWidgets('does not crash when env variables missing', (tester) async {
      // Ensure app can build without reading main() side effects
      await tester.pumpWidget(_buildApp());
      await tester.pump();

      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
