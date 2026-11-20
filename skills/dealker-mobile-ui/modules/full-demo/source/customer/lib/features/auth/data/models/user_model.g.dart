// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserModel _$UserModelFromJson(Map<String, dynamic> json) => _UserModel(
      id: json['id'] as String,
      phone: json['phone'] as String,
      role: json['role'] as String,
      name: json['name'] as String?,
      email: json['email'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      loyaltyPoints: (json['loyalty_points'] as num?)?.toInt(),
      referralCode: json['referral_code'] as String?,
      b2bStatus: json['b2b_status'] as String?,
      b2bEnabled: json['b2b_enabled'] as bool?,
    );

Map<String, dynamic> _$UserModelToJson(_UserModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'phone': instance.phone,
      'role': instance.role,
      'name': instance.name,
      'email': instance.email,
      'avatar_url': instance.avatarUrl,
      'loyalty_points': instance.loyaltyPoints,
      'referral_code': instance.referralCode,
      'b2b_status': instance.b2bStatus,
      'b2b_enabled': instance.b2bEnabled,
    };
