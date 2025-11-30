import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/models/inventory_transfer_model.dart';

final inventoryTransferRepositoryProvider = Provider<InventoryTransferRepository>((ref) {
  return InventoryTransferRepository(Supabase.instance.client);
});

class InventoryTransferRepository {
  final SupabaseClient _client;

  InventoryTransferRepository(this._client);

  Future<List<DepotNotice>> getNotices({required String tenantId}) async {
    final response = await _client
        .from('depot_notices')
        .select('*, offers:depot_notice_offers(*)')
        .eq('tenant_id', tenantId)
        .order('created_at', ascending: false);

    final List<dynamic> data = response as List<dynamic>;
    return data.map((e) {
      final notice = DepotNotice.fromJson(e);
      // Manually map offers if they exist in the response
      if (e['offers'] != null) {
        final offersList = (e['offers'] as List).map((o) => NoticeOffer.fromJson(o)).toList();
        return notice.copyWith(offers: offersList);
      }
      return notice;
    }).toList();
  }

  Future<void> createNotice(DepotNotice notice) async {
    await _client.from('depot_notices').insert({
      'tenant_id': notice.tenantId,
      'branch_id': notice.branchId,
      'created_by': notice.createdBy,
      'product_name': notice.productName,
      'quantity': notice.quantity,
      'unit': notice.unit,
      'type': notice.type.name, // Enum to string
      'status': notice.status.name,
      'note': notice.note,
      'expires_at': notice.expiresAt?.toIso8601String(),
    });
  }

  Future<void> createOffer(NoticeOffer offer) async {
    await _client.from('depot_notice_offers').insert({
      'notice_id': offer.noticeId,
      'tenant_id': offer.tenantId,
      'branch_id': offer.branchId,
      'offered_by': offer.offeredBy,
      'quantity': offer.quantity,
      'status': offer.status.name,
      'message': offer.message,
    });
  }

  Future<void> updateOfferStatus({
    required String offerId,
    required DepotOfferStatus status,
    required String decisionBy,
  }) async {
    await _client.from('depot_notice_offers').update({
      'status': status.name,
      'decision_by': decisionBy,
      'decision_at': DateTime.now().toIso8601String(),
    }).eq('id', offerId);
  }
  
  Future<void> updateNoticeStatus({
    required String noticeId,
    required DepotNoticeStatus status,
  }) async {
    await _client.from('depot_notices').update({
      'status': status.name,
    }).eq('id', noticeId);
  }
}
