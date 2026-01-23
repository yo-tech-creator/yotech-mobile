import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/tasks_repository.dart';
import '../models/task_models.dart';
import '../../../auth/domain/providers/auth_provider.dart';

/// Tasks Repository Provider
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  return TasksRepository(Supabase.instance.client);
});

/// Aktif görevler (ana görevler + alt görevler ağacı)
final activeTasksProvider =
    FutureProvider.autoDispose<List<TaskNode>>((ref) async {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(tasksRepositoryProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      if (user.branchId == null || user.branchId!.isEmpty) {
        return [];
      }
      return repo.fetchActiveTasks(
        tenantId: user.tenantId,
        branchId: user.branchId,
      );
    },
    orElse: () => [],
  );
});

/// Tamamlanan görevler (onay bekleyen + onaylanan)
final completedTasksProvider =
    FutureProvider.autoDispose<List<TaskNode>>((ref) async {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(tasksRepositoryProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      if (user.branchId == null || user.branchId!.isEmpty) {
        return [];
      }
      return repo.fetchCompletedTasks(
        tenantId: user.tenantId,
        branchId: user.branchId,
      );
    },
    orElse: () => [],
  );
});

/// Arşivlenmiş görevler
final archivedTasksProvider =
    FutureProvider.autoDispose<List<TaskNode>>((ref) async {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(tasksRepositoryProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      if (user.branchId == null || user.branchId!.isEmpty) {
        return [];
      }
      return repo.fetchArchivedTasks(
        tenantId: user.tenantId,
        branchId: user.branchId,
      );
    },
    orElse: () => [],
  );
});

/// Oluşturduğum görevler
final myCreatedTasksProvider =
    FutureProvider.autoDispose<List<TaskNode>>((ref) async {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(tasksRepositoryProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      return repo.fetchMyCreatedTasks(
        tenantId: user.tenantId,
        userId: user.id,
      );
    },
    orElse: () => [],
  );
});

/// Bana atanan görevler
final assignedToMeProvider =
    FutureProvider.autoDispose<List<TaskNode>>((ref) async {
  final authState = ref.watch(authProvider);
  final repo = ref.watch(tasksRepositoryProvider);

  return authState.maybeWhen(
    authenticated: (user) async {
      return repo.fetchAssignedToMe(
        tenantId: user.tenantId,
        userId: user.id,
      );
    },
    orElse: () => [],
  );
});

/// Görev ekleri
final taskAttachmentsProvider = FutureProvider.autoDispose
    .family<List<TaskAttachment>, String>((ref, taskId) async {
  final repo = ref.watch(tasksRepositoryProvider);
  return repo.fetchAttachments(taskId: taskId);
});

/// Görev atananları
final taskAssigneesProvider = FutureProvider.autoDispose
    .family<List<TaskAssignee>, String>((ref, taskId) async {
  final repo = ref.watch(tasksRepositoryProvider);
  return repo.fetchAssignees(taskId: taskId);
});
