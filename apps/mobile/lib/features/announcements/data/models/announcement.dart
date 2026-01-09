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
  });

  final String id;
  final String tenantId;
  final String title;
  final String content;
  final DateTime publishedAt;
  final String? summary;
  final String? coverImageUrl;
  final String? author;

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
    );
  }
}
