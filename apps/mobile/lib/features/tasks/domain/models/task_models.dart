import 'package:flutter/foundation.dart';

/// Görev durumu
enum TaskStatus {
  pending, // Beklemede (atandı)
  inProgress, // Devam ediyor
  completed, // Tamamlandı (onay bekliyor)
  approved, // Onaylandı
}

extension TaskStatusExtension on TaskStatus {
  String get dbValue {
    switch (this) {
      case TaskStatus.pending:
        return 'atandi';
      case TaskStatus.inProgress:
        return 'devam_ediyor';
      case TaskStatus.completed:
        return 'tamamlandi';
      case TaskStatus.approved:
        return 'onaylandi';
    }
  }

  static TaskStatus fromDb(String? value) {
    switch (value) {
      case 'devam_ediyor':
        return TaskStatus.inProgress;
      case 'tamamlandi':
        return TaskStatus.completed;
      case 'onaylandi':
        return TaskStatus.approved;
      case 'atandi':
      default:
        return TaskStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case TaskStatus.pending:
        return 'Beklemede';
      case TaskStatus.inProgress:
        return 'Devam Ediyor';
      case TaskStatus.completed:
        return 'Tamamlandı';
      case TaskStatus.approved:
        return 'Onaylandı';
    }
  }

  String get emoji {
    switch (this) {
      case TaskStatus.pending:
        return '⭕';
      case TaskStatus.inProgress:
        return '🔄';
      case TaskStatus.completed:
        return '✅';
      case TaskStatus.approved:
        return '🏆';
    }
  }
}

/// Görev önceliği
enum TaskPriority {
  low,
  medium,
  high,
}

extension TaskPriorityExtension on TaskPriority {
  String get dbValue {
    switch (this) {
      case TaskPriority.low:
        return 'dusuk';
      case TaskPriority.medium:
        return 'orta';
      case TaskPriority.high:
        return 'yuksek';
    }
  }

  static TaskPriority fromDb(String? value) {
    switch (value) {
      case 'yuksek':
        return TaskPriority.high;
      case 'dusuk':
        return TaskPriority.low;
      case 'orta':
      default:
        return TaskPriority.medium;
    }
  }

  String get label {
    switch (this) {
      case TaskPriority.low:
        return 'Düşük';
      case TaskPriority.medium:
        return 'Orta';
      case TaskPriority.high:
        return 'Yüksek';
    }
  }

  String get emoji {
    switch (this) {
      case TaskPriority.low:
        return '🟢';
      case TaskPriority.medium:
        return '🟡';
      case TaskPriority.high:
        return '🔴';
    }
  }
}

/// Görev modeli
@immutable
class Task {
  const Task({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.createdBy,
    required this.status,
    required this.priority,
    required this.createdAt,
    required this.updatedAt,
    this.branchId,
    this.description,
    this.dueDate,
    this.completedAt,
    this.approvedAt,
    this.approvedBy,
    this.parentTaskId,
    this.sourceTaskId,
    this.completionPercentage = 0,
    this.sortOrder = 0,
    this.isArchived = false,
    this.creatorName,
    this.creatorRole,
    this.branchName,
    this.approverName,
    this.assignees = const [],
    this.attachments = const [],
  });

  final String id;
  final String tenantId;
  final String? branchId;
  final String title;
  final String? description;
  final String createdBy;
  final TaskStatus status;
  final TaskPriority priority;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final DateTime? approvedAt;
  final String? approvedBy;
  final String? parentTaskId;
  final String? sourceTaskId; // İletilen görevin orijinali
  final int completionPercentage;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  // İlişkili veriler
  final String? creatorName;
  final String? creatorRole;
  final String? branchName;
  final String? approverName;
  final List<TaskAssignee> assignees;
  final List<TaskAttachment> attachments;

  /// Ana görev mi? (parent yok)
  bool get isMainQuest => parentTaskId == null;

  /// İletilmiş görev mi?
  bool get isForwarded => sourceTaskId != null;

  /// Tamamlanma oranı (0.0 - 1.0)
  double get progress => completionPercentage / 100.0;

  /// Gecikmiş mi?
  bool get isOverdue {
    if (dueDate == null) return false;
    if (status == TaskStatus.approved) return false;
    return DateTime.now().isAfter(dueDate!);
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String?,
      title: map['title'] as String,
      description: map['description'] as String?,
      createdBy: map['created_by'] as String,
      status: TaskStatusExtension.fromDb(map['status'] as String?),
      priority: TaskPriorityExtension.fromDb(map['priority'] as String?),
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      completedAt: map['completed_at'] != null
          ? DateTime.tryParse(map['completed_at'] as String)
          : null,
      approvedAt: map['approved_at'] != null
          ? DateTime.tryParse(map['approved_at'] as String)
          : null,
      approvedBy: map['approved_by'] as String?,
      parentTaskId: map['parent_task_id'] as String?,
      sourceTaskId: map['source_task_id'] as String?,
      completionPercentage: map['completion_percentage'] as int? ?? 0,
      sortOrder: map['sort_order'] as int? ?? 0,
      isArchived: map['is_archived'] as bool? ?? false,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      creatorName: map['creator_name'] as String?,
      creatorRole: map['creator_role'] as String?,
      branchName: map['branch_name'] as String?,
      approverName: map['approver_name'] as String?,
    );
  }

  Task copyWith({
    TaskStatus? status,
    int? completionPercentage,
    bool? isArchived,
    List<TaskAssignee>? assignees,
    List<TaskAttachment>? attachments,
  }) {
    return Task(
      id: id,
      tenantId: tenantId,
      branchId: branchId,
      title: title,
      description: description,
      createdBy: createdBy,
      status: status ?? this.status,
      priority: priority,
      dueDate: dueDate,
      completedAt: completedAt,
      approvedAt: approvedAt,
      approvedBy: approvedBy,
      parentTaskId: parentTaskId,
      sourceTaskId: sourceTaskId,
      completionPercentage: completionPercentage ?? this.completionPercentage,
      sortOrder: sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt,
      creatorName: creatorName,
      creatorRole: creatorRole,
      branchName: branchName,
      approverName: approverName,
      assignees: assignees ?? this.assignees,
      attachments: attachments ?? this.attachments,
    );
  }
}

/// Görev ağacı düğümü
@immutable
class TaskNode {
  const TaskNode({
    required this.task,
    this.children = const [],
  });

  final Task task;
  final List<TaskNode> children;

  /// Alt görev sayısı (tüm seviyeler)
  int get totalDescendants {
    var count = children.length;
    for (final child in children) {
      count += child.totalDescendants;
    }
    return count;
  }

  /// Tamamlanan alt görev sayısı
  int get completedDescendants {
    var count = 0;
    for (final child in children) {
      if (child.task.status == TaskStatus.completed ||
          child.task.status == TaskStatus.approved) {
        count++;
      }
      count += child.completedDescendants;
    }
    return count;
  }

  /// İlerleme yüzdesi (alt görevlere göre)
  double get progress {
    if (children.isEmpty) {
      return task.progress;
    }
    final total = totalDescendants;
    if (total == 0) return 0;
    return completedDescendants / total;
  }

  /// Görev ağacını oluştur
  static List<TaskNode> buildTree(List<Task> tasks) {
    final byParent = <String?, List<Task>>{};
    for (final task in tasks) {
      byParent.putIfAbsent(task.parentTaskId, () => []).add(task);
    }

    TaskNode buildNode(Task task) {
      final childTasks = byParent[task.id] ?? [];
      childTasks.sort((a, b) {
        final orderCompare = a.sortOrder.compareTo(b.sortOrder);
        if (orderCompare != 0) return orderCompare;
        return a.createdAt.compareTo(b.createdAt);
      });
      return TaskNode(
        task: task,
        children: childTasks.map(buildNode).toList(),
      );
    }

    final roots = byParent[null] ?? [];
    roots.sort((a, b) {
      final orderCompare = a.sortOrder.compareTo(b.sortOrder);
      if (orderCompare != 0) return orderCompare;
      return a.createdAt.compareTo(b.createdAt);
    });
    return roots.map(buildNode).toList();
  }
}

/// Görev atanan kişi
@immutable
class TaskAssignee {
  const TaskAssignee({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.assignedAt,
    this.userName,
    this.userRole,
  });

  final String id;
  final String taskId;
  final String userId;
  final DateTime assignedAt;
  final String? userName;
  final String? userRole;

  factory TaskAssignee.fromMap(Map<String, dynamic> map) {
    return TaskAssignee(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      userId: map['user_id'] as String,
      assignedAt: DateTime.parse(map['assigned_at'] as String),
      userName: map['user_name'] as String?,
      userRole: map['user_role'] as String?,
    );
  }
}

/// Görev eki (fotoğraf/dosya)
@immutable
class TaskAttachment {
  const TaskAttachment({
    required this.id,
    required this.taskId,
    required this.fileUrl,
    required this.fileName,
    required this.uploadedBy,
    required this.createdAt,
    this.fileType,
    this.fileSize,
    this.uploaderName,
  });

  final String id;
  final String taskId;
  final String fileUrl;
  final String fileName;
  final String? fileType;
  final int? fileSize;
  final String uploadedBy;
  final DateTime createdAt;
  final String? uploaderName;

  bool get isImage {
    if (fileType == null) return false;
    return fileType!.startsWith('image/');
  }

  factory TaskAttachment.fromMap(Map<String, dynamic> map) {
    return TaskAttachment(
      id: map['id'] as String,
      taskId: map['task_id'] as String,
      fileUrl: map['file_url'] as String,
      fileName: map['file_name'] as String,
      fileType: map['file_type'] as String?,
      fileSize: map['file_size'] as int?,
      uploadedBy: map['uploaded_by'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      uploaderName: map['uploader_name'] as String?,
    );
  }
}

/// Görev oluşturma için draft
class TaskDraft {
  TaskDraft({
    this.title = '',
    this.description,
    this.priority = TaskPriority.medium,
    this.dueDate,
    this.children = const [],
  });

  String title;
  String? description;
  TaskPriority priority;
  DateTime? dueDate;
  List<TaskDraft> children;

  bool get isValid => title.trim().isNotEmpty;

  Map<String, dynamic> toPayload({
    required String tenantId,
    required String creatorId,
    String? branchId,
    String? parentTaskId,
    String? sourceTaskId,
    int sortOrder = 0,
  }) {
    return {
      'tenant_id': tenantId,
      'created_by': creatorId,
      'branch_id': branchId,
      'title': title.trim(),
      'description': description?.trim(),
      'priority': priority.dbValue,
      'due_date': dueDate?.toIso8601String(),
      'parent_task_id': parentTaskId,
      'source_task_id': sourceTaskId,
      'sort_order': sortOrder,
    }..removeWhere((key, value) => value == null);
  }
}
