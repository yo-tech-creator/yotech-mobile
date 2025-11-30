import 'package:freezed_annotation/freezed_annotation.dart';

part 'inventory_transfer_model.freezed.dart';
part 'inventory_transfer_model.g.dart';

enum DepotNoticeType {
  @JsonValue('shortage')
  shortage,
  @JsonValue('surplus')
  surplus,
}

enum DepotNoticeStatus {
  @JsonValue('open')
  open,
  @JsonValue('in_transfer')
  inTransfer,
  @JsonValue('fulfilled')
  fulfilled,
  @JsonValue('cancelled')
  cancelled,
}

enum DepotOfferStatus {
  @JsonValue('pending')
  pending,
  @JsonValue('accepted')
  accepted,
  @JsonValue('rejected')
  rejected,
  @JsonValue('expired')
  expired,
}

@freezed
@JsonSerializable(fieldRename: FieldRename.snake, explicitToJson: true)
class DepotNotice with _$DepotNotice {
  const factory DepotNotice({
    required String id,
    required String tenantId,
    required String branchId,
    required String createdBy,
    required String productName,
    required double quantity,
    @Default('adet') String unit,
    required DepotNoticeType type,
    @Default(DepotNoticeStatus.open) DepotNoticeStatus status,
    String? note,
    DateTime? expiresAt,
    required DateTime createdAt,
    DateTime? updatedAt,
    List<NoticeOffer>? offers,
  }) = _DepotNotice;

  factory DepotNotice.fromJson(Map<String, dynamic> json) =>
      _$DepotNoticeFromJson(json);
}

@freezed
@JsonSerializable(fieldRename: FieldRename.snake)
class NoticeOffer with _$NoticeOffer {
  const factory NoticeOffer({
    required String id,
    required String noticeId,
    required String tenantId,
    required String branchId,
    required String offeredBy,
    required double quantity,
    @Default(DepotOfferStatus.pending) DepotOfferStatus status,
    String? decisionBy,
    DateTime? decisionAt,
    String? message,
    required DateTime createdAt,
  }) = _NoticeOffer;

  factory NoticeOffer.fromJson(Map<String, dynamic> json) =>
      _$NoticeOfferFromJson(json);
}
