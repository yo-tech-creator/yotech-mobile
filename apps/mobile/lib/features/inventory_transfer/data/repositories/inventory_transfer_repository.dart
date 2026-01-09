import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:yotech_mobile/features/inventory_transfer/data/models/inventory_transfer_model.dart';

final inventoryTransferRepositoryProvider =
    Provider<InventoryTransferRepository>((ref) {
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
    return data.map((raw) {
      final map = raw as Map<String, dynamic>;
      var enrichedNotice = DepotNotice.fromJson(_normalizeNotice(map));
      if (map['offers'] != null) {
        final offersList = (map['offers'] as List).map<NoticeOffer>((o) {
          final offerMap = o as Map<String, dynamic>;
          return NoticeOffer.fromJson(_normalizeOffer(offerMap));
        }).toList();
        enrichedNotice = enrichedNotice.copyWith(offers: offersList);
      }
      return enrichedNotice;
    }).toList();
  }

  Future<void> createNotice(DepotNotice notice) async {
    await _client.from('depot_notices').insert({
      'tenant_id': notice.tenantId,
      'branch_id': notice.branchId,
      'created_by': notice.createdBy,
      'product_name': notice.productName,
      'quantity': notice.quantity.toInt(),
      'unit': notice.unit,
      'type': notice.type.name, // Enum to string
      'status': notice.status.dbValue,
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
      'quantity': offer.quantity.toInt(),
      'status': offer.status.name,
      'message': offer.message,
    });
  }

  Future<void> updateOfferStatus({
    required String offerId,
    required DepotOfferStatus status,
    String? decisionBy,
  }) async {
    final payload = {
      'status': status.name,
      'decision_at': DateTime.now().toIso8601String(),
    };
    if (decisionBy != null) {
      payload['decision_by'] = decisionBy;
    }
    await _client.from('depot_notice_offers').update(payload).eq('id', offerId);
  }

  Future<void> updateOwnOffer({
    required String offerId,
    required double quantity,
    String? message,
  }) async {
    await _client.from('depot_notice_offers').update({
      'quantity': quantity.toInt(),
      'message': message,
    }).eq('id', offerId);
  }

  Future<void> updateNoticeStatus({
    required String noticeId,
    required DepotNoticeStatus status,
  }) async {
    await _client.from('depot_notices').update({
      'status': status.dbValue,
    }).eq('id', noticeId);
  }

  Future<void> updateNoticeQuantity({
    required String noticeId,
    required double quantity,
    required DepotNoticeStatus status,
  }) async {
    await _client.from('depot_notices').update({
      'quantity': quantity.toInt(),
      'status': status.dbValue,
    }).eq('id', noticeId);
  }

  Future<void> deleteNotice(String noticeId) async {
    await _client.from('depot_notices').delete().eq('id', noticeId);
  }

  Map<String, dynamic> _normalizeNotice(Map<String, dynamic> map) {
    return {
      'id': map['id'],
      'tenantId': map['tenant_id'],
      'branchId': map['branch_id'],
      'branchName': map['branch_name'],
      'createdBy': map['created_by'],
      'productName': map['product_name'],
      'quantity': map['quantity'],
      'unit': map['unit'],
      'type': map['type'],
      'status': map['status'],
      'note': map['note'],
      'expiresAt': map['expires_at'],
      'createdAt': map['created_at'],
      'updatedAt': map['updated_at'],
      'offers': null,
    }..removeWhere((key, value) => value == null);
  }

  Map<String, dynamic> _normalizeOffer(Map<String, dynamic> map) {
    return {
      'id': map['id'],
      'noticeId': map['notice_id'],
      'tenantId': map['tenant_id'],
      'branchId': map['branch_id'],
      'branchName': map['branch_name'],
      'offeredBy': map['offered_by'],
      'quantity': map['quantity'],
      'status': map['status'],
      'decisionBy': map['decision_by'],
      'decisionAt': map['decision_at'],
      'message': map['message'],
      'createdAt': map['created_at'],
    }..removeWhere((key, value) => value == null);
  }
}
