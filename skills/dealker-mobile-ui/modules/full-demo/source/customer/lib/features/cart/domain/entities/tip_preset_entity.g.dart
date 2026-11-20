// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tip_preset_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_TipPresetEntity _$TipPresetEntityFromJson(Map<String, dynamic> json) =>
    _TipPresetEntity(
      amount: _tipPresetAmountFromJson(json['amount']),
      emoji: json['emoji'] as String?,
    );

Map<String, dynamic> _$TipPresetEntityToJson(_TipPresetEntity instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'emoji': instance.emoji,
    };
