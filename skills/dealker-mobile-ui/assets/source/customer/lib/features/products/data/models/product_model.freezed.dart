// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProductModel {
  String get id;
  String get name;
  String get slug;
  @JsonKey(fromJson: _productPriceFromJson)
  double get price;
  @JsonKey(name: 'stock_quantity')
  int get stockQuantity;
  String get unit;
  @JsonKey(name: 'sale_price', fromJson: _productSalePriceFromJson)
  double? get salePrice;
  @JsonKey(name: 'category_id')
  String? get categoryId;
  @JsonKey(name: 'category_name')
  String? get categoryName;
  List<String> get images;
  @JsonKey(name: 'thumbnail_url')
  String? get thumbnailUrl;
  List<String> get tags;
  @JsonKey(name: 'is_featured')
  bool get isFeatured;
  @JsonKey(name: 'is_active')
  bool get isActive;
  @JsonKey(name: 'total_sold')
  int get totalSold;
  String? get description;
  String? get ingredients;
  @JsonKey(name: 'nutrition_info', fromJson: _productMapFromJson)
  Map<String, dynamic>? get nutritionInfo;
  @JsonKey(name: 'storage_instructions')
  String? get storageInstructions;
  @JsonKey(name: 'brand')
  String? get brand;
  @JsonKey(name: 'brand_logo_url')
  String? get brandLogoUrl;
  @JsonKey(name: 'net_quantity')
  String? get netQuantity;
  @JsonKey(fromJson: _productMapFromJson)
  Map<String, dynamic>? get highlights;
  List<dynamic>? get attributes;
  @JsonKey(name: 'vendor_name')
  String? get vendorName;
  @JsonKey(name: 'sold_by')
  String? get soldBy;
  @JsonKey(name: 'created_at')
  String? get createdAt;
  @JsonKey(name: 'vendor_address')
  String? get vendorAddress;
  @JsonKey(name: 'vendor_fssai')
  String? get vendorFssai;
  @JsonKey(name: 'return_policy')
  String get returnPolicy;
  @JsonKey(name: 'avg_rating', fromJson: _productPriceFromJson)
  double get avgRating;
  @JsonKey(name: 'rating_count')
  int get ratingCount;
  @JsonKey(name: 'is_authentic')
  bool get isAuthentic; // Phase 1/3: product family / option fields
  @JsonKey(name: 'product_family_id')
  String? get productFamilyId;
  @JsonKey(name: 'family_name')
  String? get familyName;
  @JsonKey(name: 'option_label')
  String? get optionLabel;
  @JsonKey(name: 'option_count')
  int get optionCount;
  @JsonKey(name: 'option_sort_order')
  int get optionSortOrder;
  @JsonKey(name: 'is_default_option')
  bool get isDefaultOption;
  @JsonKey(name: 'food_type')
  String get foodType;
  @JsonKey(name: 'origin_tag')
  String get originTag;
  @JsonKey(name: 'custom_badges', fromJson: _badgesFromJson)
  List<String> get customBadges;
  @JsonKey(name: 'display_delivery_minutes')
  int? get displayDeliveryMinutes;
  @JsonKey(name: 'shop_product_id')
  String? get shopProductId;
  @JsonKey(name: 'shop_id')
  String? get shopId;
  @JsonKey(name: 'bulk_min_quantity')
  int? get bulkMinQuantity;
  @JsonKey(name: 'bulk_max_quantity')
  int? get bulkMaxQuantity;
  @JsonKey(name: 'bulk_order_eligible')
  bool?
      get bulkOrderEligible; // Sponsored placement (an approved vendor campaign shown first in a section).
  @JsonKey(name: 'is_sponsored')
  bool get isSponsored;
  @JsonKey(name: 'ad_token')
  String? get adToken;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProductModelCopyWith<ProductModel> get copyWith =>
      _$ProductModelCopyWithImpl<ProductModel>(
          this as ProductModel, _$identity);

  /// Serializes this ProductModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProductModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.salePrice, salePrice) ||
                other.salePrice == salePrice) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            const DeepCollectionEquality().equals(other.images, images) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            const DeepCollectionEquality().equals(other.tags, tags) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.totalSold, totalSold) ||
                other.totalSold == totalSold) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.ingredients, ingredients) ||
                other.ingredients == ingredients) &&
            const DeepCollectionEquality()
                .equals(other.nutritionInfo, nutritionInfo) &&
            (identical(other.storageInstructions, storageInstructions) ||
                other.storageInstructions == storageInstructions) &&
            (identical(other.brand, brand) || other.brand == brand) &&
            (identical(other.brandLogoUrl, brandLogoUrl) ||
                other.brandLogoUrl == brandLogoUrl) &&
            (identical(other.netQuantity, netQuantity) ||
                other.netQuantity == netQuantity) &&
            const DeepCollectionEquality()
                .equals(other.highlights, highlights) &&
            const DeepCollectionEquality()
                .equals(other.attributes, attributes) &&
            (identical(other.vendorName, vendorName) ||
                other.vendorName == vendorName) &&
            (identical(other.soldBy, soldBy) || other.soldBy == soldBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.vendorAddress, vendorAddress) ||
                other.vendorAddress == vendorAddress) &&
            (identical(other.vendorFssai, vendorFssai) ||
                other.vendorFssai == vendorFssai) &&
            (identical(other.returnPolicy, returnPolicy) ||
                other.returnPolicy == returnPolicy) &&
            (identical(other.avgRating, avgRating) ||
                other.avgRating == avgRating) &&
            (identical(other.ratingCount, ratingCount) ||
                other.ratingCount == ratingCount) &&
            (identical(other.isAuthentic, isAuthentic) ||
                other.isAuthentic == isAuthentic) &&
            (identical(other.productFamilyId, productFamilyId) ||
                other.productFamilyId == productFamilyId) &&
            (identical(other.familyName, familyName) ||
                other.familyName == familyName) &&
            (identical(other.optionLabel, optionLabel) ||
                other.optionLabel == optionLabel) &&
            (identical(other.optionCount, optionCount) ||
                other.optionCount == optionCount) &&
            (identical(other.optionSortOrder, optionSortOrder) ||
                other.optionSortOrder == optionSortOrder) &&
            (identical(other.isDefaultOption, isDefaultOption) ||
                other.isDefaultOption == isDefaultOption) &&
            (identical(other.foodType, foodType) ||
                other.foodType == foodType) &&
            (identical(other.originTag, originTag) ||
                other.originTag == originTag) &&
            const DeepCollectionEquality()
                .equals(other.customBadges, customBadges) &&
            (identical(other.displayDeliveryMinutes, displayDeliveryMinutes) ||
                other.displayDeliveryMinutes == displayDeliveryMinutes) &&
            (identical(other.shopProductId, shopProductId) ||
                other.shopProductId == shopProductId) &&
            (identical(other.shopId, shopId) || other.shopId == shopId) &&
            (identical(other.bulkMinQuantity, bulkMinQuantity) ||
                other.bulkMinQuantity == bulkMinQuantity) &&
            (identical(other.bulkMaxQuantity, bulkMaxQuantity) ||
                other.bulkMaxQuantity == bulkMaxQuantity) &&
            (identical(other.bulkOrderEligible, bulkOrderEligible) ||
                other.bulkOrderEligible == bulkOrderEligible) &&
            (identical(other.isSponsored, isSponsored) ||
                other.isSponsored == isSponsored) &&
            (identical(other.adToken, adToken) || other.adToken == adToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        slug,
        price,
        stockQuantity,
        unit,
        salePrice,
        categoryId,
        categoryName,
        const DeepCollectionEquality().hash(images),
        thumbnailUrl,
        const DeepCollectionEquality().hash(tags),
        isFeatured,
        isActive,
        totalSold,
        description,
        ingredients,
        const DeepCollectionEquality().hash(nutritionInfo),
        storageInstructions,
        brand,
        brandLogoUrl,
        netQuantity,
        const DeepCollectionEquality().hash(highlights),
        const DeepCollectionEquality().hash(attributes),
        vendorName,
        soldBy,
        createdAt,
        vendorAddress,
        vendorFssai,
        returnPolicy,
        avgRating,
        ratingCount,
        isAuthentic,
        productFamilyId,
        familyName,
        optionLabel,
        optionCount,
        optionSortOrder,
        isDefaultOption,
        foodType,
        originTag,
        const DeepCollectionEquality().hash(customBadges),
        displayDeliveryMinutes,
        shopProductId,
        shopId,
        bulkMinQuantity,
        bulkMaxQuantity,
        bulkOrderEligible,
        isSponsored,
        adToken
      ]);

  @override
  String toString() {
    return 'ProductModel(id: $id, name: $name, slug: $slug, price: $price, stockQuantity: $stockQuantity, unit: $unit, salePrice: $salePrice, categoryId: $categoryId, categoryName: $categoryName, images: $images, thumbnailUrl: $thumbnailUrl, tags: $tags, isFeatured: $isFeatured, isActive: $isActive, totalSold: $totalSold, description: $description, ingredients: $ingredients, nutritionInfo: $nutritionInfo, storageInstructions: $storageInstructions, brand: $brand, brandLogoUrl: $brandLogoUrl, netQuantity: $netQuantity, highlights: $highlights, attributes: $attributes, vendorName: $vendorName, soldBy: $soldBy, createdAt: $createdAt, vendorAddress: $vendorAddress, vendorFssai: $vendorFssai, returnPolicy: $returnPolicy, avgRating: $avgRating, ratingCount: $ratingCount, isAuthentic: $isAuthentic, productFamilyId: $productFamilyId, familyName: $familyName, optionLabel: $optionLabel, optionCount: $optionCount, optionSortOrder: $optionSortOrder, isDefaultOption: $isDefaultOption, foodType: $foodType, originTag: $originTag, customBadges: $customBadges, displayDeliveryMinutes: $displayDeliveryMinutes, shopProductId: $shopProductId, shopId: $shopId, bulkMinQuantity: $bulkMinQuantity, bulkMaxQuantity: $bulkMaxQuantity, bulkOrderEligible: $bulkOrderEligible, isSponsored: $isSponsored, adToken: $adToken)';
  }
}

/// @nodoc
abstract mixin class $ProductModelCopyWith<$Res> {
  factory $ProductModelCopyWith(
          ProductModel value, $Res Function(ProductModel) _then) =
      _$ProductModelCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String slug,
      @JsonKey(fromJson: _productPriceFromJson) double price,
      @JsonKey(name: 'stock_quantity') int stockQuantity,
      String unit,
      @JsonKey(name: 'sale_price', fromJson: _productSalePriceFromJson)
      double? salePrice,
      @JsonKey(name: 'category_id') String? categoryId,
      @JsonKey(name: 'category_name') String? categoryName,
      List<String> images,
      @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
      List<String> tags,
      @JsonKey(name: 'is_featured') bool isFeatured,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'total_sold') int totalSold,
      String? description,
      String? ingredients,
      @JsonKey(name: 'nutrition_info', fromJson: _productMapFromJson)
      Map<String, dynamic>? nutritionInfo,
      @JsonKey(name: 'storage_instructions') String? storageInstructions,
      @JsonKey(name: 'brand') String? brand,
      @JsonKey(name: 'brand_logo_url') String? brandLogoUrl,
      @JsonKey(name: 'net_quantity') String? netQuantity,
      @JsonKey(fromJson: _productMapFromJson) Map<String, dynamic>? highlights,
      List<dynamic>? attributes,
      @JsonKey(name: 'vendor_name') String? vendorName,
      @JsonKey(name: 'sold_by') String? soldBy,
      @JsonKey(name: 'created_at') String? createdAt,
      @JsonKey(name: 'vendor_address') String? vendorAddress,
      @JsonKey(name: 'vendor_fssai') String? vendorFssai,
      @JsonKey(name: 'return_policy') String returnPolicy,
      @JsonKey(name: 'avg_rating', fromJson: _productPriceFromJson)
      double avgRating,
      @JsonKey(name: 'rating_count') int ratingCount,
      @JsonKey(name: 'is_authentic') bool isAuthentic,
      @JsonKey(name: 'product_family_id') String? productFamilyId,
      @JsonKey(name: 'family_name') String? familyName,
      @JsonKey(name: 'option_label') String? optionLabel,
      @JsonKey(name: 'option_count') int optionCount,
      @JsonKey(name: 'option_sort_order') int optionSortOrder,
      @JsonKey(name: 'is_default_option') bool isDefaultOption,
      @JsonKey(name: 'food_type') String foodType,
      @JsonKey(name: 'origin_tag') String originTag,
      @JsonKey(name: 'custom_badges', fromJson: _badgesFromJson)
      List<String> customBadges,
      @JsonKey(name: 'display_delivery_minutes') int? displayDeliveryMinutes,
      @JsonKey(name: 'shop_product_id') String? shopProductId,
      @JsonKey(name: 'shop_id') String? shopId,
      @JsonKey(name: 'bulk_min_quantity') int? bulkMinQuantity,
      @JsonKey(name: 'bulk_max_quantity') int? bulkMaxQuantity,
      @JsonKey(name: 'bulk_order_eligible') bool? bulkOrderEligible,
      @JsonKey(name: 'is_sponsored') bool isSponsored,
      @JsonKey(name: 'ad_token') String? adToken});
}

/// @nodoc
class _$ProductModelCopyWithImpl<$Res> implements $ProductModelCopyWith<$Res> {
  _$ProductModelCopyWithImpl(this._self, this._then);

  final ProductModel _self;
  final $Res Function(ProductModel) _then;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? slug = null,
    Object? price = null,
    Object? stockQuantity = null,
    Object? unit = null,
    Object? salePrice = freezed,
    Object? categoryId = freezed,
    Object? categoryName = freezed,
    Object? images = null,
    Object? thumbnailUrl = freezed,
    Object? tags = null,
    Object? isFeatured = null,
    Object? isActive = null,
    Object? totalSold = null,
    Object? description = freezed,
    Object? ingredients = freezed,
    Object? nutritionInfo = freezed,
    Object? storageInstructions = freezed,
    Object? brand = freezed,
    Object? brandLogoUrl = freezed,
    Object? netQuantity = freezed,
    Object? highlights = freezed,
    Object? attributes = freezed,
    Object? vendorName = freezed,
    Object? soldBy = freezed,
    Object? createdAt = freezed,
    Object? vendorAddress = freezed,
    Object? vendorFssai = freezed,
    Object? returnPolicy = null,
    Object? avgRating = null,
    Object? ratingCount = null,
    Object? isAuthentic = null,
    Object? productFamilyId = freezed,
    Object? familyName = freezed,
    Object? optionLabel = freezed,
    Object? optionCount = null,
    Object? optionSortOrder = null,
    Object? isDefaultOption = null,
    Object? foodType = null,
    Object? originTag = null,
    Object? customBadges = null,
    Object? displayDeliveryMinutes = freezed,
    Object? shopProductId = freezed,
    Object? shopId = freezed,
    Object? bulkMinQuantity = freezed,
    Object? bulkMaxQuantity = freezed,
    Object? bulkOrderEligible = freezed,
    Object? isSponsored = null,
    Object? adToken = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      stockQuantity: null == stockQuantity
          ? _self.stockQuantity
          : stockQuantity // ignore: cast_nullable_to_non_nullable
              as int,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      salePrice: freezed == salePrice
          ? _self.salePrice
          : salePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryName: freezed == categoryName
          ? _self.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      images: null == images
          ? _self.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<String>,
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _self.tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isFeatured: null == isFeatured
          ? _self.isFeatured
          : isFeatured // ignore: cast_nullable_to_non_nullable
              as bool,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      totalSold: null == totalSold
          ? _self.totalSold
          : totalSold // ignore: cast_nullable_to_non_nullable
              as int,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      ingredients: freezed == ingredients
          ? _self.ingredients
          : ingredients // ignore: cast_nullable_to_non_nullable
              as String?,
      nutritionInfo: freezed == nutritionInfo
          ? _self.nutritionInfo
          : nutritionInfo // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      storageInstructions: freezed == storageInstructions
          ? _self.storageInstructions
          : storageInstructions // ignore: cast_nullable_to_non_nullable
              as String?,
      brand: freezed == brand
          ? _self.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String?,
      brandLogoUrl: freezed == brandLogoUrl
          ? _self.brandLogoUrl
          : brandLogoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      netQuantity: freezed == netQuantity
          ? _self.netQuantity
          : netQuantity // ignore: cast_nullable_to_non_nullable
              as String?,
      highlights: freezed == highlights
          ? _self.highlights
          : highlights // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      attributes: freezed == attributes
          ? _self.attributes
          : attributes // ignore: cast_nullable_to_non_nullable
              as List<dynamic>?,
      vendorName: freezed == vendorName
          ? _self.vendorName
          : vendorName // ignore: cast_nullable_to_non_nullable
              as String?,
      soldBy: freezed == soldBy
          ? _self.soldBy
          : soldBy // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
      vendorAddress: freezed == vendorAddress
          ? _self.vendorAddress
          : vendorAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      vendorFssai: freezed == vendorFssai
          ? _self.vendorFssai
          : vendorFssai // ignore: cast_nullable_to_non_nullable
              as String?,
      returnPolicy: null == returnPolicy
          ? _self.returnPolicy
          : returnPolicy // ignore: cast_nullable_to_non_nullable
              as String,
      avgRating: null == avgRating
          ? _self.avgRating
          : avgRating // ignore: cast_nullable_to_non_nullable
              as double,
      ratingCount: null == ratingCount
          ? _self.ratingCount
          : ratingCount // ignore: cast_nullable_to_non_nullable
              as int,
      isAuthentic: null == isAuthentic
          ? _self.isAuthentic
          : isAuthentic // ignore: cast_nullable_to_non_nullable
              as bool,
      productFamilyId: freezed == productFamilyId
          ? _self.productFamilyId
          : productFamilyId // ignore: cast_nullable_to_non_nullable
              as String?,
      familyName: freezed == familyName
          ? _self.familyName
          : familyName // ignore: cast_nullable_to_non_nullable
              as String?,
      optionLabel: freezed == optionLabel
          ? _self.optionLabel
          : optionLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      optionCount: null == optionCount
          ? _self.optionCount
          : optionCount // ignore: cast_nullable_to_non_nullable
              as int,
      optionSortOrder: null == optionSortOrder
          ? _self.optionSortOrder
          : optionSortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      isDefaultOption: null == isDefaultOption
          ? _self.isDefaultOption
          : isDefaultOption // ignore: cast_nullable_to_non_nullable
              as bool,
      foodType: null == foodType
          ? _self.foodType
          : foodType // ignore: cast_nullable_to_non_nullable
              as String,
      originTag: null == originTag
          ? _self.originTag
          : originTag // ignore: cast_nullable_to_non_nullable
              as String,
      customBadges: null == customBadges
          ? _self.customBadges
          : customBadges // ignore: cast_nullable_to_non_nullable
              as List<String>,
      displayDeliveryMinutes: freezed == displayDeliveryMinutes
          ? _self.displayDeliveryMinutes
          : displayDeliveryMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      shopProductId: freezed == shopProductId
          ? _self.shopProductId
          : shopProductId // ignore: cast_nullable_to_non_nullable
              as String?,
      shopId: freezed == shopId
          ? _self.shopId
          : shopId // ignore: cast_nullable_to_non_nullable
              as String?,
      bulkMinQuantity: freezed == bulkMinQuantity
          ? _self.bulkMinQuantity
          : bulkMinQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
      bulkMaxQuantity: freezed == bulkMaxQuantity
          ? _self.bulkMaxQuantity
          : bulkMaxQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
      bulkOrderEligible: freezed == bulkOrderEligible
          ? _self.bulkOrderEligible
          : bulkOrderEligible // ignore: cast_nullable_to_non_nullable
              as bool?,
      isSponsored: null == isSponsored
          ? _self.isSponsored
          : isSponsored // ignore: cast_nullable_to_non_nullable
              as bool,
      adToken: freezed == adToken
          ? _self.adToken
          : adToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ProductModel].
extension ProductModelPatterns on ProductModel {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_ProductModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProductModel() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_ProductModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProductModel():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_ProductModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProductModel() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            String id,
            String name,
            String slug,
            @JsonKey(fromJson: _productPriceFromJson) double price,
            @JsonKey(name: 'stock_quantity') int stockQuantity,
            String unit,
            @JsonKey(name: 'sale_price', fromJson: _productSalePriceFromJson)
            double? salePrice,
            @JsonKey(name: 'category_id') String? categoryId,
            @JsonKey(name: 'category_name') String? categoryName,
            List<String> images,
            @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
            List<String> tags,
            @JsonKey(name: 'is_featured') bool isFeatured,
            @JsonKey(name: 'is_active') bool isActive,
            @JsonKey(name: 'total_sold') int totalSold,
            String? description,
            String? ingredients,
            @JsonKey(name: 'nutrition_info', fromJson: _productMapFromJson)
            Map<String, dynamic>? nutritionInfo,
            @JsonKey(name: 'storage_instructions') String? storageInstructions,
            @JsonKey(name: 'brand') String? brand,
            @JsonKey(name: 'brand_logo_url') String? brandLogoUrl,
            @JsonKey(name: 'net_quantity') String? netQuantity,
            @JsonKey(fromJson: _productMapFromJson)
            Map<String, dynamic>? highlights,
            List<dynamic>? attributes,
            @JsonKey(name: 'vendor_name') String? vendorName,
            @JsonKey(name: 'sold_by') String? soldBy,
            @JsonKey(name: 'created_at') String? createdAt,
            @JsonKey(name: 'vendor_address') String? vendorAddress,
            @JsonKey(name: 'vendor_fssai') String? vendorFssai,
            @JsonKey(name: 'return_policy') String returnPolicy,
            @JsonKey(name: 'avg_rating', fromJson: _productPriceFromJson)
            double avgRating,
            @JsonKey(name: 'rating_count') int ratingCount,
            @JsonKey(name: 'is_authentic') bool isAuthentic,
            @JsonKey(name: 'product_family_id') String? productFamilyId,
            @JsonKey(name: 'family_name') String? familyName,
            @JsonKey(name: 'option_label') String? optionLabel,
            @JsonKey(name: 'option_count') int optionCount,
            @JsonKey(name: 'option_sort_order') int optionSortOrder,
            @JsonKey(name: 'is_default_option') bool isDefaultOption,
            @JsonKey(name: 'food_type') String foodType,
            @JsonKey(name: 'origin_tag') String originTag,
            @JsonKey(name: 'custom_badges', fromJson: _badgesFromJson)
            List<String> customBadges,
            @JsonKey(name: 'display_delivery_minutes')
            int? displayDeliveryMinutes,
            @JsonKey(name: 'shop_product_id') String? shopProductId,
            @JsonKey(name: 'shop_id') String? shopId,
            @JsonKey(name: 'bulk_min_quantity') int? bulkMinQuantity,
            @JsonKey(name: 'bulk_max_quantity') int? bulkMaxQuantity,
            @JsonKey(name: 'bulk_order_eligible') bool? bulkOrderEligible,
            @JsonKey(name: 'is_sponsored') bool isSponsored,
            @JsonKey(name: 'ad_token') String? adToken)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProductModel() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.slug,
            _that.price,
            _that.stockQuantity,
            _that.unit,
            _that.salePrice,
            _that.categoryId,
            _that.categoryName,
            _that.images,
            _that.thumbnailUrl,
            _that.tags,
            _that.isFeatured,
            _that.isActive,
            _that.totalSold,
            _that.description,
            _that.ingredients,
            _that.nutritionInfo,
            _that.storageInstructions,
            _that.brand,
            _that.brandLogoUrl,
            _that.netQuantity,
            _that.highlights,
            _that.attributes,
            _that.vendorName,
            _that.soldBy,
            _that.createdAt,
            _that.vendorAddress,
            _that.vendorFssai,
            _that.returnPolicy,
            _that.avgRating,
            _that.ratingCount,
            _that.isAuthentic,
            _that.productFamilyId,
            _that.familyName,
            _that.optionLabel,
            _that.optionCount,
            _that.optionSortOrder,
            _that.isDefaultOption,
            _that.foodType,
            _that.originTag,
            _that.customBadges,
            _that.displayDeliveryMinutes,
            _that.shopProductId,
            _that.shopId,
            _that.bulkMinQuantity,
            _that.bulkMaxQuantity,
            _that.bulkOrderEligible,
            _that.isSponsored,
            _that.adToken);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            String id,
            String name,
            String slug,
            @JsonKey(fromJson: _productPriceFromJson) double price,
            @JsonKey(name: 'stock_quantity') int stockQuantity,
            String unit,
            @JsonKey(name: 'sale_price', fromJson: _productSalePriceFromJson)
            double? salePrice,
            @JsonKey(name: 'category_id') String? categoryId,
            @JsonKey(name: 'category_name') String? categoryName,
            List<String> images,
            @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
            List<String> tags,
            @JsonKey(name: 'is_featured') bool isFeatured,
            @JsonKey(name: 'is_active') bool isActive,
            @JsonKey(name: 'total_sold') int totalSold,
            String? description,
            String? ingredients,
            @JsonKey(name: 'nutrition_info', fromJson: _productMapFromJson)
            Map<String, dynamic>? nutritionInfo,
            @JsonKey(name: 'storage_instructions') String? storageInstructions,
            @JsonKey(name: 'brand') String? brand,
            @JsonKey(name: 'brand_logo_url') String? brandLogoUrl,
            @JsonKey(name: 'net_quantity') String? netQuantity,
            @JsonKey(fromJson: _productMapFromJson)
            Map<String, dynamic>? highlights,
            List<dynamic>? attributes,
            @JsonKey(name: 'vendor_name') String? vendorName,
            @JsonKey(name: 'sold_by') String? soldBy,
            @JsonKey(name: 'created_at') String? createdAt,
            @JsonKey(name: 'vendor_address') String? vendorAddress,
            @JsonKey(name: 'vendor_fssai') String? vendorFssai,
            @JsonKey(name: 'return_policy') String returnPolicy,
            @JsonKey(name: 'avg_rating', fromJson: _productPriceFromJson)
            double avgRating,
            @JsonKey(name: 'rating_count') int ratingCount,
            @JsonKey(name: 'is_authentic') bool isAuthentic,
            @JsonKey(name: 'product_family_id') String? productFamilyId,
            @JsonKey(name: 'family_name') String? familyName,
            @JsonKey(name: 'option_label') String? optionLabel,
            @JsonKey(name: 'option_count') int optionCount,
            @JsonKey(name: 'option_sort_order') int optionSortOrder,
            @JsonKey(name: 'is_default_option') bool isDefaultOption,
            @JsonKey(name: 'food_type') String foodType,
            @JsonKey(name: 'origin_tag') String originTag,
            @JsonKey(name: 'custom_badges', fromJson: _badgesFromJson)
            List<String> customBadges,
            @JsonKey(name: 'display_delivery_minutes')
            int? displayDeliveryMinutes,
            @JsonKey(name: 'shop_product_id') String? shopProductId,
            @JsonKey(name: 'shop_id') String? shopId,
            @JsonKey(name: 'bulk_min_quantity') int? bulkMinQuantity,
            @JsonKey(name: 'bulk_max_quantity') int? bulkMaxQuantity,
            @JsonKey(name: 'bulk_order_eligible') bool? bulkOrderEligible,
            @JsonKey(name: 'is_sponsored') bool isSponsored,
            @JsonKey(name: 'ad_token') String? adToken)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProductModel():
        return $default(
            _that.id,
            _that.name,
            _that.slug,
            _that.price,
            _that.stockQuantity,
            _that.unit,
            _that.salePrice,
            _that.categoryId,
            _that.categoryName,
            _that.images,
            _that.thumbnailUrl,
            _that.tags,
            _that.isFeatured,
            _that.isActive,
            _that.totalSold,
            _that.description,
            _that.ingredients,
            _that.nutritionInfo,
            _that.storageInstructions,
            _that.brand,
            _that.brandLogoUrl,
            _that.netQuantity,
            _that.highlights,
            _that.attributes,
            _that.vendorName,
            _that.soldBy,
            _that.createdAt,
            _that.vendorAddress,
            _that.vendorFssai,
            _that.returnPolicy,
            _that.avgRating,
            _that.ratingCount,
            _that.isAuthentic,
            _that.productFamilyId,
            _that.familyName,
            _that.optionLabel,
            _that.optionCount,
            _that.optionSortOrder,
            _that.isDefaultOption,
            _that.foodType,
            _that.originTag,
            _that.customBadges,
            _that.displayDeliveryMinutes,
            _that.shopProductId,
            _that.shopId,
            _that.bulkMinQuantity,
            _that.bulkMaxQuantity,
            _that.bulkOrderEligible,
            _that.isSponsored,
            _that.adToken);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            String id,
            String name,
            String slug,
            @JsonKey(fromJson: _productPriceFromJson) double price,
            @JsonKey(name: 'stock_quantity') int stockQuantity,
            String unit,
            @JsonKey(name: 'sale_price', fromJson: _productSalePriceFromJson)
            double? salePrice,
            @JsonKey(name: 'category_id') String? categoryId,
            @JsonKey(name: 'category_name') String? categoryName,
            List<String> images,
            @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
            List<String> tags,
            @JsonKey(name: 'is_featured') bool isFeatured,
            @JsonKey(name: 'is_active') bool isActive,
            @JsonKey(name: 'total_sold') int totalSold,
            String? description,
            String? ingredients,
            @JsonKey(name: 'nutrition_info', fromJson: _productMapFromJson)
            Map<String, dynamic>? nutritionInfo,
            @JsonKey(name: 'storage_instructions') String? storageInstructions,
            @JsonKey(name: 'brand') String? brand,
            @JsonKey(name: 'brand_logo_url') String? brandLogoUrl,
            @JsonKey(name: 'net_quantity') String? netQuantity,
            @JsonKey(fromJson: _productMapFromJson)
            Map<String, dynamic>? highlights,
            List<dynamic>? attributes,
            @JsonKey(name: 'vendor_name') String? vendorName,
            @JsonKey(name: 'sold_by') String? soldBy,
            @JsonKey(name: 'created_at') String? createdAt,
            @JsonKey(name: 'vendor_address') String? vendorAddress,
            @JsonKey(name: 'vendor_fssai') String? vendorFssai,
            @JsonKey(name: 'return_policy') String returnPolicy,
            @JsonKey(name: 'avg_rating', fromJson: _productPriceFromJson)
            double avgRating,
            @JsonKey(name: 'rating_count') int ratingCount,
            @JsonKey(name: 'is_authentic') bool isAuthentic,
            @JsonKey(name: 'product_family_id') String? productFamilyId,
            @JsonKey(name: 'family_name') String? familyName,
            @JsonKey(name: 'option_label') String? optionLabel,
            @JsonKey(name: 'option_count') int optionCount,
            @JsonKey(name: 'option_sort_order') int optionSortOrder,
            @JsonKey(name: 'is_default_option') bool isDefaultOption,
            @JsonKey(name: 'food_type') String foodType,
            @JsonKey(name: 'origin_tag') String originTag,
            @JsonKey(name: 'custom_badges', fromJson: _badgesFromJson)
            List<String> customBadges,
            @JsonKey(name: 'display_delivery_minutes')
            int? displayDeliveryMinutes,
            @JsonKey(name: 'shop_product_id') String? shopProductId,
            @JsonKey(name: 'shop_id') String? shopId,
            @JsonKey(name: 'bulk_min_quantity') int? bulkMinQuantity,
            @JsonKey(name: 'bulk_max_quantity') int? bulkMaxQuantity,
            @JsonKey(name: 'bulk_order_eligible') bool? bulkOrderEligible,
            @JsonKey(name: 'is_sponsored') bool isSponsored,
            @JsonKey(name: 'ad_token') String? adToken)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProductModel() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.slug,
            _that.price,
            _that.stockQuantity,
            _that.unit,
            _that.salePrice,
            _that.categoryId,
            _that.categoryName,
            _that.images,
            _that.thumbnailUrl,
            _that.tags,
            _that.isFeatured,
            _that.isActive,
            _that.totalSold,
            _that.description,
            _that.ingredients,
            _that.nutritionInfo,
            _that.storageInstructions,
            _that.brand,
            _that.brandLogoUrl,
            _that.netQuantity,
            _that.highlights,
            _that.attributes,
            _that.vendorName,
            _that.soldBy,
            _that.createdAt,
            _that.vendorAddress,
            _that.vendorFssai,
            _that.returnPolicy,
            _that.avgRating,
            _that.ratingCount,
            _that.isAuthentic,
            _that.productFamilyId,
            _that.familyName,
            _that.optionLabel,
            _that.optionCount,
            _that.optionSortOrder,
            _that.isDefaultOption,
            _that.foodType,
            _that.originTag,
            _that.customBadges,
            _that.displayDeliveryMinutes,
            _that.shopProductId,
            _that.shopId,
            _that.bulkMinQuantity,
            _that.bulkMaxQuantity,
            _that.bulkOrderEligible,
            _that.isSponsored,
            _that.adToken);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ProductModel extends ProductModel {
  const _ProductModel(
      {required this.id,
      required this.name,
      required this.slug,
      @JsonKey(fromJson: _productPriceFromJson) required this.price,
      @JsonKey(name: 'stock_quantity') required this.stockQuantity,
      required this.unit,
      @JsonKey(name: 'sale_price', fromJson: _productSalePriceFromJson)
      this.salePrice,
      @JsonKey(name: 'category_id') this.categoryId,
      @JsonKey(name: 'category_name') this.categoryName,
      final List<String> images = const <String>[],
      @JsonKey(name: 'thumbnail_url') this.thumbnailUrl,
      final List<String> tags = const <String>[],
      @JsonKey(name: 'is_featured') this.isFeatured = false,
      @JsonKey(name: 'is_active') this.isActive = true,
      @JsonKey(name: 'total_sold') this.totalSold = 0,
      this.description,
      this.ingredients,
      @JsonKey(name: 'nutrition_info', fromJson: _productMapFromJson)
      final Map<String, dynamic>? nutritionInfo,
      @JsonKey(name: 'storage_instructions') this.storageInstructions,
      @JsonKey(name: 'brand') this.brand,
      @JsonKey(name: 'brand_logo_url') this.brandLogoUrl,
      @JsonKey(name: 'net_quantity') this.netQuantity,
      @JsonKey(fromJson: _productMapFromJson)
      final Map<String, dynamic>? highlights,
      final List<dynamic>? attributes,
      @JsonKey(name: 'vendor_name') this.vendorName,
      @JsonKey(name: 'sold_by') this.soldBy,
      @JsonKey(name: 'created_at') this.createdAt,
      @JsonKey(name: 'vendor_address') this.vendorAddress,
      @JsonKey(name: 'vendor_fssai') this.vendorFssai,
      @JsonKey(name: 'return_policy') this.returnPolicy = 'no_return',
      @JsonKey(name: 'avg_rating', fromJson: _productPriceFromJson)
      this.avgRating = 0.0,
      @JsonKey(name: 'rating_count') this.ratingCount = 0,
      @JsonKey(name: 'is_authentic') this.isAuthentic = true,
      @JsonKey(name: 'product_family_id') this.productFamilyId,
      @JsonKey(name: 'family_name') this.familyName,
      @JsonKey(name: 'option_label') this.optionLabel,
      @JsonKey(name: 'option_count') this.optionCount = 1,
      @JsonKey(name: 'option_sort_order') this.optionSortOrder = 0,
      @JsonKey(name: 'is_default_option') this.isDefaultOption = false,
      @JsonKey(name: 'food_type') this.foodType = 'NONE',
      @JsonKey(name: 'origin_tag') this.originTag = 'NONE',
      @JsonKey(name: 'custom_badges', fromJson: _badgesFromJson)
      final List<String> customBadges = const <String>[],
      @JsonKey(name: 'display_delivery_minutes') this.displayDeliveryMinutes,
      @JsonKey(name: 'shop_product_id') this.shopProductId,
      @JsonKey(name: 'shop_id') this.shopId,
      @JsonKey(name: 'bulk_min_quantity') this.bulkMinQuantity,
      @JsonKey(name: 'bulk_max_quantity') this.bulkMaxQuantity,
      @JsonKey(name: 'bulk_order_eligible') this.bulkOrderEligible,
      @JsonKey(name: 'is_sponsored') this.isSponsored = false,
      @JsonKey(name: 'ad_token') this.adToken})
      : _images = images,
        _tags = tags,
        _nutritionInfo = nutritionInfo,
        _highlights = highlights,
        _attributes = attributes,
        _customBadges = customBadges,
        super._();
  factory _ProductModel.fromJson(Map<String, dynamic> json) =>
      _$ProductModelFromJson(json);

  @override
  final String id;
  @override
  final String name;
  @override
  final String slug;
  @override
  @JsonKey(fromJson: _productPriceFromJson)
  final double price;
  @override
  @JsonKey(name: 'stock_quantity')
  final int stockQuantity;
  @override
  final String unit;
  @override
  @JsonKey(name: 'sale_price', fromJson: _productSalePriceFromJson)
  final double? salePrice;
  @override
  @JsonKey(name: 'category_id')
  final String? categoryId;
  @override
  @JsonKey(name: 'category_name')
  final String? categoryName;
  final List<String> _images;
  @override
  @JsonKey()
  List<String> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  @JsonKey(name: 'thumbnail_url')
  final String? thumbnailUrl;
  final List<String> _tags;
  @override
  @JsonKey()
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  @JsonKey(name: 'is_featured')
  final bool isFeatured;
  @override
  @JsonKey(name: 'is_active')
  final bool isActive;
  @override
  @JsonKey(name: 'total_sold')
  final int totalSold;
  @override
  final String? description;
  @override
  final String? ingredients;
  final Map<String, dynamic>? _nutritionInfo;
  @override
  @JsonKey(name: 'nutrition_info', fromJson: _productMapFromJson)
  Map<String, dynamic>? get nutritionInfo {
    final value = _nutritionInfo;
    if (value == null) return null;
    if (_nutritionInfo is EqualUnmodifiableMapView) return _nutritionInfo;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  @JsonKey(name: 'storage_instructions')
  final String? storageInstructions;
  @override
  @JsonKey(name: 'brand')
  final String? brand;
  @override
  @JsonKey(name: 'brand_logo_url')
  final String? brandLogoUrl;
  @override
  @JsonKey(name: 'net_quantity')
  final String? netQuantity;
  final Map<String, dynamic>? _highlights;
  @override
  @JsonKey(fromJson: _productMapFromJson)
  Map<String, dynamic>? get highlights {
    final value = _highlights;
    if (value == null) return null;
    if (_highlights is EqualUnmodifiableMapView) return _highlights;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final List<dynamic>? _attributes;
  @override
  List<dynamic>? get attributes {
    final value = _attributes;
    if (value == null) return null;
    if (_attributes is EqualUnmodifiableListView) return _attributes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  @JsonKey(name: 'vendor_name')
  final String? vendorName;
  @override
  @JsonKey(name: 'sold_by')
  final String? soldBy;
  @override
  @JsonKey(name: 'created_at')
  final String? createdAt;
  @override
  @JsonKey(name: 'vendor_address')
  final String? vendorAddress;
  @override
  @JsonKey(name: 'vendor_fssai')
  final String? vendorFssai;
  @override
  @JsonKey(name: 'return_policy')
  final String returnPolicy;
  @override
  @JsonKey(name: 'avg_rating', fromJson: _productPriceFromJson)
  final double avgRating;
  @override
  @JsonKey(name: 'rating_count')
  final int ratingCount;
  @override
  @JsonKey(name: 'is_authentic')
  final bool isAuthentic;
// Phase 1/3: product family / option fields
  @override
  @JsonKey(name: 'product_family_id')
  final String? productFamilyId;
  @override
  @JsonKey(name: 'family_name')
  final String? familyName;
  @override
  @JsonKey(name: 'option_label')
  final String? optionLabel;
  @override
  @JsonKey(name: 'option_count')
  final int optionCount;
  @override
  @JsonKey(name: 'option_sort_order')
  final int optionSortOrder;
  @override
  @JsonKey(name: 'is_default_option')
  final bool isDefaultOption;
  @override
  @JsonKey(name: 'food_type')
  final String foodType;
  @override
  @JsonKey(name: 'origin_tag')
  final String originTag;
  final List<String> _customBadges;
  @override
  @JsonKey(name: 'custom_badges', fromJson: _badgesFromJson)
  List<String> get customBadges {
    if (_customBadges is EqualUnmodifiableListView) return _customBadges;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customBadges);
  }

  @override
  @JsonKey(name: 'display_delivery_minutes')
  final int? displayDeliveryMinutes;
  @override
  @JsonKey(name: 'shop_product_id')
  final String? shopProductId;
  @override
  @JsonKey(name: 'shop_id')
  final String? shopId;
  @override
  @JsonKey(name: 'bulk_min_quantity')
  final int? bulkMinQuantity;
  @override
  @JsonKey(name: 'bulk_max_quantity')
  final int? bulkMaxQuantity;
  @override
  @JsonKey(name: 'bulk_order_eligible')
  final bool? bulkOrderEligible;
// Sponsored placement (an approved vendor campaign shown first in a section).
  @override
  @JsonKey(name: 'is_sponsored')
  final bool isSponsored;
  @override
  @JsonKey(name: 'ad_token')
  final String? adToken;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProductModelCopyWith<_ProductModel> get copyWith =>
      __$ProductModelCopyWithImpl<_ProductModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ProductModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProductModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.salePrice, salePrice) ||
                other.salePrice == salePrice) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.totalSold, totalSold) ||
                other.totalSold == totalSold) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.ingredients, ingredients) ||
                other.ingredients == ingredients) &&
            const DeepCollectionEquality()
                .equals(other._nutritionInfo, _nutritionInfo) &&
            (identical(other.storageInstructions, storageInstructions) ||
                other.storageInstructions == storageInstructions) &&
            (identical(other.brand, brand) || other.brand == brand) &&
            (identical(other.brandLogoUrl, brandLogoUrl) ||
                other.brandLogoUrl == brandLogoUrl) &&
            (identical(other.netQuantity, netQuantity) ||
                other.netQuantity == netQuantity) &&
            const DeepCollectionEquality()
                .equals(other._highlights, _highlights) &&
            const DeepCollectionEquality()
                .equals(other._attributes, _attributes) &&
            (identical(other.vendorName, vendorName) ||
                other.vendorName == vendorName) &&
            (identical(other.soldBy, soldBy) || other.soldBy == soldBy) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.vendorAddress, vendorAddress) ||
                other.vendorAddress == vendorAddress) &&
            (identical(other.vendorFssai, vendorFssai) ||
                other.vendorFssai == vendorFssai) &&
            (identical(other.returnPolicy, returnPolicy) ||
                other.returnPolicy == returnPolicy) &&
            (identical(other.avgRating, avgRating) ||
                other.avgRating == avgRating) &&
            (identical(other.ratingCount, ratingCount) ||
                other.ratingCount == ratingCount) &&
            (identical(other.isAuthentic, isAuthentic) ||
                other.isAuthentic == isAuthentic) &&
            (identical(other.productFamilyId, productFamilyId) ||
                other.productFamilyId == productFamilyId) &&
            (identical(other.familyName, familyName) ||
                other.familyName == familyName) &&
            (identical(other.optionLabel, optionLabel) ||
                other.optionLabel == optionLabel) &&
            (identical(other.optionCount, optionCount) ||
                other.optionCount == optionCount) &&
            (identical(other.optionSortOrder, optionSortOrder) ||
                other.optionSortOrder == optionSortOrder) &&
            (identical(other.isDefaultOption, isDefaultOption) ||
                other.isDefaultOption == isDefaultOption) &&
            (identical(other.foodType, foodType) ||
                other.foodType == foodType) &&
            (identical(other.originTag, originTag) ||
                other.originTag == originTag) &&
            const DeepCollectionEquality()
                .equals(other._customBadges, _customBadges) &&
            (identical(other.displayDeliveryMinutes, displayDeliveryMinutes) ||
                other.displayDeliveryMinutes == displayDeliveryMinutes) &&
            (identical(other.shopProductId, shopProductId) ||
                other.shopProductId == shopProductId) &&
            (identical(other.shopId, shopId) || other.shopId == shopId) &&
            (identical(other.bulkMinQuantity, bulkMinQuantity) ||
                other.bulkMinQuantity == bulkMinQuantity) &&
            (identical(other.bulkMaxQuantity, bulkMaxQuantity) ||
                other.bulkMaxQuantity == bulkMaxQuantity) &&
            (identical(other.bulkOrderEligible, bulkOrderEligible) ||
                other.bulkOrderEligible == bulkOrderEligible) &&
            (identical(other.isSponsored, isSponsored) ||
                other.isSponsored == isSponsored) &&
            (identical(other.adToken, adToken) || other.adToken == adToken));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        slug,
        price,
        stockQuantity,
        unit,
        salePrice,
        categoryId,
        categoryName,
        const DeepCollectionEquality().hash(_images),
        thumbnailUrl,
        const DeepCollectionEquality().hash(_tags),
        isFeatured,
        isActive,
        totalSold,
        description,
        ingredients,
        const DeepCollectionEquality().hash(_nutritionInfo),
        storageInstructions,
        brand,
        brandLogoUrl,
        netQuantity,
        const DeepCollectionEquality().hash(_highlights),
        const DeepCollectionEquality().hash(_attributes),
        vendorName,
        soldBy,
        createdAt,
        vendorAddress,
        vendorFssai,
        returnPolicy,
        avgRating,
        ratingCount,
        isAuthentic,
        productFamilyId,
        familyName,
        optionLabel,
        optionCount,
        optionSortOrder,
        isDefaultOption,
        foodType,
        originTag,
        const DeepCollectionEquality().hash(_customBadges),
        displayDeliveryMinutes,
        shopProductId,
        shopId,
        bulkMinQuantity,
        bulkMaxQuantity,
        bulkOrderEligible,
        isSponsored,
        adToken
      ]);

  @override
  String toString() {
    return 'ProductModel(id: $id, name: $name, slug: $slug, price: $price, stockQuantity: $stockQuantity, unit: $unit, salePrice: $salePrice, categoryId: $categoryId, categoryName: $categoryName, images: $images, thumbnailUrl: $thumbnailUrl, tags: $tags, isFeatured: $isFeatured, isActive: $isActive, totalSold: $totalSold, description: $description, ingredients: $ingredients, nutritionInfo: $nutritionInfo, storageInstructions: $storageInstructions, brand: $brand, brandLogoUrl: $brandLogoUrl, netQuantity: $netQuantity, highlights: $highlights, attributes: $attributes, vendorName: $vendorName, soldBy: $soldBy, createdAt: $createdAt, vendorAddress: $vendorAddress, vendorFssai: $vendorFssai, returnPolicy: $returnPolicy, avgRating: $avgRating, ratingCount: $ratingCount, isAuthentic: $isAuthentic, productFamilyId: $productFamilyId, familyName: $familyName, optionLabel: $optionLabel, optionCount: $optionCount, optionSortOrder: $optionSortOrder, isDefaultOption: $isDefaultOption, foodType: $foodType, originTag: $originTag, customBadges: $customBadges, displayDeliveryMinutes: $displayDeliveryMinutes, shopProductId: $shopProductId, shopId: $shopId, bulkMinQuantity: $bulkMinQuantity, bulkMaxQuantity: $bulkMaxQuantity, bulkOrderEligible: $bulkOrderEligible, isSponsored: $isSponsored, adToken: $adToken)';
  }
}

/// @nodoc
abstract mixin class _$ProductModelCopyWith<$Res>
    implements $ProductModelCopyWith<$Res> {
  factory _$ProductModelCopyWith(
          _ProductModel value, $Res Function(_ProductModel) _then) =
      __$ProductModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String slug,
      @JsonKey(fromJson: _productPriceFromJson) double price,
      @JsonKey(name: 'stock_quantity') int stockQuantity,
      String unit,
      @JsonKey(name: 'sale_price', fromJson: _productSalePriceFromJson)
      double? salePrice,
      @JsonKey(name: 'category_id') String? categoryId,
      @JsonKey(name: 'category_name') String? categoryName,
      List<String> images,
      @JsonKey(name: 'thumbnail_url') String? thumbnailUrl,
      List<String> tags,
      @JsonKey(name: 'is_featured') bool isFeatured,
      @JsonKey(name: 'is_active') bool isActive,
      @JsonKey(name: 'total_sold') int totalSold,
      String? description,
      String? ingredients,
      @JsonKey(name: 'nutrition_info', fromJson: _productMapFromJson)
      Map<String, dynamic>? nutritionInfo,
      @JsonKey(name: 'storage_instructions') String? storageInstructions,
      @JsonKey(name: 'brand') String? brand,
      @JsonKey(name: 'brand_logo_url') String? brandLogoUrl,
      @JsonKey(name: 'net_quantity') String? netQuantity,
      @JsonKey(fromJson: _productMapFromJson) Map<String, dynamic>? highlights,
      List<dynamic>? attributes,
      @JsonKey(name: 'vendor_name') String? vendorName,
      @JsonKey(name: 'sold_by') String? soldBy,
      @JsonKey(name: 'created_at') String? createdAt,
      @JsonKey(name: 'vendor_address') String? vendorAddress,
      @JsonKey(name: 'vendor_fssai') String? vendorFssai,
      @JsonKey(name: 'return_policy') String returnPolicy,
      @JsonKey(name: 'avg_rating', fromJson: _productPriceFromJson)
      double avgRating,
      @JsonKey(name: 'rating_count') int ratingCount,
      @JsonKey(name: 'is_authentic') bool isAuthentic,
      @JsonKey(name: 'product_family_id') String? productFamilyId,
      @JsonKey(name: 'family_name') String? familyName,
      @JsonKey(name: 'option_label') String? optionLabel,
      @JsonKey(name: 'option_count') int optionCount,
      @JsonKey(name: 'option_sort_order') int optionSortOrder,
      @JsonKey(name: 'is_default_option') bool isDefaultOption,
      @JsonKey(name: 'food_type') String foodType,
      @JsonKey(name: 'origin_tag') String originTag,
      @JsonKey(name: 'custom_badges', fromJson: _badgesFromJson)
      List<String> customBadges,
      @JsonKey(name: 'display_delivery_minutes') int? displayDeliveryMinutes,
      @JsonKey(name: 'shop_product_id') String? shopProductId,
      @JsonKey(name: 'shop_id') String? shopId,
      @JsonKey(name: 'bulk_min_quantity') int? bulkMinQuantity,
      @JsonKey(name: 'bulk_max_quantity') int? bulkMaxQuantity,
      @JsonKey(name: 'bulk_order_eligible') bool? bulkOrderEligible,
      @JsonKey(name: 'is_sponsored') bool isSponsored,
      @JsonKey(name: 'ad_token') String? adToken});
}

/// @nodoc
class __$ProductModelCopyWithImpl<$Res>
    implements _$ProductModelCopyWith<$Res> {
  __$ProductModelCopyWithImpl(this._self, this._then);

  final _ProductModel _self;
  final $Res Function(_ProductModel) _then;

  /// Create a copy of ProductModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? slug = null,
    Object? price = null,
    Object? stockQuantity = null,
    Object? unit = null,
    Object? salePrice = freezed,
    Object? categoryId = freezed,
    Object? categoryName = freezed,
    Object? images = null,
    Object? thumbnailUrl = freezed,
    Object? tags = null,
    Object? isFeatured = null,
    Object? isActive = null,
    Object? totalSold = null,
    Object? description = freezed,
    Object? ingredients = freezed,
    Object? nutritionInfo = freezed,
    Object? storageInstructions = freezed,
    Object? brand = freezed,
    Object? brandLogoUrl = freezed,
    Object? netQuantity = freezed,
    Object? highlights = freezed,
    Object? attributes = freezed,
    Object? vendorName = freezed,
    Object? soldBy = freezed,
    Object? createdAt = freezed,
    Object? vendorAddress = freezed,
    Object? vendorFssai = freezed,
    Object? returnPolicy = null,
    Object? avgRating = null,
    Object? ratingCount = null,
    Object? isAuthentic = null,
    Object? productFamilyId = freezed,
    Object? familyName = freezed,
    Object? optionLabel = freezed,
    Object? optionCount = null,
    Object? optionSortOrder = null,
    Object? isDefaultOption = null,
    Object? foodType = null,
    Object? originTag = null,
    Object? customBadges = null,
    Object? displayDeliveryMinutes = freezed,
    Object? shopProductId = freezed,
    Object? shopId = freezed,
    Object? bulkMinQuantity = freezed,
    Object? bulkMaxQuantity = freezed,
    Object? bulkOrderEligible = freezed,
    Object? isSponsored = null,
    Object? adToken = freezed,
  }) {
    return _then(_ProductModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      slug: null == slug
          ? _self.slug
          : slug // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      stockQuantity: null == stockQuantity
          ? _self.stockQuantity
          : stockQuantity // ignore: cast_nullable_to_non_nullable
              as int,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      salePrice: freezed == salePrice
          ? _self.salePrice
          : salePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      categoryName: freezed == categoryName
          ? _self.categoryName
          : categoryName // ignore: cast_nullable_to_non_nullable
              as String?,
      images: null == images
          ? _self._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<String>,
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      tags: null == tags
          ? _self._tags
          : tags // ignore: cast_nullable_to_non_nullable
              as List<String>,
      isFeatured: null == isFeatured
          ? _self.isFeatured
          : isFeatured // ignore: cast_nullable_to_non_nullable
              as bool,
      isActive: null == isActive
          ? _self.isActive
          : isActive // ignore: cast_nullable_to_non_nullable
              as bool,
      totalSold: null == totalSold
          ? _self.totalSold
          : totalSold // ignore: cast_nullable_to_non_nullable
              as int,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      ingredients: freezed == ingredients
          ? _self.ingredients
          : ingredients // ignore: cast_nullable_to_non_nullable
              as String?,
      nutritionInfo: freezed == nutritionInfo
          ? _self._nutritionInfo
          : nutritionInfo // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      storageInstructions: freezed == storageInstructions
          ? _self.storageInstructions
          : storageInstructions // ignore: cast_nullable_to_non_nullable
              as String?,
      brand: freezed == brand
          ? _self.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String?,
      brandLogoUrl: freezed == brandLogoUrl
          ? _self.brandLogoUrl
          : brandLogoUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      netQuantity: freezed == netQuantity
          ? _self.netQuantity
          : netQuantity // ignore: cast_nullable_to_non_nullable
              as String?,
      highlights: freezed == highlights
          ? _self._highlights
          : highlights // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      attributes: freezed == attributes
          ? _self._attributes
          : attributes // ignore: cast_nullable_to_non_nullable
              as List<dynamic>?,
      vendorName: freezed == vendorName
          ? _self.vendorName
          : vendorName // ignore: cast_nullable_to_non_nullable
              as String?,
      soldBy: freezed == soldBy
          ? _self.soldBy
          : soldBy // ignore: cast_nullable_to_non_nullable
              as String?,
      createdAt: freezed == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as String?,
      vendorAddress: freezed == vendorAddress
          ? _self.vendorAddress
          : vendorAddress // ignore: cast_nullable_to_non_nullable
              as String?,
      vendorFssai: freezed == vendorFssai
          ? _self.vendorFssai
          : vendorFssai // ignore: cast_nullable_to_non_nullable
              as String?,
      returnPolicy: null == returnPolicy
          ? _self.returnPolicy
          : returnPolicy // ignore: cast_nullable_to_non_nullable
              as String,
      avgRating: null == avgRating
          ? _self.avgRating
          : avgRating // ignore: cast_nullable_to_non_nullable
              as double,
      ratingCount: null == ratingCount
          ? _self.ratingCount
          : ratingCount // ignore: cast_nullable_to_non_nullable
              as int,
      isAuthentic: null == isAuthentic
          ? _self.isAuthentic
          : isAuthentic // ignore: cast_nullable_to_non_nullable
              as bool,
      productFamilyId: freezed == productFamilyId
          ? _self.productFamilyId
          : productFamilyId // ignore: cast_nullable_to_non_nullable
              as String?,
      familyName: freezed == familyName
          ? _self.familyName
          : familyName // ignore: cast_nullable_to_non_nullable
              as String?,
      optionLabel: freezed == optionLabel
          ? _self.optionLabel
          : optionLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      optionCount: null == optionCount
          ? _self.optionCount
          : optionCount // ignore: cast_nullable_to_non_nullable
              as int,
      optionSortOrder: null == optionSortOrder
          ? _self.optionSortOrder
          : optionSortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      isDefaultOption: null == isDefaultOption
          ? _self.isDefaultOption
          : isDefaultOption // ignore: cast_nullable_to_non_nullable
              as bool,
      foodType: null == foodType
          ? _self.foodType
          : foodType // ignore: cast_nullable_to_non_nullable
              as String,
      originTag: null == originTag
          ? _self.originTag
          : originTag // ignore: cast_nullable_to_non_nullable
              as String,
      customBadges: null == customBadges
          ? _self._customBadges
          : customBadges // ignore: cast_nullable_to_non_nullable
              as List<String>,
      displayDeliveryMinutes: freezed == displayDeliveryMinutes
          ? _self.displayDeliveryMinutes
          : displayDeliveryMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      shopProductId: freezed == shopProductId
          ? _self.shopProductId
          : shopProductId // ignore: cast_nullable_to_non_nullable
              as String?,
      shopId: freezed == shopId
          ? _self.shopId
          : shopId // ignore: cast_nullable_to_non_nullable
              as String?,
      bulkMinQuantity: freezed == bulkMinQuantity
          ? _self.bulkMinQuantity
          : bulkMinQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
      bulkMaxQuantity: freezed == bulkMaxQuantity
          ? _self.bulkMaxQuantity
          : bulkMaxQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
      bulkOrderEligible: freezed == bulkOrderEligible
          ? _self.bulkOrderEligible
          : bulkOrderEligible // ignore: cast_nullable_to_non_nullable
              as bool?,
      isSponsored: null == isSponsored
          ? _self.isSponsored
          : isSponsored // ignore: cast_nullable_to_non_nullable
              as bool,
      adToken: freezed == adToken
          ? _self.adToken
          : adToken // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
