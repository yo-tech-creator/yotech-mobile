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
