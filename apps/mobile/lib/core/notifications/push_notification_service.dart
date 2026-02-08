import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../features/auth/domain/models/auth_state.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/auth/domain/providers/auth_provider.dart';
import 'notification_types.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref);
  service.initialize();
  return service;
});

/// Stream of notification navigation events
final notificationNavigationProvider =
    StreamProvider<NotificationPayload?>((ref) {
  final service = ref.watch(pushNotificationServiceProvider);
  return service.navigationStream;
});

/// Unread notification count
final unreadNotificationCountProvider = FutureProvider<int>((ref) async {
  final client = Supabase.instance.client;
  final result = await client.rpc('get_unread_notification_count');
  return (result as int?) ?? 0;
});

// ============================================================================
// SERVICE
// ============================================================================

class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _client = Supabase.instance.client;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  String? _lastRegisteredToken;
  bool _isRegisteringToken = false; // Race condition önlemek için

  // Navigation stream for deep linking
  final _navigationController =
      StreamController<NotificationPayload?>.broadcast();
  Stream<NotificationPayload?> get navigationStream =>
      _navigationController.stream;

  /// Initialize the notification service
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // İzin iste
    await _ensurePermission();

    // Local notifications başlat
    await _initializeLocalNotifications();

    // Auth değişikliklerini dinle ve token kaydet
    _setupAuthListener();

    // Token refresh dinle
    _messaging.onTokenRefresh.listen((token) {
      final authState = _ref.read(authProvider);
      authState.maybeWhen(
        authenticated: (user) => _registerDeviceToken(user, token: token),
        orElse: () {},
      );
    });

    // Foreground mesajları dinle
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // ============================================================
    // NOTIFICATION TAP HANDLING - Bildirime tıklayınca uygulama açma
    // ============================================================
    
    // 1. Uygulama KAPALI iken bildirime tıklandı mı kontrol et
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 Uygulama kapalıyken bildirime tıklandı: ${initialMessage.messageId}');
      _handleNotificationTap(initialMessage);
    }

    // 2. Uygulama ARKA PLANDA iken bildirime tıklanınca
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('🔔 Arka planda bildirime tıklandı: ${message.messageId}');
      _handleNotificationTap(message);
    });

    debugPrint('✅ Push notification service initialized');
  }

  /// Handle notification tap - uygulama açıldığında çağrılır
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tap handled - data: ${message.data}');
    // Şimdilik sadece uygulama açılıyor, navigasyon yok
    // İleride message.data içindeki bilgilere göre yönlendirme yapılabilir
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'yotech_main',
        'Yotech Bildirimleri',
        description: 'Yotech uygulaması ana bildirim kanalı',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Request notification permissions
  Future<void> _ensurePermission() async {
    await _messaging.setAutoInitEnabled(true);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push izinleri reddedildi');
    }
  }

  /// Listen to auth state changes
  void _setupAuthListener() {
    _ref.listen<AuthState>(authProvider, (previous, next) {
      // Sadece yeni authenticated olduğunda kaydet
      // previous null ise veya unauthenticated ise ve şimdi authenticated olduysa
      final wasAuth = previous?.maybeWhen(
            authenticated: (_) => true,
            orElse: () => false,
          ) ??
          false;

      next.maybeWhen(
        authenticated: (user) {
          if (!wasAuth) {
            _registerDeviceToken(user);
          }
        },
        orElse: () {},
      );
    });
  }

  /// Register device token with Supabase
  Future<void> _registerDeviceToken(UserModel user, {String? token}) async {
    // Race condition önleme - aynı anda birden fazla kayıt işlemi olmasın
    if (_isRegisteringToken) {
      debugPrint('ℹ️ Token kaydı zaten devam ediyor, atlanıyor');
      return;
    }
    _isRegisteringToken = true;

    try {
      debugPrint('🔔 Token kaydı başlatılıyor - User: ${user.id}');

      final resolvedToken = token ?? await _messaging.getToken();
      if (resolvedToken == null || resolvedToken.isEmpty) {
        debugPrint('❌ Token alınamadı!');
        return;
      }

      debugPrint('🔔 FCM Token alındı: ${resolvedToken.substring(0, 30)}...');

      if (_lastRegisteredToken == resolvedToken) {
        debugPrint('ℹ️ Token zaten kayıtlı (cache), atlanıyor');
        return;
      }

      final response = await _client.rpc('register_device_token', params: {
        'p_user_id': user.id,
        'p_tenant_id': user.tenantId,
        'p_token': resolvedToken,
        'p_platform': Platform.isIOS
            ? 'ios'
            : Platform.isAndroid
                ? 'android'
                : 'other',
      });

      debugPrint('🔔 Token kayıt cevabı: $response');

      if (response is Map && response['success'] == true) {
        _lastRegisteredToken = resolvedToken;
        debugPrint('✅ Token kaydı başarılı: ${response['action']}');
      } else {
        debugPrint('⚠️ Token kaydı beklenmeyen cevap: $response');
      }
    } catch (e, stack) {
      // Duplicate key hatası aslında başarılı demek - token zaten var
      if (e.toString().contains('23505') ||
          e.toString().contains('duplicate key')) {
        _lastRegisteredToken = token ?? await _messaging.getToken();
        debugPrint('ℹ️ Token zaten veritabanında kayıtlı (upsert yapıldı)');
      } else {
        debugPrint('❌ Token kaydı başarısız: $e');
        debugPrint('Stack: $stack');
      }
    } finally {
      _isRegisteringToken = false;
    }
  }

  /// Handle foreground message - show local notification
  /// Android'de foreground'da FCM notification otomatik gösterilmez
  /// Bu yüzden her zaman local notification göstermeliyiz
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('📱 FCM foreground mesaj alındı: ${message.messageId}');
    debugPrint(
        '📱 Notification: ${message.notification?.title} - ${message.notification?.body}');
    debugPrint('📱 Data: ${message.data}');

    final notification = message.notification;
    final data = message.data;

    // Notification payload varsa onu kullan, yoksa data'dan al
    String title;
    String body;

    if (notification != null) {
      // FCM notification payload'ından al
      title = notification.title ?? data['title'] ?? 'Yotech';
      body = notification.body ?? data['body'] ?? '';
    } else {
      // Data-only mesajlardan al
      title = data['title'] ?? 'Yotech';
      body = data['body'] ?? '';
    }

    debugPrint('📱 Gösterilecek bildirim: $title - $body');

    // Foreground'da local notification göster
    _showLocalNotification(
      title: title,
      body: body,
      payload: jsonEncode(data),
    );
  }

  /// Handle local notification tap (foreground notification tapped)
  /// NOT: Navigasyon kaldırıldı - sadece uygulama açılıyor
  void _onNotificationTapped(NotificationResponse response) {
    debugPrint('🔔 Local notification tapped');
    // Navigasyon devre dışı - uygulama normal şekilde açılıyor
  }

  /// Show a local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'yotech_main',
      'Yotech Bildirimleri',
      channelDescription: 'Yotech uygulaması ana bildirim kanalı',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Dispose resources
  void dispose() {
    _navigationController.close();
  }
}
