import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/form_models.dart';

class FormsRepository {
  const FormsRepository(this._client);

  final SupabaseClient _client;

  /// Kullanıcının rolüne göre görebileceği yayınlanmış formları getirir
  Future<List<PublishedForm>> fetchPublishedForms({
    required String tenantId,
    required String userRole,
  }) async {
    final response = await _client
        .from('v_store_scoring_published_forms')
        .select()
        .eq('tenant_id', tenantId)
        .order('published_at', ascending: false);

    final rows = List<Map<String, dynamic>>.from(response as List);

    // visible_roles filtresi - eğer null veya boşsa herkese görünür
    // aksi halde kullanıcının rolü listede olmalı
    final filteredRows = rows.where((row) {
      final visibleRoles = row['visible_roles'] as List<dynamic>?;
      if (visibleRoles == null || visibleRoles.isEmpty) {
        return true; // Tüm roller görebilir
      }
      return visibleRoles.contains(userRole);
    }).toList();

    return filteredRows.map((row) => PublishedForm.fromMap(row)).toList();
  }

  /// Belirli bir form versiyonunun detaylarını getirir
  Future<PublishedForm?> fetchFormDetail({
    required String formVersionId,
  }) async {
    final response = await _client
        .from('v_store_scoring_published_forms')
        .select()
        .eq('form_version_id', formVersionId)
        .maybeSingle();

    if (response == null) return null;
    return PublishedForm.fromMap(Map<String, dynamic>.from(response as Map));
  }

  /// Yeni form oturumu oluşturur (form doldurmaya başlama)
  Future<String> createSession({
    required String formVersionId,
    required String branchId,
    required String evaluatorId,
    String? evaluatedUserId,
  }) async {
    final response = await _client
        .from('store_scoring_sessions')
        .insert({
          'form_version_id': formVersionId,
          'branch_id': branchId,
          'evaluator_id': evaluatorId,
          'evaluated_user_id': evaluatedUserId,
          'total_positive': 0,
          'total_negative': 0,
          'total_possible': 0,
        })
        .select('id')
        .single();

    return response['id'] as String;
  }

  /// Form oturumunu tamamlar ve puanları günceller
  Future<void> completeSession({
    required String sessionId,
    required double totalPositive,
    required double totalNegative,
    required double totalPossible,
    String? notes,
  }) async {
    await _client.from('store_scoring_sessions').update({
      'total_positive': totalPositive,
      'total_negative': totalNegative,
      'total_possible': totalPossible,
      'notes': notes,
      'scored_at': DateTime.now().toIso8601String(),
    }).eq('id', sessionId);
  }

  /// Form madde cevabını kaydeder (tekil - geriye uyumluluk için)
  Future<void> saveItemResponse({
    required String sessionId,
    required String itemId,
    required FormItemResult result,
    required double pointsAwarded,
    String? comment,
  }) async {
    await _client.from('store_scoring_session_items').insert({
      'session_id': sessionId,
      'item_id': itemId,
      'result': result.dbValue,
      'points_awarded': pointsAwarded,
      'comment': comment,
    });
  }

  /// Tüm form maddesi cevaplarını tek seferde kaydeder (batch insert)
  Future<void> saveAllItemResponses({
    required String sessionId,
    required List<Map<String, dynamic>> responses,
  }) async {
    if (responses.isEmpty) return;

    // Her response'a session_id ekle
    final records = responses
        .map((r) => {
              ...r,
              'session_id': sessionId,
            })
        .toList();

    await _client.from('store_scoring_session_items').insert(records);
  }

  /// Tamamlanmış form oturumlarını getirir (filtrelerle)
  Future<List<FormSession>> fetchCompletedSessions({
    required String tenantId,
    String? branchId,
    String? evaluatorId,
    String? formVersionId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client.from('store_scoring_sessions').select('''
          id,
          form_version_id,
          branch_id,
          evaluator_id,
          evaluated_user_id,
          total_positive,
          total_negative,
          total_possible,
          notes,
          scored_at,
          store_scoring_form_versions!inner(
            form_id,
            store_scoring_forms!inner(
              tenant_id,
              title
            )
          ),
          users!store_scoring_sessions_evaluator_id_fkey(
            first_name,
            last_name
          ),
          branches!store_scoring_sessions_branch_id_fkey(
            name
          ),
          evaluated_user:users!store_scoring_sessions_evaluated_user_id_fkey(
            first_name,
            last_name
          )
        ''').eq('store_scoring_form_versions.store_scoring_forms.tenant_id', tenantId);

    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }

    if (evaluatorId != null) {
      query = query.eq('evaluator_id', evaluatorId);
    }

    if (formVersionId != null) {
      query = query.eq('form_version_id', formVersionId);
    }

    if (startDate != null) {
      query = query.gte('scored_at', startDate.toIso8601String());
    }

    if (endDate != null) {
      query = query.lte(
          'scored_at', endDate.add(const Duration(days: 1)).toIso8601String());
    }

    final response = await query.order('scored_at', ascending: false);
    final rows = List<Map<String, dynamic>>.from(response as List);

    return rows.map((row) {
      // Nested verilerden form başlığı ve kullanıcı adını çıkar
      final formVersionData =
          row['store_scoring_form_versions'] as Map<String, dynamic>?;
      final formData =
          formVersionData?['store_scoring_forms'] as Map<String, dynamic>?;
      final userData = row['users'] as Map<String, dynamic>?;
      final branchData = row['branches'] as Map<String, dynamic>?;
      final evaluatedUserData = row['evaluated_user'] as Map<String, dynamic>?;

      final firstName = userData?['first_name'] as String? ?? '';
      final lastName = userData?['last_name'] as String? ?? '';
      final evaluatorName = '$firstName $lastName'.trim();

      // Değerlendirilen personel bilgisi
      final evalFirstName = evaluatedUserData?['first_name'] as String? ?? '';
      final evalLastName = evaluatedUserData?['last_name'] as String? ?? '';
      final evaluatedUserName = '$evalFirstName $evalLastName'.trim();

      return FormSession(
        id: row['id'] as String,
        formVersionId: row['form_version_id'] as String,
        branchId: row['branch_id'] as String,
        evaluatorId: row['evaluator_id'] as String,
        totalPositive: (row['total_positive'] as num).toDouble(),
        totalNegative: (row['total_negative'] as num).toDouble(),
        totalPossible: (row['total_possible'] as num).toDouble(),
        notes: row['notes'] as String?,
        scoredAt: DateTime.parse(row['scored_at'] as String),
        formTitle: formData?['title'] as String?,
        evaluatorName: evaluatorName.isEmpty ? null : evaluatorName,
        branchName: branchData?['name'] as String?,
        branchManagerName: null,
        evaluatedUserId: row['evaluated_user_id'] as String?,
        evaluatedUserName: evaluatedUserName.isEmpty ? null : evaluatedUserName,
      );
    }).toList();
  }

  /// Belirli bir oturumun madde cevaplarını getirir
  Future<List<FormSessionItem>> fetchSessionItems({
    required String sessionId,
  }) async {
    final response = await _client
        .from('store_scoring_session_items')
        .select()
        .eq('session_id', sessionId);

    final rows = List<Map<String, dynamic>>.from(response as List);
    return rows.map((row) => FormSessionItem.fromMap(row)).toList();
  }

  /// Şubedeki personelleri getirir (filtreleme için)
  Future<List<Map<String, dynamic>>> fetchBranchPersonnel({
    required String branchId,
  }) async {
    final response = await _client
        .from('users')
        .select('id, first_name, last_name, role')
        .eq('branch_id', branchId)
        .order('first_name');

    return List<Map<String, dynamic>>.from(response as List);
  }

  /// Tenant'taki tüm formları getirir (filtreleme için)
  Future<List<Map<String, dynamic>>> fetchTenantForms({
    required String tenantId,
  }) async {
    final response = await _client
        .from('store_scoring_forms')
        .select('id, title, code')
        .eq('tenant_id', tenantId)
        .eq('is_active', true)
        .order('title');

    return List<Map<String, dynamic>>.from(response as List);
  }
}
