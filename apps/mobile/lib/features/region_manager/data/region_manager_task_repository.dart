import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/branch_task_node.dart';
import '../domain/models/manager_todo_node.dart';

class RegionManagerTaskRepository {
  const RegionManagerTaskRepository(this._client);

  final SupabaseClient _client;

  Future<List<BranchTaskNode>> fetchBranchTaskTree({
    required String tenantId,
    required String managerId,
    required List<String> branchIds,
  }) async {
    if (branchIds.isEmpty) {
      return const <BranchTaskNode>[];
    }

    final response = await _client
        .from('tasks')
        .select()
        .eq('tenant_id', tenantId)
        .eq('created_by', managerId)
        .inFilter('branch_id', branchIds)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final rows = List<Map<String, dynamic>>.from(response as List);
    final records = rows.map(BranchTaskRecord.fromMap).toList();
    return BranchTaskNode.buildTree(records);
  }

  Future<BranchTaskRecord> createBranchTask({
    required String tenantId,
    required String managerId,
    required String branchId,
    required String title,
    String? description,
    String? priority,
    DateTime? dueDate,
    String? parentId,
    BranchTaskStatus status = BranchTaskStatus.pending,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'created_by': managerId,
      'branch_id': branchId,
      'title': title,
      'status': branchTaskStatusToString(status),
      'description': description,
      'priority': priority,
      'due_date': dueDate?.toIso8601String(),
      'parent_task_id': parentId,
      'sort_order': sortOrder,
    }..removeWhere((key, value) => value == null);

    final response =
        await _client.from('tasks').insert(payload).select().single();

    return BranchTaskRecord.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<BranchTaskRecord> updateBranchTask({
    required String taskId,
    String? title,
    String? description,
    bool setDescription = false,
    BranchTaskStatus? status,
    int? sortOrder,
  }) async {
    final updates = <String, dynamic>{};

    if (title != null) {
      updates['title'] = title;
    }

    if (setDescription) {
      updates['description'] = description;
    }

    if (status != null) {
      updates['status'] = branchTaskStatusToString(status);
    }

    if (sortOrder != null) {
      updates['sort_order'] = sortOrder;
    }

    if (updates.isEmpty) {
      final current =
          await _client.from('tasks').select().eq('id', taskId).single();

      return BranchTaskRecord.fromMap(
        Map<String, dynamic>.from(current as Map),
      );
    }

    final response = await _client
        .from('tasks')
        .update(updates)
        .eq('id', taskId)
        .select()
        .single();

    return BranchTaskRecord.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<void> updateBranchTaskStatus({
    required String taskId,
    required BranchTaskStatus status,
  }) async {
    await _client
        .from('tasks')
        .update({'status': branchTaskStatusToString(status)}).eq('id', taskId);
  }

  Future<void> deleteBranchTaskTree({required String taskId}) async {
    await _client.from('tasks').delete().eq('id', taskId);
  }

  Future<List<ManagerTodoNode>> fetchManagerTodoTree({
    required String tenantId,
    required String managerId,
  }) async {
    final response = await _client
        .from('todos')
        .select()
        .eq('tenant_id', tenantId)
        .eq('owner_id', managerId)
        .order('sort_order', ascending: true)
        .order('created_at', ascending: true);

    final rows = List<Map<String, dynamic>>.from(response as List);
    final records = rows.map(ManagerTodoRecord.fromMap).toList();
    return ManagerTodoNode.buildTree(records);
  }

  Future<ManagerTodoRecord> createManagerTodo({
    required String tenantId,
    required String managerId,
    required String title,
    String? description,
    String? parentId,
    ManagerTodoStatus status = ManagerTodoStatus.pending,
    int? sortOrder,
  }) async {
    final payload = <String, dynamic>{
      'tenant_id': tenantId,
      'owner_id': managerId,
      'title': title,
      'status': managerTodoStatusToString(status),
      'description': description,
      'parent_id': parentId,
      'sort_order': sortOrder,
    }..removeWhere((key, value) => value == null);

    final response =
        await _client.from('todos').insert(payload).select().single();

    return ManagerTodoRecord.fromMap(
      Map<String, dynamic>.from(response as Map),
    );
  }

  Future<void> updateManagerTodoStatus({
    required String todoId,
    required ManagerTodoStatus status,
  }) async {
    await _client
        .from('todos')
        .update({'status': managerTodoStatusToString(status)}).eq('id', todoId);
  }

  Future<void> deleteManagerTodoTree({required String todoId}) async {
    await _client.from('todos').delete().eq('id', todoId);
  }
}
