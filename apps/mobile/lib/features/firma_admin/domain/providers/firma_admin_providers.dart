import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../auth/domain/providers/auth_provider.dart';

// ============================================================================
// Models
// ============================================================================

class FirmaStats {
  final int branchCount;
  final int personnelCount;
  final int pendingRequests;
  final int todayForms;
  final int departmentCount;
  final int activeAnnouncements;

  const FirmaStats({
    this.branchCount = 0,
    this.personnelCount = 0,
    this.pendingRequests = 0,
    this.todayForms = 0,
    this.departmentCount = 0,
    this.activeAnnouncements = 0,
  });
}

class FirmaBranch {
  final String id;
  final String name;
  final String? regionName;
  final String? address;
  final int personnelCount;
  final bool isActive;

  const FirmaBranch({
    required this.id,
    required this.name,
    this.regionName,
    this.address,
    this.personnelCount = 0,
    this.isActive = true,
  });

  factory FirmaBranch.fromJson(Map<String, dynamic> json) {
    return FirmaBranch(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Şube',
      regionName: (json['region'] as Map<String, dynamic>?)?['name'] as String?,
      address: json['address'] as String?,
      personnelCount: json['personnel_count'] as int? ?? 0,
      isActive: json['active'] as bool? ?? true,
    );
  }
}

class FirmaPersonnel {
  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final String? branchName;
  final String? departmentName;
  final String? email;
  final bool isActive;

  const FirmaPersonnel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.branchName,
    this.departmentName,
    this.email,
    this.isActive = true,
  });

  String get fullName => '$firstName $lastName';

  String get roleLabel {
    switch (role) {
      case 'firma_admin':
        return 'Firma Yöneticisi';
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

  factory FirmaPersonnel.fromJson(Map<String, dynamic> json) {
    return FirmaPersonnel(
      id: json['id'] as String,
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      role: json['role'] as String? ?? 'personel',
      branchName: (json['branch'] as Map<String, dynamic>?)?['name'] as String?,
      departmentName:
          (json['department'] as Map<String, dynamic>?)?['name'] as String?,
      email: json['email'] as String?,
      isActive: json['active'] as bool? ?? true,
    );
  }
}

class FirmaDepartment {
  final String id;
  final String name;
  final String? description;
  final int userCount;

  const FirmaDepartment({
    required this.id,
    required this.name,
    this.description,
    this.userCount = 0,
  });

  factory FirmaDepartment.fromJson(Map<String, dynamic> json) {
    return FirmaDepartment(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Departman',
      description: json['description'] as String?,
      userCount: json['user_count'] as int? ?? 0,
    );
  }
}

class FirmaRequest {
  final String id;
  final String title;
  final String category;
  final String status;
  final String creatorName;
  final String? branchName;
  final DateTime createdAt;

  const FirmaRequest({
    required this.id,
    required this.title,
    required this.category,
    required this.status,
    required this.creatorName,
    this.branchName,
    required this.createdAt,
  });

  String get categoryLabel {
    switch (category) {
      case 'malfunction':
        return 'Arıza';
      case 'equipment':
        return 'Ekipman';
      case 'leave':
        return 'İzin';
      default:
        return 'Diğer';
    }
  }

  String get statusLabel {
    switch (status) {
      case 'pending':
        return 'Bekliyor';
      case 'in_progress':
        return 'İşlemde';
      case 'resolved':
        return 'Çözüldü';
      case 'rejected':
        return 'Reddedildi';
      default:
        return status;
    }
  }

  factory FirmaRequest.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final branch = json['branch'] as Map<String, dynamic>?;
    return FirmaRequest(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Talep',
      category: json['category'] as String? ?? 'other',
      status: json['status'] as String? ?? 'pending',
      creatorName: creator != null
          ? '${creator['first_name'] ?? ''} ${creator['last_name'] ?? ''}'
              .trim()
          : 'Bilinmiyor',
      branchName: branch?['name'] as String?,
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

class FirmaAnnouncement {
  final String id;
  final String title;
  final String? content;
  final String type;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;

  const FirmaAnnouncement({
    required this.id,
    required this.title,
    this.content,
    required this.type,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
  });

  String get typeLabel {
    switch (type) {
      case 'announcement':
        return 'Duyuru';
      case 'survey':
        return 'Anket';
      case 'alert':
        return 'Uyarı';
      default:
        return type;
    }
  }

  factory FirmaAnnouncement.fromJson(Map<String, dynamic> json) {
    return FirmaAnnouncement(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Duyuru',
      content: json['content'] as String?,
      type: json['type'] as String? ?? 'announcement',
      createdAt: DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

// ============================================================================
// Providers
// ============================================================================

final _supabase = Supabase.instance.client;

/// Firma istatistikleri
final firmaStatsProvider = FutureProvider.autoDispose<FirmaStats>((ref) async {
  final user = ref.watch(authProvider).maybeWhen(
        authenticated: (user) => user,
        orElse: () => null,
      );

  if (user?.tenantId == null) {
    return const FirmaStats();
  }

  final tenantId = user!.tenantId;

  // Parallel queries
  final results = await Future.wait([
    _supabase
        .from('branches')
        .select('id')
        .eq('tenant_id', tenantId)
        .eq('active', true),
    _supabase.from('users').select('id').eq('tenant_id', tenantId),
    _supabase.from('branch_requests').select('id').eq('status', 'pending'),
    _supabase.from('departments').select('id').eq('tenant_id', tenantId),
  ]);

  return FirmaStats(
    branchCount: (results[0] as List).length,
    personnelCount: (results[1] as List).length,
    pendingRequests: (results[2] as List).length,
    departmentCount: (results[3] as List).length,
    todayForms: 0,
    activeAnnouncements: 0,
  );
});

/// Şube listesi
final firmaBranchesProvider =
    FutureProvider.autoDispose<List<FirmaBranch>>((ref) async {
  final user = ref.watch(authProvider).maybeWhen(
        authenticated: (user) => user,
        orElse: () => null,
      );

  if (user?.tenantId == null) return [];

  final response = await _supabase
      .from('branches')
      .select('id, name, address, active, region:regions(name)')
      .eq('tenant_id', user!.tenantId)
      .order('name');

  final branches = <FirmaBranch>[];
  for (final json in response as List) {
    // Get personnel count for each branch
    final countResponse = await _supabase
        .from('users')
        .select('id')
        .eq('branch_id', json['id'] as String);
    final branch = FirmaBranch(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Şube',
      regionName: (json['region'] as Map<String, dynamic>?)?['name'] as String?,
      address: json['address'] as String?,
      personnelCount: (countResponse as List).length,
      isActive: json['active'] as bool? ?? true,
    );
    branches.add(branch);
  }

  return branches;
});

/// Personel listesi
final firmaPersonnelProvider =
    FutureProvider.autoDispose<List<FirmaPersonnel>>((ref) async {
  final user = ref.watch(authProvider).maybeWhen(
        authenticated: (user) => user,
        orElse: () => null,
      );

  if (user?.tenantId == null) return [];

  final response = await _supabase
      .from('users')
      .select(
          'id, first_name, last_name, role, email, active, branch:branches(name), department:departments(name)')
      .eq('tenant_id', user!.tenantId)
      .order('first_name');

  return (response as List)
      .map((json) => FirmaPersonnel.fromJson(json as Map<String, dynamic>))
      .toList();
});

/// Departman listesi
final firmaDepartmentsProvider =
    FutureProvider.autoDispose<List<FirmaDepartment>>((ref) async {
  final user = ref.watch(authProvider).maybeWhen(
        authenticated: (user) => user,
        orElse: () => null,
      );

  if (user?.tenantId == null) return [];

  final response = await _supabase
      .from('departments')
      .select('id, name, description')
      .eq('tenant_id', user!.tenantId)
      .order('name');

  final departments = <FirmaDepartment>[];
  for (final json in response as List) {
    final countResponse = await _supabase
        .from('users')
        .select('id')
        .eq('department_id', json['id'] as String);
    departments.add(FirmaDepartment(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Departman',
      description: json['description'] as String?,
      userCount: (countResponse as List).length,
    ));
  }

  return departments;
});

/// Bekleyen talepler
final firmaPendingRequestsProvider =
    FutureProvider.autoDispose<List<FirmaRequest>>((ref) async {
  final user = ref.watch(authProvider).maybeWhen(
        authenticated: (user) => user,
        orElse: () => null,
      );

  if (user?.tenantId == null) return [];

  final response = await _supabase
      .from('branch_requests')
      .select(
          'id, title, category, status, created_at, creator:users!branch_requests_created_by_fkey(first_name, last_name), branch:branches(name, tenant_id)')
      .eq('status', 'pending')
      .order('created_at', ascending: false)
      .limit(20);

  return (response as List)
      .where((json) {
        final branch = json['branch'] as Map<String, dynamic>?;
        return branch?['tenant_id'] == user!.tenantId;
      })
      .map((json) => FirmaRequest.fromJson(json as Map<String, dynamic>))
      .toList();
});
