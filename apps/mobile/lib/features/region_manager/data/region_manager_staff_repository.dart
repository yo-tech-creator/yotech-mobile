import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/branch_personnel.dart';

class CreatePersonnelResult {
  const CreatePersonnelResult({
    required this.userId,
    required this.email,
  });

  final String userId;
  final String email;
}

class RegionManagerStaffRepository {
  const RegionManagerStaffRepository(this._client);

  final SupabaseClient _client;

  Future<List<BranchPersonnel>> fetchBranchPersonnel({
    required String tenantId,
    required String branchId,
  }) async {
    final rpcResult = await _client.rpc(
      'region_manager_get_branch_personnel',
      params: {'p_branch_id': branchId},
    );

    final dynamic payload =
        rpcResult is PostgrestResponse ? rpcResult.data : rpcResult;

    if (payload == null) {
      return const <BranchPersonnel>[];
    }

    if (payload is! List) {
      throw StateError('Beklenmeyen personel listesi yanıtı alındı.');
    }

    final personnel = <BranchPersonnel>[];
    for (final raw in payload) {
      if (raw is! Map) {
        continue;
      }
      final map = Map<String, dynamic>.from(raw);
      final normalizedMap = <String, dynamic>{
        'id': map['member_id'],
        'tenant_id': tenantId,
        'branch_id': branchId,
        'first_name': map['first_name'],
        'last_name': map['last_name'],
        'email': map['email'],
        'phone': map['phone'],
        'employee_code': map['employee_code'],
        'role': map['role'],
        'position': map['position'],
        'active': map['active'] ?? true,
      };
      personnel.add(BranchPersonnel.fromMap(normalizedMap));
    }

    personnel.sort((a, b) {
      final first = a.firstName.compareTo(b.firstName);
      if (first != 0) return first;
      return a.lastName.compareTo(b.lastName);
    });

    return List<BranchPersonnel>.unmodifiable(personnel);
  }

  Future<void> updatePersonnelRole({
    required String userId,
    required String role,
  }) async {
    await _client.rpc(
      'region_manager_update_personnel_role',
      params: {
        'p_personnel_id': userId,
        'p_role': role,
      },
    );
  }

  Future<void> removePersonnel({required String userId}) async {
    await _client.rpc(
      'region_manager_remove_personnel',
      params: {'p_personnel_id': userId},
    );
  }

  Future<CreatePersonnelResult> createPersonnel({
    required String branchId,
    required String employeeCode,
    required String password,
    required String firstName,
    required String lastName,
    required String role,
    String? email,
    String? phone,
    String? position,
  }) async {
    try {
      final rpcResult = await _client.rpc(
        'region_manager_create_personnel',
        params: {
          'p_branch_id': branchId,
          'p_employee_code': employeeCode,
          'p_password': password,
          'p_first_name': firstName,
          'p_last_name': lastName,
          'p_role': role,
          'p_email': email,
          'p_phone': phone,
          'p_position': position,
        },
      );

      final dynamic payload =
          rpcResult is PostgrestResponse ? rpcResult.data : rpcResult;

      if (payload is Map) {
        final map = Map<String, dynamic>.from(payload);
        if (map['success'] == true) {
          final userId = map['user_id']?.toString();
          final emailValue = map['email']?.toString();
          if (userId == null || emailValue == null) {
            throw StateError('Personel oluşturuldu ancak yanıt eksik.');
          }
          return CreatePersonnelResult(userId: userId, email: emailValue);
        }
        final message = map['error']?.toString();
        throw StateError(
          message == null || message.isEmpty
              ? 'Personel oluşturulamadı.'
              : message,
        );
      }

      throw StateError('Personel oluşturulamadı.');
    } on PostgrestException catch (error) {
      final trimmedMessage = error.message.trim();
      throw StateError(
        trimmedMessage.isEmpty ? 'Personel oluşturulamadı.' : trimmedMessage,
      );
    }
  }
}
