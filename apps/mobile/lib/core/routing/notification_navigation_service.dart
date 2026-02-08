import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../notifications/notification_types.dart';
import '../../features/auth/domain/providers/auth_provider.dart';
import '../../features/announcements/data/models/announcement.dart';
import '../../features/announcements/presentation/screens/survey_page.dart';
import '../../features/announcements/presentation/screens/announcements_page.dart';
import '../../features/visual_audit/presentation/screens/visual_audit_detail_page.dart';

/// Global Navigator Key - tüm uygulamada erişilebilir
final navigatorKeyProvider = Provider<GlobalKey<NavigatorState>>((ref) {
  return GlobalKey<NavigatorState>();
});

/// Pending notification - uygulama hazır olmadan gelen bildirim
final pendingNotificationProvider =
    StateProvider<NotificationPayload?>((ref) => null);

/// Bildirimlerden gelen navigation'ları yöneten servis
class NotificationNavigationService {
  NotificationNavigationService(this._navigatorKey, this._ref);

  final GlobalKey<NavigatorState> _navigatorKey;
  final Ref _ref;

  NavigatorState? get _navigator => _navigatorKey.currentState;

  /// Navigator hazır mı kontrol et
  bool get isNavigatorReady => _navigator != null && _navigator!.mounted;

  /// Auth durumunu kontrol et - authenticated olana kadar bekle
  Future<bool> _waitForAuth(
      {Duration timeout = const Duration(seconds: 5)}) async {
    debugPrint('⏳ Waiting for auth...');

    // Polling ile auth durumunu kontrol et
    final startTime = DateTime.now();

    while (DateTime.now().difference(startTime) < timeout) {
      final currentState = _ref.read(authProvider);

      final isAuthenticated = currentState.maybeWhen(
        authenticated: (_) => true,
        orElse: () => false,
      );

      if (isAuthenticated) {
        debugPrint('✅ Auth completed - user authenticated');
        return true;
      }

      final isUnauthenticated = currentState.maybeWhen(
        unauthenticated: () => true,
        orElse: () => false,
      );

      if (isUnauthenticated) {
        debugPrint('❌ Auth completed - user not authenticated');
        return false;
      }

      // Henüz initial veya loading durumunda, biraz bekle ve tekrar kontrol et
      await Future.delayed(const Duration(milliseconds: 100));
    }

    debugPrint('⏰ Auth wait timeout');
    return false;
  }

  /// Pending notification varsa işle
  void processPendingNotification() {
    final pending = _ref.read(pendingNotificationProvider);
    if (pending != null) {
      debugPrint('🔔 Processing pending notification: ${pending.type}');
      _ref.read(pendingNotificationProvider.notifier).state = null;
      // Auth zaten tamamlanmış, direkt navigate et
      _navigateDirectly(pending);
    }
  }

  /// Notification payload'a göre ilgili sayfaya yönlendir (stream'den gelen)
  Future<void> navigate(NotificationPayload payload) async {
    debugPrint(
        '🔔 Notification navigation: ${payload.type}, announcement_id: ${payload.announcementId}');

    // Navigator hazır değilse pending olarak sakla
    if (!isNavigatorReady) {
      debugPrint('⏳ Navigator not ready, saving as pending');
      _ref.read(pendingNotificationProvider.notifier).state = payload;
      return;
    }

    // Auth tamamlanana kadar bekle (cold start durumunda)
    final isAuthenticated = await _waitForAuth();
    if (!isAuthenticated) {
      debugPrint('❌ User not authenticated, cannot navigate');
      return;
    }

    // Navigator hala hazır mı kontrol et (auth beklerken değişmiş olabilir)
    if (!isNavigatorReady) {
      debugPrint('⏳ Navigator no longer ready after auth wait');
      _ref.read(pendingNotificationProvider.notifier).state = payload;
      return;
    }

    await _navigateDirectly(payload);
  }

  /// Doğrudan navigasyon yap (auth kontrolü yapılmış varsayılır)
  Future<void> _navigateDirectly(NotificationPayload payload) async {
    if (!isNavigatorReady) {
      debugPrint('❌ Navigator not ready for direct navigation');
      return;
    }

    switch (payload.type) {
      case NotificationType.announcement:
        await _navigateToAnnouncement(payload);
        break;

      case NotificationType.survey:
        await _navigateToSurvey(payload);
        break;

      case NotificationType.visualAuditTask:
      case NotificationType.visualAuditPhoto:
      case NotificationType.visualAuditComment:
      case NotificationType.visualAuditCompleted:
        await _navigateToVisualAudit(payload);
        break;

      case NotificationType.taskAssigned:
      case NotificationType.taskCompleted:
      case NotificationType.taskApproved:
        await _navigateToTask(payload);
        break;

      case NotificationType.sktWarning:
        await _navigateToSkt(payload);
        break;

      case NotificationType.depotTransfer:
        await _navigateToDepotTransfer(payload);
        break;

      case NotificationType.general:
        _navigator!.push(
          MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
        );
        break;
    }
  }

  Future<void> _navigateToAnnouncement(NotificationPayload payload) async {
    // Direkt duyurular sayfasına git - basit ve güvenilir
    _navigator!.push(
      MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
    );
  }

  Future<void> _navigateToSurvey(NotificationPayload payload) async {
    final surveyId = payload.surveyId ?? payload.announcementId;

    if (surveyId == null) {
      _navigator!.push(
        MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
      );
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('announcements')
          .select()
          .eq('id', surveyId)
          .maybeSingle();

      if (response != null && isNavigatorReady) {
        final announcement = Announcement.fromJson(response);

        _navigator!.push(
          MaterialPageRoute(
            builder: (_) => SurveyPage(
              announcement: announcement,
              openedFromNotification: true,
            ),
          ),
        );
      } else {
        _navigator!.push(
          MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
        );
      }
    } catch (e) {
      debugPrint('Survey load error: $e');
      if (isNavigatorReady) {
        _navigator!.push(
          MaterialPageRoute(builder: (_) => const AnnouncementsPage()),
        );
      }
    }
  }

  Future<void> _navigateToVisualAudit(NotificationPayload payload) async {
    final taskId = payload.taskId;

    if (taskId != null && isNavigatorReady) {
      _navigator!.push(
        MaterialPageRoute(
          builder: (_) => VisualAuditDetailPage(taskId: taskId),
        ),
      );
    }
  }

  Future<void> _navigateToTask(NotificationPayload payload) async {
    final taskId = payload.taskId;
    if (taskId != null && isNavigatorReady) {
      _navigator!.push(
        MaterialPageRoute(
          builder: (_) => VisualAuditDetailPage(taskId: taskId),
        ),
      );
    }
  }

  Future<void> _navigateToSkt(NotificationPayload payload) async {
    debugPrint('Navigate to SKT - not implemented');
  }

  Future<void> _navigateToDepotTransfer(NotificationPayload payload) async {
    debugPrint('Navigate to Depot Transfer - not implemented');
  }
}

/// NotificationNavigationService provider
final notificationNavigationServiceProvider =
    Provider<NotificationNavigationService>((ref) {
  final navigatorKey = ref.watch(navigatorKeyProvider);
  return NotificationNavigationService(navigatorKey, ref);
});
