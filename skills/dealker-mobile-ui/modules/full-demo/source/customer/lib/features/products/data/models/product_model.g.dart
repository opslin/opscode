// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'product_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProductModel _$ProductModelFromJson(Map<String, dynamic> json) =>
    _ProductModel(
      id: json['id'] as String,
      name: json['name'] as String,
      slug: json['slug'] as String,
      price: _productPriceFromJson(json['price']),
      stockQuantity: (json['stock_quantity'] as num).toInt(),
      unit: json['unit'] as String,
      salePrice: _productSalePriceFromJson(json['sale_price']),
      categoryId: json['category_id'] as String?,
      categoryName: json['category_name'] as String?,
      images: (json['images'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const <String>[],
      thumbnailUrl: json['thumbnail_url'] as String?,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              const <String>[],
      isFeatured: json['is_featured'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      totalSold: (json['total_sold'] as num?)?.toInt() ?? 0,
      description: json['description'] as String?,
      ingredients: json['ingredients'] as String?,
      nutritionInfo: _productMapFromJson(json['nutrition_info']),
      storageInstructions: json['storage_instructions'] as String?,
      brand: json['brand'] as String?,
      brandLogoUrl: json['brand_logo_url'] as String?,
      netQuantity: json['net_quantity'] as String?,
      highlights: _productMapFromJson(json['highlights']),
      attributes: json['attributes'] as List<dynamic>?,
      vendorName: json['vendor_name'] as String?,
      soldBy: json['sold_by'] as String?,
      createdAt: json['created_at'] as String?,
      vendorAddress: json['vendor_address'] as String?,
      vendorFssai: json['vendor_fssai'] as String?,
      returnPolicy: json['return_policy'] as String? ?? 'no_return',
      avgRating: json['avg_rating'] == null
          ? 0.0
          : _productPriceFromJson(json['avg_rating']),
      ratingCount: (json['rating_count'] as num?)?.toInt() ?? 0,
      isAuthentic: json['is_authentic'] as bool? ?? true,
      productFamilyId: json['product_family_id'] as String?,
      familyName: json['family_name'] as String?,
      optionLabel: json['option_label'] as String?,
      optionCount: (json['option_count'] as num?)?.toInt() ?? 1,
      optionSortOrder: (json['option_sort_order'] as num?)?.toInt() ?? 0,
      isDefaultOption: json['is_default_option'] as bool? ?? false,
      foodType: json['food_type'] as String? ?? 'NONE',
      originTag: json['origin_tag'] as String? ?? 'NONE',
      customBadges: json['custom_badges'] == null
          ? const <String>[]
          : _badgesFromJson(json['custom_badges']),
      displayDeliveryMinutes:
          (json['display_delivery_minutes'] as num?)?.toInt(),
      shopProductId: json['shop_product_id'] as String?,
      shopId: json['shop_id'] as String?,
      bulkMinQuantity: (json['bulk_min_quantity'] as num?)?.toInt(),
      bulkMaxQuantity: (json['bulk_max_quantity'] as num?)?.toInt(),
      bulkOrderEligible: json['bulk_order_eligible'] as bool?,
      isSponsored: json['is_sponsored'] as bool? ?? false,
      adToken: json['ad_token'] as String?,
    );

Map<String, dynamic> _$ProductModelToJson(_ProductModel instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'slug': instance.slug,
      'price': instance.price,
      'stock_quantity': instance.stockQuantity,
      'unit': instance.unit,
      'sale_price': instance.salePrice,
      'category_id': instance.categoryId,
      'category_name': instance.categoryName,
      'images': instance.images,
      'thumbnail_url': instance.thumbnailUrl,
      'tags': instance.tags,
      'is_featured': instance.isFeatured,
      'is_active': instance.isActive,
      'total_sold': instance.totalSold,
      'description': instance.description,
      'ingredients': instance.ingredients,
      'nutrition_info': instance.nutritionInfo,
      'storage_instructions': instance.storageInstructions,
      'brand': instance.brand,
      'brand_logo_url': instance.brandLogoUrl,
      'net_quantity': instance.netQuantity,
      'highlights': instance.highlights,
      'attributes': instance.attributes,
      'vendor_name': instance.vendorName,
      'sold_by': instance.soldBy,
      'created_at': instance.createdAt,
      'vendor_address': instance.vendorAddress,
      'vendor_fssai': instance.vendorFssai,
      'return_policy': instance.returnPolicy,
      'avg_rating': instance.avgRating,
      'rating_count': instance.ratingCount,
      'is_authentic': instance.isAuthentic,
      'product_family_id': instance.productFamilyId,
      'family_name': instance.familyName,
      'option_label': instance.optionLabel,
      'option_count': instance.optionCount,
      'option_sort_order': instance.optionSortOrder,
      'is_default_option': instance.isDefaultOption,
      'food_type': instance.foodType,
      'origin_tag': instance.originTag,
      'custom_badges': instance.customBadges,
      'display_delivery_minutes': instance.displayDeliveryMinutes,
      'shop_product_id': instance.shopProductId,
      'shop_id': instance.shopId,
      'bulk_min_quantity': instance.bulkMinQuantity,
      'bulk_max_quantity': instance.bulkMaxQuantity,
      'bulk_order_eligible': instance.bulkOrderEligible,
      'is_sponsored': instance.isSponsored,
      'ad_token': instance.adToken,
    };
