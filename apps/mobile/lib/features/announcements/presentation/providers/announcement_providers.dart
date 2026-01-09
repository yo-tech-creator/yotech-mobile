import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:yotech_mobile/features/announcements/data/models/announcement.dart';
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
  return items.where((a) => a.coverImageUrl != null).toList();
});
