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
  @JsonValue('cancelled')
  cancelled,
  @JsonValue('delivered')
  delivered,
}

@freezed
@JsonSerializable(
  fieldRename: FieldRename.snake,
  explicitToJson: true,
  createFactory: false,
  createToJson: false,
)
class DepotNotice with _$DepotNotice {
  const factory DepotNotice({
    required String id,
    required String tenantId,
    required String branchId,
    String? branchName,
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
@JsonSerializable(
  fieldRename: FieldRename.snake,
  createFactory: false,
  createToJson: false,
)
class NoticeOffer with _$NoticeOffer {
  const factory NoticeOffer({
    required String id,
    required String noticeId,
    required String tenantId,
    required String branchId,
    String? branchName,
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

extension DepotNoticeStatusDbX on DepotNoticeStatus {
  String get dbValue {
    switch (this) {
      case DepotNoticeStatus.inTransfer:
        return 'in_transfer';
      case DepotNoticeStatus.open:
        return 'open';
      case DepotNoticeStatus.fulfilled:
        return 'fulfilled';
      case DepotNoticeStatus.cancelled:
        return 'cancelled';
    }
  }
}

extension DepotNoticeComputedX on DepotNotice {
  static const Set<DepotOfferStatus> _reservedStatuses = {
    DepotOfferStatus.accepted,
    DepotOfferStatus.delivered,
  };

  double get reservedQuantity {
    final offersList = offers ?? const <NoticeOffer>[];
    var total = 0.0;
    for (final offer in offersList) {
      if (_reservedStatuses.contains(offer.status)) {
        total += offer.quantity;
      }
    }
    return total;
  }

  double get remainingQuantity {
    final remaining = quantity - reservedQuantity;
    if (remaining <= 0) return 0;
    return remaining;
  }

  bool get hasRemaining => remainingQuantity > 0;
}
