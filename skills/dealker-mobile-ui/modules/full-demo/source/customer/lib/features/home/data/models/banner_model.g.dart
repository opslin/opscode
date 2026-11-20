// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'banner_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BannerModel _$BannerModelFromJson(Map<String, dynamic> json) => _BannerModel(
      id: json['id'] as String,
      imageUrl: json['image_url'] as String,
      linkType: json['link_type'] as String,
      title: json['title'] as String?,
      subtitle: json['subtitle'] as String?,
      linkValue: json['link_value'] as String?,
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$BannerModelToJson(_BannerModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'image_url': instance.imageUrl,
      'link_type': instance.linkType,
      'title': instance.title,
      'subtitle': instance.subtitle,
      'link_value': instance.linkValue,
      'sort_order': instance.sortOrder,
    };
