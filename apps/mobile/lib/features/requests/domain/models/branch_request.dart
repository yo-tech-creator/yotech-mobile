import 'request_category.dart';
import 'request_status.dart';

class BranchRequest {
  const BranchRequest({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.createdBy,
    required this.category,
    required this.status,
    required this.title,
    this.description,
    this.payload,
    this.targetDepartment,
    this.targetUserId,
    this.resolvedBy,
    this.resolvedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String branchId;
  final String createdBy;
  final RequestCategory category;
  final RequestStatus status;
  final String title;
  final String? description;
  final Map<String, dynamic>? payload;
  final String? targetDepartment;
  final String? targetUserId;
  final String? resolvedBy;
  final DateTime? resolvedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory BranchRequest.fromMap(Map<String, dynamic> map) {
    return BranchRequest(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      branchId: map['branch_id'] as String,
      createdBy: map['created_by'] as String,
      category: RequestCategoryX.fromValue(map['category'] as String),
      status: RequestStatusX.fromValue(map['status'] as String),
      title: map['title'] as String,
      description: map['description'] as String?,
      payload: map['payload'] == null
          ? null
          : Map<String, dynamic>.from(map['payload'] as Map),
      targetDepartment: map['target_department'] as String?,
      targetUserId: map['target_user_id'] as String?,
      resolvedBy: map['resolved_by'] as String?,
      resolvedAt: map['resolved_at'] == null
          ? null
          : DateTime.parse(map['resolved_at'] as String).toLocal(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'branch_id': branchId,
      'created_by': createdBy,
      'category': category.value,
      'status': status.value,
      'title': title,
      'description': description,
      'payload': payload,
      'target_department': targetDepartment,
      'target_user_id': targetUserId,
      'resolved_by': resolvedBy,
      'resolved_at': resolvedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }

  BranchRequest copyWith({
    RequestStatus? status,
    String? resolvedBy,
    DateTime? resolvedAt,
  }) {
    return BranchRequest(
      id: id,
      tenantId: tenantId,
      branchId: branchId,
      createdBy: createdBy,
      category: category,
      status: status ?? this.status,
      title: title,
      description: description,
      payload: payload == null ? null : Map<String, dynamic>.from(payload!),
      targetDepartment: targetDepartment,
      targetUserId: targetUserId,
      resolvedBy: resolvedBy ?? this.resolvedBy,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is BranchRequest &&
            runtimeType == other.runtimeType &&
            other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
