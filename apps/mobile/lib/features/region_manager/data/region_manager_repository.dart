import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/managed_branch.dart';

class RegionManagerRepository {
  const RegionManagerRepository(this._client);

  final SupabaseClient _client;

  Future<List<ManagedBranch>> fetchManagedBranches({
    required String tenantId,
    required String managerId,
  }) async {
    try {
      final response = await _client
          .from('branches')
          .select(
              'id, name, city, code, manager_id, region:regions!inner(manager_id)')
          .eq('tenant_id', tenantId.trim())
          .eq('is_active', true)
          .eq('region.manager_id', managerId)
          .order('name');

      final rows = (response as List).cast<Map<String, dynamic>>();
      return rows.map(ManagedBranch.fromMap).toList();
    } catch (error, stackTrace) {
      throw FetchManagedBranchesException(error, stackTrace);
    }
  }
}

class FetchManagedBranchesException implements Exception {
  FetchManagedBranchesException(this.error, this.stackTrace);

  final Object error;
  final StackTrace stackTrace;
}
