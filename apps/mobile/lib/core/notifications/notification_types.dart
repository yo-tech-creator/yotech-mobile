/// Notification type enum - mirrors database enum
enum NotificationType {
  visualAuditTask('visual_audit_task'),
  visualAuditPhoto('visual_audit_photo'),
  visualAuditComment('visual_audit_comment'),
  visualAuditCompleted('visual_audit_completed'),
  taskAssigned('task_assigned'),
  taskCompleted('task_completed'),
  taskApproved('task_approved'),
  announcement('announcement'),
  survey('survey'),
  sktWarning('skt_warning'),
  depotTransfer('depot_transfer'),
  general('general');

  const NotificationType(this.value);
  final String value;

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.general,
    );
  }

  /// Get emoji for notification type
  String get emoji {
    switch (this) {
      case NotificationType.visualAuditTask:
        return '📸';
      case NotificationType.visualAuditPhoto:
        return '📷';
      case NotificationType.visualAuditComment:
        return '💬';
      case NotificationType.visualAuditCompleted:
        return '✅';
      case NotificationType.taskAssigned:
        return '📋';
      case NotificationType.taskCompleted:
        return '✔️';
      case NotificationType.taskApproved:
        return '🏆';
      case NotificationType.announcement:
        return '📢';
      case NotificationType.survey:
        return '📊';
      case NotificationType.sktWarning:
        return '⚠️';
      case NotificationType.depotTransfer:
        return '📦';
      case NotificationType.general:
        return '🔔';
    }
  }

  /// Get Turkish label
  String get label {
    switch (this) {
      case NotificationType.visualAuditTask:
        return 'Görsel Denetim';
      case NotificationType.visualAuditPhoto:
        return 'Fotoğraf Yüklendi';
      case NotificationType.visualAuditComment:
        return 'Yeni Yorum';
      case NotificationType.visualAuditCompleted:
        return 'Denetim Tamamlandı';
      case NotificationType.taskAssigned:
        return 'Yeni Görev';
      case NotificationType.taskCompleted:
        return 'Görev Tamamlandı';
      case NotificationType.taskApproved:
        return 'Görev Onaylandı';
      case NotificationType.announcement:
        return 'Duyuru';
      case NotificationType.survey:
        return 'Anket';
      case NotificationType.sktWarning:
        return 'SKT Uyarısı';
      case NotificationType.depotTransfer:
        return 'Depo Transfer';
      case NotificationType.general:
        return 'Bildirim';
    }
  }
}

/// Notification payload for navigation
class NotificationPayload {
  const NotificationPayload({
    required this.type,
    this.route,
    this.notificationId,
    this.taskId,
    this.branchId,
    this.photoId,
    this.commentId,
    this.announcementId,
    this.surveyId,
    this.extra = const {},
  });

  final NotificationType type;
  final String? route;
  final String? notificationId;
  final String? taskId;
  final String? branchId;
  final String? photoId;
  final String? commentId;
  final String? announcementId;
  final String? surveyId;
  final Map<String, dynamic> extra;

  factory NotificationPayload.fromMap(Map<String, dynamic> data) {
    return NotificationPayload(
      type: NotificationType.fromString(data['type'] as String?),
      route: data['route'] as String?,
      notificationId: data['notification_id'] as String?,
      taskId: data['task_id'] as String?,
      branchId: data['branch_id'] as String?,
      photoId: data['photo_id'] as String?,
      commentId: data['comment_id'] as String?,
      announcementId: data['announcement_id'] as String?,
      surveyId: data['survey_id'] as String?,
      extra: Map<String, dynamic>.from(data),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.value,
      if (route != null) 'route': route,
      if (notificationId != null) 'notification_id': notificationId,
      if (taskId != null) 'task_id': taskId,
      if (branchId != null) 'branch_id': branchId,
      if (photoId != null) 'photo_id': photoId,
      if (commentId != null) 'comment_id': commentId,
      if (announcementId != null) 'announcement_id': announcementId,
      if (surveyId != null) 'survey_id': surveyId,
      ...extra,
    };
  }

  @override
  String toString() =>
      'NotificationPayload(type: $type, route: $route, taskId: $taskId)';
}

/// Notification model for history/list
class NotificationItem {
  const NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.data = const {},
    this.readAt,
    required this.createdAt,
  });

  final String id;
  final NotificationType type;
  final String title;
  final String? body;
  final Map<String, dynamic> data;
  final DateTime? readAt;
  final DateTime createdAt;

  bool get isRead => readAt != null;

  factory NotificationItem.fromMap(Map<String, dynamic> map) {
    return NotificationItem(
      id: map['id'] as String,
      type: NotificationType.fromString(map['type'] as String?),
      title: map['title'] as String,
      body: map['body'] as String?,
      data: Map<String, dynamic>.from(map['data'] as Map? ?? {}),
      readAt: map['read_at'] != null
          ? DateTime.parse(map['read_at'] as String)
          : null,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  NotificationPayload toPayload() {
    return NotificationPayload.fromMap({
      'type': type.value,
      'notification_id': id,
      ...data,
    });
  }
}
