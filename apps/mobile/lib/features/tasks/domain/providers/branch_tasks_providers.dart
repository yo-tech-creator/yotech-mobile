import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../auth/domain/models/user_model.dart';
import '../../../auth/domain/providers/auth_provider.dart';
import '../../../region_manager/domain/models/branch_task_node.dart';
import '../../data/branch_tasks_repository.dart';

final branchTasksRepositoryProvider = Provider<BranchTasksRepository>((ref) {
  return BranchTasksRepository(Supabase.instance.client);
});

final branchTaskTreeProvider =
    FutureProvider.autoDispose<List<BranchTaskNode>>((ref) async {
  final authState = ref.watch(authProvider);
  final repository = ref.watch(branchTasksRepositoryProvider);

  return authState.maybeWhen<Future<List<BranchTaskNode>>>(
    authenticated: (user) async =>
        _loadTasks(repository: repository, user: user),
    orElse: () async => const <BranchTaskNode>[],
  );
});

Future<List<BranchTaskNode>> _loadTasks({
  required BranchTasksRepository repository,
  required UserModel user,
}) async {
  if (user.branchId == null || user.branchId!.isEmpty) {
    return const <BranchTaskNode>[];
  }
  return repository.fetchBranchTasks(
    tenantId: user.tenantId,
    branchId: user.branchId!,
  );
}
