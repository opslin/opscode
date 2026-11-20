// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cart_item_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CartItemEntity {
  String get productId;
  String get name;
  double get price;
  int get quantity;
  double get total;
  double? get salePrice;
  String? get unit;

  /// Full pack-size string as the shopper should see it (e.g. "200 gm"),
  /// distinct from [unit] which is just the bare unit code (e.g. "g").
  String? get netQuantity;
  String? get thumbnailUrl;
  String? get shopProductId;
  String? get shopId;

  /// The seller's shop name (the cart groups lines under it: "Sold by …").
  String? get shopName;
  String? get optionLabel;
  String? get familyName;
  String? get foodType;
  String? get originTag;
  int?
      get displayDeliveryMinutes; // Lets the cart screen's own "+" button evaluate a CATEGORY-scoped
// purchase-limit rule from a cart line alone.
  String?
      get categoryId; // A line can go out of stock (or get manually delisted) after it was
// added — e.g. another customer buying the last unit first while this
// one sits in this cart. The backend still returns the line (so it
// stays visible here) but excludes it from subtotal/totalPayable.
  bool get isAvailable;
  int get stockQuantity; // Only ever non-null when this line's own price mode is wholesale (the
// backend nulls both for a retail line regardless of what the listing
// itself has configured — see cart.service.js#_formatLine). Lets the
// cart screen's stepper enforce the same floor/ceiling the ADD button
// already applied when this line was first created.
  int? get bulkMinQuantity;
  int? get bulkMaxQuantity;

  /// Create a copy of CartItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CartItemEntityCopyWith<CartItemEntity> get copyWith =>
      _$CartItemEntityCopyWithImpl<CartItemEntity>(
          this as CartItemEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CartItemEntity &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.salePrice, salePrice) ||
                other.salePrice == salePrice) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.netQuantity, netQuantity) ||
                other.netQuantity == netQuantity) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.shopProductId, shopProductId) ||
                other.shopProductId == shopProductId) &&
            (identical(other.shopId, shopId) || other.shopId == shopId) &&
            (identical(other.shopName, shopName) ||
                other.shopName == shopName) &&
            (identical(other.optionLabel, optionLabel) ||
                other.optionLabel == optionLabel) &&
            (identical(other.familyName, familyName) ||
                other.familyName == familyName) &&
            (identical(other.foodType, foodType) ||
                other.foodType == foodType) &&
            (identical(other.originTag, originTag) ||
                other.originTag == originTag) &&
            (identical(other.displayDeliveryMinutes, displayDeliveryMinutes) ||
                other.displayDeliveryMinutes == displayDeliveryMinutes) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            (identical(other.bulkMinQuantity, bulkMinQuantity) ||
                other.bulkMinQuantity == bulkMinQuantity) &&
            (identical(other.bulkMaxQuantity, bulkMaxQuantity) ||
                other.bulkMaxQuantity == bulkMaxQuantity));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        productId,
        name,
        price,
        quantity,
        total,
        salePrice,
        unit,
        netQuantity,
        thumbnailUrl,
        shopProductId,
        shopId,
        shopName,
        optionLabel,
        familyName,
        foodType,
        originTag,
        displayDeliveryMinutes,
        categoryId,
        isAvailable,
        stockQuantity,
        bulkMinQuantity,
        bulkMaxQuantity
      ]);

  @override
  String toString() {
    return 'CartItemEntity(productId: $productId, name: $name, price: $price, quantity: $quantity, total: $total, salePrice: $salePrice, unit: $unit, netQuantity: $netQuantity, thumbnailUrl: $thumbnailUrl, shopProductId: $shopProductId, shopId: $shopId, shopName: $shopName, optionLabel: $optionLabel, familyName: $familyName, foodType: $foodType, originTag: $originTag, displayDeliveryMinutes: $displayDeliveryMinutes, categoryId: $categoryId, isAvailable: $isAvailable, stockQuantity: $stockQuantity, bulkMinQuantity: $bulkMinQuantity, bulkMaxQuantity: $bulkMaxQuantity)';
  }
}

/// @nodoc
abstract mixin class $CartItemEntityCopyWith<$Res> {
  factory $CartItemEntityCopyWith(
          CartItemEntity value, $Res Function(CartItemEntity) _then) =
      _$CartItemEntityCopyWithImpl;
  @useResult
  $Res call(
      {String productId,
      String name,
      double price,
      int quantity,
      double total,
      double? salePrice,
      String? unit,
      String? netQuantity,
      String? thumbnailUrl,
      String? shopProductId,
      String? shopId,
      String? shopName,
      String? optionLabel,
      String? familyName,
      String? foodType,
      String? originTag,
      int? displayDeliveryMinutes,
      String? categoryId,
      bool isAvailable,
      int stockQuantity,
      int? bulkMinQuantity,
      int? bulkMaxQuantity});
}

/// @nodoc
class _$CartItemEntityCopyWithImpl<$Res>
    implements $CartItemEntityCopyWith<$Res> {
  _$CartItemEntityCopyWithImpl(this._self, this._then);

  final CartItemEntity _self;
  final $Res Function(CartItemEntity) _then;

  /// Create a copy of CartItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? name = null,
    Object? price = null,
    Object? quantity = null,
    Object? total = null,
    Object? salePrice = freezed,
    Object? unit = freezed,
    Object? netQuantity = freezed,
    Object? thumbnailUrl = freezed,
    Object? shopProductId = freezed,
    Object? shopId = freezed,
    Object? shopName = freezed,
    Object? optionLabel = freezed,
    Object? familyName = freezed,
    Object? foodType = freezed,
    Object? originTag = freezed,
    Object? displayDeliveryMinutes = freezed,
    Object? categoryId = freezed,
    Object? isAvailable = null,
    Object? stockQuantity = null,
    Object? bulkMinQuantity = freezed,
    Object? bulkMaxQuantity = freezed,
  }) {
    return _then(_self.copyWith(
      productId: null == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      salePrice: freezed == salePrice
          ? _self.salePrice
          : salePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      unit: freezed == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String?,
      netQuantity: freezed == netQuantity
          ? _self.netQuantity
          : netQuantity // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      shopProductId: freezed == shopProductId
          ? _self.shopProductId
          : shopProductId // ignore: cast_nullable_to_non_nullable
              as String?,
      shopId: freezed == shopId
          ? _self.shopId
          : shopId // ignore: cast_nullable_to_non_nullable
              as String?,
      shopName: freezed == shopName
          ? _self.shopName
          : shopName // ignore: cast_nullable_to_non_nullable
              as String?,
      optionLabel: freezed == optionLabel
          ? _self.optionLabel
          : optionLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      familyName: freezed == familyName
          ? _self.familyName
          : familyName // ignore: cast_nullable_to_non_nullable
              as String?,
      foodType: freezed == foodType
          ? _self.foodType
          : foodType // ignore: cast_nullable_to_non_nullable
              as String?,
      originTag: freezed == originTag
          ? _self.originTag
          : originTag // ignore: cast_nullable_to_non_nullable
              as String?,
      displayDeliveryMinutes: freezed == displayDeliveryMinutes
          ? _self.displayDeliveryMinutes
          : displayDeliveryMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _self.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      stockQuantity: null == stockQuantity
          ? _self.stockQuantity
          : stockQuantity // ignore: cast_nullable_to_non_nullable
              as int,
      bulkMinQuantity: freezed == bulkMinQuantity
          ? _self.bulkMinQuantity
          : bulkMinQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
      bulkMaxQuantity: freezed == bulkMaxQuantity
          ? _self.bulkMaxQuantity
          : bulkMaxQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [CartItemEntity].
extension CartItemEntityPatterns on CartItemEntity {
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
    TResult Function(_CartItemEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartItemEntity() when $default != null:
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
    TResult Function(_CartItemEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartItemEntity():
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
    TResult? Function(_CartItemEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartItemEntity() when $default != null:
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
            String productId,
            String name,
            double price,
            int quantity,
            double total,
            double? salePrice,
            String? unit,
            String? netQuantity,
            String? thumbnailUrl,
            String? shopProductId,
            String? shopId,
            String? shopName,
            String? optionLabel,
            String? familyName,
            String? foodType,
            String? originTag,
            int? displayDeliveryMinutes,
            String? categoryId,
            bool isAvailable,
            int stockQuantity,
            int? bulkMinQuantity,
            int? bulkMaxQuantity)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartItemEntity() when $default != null:
        return $default(
            _that.productId,
            _that.name,
            _that.price,
            _that.quantity,
            _that.total,
            _that.salePrice,
            _that.unit,
            _that.netQuantity,
            _that.thumbnailUrl,
            _that.shopProductId,
            _that.shopId,
            _that.shopName,
            _that.optionLabel,
            _that.familyName,
            _that.foodType,
            _that.originTag,
            _that.displayDeliveryMinutes,
            _that.categoryId,
            _that.isAvailable,
            _that.stockQuantity,
            _that.bulkMinQuantity,
            _that.bulkMaxQuantity);
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
            String productId,
            String name,
            double price,
            int quantity,
            double total,
            double? salePrice,
            String? unit,
            String? netQuantity,
            String? thumbnailUrl,
            String? shopProductId,
            String? shopId,
            String? shopName,
            String? optionLabel,
            String? familyName,
            String? foodType,
            String? originTag,
            int? displayDeliveryMinutes,
            String? categoryId,
            bool isAvailable,
            int stockQuantity,
            int? bulkMinQuantity,
            int? bulkMaxQuantity)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartItemEntity():
        return $default(
            _that.productId,
            _that.name,
            _that.price,
            _that.quantity,
            _that.total,
            _that.salePrice,
            _that.unit,
            _that.netQuantity,
            _that.thumbnailUrl,
            _that.shopProductId,
            _that.shopId,
            _that.shopName,
            _that.optionLabel,
            _that.familyName,
            _that.foodType,
            _that.originTag,
            _that.displayDeliveryMinutes,
            _that.categoryId,
            _that.isAvailable,
            _that.stockQuantity,
            _that.bulkMinQuantity,
            _that.bulkMaxQuantity);
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
            String productId,
            String name,
            double price,
            int quantity,
            double total,
            double? salePrice,
            String? unit,
            String? netQuantity,
            String? thumbnailUrl,
            String? shopProductId,
            String? shopId,
            String? shopName,
            String? optionLabel,
            String? familyName,
            String? foodType,
            String? originTag,
            int? displayDeliveryMinutes,
            String? categoryId,
            bool isAvailable,
            int stockQuantity,
            int? bulkMinQuantity,
            int? bulkMaxQuantity)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartItemEntity() when $default != null:
        return $default(
            _that.productId,
            _that.name,
            _that.price,
            _that.quantity,
            _that.total,
            _that.salePrice,
            _that.unit,
            _that.netQuantity,
            _that.thumbnailUrl,
            _that.shopProductId,
            _that.shopId,
            _that.shopName,
            _that.optionLabel,
            _that.familyName,
            _that.foodType,
            _that.originTag,
            _that.displayDeliveryMinutes,
            _that.categoryId,
            _that.isAvailable,
            _that.stockQuantity,
            _that.bulkMinQuantity,
            _that.bulkMaxQuantity);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CartItemEntity extends CartItemEntity {
  const _CartItemEntity(
      {required this.productId,
      required this.name,
      required this.price,
      required this.quantity,
      required this.total,
      this.salePrice,
      this.unit,
      this.netQuantity,
      this.thumbnailUrl,
      this.shopProductId,
      this.shopId,
      this.shopName,
      this.optionLabel,
      this.familyName,
      this.foodType,
      this.originTag,
      this.displayDeliveryMinutes,
      this.categoryId,
      this.isAvailable = true,
      this.stockQuantity = 9999,
      this.bulkMinQuantity,
      this.bulkMaxQuantity})
      : super._();

  @override
  final String productId;
  @override
  final String name;
  @override
  final double price;
  @override
  final int quantity;
  @override
  final double total;
  @override
  final double? salePrice;
  @override
  final String? unit;

  /// Full pack-size string as the shopper should see it (e.g. "200 gm"),
  /// distinct from [unit] which is just the bare unit code (e.g. "g").
  @override
  final String? netQuantity;
  @override
  final String? thumbnailUrl;
  @override
  final String? shopProductId;
  @override
  final String? shopId;

  /// The seller's shop name (the cart groups lines under it: "Sold by …").
  @override
  final String? shopName;
  @override
  final String? optionLabel;
  @override
  final String? familyName;
  @override
  final String? foodType;
  @override
  final String? originTag;
  @override
  final int? displayDeliveryMinutes;
// Lets the cart screen's own "+" button evaluate a CATEGORY-scoped
// purchase-limit rule from a cart line alone.
  @override
  final String? categoryId;
// A line can go out of stock (or get manually delisted) after it was
// added — e.g. another customer buying the last unit first while this
// one sits in this cart. The backend still returns the line (so it
// stays visible here) but excludes it from subtotal/totalPayable.
  @override
  @JsonKey()
  final bool isAvailable;
  @override
  @JsonKey()
  final int stockQuantity;
// Only ever non-null when this line's own price mode is wholesale (the
// backend nulls both for a retail line regardless of what the listing
// itself has configured — see cart.service.js#_formatLine). Lets the
// cart screen's stepper enforce the same floor/ceiling the ADD button
// already applied when this line was first created.
  @override
  final int? bulkMinQuantity;
  @override
  final int? bulkMaxQuantity;

  /// Create a copy of CartItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CartItemEntityCopyWith<_CartItemEntity> get copyWith =>
      __$CartItemEntityCopyWithImpl<_CartItemEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CartItemEntity &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.salePrice, salePrice) ||
                other.salePrice == salePrice) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.netQuantity, netQuantity) ||
                other.netQuantity == netQuantity) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.shopProductId, shopProductId) ||
                other.shopProductId == shopProductId) &&
            (identical(other.shopId, shopId) || other.shopId == shopId) &&
            (identical(other.shopName, shopName) ||
                other.shopName == shopName) &&
            (identical(other.optionLabel, optionLabel) ||
                other.optionLabel == optionLabel) &&
            (identical(other.familyName, familyName) ||
                other.familyName == familyName) &&
            (identical(other.foodType, foodType) ||
                other.foodType == foodType) &&
            (identical(other.originTag, originTag) ||
                other.originTag == originTag) &&
            (identical(other.displayDeliveryMinutes, displayDeliveryMinutes) ||
                other.displayDeliveryMinutes == displayDeliveryMinutes) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.isAvailable, isAvailable) ||
                other.isAvailable == isAvailable) &&
            (identical(other.stockQuantity, stockQuantity) ||
                other.stockQuantity == stockQuantity) &&
            (identical(other.bulkMinQuantity, bulkMinQuantity) ||
                other.bulkMinQuantity == bulkMinQuantity) &&
            (identical(other.bulkMaxQuantity, bulkMaxQuantity) ||
                other.bulkMaxQuantity == bulkMaxQuantity));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        productId,
        name,
        price,
        quantity,
        total,
        salePrice,
        unit,
        netQuantity,
        thumbnailUrl,
        shopProductId,
        shopId,
        shopName,
        optionLabel,
        familyName,
        foodType,
        originTag,
        displayDeliveryMinutes,
        categoryId,
        isAvailable,
        stockQuantity,
        bulkMinQuantity,
        bulkMaxQuantity
      ]);

  @override
  String toString() {
    return 'CartItemEntity(productId: $productId, name: $name, price: $price, quantity: $quantity, total: $total, salePrice: $salePrice, unit: $unit, netQuantity: $netQuantity, thumbnailUrl: $thumbnailUrl, shopProductId: $shopProductId, shopId: $shopId, shopName: $shopName, optionLabel: $optionLabel, familyName: $familyName, foodType: $foodType, originTag: $originTag, displayDeliveryMinutes: $displayDeliveryMinutes, categoryId: $categoryId, isAvailable: $isAvailable, stockQuantity: $stockQuantity, bulkMinQuantity: $bulkMinQuantity, bulkMaxQuantity: $bulkMaxQuantity)';
  }
}

/// @nodoc
abstract mixin class _$CartItemEntityCopyWith<$Res>
    implements $CartItemEntityCopyWith<$Res> {
  factory _$CartItemEntityCopyWith(
          _CartItemEntity value, $Res Function(_CartItemEntity) _then) =
      __$CartItemEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String productId,
      String name,
      double price,
      int quantity,
      double total,
      double? salePrice,
      String? unit,
      String? netQuantity,
      String? thumbnailUrl,
      String? shopProductId,
      String? shopId,
      String? shopName,
      String? optionLabel,
      String? familyName,
      String? foodType,
      String? originTag,
      int? displayDeliveryMinutes,
      String? categoryId,
      bool isAvailable,
      int stockQuantity,
      int? bulkMinQuantity,
      int? bulkMaxQuantity});
}

/// @nodoc
class __$CartItemEntityCopyWithImpl<$Res>
    implements _$CartItemEntityCopyWith<$Res> {
  __$CartItemEntityCopyWithImpl(this._self, this._then);

  final _CartItemEntity _self;
  final $Res Function(_CartItemEntity) _then;

  /// Create a copy of CartItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? productId = null,
    Object? name = null,
    Object? price = null,
    Object? quantity = null,
    Object? total = null,
    Object? salePrice = freezed,
    Object? unit = freezed,
    Object? netQuantity = freezed,
    Object? thumbnailUrl = freezed,
    Object? shopProductId = freezed,
    Object? shopId = freezed,
    Object? shopName = freezed,
    Object? optionLabel = freezed,
    Object? familyName = freezed,
    Object? foodType = freezed,
    Object? originTag = freezed,
    Object? displayDeliveryMinutes = freezed,
    Object? categoryId = freezed,
    Object? isAvailable = null,
    Object? stockQuantity = null,
    Object? bulkMinQuantity = freezed,
    Object? bulkMaxQuantity = freezed,
  }) {
    return _then(_CartItemEntity(
      productId: null == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      price: null == price
          ? _self.price
          : price // ignore: cast_nullable_to_non_nullable
              as double,
      quantity: null == quantity
          ? _self.quantity
          : quantity // ignore: cast_nullable_to_non_nullable
              as int,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      salePrice: freezed == salePrice
          ? _self.salePrice
          : salePrice // ignore: cast_nullable_to_non_nullable
              as double?,
      unit: freezed == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String?,
      netQuantity: freezed == netQuantity
          ? _self.netQuantity
          : netQuantity // ignore: cast_nullable_to_non_nullable
              as String?,
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      shopProductId: freezed == shopProductId
          ? _self.shopProductId
          : shopProductId // ignore: cast_nullable_to_non_nullable
              as String?,
      shopId: freezed == shopId
          ? _self.shopId
          : shopId // ignore: cast_nullable_to_non_nullable
              as String?,
      shopName: freezed == shopName
          ? _self.shopName
          : shopName // ignore: cast_nullable_to_non_nullable
              as String?,
      optionLabel: freezed == optionLabel
          ? _self.optionLabel
          : optionLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      familyName: freezed == familyName
          ? _self.familyName
          : familyName // ignore: cast_nullable_to_non_nullable
              as String?,
      foodType: freezed == foodType
          ? _self.foodType
          : foodType // ignore: cast_nullable_to_non_nullable
              as String?,
      originTag: freezed == originTag
          ? _self.originTag
          : originTag // ignore: cast_nullable_to_non_nullable
              as String?,
      displayDeliveryMinutes: freezed == displayDeliveryMinutes
          ? _self.displayDeliveryMinutes
          : displayDeliveryMinutes // ignore: cast_nullable_to_non_nullable
              as int?,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      isAvailable: null == isAvailable
          ? _self.isAvailable
          : isAvailable // ignore: cast_nullable_to_non_nullable
              as bool,
      stockQuantity: null == stockQuantity
          ? _self.stockQuantity
          : stockQuantity // ignore: cast_nullable_to_non_nullable
              as int,
      bulkMinQuantity: freezed == bulkMinQuantity
          ? _self.bulkMinQuantity
          : bulkMinQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
      bulkMaxQuantity: freezed == bulkMaxQuantity
          ? _self.bulkMaxQuantity
          : bulkMaxQuantity // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

// dart format on
