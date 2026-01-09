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
    return BranchTaskNode.buildTree(records);
  }

  Future<void> updateTaskStatus({
    required String taskId,
    required BranchTaskStatus status,
  }) async {
    await _client
        .from('tasks')
        .update({'status': branchTaskStatusToString(status)}).eq('id', taskId);
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
