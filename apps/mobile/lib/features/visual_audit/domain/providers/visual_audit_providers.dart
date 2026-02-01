import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/visual_audit_models.dart';

/// Seçilen tarih provider'ı
final selectedDateProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Görev listesi provider'ı
final visualAuditTasksProvider =
    FutureProvider.autoDispose<List<VisualAuditTask>>((ref) async {
  final selectedDate = ref.watch(selectedDateProvider);
  final dateStr =
      '${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}';

  // ignore: avoid_print
  print('📷 VisualAudit: Fetching tasks for date: $dateStr');
  developer.log('📷 VisualAudit: Fetching tasks for date: $dateStr',
      name: 'visual_audit');

  try {
    final response = await Supabase.instance.client
        .rpc('get_my_visual_audit_tasks', params: {'p_date': dateStr});

    // ignore: avoid_print
    print(
        '📷 VisualAudit: Response type: ${response.runtimeType}, value: $response');
    developer.log('📷 VisualAudit: Response: $response', name: 'visual_audit');

    if (response == null) return [];

    final List<dynamic> data = response as List<dynamic>;
    // ignore: avoid_print
    print('📷 VisualAudit: Parsed ${data.length} tasks');
    return data
        .map((e) => VisualAuditTask.fromJson(e as Map<String, dynamic>))
        .toList();
  } catch (e, st) {
    // ignore: avoid_print
    print('📷 VisualAudit ERROR: $e\n$st');
    developer.log('📷 VisualAudit ERROR: $e',
        name: 'visual_audit', error: e, stackTrace: st);
    rethrow;
  }
});

/// Tek görev detayı provider'ı
final visualAuditTaskProvider = FutureProvider.autoDispose
    .family<VisualAuditTask?, String>((ref, taskId) async {
  // Önce listeden bulmaya çalış
  final tasks = await ref.watch(visualAuditTasksProvider.future);
  final task = tasks.where((t) => t.id == taskId).firstOrNull;
  return task;
});

/// Görev fotoğrafları provider'ı
final visualAuditPhotosProvider = FutureProvider.autoDispose
    .family<List<VisualAuditPhoto>, String>((ref, taskId) async {
  final response = await Supabase.instance.client
      .rpc('get_visual_audit_task_photos', params: {'p_task_id': taskId});

  if (response == null) return [];

  final List<dynamic> data = response as List<dynamic>;
  return data
      .map((e) => VisualAuditPhoto.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Görev yorumları provider'ı
final visualAuditCommentsProvider = FutureProvider.autoDispose
    .family<List<VisualAuditComment>, String>((ref, taskId) async {
  final response = await Supabase.instance.client
      .rpc('get_visual_audit_comments', params: {'p_task_id': taskId});

  if (response == null) return [];

  final List<dynamic> data = response as List<dynamic>;
  return data
      .map((e) => VisualAuditComment.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Bölümler provider'ı
final visualAuditSectionsProvider =
    FutureProvider.autoDispose<List<VisualAuditSection>>((ref) async {
  final response =
      await Supabase.instance.client.rpc('get_visual_audit_sections');

  if (response == null) return [];

  final List<dynamic> data = response as List<dynamic>;
  return data
      .map((e) => VisualAuditSection.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Fotoğraf yükleme notifier
class VisualAuditPhotoUploadNotifier extends StateNotifier<AsyncValue<void>> {
  VisualAuditPhotoUploadNotifier() : super(const AsyncValue.data(null));

  Future<bool> uploadPhoto({
    required String taskId,
    required String photoUrl,
    String? caption,
    String? thumbnailUrl,
    double? latitude,
    double? longitude,
  }) async {
    state = const AsyncValue.loading();
    try {
      await Supabase.instance.client.rpc('upload_visual_audit_photo', params: {
        'p_task_id': taskId,
        'p_photo_url': photoUrl,
        'p_caption': caption,
        'p_thumbnail_url': thumbnailUrl,
        'p_latitude': latitude,
        'p_longitude': longitude,
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final visualAuditPhotoUploadProvider = StateNotifierProvider.autoDispose<
    VisualAuditPhotoUploadNotifier, AsyncValue<void>>((ref) {
  return VisualAuditPhotoUploadNotifier();
});

/// Yorum ekleme notifier
class VisualAuditCommentNotifier extends StateNotifier<AsyncValue<void>> {
  VisualAuditCommentNotifier() : super(const AsyncValue.data(null));

  Future<bool> addComment({
    required String taskId,
    required String message,
    VisualAuditCommentType commentType = VisualAuditCommentType.comment,
    String? photoId,
  }) async {
    state = const AsyncValue.loading();
    try {
      await Supabase.instance.client.rpc('add_visual_audit_comment', params: {
        'p_task_id': taskId,
        'p_message': message,
        'p_comment_type': commentType.dbValue,
        'p_photo_id': photoId,
      });
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final visualAuditCommentProvider = StateNotifierProvider.autoDispose<
    VisualAuditCommentNotifier, AsyncValue<void>>((ref) {
  return VisualAuditCommentNotifier();
});
