// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_item_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrderItemEntity {
  String get productId;
  String get name;
  double get price;
  int get quantity;
  String get unit;
  double get total;
  String? get thumbnailUrl;
  String?
      get brand; // Captured at checkout; null when the item had no real list price.
  double? get originalPrice;
  int get discountPercent;

  /// Create a copy of OrderItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $OrderItemEntityCopyWith<OrderItemEntity> get copyWith =>
      _$OrderItemEntityCopyWithImpl<OrderItemEntity>(
          this as OrderItemEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is OrderItemEntity &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.brand, brand) || other.brand == brand) &&
            (identical(other.originalPrice, originalPrice) ||
                other.originalPrice == originalPrice) &&
            (identical(other.discountPercent, discountPercent) ||
                other.discountPercent == discountPercent));
  }

  @override
  int get hashCode => Object.hash(runtimeType, productId, name, price, quantity,
      unit, total, thumbnailUrl, brand, originalPrice, discountPercent);

  @override
  String toString() {
    return 'OrderItemEntity(productId: $productId, name: $name, price: $price, quantity: $quantity, unit: $unit, total: $total, thumbnailUrl: $thumbnailUrl, brand: $brand, originalPrice: $originalPrice, discountPercent: $discountPercent)';
  }
}

/// @nodoc
abstract mixin class $OrderItemEntityCopyWith<$Res> {
  factory $OrderItemEntityCopyWith(
          OrderItemEntity value, $Res Function(OrderItemEntity) _then) =
      _$OrderItemEntityCopyWithImpl;
  @useResult
  $Res call(
      {String productId,
      String name,
      double price,
      int quantity,
      String unit,
      double total,
      String? thumbnailUrl,
      String? brand,
      double? originalPrice,
      int discountPercent});
}

/// @nodoc
class _$OrderItemEntityCopyWithImpl<$Res>
    implements $OrderItemEntityCopyWith<$Res> {
  _$OrderItemEntityCopyWithImpl(this._self, this._then);

  final OrderItemEntity _self;
  final $Res Function(OrderItemEntity) _then;

  /// Create a copy of OrderItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? name = null,
    Object? price = null,
    Object? quantity = null,
    Object? unit = null,
    Object? total = null,
    Object? thumbnailUrl = freezed,
    Object? brand = freezed,
    Object? originalPrice = freezed,
    Object? discountPercent = null,
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
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      brand: freezed == brand
          ? _self.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String?,
      originalPrice: freezed == originalPrice
          ? _self.originalPrice
          : originalPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      discountPercent: null == discountPercent
          ? _self.discountPercent
          : discountPercent // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [OrderItemEntity].
extension OrderItemEntityPatterns on OrderItemEntity {
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
    TResult Function(_OrderItemEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OrderItemEntity() when $default != null:
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
    TResult Function(_OrderItemEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderItemEntity():
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
    TResult? Function(_OrderItemEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderItemEntity() when $default != null:
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
            String unit,
            double total,
            String? thumbnailUrl,
            String? brand,
            double? originalPrice,
            int discountPercent)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OrderItemEntity() when $default != null:
        return $default(
            _that.productId,
            _that.name,
            _that.price,
            _that.quantity,
            _that.unit,
            _that.total,
            _that.thumbnailUrl,
            _that.brand,
            _that.originalPrice,
            _that.discountPercent);
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
            String unit,
            double total,
            String? thumbnailUrl,
            String? brand,
            double? originalPrice,
            int discountPercent)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderItemEntity():
        return $default(
            _that.productId,
            _that.name,
            _that.price,
            _that.quantity,
            _that.unit,
            _that.total,
            _that.thumbnailUrl,
            _that.brand,
            _that.originalPrice,
            _that.discountPercent);
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
            String unit,
            double total,
            String? thumbnailUrl,
            String? brand,
            double? originalPrice,
            int discountPercent)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderItemEntity() when $default != null:
        return $default(
            _that.productId,
            _that.name,
            _that.price,
            _that.quantity,
            _that.unit,
            _that.total,
            _that.thumbnailUrl,
            _that.brand,
            _that.originalPrice,
            _that.discountPercent);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _OrderItemEntity implements OrderItemEntity {
  const _OrderItemEntity(
      {required this.productId,
      required this.name,
      required this.price,
      required this.quantity,
      required this.unit,
      required this.total,
      this.thumbnailUrl,
      this.brand,
      this.originalPrice,
      this.discountPercent = 0});

  @override
  final String productId;
  @override
  final String name;
  @override
  final double price;
  @override
  final int quantity;
  @override
  final String unit;
  @override
  final double total;
  @override
  final String? thumbnailUrl;
  @override
  final String? brand;
// Captured at checkout; null when the item had no real list price.
  @override
  final double? originalPrice;
  @override
  @JsonKey()
  final int discountPercent;

  /// Create a copy of OrderItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$OrderItemEntityCopyWith<_OrderItemEntity> get copyWith =>
      __$OrderItemEntityCopyWithImpl<_OrderItemEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _OrderItemEntity &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.price, price) || other.price == price) &&
            (identical(other.quantity, quantity) ||
                other.quantity == quantity) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.thumbnailUrl, thumbnailUrl) ||
                other.thumbnailUrl == thumbnailUrl) &&
            (identical(other.brand, brand) || other.brand == brand) &&
            (identical(other.originalPrice, originalPrice) ||
                other.originalPrice == originalPrice) &&
            (identical(other.discountPercent, discountPercent) ||
                other.discountPercent == discountPercent));
  }

  @override
  int get hashCode => Object.hash(runtimeType, productId, name, price, quantity,
      unit, total, thumbnailUrl, brand, originalPrice, discountPercent);

  @override
  String toString() {
    return 'OrderItemEntity(productId: $productId, name: $name, price: $price, quantity: $quantity, unit: $unit, total: $total, thumbnailUrl: $thumbnailUrl, brand: $brand, originalPrice: $originalPrice, discountPercent: $discountPercent)';
  }
}

/// @nodoc
abstract mixin class _$OrderItemEntityCopyWith<$Res>
    implements $OrderItemEntityCopyWith<$Res> {
  factory _$OrderItemEntityCopyWith(
          _OrderItemEntity value, $Res Function(_OrderItemEntity) _then) =
      __$OrderItemEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String productId,
      String name,
      double price,
      int quantity,
      String unit,
      double total,
      String? thumbnailUrl,
      String? brand,
      double? originalPrice,
      int discountPercent});
}

/// @nodoc
class __$OrderItemEntityCopyWithImpl<$Res>
    implements _$OrderItemEntityCopyWith<$Res> {
  __$OrderItemEntityCopyWithImpl(this._self, this._then);

  final _OrderItemEntity _self;
  final $Res Function(_OrderItemEntity) _then;

  /// Create a copy of OrderItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? productId = null,
    Object? name = null,
    Object? price = null,
    Object? quantity = null,
    Object? unit = null,
    Object? total = null,
    Object? thumbnailUrl = freezed,
    Object? brand = freezed,
    Object? originalPrice = freezed,
    Object? discountPercent = null,
  }) {
    return _then(_OrderItemEntity(
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
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      thumbnailUrl: freezed == thumbnailUrl
          ? _self.thumbnailUrl
          : thumbnailUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      brand: freezed == brand
          ? _self.brand
          : brand // ignore: cast_nullable_to_non_nullable
              as String?,
      originalPrice: freezed == originalPrice
          ? _self.originalPrice
          : originalPrice // ignore: cast_nullable_to_non_nullable
              as double?,
      discountPercent: null == discountPercent
          ? _self.discountPercent
          : discountPercent // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
