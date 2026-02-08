// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/notifications/push_notification_service.dart';
import 'core/routing/app_router.dart';
import 'core/routing/auth_wrapper.dart';
import 'core/localization/locale_controller.dart';
import 'core/localization/localization_extensions.dart';
import 'core/providers/shared_preferences_provider.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'package:yotech_mobile/l10n/app_localizations.dart';

// NOT: onBackgroundMessage kaldırıldı - duplicate main() sorununa neden oluyordu

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
  // NOT: onBackgroundMessage kaldırıldı

  // Supabase başlatma
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseAnonKey,
  );

  // NOT: Session recovery artık AuthNotifier içinde yapılıyor.
  // AuthNotifier listener ile initialSession event'ini yakalıyor.
  debugPrint(
      '🚀 [main] Supabase initialized, currentSession: ${Supabase.instance.client.auth.currentSession != null}');

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

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  bool _listenerSetup = false;

  @override
  void initState() {
    super.initState();
  }

  void _setupNotificationListener() {
    if (_listenerSetup) return;
    _listenerSetup = true;

    // Notification stream'i dinle - navigasyon devre dışı bırakıldı
    // Bildirime tıklandığında sadece uygulama açılıyor
  }

  @override
  Widget build(BuildContext context) {
    // Push notification service'i başlat
    ref.watch(pushNotificationServiceProvider);

    final locale = ref.watch(localeControllerProvider);
    final appTheme = ref.watch(appThemeControllerProvider);
    final themeData = buildAppTheme(appTheme);

    // Listener'ı build içinde kur - ref.listen build içinde olmalı
    _setupNotificationListener();

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
      theme: themeData,
      home: const AuthWrapper(), // ✅ Auth state değişikliklerini dinler
      onGenerateRoute: AppRouter.onGenerateRoute,
    );
  }
}
