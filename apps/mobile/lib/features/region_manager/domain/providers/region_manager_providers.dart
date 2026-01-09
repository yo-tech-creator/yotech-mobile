import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/providers/auth_provider.dart';
import '../../data/region_manager_repository.dart';
import '../../data/region_manager_staff_repository.dart';
import '../../data/region_manager_task_repository.dart';
import '../../data/store_scoring_repository.dart';
import '../models/branch_task_node.dart';
import '../models/branch_personnel.dart';
import '../models/managed_branch.dart';
import '../models/manager_todo_node.dart';
import '../models/store_scoring_models.dart';

class BranchTaskScope {
  BranchTaskScope(Iterable<String> ids)
      : branchIds = List.unmodifiable((ids.toSet().toList())..sort());

  final List<String> branchIds;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BranchTaskScope) return false;
    if (branchIds.length != other.branchIds.length) return false;
    for (var i = 0; i < branchIds.length; i++) {
      if (branchIds[i] != other.branchIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(branchIds);
}

class BranchPersonnelScope {
  const BranchPersonnelScope(this.branchId);

  final String branchId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BranchPersonnelScope) return false;
    return branchId == other.branchId;
  }

  @override
  int get hashCode => branchId.hashCode;
}

final regionManagerRepositoryProvider =
    Provider<RegionManagerRepository>((ref) {
  return RegionManagerRepository(Supabase.instance.client);
});

final regionManagerBranchesProvider =
    FutureProvider.autoDispose<List<ManagedBranch>>((ref) async {
  final authState = ref.watch(authProvider);
  final repository = ref.watch(regionManagerRepositoryProvider);

  return authState.maybeWhen<Future<List<ManagedBranch>>>(
    authenticated: (user) async {
      if (user.role != 'bolge_muduru') {
        return <ManagedBranch>[];
      }
      return repository.fetchManagedBranches(
        tenantId: user.tenantId,
        managerId: user.id,
      );
    },
    orElse: () async => <ManagedBranch>[],
  );
});

final regionManagerTaskRepositoryProvider =
    Provider<RegionManagerTaskRepository>((ref) {
  return RegionManagerTaskRepository(Supabase.instance.client);
});

final regionManagerStaffRepositoryProvider =
    Provider<RegionManagerStaffRepository>((ref) {
  return RegionManagerStaffRepository(Supabase.instance.client);
});

final storeScoringRepositoryProvider = Provider<StoreScoringRepository>((ref) {
  return StoreScoringRepository(Supabase.instance.client);
});

final regionBranchTaskTreeProvider =
    FutureProvider.autoDispose.family<List<BranchTaskNode>, BranchTaskScope>(
  (ref, scope) async {
    final authState = ref.watch(authProvider);
    final repository = ref.watch(regionManagerTaskRepositoryProvider);

    return authState.maybeWhen<Future<List<BranchTaskNode>>>(
      authenticated: (user) async {
        if (user.role != 'bolge_muduru' || scope.branchIds.isEmpty) {
          return const <BranchTaskNode>[];
        }
        return repository.fetchBranchTaskTree(
          tenantId: user.tenantId,
          managerId: user.id,
          branchIds: scope.branchIds,
        );
      },
      orElse: () async => const <BranchTaskNode>[],
    );
  },
);

final storeScoringFormsProvider =
    FutureProvider.autoDispose<List<StoreScoringForm>>((ref) async {
  final authState = ref.watch(authProvider);
  final repository = ref.watch(storeScoringRepositoryProvider);

  return authState.maybeWhen<Future<List<StoreScoringForm>>>(
    authenticated: (user) async {
      return repository.fetchPublishedForms(tenantId: user.tenantId);
    },
    orElse: () async => const <StoreScoringForm>[],
  );
});

class StoreScoringHistoryScope {
  const StoreScoringHistoryScope({
    required this.branchId,
    required this.tenantId,
  });

  final String branchId;
  final String tenantId;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! StoreScoringHistoryScope) return false;
    return branchId == other.branchId && tenantId == other.tenantId;
  }

  @override
  int get hashCode => Object.hash(branchId, tenantId);
}

final storeScoringHistoryProvider = FutureProvider.autoDispose
    .family<List<StoreScoringSessionSummary>, StoreScoringHistoryScope>(
  (ref, scope) async {
    if (scope.branchId.isEmpty) {
      return const <StoreScoringSessionSummary>[];
    }

    final repository = ref.watch(storeScoringRepositoryProvider);

    return repository.fetchBranchSessions(
      tenantId: scope.tenantId,
      branchId: scope.branchId,
    );
  },
);

final regionManagerTodoTreeProvider =
    FutureProvider.autoDispose<List<ManagerTodoNode>>((ref) async {
  final authState = ref.watch(authProvider);
  final repository = ref.watch(regionManagerTaskRepositoryProvider);

  return authState.maybeWhen<Future<List<ManagerTodoNode>>>(
    authenticated: (user) async {
      if (user.role != 'bolge_muduru') {
        return const <ManagerTodoNode>[];
      }
      return repository.fetchManagerTodoTree(
        tenantId: user.tenantId,
        managerId: user.id,
      );
    },
    orElse: () async => const <ManagerTodoNode>[],
  );
});

final branchPersonnelProvider = FutureProvider.autoDispose
    .family<List<BranchPersonnel>, BranchPersonnelScope>(
  (ref, scope) async {
    final authState = ref.watch(authProvider);
    final repository = ref.watch(regionManagerStaffRepositoryProvider);

    return authState.maybeWhen<Future<List<BranchPersonnel>>>(
      authenticated: (user) async {
        if (user.role != 'bolge_muduru') {
          return const <BranchPersonnel>[];
        }
        return repository.fetchBranchPersonnel(
          tenantId: user.tenantId,
          branchId: scope.branchId,
        );
      },
      orElse: () async => const <BranchPersonnel>[],
    );
  },
);
