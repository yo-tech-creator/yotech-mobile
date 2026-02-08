import 'package:supabase_flutter/supabase_flutter.dart';

import '../../region_manager/domain/models/branch_task_node.dart';

class BranchTasksRepository {
  const BranchTasksRepository(this._client);

  final SupabaseClient _client;

  Future<List<BranchTaskNode>> fetchBranchTasks({
    required String tenantId,
    required String branchId,
  }) async {
    final response = await _client
        .from('tasks')
        .select()
        .eq('tenant_id', tenantId)
        .eq('branch_id', branchId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final rows = List<Map<String, dynamic>>.from(response as List);
    final records = rows.map(BranchTaskRecord.fromMap).toList();

    final creatorIds = records.map((r) => r.managerId).toSet().toList();
    final creatorMap = <String, Map<String, dynamic>>{};

    if (creatorIds.isNotEmpty) {
      final creatorsResponse = await _client
          .from('users')
          .select('id, first_name, last_name, role')
          .inFilter('id', creatorIds);

      final creatorRows =
          List<Map<String, dynamic>>.from(creatorsResponse as List);
      for (final user in creatorRows) {
        final id = user['id'] as String?;
        if (id != null) {
          creatorMap[id] = user;
        }
      }
    }

    final enriched = records.map((record) {
      final user = creatorMap[record.managerId];
      final firstName = user?['first_name'] as String?;
      final lastName = user?['last_name'] as String?;
      final role = user?['role'] as String?;
      final fullName = [firstName, lastName]
          .where((part) => part != null && part.isNotEmpty)
          .join(' ');

      return record.copyWith(
        managerName: fullName.isEmpty ? null : fullName,
        managerRole: role,
      );
    }).toList();

    return BranchTaskNode.buildTree(enriched);
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required BranchTaskStatus status,
  }) async {
    await _client
        .from('tasks')
        .update({'status': branchTaskStatusToString(status)}).eq('id', taskId);

    // Eğer tamamlandı olarak işaretlendiyse
    if (status == BranchTaskStatus.completed) {
      // Tüm alt görevleri de tamamla
      await _completeChildTasks(taskId);
      // Üst görevleri de kontrol et
      await _checkAndCompleteParentTasks(taskId);
    }
  }

  /// Bir görevin tüm alt görevlerini rekürsif olarak tamamla
  Future<void> _completeChildTasks(String taskId) async {
    // Bu görevin tüm alt görevlerini bul
    final childrenResponse =
        await _client.from('tasks').select('id').eq('parent_task_id', taskId);

    final children = List<Map<String, dynamic>>.from(childrenResponse as List);

    for (final child in children) {
      final childId = child['id'] as String;
      // Alt görevi tamamla
      await _client
          .from('tasks')
          .update({'status': 'tamamlandi'}).eq('id', childId);
      // Rekürsif olarak bu alt görevin alt görevlerini de tamamla
      await _completeChildTasks(childId);
    }
  }

  /// Alt görevlerin hepsi tamamlandıysa üst görevi de tamamla
  /// Rekürsif olarak tüm üst görevleri kontrol eder
  Future<void> _checkAndCompleteParentTasks(String taskId) async {
    // Önce bu görevin parent_task_id'sini bul
    final taskResponse = await _client
        .from('tasks')
        .select('parent_task_id')
        .eq('id', taskId)
        .maybeSingle();

    if (taskResponse == null) return;

    final parentTaskId = taskResponse['parent_task_id'] as String?;
    if (parentTaskId == null) return;

    // Parent'ın tüm alt görevlerini kontrol et
    final siblingsResponse = await _client
        .from('tasks')
        .select('id, status')
        .eq('parent_task_id', parentTaskId);

    final siblings = List<Map<String, dynamic>>.from(siblingsResponse as List);

    // Tüm kardeşler tamamlandı mı kontrol et
    final allCompleted = siblings.every((sibling) {
      final status = sibling['status'] as String?;
      return status == 'tamamlandi';
    });

    if (allCompleted) {
      // Üst görevi tamamla
      await _client
          .from('tasks')
          .update({'status': 'tamamlandi'}).eq('id', parentTaskId);

      // Rekürsif olarak bir üst seviyeyi de kontrol et
      await _checkAndCompleteParentTasks(parentTaskId);
    }
  }

  Future<BranchTaskRecord> createTask({
    required String tenantId,
    required String creatorId,
    required String branchId,
    required String title,
    String? description,
    String? priority,
    DateTime? dueDate,
    String? parentTaskId,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'branch_id': branchId,
      'created_by': creatorId,
      'title': title,
      'description': description,
      'priority': priority,
      'due_date': dueDate?.toIso8601String(),
      'parent_task_id': parentTaskId,
      'sort_order': sortOrder,
    }..removeWhere((key, value) => value == null);

    final response =
        await _client.from('tasks').insert(payload).select().single();
    return BranchTaskRecord.fromMap(Map<String, dynamic>.from(response as Map));
  }

  Future<void> deleteTaskCascade({
    required BranchTaskNode root,
  }) async {
    final ids = <String>[];

    void collect(BranchTaskNode node) {
      for (final child in node.children) {
        collect(child);
      }
      ids.add(node.record.id);
    }

    collect(root);

    for (final id in ids) {
      await _client.from('tasks').delete().eq('id', id);
    }
  }
}
