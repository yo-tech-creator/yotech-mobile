/// Talep transfer modeli
class RequestTransfer {
  const RequestTransfer({
    required this.id,
    required this.tenantId,
    required this.requestId,
    required this.fromUserId,
    required this.toUserId,
    this.reason,
    required this.status,
    this.respondedAt,
    required this.createdAt,
    required this.updatedAt,
    this.fromUserName,
    this.toUserName,
    this.requestTitle,
  });

  final String id;
  final String tenantId;
  final String requestId;
  final String fromUserId;
  final String toUserId;
  final String? reason;
  final TransferStatus status;
  final DateTime? respondedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Join'den gelen ek bilgiler
  final String? fromUserName;
  final String? toUserName;
  final String? requestTitle;

  factory RequestTransfer.fromMap(Map<String, dynamic> map) {
    return RequestTransfer(
      id: map['id'] as String,
      tenantId: map['tenant_id'] as String,
      requestId: map['request_id'] as String,
      fromUserId: map['from_user_id'] as String,
      toUserId: map['to_user_id'] as String,
      reason: map['reason'] as String?,
      status: TransferStatusX.fromValue(map['status'] as String),
      respondedAt: map['responded_at'] == null
          ? null
          : DateTime.parse(map['responded_at'] as String).toLocal(),
      createdAt: DateTime.parse(map['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(map['updated_at'] as String).toLocal(),
      fromUserName: map['from_user_name'] as String?,
      toUserName: map['to_user_name'] as String?,
      requestTitle: map['request_title'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tenant_id': tenantId,
      'request_id': requestId,
      'from_user_id': fromUserId,
      'to_user_id': toUserId,
      'reason': reason,
      'status': status.value,
      'responded_at': respondedAt?.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is RequestTransfer &&
            runtimeType == other.runtimeType &&
            other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

enum TransferStatus {
  pending,
  approved,
  rejected,
}

extension TransferStatusX on TransferStatus {
  String get value {
    switch (this) {
      case TransferStatus.pending:
        return 'pending';
      case TransferStatus.approved:
        return 'approved';
      case TransferStatus.rejected:
        return 'rejected';
    }
  }

  String get label {
    switch (this) {
      case TransferStatus.pending:
        return 'Bekliyor';
      case TransferStatus.approved:
        return 'Onaylandı';
      case TransferStatus.rejected:
        return 'Reddedildi';
    }
  }

  static TransferStatus fromValue(String value) {
    switch (value) {
      case 'pending':
        return TransferStatus.pending;
      case 'approved':
        return TransferStatus.approved;
      case 'rejected':
        return TransferStatus.rejected;
      default:
        return TransferStatus.pending;
    }
  }
}
