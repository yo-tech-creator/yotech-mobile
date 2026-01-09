import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/merch/data/models/merch_person.dart';

final merchRepositoryProvider = Provider<MerchRepository>((ref) {
  return MerchRepository(Supabase.instance.client);
});

class MerchRepository {
  MerchRepository(this._client);

  final SupabaseClient _client;

  Future<List<MerchPerson>> fetchPeople(String tenantId) async {
    final response = await _client
        .from('merch_people')
        .select()
        .eq('tenant_id', tenantId)
        .order('company_name')
        .order('first_name');
    final rows = response as List<dynamic>;
    return rows
        .map((row) => MerchPerson.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<MerchPerson> createPerson({
    required MerchPerson person,
    required String tenantId,
    required String userId,
  }) async {
    final response = await _client
        .from('merch_people')
        .insert({
          'tenant_id': tenantId,
          'created_by': userId,
          'first_name': person.firstName,
          'last_name': person.lastName,
          'company_name': person.companyName,
          'phone_number': person.phoneNumber,
          'rank': person.rank.name,
        })
        .select()
        .single();
    return MerchPerson.fromJson(Map<String, dynamic>.from(response));
  }

  Future<void> updatePerson(MerchPerson person) async {
    await _client.from('merch_people').update({
      'first_name': person.firstName,
      'last_name': person.lastName,
      'company_name': person.companyName,
      'phone_number': person.phoneNumber,
      'rank': person.rank.name,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', person.id);
  }

  Future<void> deletePerson({
    required String id,
    required String tenantId,
  }) async {
    await _client
        .from('merch_people')
        .delete()
        .eq('id', id)
        .eq('tenant_id', tenantId);
  }
}
