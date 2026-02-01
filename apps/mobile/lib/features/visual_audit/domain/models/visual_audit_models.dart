/// Görsel Denetim Modeli
class VisualAuditTask {
  final String id;
  final String? templateId;
  final String templateName;
  final String sectionId;
  final String sectionName;
  final String sectionIcon;
  final String sectionColor;
  final DateTime scheduledDate;
  final String scheduledTime;
  final DateTime deadlineAt;
  final VisualAuditStatus status;
  final int photoCount;
  final int minPhotos;
  final String? completedBy;
  final DateTime? completedAt;
  final bool isOverdue;
  final String? notes;
  final String? title;

  VisualAuditTask({
    required this.id,
    this.templateId,
    required this.templateName,
    required this.sectionId,
    required this.sectionName,
    required this.sectionIcon,
    required this.sectionColor,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.deadlineAt,
    required this.status,
    required this.photoCount,
    required this.minPhotos,
    this.completedBy,
    this.completedAt,
    required this.isOverdue,
    this.notes,
    this.title,
  });

  factory VisualAuditTask.fromJson(Map<String, dynamic> json) {
    return VisualAuditTask(
      id: json['id'] as String,
      templateId: json['template_id'] as String?,
      templateName: json['template_name'] as String? ?? '',
      sectionId: json['section_id'] as String,
      sectionName: json['section_name'] as String? ?? '',
      sectionIcon: json['section_icon'] as String? ?? 'store',
      sectionColor: json['section_color'] as String? ?? '#3B82F6',
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      scheduledTime: json['scheduled_time'] as String,
      deadlineAt: DateTime.parse(json['deadline_at'] as String),
      status:
          VisualAuditStatus.fromString(json['status'] as String? ?? 'pending'),
      photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
      minPhotos: (json['min_photos'] as num?)?.toInt() ?? 1,
      completedBy: json['completed_by'] as String?,
      completedAt: json['completed_at'] != null
          ? DateTime.parse(json['completed_at'] as String)
          : null,
      isOverdue: json['is_overdue'] as bool? ?? false,
      notes: json['notes'] as String?,
      title: json['title'] as String?,
    );
  }

  bool get isCompleted =>
      status == VisualAuditStatus.completed ||
      status == VisualAuditStatus.approved;
  bool get needsMorePhotos => photoCount < minPhotos;

  /// Display title - prefer title, then template name, then section name
  String get displayTitle => title ?? templateName;

  String get displayTime {
    final parts = scheduledTime.split(':');
    if (parts.length >= 2) {
      return '${parts[0]}:${parts[1]}';
    }
    return scheduledTime;
  }
}

/// Görsel Denetim Fotoğrafı
class VisualAuditPhoto {
  final String id;
  final String photoUrl;
  final String? thumbnailUrl;
  final String? caption;
  final String uploadedBy;
  final String uploaderName;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  VisualAuditPhoto({
    required this.id,
    required this.photoUrl,
    this.thumbnailUrl,
    this.caption,
    required this.uploadedBy,
    required this.uploaderName,
    this.latitude,
    this.longitude,
    required this.createdAt,
  });

  factory VisualAuditPhoto.fromJson(Map<String, dynamic> json) {
    return VisualAuditPhoto(
      id: json['id'] as String,
      photoUrl: json['photo_url'] as String,
      thumbnailUrl: json['thumbnail_url'] as String?,
      caption: json['caption'] as String?,
      uploadedBy: json['uploaded_by'] as String,
      uploaderName: json['uploader_name'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

/// Görev Yorumu
class VisualAuditComment {
  final String id;
  final String userId;
  final String userName;
  final String userRole;
  final VisualAuditCommentType commentType;
  final String message;
  final String? photoId;
  final DateTime createdAt;

  VisualAuditComment({
    required this.id,
    required this.userId,
    required this.userName,
    required this.userRole,
    required this.commentType,
    required this.message,
    this.photoId,
    required this.createdAt,
  });

  factory VisualAuditComment.fromJson(Map<String, dynamic> json) {
    return VisualAuditComment(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      userName: json['user_name'] as String? ?? '',
      userRole: json['user_role'] as String? ?? 'personel',
      commentType: VisualAuditCommentType.fromString(
          json['comment_type'] as String? ?? 'comment'),
      message: json['message'] as String,
      photoId: json['photo_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isFromManager => userRole != 'personel';
}

/// Bölüm
class VisualAuditSection {
  final String id;
  final String name;
  final String? description;
  final String icon;
  final String color;
  final int displayOrder;
  final bool isActive;

  VisualAuditSection({
    required this.id,
    required this.name,
    this.description,
    required this.icon,
    required this.color,
    required this.displayOrder,
    required this.isActive,
  });

  factory VisualAuditSection.fromJson(Map<String, dynamic> json) {
    return VisualAuditSection(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      icon: json['icon'] as String? ?? 'store',
      color: json['color'] as String? ?? '#3B82F6',
      displayOrder: (json['display_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Durum Enum
enum VisualAuditStatus {
  pending,
  inProgress,
  completed,
  missed,
  approved,
  rejected;

  static VisualAuditStatus fromString(String value) {
    switch (value) {
      case 'pending':
        return VisualAuditStatus.pending;
      case 'in_progress':
        return VisualAuditStatus.inProgress;
      case 'completed':
        return VisualAuditStatus.completed;
      case 'missed':
        return VisualAuditStatus.missed;
      case 'approved':
        return VisualAuditStatus.approved;
      case 'rejected':
        return VisualAuditStatus.rejected;
      default:
        return VisualAuditStatus.pending;
    }
  }

  String get displayName {
    switch (this) {
      case VisualAuditStatus.pending:
        return 'Bekliyor';
      case VisualAuditStatus.inProgress:
        return 'Devam Ediyor';
      case VisualAuditStatus.completed:
        return 'Tamamlandı';
      case VisualAuditStatus.missed:
        return 'Kaçırıldı';
      case VisualAuditStatus.approved:
        return 'Onaylandı';
      case VisualAuditStatus.rejected:
        return 'Reddedildi';
    }
  }

  String get dbValue {
    switch (this) {
      case VisualAuditStatus.pending:
        return 'pending';
      case VisualAuditStatus.inProgress:
        return 'in_progress';
      case VisualAuditStatus.completed:
        return 'completed';
      case VisualAuditStatus.missed:
        return 'missed';
      case VisualAuditStatus.approved:
        return 'approved';
      case VisualAuditStatus.rejected:
        return 'rejected';
    }
  }
}

/// Yorum Tipi Enum
enum VisualAuditCommentType {
  comment,
  approval,
  rejection,
  revisionRequest;

  static VisualAuditCommentType fromString(String value) {
    switch (value) {
      case 'comment':
        return VisualAuditCommentType.comment;
      case 'approval':
        return VisualAuditCommentType.approval;
      case 'rejection':
        return VisualAuditCommentType.rejection;
      case 'revision_request':
        return VisualAuditCommentType.revisionRequest;
      default:
        return VisualAuditCommentType.comment;
    }
  }

  String get dbValue {
    switch (this) {
      case VisualAuditCommentType.comment:
        return 'comment';
      case VisualAuditCommentType.approval:
        return 'approval';
      case VisualAuditCommentType.rejection:
        return 'rejection';
      case VisualAuditCommentType.revisionRequest:
        return 'revision_request';
    }
  }
}
