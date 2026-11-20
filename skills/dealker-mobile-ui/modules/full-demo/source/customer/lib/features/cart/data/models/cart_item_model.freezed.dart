// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'cart_item_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CartItemModel {
  String get productId;
  String get name;
  @JsonKey(fromJson: _cartDoubleFromJson)
  double get price;
  int get quantity;
  @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson)
  double get total;
  @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
  double? get salePrice;
  String? get unit;
  @JsonKey(name: 'netQuantity')
  String? get netQuantity;
  String? get thumbnailUrl;
  @JsonKey(name: 'shopProductId')
  String? get shopProductId;
  @JsonKey(name: 'shopId')
  String? get shopId;
  @JsonKey(name: 'shopName')
  String? get shopName;
  @JsonKey(name: 'optionLabel')
  String? get optionLabel;
  @JsonKey(name: 'familyName')
  String? get familyName;
  @JsonKey(name: 'foodType')
  String? get foodType;
  @JsonKey(name: 'originTag')
  String? get originTag;
  @JsonKey(name: 'displayDeliveryMinutes')
  int? get displayDeliveryMinutes;
  @JsonKey(name: 'categoryId')
  String? get categoryId;
  @JsonKey(name: 'isAvailable', fromJson: _cartBoolFromJson)
  bool get isAvailable;
  @JsonKey(name: 'stockQuantity', fromJson: _cartStockFromJson)
  int get stockQuantity;
  @JsonKey(name: 'bulkMinQuantity')
  int? get bulkMinQuantity;
  @JsonKey(name: 'bulkMaxQuantity')
  int? get bulkMaxQuantity;

  /// Create a copy of CartItemModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CartItemModelCopyWith<CartItemModel> get copyWith =>
      _$CartItemModelCopyWithImpl<CartItemModel>(
          this as CartItemModel, _$identity);

  /// Serializes this CartItemModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CartItemModel &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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
    return 'CartItemModel(productId: $productId, name: $name, price: $price, quantity: $quantity, total: $total, salePrice: $salePrice, unit: $unit, netQuantity: $netQuantity, thumbnailUrl: $thumbnailUrl, shopProductId: $shopProductId, shopId: $shopId, shopName: $shopName, optionLabel: $optionLabel, familyName: $familyName, foodType: $foodType, originTag: $originTag, displayDeliveryMinutes: $displayDeliveryMinutes, categoryId: $categoryId, isAvailable: $isAvailable, stockQuantity: $stockQuantity, bulkMinQuantity: $bulkMinQuantity, bulkMaxQuantity: $bulkMaxQuantity)';
  }
}

/// @nodoc
abstract mixin class $CartItemModelCopyWith<$Res> {
  factory $CartItemModelCopyWith(
          CartItemModel value, $Res Function(CartItemModel) _then) =
      _$CartItemModelCopyWithImpl;
  @useResult
  $Res call(
      {String productId,
      String name,
      @JsonKey(fromJson: _cartDoubleFromJson) double price,
      int quantity,
      @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson) double total,
      @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
      double? salePrice,
      String? unit,
      @JsonKey(name: 'netQuantity') String? netQuantity,
      String? thumbnailUrl,
      @JsonKey(name: 'shopProductId') String? shopProductId,
      @JsonKey(name: 'shopId') String? shopId,
      @JsonKey(name: 'shopName') String? shopName,
      @JsonKey(name: 'optionLabel') String? optionLabel,
      @JsonKey(name: 'familyName') String? familyName,
      @JsonKey(name: 'foodType') String? foodType,
      @JsonKey(name: 'originTag') String? originTag,
      @JsonKey(name: 'displayDeliveryMinutes') int? displayDeliveryMinutes,
      @JsonKey(name: 'categoryId') String? categoryId,
      @JsonKey(name: 'isAvailable', fromJson: _cartBoolFromJson)
      bool isAvailable,
      @JsonKey(name: 'stockQuantity', fromJson: _cartStockFromJson)
      int stockQuantity,
      @JsonKey(name: 'bulkMinQuantity') int? bulkMinQuantity,
      @JsonKey(name: 'bulkMaxQuantity') int? bulkMaxQuantity});
}

/// @nodoc
class _$CartItemModelCopyWithImpl<$Res>
    implements $CartItemModelCopyWith<$Res> {
  _$CartItemModelCopyWithImpl(this._self, this._then);

  final CartItemModel _self;
  final $Res Function(CartItemModel) _then;

  /// Create a copy of CartItemModel
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

/// Adds pattern-matching-related methods to [CartItemModel].
extension CartItemModelPatterns on CartItemModel {
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
    TResult Function(_CartItemModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartItemModel() when $default != null:
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
    TResult Function(_CartItemModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartItemModel():
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
    TResult? Function(_CartItemModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartItemModel() when $default != null:
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
            @JsonKey(fromJson: _cartDoubleFromJson) double price,
            int quantity,
            @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson)
            double total,
            @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
            double? salePrice,
            String? unit,
            @JsonKey(name: 'netQuantity') String? netQuantity,
            String? thumbnailUrl,
            @JsonKey(name: 'shopProductId') String? shopProductId,
            @JsonKey(name: 'shopId') String? shopId,
            @JsonKey(name: 'shopName') String? shopName,
            @JsonKey(name: 'optionLabel') String? optionLabel,
            @JsonKey(name: 'familyName') String? familyName,
            @JsonKey(name: 'foodType') String? foodType,
            @JsonKey(name: 'originTag') String? originTag,
            @JsonKey(name: 'displayDeliveryMinutes')
            int? displayDeliveryMinutes,
            @JsonKey(name: 'categoryId') String? categoryId,
            @JsonKey(name: 'isAvailable', fromJson: _cartBoolFromJson)
            bool isAvailable,
            @JsonKey(name: 'stockQuantity', fromJson: _cartStockFromJson)
            int stockQuantity,
            @JsonKey(name: 'bulkMinQuantity') int? bulkMinQuantity,
            @JsonKey(name: 'bulkMaxQuantity') int? bulkMaxQuantity)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartItemModel() when $default != null:
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
            @JsonKey(fromJson: _cartDoubleFromJson) double price,
            int quantity,
            @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson)
            double total,
            @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
            double? salePrice,
            String? unit,
            @JsonKey(name: 'netQuantity') String? netQuantity,
            String? thumbnailUrl,
            @JsonKey(name: 'shopProductId') String? shopProductId,
            @JsonKey(name: 'shopId') String? shopId,
            @JsonKey(name: 'shopName') String? shopName,
            @JsonKey(name: 'optionLabel') String? optionLabel,
            @JsonKey(name: 'familyName') String? familyName,
            @JsonKey(name: 'foodType') String? foodType,
            @JsonKey(name: 'originTag') String? originTag,
            @JsonKey(name: 'displayDeliveryMinutes')
            int? displayDeliveryMinutes,
            @JsonKey(name: 'categoryId') String? categoryId,
            @JsonKey(name: 'isAvailable', fromJson: _cartBoolFromJson)
            bool isAvailable,
            @JsonKey(name: 'stockQuantity', fromJson: _cartStockFromJson)
            int stockQuantity,
            @JsonKey(name: 'bulkMinQuantity') int? bulkMinQuantity,
            @JsonKey(name: 'bulkMaxQuantity') int? bulkMaxQuantity)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartItemModel():
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
            @JsonKey(fromJson: _cartDoubleFromJson) double price,
            int quantity,
            @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson)
            double total,
            @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
            double? salePrice,
            String? unit,
            @JsonKey(name: 'netQuantity') String? netQuantity,
            String? thumbnailUrl,
            @JsonKey(name: 'shopProductId') String? shopProductId,
            @JsonKey(name: 'shopId') String? shopId,
            @JsonKey(name: 'shopName') String? shopName,
            @JsonKey(name: 'optionLabel') String? optionLabel,
            @JsonKey(name: 'familyName') String? familyName,
            @JsonKey(name: 'foodType') String? foodType,
            @JsonKey(name: 'originTag') String? originTag,
            @JsonKey(name: 'displayDeliveryMinutes')
            int? displayDeliveryMinutes,
            @JsonKey(name: 'categoryId') String? categoryId,
            @JsonKey(name: 'isAvailable', fromJson: _cartBoolFromJson)
            bool isAvailable,
            @JsonKey(name: 'stockQuantity', fromJson: _cartStockFromJson)
            int stockQuantity,
            @JsonKey(name: 'bulkMinQuantity') int? bulkMinQuantity,
            @JsonKey(name: 'bulkMaxQuantity') int? bulkMaxQuantity)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartItemModel() when $default != null:
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
@JsonSerializable()
class _CartItemModel extends CartItemModel {
  const _CartItemModel(
      {required this.productId,
      required this.name,
      @JsonKey(fromJson: _cartDoubleFromJson) required this.price,
      required this.quantity,
      @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson)
      required this.total,
      @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
      this.salePrice,
      this.unit,
      @JsonKey(name: 'netQuantity') this.netQuantity,
      this.thumbnailUrl,
      @JsonKey(name: 'shopProductId') this.shopProductId,
      @JsonKey(name: 'shopId') this.shopId,
      @JsonKey(name: 'shopName') this.shopName,
      @JsonKey(name: 'optionLabel') this.optionLabel,
      @JsonKey(name: 'familyName') this.familyName,
      @JsonKey(name: 'foodType') this.foodType,
      @JsonKey(name: 'originTag') this.originTag,
      @JsonKey(name: 'displayDeliveryMinutes') this.displayDeliveryMinutes,
      @JsonKey(name: 'categoryId') this.categoryId,
      @JsonKey(name: 'isAvailable', fromJson: _cartBoolFromJson)
      this.isAvailable = true,
      @JsonKey(name: 'stockQuantity', fromJson: _cartStockFromJson)
      this.stockQuantity = 9999,
      @JsonKey(name: 'bulkMinQuantity') this.bulkMinQuantity,
      @JsonKey(name: 'bulkMaxQuantity') this.bulkMaxQuantity})
      : super._();
  factory _CartItemModel.fromJson(Map<String, dynamic> json) =>
      _$CartItemModelFromJson(json);

  @override
  final String productId;
  @override
  final String name;
  @override
  @JsonKey(fromJson: _cartDoubleFromJson)
  final double price;
  @override
  final int quantity;
  @override
  @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson)
  final double total;
  @override
  @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
  final double? salePrice;
  @override
  final String? unit;
  @override
  @JsonKey(name: 'netQuantity')
  final String? netQuantity;
  @override
  final String? thumbnailUrl;
  @override
  @JsonKey(name: 'shopProductId')
  final String? shopProductId;
  @override
  @JsonKey(name: 'shopId')
  final String? shopId;
  @override
  @JsonKey(name: 'shopName')
  final String? shopName;
  @override
  @JsonKey(name: 'optionLabel')
  final String? optionLabel;
  @override
  @JsonKey(name: 'familyName')
  final String? familyName;
  @override
  @JsonKey(name: 'foodType')
  final String? foodType;
  @override
  @JsonKey(name: 'originTag')
  final String? originTag;
  @override
  @JsonKey(name: 'displayDeliveryMinutes')
  final int? displayDeliveryMinutes;
  @override
  @JsonKey(name: 'categoryId')
  final String? categoryId;
  @override
  @JsonKey(name: 'isAvailable', fromJson: _cartBoolFromJson)
  final bool isAvailable;
  @override
  @JsonKey(name: 'stockQuantity', fromJson: _cartStockFromJson)
  final int stockQuantity;
  @override
  @JsonKey(name: 'bulkMinQuantity')
  final int? bulkMinQuantity;
  @override
  @JsonKey(name: 'bulkMaxQuantity')
  final int? bulkMaxQuantity;

  /// Create a copy of CartItemModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CartItemModelCopyWith<_CartItemModel> get copyWith =>
      __$CartItemModelCopyWithImpl<_CartItemModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CartItemModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CartItemModel &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
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
    return 'CartItemModel(productId: $productId, name: $name, price: $price, quantity: $quantity, total: $total, salePrice: $salePrice, unit: $unit, netQuantity: $netQuantity, thumbnailUrl: $thumbnailUrl, shopProductId: $shopProductId, shopId: $shopId, shopName: $shopName, optionLabel: $optionLabel, familyName: $familyName, foodType: $foodType, originTag: $originTag, displayDeliveryMinutes: $displayDeliveryMinutes, categoryId: $categoryId, isAvailable: $isAvailable, stockQuantity: $stockQuantity, bulkMinQuantity: $bulkMinQuantity, bulkMaxQuantity: $bulkMaxQuantity)';
  }
}

/// @nodoc
abstract mixin class _$CartItemModelCopyWith<$Res>
    implements $CartItemModelCopyWith<$Res> {
  factory _$CartItemModelCopyWith(
          _CartItemModel value, $Res Function(_CartItemModel) _then) =
      __$CartItemModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String productId,
      String name,
      @JsonKey(fromJson: _cartDoubleFromJson) double price,
      int quantity,
      @JsonKey(name: 'lineTotal', fromJson: _cartDoubleFromJson) double total,
      @JsonKey(name: 'salePrice', fromJson: _cartNullableDoubleFromJson)
      double? salePrice,
      String? unit,
      @JsonKey(name: 'netQuantity') String? netQuantity,
      String? thumbnailUrl,
      @JsonKey(name: 'shopProductId') String? shopProductId,
      @JsonKey(name: 'shopId') String? shopId,
      @JsonKey(name: 'shopName') String? shopName,
      @JsonKey(name: 'optionLabel') String? optionLabel,
      @JsonKey(name: 'familyName') String? familyName,
      @JsonKey(name: 'foodType') String? foodType,
      @JsonKey(name: 'originTag') String? originTag,
      @JsonKey(name: 'displayDeliveryMinutes') int? displayDeliveryMinutes,
      @JsonKey(name: 'categoryId') String? categoryId,
      @JsonKey(name: 'isAvailable', fromJson: _cartBoolFromJson)
      bool isAvailable,
      @JsonKey(name: 'stockQuantity', fromJson: _cartStockFromJson)
      int stockQuantity,
      @JsonKey(name: 'bulkMinQuantity') int? bulkMinQuantity,
      @JsonKey(name: 'bulkMaxQuantity') int? bulkMaxQuantity});
}

/// @nodoc
class __$CartItemModelCopyWithImpl<$Res>
    implements _$CartItemModelCopyWith<$Res> {
  __$CartItemModelCopyWithImpl(this._self, this._then);

  final _CartItemModel _self;
  final $Res Function(_CartItemModel) _then;

  /// Create a copy of CartItemModel
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
    return _then(_CartItemModel(
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
