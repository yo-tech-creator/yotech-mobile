// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/notifications/push_notification_service.dart';
import 'core/routing/app_router.dart';
import 'core/localization/locale_controller.dart';
import 'core/localization/localization_extensions.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'package:yotech_mobile/l10n/app_localizations.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Environment variables yükle
  await dotenv.load(fileName: '.env');

  // Ortam değişkenlerini doğrula
  final supabaseUrl = dotenv.env['SUPABASE_URL'] ?? '';
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
    throw Exception(
      'SUPABASE_URL veya SUPABASE_ANON_KEY eksik. .env dosyasını kontrol edin.',
    );
  }

  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // Supabase başlatma
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  final sharedPrefs = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    ref.watch(pushNotificationServiceProvider);
    final locale = ref.watch(localeControllerProvider);

    final colorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF4DA3FF), // daha açık mavi ton
      brightness: Brightness.light,
    );

    return MaterialApp(
      onGenerateTitle: (context) => context.l10n.appTitle,
      locale: locale,
      supportedLocales: supportedAppLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: colorScheme,
        // Griyi azaltıp daha açık, maviye çalan zemin
        scaffoldBackgroundColor: const Color(0xFFF7FBFF),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF7FBFF),
          foregroundColor: colorScheme.onSurface,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: const Color(0xFFF0F6FF), // hafif mavi dokunuş
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        bottomSheetTheme: BottomSheetThemeData(
          backgroundColor: const Color(0xFFF7FBFF),
          surfaceTintColor: colorScheme.primary.withAlpha((0.04 * 255).round()),
        ),
        sliderTheme: SliderThemeData(
          thumbColor: colorScheme.primary,
          activeTrackColor: colorScheme.primary,
          inactiveTrackColor:
              colorScheme.primary.withAlpha((0.2 * 255).round()),
        ),
      ),
      home: router.getInitialScreen(), // ✅ Auth state'e göre yönlendirme
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
