import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/skt_record_model.dart';

class SktRepository {
  const SktRepository(this._client);

  final SupabaseClient _client;

  Future<List<SktRecordModel>> fetchRecords({
    required String tenantId,
    String? branchId,
  }) async {
    try {
      var query = _client.from('skt_records').select(
            'id, tenant_id, branch_id, product_id, expiry_date, quantity, notes, product_status, status, products(id, name, barcode), branches(id, name)',
          );

      query = query.eq('tenant_id', tenantId);

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId);
      }

      final response = await query.order('expiry_date', ascending: true);
      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map(SktRecordModel.fromMap).toList();
    } on PostgrestException catch (e, stackTrace) {
      log('SKT kayıtları alınırken PostgrestException: ${e.message}',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      log('SKT kayıtları alınırken beklenmeyen hata: $e',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}
