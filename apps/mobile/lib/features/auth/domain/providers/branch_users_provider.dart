import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Basit kullanıcı modeli (şube personeli için)
class BranchUser {
  final String id;
  final String? fullName;
  final String? role;
  final String? branchId;
  final bool isActive;

  BranchUser({
    required this.id,
    this.fullName,
    this.role,
    this.branchId,
    this.isActive = true,
  });

  factory BranchUser.fromJson(Map<String, dynamic> json) {
    // first_name ve last_name'i birleştir
    final firstName = json['first_name'] as String? ?? '';
    final lastName = json['last_name'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();

    return BranchUser(
      id: json['id'] as String,
      fullName: fullName.isNotEmpty ? fullName : null,
      role: json['role'] as String?,
      branchId: json['branch_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Belirli bir şubedeki kullanıcıları getiren provider
final branchUsersProvider =
    FutureProvider.family<List<BranchUser>, String>((ref, branchId) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('users')
      .select('id, first_name, last_name, role, branch_id, is_active')
      .eq('branch_id', branchId)
      .eq('is_active', true)
      .order('first_name');

  return (response as List)
      .map((e) => BranchUser.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Belirli bir şubedeki şube müdürlerini getiren provider
final branchManagersProvider =
    FutureProvider.family<List<BranchUser>, String>((ref, branchId) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('users')
      .select('id, first_name, last_name, role, branch_id, is_active')
      .eq('branch_id', branchId)
      .eq('role', 'sube_muduru')
      .eq('is_active', true)
      .order('first_name');

  return (response as List)
      .map((e) => BranchUser.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Belirli bir şubedeki personelleri getiren provider
final branchPersonnelProvider =
    FutureProvider.family<List<BranchUser>, String>((ref, branchId) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('users')
      .select('id, first_name, last_name, role, branch_id, is_active')
      .eq('branch_id', branchId)
      .eq('role', 'personel')
      .eq('is_active', true)
      .order('first_name');

  return (response as List)
      .map((e) => BranchUser.fromJson(e as Map<String, dynamic>))
      .toList();
});
