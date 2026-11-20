// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'address_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AddressModel _$AddressModelFromJson(Map<String, dynamic> json) =>
    _AddressModel(
      id: json['id'] as String,
      addressLine1: json['addressLine1'] as String,
      city: json['city'] as String,
      pincode: json['pincode'] as String,
      label: json['label'] as String? ?? 'Home',
      state: json['state'] as String? ?? '',
      latitude: json['lat'] == null ? 0 : _addressDoubleFromJson(json['lat']),
      longitude: json['lng'] == null ? 0 : _addressDoubleFromJson(json['lng']),
      addressLine2: json['addressLine2'] as String?,
      receiverName: json['receiverName'] as String?,
      receiverPhone: json['receiverPhone'] as String?,
      isDefault: json['isDefault'] as bool? ?? false,
    );

Map<String, dynamic> _$AddressModelToJson(_AddressModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'addressLine1': instance.addressLine1,
      'city': instance.city,
      'pincode': instance.pincode,
      'label': instance.label,
      'state': instance.state,
      'lat': instance.latitude,
      'lng': instance.longitude,
      'addressLine2': instance.addressLine2,
      'receiverName': instance.receiverName,
      'receiverPhone': instance.receiverPhone,
      'isDefault': instance.isDefault,
    };
