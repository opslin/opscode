// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProductEntity {
  String get id;
  String get name;
  String get slug;
  double get price;
  int get stockQuantity;
  String get unit;
  List<String> get images;
  List<String> get tags;
  bool get isFeatured;
  bool get isActive;
  int get totalSold;
  double? get salePrice;
  String? get categoryId;
  String? get categoryName;
  String? get thumbnailUrl;
  String? get description;
  String? get ingredients;
  Map<String, dynamic>? get nutritionInfo;
  String? get storageInstructions;
  String? get brand;
  String? get brandLogoUrl;
  String? get netQuantity;
  Map<String, dynamic>? get highlights;
  List<Map<String, dynamic>>? get attributes;
  String? get vendorName;

  /// Who sells it (vendor, or the platform store) — the card's "Sold by" line.
  String? get soldBy;
  DateTime? get createdAt;
  String? get vendorAddress;
  String? get vendorFssai;
  String get returnPolicy;
  double get avgRating;
  int get ratingCount;
  bool get isAuthentic; // Phase 1/3: product family / option fields
  String? get productFamilyId;
  String? get familyName;
  String? get optionLabel;
  int get optionCount;
  int get optionSortOrder;
  bool get isDefaultOption;
  String get foodType;
  String get originTag;
  List<String> get customBadges;
  int? get displayDeliveryMinutes;
  String? get shopProductId;
  String?
      get shopId; // B2B bulk-order settings for this shop's listing (null when there's no
// shop context, e.g. an admin/anonymous read) — see bulk_order_eligible
// on shop_products. Independent of price mode: these describe the
// listing itself, not whether the current viewer is currently buying
// wholesale.
  int? get bulkMinQuantity;
  int? get bulkMaxQuantity;
  bool? get bulkOrderEligible;

  /// Sponsored placement: shows an "AD" tag; a tap reports [adToken] to bill the click.
  bool get isSponsored;
  String? get adToken;

  /// Create a copy of ProductEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ProductEntityCopyWith<ProductEntity> get copyWith =>
      _$ProductEntityCopyWithImpl<ProductEntity>(
          this as ProductEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ProductEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            const DeepCollectionEquality().equals(other.images, images) &&
            const DeepCollectionEquality().equals(other.tags, tags) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.totalSold, totalSold) ||
                other.totalSold == totalSold) &&
            (identical(other.salePrice, salePrice) ||
                other.salePrice == salePrice) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
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

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        slug,
        price,
        stockQuantity,
        unit,
        const DeepCollectionEquality().hash(images),
        const DeepCollectionEquality().hash(tags),
        isFeatured,
        isActive,
        totalSold,
        salePrice,
        categoryId,
        categoryName,
        thumbnailUrl,
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
    return 'ProductEntity(id: $id, name: $name, slug: $slug, price: $price, stockQuantity: $stockQuantity, unit: $unit, images: $images, tags: $tags, isFeatured: $isFeatured, isActive: $isActive, totalSold: $totalSold, salePrice: $salePrice, categoryId: $categoryId, categoryName: $categoryName, thumbnailUrl: $thumbnailUrl, description: $description, ingredients: $ingredients, nutritionInfo: $nutritionInfo, storageInstructions: $storageInstructions, brand: $brand, brandLogoUrl: $brandLogoUrl, netQuantity: $netQuantity, highlights: $highlights, attributes: $attributes, vendorName: $vendorName, soldBy: $soldBy, createdAt: $createdAt, vendorAddress: $vendorAddress, vendorFssai: $vendorFssai, returnPolicy: $returnPolicy, avgRating: $avgRating, ratingCount: $ratingCount, isAuthentic: $isAuthentic, productFamilyId: $productFamilyId, familyName: $familyName, optionLabel: $optionLabel, optionCount: $optionCount, optionSortOrder: $optionSortOrder, isDefaultOption: $isDefaultOption, foodType: $foodType, originTag: $originTag, customBadges: $customBadges, displayDeliveryMinutes: $displayDeliveryMinutes, shopProductId: $shopProductId, shopId: $shopId, bulkMinQuantity: $bulkMinQuantity, bulkMaxQuantity: $bulkMaxQuantity, bulkOrderEligible: $bulkOrderEligible, isSponsored: $isSponsored, adToken: $adToken)';
  }
}

/// @nodoc
abstract mixin class $ProductEntityCopyWith<$Res> {
  factory $ProductEntityCopyWith(
          ProductEntity value, $Res Function(ProductEntity) _then) =
      _$ProductEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String slug,
      double price,
      int stockQuantity,
      String unit,
      List<String> images,
      List<String> tags,
      bool isFeatured,
      bool isActive,
      int totalSold,
      double? salePrice,
      String? categoryId,
      String? categoryName,
      String? thumbnailUrl,
      String? description,
      String? ingredients,
      Map<String, dynamic>? nutritionInfo,
      String? storageInstructions,
      String? brand,
      String? brandLogoUrl,
      String? netQuantity,
      Map<String, dynamic>? highlights,
      List<Map<String, dynamic>>? attributes,
      String? vendorName,
      String? soldBy,
      DateTime? createdAt,
      String? vendorAddress,
      String? vendorFssai,
      String returnPolicy,
      double avgRating,
      int ratingCount,
      bool isAuthentic,
      String? productFamilyId,
      String? familyName,
      String? optionLabel,
      int optionCount,
      int optionSortOrder,
      bool isDefaultOption,
      String foodType,
      String originTag,
      List<String> customBadges,
      int? displayDeliveryMinutes,
      String? shopProductId,
      String? shopId,
      int? bulkMinQuantity,
      int? bulkMaxQuantity,
      bool? bulkOrderEligible,
      bool isSponsored,
      String? adToken});
}

/// @nodoc
class _$ProductEntityCopyWithImpl<$Res>
    implements $ProductEntityCopyWith<$Res> {
  _$ProductEntityCopyWithImpl(this._self, this._then);

  final ProductEntity _self;
  final $Res Function(ProductEntity) _then;

  /// Create a copy of ProductEntity
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
    Object? images = null,
    Object? tags = null,
    Object? isFeatured = null,
    Object? isActive = null,
    Object? totalSold = null,
    Object? salePrice = freezed,
    Object? categoryId = freezed,
    Object? categoryName = freezed,
    Object? thumbnailUrl = freezed,
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
      images: null == images
          ? _self.images
          : images // ignore: cast_nullable_to_non_nullable
              as List<String>,
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
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
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
              as List<Map<String, dynamic>>?,
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
              as DateTime?,
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

/// Adds pattern-matching-related methods to [ProductEntity].
extension ProductEntityPatterns on ProductEntity {
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
    TResult Function(_ProductEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProductEntity() when $default != null:
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
    TResult Function(_ProductEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProductEntity():
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
    TResult? Function(_ProductEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProductEntity() when $default != null:
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
            double price,
            int stockQuantity,
            String unit,
            List<String> images,
            List<String> tags,
            bool isFeatured,
            bool isActive,
            int totalSold,
            double? salePrice,
            String? categoryId,
            String? categoryName,
            String? thumbnailUrl,
            String? description,
            String? ingredients,
            Map<String, dynamic>? nutritionInfo,
            String? storageInstructions,
            String? brand,
            String? brandLogoUrl,
            String? netQuantity,
            Map<String, dynamic>? highlights,
            List<Map<String, dynamic>>? attributes,
            String? vendorName,
            String? soldBy,
            DateTime? createdAt,
            String? vendorAddress,
            String? vendorFssai,
            String returnPolicy,
            double avgRating,
            int ratingCount,
            bool isAuthentic,
            String? productFamilyId,
            String? familyName,
            String? optionLabel,
            int optionCount,
            int optionSortOrder,
            bool isDefaultOption,
            String foodType,
            String originTag,
            List<String> customBadges,
            int? displayDeliveryMinutes,
            String? shopProductId,
            String? shopId,
            int? bulkMinQuantity,
            int? bulkMaxQuantity,
            bool? bulkOrderEligible,
            bool isSponsored,
            String? adToken)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ProductEntity() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.slug,
            _that.price,
            _that.stockQuantity,
            _that.unit,
            _that.images,
            _that.tags,
            _that.isFeatured,
            _that.isActive,
            _that.totalSold,
            _that.salePrice,
            _that.categoryId,
            _that.categoryName,
            _that.thumbnailUrl,
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
            double price,
            int stockQuantity,
            String unit,
            List<String> images,
            List<String> tags,
            bool isFeatured,
            bool isActive,
            int totalSold,
            double? salePrice,
            String? categoryId,
            String? categoryName,
            String? thumbnailUrl,
            String? description,
            String? ingredients,
            Map<String, dynamic>? nutritionInfo,
            String? storageInstructions,
            String? brand,
            String? brandLogoUrl,
            String? netQuantity,
            Map<String, dynamic>? highlights,
            List<Map<String, dynamic>>? attributes,
            String? vendorName,
            String? soldBy,
            DateTime? createdAt,
            String? vendorAddress,
            String? vendorFssai,
            String returnPolicy,
            double avgRating,
            int ratingCount,
            bool isAuthentic,
            String? productFamilyId,
            String? familyName,
            String? optionLabel,
            int optionCount,
            int optionSortOrder,
            bool isDefaultOption,
            String foodType,
            String originTag,
            List<String> customBadges,
            int? displayDeliveryMinutes,
            String? shopProductId,
            String? shopId,
            int? bulkMinQuantity,
            int? bulkMaxQuantity,
            bool? bulkOrderEligible,
            bool isSponsored,
            String? adToken)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProductEntity():
        return $default(
            _that.id,
            _that.name,
            _that.slug,
            _that.price,
            _that.stockQuantity,
            _that.unit,
            _that.images,
            _that.tags,
            _that.isFeatured,
            _that.isActive,
            _that.totalSold,
            _that.salePrice,
            _that.categoryId,
            _that.categoryName,
            _that.thumbnailUrl,
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
            double price,
            int stockQuantity,
            String unit,
            List<String> images,
            List<String> tags,
            bool isFeatured,
            bool isActive,
            int totalSold,
            double? salePrice,
            String? categoryId,
            String? categoryName,
            String? thumbnailUrl,
            String? description,
            String? ingredients,
            Map<String, dynamic>? nutritionInfo,
            String? storageInstructions,
            String? brand,
            String? brandLogoUrl,
            String? netQuantity,
            Map<String, dynamic>? highlights,
            List<Map<String, dynamic>>? attributes,
            String? vendorName,
            String? soldBy,
            DateTime? createdAt,
            String? vendorAddress,
            String? vendorFssai,
            String returnPolicy,
            double avgRating,
            int ratingCount,
            bool isAuthentic,
            String? productFamilyId,
            String? familyName,
            String? optionLabel,
            int optionCount,
            int optionSortOrder,
            bool isDefaultOption,
            String foodType,
            String originTag,
            List<String> customBadges,
            int? displayDeliveryMinutes,
            String? shopProductId,
            String? shopId,
            int? bulkMinQuantity,
            int? bulkMaxQuantity,
            bool? bulkOrderEligible,
            bool isSponsored,
            String? adToken)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ProductEntity() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.slug,
            _that.price,
            _that.stockQuantity,
            _that.unit,
            _that.images,
            _that.tags,
            _that.isFeatured,
            _that.isActive,
            _that.totalSold,
            _that.salePrice,
            _that.categoryId,
            _that.categoryName,
            _that.thumbnailUrl,
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

class _ProductEntity extends ProductEntity {
  const _ProductEntity(
      {required this.id,
      required this.name,
      required this.slug,
      required this.price,
      required this.stockQuantity,
      required this.unit,
      required final List<String> images,
      required final List<String> tags,
      required this.isFeatured,
      required this.isActive,
      required this.totalSold,
      this.salePrice,
      this.categoryId,
      this.categoryName,
      this.thumbnailUrl,
      this.description,
      this.ingredients,
      final Map<String, dynamic>? nutritionInfo,
      this.storageInstructions,
      this.brand,
      this.brandLogoUrl,
      this.netQuantity,
      final Map<String, dynamic>? highlights,
      final List<Map<String, dynamic>>? attributes,
      this.vendorName,
      this.soldBy,
      this.createdAt,
      this.vendorAddress,
      this.vendorFssai,
      this.returnPolicy = 'no_return',
      this.avgRating = 0.0,
      this.ratingCount = 0,
      this.isAuthentic = true,
      this.productFamilyId,
      this.familyName,
      this.optionLabel,
      this.optionCount = 1,
      this.optionSortOrder = 0,
      this.isDefaultOption = false,
      this.foodType = 'NONE',
      this.originTag = 'NONE',
      final List<String> customBadges = const <String>[],
      this.displayDeliveryMinutes,
      this.shopProductId,
      this.shopId,
      this.bulkMinQuantity,
      this.bulkMaxQuantity,
      this.bulkOrderEligible,
      this.isSponsored = false,
      this.adToken})
      : _images = images,
        _tags = tags,
        _nutritionInfo = nutritionInfo,
        _highlights = highlights,
        _attributes = attributes,
        _customBadges = customBadges,
        super._();

  @override
  final String id;
  @override
  final String name;
  @override
  final String slug;
  @override
  final double price;
  @override
  final int stockQuantity;
  @override
  final String unit;
  final List<String> _images;
  @override
  List<String> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  final List<String> _tags;
  @override
  List<String> get tags {
    if (_tags is EqualUnmodifiableListView) return _tags;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_tags);
  }

  @override
  final bool isFeatured;
  @override
  final bool isActive;
  @override
  final int totalSold;
  @override
  final double? salePrice;
  @override
  final String? categoryId;
  @override
  final String? categoryName;
  @override
  final String? thumbnailUrl;
  @override
  final String? description;
  @override
  final String? ingredients;
  final Map<String, dynamic>? _nutritionInfo;
  @override
  Map<String, dynamic>? get nutritionInfo {
    final value = _nutritionInfo;
    if (value == null) return null;
    if (_nutritionInfo is EqualUnmodifiableMapView) return _nutritionInfo;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? storageInstructions;
  @override
  final String? brand;
  @override
  final String? brandLogoUrl;
  @override
  final String? netQuantity;
  final Map<String, dynamic>? _highlights;
  @override
  Map<String, dynamic>? get highlights {
    final value = _highlights;
    if (value == null) return null;
    if (_highlights is EqualUnmodifiableMapView) return _highlights;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  final List<Map<String, dynamic>>? _attributes;
  @override
  List<Map<String, dynamic>>? get attributes {
    final value = _attributes;
    if (value == null) return null;
    if (_attributes is EqualUnmodifiableListView) return _attributes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  @override
  final String? vendorName;

  /// Who sells it (vendor, or the platform store) — the card's "Sold by" line.
  @override
  final String? soldBy;
  @override
  final DateTime? createdAt;
  @override
  final String? vendorAddress;
  @override
  final String? vendorFssai;
  @override
  @JsonKey()
  final String returnPolicy;
  @override
  @JsonKey()
  final double avgRating;
  @override
  @JsonKey()
  final int ratingCount;
  @override
  @JsonKey()
  final bool isAuthentic;
// Phase 1/3: product family / option fields
  @override
  final String? productFamilyId;
  @override
  final String? familyName;
  @override
  final String? optionLabel;
  @override
  @JsonKey()
  final int optionCount;
  @override
  @JsonKey()
  final int optionSortOrder;
  @override
  @JsonKey()
  final bool isDefaultOption;
  @override
  @JsonKey()
  final String foodType;
  @override
  @JsonKey()
  final String originTag;
  final List<String> _customBadges;
  @override
  @JsonKey()
  List<String> get customBadges {
    if (_customBadges is EqualUnmodifiableListView) return _customBadges;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_customBadges);
  }

  @override
  final int? displayDeliveryMinutes;
  @override
  final String? shopProductId;
  @override
  final String? shopId;
// B2B bulk-order settings for this shop's listing (null when there's no
// shop context, e.g. an admin/anonymous read) — see bulk_order_eligible
// on shop_products. Independent of price mode: these describe the
// listing itself, not whether the current viewer is currently buying
// wholesale.
  @override
  final int? bulkMinQuantity;
  @override
  final int? bulkMaxQuantity;
  @override
  final bool? bulkOrderEligible;

  /// Sponsored placement: shows an "AD" tag; a tap reports [adToken] to bill the click.
  @override
  @JsonKey()
  final bool isSponsored;
  @override
  final String? adToken;

  /// Create a copy of ProductEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ProductEntityCopyWith<_ProductEntity> get copyWith =>
      __$ProductEntityCopyWithImpl<_ProductEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ProductEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.slug, slug) || other.slug == slug) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            const DeepCollectionEquality().equals(other._tags, _tags) &&
            (identical(other.isFeatured, isFeatured) ||
                other.isFeatured == isFeatured) &&
            (identical(other.isActive, isActive) ||
                other.isActive == isActive) &&
            (identical(other.totalSold, totalSold) ||
                other.totalSold == totalSold) &&
            (identical(other.salePrice, salePrice) ||
                other.salePrice == salePrice) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.categoryName, categoryName) ||
                other.categoryName == categoryName) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
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

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        name,
        slug,
        price,
        stockQuantity,
        unit,
        const DeepCollectionEquality().hash(_images),
        const DeepCollectionEquality().hash(_tags),
        isFeatured,
        isActive,
        totalSold,
        salePrice,
        categoryId,
        categoryName,
        thumbnailUrl,
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
    return 'ProductEntity(id: $id, name: $name, slug: $slug, price: $price, stockQuantity: $stockQuantity, unit: $unit, images: $images, tags: $tags, isFeatured: $isFeatured, isActive: $isActive, totalSold: $totalSold, salePrice: $salePrice, categoryId: $categoryId, categoryName: $categoryName, thumbnailUrl: $thumbnailUrl, description: $description, ingredients: $ingredients, nutritionInfo: $nutritionInfo, storageInstructions: $storageInstructions, brand: $brand, brandLogoUrl: $brandLogoUrl, netQuantity: $netQuantity, highlights: $highlights, attributes: $attributes, vendorName: $vendorName, soldBy: $soldBy, createdAt: $createdAt, vendorAddress: $vendorAddress, vendorFssai: $vendorFssai, returnPolicy: $returnPolicy, avgRating: $avgRating, ratingCount: $ratingCount, isAuthentic: $isAuthentic, productFamilyId: $productFamilyId, familyName: $familyName, optionLabel: $optionLabel, optionCount: $optionCount, optionSortOrder: $optionSortOrder, isDefaultOption: $isDefaultOption, foodType: $foodType, originTag: $originTag, customBadges: $customBadges, displayDeliveryMinutes: $displayDeliveryMinutes, shopProductId: $shopProductId, shopId: $shopId, bulkMinQuantity: $bulkMinQuantity, bulkMaxQuantity: $bulkMaxQuantity, bulkOrderEligible: $bulkOrderEligible, isSponsored: $isSponsored, adToken: $adToken)';
  }
}

/// @nodoc
abstract mixin class _$ProductEntityCopyWith<$Res>
    implements $ProductEntityCopyWith<$Res> {
  factory _$ProductEntityCopyWith(
          _ProductEntity value, $Res Function(_ProductEntity) _then) =
      __$ProductEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String slug,
      double price,
      int stockQuantity,
      String unit,
      List<String> images,
      List<String> tags,
      bool isFeatured,
      bool isActive,
      int totalSold,
      double? salePrice,
      String? categoryId,
      String? categoryName,
      String? thumbnailUrl,
      String? description,
      String? ingredients,
      Map<String, dynamic>? nutritionInfo,
      String? storageInstructions,
      String? brand,
      String? brandLogoUrl,
      String? netQuantity,
      Map<String, dynamic>? highlights,
      List<Map<String, dynamic>>? attributes,
      String? vendorName,
      String? soldBy,
      DateTime? createdAt,
      String? vendorAddress,
      String? vendorFssai,
      String returnPolicy,
      double avgRating,
      int ratingCount,
      bool isAuthentic,
      String? productFamilyId,
      String? familyName,
      String? optionLabel,
      int optionCount,
      int optionSortOrder,
      bool isDefaultOption,
      String foodType,
      String originTag,
      List<String> customBadges,
      int? displayDeliveryMinutes,
      String? shopProductId,
      String? shopId,
      int? bulkMinQuantity,
      int? bulkMaxQuantity,
      bool? bulkOrderEligible,
      bool isSponsored,
      String? adToken});
}

/// @nodoc
class __$ProductEntityCopyWithImpl<$Res>
    implements _$ProductEntityCopyWith<$Res> {
  __$ProductEntityCopyWithImpl(this._self, this._then);

  final _ProductEntity _self;
  final $Res Function(_ProductEntity) _then;

  /// Create a copy of ProductEntity
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
    Object? images = null,
    Object? tags = null,
    Object? isFeatured = null,
    Object? isActive = null,
    Object? totalSold = null,
    Object? salePrice = freezed,
    Object? categoryId = freezed,
    Object? categoryName = freezed,
    Object? thumbnailUrl = freezed,
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
    return _then(_ProductEntity(
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
      images: null == images
          ? _self._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<String>,
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
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
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
              as List<Map<String, dynamic>>?,
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
              as DateTime?,
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
