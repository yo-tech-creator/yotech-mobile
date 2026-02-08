import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_types.dart';
import '../notifications/push_notification_service.dart';

/// Widget that listens to notification navigation events
/// and navigates to the appropriate screen
class NotificationNavigationHandler extends ConsumerStatefulWidget {
  const NotificationNavigationHandler({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  ConsumerState<NotificationNavigationHandler> createState() =>
      _NotificationNavigationHandlerState();
}

class _NotificationNavigationHandlerState
    extends ConsumerState<NotificationNavigationHandler> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Listen to notification navigation events
    ref.listen<AsyncValue<NotificationPayload?>>(
      notificationNavigationProvider,
      (previous, next) {
        next.whenData((payload) {
          if (payload != null) {
            _handleNavigation(payload);
          }
        });
      },
    );

    return widget.child;
  }

  void _handleNavigation(NotificationPayload payload) {
    debugPrint('Navigating from notification: ${payload.type}');

    final navigator = widget.navigatorKey.currentState;
    if (navigator == null) {
      debugPrint('Navigator not available');
      return;
    }

    // Handle different notification types
    switch (payload.type) {
      case NotificationType.visualAuditTask:
      case NotificationType.visualAuditPhoto:
      case NotificationType.visualAuditComment:
      case NotificationType.visualAuditCompleted:
        _navigateToVisualAudit(navigator, payload);
        break;

      case NotificationType.taskAssigned:
      case NotificationType.taskCompleted:
      case NotificationType.taskApproved:
        _navigateToTask(navigator, payload);
        break;

      case NotificationType.announcement:
        _navigateToAnnouncement(navigator, payload);
        break;

      case NotificationType.survey:
        _navigateToSurvey(navigator, payload);
        break;

      case NotificationType.sktWarning:
        _navigateToSkt(navigator, payload);
        break;

      case NotificationType.depotTransfer:
        _navigateToDepotTransfer(navigator, payload);
        break;

      case NotificationType.general:
        _navigateToNotifications(navigator);
        break;
    }
  }

  void _navigateToVisualAudit(
      NavigatorState navigator, NotificationPayload payload) {
    // Navigate to visual audit detail
    if (payload.taskId != null) {
      navigator.pushNamed('/visual-audit-detail', arguments: payload.taskId);
    } else {
      navigator.pushNamed('/visual-audit');
    }
  }

  void _navigateToTask(NavigatorState navigator, NotificationPayload payload) {
    if (payload.taskId != null) {
      navigator.pushNamed('/task-detail', arguments: payload.taskId);
    } else {
      navigator.pushNamed('/tasks');
    }
  }

  void _navigateToAnnouncement(
      NavigatorState navigator, NotificationPayload payload) {
    if (payload.announcementId != null) {
      navigator.pushNamed('/announcement-detail',
          arguments: payload.announcementId);
    } else {
      navigator.pushNamed('/announcements');
    }
  }

  void _navigateToSurvey(
      NavigatorState navigator, NotificationPayload payload) {
    if (payload.surveyId != null) {
      navigator.pushNamed('/survey-detail', arguments: payload.surveyId);
    } else {
      navigator.pushNamed('/surveys');
    }
  }

  void _navigateToSkt(NavigatorState navigator, NotificationPayload payload) {
    navigator.pushNamed('/skt');
  }

  void _navigateToDepotTransfer(
      NavigatorState navigator, NotificationPayload payload) {
    navigator.pushNamed('/depot-transfers');
  }

  void _navigateToNotifications(NavigatorState navigator) {
    navigator.pushNamed('/notifications');
  }
}
