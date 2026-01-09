import 'package:collection/collection.dart';

enum StoreScoringItemResult { positive, negative, notApplicable }

StoreScoringItemResult resultFromDb(String value) {
  switch (value) {
    case 'positive':
      return StoreScoringItemResult.positive;
    case 'negative':
      return StoreScoringItemResult.negative;
    case 'not_applicable':
      return StoreScoringItemResult.notApplicable;
  }
  throw ArgumentError('Unsupported store scoring result: $value');
}

String resultToDb(StoreScoringItemResult result) {
  switch (result) {
    case StoreScoringItemResult.positive:
      return 'positive';
    case StoreScoringItemResult.negative:
      return 'negative';
    case StoreScoringItemResult.notApplicable:
      return 'not_applicable';
  }
}

class StoreScoringForm {
  const StoreScoringForm({
    required this.tenantId,
    required this.formVersionId,
    required this.formId,
    required this.code,
    required this.title,
    required this.description,
    required this.version,
    required this.publishedAt,
    required this.sections,
  });

  final String tenantId;
  final String formVersionId;
  final String formId;
  final String code;
  final String title;
  final String? description;
  final int version;
  final DateTime? publishedAt;
  final List<StoreScoringSection> sections;

  factory StoreScoringForm.fromViewRow(Map<String, dynamic> row) {
    final sectionsJson = row['sections'] as List<dynamic>? ?? const [];
    final sections = sectionsJson
        .map((dynamic value) => StoreScoringSection.fromJson(
              (value as Map<String, dynamic>?) ?? const {},
            ))
        .sorted((a, b) => a.order.compareTo(b.order))
        .toList();

    return StoreScoringForm(
      tenantId: row['tenant_id'] as String? ?? '',
      formVersionId: row['form_version_id'] as String? ?? '',
      formId: row['form_id'] as String? ?? '',
      code: row['code'] as String? ?? '',
      title: row['title'] as String? ?? '',
      description: row['description'] as String?,
      version: row['version'] as int? ?? 1,
      publishedAt: row['published_at'] != null
          ? DateTime.tryParse(row['published_at'] as String)
          : null,
      sections: sections,
    );
  }
}

class StoreScoringSection {
  const StoreScoringSection({
    required this.id,
    required this.title,
    required this.order,
    required this.items,
  });

  final String id;
  final String title;
  final int order;
  final List<StoreScoringItem> items;

  factory StoreScoringSection.fromJson(Map<String, dynamic> json) {
    final itemsJson = json['items'] as List<dynamic>? ?? const [];
    return StoreScoringSection(
      id: json['sectionId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      items: itemsJson
          .map((dynamic value) => StoreScoringItem.fromJson(
                (value as Map<String, dynamic>?) ?? const {},
              ))
          .sorted((a, b) => a.order.compareTo(b.order))
          .toList(),
    );
  }
}

class StoreScoringItem {
  const StoreScoringItem({
    required this.id,
    required this.label,
    required this.positivePoints,
    required this.negativePoints,
    required this.order,
    required this.isRequired,
  });

  final String id;
  final String label;
  final double positivePoints;
  final double negativePoints;
  final int order;
  final bool isRequired;

  factory StoreScoringItem.fromJson(Map<String, dynamic> json) {
    return StoreScoringItem(
      id: json['itemId'] as String? ?? '',
      label: json['label'] as String? ?? '',
      positivePoints: (json['positivePoints'] as num?)?.toDouble() ?? 0,
      negativePoints: (json['negativePoints'] as num?)?.toDouble() ?? 0,
      order: json['order'] as int? ?? 0,
      isRequired: json['isRequired'] as bool? ?? false,
    );
  }
}

class StoreScoringSessionSummary {
  const StoreScoringSessionSummary({
    required this.id,
    required this.branchId,
    required this.formVersionId,
    required this.formTitle,
    required this.formCode,
    required this.version,
    required this.totalPositive,
    required this.totalNegative,
    required this.totalPossible,
    required this.scoredAt,
    required this.createdAt,
    required this.notes,
  });

  final String id;
  final String branchId;
  final String formVersionId;
  final String formTitle;
  final String formCode;
  final int version;
  final double totalPositive;
  final double totalNegative;
  final double totalPossible;
  final DateTime scoredAt;
  final DateTime createdAt;
  final String? notes;

  factory StoreScoringSessionSummary.fromMap(Map<String, dynamic> map) {
    final formVersion =
        (map['form_version'] as Map<String, dynamic>?) ?? const {};
    final form = (formVersion['form'] as Map<String, dynamic>?) ?? const {};
    return StoreScoringSessionSummary(
      id: map['id'] as String,
      branchId: map['branch_id'] as String,
      formVersionId: map['form_version_id'] as String,
      formTitle: form['title'] as String? ?? '',
      formCode: form['code'] as String? ?? '',
      version: formVersion['version'] as int? ?? 1,
      totalPositive: (map['total_positive'] as num?)?.toDouble() ?? 0,
      totalNegative: (map['total_negative'] as num?)?.toDouble() ?? 0,
      totalPossible: (map['total_possible'] as num?)?.toDouble() ?? 0,
      scoredAt: DateTime.parse(map['scored_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      notes: map['notes'] as String?,
    );
  }
}

class StoreScoringSessionEntry {
  const StoreScoringSessionEntry({
    required this.itemId,
    required this.label,
    required this.result,
    required this.pointsAwarded,
    required this.comment,
  });

  final String itemId;
  final String label;
  final StoreScoringItemResult result;
  final double pointsAwarded;
  final String? comment;

  factory StoreScoringSessionEntry.fromMap(Map<String, dynamic> map) {
    final item = (map['item'] as Map<String, dynamic>?) ?? const {};
    return StoreScoringSessionEntry(
      itemId: map['item_id'] as String,
      label: item['label'] as String? ?? '',
      result: resultFromDb(map['result'] as String),
      pointsAwarded: (map['points_awarded'] as num?)?.toDouble() ?? 0,
      comment: map['comment'] as String?,
    );
  }
}

class StoreScoringSessionDetail extends StoreScoringSessionSummary {
  const StoreScoringSessionDetail({
    required super.id,
    required super.branchId,
    required super.formVersionId,
    required super.formTitle,
    required super.formCode,
    required super.version,
    required super.totalPositive,
    required super.totalNegative,
    required super.totalPossible,
    required super.scoredAt,
    required super.createdAt,
    required super.notes,
    required this.entries,
  });

  final List<StoreScoringSessionEntry> entries;

  factory StoreScoringSessionDetail.fromMap(Map<String, dynamic> map) {
    final summary = StoreScoringSessionSummary.fromMap(map);
    final sessions = (map['session_items'] as List<dynamic>? ?? const [])
        .map((dynamic value) => StoreScoringSessionEntry.fromMap(
              (value as Map<String, dynamic>?) ?? const {},
            ))
        .toList();
    return StoreScoringSessionDetail(
      id: summary.id,
      branchId: summary.branchId,
      formVersionId: summary.formVersionId,
      formTitle: summary.formTitle,
      formCode: summary.formCode,
      version: summary.version,
      totalPositive: summary.totalPositive,
      totalNegative: summary.totalNegative,
      totalPossible: summary.totalPossible,
      scoredAt: summary.scoredAt,
      createdAt: summary.createdAt,
      notes: summary.notes,
      entries: sessions,
    );
  }
}

class StoreScoringSubmissionEntry {
  const StoreScoringSubmissionEntry({
    required this.itemId,
    required this.result,
    required this.pointsAwarded,
    required this.positivePoints,
    required this.negativePoints,
    this.comment,
  });

  final String itemId;
  final StoreScoringItemResult result;
  final double pointsAwarded;
  final double positivePoints;
  final double negativePoints;
  final String? comment;
}

class StoreScoringSubmission {
  const StoreScoringSubmission({
    required this.tenantId,
    required this.branchId,
    required this.evaluatorId,
    required this.formVersionId,
    required this.scoredAt,
    required this.totalPositive,
    required this.totalNegative,
    required this.totalPossible,
    this.notes,
    required this.entries,
  });

  final String tenantId;
  final String branchId;
  final String evaluatorId;
  final String formVersionId;
  final DateTime scoredAt;
  final double totalPositive;
  final double totalNegative;
  final double totalPossible;
  final String? notes;
  final List<StoreScoringSubmissionEntry> entries;
}
