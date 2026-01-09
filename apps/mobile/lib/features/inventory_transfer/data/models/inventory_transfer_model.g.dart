// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'inventory_transfer_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$DepotNoticeImpl _$$DepotNoticeImplFromJson(Map<String, dynamic> json) =>
    _$DepotNoticeImpl(
      id: json['id'] as String,
      tenantId: json['tenantId'] as String,
      branchId: json['branchId'] as String,
      branchName: json['branchName'] as String?,
      createdBy: json['createdBy'] as String,
      productName: json['productName'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      unit: json['unit'] as String? ?? 'adet',
      type: $enumDecode(_$DepotNoticeTypeEnumMap, json['type']),
      status: $enumDecodeNullable(_$DepotNoticeStatusEnumMap, json['status']) ??
          DepotNoticeStatus.open,
      note: json['note'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] == null
          ? null
          : DateTime.parse(json['updatedAt'] as String),
      offers: (json['offers'] as List<dynamic>?)
          ?.map((e) => NoticeOffer.fromJson(e as Map<String, dynamic>))
          .toList(),
    );

Map<String, dynamic> _$$DepotNoticeImplToJson(_$DepotNoticeImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'tenantId': instance.tenantId,
      'branchId': instance.branchId,
      'branchName': instance.branchName,
      'createdBy': instance.createdBy,
      'productName': instance.productName,
      'quantity': instance.quantity,
      'unit': instance.unit,
      'type': _$DepotNoticeTypeEnumMap[instance.type]!,
      'status': _$DepotNoticeStatusEnumMap[instance.status]!,
      'note': instance.note,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'createdAt': instance.createdAt.toIso8601String(),
      'updatedAt': instance.updatedAt?.toIso8601String(),
      'offers': instance.offers,
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
      noticeId: json['noticeId'] as String,
      tenantId: json['tenantId'] as String,
      branchId: json['branchId'] as String,
      branchName: json['branchName'] as String?,
      offeredBy: json['offeredBy'] as String,
      quantity: (json['quantity'] as num).toDouble(),
      status: $enumDecodeNullable(_$DepotOfferStatusEnumMap, json['status']) ??
          DepotOfferStatus.pending,
      decisionBy: json['decisionBy'] as String?,
      decisionAt: json['decisionAt'] == null
          ? null
          : DateTime.parse(json['decisionAt'] as String),
      message: json['message'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

Map<String, dynamic> _$$NoticeOfferImplToJson(_$NoticeOfferImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'noticeId': instance.noticeId,
      'tenantId': instance.tenantId,
      'branchId': instance.branchId,
      'branchName': instance.branchName,
      'offeredBy': instance.offeredBy,
      'quantity': instance.quantity,
      'status': _$DepotOfferStatusEnumMap[instance.status]!,
      'decisionBy': instance.decisionBy,
      'decisionAt': instance.decisionAt?.toIso8601String(),
      'message': instance.message,
      'createdAt': instance.createdAt.toIso8601String(),
    };

const _$DepotOfferStatusEnumMap = {
  DepotOfferStatus.pending: 'pending',
  DepotOfferStatus.accepted: 'accepted',
  DepotOfferStatus.rejected: 'rejected',
  DepotOfferStatus.expired: 'expired',
  DepotOfferStatus.cancelled: 'cancelled',
  DepotOfferStatus.delivered: 'delivered',
};
