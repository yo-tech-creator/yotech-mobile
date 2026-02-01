/// Survey question type enum
enum SurveyQuestionType {
  text,
  textarea,
  singleChoice,
  multipleChoice,
  rating,
  number,
  boolean;

  static SurveyQuestionType fromString(String? value) {
    switch (value) {
      case 'textarea':
        return SurveyQuestionType.textarea;
      case 'single_choice':
        return SurveyQuestionType.singleChoice;
      case 'multiple_choice':
        return SurveyQuestionType.multipleChoice;
      case 'rating':
        return SurveyQuestionType.rating;
      case 'number':
        return SurveyQuestionType.number;
      case 'boolean':
      case 'yes_no':
        return SurveyQuestionType.boolean;
      default:
        return SurveyQuestionType.text;
    }
  }

  String toJson() {
    switch (this) {
      case SurveyQuestionType.textarea:
        return 'textarea';
      case SurveyQuestionType.singleChoice:
        return 'single_choice';
      case SurveyQuestionType.multipleChoice:
        return 'multiple_choice';
      case SurveyQuestionType.rating:
        return 'rating';
      case SurveyQuestionType.number:
        return 'number';
      case SurveyQuestionType.boolean:
        return 'boolean';
      default:
        return 'text';
    }
  }
}

class SurveyQuestion {
  const SurveyQuestion({
    required this.id,
    required this.announcementId,
    required this.questionText,
    required this.questionType,
    required this.sortOrder,
    this.options,
    this.required = true,
  });

  final String id;
  final String announcementId;
  final String questionText;
  final SurveyQuestionType questionType;
  final List<String>? options;
  final bool required;
  final int sortOrder;

  factory SurveyQuestion.fromJson(Map<String, dynamic> json) {
    return SurveyQuestion(
      id: json['id'].toString(),
      announcementId: json['announcement_id'] as String? ?? '',
      questionText: json['question_text'] as String? ?? '',
      questionType:
          SurveyQuestionType.fromString(json['question_type'] as String?),
      options: (json['options'] as List<dynamic>?)?.cast<String>(),
      required: json['required'] as bool? ?? true,
      sortOrder: json['sort_order'] as int? ?? 0,
    );
  }
}

/// Answer model for survey submission
class SurveyAnswer {
  const SurveyAnswer({
    required this.questionId,
    this.answerText,
    this.answerOptions,
    this.answerRating,
    this.answerBoolean,
  });

  final String questionId;
  final String? answerText;
  final List<String>? answerOptions;
  final int? answerRating;
  final bool? answerBoolean;

  Map<String, dynamic> toJson() {
    return {
      'question_id': questionId,
      if (answerText != null) 'answer_text': answerText,
      if (answerOptions != null) 'answer_options': answerOptions,
      if (answerRating != null) 'answer_rating': answerRating,
      if (answerBoolean != null) 'answer_boolean': answerBoolean,
    };
  }
}
