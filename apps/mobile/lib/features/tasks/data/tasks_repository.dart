import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/task_models.dart';

/// Görev repository - tüm görev işlemleri
class TasksRepository {
  const TasksRepository(this._client);

  final SupabaseClient _client;

  // ============================================
  // GÖREV LİSTELEME
  // ============================================

  /// Kullanıcının görevlerini getirir
  Future<List<Task>> fetchTasks({
    required String tenantId,
    String? branchId,
    String? userId,
    bool includeArchived = false,
  }) async {
    var query = _client.from('tasks').select('''
      *,
      creator:users!tasks_created_by_fkey(first_name, last_name, role),
      branch:branches!tasks_branch_id_fkey(name),
      approver:users!tasks_approved_by_fkey(first_name, last_name),
      task_assignees(id, user_id, assigned_at)
    ''').eq('tenant_id', tenantId);

    if (branchId != null) {
      query = query.eq('branch_id', branchId);
    }

    if (!includeArchived) {
      query = query.eq('is_archived', false);
    }

    final response = await query.order('sort_order').order('created_at');
    final rows = List<Map<String, dynamic>>.from(response as List);

    return rows.map((row) => _parseTask(row)).toList();
  }

  /// Aktif görevleri getirir (tamamlanmamış)
  Future<List<TaskNode>> fetchActiveTasks({
    required String tenantId,
    String? branchId,
  }) async {
    final tasks = await fetchTasks(
      tenantId: tenantId,
      branchId: branchId,
    );

    // Sadece tamamlanmamış veya onaylanmamış görevleri filtrele
    final activeTasks = tasks
        .where((t) => t.status != TaskStatus.approved && !t.isArchived)
        .toList();

    return TaskNode.buildTree(activeTasks);
  }

  /// Tamamlanan görevleri getirir (onay bekleyen + onaylanan)
  Future<List<TaskNode>> fetchCompletedTasks({
    required String tenantId,
    String? branchId,
  }) async {
    final tasks = await fetchTasks(
      tenantId: tenantId,
      branchId: branchId,
    );

    // Tamamlanan veya onaylanan görevler
    final completedTasks = tasks
        .where((t) =>
            (t.status == TaskStatus.completed ||
                t.status == TaskStatus.approved) &&
            !t.isArchived)
        .toList();

    return TaskNode.buildTree(completedTasks);
  }

  /// Arşivlenmiş görevleri getirir
  Future<List<TaskNode>> fetchArchivedTasks({
    required String tenantId,
    String? branchId,
  }) async {
    final tasks = await fetchTasks(
      tenantId: tenantId,
      branchId: branchId,
      includeArchived: true,
    );

    final archivedTasks = tasks.where((t) => t.isArchived).toList();
    return TaskNode.buildTree(archivedTasks);
  }

  /// Kullanıcının oluşturduğu görevler
  Future<List<TaskNode>> fetchMyCreatedTasks({
    required String tenantId,
    required String userId,
  }) async {
    final tasks = await fetchTasks(tenantId: tenantId);
    final myTasks = tasks.where((t) => t.createdBy == userId).toList();
    return TaskNode.buildTree(myTasks);
  }

  /// Kullanıcıya atanan görevler
  Future<List<TaskNode>> fetchAssignedToMe({
    required String tenantId,
    required String userId,
  }) async {
    final response = await _client
        .from('task_assignees')
        .select('task_id')
        .eq('user_id', userId);

    final taskIds =
        (response as List).map((r) => r['task_id'] as String).toSet();

    if (taskIds.isEmpty) return [];

    final tasks = await fetchTasks(tenantId: tenantId);
    final assignedTasks = tasks.where((t) => taskIds.contains(t.id)).toList();
    return TaskNode.buildTree(assignedTasks);
  }

  // ============================================
  // GÖREV OLUŞTURMA
  // ============================================

  /// Yeni görev oluşturur
  Future<Task> createTask({
    required String tenantId,
    required String creatorId,
    required String title,
    String? branchId,
    String? description,
    TaskPriority priority = TaskPriority.medium,
    DateTime? dueDate,
    String? parentTaskId,
    String? sourceTaskId,
    int sortOrder = 0,
    List<String>? assigneeIds,
  }) async {
    final payload = {
      'tenant_id': tenantId,
      'created_by': creatorId,
      'branch_id': branchId,
      'title': title,
      'description': description,
      'priority': priority.dbValue,
      'due_date': dueDate?.toIso8601String(),
      'parent_task_id': parentTaskId,
      'source_task_id': sourceTaskId,
      'sort_order': sortOrder,
    }..removeWhere((key, value) => value == null);

    final response =
        await _client.from('tasks').insert(payload).select().single();

    final task = Task.fromMap(Map<String, dynamic>.from(response as Map));

    // Atananları ekle
    if (assigneeIds != null && assigneeIds.isNotEmpty) {
      await _addAssignees(taskId: task.id, userIds: assigneeIds);
    }

    return task;
  }

  /// Draft'tan görev ağacı oluşturur
  Future<Task> createTaskTree({
    required String tenantId,
    required String creatorId,
    required TaskDraft draft,
    String? branchId,
    List<String>? assigneeIds,
  }) async {
    final rootTask = await createTask(
      tenantId: tenantId,
      creatorId: creatorId,
      branchId: branchId,
      title: draft.title,
      description: draft.description,
      priority: draft.priority,
      dueDate: draft.dueDate,
      assigneeIds: assigneeIds,
    );

    // Alt görevleri oluştur
    await _createChildTasks(
      tenantId: tenantId,
      creatorId: creatorId,
      branchId: branchId,
      parentTaskId: rootTask.id,
      drafts: draft.children,
    );

    return rootTask;
  }

  Future<void> _createChildTasks({
    required String tenantId,
    required String creatorId,
    required String parentTaskId,
    required List<TaskDraft> drafts,
    String? branchId,
  }) async {
    for (var i = 0; i < drafts.length; i++) {
      final draft = drafts[i];
      if (!draft.isValid) continue;

      final childTask = await createTask(
        tenantId: tenantId,
        creatorId: creatorId,
        branchId: branchId,
        title: draft.title,
        description: draft.description,
        priority: draft.priority,
        dueDate: draft.dueDate,
        parentTaskId: parentTaskId,
        sortOrder: i,
      );

      if (draft.children.isNotEmpty) {
        await _createChildTasks(
          tenantId: tenantId,
          creatorId: creatorId,
          branchId: branchId,
          parentTaskId: childTask.id,
          drafts: draft.children,
        );
      }
    }
  }

  // ============================================
  // GÖREV GÜNCELLEME
  // ============================================

  /// Görev durumunu günceller
  Future<void> updateTaskStatus({
    required String taskId,
    required TaskStatus status,
  }) async {
    final updates = <String, dynamic>{
      'status': status.dbValue,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (status == TaskStatus.completed) {
      updates['completed_at'] = DateTime.now().toIso8601String();
    }

    await _client.from('tasks').update(updates).eq('id', taskId);
  }

  /// Görev ilerleme yüzdesini günceller
  Future<void> updateTaskProgress({
    required String taskId,
    required int percentage,
  }) async {
    final status = percentage >= 100
        ? TaskStatus.completed
        : percentage > 0
            ? TaskStatus.inProgress
            : TaskStatus.pending;

    await _client.from('tasks').update({
      'completion_percentage': percentage.clamp(0, 100),
      'status': status.dbValue,
      'completed_at':
          percentage >= 100 ? DateTime.now().toIso8601String() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
  }

  /// Görevi onayla
  Future<void> approveTask({
    required String taskId,
    required String approverId,
  }) async {
    await _client.from('tasks').update({
      'status': TaskStatus.approved.dbValue,
      'approved_at': DateTime.now().toIso8601String(),
      'approved_by': approverId,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
  }

  /// Görevi arşivle
  Future<void> archiveTask({required String taskId}) async {
    await _client.from('tasks').update({
      'is_archived': true,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
  }

  /// Görevi arşivden çıkar
  Future<void> unarchiveTask({required String taskId}) async {
    await _client.from('tasks').update({
      'is_archived': false,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
  }

  // ============================================
  // GÖREV İLETME (FORWARD)
  // ============================================

  /// Görevi başka kullanıcılara ilet (fork)
  /// Orijinal görev kalır, yeni bir görev oluşturulur
  Future<Task> forwardTask({
    required Task sourceTask,
    required String forwarderId,
    required List<String> assigneeIds,
    String? branchId,
  }) async {
    final newTask = await createTask(
      tenantId: sourceTask.tenantId,
      creatorId: forwarderId,
      branchId: branchId ?? sourceTask.branchId,
      title: sourceTask.title,
      description: sourceTask.description,
      priority: sourceTask.priority,
      dueDate: sourceTask.dueDate,
      sourceTaskId: sourceTask.id, // Orijinal görevi referans al
      assigneeIds: assigneeIds,
    );

    return newTask;
  }

  /// Alt görevi yeni görev olarak ilet
  Future<Task> forwardSubtask({
    required TaskNode subtaskNode,
    required String forwarderId,
    required List<String> assigneeIds,
    String? branchId,
  }) async {
    // Ana görev olarak oluştur (parent yok)
    final newTask = await createTask(
      tenantId: subtaskNode.task.tenantId,
      creatorId: forwarderId,
      branchId: branchId ?? subtaskNode.task.branchId,
      title: subtaskNode.task.title,
      description: subtaskNode.task.description,
      priority: subtaskNode.task.priority,
      dueDate: subtaskNode.task.dueDate,
      sourceTaskId: subtaskNode.task.id,
      assigneeIds: assigneeIds,
    );

    // Alt görevleri de kopyala
    await _copyChildren(
      tenantId: subtaskNode.task.tenantId,
      creatorId: forwarderId,
      branchId: branchId ?? subtaskNode.task.branchId,
      parentTaskId: newTask.id,
      children: subtaskNode.children,
    );

    return newTask;
  }

  Future<void> _copyChildren({
    required String tenantId,
    required String creatorId,
    required String parentTaskId,
    required List<TaskNode> children,
    String? branchId,
  }) async {
    for (var i = 0; i < children.length; i++) {
      final child = children[i];
      final newChild = await createTask(
        tenantId: tenantId,
        creatorId: creatorId,
        branchId: branchId,
        title: child.task.title,
        description: child.task.description,
        priority: child.task.priority,
        dueDate: child.task.dueDate,
        parentTaskId: parentTaskId,
        sourceTaskId: child.task.id,
        sortOrder: i,
      );

      if (child.children.isNotEmpty) {
        await _copyChildren(
          tenantId: tenantId,
          creatorId: creatorId,
          branchId: branchId,
          parentTaskId: newChild.id,
          children: child.children,
        );
      }
    }
  }

  // ============================================
  // GÖREV SİLME
  // ============================================

  /// Görevi ve alt görevlerini sil
  Future<void> deleteTaskCascade({required TaskNode node}) async {
    final ids = <String>[];

    void collect(TaskNode n) {
      for (final child in n.children) {
        collect(child);
      }
      ids.add(n.task.id);
    }

    collect(node);

    for (final id in ids) {
      await _client.from('tasks').delete().eq('id', id);
    }
  }

  // ============================================
  // ATANANLAR (ASSIGNEES)
  // ============================================

  Future<void> _addAssignees({
    required String taskId,
    required List<String> userIds,
  }) async {
    if (userIds.isEmpty) return;

    final records = userIds
        .map((userId) => {
              'task_id': taskId,
              'user_id': userId,
            })
        .toList();

    await _client.from('task_assignees').insert(records);
  }

  /// Görev atananlarını getirir
  Future<List<TaskAssignee>> fetchAssignees({required String taskId}) async {
    final response = await _client.from('task_assignees').select('''
      id,
      task_id,
      user_id,
      assigned_at,
      user:users!task_assignees_user_id_fkey(first_name, last_name, role)
    ''').eq('task_id', taskId);

    final rows = List<Map<String, dynamic>>.from(response as List);
    return rows.map((row) {
      final userData = row['user'] as Map<String, dynamic>?;
      final firstName = userData?['first_name'] as String? ?? '';
      final lastName = userData?['last_name'] as String? ?? '';
      final userName = '$firstName $lastName'.trim();

      return TaskAssignee(
        id: row['id'] as String,
        taskId: row['task_id'] as String,
        userId: row['user_id'] as String,
        assignedAt: DateTime.parse(row['assigned_at'] as String),
        userName: userName.isEmpty ? null : userName,
        userRole: userData?['role'] as String?,
      );
    }).toList();
  }

  // ============================================
  // EKLER (ATTACHMENTS)
  // ============================================

  /// Göreve dosya ekle
  Future<TaskAttachment> addAttachment({
    required String taskId,
    required String fileName,
    required Uint8List fileBytes,
    required String fileType,
    required String uploaderId,
  }) async {
    // Storage'a yükle
    final storagePath =
        'tasks/$taskId/${DateTime.now().millisecondsSinceEpoch}_$fileName';

    await _client.storage.from('task-attachments').uploadBinary(
          storagePath,
          fileBytes,
          fileOptions: FileOptions(contentType: fileType),
        );

    final fileUrl =
        _client.storage.from('task-attachments').getPublicUrl(storagePath);

    // Veritabanına kaydet
    final response = await _client
        .from('task_attachments')
        .insert({
          'task_id': taskId,
          'file_url': fileUrl,
          'file_name': fileName,
          'file_type': fileType,
          'file_size': fileBytes.length,
          'uploaded_by': uploaderId,
        })
        .select()
        .single();

    return TaskAttachment.fromMap(Map<String, dynamic>.from(response as Map));
  }

  /// Görev eklerini getirir
  Future<List<TaskAttachment>> fetchAttachments(
      {required String taskId}) async {
    final response = await _client.from('task_attachments').select('''
      *,
      uploader:users!task_attachments_uploaded_by_fkey(first_name, last_name)
    ''').eq('task_id', taskId).order('created_at');

    final rows = List<Map<String, dynamic>>.from(response as List);
    return rows.map((row) {
      final uploaderData = row['uploader'] as Map<String, dynamic>?;
      final firstName = uploaderData?['first_name'] as String? ?? '';
      final lastName = uploaderData?['last_name'] as String? ?? '';
      final uploaderName = '$firstName $lastName'.trim();

      return TaskAttachment(
        id: row['id'] as String,
        taskId: row['task_id'] as String,
        fileUrl: row['file_url'] as String,
        fileName: row['file_name'] as String,
        fileType: row['file_type'] as String?,
        fileSize: row['file_size'] as int?,
        uploadedBy: row['uploaded_by'] as String,
        createdAt: DateTime.parse(row['created_at'] as String),
        uploaderName: uploaderName.isEmpty ? null : uploaderName,
      );
    }).toList();
  }

  /// Eki sil
  Future<void> deleteAttachment({required String attachmentId}) async {
    await _client.from('task_attachments').delete().eq('id', attachmentId);
  }

  // ============================================
  // YARDIMCI METODLAR
  // ============================================

  Task _parseTask(Map<String, dynamic> row) {
    final creatorData = row['creator'] as Map<String, dynamic>?;
    final branchData = row['branch'] as Map<String, dynamic>?;
    final approverData = row['approver'] as Map<String, dynamic>?;

    final creatorFirstName = creatorData?['first_name'] as String? ?? '';
    final creatorLastName = creatorData?['last_name'] as String? ?? '';
    final creatorName = '$creatorFirstName $creatorLastName'.trim();

    final approverFirstName = approverData?['first_name'] as String? ?? '';
    final approverLastName = approverData?['last_name'] as String? ?? '';
    final approverName = '$approverFirstName $approverLastName'.trim();

    return Task(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      branchId: row['branch_id'] as String?,
      title: row['title'] as String,
      description: row['description'] as String?,
      createdBy: row['created_by'] as String,
      status: TaskStatusExtension.fromDb(row['status'] as String?),
      priority: TaskPriorityExtension.fromDb(row['priority'] as String?),
      dueDate: row['due_date'] != null
          ? DateTime.tryParse(row['due_date'] as String)
          : null,
      completedAt: row['completed_at'] != null
          ? DateTime.tryParse(row['completed_at'] as String)
          : null,
      approvedAt: row['approved_at'] != null
          ? DateTime.tryParse(row['approved_at'] as String)
          : null,
      approvedBy: row['approved_by'] as String?,
      parentTaskId: row['parent_task_id'] as String?,
      sourceTaskId: row['source_task_id'] as String?,
      completionPercentage: row['completion_percentage'] as int? ?? 0,
      sortOrder: row['sort_order'] as int? ?? 0,
      isArchived: row['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(row['created_at'] as String),
      updatedAt: DateTime.parse(row['updated_at'] as String),
      creatorName: creatorName.isEmpty ? null : creatorName,
      creatorRole: creatorData?['role'] as String?,
      branchName: branchData?['name'] as String?,
      approverName: approverName.isEmpty ? null : approverName,
    );
  }
}
