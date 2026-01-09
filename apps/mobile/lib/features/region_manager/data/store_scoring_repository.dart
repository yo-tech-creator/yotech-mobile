import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/store_scoring_models.dart';

class StoreScoringRepository {
  const StoreScoringRepository(this._client);

  final SupabaseClient _client;

  Future<List<StoreScoringForm>> fetchPublishedForms({
    required String tenantId,
  }) async {
    try {
      final response = await _client
          .from('v_store_scoring_published_forms')
          .select(
            'form_version_id, form_id, tenant_id, code, title, description, version, published_at, sections',
          )
          .eq('tenant_id', tenantId)
          .order('published_at', ascending: false);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _log('fetchPublishedForms tenant=$tenantId rows=${rows.length}');
      return rows.map(StoreScoringForm.fromViewRow).toList();
    } catch (error, stackTrace) {
      _log('fetchPublishedForms error', error: error, stackTrace: stackTrace);
      throw FetchStoreScoringFormsException(error, stackTrace);
    }
  }

  Future<List<StoreScoringSessionSummary>> fetchBranchSessions({
    required String tenantId,
    required String branchId,
    int limit = 20,
  }) async {
    try {
      final response = await _client
          .from('store_scoring_sessions')
          .select(
            'id, branch_id, form_version_id, scored_at, created_at, total_positive, total_negative, total_possible, notes, form_version:store_scoring_form_versions!inner(version, form:store_scoring_forms!inner(title, code, tenant_id))',
          )
          .eq('branch_id', branchId)
          .eq('form_version.form.tenant_id', tenantId)
          .order('scored_at', ascending: false)
          .limit(limit);

      final rows = (response as List).cast<Map<String, dynamic>>();
      _log(
        'fetchBranchSessions tenant=$tenantId branch=$branchId rows=${rows.length}',
      );
      return rows.map(StoreScoringSessionSummary.fromMap).toList();
    } catch (error, stackTrace) {
      _log('fetchBranchSessions error', error: error, stackTrace: stackTrace);
      throw FetchStoreScoringSessionsException(error, stackTrace);
    }
  }

  Future<StoreScoringSessionDetail> fetchSessionDetail(String sessionId) async {
    try {
      final response = await _client
          .from('store_scoring_sessions')
          .select(
            'id, branch_id, form_version_id, scored_at, created_at, total_positive, total_negative, total_possible, notes, form_version:store_scoring_form_versions!inner(version, form:store_scoring_forms!inner(title, code)), session_items:store_scoring_session_items(item_id, result, points_awarded, comment, item:store_scoring_items(label))',
          )
          .eq('id', sessionId)
          .maybeSingle();

      if (response == null) {
        throw const StoreScoringSessionNotFound();
      }

      final entryCount =
          (response['session_items'] as List<dynamic>? ?? const []).length;
      _log('fetchSessionDetail sessionId=$sessionId entries=$entryCount');
      return StoreScoringSessionDetail.fromMap(response);
    } catch (error, stackTrace) {
      if (error is StoreScoringSessionNotFound) {
        rethrow;
      }
      _log('fetchSessionDetail error', error: error, stackTrace: stackTrace);
      throw FetchStoreScoringSessionDetailException(error, stackTrace);
    }
  }

  Future<String> submitSession(StoreScoringSubmission submission) async {
    try {
      final sessionInsert = await _client
          .from('store_scoring_sessions')
          .insert({
            'form_version_id': submission.formVersionId,
            'branch_id': submission.branchId,
            'evaluator_id': submission.evaluatorId,
            'total_positive': submission.totalPositive,
            'total_negative': submission.totalNegative,
            'total_possible': submission.totalPossible,
            'notes': submission.notes,
            'scored_at': submission.scoredAt.toIso8601String(),
          })
          .select('id')
          .single();

      final sessionId = sessionInsert['id'] as String;

      if (submission.entries.isNotEmpty) {
        final payload = submission.entries
            .map((entry) => {
                  'session_id': sessionId,
                  'item_id': entry.itemId,
                  'result': resultToDb(entry.result),
                  'points_awarded': entry.pointsAwarded,
                  'comment': entry.comment,
                })
            .toList();

        await _client.from('store_scoring_session_items').insert(payload);
      }

      _log(
        'submitSession success sessionId=$sessionId branch=${submission.branchId} formVersion=${submission.formVersionId} entries=${submission.entries.length}',
      );
      return sessionId;
    } catch (error, stackTrace) {
      _log('submitSession error', error: error, stackTrace: stackTrace);
      throw SubmitStoreScoringSessionException(error, stackTrace);
    }
  }

  Future<void> updateSession(
    String sessionId,
    StoreScoringSubmission submission,
  ) async {
    try {
      await _client.from('store_scoring_sessions').update({
        'form_version_id': submission.formVersionId,
        'branch_id': submission.branchId,
        'evaluator_id': submission.evaluatorId,
        'total_positive': submission.totalPositive,
        'total_negative': submission.totalNegative,
        'total_possible': submission.totalPossible,
        'notes': submission.notes,
        'scored_at': submission.scoredAt.toIso8601String(),
      }).eq('id', sessionId);

      await _client
          .from('store_scoring_session_items')
          .delete()
          .eq('session_id', sessionId);

      if (submission.entries.isNotEmpty) {
        final payload = submission.entries
            .map((entry) => {
                  'session_id': sessionId,
                  'item_id': entry.itemId,
                  'result': resultToDb(entry.result),
                  'points_awarded': entry.pointsAwarded,
                  'comment': entry.comment,
                })
            .toList();

        await _client.from('store_scoring_session_items').insert(payload);
      }
      _log(
        'updateSession success sessionId=$sessionId branch=${submission.branchId} formVersion=${submission.formVersionId} entries=${submission.entries.length}',
      );
    } catch (error, stackTrace) {
      _log('updateSession error', error: error, stackTrace: stackTrace);
      throw SubmitStoreScoringSessionException(error, stackTrace);
    }
  }
}

void _log(String message, {Object? error, StackTrace? stackTrace}) {
  const name = 'StoreScoringRepository';
  developer.log(message, name: name, error: error, stackTrace: stackTrace);
  final buffer = StringBuffer('[$name] $message');
  if (error != null) {
    buffer.write(' | error: $error');
  }
  debugPrint(buffer.toString());
  if (stackTrace != null) {
    debugPrint(stackTrace.toString());
  }
}

String _postgrestMessage(PostgrestException error) {
  if (error.message.isNotEmpty) {
    return error.message;
  }
  final details = error.details?.toString();
  if (details != null && details.isNotEmpty) {
    return details;
  }
  final hint = error.hint?.toString();
  if (hint != null && hint.isNotEmpty) {
    return hint;
  }
  final code = error.code?.toString();
  if (code != null && code.isNotEmpty) {
    return 'Supabase hata kodu: $code';
  }
  return 'Bilinmeyen Supabase hatası';
}

class FetchStoreScoringFormsException implements Exception {
  FetchStoreScoringFormsException(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() {
    if (error is PostgrestException) {
      return _postgrestMessage(error as PostgrestException);
    }
    return error.toString();
  }
}

class FetchStoreScoringSessionsException implements Exception {
  FetchStoreScoringSessionsException(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() {
    if (error is PostgrestException) {
      return _postgrestMessage(error as PostgrestException);
    }
    return error.toString();
  }
}

class FetchStoreScoringSessionDetailException implements Exception {
  FetchStoreScoringSessionDetailException(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() {
    if (error is PostgrestException) {
      return _postgrestMessage(error as PostgrestException);
    }
    return error.toString();
  }
}

class SubmitStoreScoringSessionException implements Exception {
  SubmitStoreScoringSessionException(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() {
    if (error is PostgrestException) {
      return _postgrestMessage(error as PostgrestException);
    }
    return error.toString();
  }
}

class StoreScoringSessionNotFound implements Exception {
  const StoreScoringSessionNotFound();
}
