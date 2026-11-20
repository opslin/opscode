// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'purchase_limit_status_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PurchaseLimitStatusModel _$PurchaseLimitStatusModelFromJson(
        Map<String, dynamic> json) =>
    _PurchaseLimitStatusModel(
      productId: json['productId'] as String,
      remainingToAdd: (json['remainingToAdd'] as num).toInt(),
      isAtLimit: json['isAtLimit'] as bool,
      categoryId: json['categoryId'] as String?,
      ruleLabel: json['ruleLabel'] as String?,
      maxQtyPerOrder: (json['maxQtyPerOrder'] as num?)?.toInt(),
      remainingThisOrder: (json['remainingThisOrder'] as num?)?.toInt(),
      windowEnabled: json['windowEnabled'] as bool?,
      windowPeriod: json['windowPeriod'] as String?,
      windowCount: (json['windowCount'] as num?)?.toInt(),
      maxQtyPerWindow: (json['maxQtyPerWindow'] as num?)?.toInt(),
      usedInWindow: (json['usedInWindow'] as num?)?.toInt(),
      remainingInWindow: (json['remainingInWindow'] as num?)?.toInt(),
    );

Map<String, dynamic> _$PurchaseLimitStatusModelToJson(
        _PurchaseLimitStatusModel instance) =>
    <String, dynamic>{
      'productId': instance.productId,
      'remainingToAdd': instance.remainingToAdd,
      'isAtLimit': instance.isAtLimit,
      'categoryId': instance.categoryId,
      'ruleLabel': instance.ruleLabel,
      'maxQtyPerOrder': instance.maxQtyPerOrder,
      'remainingThisOrder': instance.remainingThisOrder,
      'windowEnabled': instance.windowEnabled,
      'windowPeriod': instance.windowPeriod,
      'windowCount': instance.windowCount,
      'maxQtyPerWindow': instance.maxQtyPerWindow,
      'usedInWindow': instance.usedInWindow,
      'remainingInWindow': instance.remainingInWindow,
    };
