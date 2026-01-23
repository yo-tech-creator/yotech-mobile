import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Şube modeli
class Branch {
  final String id;
  final String name;
  final String? regionId;
  final String? managerId;
  final bool isActive;

  Branch({
    required this.id,
    required this.name,
    this.regionId,
    this.managerId,
    this.isActive = true,
  });

  factory Branch.fromJson(Map<String, dynamic> json) {
    return Branch(
      id: json['id'] as String,
      name: json['name'] as String,
      regionId: json['region_id'] as String?,
      managerId: json['manager_id'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }
}

/// Tüm şubeleri getiren provider
final branchesProvider = FutureProvider<List<Branch>>((ref) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('branches')
      .select('*')
      .eq('is_active', true)
      .order('name');

  return (response as List)
      .map((e) => Branch.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Belirli bir bölgeye ait şubeleri getiren provider
final regionBranchesProvider =
    FutureProvider.family<List<Branch>, String>((ref, regionId) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('branches')
      .select('*')
      .eq('is_active', true)
      .eq('region_id', regionId)
      .order('name');

  return (response as List)
      .map((e) => Branch.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Tek bir şubeyi getiren provider
final branchProvider =
    FutureProvider.family<Branch?, String>((ref, branchId) async {
  final supabase = Supabase.instance.client;

  final response = await supabase
      .from('branches')
      .select('*')
      .eq('id', branchId)
      .maybeSingle();

  if (response == null) return null;
  return Branch.fromJson(response);
});
