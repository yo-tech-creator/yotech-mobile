import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/announcements/data/models/announcement.dart';
import 'package:yotech_mobile/features/announcements/data/models/survey_question.dart';
import 'package:yotech_mobile/features/announcements/data/repositories/announcements_repository.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';

final announcementsStreamProvider = StreamProvider<List<Announcement>>((ref) {
  final user = ref.watch(authProvider).mapOrNull(authenticated: (s) => s.user);
  if (user == null) {
    return const Stream<List<Announcement>>.empty();
  }
  final repository = ref.watch(announcementsRepositoryProvider);
  return repository.watchAnnouncements(user.tenantId);
});

final latestAnnouncementsProvider = Provider<List<Announcement>>((ref) {
  final stream = ref.watch(announcementsStreamProvider);
  return stream.maybeWhen(data: (items) => items, orElse: () => const []);
});

final pinnedAnnouncementsProvider = Provider<List<Announcement>>((ref) {
  final items = ref.watch(latestAnnouncementsProvider);
  return items.where((a) => a.pinned).toList();
});

/// Survey questions for a specific announcement
final surveyQuestionsProvider =
    FutureProvider.family<List<SurveyQuestion>, String>(
  (ref, announcementId) async {
    final repository = ref.watch(announcementsRepositoryProvider);
    return repository.getSurveyQuestions(announcementId);
  },
);

/// Check if user has responded to a survey
final hasUserRespondedProvider =
    FutureProvider.autoDispose.family<bool, String>(
  (ref, announcementId) async {
    final repository = ref.watch(announcementsRepositoryProvider);
    return repository.hasUserResponded(announcementId);
  },
);

/// Survey submission notifier
class SurveySubmissionNotifier extends StateNotifier<AsyncValue<void>> {
  SurveySubmissionNotifier(this._repository)
      : super(const AsyncValue.data(null));

  final AnnouncementsRepository _repository;

  Future<bool> submit({
    required String announcementId,
    required List<SurveyAnswer> answers,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _repository.submitSurveyResponse(
        announcementId: announcementId,
        answers: answers,
      );
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final surveySubmissionProvider =
    StateNotifierProvider<SurveySubmissionNotifier, AsyncValue<void>>((ref) {
  return SurveySubmissionNotifier(ref.watch(announcementsRepositoryProvider));
});
