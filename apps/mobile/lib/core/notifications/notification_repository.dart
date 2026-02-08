import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_types.dart';

// ============================================================================
// PROVIDER
// ============================================================================

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return NotificationRepository(Supabase.instance.client);
});

final notificationsProvider =
    FutureProvider.autoDispose<List<NotificationItem>>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getNotifications();
});

final unreadCountProvider = FutureProvider.autoDispose<int>((ref) async {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.getUnreadCount();
});

// ============================================================================
// REPOSITORY
// ============================================================================

class NotificationRepository {
  NotificationRepository(this._client);
  final SupabaseClient _client;

  /// Get user's notifications
  Future<List<NotificationItem>> getNotifications({int limit = 50}) async {
    final response = await _client
        .from('notifications')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((e) => NotificationItem.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Get unread notification count
  Future<int> getUnreadCount() async {
    final result = await _client.rpc('get_unread_notification_count');
    return (result as int?) ?? 0;
  }

  /// Mark a notification as read
  Future<bool> markAsRead(String notificationId) async {
    final result = await _client.rpc(
      'mark_notification_read',
      params: {'p_notification_id': notificationId},
    );
    return result == true;
  }

  /// Mark all notifications as read
  Future<int> markAllAsRead() async {
    final result = await _client.rpc('mark_all_notifications_read');
    return (result as int?) ?? 0;
  }
}
