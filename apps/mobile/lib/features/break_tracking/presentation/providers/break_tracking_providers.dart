import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/auth/domain/providers/auth_provider.dart';
import 'package:yotech_mobile/features/break_tracking/data/models/break_session.dart';
import 'package:yotech_mobile/features/break_tracking/data/repositories/break_tracking_repository.dart';

final breakTrackingRepositoryProvider =
    Provider<BreakTrackingRepository>((ref) {
  return BreakTrackingRepository(Supabase.instance.client);
});

class BreakSessionController extends AsyncNotifier<BreakSession?> {
  @override
  FutureOr<BreakSession?> build() async {
    final user =
        ref.watch(authProvider).mapOrNull(authenticated: (state) => state.user);
    if (user == null) return null;
    final repository = ref.read(breakTrackingRepositoryProvider);
    return repository.fetchActiveSession(user.id);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => await build());
  }

  Future<void> startBreak() async {
    final user =
        ref.read(authProvider).mapOrNull(authenticated: (state) => state.user);
    if (user == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }
    final repository = ref.read(breakTrackingRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final session = await repository.startBreak(user.id);
      return session;
    });
  }

  Future<void> endBreak() async {
    final user =
        ref.read(authProvider).mapOrNull(authenticated: (state) => state.user);
    if (user == null) {
      throw Exception('Kullanıcı oturumu bulunamadı');
    }
    final repository = ref.read(breakTrackingRepositoryProvider);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await repository.endBreak(user.id);
      return null;
    });
  }
}

final breakSessionProvider =
    AsyncNotifierProvider<BreakSessionController, BreakSession?>(() {
  return BreakSessionController();
});

final breakHistoryProvider =
    FutureProvider.autoDispose<List<BreakSession>>((ref) async {
  final user =
      ref.watch(authProvider).mapOrNull(authenticated: (state) => state.user);
  if (user == null) return const [];
  final repository = ref.read(breakTrackingRepositoryProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  return repository.fetchRecentSessions(userId: user.id, since: startOfDay);
});

/// Provider for break history with date filter
final breakHistoryWithDateProvider = FutureProvider.autoDispose
    .family<List<BreakSession>, DateTime?>((ref, date) async {
  final user =
      ref.watch(authProvider).mapOrNull(authenticated: (state) => state.user);
  if (user == null) return const [];
  final repository = ref.read(breakTrackingRepositoryProvider);

  DateTime? since;
  if (date != null) {
    since = DateTime(date.year, date.month, date.day);
  }

  return repository.fetchRecentSessions(
    userId: user.id,
    since: since,
    limit: 50,
  );
});

/// Provider for team break sessions (for managers)
final teamBreakSessionsProvider = FutureProvider.autoDispose
    .family<List<BreakSession>, DateTime?>((ref, date) async {
  final authState = ref.watch(authProvider);
  final user = authState.mapOrNull(authenticated: (state) => state.user);
  if (user == null) return const [];

  // Only managers can see team breaks
  final role = user.role;
  if (role != 'sube_muduru' &&
      role != 'bolge_muduru' &&
      role != 'firma_admin') {
    return const [];
  }

  final repository = ref.read(breakTrackingRepositoryProvider);

  DateTime? since;
  if (date != null) {
    since = DateTime(date.year, date.month, date.day);
  }

  // Fetch team breaks
  List<BreakSession> sessions = await repository.fetchTeamBreakSessions(
    userId: user.id,
    since: since,
    limit: 200,
  );

  // Fetch user names
  final userIds = sessions.map((s) => s.userId).toSet().toList();
  final names = await repository.fetchUserNames(userIds, user.tenantId);

  // Add user names to sessions
  sessions = sessions.map((s) {
    return s.copyWith(userName: names[s.userId]);
  }).toList();

  return sessions;
});
