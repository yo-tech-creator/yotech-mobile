/// Announcement type enum
enum AnnouncementType {
  announcement,
  survey;

  static AnnouncementType fromString(String? value) {
    switch (value) {
      case 'survey':
        return AnnouncementType.survey;
      default:
        return AnnouncementType.announcement;
    }
  }
}

class Announcement {
  const Announcement({
    required this.id,
    required this.tenantId,
    required this.title,
    required this.content,
    required this.publishedAt,
    this.summary,
    this.coverImageUrl,
    this.author,
    this.type = AnnouncementType.announcement,
    this.pinned = false,
    this.pinnedAt,
    this.priority = 2,
    this.expiresAt,
    this.questionCount = 0,
    this.hasResponded = false,
  });

  final String id;
  final String tenantId;
  final String title;
  final String content;
  final DateTime publishedAt;
  final String? summary;
  final String? coverImageUrl;
  final String? author;
  final AnnouncementType type;
  final bool pinned;
  final DateTime? pinnedAt;
  final int priority;
  final DateTime? expiresAt;
  final int questionCount;
  final bool hasResponded;

  bool get isSurvey => type == AnnouncementType.survey;
  bool get isExpired =>
      expiresAt != null && expiresAt!.isBefore(DateTime.now());

  String get displaySummary =>
      summary?.trim().isNotEmpty == true ? summary!.trim() : content;

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'].toString(),
      tenantId: json['tenant_id'] as String? ?? '',
      title: json['title'] as String? ?? 'Başlıksız',
      content: json['content'] as String? ?? json['body'] as String? ?? '',
      summary: json['summary'] as String?,
      coverImageUrl: json['cover_image_url'] as String?,
      author: json['author'] as String?,
      publishedAt: DateTime.tryParse(
            (json['published_at'] ?? json['created_at'])?.toString() ?? '',
          ) ??
          DateTime.now(),
      type: AnnouncementType.fromString(json['type'] as String?),
      pinned: json['pinned'] as bool? ?? false,
      pinnedAt: json['pinned_at'] != null
          ? DateTime.tryParse(json['pinned_at'].toString())
          : null,
      priority: json['priority'] as int? ?? 2,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
      questionCount: json['question_count'] as int? ?? 0,
      hasResponded: json['has_responded'] as bool? ?? false,
    );
  }
}
