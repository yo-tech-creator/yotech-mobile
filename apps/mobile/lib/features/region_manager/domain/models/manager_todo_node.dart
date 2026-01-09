import 'package:collection/collection.dart';

enum ManagerTodoStatus { pending, completed }

ManagerTodoStatus managerTodoStatusFromString(String value) {
  switch (value) {
    case 'completed':
      return ManagerTodoStatus.completed;
    case 'pending':
    default:
      return ManagerTodoStatus.pending;
  }
}

String managerTodoStatusToString(ManagerTodoStatus status) {
  switch (status) {
    case ManagerTodoStatus.pending:
      return 'pending';
    case ManagerTodoStatus.completed:
      return 'completed';
  }
}

class ManagerTodoRecord {
  ManagerTodoRecord({
    required this.id,
    required this.tenantId,
    required this.ownerId,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
    this.description,
    this.sortOrder,
  });

  final String id;
  final String tenantId;
  final String ownerId;
  final String title;
  final ManagerTodoStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId;
  final String? description;
  final int? sortOrder;

  factory ManagerTodoRecord.fromMap(Map<String, dynamic> map) {
    return ManagerTodoRecord(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      ownerId: map['owner_id'] as String,
      title: map['title'] as String,
      status:
          managerTodoStatusFromString(map['status'] as String? ?? 'pending'),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      parentId: map['parent_id'] as String?,
      description: map['description'] as String?,
      sortOrder: map['sort_order'] as int?,
    );
  }
}

class ManagerTodoNode {
  ManagerTodoNode({
    required this.record,
    required List<ManagerTodoNode> children,
  }) : _children = children;

  final ManagerTodoRecord record;
  final List<ManagerTodoNode> _children;

  List<ManagerTodoNode> get children => List.unmodifiable(_children);

  ManagerTodoNode copyWith({
    ManagerTodoRecord? record,
    List<ManagerTodoNode>? children,
  }) {
    return ManagerTodoNode(
      record: record ?? this.record,
      children: children ?? _children,
    );
  }

  static List<ManagerTodoNode> buildTree(List<ManagerTodoRecord> records) {
    final byParent = <String?, List<ManagerTodoRecord>>{};
    for (final record in records) {
      byParent
          .putIfAbsent(record.parentId, () => <ManagerTodoRecord>[])
          .add(record);
    }

    ManagerTodoNode buildNode(ManagerTodoRecord record) {
      final childRecords = byParent[record.id] ?? const <ManagerTodoRecord>[];
      final sortedChildren = childRecords.sorted((a, b) {
        final orderA = a.sortOrder ?? 0;
        final orderB = b.sortOrder ?? 0;
        final orderCompare = orderA.compareTo(orderB);
        if (orderCompare != 0) {
          return orderCompare;
        }
        return a.createdAt.compareTo(b.createdAt);
      });

      return ManagerTodoNode(
        record: record,
        children: sortedChildren.map(buildNode).toList(),
      );
    }

    final roots = byParent[null] ?? const <ManagerTodoRecord>[];
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
