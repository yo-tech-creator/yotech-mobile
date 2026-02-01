class BreakSession {
  const BreakSession({
    required this.id,
    required this.tenantId,
    required this.branchId,
    required this.userId,
    required this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.userName,
  });

  final String id;
  final String tenantId;
  final String branchId;
  final String userId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int? durationSeconds;
  final String? userName;

  bool get isActive => endedAt == null;

  Duration? get recordedDuration =>
      durationSeconds != null ? Duration(seconds: durationSeconds!) : null;

  BreakSession copyWith({String? userName}) {
    return BreakSession(
      id: id,
      tenantId: tenantId,
      branchId: branchId,
      userId: userId,
      startedAt: startedAt,
      endedAt: endedAt,
      durationSeconds: durationSeconds,
      userName: userName ?? this.userName,
    );
  }

  factory BreakSession.fromJson(Map<String, dynamic> json) {
    return BreakSession(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      userId: json['user_id'] as String,
      startedAt: DateTime.parse(json['started_at'] as String),
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      durationSeconds: json['duration_seconds'] as int?,
      userName: json['user_name'] as String?,
    );
  }
}
