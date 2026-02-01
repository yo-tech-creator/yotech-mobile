import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/break_tracking/data/models/break_session.dart';

class BreakTrackingRepository {
  BreakTrackingRepository(this._client);

  final SupabaseClient _client;

  Future<BreakSession?> fetchActiveSession(String userId) async {
    final response = await _client
        .from('break_sessions')
        .select()
        .eq('user_id', userId)
        .isFilter('ended_at', null)
        .order('started_at', ascending: false)
        .limit(1)
        .maybeSingle();

    if (response == null) return null;
    return BreakSession.fromJson(Map<String, dynamic>.from(response));
  }

  Future<List<BreakSession>> fetchRecentSessions({
    required String userId,
    DateTime? since,
    int limit = 20,
  }) async {
    var query = _client.from('break_sessions').select().eq('user_id', userId);

    if (since != null) {
      query = query.gte('started_at', since.toIso8601String());
    }

    final response =
        await query.order('started_at', ascending: false).limit(limit);
    return (response as List)
        .map((e) => BreakSession.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Fetch team break sessions for managers
  /// Uses get_branch_break_sessions RPC which handles hierarchy
  Future<List<BreakSession>> fetchTeamBreakSessions({
    required String userId,
    DateTime? since,
    int limit = 100,
  }) async {
    final response = await _client.rpc(
      'get_branch_break_sessions',
      params: {'p_user_id': userId},
    );

    List<BreakSession> sessions = (response as List)
        .map((e) => BreakSession.fromJson(Map<String, dynamic>.from(e)))
        .toList();

    // Filter by date if specified
    if (since != null) {
      sessions = sessions.where((s) => s.startedAt.isAfter(since)).toList();
    }

    // Limit results
    if (sessions.length > limit) {
      sessions = sessions.sublist(0, limit);
    }

    return sessions;
  }

  /// Fetch user names for a list of user IDs
  Future<Map<String, String>> fetchUserNames(
    List<String> userIds,
    String tenantId,
  ) async {
    if (userIds.isEmpty) return {};

    final response = await _client
        .from('users')
        .select('id, first_name, last_name, employee_code')
        .eq('tenant_id', tenantId)
        .inFilter('id', userIds);

    final names = <String, String>{};
    for (final row in (response as List)) {
      final id = row['id'] as String?;
      if (id == null) continue;
      final firstName = row['first_name'] as String? ?? '';
      final lastName = row['last_name'] as String? ?? '';
      final employeeCode = row['employee_code'] as String? ?? '';
      String name = '$firstName $lastName'.trim();
      if (name.isEmpty) name = employeeCode;
      if (name.isEmpty) name = id.substring(0, 8);
      names[id] = name;
    }
    return names;
  }

  Future<BreakSession> startBreak(String userId) async {
    final response =
        await _client.rpc('start_break_session', params: {'p_user_id': userId});
    return BreakSession.fromJson(Map<String, dynamic>.from(response));
  }

  Future<BreakSession> endBreak(String userId) async {
    final response =
        await _client.rpc('end_break_session', params: {'p_user_id': userId});
    return BreakSession.fromJson(Map<String, dynamic>.from(response));
  }
}
