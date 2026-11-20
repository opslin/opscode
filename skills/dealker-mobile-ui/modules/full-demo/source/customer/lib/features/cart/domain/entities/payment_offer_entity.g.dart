// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'payment_offer_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PaymentOfferEntity _$PaymentOfferEntityFromJson(Map<String, dynamic> json) =>
    _PaymentOfferEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      provider: json['provider'] as String,
      isLocked: json['isLocked'] as bool,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      cashbackType: json['cashbackType'] as String? ?? 'FLAT',
      cashbackAmount: json['cashbackAmount'] == null
          ? 0
          : _paymentOfferAmountFromJson(json['cashbackAmount']),
      cashbackPercent:
          _paymentOfferNullableAmountFromJson(json['cashbackPercent']),
      maxCashback: _paymentOfferNullableAmountFromJson(json['maxCashback']),
      minOrderAmount: json['minOrderAmount'] == null
          ? 0
          : _paymentOfferAmountFromJson(json['minOrderAmount']),
      lockMessage: json['lockMessage'] as String?,
      unlockProgress: json['unlockProgress'] == null
          ? 0
          : _paymentOfferAmountFromJson(json['unlockProgress']),
    );

Map<String, dynamic> _$PaymentOfferEntityToJson(_PaymentOfferEntity instance) =>
    <String, dynamic>{
      'id': instance.id,
      'title': instance.title,
      'provider': instance.provider,
      'isLocked': instance.isLocked,
      'description': instance.description,
      'iconUrl': instance.iconUrl,
      'cashbackType': instance.cashbackType,
      'cashbackAmount': instance.cashbackAmount,
      'cashbackPercent': instance.cashbackPercent,
      'maxCashback': instance.maxCashback,
      'minOrderAmount': instance.minOrderAmount,
      'lockMessage': instance.lockMessage,
      'unlockProgress': instance.unlockProgress,
    };
