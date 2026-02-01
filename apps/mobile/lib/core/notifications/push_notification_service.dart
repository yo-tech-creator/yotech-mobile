import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../features/auth/domain/models/auth_state.dart';
import '../../features/auth/domain/models/user_model.dart';
import '../../features/auth/domain/providers/auth_provider.dart';

final pushNotificationServiceProvider =
    Provider<PushNotificationService>((ref) {
  final service = PushNotificationService(ref);
  // Service kendini lazy olarak başlatıyor.
  service.initialize();
  return service;
});

class PushNotificationService {
  PushNotificationService(this._ref);

  final Ref _ref;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final SupabaseClient _client = Supabase.instance.client;

  bool _initialized = false;
  String? _lastRegisteredToken;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;

    await _ensurePermission();

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp
        .listen((message) => _handleOpenedMessage(message));
    _messaging.onTokenRefresh.listen((token) {
      final authState = _ref.read(authProvider);
      authState.maybeWhen(
        authenticated: (user) => _registerDeviceToken(user, token: token),
        orElse: () {},
      );
    });

    _ref.listen<AuthState>(authProvider, (previous, next) {
      next.maybeWhen(
        authenticated: (user) => _registerDeviceToken(user),
        orElse: () {},
      );
    });

    final current = _ref.read(authProvider);
    current.maybeWhen(
      authenticated: (user) => _registerDeviceToken(user),
      orElse: () {},
    );
  }

  Future<void> _ensurePermission() async {
    await _messaging.setAutoInitEnabled(true);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      debugPrint('Push izinleri reddedildi, token kaydedilmeyecek.');
    }
  }

  Future<void> _registerDeviceToken(UserModel user, {String? token}) async {
    try {
      final resolvedToken = token ?? await _messaging.getToken();
      if (resolvedToken == null || resolvedToken.isEmpty) {
        return;
      }

      if (_lastRegisteredToken == resolvedToken) {
        return;
      }

      // RPC fonksiyonu ile token kaydet
      // SECURITY DEFINER ile RLS bypass edilir, cihaz değişikliği durumu handle edilir
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

      if (response is Map && response['success'] == true) {
        _lastRegisteredToken = resolvedToken;
        debugPrint('Token kaydı başarılı: ${response['action']}');
      } else {
        debugPrint(
            'Token kaydı başarısız: ${response['error'] ?? 'Unknown error'}');
      }
    } catch (e) {
      // Kritik olmayan hata, sadece logla
      debugPrint('Token kaydı başarısız: $e');
    }
  }

  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint('FCM foreground mesajı: ${message.messageId}');
  }

  void _handleOpenedMessage(RemoteMessage message) {
    debugPrint('Kullanıcı bildirimi açtı: ${message.messageId}');
  }
}
