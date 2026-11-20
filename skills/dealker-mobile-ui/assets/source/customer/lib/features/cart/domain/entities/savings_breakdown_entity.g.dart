// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'savings_breakdown_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_SavingsBreakdownEntity _$SavingsBreakdownEntityFromJson(
        Map<String, dynamic> json) =>
    _SavingsBreakdownEntity(
      total: (json['total'] as num?)?.toDouble() ?? 0,
      items: (json['breakdown'] as List<dynamic>?)
              ?.map((e) => SavingsLineItem.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <SavingsLineItem>[],
    );

Map<String, dynamic> _$SavingsBreakdownEntityToJson(
        _SavingsBreakdownEntity instance) =>
    <String, dynamic>{
      'total': instance.total,
      'breakdown': instance.items,
    };

_SavingsLineItem _$SavingsLineItemFromJson(Map<String, dynamic> json) =>
    _SavingsLineItem(
      type: json['type'] as String,
      label: json['label'] as String,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$SavingsLineItemToJson(_SavingsLineItem instance) =>
    <String, dynamic>{
      'type': instance.type,
      'label': instance.label,
      'amount': instance.amount,
    };
