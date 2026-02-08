import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/domain/providers/auth_provider.dart';
import '../domain/models/branch_request.dart';
import '../domain/models/department.dart';
import '../domain/models/request_category.dart';
import '../domain/models/request_status.dart';
import '../domain/models/request_transfer.dart';
import '../domain/models/target_user.dart';

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
    String? targetDepartmentId,
    String? targetUserId,
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
      'target_department_id': targetDepartmentId,
      'target_user_id': targetUserId,
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
    String? targetDepartmentId,
  }) async {
    final updatePayload = <String, dynamic>{
      'title': title,
      'description': description,
      'payload': payload,
      'target_department': targetDepartment,
      'target_department_id': targetDepartmentId,
    };

    final response = await _client
        .from('branch_requests')
        .update(updatePayload)
        .eq('id', requestId)
        .select()
        .single();

    return BranchRequest.fromMap(response);
  }

  /// Gelen talepleri getir - kullanıcının hedef olduğu, departmanına atanan veya yönetici olarak görebileceği başkalarının talepleri
  Future<List<BranchRequest>> fetchIncomingRequests({
    required String userId,
    required String userRole,
    String? branchId,
    String? regionId,
    String? tenantId,
    String? departmentId,
  }) async {
    final isManager =
        ['firma_admin', 'bolge_muduru', 'sube_muduru'].contains(userRole);

    /// Parse request rows with creator, branch, and assigned_to info
    Future<List<BranchRequest>> parseWithExtraInfo(List<dynamic> rows) async {
      final parsed = List<Map<String, dynamic>>.from(rows);
      final results = <BranchRequest>[];

      for (final row in parsed) {
        // Creator bilgisini al
        final creatorInfo = row['creator'] as Map<String, dynamic>?;
        if (creatorInfo != null) {
          final firstName = creatorInfo['first_name'] as String? ?? '';
          final lastName = creatorInfo['last_name'] as String? ?? '';
          final creatorName = '$firstName $lastName'.trim();

          // Payload'a creator_name ekle
          final payload = row['payload'] as Map<String, dynamic>? ?? {};
          row['payload'] = {...payload, 'creator_name': creatorName};
        }
        row.remove('creator');

        // Branch bilgisini al
        final branchInfo = row['branch'] as Map<String, dynamic>?;
        if (branchInfo != null) {
          row['branch_name'] = branchInfo['name'] as String?;
        }
        row.remove('branch');

        // Assigned_to bilgisini al
        final assignedInfo = row['assigned_user'] as Map<String, dynamic>?;
        if (assignedInfo != null) {
          final firstName = assignedInfo['first_name'] as String? ?? '';
          final lastName = assignedInfo['last_name'] as String? ?? '';
          row['assigned_to_name'] = '$firstName $lastName'.trim();
        }
        row.remove('assigned_user');

        results.add(BranchRequest.fromMap(row));
      }

      return results;
    }

    // Query string with joins
    const selectQuery = '''
      *,
      creator:users!branch_requests_created_by_fkey(first_name, last_name),
      branch:branches!branch_requests_branch_id_fkey(name),
      assigned_user:users!branch_requests_assigned_to_fkey(first_name, last_name)
    ''';

    if (!isManager) {
      // Personel: kendisine atanan VEYA departmanına atanan talepler
      // OR filtresi için iki sorgu yapıp birleştiriyoruz
      final targetUserRows = await _client
          .from('branch_requests')
          .select(selectQuery)
          .eq('target_user_id', userId)
          .neq('created_by', userId)
          .order('created_at', ascending: false);

      final results = await parseWithExtraInfo(targetUserRows as List<dynamic>);

      // Departmana atanan talepler (eğer departmanı varsa)
      if (departmentId != null) {
        final deptRows = await _client
            .from('branch_requests')
            .select(selectQuery)
            .eq('target_department_id', departmentId)
            .neq('created_by', userId)
            .order('created_at', ascending: false);

        final deptResults = await parseWithExtraInfo(deptRows as List<dynamic>);

        // Birleştir ve tekrarları kaldır
        final existingIds = results.map((r) => r.id).toSet();
        for (final req in deptResults) {
          if (!existingIds.contains(req.id)) {
            results.add(req);
          }
        }

        // Tarih sırasına göre sırala
        results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      }

      return results;
    }

    // Yöneticiler için - hedef kendisi olan veya kapsamındaki talepler
    List<String>? filterBranchIds;

    // Rol bazlı filtreleme
    switch (userRole) {
      case 'firma_admin':
        // Firma admin tüm firma taleplerini görebilir
        // RLS zaten tenant bazlı filtreleme yapacak
        break;
      case 'bolge_muduru':
        // Bölge müdürü kendi bölgesindeki şubelerin taleplerini görebilir
        if (regionId != null) {
          final branchesInRegion = await _client
              .from('branches')
              .select('id')
              .eq('region_id', regionId);
          filterBranchIds =
              (branchesInRegion as List).map((b) => b['id'] as String).toList();
        }
        break;
      case 'sube_muduru':
        // Şube müdürü sadece kendi şubesinin taleplerini görebilir
        if (branchId != null) {
          filterBranchIds = [branchId];
        }
        break;
    }

    var query = _client
        .from('branch_requests')
        .select(selectQuery)
        .neq('created_by', userId);

    if (filterBranchIds != null && filterBranchIds.isNotEmpty) {
      query = query.inFilter('branch_id', filterBranchIds);
    }

    final rows = await query.order('created_at', ascending: false);
    return parseWithExtraInfo(rows as List<dynamic>);
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

/// Gelen talepler - kullanıcının hedef olduğu, departmanına atanan veya yönetici olarak görebileceği talepler
final incomingRequestsProvider =
    FutureProvider.autoDispose<List<BranchRequest>>((ref) async {
  final repo = ref.watch(requestRepositoryProvider);
  final user = ref.watch(authProvider).maybeWhen(
        authenticated: (user) => user,
        orElse: () => null,
      );
  if (user == null) {
    return const <BranchRequest>[];
  }

  return repo.fetchIncomingRequests(
    userId: user.id,
    userRole: user.role,
    branchId: user.branchId,
    regionId: user.regionId,
    tenantId: user.tenantId,
    departmentId: user.departmentId,
  );
});

/// Talep atama ve transfer işlemleri extension
extension RequestAssignmentExtension on RequestRepository {
  /// Talebi işleme al (claim) - RPC fonksiyonu kullanır
  Future<BranchRequest> claimRequest(String requestId) async {
    final response = await _client.rpc('claim_request', params: {
      'p_request_id': requestId,
    });

    if (response == null) {
      throw StateError('Talep işleme alınamadı.');
    }

    return BranchRequest.fromMap(response as Map<String, dynamic>);
  }

  /// Transfer talebi oluştur - RPC fonksiyonu kullanır
  Future<RequestTransfer> createTransferRequest({
    required String requestId,
    required String toUserId,
    String? reason,
  }) async {
    final response = await _client.rpc('create_transfer_request', params: {
      'p_request_id': requestId,
      'p_to_user_id': toUserId,
      'p_reason': reason,
    });

    if (response == null) {
      throw StateError('Transfer talebi oluşturulamadı.');
    }

    return RequestTransfer.fromMap(response as Map<String, dynamic>);
  }

  /// Transfer talebini yanıtla (onayla/reddet) - RPC fonksiyonu kullanır
  Future<RequestTransfer> respondTransferRequest({
    required String transferId,
    required bool approve,
  }) async {
    final response = await _client.rpc('respond_transfer_request', params: {
      'p_transfer_id': transferId,
      'p_approve': approve,
    });

    if (response == null) {
      throw StateError('Transfer talebi yanıtlanamadı.');
    }

    return RequestTransfer.fromMap(response as Map<String, dynamic>);
  }

  /// Bana gelen transfer taleplerini getir
  Future<List<RequestTransfer>> fetchIncomingTransfers() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      return const <RequestTransfer>[];
    }

    final response = await _client
        .from('request_transfers')
        .select('''
          *,
          from_user:users!request_transfers_from_user_id_fkey(first_name, last_name),
          to_user:users!request_transfers_to_user_id_fkey(first_name, last_name),
          request:branch_requests!request_transfers_request_id_fkey(title)
        ''')
        .eq('to_user_id', userId)
        .eq('status', 'pending')
        .order('created_at', ascending: false);

    return (response as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);

      // From user name
      final fromUser = map['from_user'] as Map<String, dynamic>?;
      if (fromUser != null) {
        final firstName = fromUser['first_name'] as String? ?? '';
        final lastName = fromUser['last_name'] as String? ?? '';
        map['from_user_name'] = '$firstName $lastName'.trim();
      }
      map.remove('from_user');

      // To user name
      final toUser = map['to_user'] as Map<String, dynamic>?;
      if (toUser != null) {
        final firstName = toUser['first_name'] as String? ?? '';
        final lastName = toUser['last_name'] as String? ?? '';
        map['to_user_name'] = '$firstName $lastName'.trim();
      }
      map.remove('to_user');

      // Request title
      final request = map['request'] as Map<String, dynamic>?;
      if (request != null) {
        map['request_title'] = request['title'] as String?;
      }
      map.remove('request');

      return RequestTransfer.fromMap(map);
    }).toList();
  }

  /// Departmandaki diğer kullanıcıları getir (transfer için)
  Future<List<DepartmentUser>> getDepartmentColleagues() async {
    final user = _ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );

    if (user?.departmentId == null) {
      return const <DepartmentUser>[];
    }

    final departmentId = user!.departmentId!;
    final response = await _client
        .from('users')
        .select('id, first_name, last_name, role, branch_id')
        .eq('department_id', departmentId)
        .eq('is_active', true)
        .neq('id', user.id) // Kendisini hariç tut
        .order('first_name');

    return (response as List).map((e) {
      final map = e as Map<String, dynamic>;
      return DepartmentUser(
        id: map['id'] as String,
        firstName: map['first_name'] as String? ?? '',
        lastName: map['last_name'] as String? ?? '',
        role: map['role'] as String,
        branchId: map['branch_id'] as String?,
      );
    }).toList();
  }
}

/// Gelen transfer talepleri provider'ı
final incomingTransfersProvider =
    FutureProvider.autoDispose<List<RequestTransfer>>((ref) async {
  final repo = ref.watch(requestRepositoryProvider);
  return repo.fetchIncomingTransfers();
});

/// Departman arkadaşları provider'ı (transfer için)
final departmentColleaguesProvider =
    FutureProvider.autoDispose<List<DepartmentUser>>((ref) async {
  final repo = ref.watch(requestRepositoryProvider);
  return repo.getDepartmentColleagues();
});

/// Hedef kullanıcıları getiren metot (get_request_target_users RPC)
extension RequestRepositoryTargetUsers on RequestRepository {
  /// Hedef kullanıcıları getir - basit sorgu ile
  Future<List<TargetUser>> getTargetUsers(String branchId) async {
    // Şubedeki bölge ve kiracı bilgisini al
    final branchResponse = await _client
        .from('branches')
        .select('region_id, tenant_id')
        .eq('id', branchId)
        .maybeSingle();

    if (branchResponse == null) {
      return const <TargetUser>[];
    }

    final tenantId = branchResponse['tenant_id'] as String?;
    final regionId = branchResponse['region_id'] as String?;
    final currentUserId = _client.auth.currentUser?.id;

    if (tenantId == null) {
      return const <TargetUser>[];
    }

    // Yöneticileri getir
    final usersResponse = await _client
        .from('users')
        .select('id, first_name, last_name, role, branch_id, branches(name)')
        .eq('tenant_id', tenantId)
        .eq('is_active', true)
        .inFilter('role', ['firma_admin', 'bolge_muduru', 'sube_muduru']);

    final users = List<Map<String, dynamic>>.from(usersResponse as List);

    // Filtrele ve dönüştür
    final result = <TargetUser>[];
    for (final user in users) {
      final userId = user['id'] as String?;
      final role = user['role'] as String?;
      final userBranchId = user['branch_id'] as String?;

      // Kendini hariç tut
      if (userId == currentUserId) continue;

      // Firma admin her zaman dahil
      if (role == 'firma_admin') {
        result.add(_mapUserToTargetUser(user));
        continue;
      }

      // Şube müdürü - sadece aynı şubedeki
      if (role == 'sube_muduru' && userBranchId == branchId) {
        result.add(_mapUserToTargetUser(user));
        continue;
      }

      // Bölge müdürü - aynı bölgedeki
      if (role == 'bolge_muduru' && regionId != null) {
        // Bölge müdürünün şubesinin bölgesi aynı mı kontrol et
        if (userBranchId != null) {
          final userBranchResponse = await _client
              .from('branches')
              .select('region_id')
              .eq('id', userBranchId)
              .maybeSingle();
          if (userBranchResponse != null &&
              userBranchResponse['region_id'] == regionId) {
            result.add(_mapUserToTargetUser(user));
          }
        } else {
          // Şubesi yok = merkez, dahil et
          result.add(_mapUserToTargetUser(user));
        }
      }
    }

    return result;
  }

  TargetUser _mapUserToTargetUser(Map<String, dynamic> user) {
    final firstName = user['first_name'] as String? ?? '';
    final lastName = user['last_name'] as String? ?? '';
    final branches = user['branches'] as Map<String, dynamic>?;
    final branchName = branches?['name'] as String?;

    return TargetUser(
      userId: user['id'] as String,
      userName: '$firstName $lastName'.trim(),
      userRole: user['role'] as String,
      branchName: branchName,
    );
  }

  /// Talep durumunu workflow ile güncelle (doğrudan güncelleme)
  Future<BranchRequest> updateRequestStatusWorkflow({
    required String requestId,
    required RequestStatus newStatus,
    String? note,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;

    final updatePayload = <String, dynamic>{
      'status': newStatus.value,
    };

    // Resolved veya failed durumlarında resolved_by ve resolved_at ekle
    if (newStatus == RequestStatus.resolved ||
        newStatus == RequestStatus.failed ||
        newStatus == RequestStatus.rejected) {
      updatePayload['resolved_by'] = currentUserId;
      updatePayload['resolved_at'] = DateTime.now().toUtc().toIso8601String();
    }

    // Note varsa payload'a ekle
    if (note != null && note.isNotEmpty) {
      // Mevcut payload'ı al ve güncelle
      final existingRequest = await _client
          .from('branch_requests')
          .select('payload')
          .eq('id', requestId)
          .single();

      final existingPayload =
          (existingRequest['payload'] as Map<String, dynamic>?) ?? {};
      existingPayload['resolution_note'] = note;
      updatePayload['payload'] = existingPayload;
    }

    final response = await _client
        .from('branch_requests')
        .update(updatePayload)
        .eq('id', requestId)
        .select()
        .single();

    return BranchRequest.fromMap(response);
  }
}

/// Hedef kullanıcıları sağlayan provider
final targetUsersProvider = FutureProvider.autoDispose
    .family<List<TargetUser>, String>((ref, branchId) {
  final repo = ref.watch(requestRepositoryProvider);
  return repo.getTargetUsers(branchId);
});

/// Departmanları sağlayan provider
final departmentsProvider =
    FutureProvider.autoDispose<List<Department>>((ref) async {
  final client = Supabase.instance.client;
  final response = await client
      .from('departments')
      .select()
      .eq('is_active', true)
      .order('name');

  return (response as List)
      .map((e) => Department.fromMap(e as Map<String, dynamic>))
      .toList();
});

/// Departman yönetimi için extension
extension DepartmentManagement on RequestRepository {
  /// Tüm departmanları getir (yönetim için)
  Future<List<Department>> fetchAllDepartments() async {
    final response = await _client.from('departments').select().order('name');

    return (response as List)
        .map((e) => Department.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Yeni departman oluştur
  Future<Department> createDepartment({
    required String name,
    String? description,
  }) async {
    final user = _ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );

    if (user == null) {
      throw StateError('Kullanıcı oturumu bulunamadı.');
    }

    final response = await _client
        .from('departments')
        .insert({
          'tenant_id': user.tenantId,
          'name': name,
          'description': description,
        })
        .select()
        .single();

    return Department.fromMap(response);
  }

  /// Departman güncelle
  Future<Department> updateDepartment({
    required String departmentId,
    required String name,
    String? description,
    bool? isActive,
  }) async {
    final updateData = <String, dynamic>{
      'name': name,
    };
    if (description != null) updateData['description'] = description;
    if (isActive != null) updateData['is_active'] = isActive;

    final response = await _client
        .from('departments')
        .update(updateData)
        .eq('id', departmentId)
        .select()
        .single();

    return Department.fromMap(response);
  }

  /// Departman sil (soft delete - is_active = false)
  Future<void> deleteDepartment(String departmentId) async {
    await _client
        .from('departments')
        .update({'is_active': false}).eq('id', departmentId);
  }

  /// Departmandaki kullanıcıları getir
  Future<List<DepartmentUser>> getDepartmentUsers(String departmentId) async {
    final response = await _client
        .from('users')
        .select('id, first_name, last_name, role, branch_id, department_id')
        .eq('department_id', departmentId)
        .eq('is_active', true)
        .order('first_name');

    return (response as List).map((e) {
      final map = e as Map<String, dynamic>;
      return DepartmentUser(
        id: map['id'] as String,
        firstName: map['first_name'] as String? ?? '',
        lastName: map['last_name'] as String? ?? '',
        role: map['role'] as String,
        branchId: map['branch_id'] as String?,
      );
    }).toList();
  }

  /// Departmana atanabilecek kullanıcıları getir (aynı tenant'tan)
  Future<List<DepartmentUser>> getAssignableUsers() async {
    final user = _ref.read(authProvider).maybeWhen(
          authenticated: (user) => user,
          orElse: () => null,
        );

    if (user == null) {
      return const <DepartmentUser>[];
    }

    final response = await _client
        .from('users')
        .select('id, first_name, last_name, role, branch_id, department_id')
        .eq('tenant_id', user.tenantId)
        .eq('is_active', true)
        .order('first_name');

    return (response as List).map((e) {
      final map = e as Map<String, dynamic>;
      return DepartmentUser(
        id: map['id'] as String,
        firstName: map['first_name'] as String? ?? '',
        lastName: map['last_name'] as String? ?? '',
        role: map['role'] as String,
        branchId: map['branch_id'] as String?,
        departmentId: map['department_id'] as String?,
      );
    }).toList();
  }

  /// Kullanıcıyı departmana ata
  Future<void> assignUserToDepartment({
    required String userId,
    String? departmentId,
  }) async {
    await _client
        .from('users')
        .update({'department_id': departmentId}).eq('id', userId);
  }
}

/// Departmandaki kullanıcı modeli
class DepartmentUser {
  const DepartmentUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.branchId,
    this.departmentId,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final String? branchId;
  final String? departmentId;

  String get fullName => '$firstName $lastName'.trim();

  String get roleLabel {
    switch (role) {
      case 'firma_admin':
        return 'Firma Admin';
      case 'bolge_muduru':
        return 'Bölge Müdürü';
      case 'sube_muduru':
        return 'Şube Müdürü';
      case 'personel':
        return 'Personel';
      default:
        return role;
    }
  }
}

/// Departman yönetimi provider'ı
final departmentManagementProvider =
    FutureProvider.autoDispose<List<Department>>((ref) async {
  final repo = ref.watch(requestRepositoryProvider);
  return repo.fetchAllDepartments();
});

/// Atanabilir kullanıcılar provider'ı
final assignableUsersProvider =
    FutureProvider.autoDispose<List<DepartmentUser>>((ref) async {
  final repo = ref.watch(requestRepositoryProvider);
  return repo.getAssignableUsers();
});
