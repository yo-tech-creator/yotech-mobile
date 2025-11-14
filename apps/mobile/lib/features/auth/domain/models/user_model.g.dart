// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_$UserModelImpl _$$UserModelImplFromJson(Map<String, dynamic> json) =>
    _$UserModelImpl(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      surname: json['surname'] as String,
      role: json['role'] as String,
      tenantId: json['tenantId'] as String,
      branchId: json['branchId'] as String?,
      regionId: json['regionId'] as String?,
      sicilNo: json['sicilNo'] as String?,
    );

Map<String, dynamic> _$$UserModelImplToJson(_$UserModelImpl instance) =>
    <String, dynamic>{
      'id': instance.id,
      'email': instance.email,
      'name': instance.name,
      'surname': instance.surname,
      'role': instance.role,
      'tenantId': instance.tenantId,
      'branchId': instance.branchId,
      'regionId': instance.regionId,
      'sicilNo': instance.sicilNo,
    };
