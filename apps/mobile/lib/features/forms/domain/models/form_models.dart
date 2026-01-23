import 'package:flutter/foundation.dart';

/// Yayınlanmış form modeli
@immutable
class PublishedForm {
  const PublishedForm({
    required this.formId,
    required this.formVersionId,
    required this.tenantId,
    required this.code,
    required this.title,
    this.description,
    required this.version,
    this.publishedAt,
    required this.sections,
    this.visibleRoles,
  });

  final String formId;
  final String formVersionId;
  final String tenantId;
  final String code;
  final String title;
  final String? description;
  final int version;
  final DateTime? publishedAt;
  final List<FormSection> sections;
  final List<String>? visibleRoles;

  factory PublishedForm.fromMap(Map<String, dynamic> map) {
    final sectionsRaw = map['sections'];
    List<FormSection> sections = [];

    if (sectionsRaw is List) {
      sections = sectionsRaw
          .map((s) => FormSection.fromMap(Map<String, dynamic>.from(s as Map)))
          .toList();
    }

    return PublishedForm(
      formId: map['form_id'] as String? ?? '',
      formVersionId: map['form_version_id'] as String? ?? '',
      tenantId: map['tenant_id'] as String? ?? '',
      code: map['code'] as String? ?? '',
      title: map['title'] as String? ?? 'İsimsiz Form',
      description: map['description'] as String?,
      version: map['version'] as int? ?? 1,
      publishedAt: map['published_at'] != null
          ? DateTime.tryParse(map['published_at'] as String)
          : null,
      sections: sections,
      visibleRoles: (map['visible_roles'] as List<dynamic>?)
          ?.map((e) => e as String)
          .toList(),
    );
  }

  int get totalItemCount =>
      sections.fold(0, (sum, section) => sum + section.items.length);
}

/// Form bölümü
@immutable
class FormSection {
  const FormSection({
    required this.id,
    required this.title,
    required this.orderIndex,
    required this.items,
  });

  final String id;
  final String title;
  final int orderIndex;
  final List<FormItem> items;

  factory FormSection.fromMap(Map<String, dynamic> map) {
    final itemsRaw = map['items'];
    List<FormItem> items = [];

    if (itemsRaw is List) {
      items = itemsRaw
          .map((i) => FormItem.fromMap(Map<String, dynamic>.from(i as Map)))
          .toList();
    }

    return FormSection(
      id: map['sectionId'] as String? ?? map['id'] as String? ?? '',
      title: map['title'] as String? ?? 'Bölüm',
      orderIndex: map['order'] as int? ?? map['order_index'] as int? ?? 0,
      items: items,
    );
  }
}

/// Form maddesi
@immutable
class FormItem {
  const FormItem({
    required this.id,
    required this.label,
    required this.positivePoints,
    required this.negativePoints,
    required this.orderIndex,
    required this.isRequired,
    this.metadata,
  });

  final String id;
  final String label;
  final double positivePoints;
  final double negativePoints;
  final int orderIndex;
  final bool isRequired;
  final Map<String, dynamic>? metadata;

  factory FormItem.fromMap(Map<String, dynamic> map) {
    return FormItem(
      id: map['itemId'] as String? ?? map['id'] as String? ?? '',
      label: map['label'] as String? ?? '',
      positivePoints: (map['positivePoints'] as num?)?.toDouble() ??
          (map['positive_points'] as num?)?.toDouble() ??
          0,
      negativePoints: (map['negativePoints'] as num?)?.toDouble() ??
          (map['negative_points'] as num?)?.toDouble() ??
          0,
      orderIndex: map['order'] as int? ?? map['order_index'] as int? ?? 0,
      isRequired:
          map['isRequired'] as bool? ?? map['is_required'] as bool? ?? false,
      metadata: map['metadata'] as Map<String, dynamic>?,
    );
  }
}

/// Form doldurma sonucu tipi
enum FormItemResult {
  positive,
  negative,
  neutral,
  notApplicable,
}

extension FormItemResultX on FormItemResult {
  String get label {
    switch (this) {
      case FormItemResult.positive:
        return 'Evet';
      case FormItemResult.negative:
        return 'Hayır';
      case FormItemResult.neutral:
        return 'Kısmen';
      case FormItemResult.notApplicable:
        return 'N/A';
    }
  }

  String get dbValue {
    switch (this) {
      case FormItemResult.positive:
        return 'positive';
      case FormItemResult.negative:
        return 'negative';
      case FormItemResult.neutral:
        return 'neutral';
      case FormItemResult.notApplicable:
        return 'not_applicable';
    }
  }

  static FormItemResult fromDbValue(String value) {
    switch (value) {
      case 'positive':
        return FormItemResult.positive;
      case 'negative':
        return FormItemResult.negative;
      case 'neutral':
        return FormItemResult.neutral;
      case 'not_applicable':
        return FormItemResult.notApplicable;
      default:
        return FormItemResult.neutral;
    }
  }
}

/// Tamamlanmış form oturumu
@immutable
class FormSession {
  const FormSession({
    required this.id,
    required this.formVersionId,
    required this.branchId,
    required this.evaluatorId,
    required this.totalPositive,
    required this.totalNegative,
    required this.totalPossible,
    this.notes,
    required this.scoredAt,
    this.formTitle,
    this.evaluatorName,
    this.branchName,
    this.branchManagerName,
    this.evaluatedUserId,
    this.evaluatedUserName,
  });

  final String id;
  final String formVersionId;
  final String branchId;
  final String evaluatorId;
  final double totalPositive;
  final double totalNegative;
  final double totalPossible;
  final String? notes;
  final DateTime scoredAt;
  final String? formTitle;
  final String? evaluatorName;
  final String? branchName;
  final String? branchManagerName;
  final String? evaluatedUserId;
  final String? evaluatedUserName;

  double get score {
    if (totalPossible == 0) return 0;
    return ((totalPositive - totalNegative) / totalPossible * 100)
        .clamp(0, 100);
  }

  factory FormSession.fromMap(Map<String, dynamic> map) {
    return FormSession(
      id: map['id'] as String? ?? '',
      formVersionId: map['form_version_id'] as String? ?? '',
      branchId: map['branch_id'] as String? ?? '',
      evaluatorId: map['evaluator_id'] as String? ?? '',
      totalPositive: (map['total_positive'] as num?)?.toDouble() ?? 0,
      totalNegative: (map['total_negative'] as num?)?.toDouble() ?? 0,
      totalPossible: (map['total_possible'] as num?)?.toDouble() ?? 0,
      notes: map['notes'] as String?,
      scoredAt: DateTime.tryParse(map['scored_at'] as String? ?? '') ??
          DateTime.now(),
      formTitle: map['form_title'] as String?,
      evaluatorName: map['evaluator_name'] as String?,
      branchName: map['branch_name'] as String?,
    );
  }
}

/// Form oturum maddesi cevabı
@immutable
class FormSessionItem {
  const FormSessionItem({
    required this.id,
    required this.sessionId,
    required this.itemId,
    required this.result,
    required this.pointsAwarded,
    this.comment,
  });

  final String id;
  final String sessionId;
  final String itemId;
  final FormItemResult result;
  final double pointsAwarded;
  final String? comment;

  factory FormSessionItem.fromMap(Map<String, dynamic> map) {
    return FormSessionItem(
      id: map['id'] as String? ?? '',
      sessionId: map['session_id'] as String? ?? '',
      itemId: map['item_id'] as String? ?? '',
      result: FormItemResultX.fromDbValue(map['result'] as String? ?? ''),
      pointsAwarded: (map['points_awarded'] as num?)?.toDouble() ?? 0,
      comment: map['comment'] as String?,
    );
  }
}
