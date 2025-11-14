import 'dart:developer';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/models/branch_summary_model.dart';
import '../domain/models/product_summary_model.dart';
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
            'id, tenant_id, branch_id, product_id, expiry_date, quantity, notes, product_status, status, alarm_days_before, products(id, name, barcode, category, alt_barcodes), branches(id, name)',
          );

      query = query.eq('tenant_id', tenantId.trim());

      if (branchId != null && branchId.isNotEmpty) {
        query = query.eq('branch_id', branchId.trim());
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

  Future<List<BranchSummaryModel>> fetchBranches(String tenantId) async {
    try {
      final response = await _client
          .from('branches')
          .select('id, name')
          .eq('tenant_id', tenantId.trim())
          .eq('active', true)
          .order('name');

      final list = (response as List).cast<Map<String, dynamic>>();
      return list.map(BranchSummaryModel.fromMap).toList();
    } on PostgrestException catch (e, stackTrace) {
      log('SKT branch listeleme hatasi: ${e.message}',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      log('SKT branch listeleme beklenmeyen hata: $e',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<List<ProductSummaryModel>> searchProducts({
    required String tenantId,
    required String query,
  }) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return <ProductSummaryModel>[];
    }

    try {
      final normalizedTenantId = tenantId.trim();

      PostgrestFilterBuilder baseQuery() {
        return _client
            .from('products')
            .select('id, name, barcode, alt_barcodes')
            .eq('tenant_id', normalizedTenantId)
            .eq('active', true);
      }

      final sanitized = trimmed.replaceAll('%', '\\%').replaceAll('_', '\\_');
      final pattern = '%$sanitized%';
      final seen = <String>{};
      final collected = <ProductSummaryModel>[];

      Future<void> appendResults(PostgrestFilterBuilder queryBuilder) async {
        if (collected.length >= 20) {
          return;
        }
        final response = await queryBuilder.limit(20 - collected.length);
        final list = (response as List).cast<Map<String, dynamic>>();
        for (final map in list) {
          final product = ProductSummaryModel.fromMap(map);
          if (seen.add(product.id)) {
            collected.add(product);
            if (collected.length >= 20) {
              break;
            }
          }
        }
      }

      // Prefer exact barcode matches first.
      await appendResults(baseQuery().eq('barcode', trimmed.trim()));

      final altExactValue = trimmed.trim();
      if (altExactValue.isNotEmpty) {
        await appendResults(
          baseQuery().contains('alt_barcodes', '{$altExactValue}'),
        );
      }

      // Follow with partial barcode matches.
      await appendResults(baseQuery().ilike('barcode', pattern));

      // Finally search by product name.
      await appendResults(baseQuery().ilike('name', pattern));

      // PostgREST ilike operator calismadigi icin alt barkodlarda kismi eslesmeyi
      // istemci tarafinda yapiyoruz. Dizide arama en az 3 karakter ile tetikleniyor
      // ve sadece alt barkodu olan urunler icin sorgu yapiliyor.
      if (trimmed.length >= 3 && collected.length < 20) {
        final altResponse =
            await baseQuery().not('alt_barcodes', 'is', null).limit(200);
        final altList = (altResponse as List).cast<Map<String, dynamic>>();
        final lowerNeedle = trimmed.toLowerCase();
        for (final map in altList) {
          final product = ProductSummaryModel.fromMap(map);
          final hasMatch = product.altBarcodes.any(
            (code) => code.toLowerCase().contains(lowerNeedle),
          );
          if (hasMatch && seen.add(product.id)) {
            collected.add(product);
            if (collected.length >= 20) {
              break;
            }
          }
        }
      }

      return collected;
    } on PostgrestException catch (e, stackTrace) {
      log('SKT urun arama hatasi: ${e.message}',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      log('SKT urun arama beklenmeyen hata: $e',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> createRecord({
    required String tenantId,
    required String branchId,
    required String productId,
    required String userId,
    required DateTime expiryDate,
    required int quantity,
    String? productStatus,
    String? notes,
    int alarmDaysBefore = 7,
  }) async {
    final normalizedExpiry = expiryDate.toUtc();
    final alarmDate =
        normalizedExpiry.subtract(Duration(days: alarmDaysBefore));
    final status = _statusFor(normalizedExpiry);

    final payload = {
      'tenant_id': tenantId,
      'branch_id': branchId,
      'product_id': productId,
      'user_id': userId,
      'expiry_date': normalizedExpiry.toIso8601String(),
      'quantity': quantity,
      'notes': notes,
      'product_status': productStatus,
      'status': status,
      'alarm_days_before': alarmDaysBefore,
      'alarm_date': alarmDate.toIso8601String(),
      'alarm_sent': false,
    };

    try {
      await _client.from('skt_records').insert(payload);
    } on PostgrestException catch (e, stackTrace) {
      log('SKT kaydi olusturma hatasi: ${e.message}',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      log('SKT kaydi olusturma beklenmeyen hata: $e',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> updateRecord({
    required String recordId,
    required DateTime expiryDate,
    required int quantity,
    String? productStatus,
    String? notes,
    required int alarmDaysBefore,
  }) async {
    final normalizedExpiry = expiryDate.toUtc();
    final status = _statusFor(normalizedExpiry);
    final alarmDate =
        normalizedExpiry.subtract(Duration(days: alarmDaysBefore));

    final payload = <String, dynamic>{
      'expiry_date': normalizedExpiry.toIso8601String(),
      'quantity': quantity,
      'notes': notes,
      'product_status': productStatus,
      'status': status,
      'alarm_days_before': alarmDaysBefore,
      'alarm_date': alarmDate.toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    try {
      await _client
          .from('skt_records')
          .update(payload)
          .eq('id', recordId)
          .select('id')
          .single();
    } on PostgrestException catch (e, stackTrace) {
      log('SKT kaydi guncelleme hatasi: ${e.message}',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      log('SKT kaydi guncelleme beklenmeyen hata: $e',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<bool> deleteRecord({required String recordId}) async {
    try {
      final response = await _client
          .from('skt_records')
          .delete()
          .eq('id', recordId)
          .select('id');

      final data = (response as List?)?.cast<Map<String, dynamic>>();
      if (data == null) {
        return false;
      }

      return data.isNotEmpty;
    } on PostgrestException catch (e, stackTrace) {
      log('SKT kaydi silme hatasi: ${e.message}',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    } catch (e, stackTrace) {
      log('SKT kaydi silme beklenmeyen hata: $e',
          name: 'SktRepository', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }
}

String _statusFor(DateTime expiryUtc) {
  final nowUtc = DateTime.now().toUtc();
  final days = expiryUtc.difference(nowUtc).inDays;
  if (days < 0) {
    return 'gecmis';
  }
  if (days <= 7) {
    return 'yaklasan';
  }
  return 'normal';
}
