import 'package:collection/collection.dart';

enum BranchTaskStatus { pending, inProgress, completed }

BranchTaskStatus branchTaskStatusFromString(String value) {
  switch (value) {
    case 'devam_ediyor':
      return BranchTaskStatus.inProgress;
    case 'tamamlandi':
      return BranchTaskStatus.completed;
    case 'atandi':
    default:
      return BranchTaskStatus.pending;
  }
}

String branchTaskStatusToString(BranchTaskStatus status) {
  switch (status) {
    case BranchTaskStatus.pending:
      return 'atandi';
    case BranchTaskStatus.inProgress:
      return 'devam_ediyor';
    case BranchTaskStatus.completed:
      return 'tamamlandi';
  }
}

class BranchTaskRecord {
  BranchTaskRecord({
    required this.id,
    required this.tenantId,
    required this.managerId,
    required this.branchId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.description,
    this.dueDate,
    this.priority,
    this.sortOrder,
  });

  final String id;
  final String tenantId;
  final String managerId;
  final String branchId;
  final String title;
  final BranchTaskStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId;
  final String? description;
  final DateTime? dueDate;
  final String? priority;
  final int? sortOrder;

  factory BranchTaskRecord.fromMap(Map<String, dynamic> map) {
    return BranchTaskRecord(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      managerId: (map['created_by'] ?? map['manager_id']) as String,
      branchId: map['branch_id'] as String,
      title: map['title'] as String,
      status: branchTaskStatusFromString(map['status'] as String? ?? 'atandi'),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      parentId: map['parent_task_id'] as String?,
      description: map['description'] as String?,
      dueDate: map['due_date'] != null
          ? DateTime.tryParse(map['due_date'] as String)
          : null,
      priority: map['priority'] as String?,
      sortOrder: map['sort_order'] as int?,
    );
  }
}

class BranchTaskNode {
  BranchTaskNode({
    required this.record,
    required List<BranchTaskNode> children,
  }) : _children = children;

  final BranchTaskRecord record;
  final List<BranchTaskNode> _children;

  List<BranchTaskNode> get children => List.unmodifiable(_children);

  BranchTaskNode copyWith({
    BranchTaskRecord? record,
    List<BranchTaskNode>? children,
  }) {
    return BranchTaskNode(
      record: record ?? this.record,
      children: children ?? _children,
    );
  }

  static List<BranchTaskNode> buildTree(List<BranchTaskRecord> records) {
    final byParent = <String?, List<BranchTaskRecord>>{};
    for (final record in records) {
      byParent
          .putIfAbsent(record.parentId, () => <BranchTaskRecord>[])
          .add(record);
    }

    BranchTaskNode buildNode(BranchTaskRecord record) {
      final childRecords = byParent[record.id] ?? const <BranchTaskRecord>[];
      final sortedChildren = childRecords.sorted((a, b) {
        final orderA = a.sortOrder ?? 0;
        final orderB = b.sortOrder ?? 0;
        final orderCompare = orderA.compareTo(orderB);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return a.createdAt.compareTo(b.createdAt);
      });

      return BranchTaskNode(
        record: record,
        children: sortedChildren.map(buildNode).toList(),
      );
    }

    final roots = byParent[null] ?? const <BranchTaskRecord>[];
    final sortedRoots = roots.sorted((a, b) {
      final orderA = a.sortOrder ?? 0;
      final orderB = b.sortOrder ?? 0;
      final orderCompare = orderA.compareTo(orderB);
      if (orderCompare != 0) {
        return orderCompare;
      }
      return a.createdAt.compareTo(b.createdAt);
    });

    return sortedRoots.map(buildNode).toList();
  }
}
