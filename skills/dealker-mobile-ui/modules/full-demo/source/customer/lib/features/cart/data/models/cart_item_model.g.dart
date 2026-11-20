// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cart_item_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_CartItemModel _$CartItemModelFromJson(Map<String, dynamic> json) =>
    _CartItemModel(
      productId: json['productId'] as String,
      name: json['name'] as String,
      price: _cartDoubleFromJson(json['price']),
      quantity: (json['quantity'] as num).toInt(),
      total: _cartDoubleFromJson(json['lineTotal']),
      salePrice: _cartNullableDoubleFromJson(json['salePrice']),
      unit: json['unit'] as String?,
      netQuantity: json['netQuantity'] as String?,
      thumbnailUrl: json['thumbnailUrl'] as String?,
      shopProductId: json['shopProductId'] as String?,
      shopId: json['shopId'] as String?,
      shopName: json['shopName'] as String?,
      optionLabel: json['optionLabel'] as String?,
      familyName: json['familyName'] as String?,
      foodType: json['foodType'] as String?,
      originTag: json['originTag'] as String?,
      displayDeliveryMinutes: (json['displayDeliveryMinutes'] as num?)?.toInt(),
      categoryId: json['categoryId'] as String?,
      isAvailable: json['isAvailable'] == null
          ? true
          : _cartBoolFromJson(json['isAvailable']),
      stockQuantity: json['stockQuantity'] == null
          ? 9999
          : _cartStockFromJson(json['stockQuantity']),
      bulkMinQuantity: (json['bulkMinQuantity'] as num?)?.toInt(),
      bulkMaxQuantity: (json['bulkMaxQuantity'] as num?)?.toInt(),
    );

Map<String, dynamic> _$CartItemModelToJson(_CartItemModel instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'name': instance.name,
      'price': instance.price,
      'quantity': instance.quantity,
      'lineTotal': instance.total,
      'salePrice': instance.salePrice,
      'unit': instance.unit,
      'netQuantity': instance.netQuantity,
      'thumbnailUrl': instance.thumbnailUrl,
      'shopProductId': instance.shopProductId,
      'shopId': instance.shopId,
      'shopName': instance.shopName,
      'optionLabel': instance.optionLabel,
      'familyName': instance.familyName,
      'foodType': instance.foodType,
      'originTag': instance.originTag,
      'displayDeliveryMinutes': instance.displayDeliveryMinutes,
      'categoryId': instance.categoryId,
      'isAvailable': instance.isAvailable,
      'stockQuantity': instance.stockQuantity,
      'bulkMinQuantity': instance.bulkMinQuantity,
      'bulkMaxQuantity': instance.bulkMaxQuantity,
    };
