// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CartModel _$CartModelFromJson(Map<String, dynamic> json) => _CartModel(
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => CartItemModel.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <CartItemModel>[],
      subtotal: json['subtotal'] == null
          ? 0
          : _cartSubtotalFromJson(json['subtotal']),
      itemCount: (json['count'] as num?)?.toInt() ?? 0,
      tipAmount: json['tipAmount'] == null
          ? 0
          : _cartSubtotalFromJson(json['tipAmount']),
      deliveryInstructions: json['deliveryInstructions'] as String?,
    );

Map<String, dynamic> _$CartModelToJson(_CartModel instance) =>
    <String, dynamic>{
      'items': instance.items,
      'subtotal': instance.subtotal,
      'count': instance.itemCount,
      'tipAmount': instance.tipAmount,
      'deliveryInstructions': instance.deliveryInstructions,
    };
