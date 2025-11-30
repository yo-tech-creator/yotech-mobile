// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_transfer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DepotNoticeImpl _$$DepotNoticeImplFromJson(Map<String, dynamic> json) =>
    _$DepotNoticeImpl(
      id: json['id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      createdBy: json['created_by'] as String,
      productName: json['product_name'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'adet',
      type: $enumDecode(_$DepotNoticeTypeEnumMap, json['type']),
      status: $enumDecodeNullable(_$DepotNoticeStatusEnumMap, json['status']) ??
          DepotNoticeStatus.open,
      note: json['note'] as String?,
      expiresAt: json['expires_at'] == null
          ? null
          : DateTime.parse(json['expires_at'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$$DepotNoticeImplToJson(_$DepotNoticeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenant_id': instance.tenantId,
      'branch_id': instance.branchId,
      'created_by': instance.createdBy,
      'product_name': instance.productName,
      'quantity': instance.quantity,
      'unit': instance.unit,
      'type': _$DepotNoticeTypeEnumMap[instance.type]!,
      'status': _$DepotNoticeStatusEnumMap[instance.status]!,
      'note': instance.note,
      'expires_at': instance.expiresAt?.toIso8601String(),
      'created_at': instance.createdAt.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };

const _$DepotNoticeTypeEnumMap = {
  DepotNoticeType.shortage: 'shortage',
  DepotNoticeType.surplus: 'surplus',
};

const _$DepotNoticeStatusEnumMap = {
  DepotNoticeStatus.open: 'open',
  DepotNoticeStatus.inTransfer: 'in_transfer',
  DepotNoticeStatus.fulfilled: 'fulfilled',
  DepotNoticeStatus.cancelled: 'cancelled',
};

_$NoticeOfferImpl _$$NoticeOfferImplFromJson(Map<String, dynamic> json) =>
    _$NoticeOfferImpl(
      id: json['id'] as String,
      noticeId: json['notice_id'] as String,
      tenantId: json['tenant_id'] as String,
      branchId: json['branch_id'] as String,
      offeredBy: json['offered_by'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      status: $enumDecodeNullable(_$DepotOfferStatusEnumMap, json['status']) ??
          DepotOfferStatus.pending,
      decisionBy: json['decision_by'] as String?,
      decisionAt: json['decision_at'] == null
          ? null
          : DateTime.parse(json['decision_at'] as String),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );

Map<String, dynamic> _$$NoticeOfferImplToJson(_$NoticeOfferImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'notice_id': instance.noticeId,
      'tenant_id': instance.tenantId,
      'branch_id': instance.branchId,
      'offered_by': instance.offeredBy,
      'quantity': instance.quantity,
      'status': _$DepotOfferStatusEnumMap[instance.status]!,
      'decision_by': instance.decisionBy,
      'decision_at': instance.decisionAt?.toIso8601String(),
      'message': instance.message,
      'created_at': instance.createdAt.toIso8601String(),
    };

const _$DepotOfferStatusEnumMap = {
  DepotOfferStatus.pending: 'pending',
  DepotOfferStatus.accepted: 'accepted',
  DepotOfferStatus.rejected: 'rejected',
  DepotOfferStatus.expired: 'expired',
};
