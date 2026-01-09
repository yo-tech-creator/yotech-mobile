import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/providers/auth_provider.dart';
import '../domain/models/branch_request.dart';
import '../domain/models/request_category.dart';
import '../domain/models/request_status.dart';

class RequestRepository {
  RequestRepository(this._client, this._ref);

  final SupabaseClient _client;
  final Ref _ref;

  Future<List<BranchRequest>> fetchRequests({
    List<String>? branchIds,
    bool onlyMine = false,
    RequestStatus? status,
    RequestCategory? category,
  }) async {
    final query = _client.from('branch_requests').select();

    if (branchIds != null && branchIds.isNotEmpty) {
      query.inFilter('branch_id', branchIds);
    }

    if (onlyMine) {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) {
        return const <BranchRequest>[];
      }
      query.eq('created_by', userId);
    }

    if (status != null) {
      query.eq('status', status.value);
    }

    if (category != null) {
      query.eq('category', category.value);
    }

    query.order('created_at', ascending: false);

    final rows = await query;
    final parsed = List<Map<String, dynamic>>.from(rows as List<dynamic>);
    return parsed.map(BranchRequest.fromMap).toList(growable: false);
  }

  Future<BranchRequest> createRequest({
    required RequestCategory category,
    required String title,
    required String branchId,
    String? description,
    Map<String, dynamic>? payload,
    String? targetDepartment,
  }) async {
    final user = _ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );

    if (user == null) {
      throw StateError('Kullanıcı oturumu bulunamadı.');
    }

    final insertPayload = <String, dynamic>{
      'branch_id': branchId,
      'category': category.value,
      'title': title,
      'description': description,
      'payload': payload,
      'target_department': targetDepartment,
    }..removeWhere((key, value) => value == null);

    final response = await _client
        .from('branch_requests')
        .insert(insertPayload)
        .select()
        .single();

    return BranchRequest.fromMap(response);
  }

  Future<BranchRequest> updateStatus({
    required String requestId,
    required RequestStatus status,
    String? resolvedBy,
    DateTime? resolvedAt,
  }) async {
    final payload = <String, dynamic>{
      'status': status.value,
      'resolved_by': resolvedBy,
      'resolved_at': resolvedAt?.toUtc().toIso8601String(),
    }..removeWhere((key, value) => value == null);

    final response = await _client
        .from('branch_requests')
        .update(payload)
        .eq('id', requestId)
        .select()
        .single();

    return BranchRequest.fromMap(response);
  }

  Future<BranchRequest> updateRequest({
    required String requestId,
    required String title,
    String? description,
    Map<String, dynamic>? payload,
    String? targetDepartment,
  }) async {
    final updatePayload = <String, dynamic>{
      'title': title,
      'description': description,
      'payload': payload,
      'target_department': targetDepartment,
    };

    final response = await _client
        .from('branch_requests')
        .update(updatePayload)
        .eq('id', requestId)
        .select()
        .single();

    return BranchRequest.fromMap(response);
  }
}

@immutable
class BranchRequestsFilter {
  const BranchRequestsFilter({
    this.branchIds = const <String>[],
    this.status,
    this.category,
    this.onlyMine = false,
  });

  final List<String> branchIds;
  final RequestStatus? status;
  final RequestCategory? category;
  final bool onlyMine;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! BranchRequestsFilter) return false;
    return listEquals(branchIds, other.branchIds) &&
        status == other.status &&
        category == other.category &&
        onlyMine == other.onlyMine;
  }

  @override
  int get hashCode => Object.hash(
        Object.hashAll(branchIds),
        status,
        category,
        onlyMine,
      );
}

final requestRepositoryProvider = Provider<RequestRepository>((ref) {
  final client = Supabase.instance.client;
  return RequestRepository(client, ref);
});

final branchRequestsProvider = FutureProvider.autoDispose
    .family<List<BranchRequest>, BranchRequestsFilter>(
  (ref, filter) {
    final repo = ref.watch(requestRepositoryProvider);
    if (filter.branchIds.isEmpty && !filter.onlyMine) {
      return const <BranchRequest>[];
    }
    return repo.fetchRequests(
      branchIds: filter.branchIds.isEmpty ? null : filter.branchIds,
      onlyMine: filter.onlyMine,
      status: filter.status,
      category: filter.category,
    );
  },
);

final personalRequestsProvider =
    FutureProvider.autoDispose<List<BranchRequest>>((ref) async {
  final repo = ref.watch(requestRepositoryProvider);
  final user = ref.watch(authProvider).maybeWhen(
        authenticated: (user) => user,
        orElse: () => null,
      );
  if (user?.branchId == null) {
    return const <BranchRequest>[];
  }
  return repo.fetchRequests(
    branchIds: [user!.branchId!],
    onlyMine: true,
  );
});
