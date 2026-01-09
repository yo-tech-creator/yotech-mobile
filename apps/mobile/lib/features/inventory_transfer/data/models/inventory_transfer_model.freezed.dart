// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'inventory_transfer_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

DepotNotice _$DepotNoticeFromJson(Map<String, dynamic> json) {
  return _DepotNotice.fromJson(json);
}

/// @nodoc
mixin _$DepotNotice {
  String get id => throw _privateConstructorUsedError;
  String get tenantId => throw _privateConstructorUsedError;
  String get branchId => throw _privateConstructorUsedError;
  String? get branchName => throw _privateConstructorUsedError;
  String get createdBy => throw _privateConstructorUsedError;
  String get productName => throw _privateConstructorUsedError;
  double get quantity => throw _privateConstructorUsedError;
  String get unit => throw _privateConstructorUsedError;
  DepotNoticeType get type => throw _privateConstructorUsedError;
  DepotNoticeStatus get status => throw _privateConstructorUsedError;
  String? get note => throw _privateConstructorUsedError;
  DateTime? get expiresAt => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  DateTime? get updatedAt => throw _privateConstructorUsedError;
  List<NoticeOffer>? get offers => throw _privateConstructorUsedError;

  /// Serializes this DepotNotice to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of DepotNotice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $DepotNoticeCopyWith<DepotNotice> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $DepotNoticeCopyWith<$Res> {
  factory $DepotNoticeCopyWith(
          DepotNotice value, $Res Function(DepotNotice) then) =
      _$DepotNoticeCopyWithImpl<$Res, DepotNotice>;
  @useResult
  $Res call(
      {String id,
      String tenantId,
      String branchId,
      String? branchName,
      String createdBy,
      String productName,
      double quantity,
      String unit,
      DepotNoticeType type,
      DepotNoticeStatus status,
      String? note,
      DateTime? expiresAt,
      DateTime createdAt,
      DateTime? updatedAt,
      List<NoticeOffer>? offers});
}

/// @nodoc
class _$DepotNoticeCopyWithImpl<$Res, $Val extends DepotNotice>
    implements $DepotNoticeCopyWith<$Res> {
  _$DepotNoticeCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of DepotNotice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? branchId = null,
    Object? branchName = freezed,
    Object? createdBy = null,
    Object? productName = null,
    Object? quantity = null,
    Object? unit = null,
    Object? type = null,
    Object? status = null,
    Object? note = freezed,
    Object? expiresAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? offers = freezed,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      branchId: null == branchId
          ? _value.branchId
          : branchId // ignore: cast_nullable_to_non_nullable
              as String,
      branchName: freezed == branchName
          ? _value.branchName
          : branchName // ignore: cast_nullable_to_non_nullable
              as String?,
      createdBy: null == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      productName: null == productName
          ? _value.productName
          : productName // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as double,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as DepotNoticeType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as DepotNoticeStatus,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      offers: freezed == offers
          ? _value.offers
          : offers // ignore: cast_nullable_to_non_nullable
              as List<NoticeOffer>?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$DepotNoticeImplCopyWith<$Res>
    implements $DepotNoticeCopyWith<$Res> {
  factory _$$DepotNoticeImplCopyWith(
          _$DepotNoticeImpl value, $Res Function(_$DepotNoticeImpl) then) =
      __$$DepotNoticeImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String tenantId,
      String branchId,
      String? branchName,
      String createdBy,
      String productName,
      double quantity,
      String unit,
      DepotNoticeType type,
      DepotNoticeStatus status,
      String? note,
      DateTime? expiresAt,
      DateTime createdAt,
      DateTime? updatedAt,
      List<NoticeOffer>? offers});
}

/// @nodoc
class __$$DepotNoticeImplCopyWithImpl<$Res>
    extends _$DepotNoticeCopyWithImpl<$Res, _$DepotNoticeImpl>
    implements _$$DepotNoticeImplCopyWith<$Res> {
  __$$DepotNoticeImplCopyWithImpl(
      _$DepotNoticeImpl _value, $Res Function(_$DepotNoticeImpl) _then)
      : super(_value, _then);

  /// Create a copy of DepotNotice
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? tenantId = null,
    Object? branchId = null,
    Object? branchName = freezed,
    Object? createdBy = null,
    Object? productName = null,
    Object? quantity = null,
    Object? unit = null,
    Object? type = null,
    Object? status = null,
    Object? note = freezed,
    Object? expiresAt = freezed,
    Object? createdAt = null,
    Object? updatedAt = freezed,
    Object? offers = freezed,
  }) {
    return _then(_$DepotNoticeImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      branchId: null == branchId
          ? _value.branchId
          : branchId // ignore: cast_nullable_to_non_nullable
              as String,
      branchName: freezed == branchName
          ? _value.branchName
          : branchName // ignore: cast_nullable_to_non_nullable
              as String?,
      createdBy: null == createdBy
          ? _value.createdBy
          : createdBy // ignore: cast_nullable_to_non_nullable
              as String,
      productName: null == productName
          ? _value.productName
          : productName // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as double,
      unit: null == unit
          ? _value.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _value.type
          : type // ignore: cast_nullable_to_non_nullable
              as DepotNoticeType,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as DepotNoticeStatus,
      note: freezed == note
          ? _value.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
      expiresAt: freezed == expiresAt
          ? _value.expiresAt
          : expiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      updatedAt: freezed == updatedAt
          ? _value.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      offers: freezed == offers
          ? _value._offers
          : offers // ignore: cast_nullable_to_non_nullable
              as List<NoticeOffer>?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$DepotNoticeImpl implements _DepotNotice {
  const _$DepotNoticeImpl(
      {required this.id,
      required this.tenantId,
      required this.branchId,
      this.branchName,
      required this.createdBy,
      required this.productName,
      required this.quantity,
      this.unit = 'adet',
      required this.type,
      this.status = DepotNoticeStatus.open,
      this.note,
      this.expiresAt,
      required this.createdAt,
      this.updatedAt,
      final List<NoticeOffer>? offers})
      : _offers = offers;

  factory _$DepotNoticeImpl.fromJson(Map<String, dynamic> json) =>
      _$$DepotNoticeImplFromJson(json);

  @override
  final String id;
  @override
  final String tenantId;
  @override
  final String branchId;
  @override
  final String? branchName;
  @override
  final String createdBy;
  @override
  final String productName;
  @override
  final double quantity;
  @override
  @JsonKey()
  final String unit;
  @override
  final DepotNoticeType type;
  @override
  @JsonKey()
  final DepotNoticeStatus status;
  @override
  final String? note;
  @override
  final DateTime? expiresAt;
  @override
  final DateTime createdAt;
  @override
  final DateTime? updatedAt;
  final List<NoticeOffer>? _offers;
  @override
  List<NoticeOffer>? get offers {
    final value = _offers;
    if (value == null) return null;
    if (_offers is EqualUnmodifiableListView) return _offers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  String toString() {
    return 'DepotNotice(id: $id, tenantId: $tenantId, branchId: $branchId, branchName: $branchName, createdBy: $createdBy, productName: $productName, quantity: $quantity, unit: $unit, type: $type, status: $status, note: $note, expiresAt: $expiresAt, createdAt: $createdAt, updatedAt: $updatedAt, offers: $offers)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$DepotNoticeImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.branchName, branchName) ||
                other.branchName == branchName) &&
            (identical(other.createdBy, createdBy) ||
                other.createdBy == createdBy) &&
            (identical(other.productName, productName) ||
                other.productName == productName) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.note, note) || other.note == note) &&
            (identical(other.expiresAt, expiresAt) ||
                other.expiresAt == expiresAt) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            const DeepCollectionEquality().equals(other._offers, _offers));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      tenantId,
      branchId,
      branchName,
      createdBy,
      productName,
      quantity,
      unit,
      type,
      status,
      note,
      expiresAt,
      createdAt,
      updatedAt,
      const DeepCollectionEquality().hash(_offers));

  /// Create a copy of DepotNotice
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$DepotNoticeImplCopyWith<_$DepotNoticeImpl> get copyWith =>
      __$$DepotNoticeImplCopyWithImpl<_$DepotNoticeImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$DepotNoticeImplToJson(
      this,
    );
  }
}

abstract class _DepotNotice implements DepotNotice {
  const factory _DepotNotice(
      {required final String id,
      required final String tenantId,
      required final String branchId,
      final String? branchName,
      required final String createdBy,
      required final String productName,
      required final double quantity,
      final String unit,
      required final DepotNoticeType type,
      final DepotNoticeStatus status,
      final String? note,
      final DateTime? expiresAt,
      required final DateTime createdAt,
      final DateTime? updatedAt,
      final List<NoticeOffer>? offers}) = _$DepotNoticeImpl;

  factory _DepotNotice.fromJson(Map<String, dynamic> json) =
      _$DepotNoticeImpl.fromJson;

  @override
  String get id;
  @override
  String get tenantId;
  @override
  String get branchId;
  @override
  String? get branchName;
  @override
  String get createdBy;
  @override
  String get productName;
  @override
  double get quantity;
  @override
  String get unit;
  @override
  DepotNoticeType get type;
  @override
  DepotNoticeStatus get status;
  @override
  String? get note;
  @override
  DateTime? get expiresAt;
  @override
  DateTime get createdAt;
  @override
  DateTime? get updatedAt;
  @override
  List<NoticeOffer>? get offers;

  /// Create a copy of DepotNotice
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$DepotNoticeImplCopyWith<_$DepotNoticeImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

NoticeOffer _$NoticeOfferFromJson(Map<String, dynamic> json) {
  return _NoticeOffer.fromJson(json);
}

/// @nodoc
mixin _$NoticeOffer {
  String get id => throw _privateConstructorUsedError;
  String get noticeId => throw _privateConstructorUsedError;
  String get tenantId => throw _privateConstructorUsedError;
  String get branchId => throw _privateConstructorUsedError;
  String? get branchName => throw _privateConstructorUsedError;
  String get offeredBy => throw _privateConstructorUsedError;
  double get quantity => throw _privateConstructorUsedError;
  DepotOfferStatus get status => throw _privateConstructorUsedError;
  String? get decisionBy => throw _privateConstructorUsedError;
  DateTime? get decisionAt => throw _privateConstructorUsedError;
  String? get message => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;

  /// Serializes this NoticeOffer to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of NoticeOffer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $NoticeOfferCopyWith<NoticeOffer> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $NoticeOfferCopyWith<$Res> {
  factory $NoticeOfferCopyWith(
          NoticeOffer value, $Res Function(NoticeOffer) then) =
      _$NoticeOfferCopyWithImpl<$Res, NoticeOffer>;
  @useResult
  $Res call(
      {String id,
      String noticeId,
      String tenantId,
      String branchId,
      String? branchName,
      String offeredBy,
      double quantity,
      DepotOfferStatus status,
      String? decisionBy,
      DateTime? decisionAt,
      String? message,
      DateTime createdAt});
}

/// @nodoc
class _$NoticeOfferCopyWithImpl<$Res, $Val extends NoticeOffer>
    implements $NoticeOfferCopyWith<$Res> {
  _$NoticeOfferCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of NoticeOffer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? noticeId = null,
    Object? tenantId = null,
    Object? branchId = null,
    Object? branchName = freezed,
    Object? offeredBy = null,
    Object? quantity = null,
    Object? status = null,
    Object? decisionBy = freezed,
    Object? decisionAt = freezed,
    Object? message = freezed,
    Object? createdAt = null,
  }) {
    return _then(_value.copyWith(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      noticeId: null == noticeId
          ? _value.noticeId
          : noticeId // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      branchId: null == branchId
          ? _value.branchId
          : branchId // ignore: cast_nullable_to_non_nullable
              as String,
      branchName: freezed == branchName
          ? _value.branchName
          : branchName // ignore: cast_nullable_to_non_nullable
              as String?,
      offeredBy: null == offeredBy
          ? _value.offeredBy
          : offeredBy // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as DepotOfferStatus,
      decisionBy: freezed == decisionBy
          ? _value.decisionBy
          : decisionBy // ignore: cast_nullable_to_non_nullable
              as String?,
      decisionAt: freezed == decisionAt
          ? _value.decisionAt
          : decisionAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$NoticeOfferImplCopyWith<$Res>
    implements $NoticeOfferCopyWith<$Res> {
  factory _$$NoticeOfferImplCopyWith(
          _$NoticeOfferImpl value, $Res Function(_$NoticeOfferImpl) then) =
      __$$NoticeOfferImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String id,
      String noticeId,
      String tenantId,
      String branchId,
      String? branchName,
      String offeredBy,
      double quantity,
      DepotOfferStatus status,
      String? decisionBy,
      DateTime? decisionAt,
      String? message,
      DateTime createdAt});
}

/// @nodoc
class __$$NoticeOfferImplCopyWithImpl<$Res>
    extends _$NoticeOfferCopyWithImpl<$Res, _$NoticeOfferImpl>
    implements _$$NoticeOfferImplCopyWith<$Res> {
  __$$NoticeOfferImplCopyWithImpl(
      _$NoticeOfferImpl _value, $Res Function(_$NoticeOfferImpl) _then)
      : super(_value, _then);

  /// Create a copy of NoticeOffer
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? noticeId = null,
    Object? tenantId = null,
    Object? branchId = null,
    Object? branchName = freezed,
    Object? offeredBy = null,
    Object? quantity = null,
    Object? status = null,
    Object? decisionBy = freezed,
    Object? decisionAt = freezed,
    Object? message = freezed,
    Object? createdAt = null,
  }) {
    return _then(_$NoticeOfferImpl(
      id: null == id
          ? _value.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      noticeId: null == noticeId
          ? _value.noticeId
          : noticeId // ignore: cast_nullable_to_non_nullable
              as String,
      tenantId: null == tenantId
          ? _value.tenantId
          : tenantId // ignore: cast_nullable_to_non_nullable
              as String,
      branchId: null == branchId
          ? _value.branchId
          : branchId // ignore: cast_nullable_to_non_nullable
              as String,
      branchName: freezed == branchName
          ? _value.branchName
          : branchName // ignore: cast_nullable_to_non_nullable
              as String?,
      offeredBy: null == offeredBy
          ? _value.offeredBy
          : offeredBy // ignore: cast_nullable_to_non_nullable
              as String,
      quantity: null == quantity
          ? _value.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as double,
      status: null == status
          ? _value.status
          : status // ignore: cast_nullable_to_non_nullable
              as DepotOfferStatus,
      decisionBy: freezed == decisionBy
          ? _value.decisionBy
          : decisionBy // ignore: cast_nullable_to_non_nullable
              as String?,
      decisionAt: freezed == decisionAt
          ? _value.decisionAt
          : decisionAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      message: freezed == message
          ? _value.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$NoticeOfferImpl implements _NoticeOffer {
  const _$NoticeOfferImpl(
      {required this.id,
      required this.noticeId,
      required this.tenantId,
      required this.branchId,
      this.branchName,
      required this.offeredBy,
      required this.quantity,
      this.status = DepotOfferStatus.pending,
      this.decisionBy,
      this.decisionAt,
      this.message,
      required this.createdAt});

  factory _$NoticeOfferImpl.fromJson(Map<String, dynamic> json) =>
      _$$NoticeOfferImplFromJson(json);

  @override
  final String id;
  @override
  final String noticeId;
  @override
  final String tenantId;
  @override
  final String branchId;
  @override
  final String? branchName;
  @override
  final String offeredBy;
  @override
  final double quantity;
  @override
  @JsonKey()
  final DepotOfferStatus status;
  @override
  final String? decisionBy;
  @override
  final DateTime? decisionAt;
  @override
  final String? message;
  @override
  final DateTime createdAt;

  @override
  String toString() {
    return 'NoticeOffer(id: $id, noticeId: $noticeId, tenantId: $tenantId, branchId: $branchId, branchName: $branchName, offeredBy: $offeredBy, quantity: $quantity, status: $status, decisionBy: $decisionBy, decisionAt: $decisionAt, message: $message, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$NoticeOfferImpl &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.noticeId, noticeId) ||
                other.noticeId == noticeId) &&
            (identical(other.tenantId, tenantId) ||
                other.tenantId == tenantId) &&
            (identical(other.branchId, branchId) ||
                other.branchId == branchId) &&
            (identical(other.branchName, branchName) ||
                other.branchName == branchName) &&
            (identical(other.offeredBy, offeredBy) ||
                other.offeredBy == offeredBy) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.decisionBy, decisionBy) ||
                other.decisionBy == decisionBy) &&
            (identical(other.decisionAt, decisionAt) ||
                other.decisionAt == decisionAt) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      noticeId,
      tenantId,
      branchId,
      branchName,
      offeredBy,
      quantity,
      status,
      decisionBy,
      decisionAt,
      message,
      createdAt);

  /// Create a copy of NoticeOffer
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$NoticeOfferImplCopyWith<_$NoticeOfferImpl> get copyWith =>
      __$$NoticeOfferImplCopyWithImpl<_$NoticeOfferImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$NoticeOfferImplToJson(
      this,
    );
  }
}

abstract class _NoticeOffer implements NoticeOffer {
  const factory _NoticeOffer(
      {required final String id,
      required final String noticeId,
      required final String tenantId,
      required final String branchId,
      final String? branchName,
      required final String offeredBy,
      required final double quantity,
      final DepotOfferStatus status,
      final String? decisionBy,
      final DateTime? decisionAt,
      final String? message,
      required final DateTime createdAt}) = _$NoticeOfferImpl;

  factory _NoticeOffer.fromJson(Map<String, dynamic> json) =
      _$NoticeOfferImpl.fromJson;

  @override
  String get id;
  @override
  String get noticeId;
  @override
  String get tenantId;
  @override
  String get branchId;
  @override
  String? get branchName;
  @override
  String get offeredBy;
  @override
  double get quantity;
  @override
  DepotOfferStatus get status;
  @override
  String? get decisionBy;
  @override
  DateTime? get decisionAt;
  @override
  String? get message;
  @override
  DateTime get createdAt;

  /// Create a copy of NoticeOffer
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$NoticeOfferImplCopyWith<_$NoticeOfferImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
