// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_stats_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_UserStatsModel _$UserStatsModelFromJson(Map<String, dynamic> json) =>
    _UserStatsModel(
      totalOrders: (json['total_orders'] as num?)?.toInt() ?? 0,
      totalSpent:
          json['total_spent'] == null ? 0 : _toDouble(json['total_spent']),
      loyaltyPoints: (json['loyalty_points'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$UserStatsModelToJson(_UserStatsModel instance) =>
    <String, dynamic>{
      'total_orders': instance.totalOrders,
      'total_spent': instance.totalSpent,
      'loyalty_points': instance.loyaltyPoints,
    };
