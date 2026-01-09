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
