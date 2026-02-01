import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/announcements/data/models/announcement.dart';
import 'package:yotech_mobile/features/announcements/data/models/survey_question.dart';

final announcementsRepositoryProvider =
    Provider<AnnouncementsRepository>((ref) {
  return AnnouncementsRepository(Supabase.instance.client);
});

class AnnouncementsRepository {
  AnnouncementsRepository(this._client);

  final SupabaseClient _client;

  /// Watch announcements for the current user via RPC
  Stream<List<Announcement>> watchAnnouncements(String tenantId) {
    return _client
        .from('announcements')
        .stream(primaryKey: ['id'])
        .eq('tenant_id', tenantId)
        .order('published_at', ascending: false)
        .map(
          (rows) {
            final announcements = rows
                .map((row) =>
                    Announcement.fromJson(Map<String, dynamic>.from(row)))
                .toList();
            // Sort: pinned first (by pinned_at desc), then priority, then published_at
            announcements.sort((a, b) {
              // First by pinned status
              if (a.pinned && !b.pinned) return -1;
              if (!a.pinned && b.pinned) return 1;
              
              // If both pinned, sort by pinned_at (most recent first)
              if (a.pinned && b.pinned) {
                final aTime = a.pinnedAt?.millisecondsSinceEpoch ?? 0;
                final bTime = b.pinnedAt?.millisecondsSinceEpoch ?? 0;
                if (bTime != aTime) return bTime.compareTo(aTime);
              }
              
              // Then by priority
              if (b.priority != a.priority) {
                return b.priority.compareTo(a.priority);
              }
              
              // Finally by published_at
              return b.publishedAt.compareTo(a.publishedAt);
            });
            return announcements;
          },
        );
  }

  /// Get announcements for the current user via RPC function
  Future<List<Announcement>> getMyAnnouncements() async {
    final response = await _client.rpc('get_my_announcements');

    if (response == null) return [];

    final list = response as List<dynamic>;
    return list
        .map((item) => Announcement.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Mark announcement as read
  Future<void> markAsRead(String announcementId) async {
    await _client.from('announcement_reads').upsert({
      'announcement_id': announcementId,
      'user_id': _client.auth.currentUser!.id,
      'read_at': DateTime.now().toIso8601String(),
    }, onConflict: 'announcement_id,user_id');
  }

  /// Get survey questions for an announcement
  Future<List<SurveyQuestion>> getSurveyQuestions(String announcementId) async {
    final response = await _client
        .from('survey_questions')
        .select()
        .eq('announcement_id', announcementId)
        .order('sort_order');

    return (response as List<dynamic>)
        .map((item) => SurveyQuestion.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Check if user has already responded to survey
  Future<bool> hasUserResponded(String announcementId) async {
    final response = await _client
        .from('survey_responses')
        .select('id')
        .eq('announcement_id', announcementId)
        .eq('user_id', _client.auth.currentUser!.id)
        .maybeSingle();

    return response != null;
  }

  /// Submit survey response
  Future<void> submitSurveyResponse({
    required String announcementId,
    required List<SurveyAnswer> answers,
  }) async {
    await _client.rpc('submit_survey_response', params: {
      'p_announcement_id': announcementId,
      'p_answers': answers.map((a) => a.toJson()).toList(),
    });
  }

  /// Create a new announcement
  Future<void> createAnnouncement({
    required String title,
    required String content,
    String? summary,
    required String targetScope,
    List<String>? targetBranches,
    bool managersOnly = false,
    bool pinned = false,
    int priority = 2,
    DateTime? expiresAt,
  }) async {
    await _client.rpc('create_announcement', params: {
      'p_title': title,
      'p_content': content,
      'p_summary': summary,
      'p_target_scope': targetScope,
      'p_target_branches': targetBranches,
      'p_managers_only': managersOnly,
      'p_pinned': pinned,
      'p_priority': priority,
      'p_expires_at': expiresAt?.toIso8601String(),
    });
  }

  /// Get branches for the current user (for target selection)
  Future<List<Map<String, dynamic>>> getAvailableBranches() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];

    // Get user's role and branch/region info
    final userProfile = await _client
        .from('users')
        .select('role, branch_id, tenant_id')
        .eq('id', userId)
        .maybeSingle();

    if (userProfile == null) return [];

    final role = userProfile['role'] as String?;
    final tenantId = userProfile['tenant_id'] as String?;

    if (tenantId == null) return [];

    // Bölge müdürü - kendi bölgesindeki şubeleri getir
    if (role == 'bolge_muduru') {
      // regions tablosunda manager_id = userId olan bölgeyi bul
      final region = await _client
          .from('regions')
          .select('id')
          .eq('manager_id', userId)
          .maybeSingle();

      if (region != null) {
        final regionId = region['id'] as String?;
        if (regionId != null) {
          final branches = await _client
              .from('branches')
              .select('id, name, code')
              .eq('tenant_id', tenantId)
              .eq('region_id', regionId)
              .eq('is_active', true)
              .order('name');
          return List<Map<String, dynamic>>.from(branches);
        }
      }
    }

    // Şube müdürü - kendi şubesini getir
    if (role == 'sube_muduru') {
      final branchId = userProfile['branch_id'] as String?;
      if (branchId != null) {
        final branches = await _client
            .from('branches')
            .select('id, name, code')
            .eq('id', branchId);
        return List<Map<String, dynamic>>.from(branches);
      }
    }

    return [];
  }

  /// Create a new survey
  Future<void> createSurvey({
    required String title,
    required String content,
    String? summary,
    required String targetScope,
    List<String>? targetBranches,
    bool managersOnly = false,
    DateTime? expiresAt,
    required List<Map<String, dynamic>> questions,
  }) async {
    await _client.rpc('create_survey', params: {
      'p_title': title,
      'p_content': content,
      'p_summary': summary,
      'p_target_scope': targetScope,
      'p_target_branches': targetBranches,
      'p_managers_only': managersOnly,
      'p_expires_at': expiresAt?.toIso8601String(),
      'p_questions': questions,
    });
  }
}
