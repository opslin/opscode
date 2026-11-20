// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wishlist_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WishlistItemEntity {
  String get productId;
  ProductEntity get product;
  DateTime? get addedAt;

  /// Create a copy of WishlistItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WishlistItemEntityCopyWith<WishlistItemEntity> get copyWith =>
      _$WishlistItemEntityCopyWithImpl<WishlistItemEntity>(
          this as WishlistItemEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WishlistItemEntity &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.product, product) || other.product == product) &&
            (identical(other.addedAt, addedAt) || other.addedAt == addedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, productId, product, addedAt);

  @override
  String toString() {
    return 'WishlistItemEntity(productId: $productId, product: $product, addedAt: $addedAt)';
  }
}

/// @nodoc
abstract mixin class $WishlistItemEntityCopyWith<$Res> {
  factory $WishlistItemEntityCopyWith(
          WishlistItemEntity value, $Res Function(WishlistItemEntity) _then) =
      _$WishlistItemEntityCopyWithImpl;
  @useResult
  $Res call({String productId, ProductEntity product, DateTime? addedAt});

  $ProductEntityCopyWith<$Res> get product;
}

/// @nodoc
class _$WishlistItemEntityCopyWithImpl<$Res>
    implements $WishlistItemEntityCopyWith<$Res> {
  _$WishlistItemEntityCopyWithImpl(this._self, this._then);

  final WishlistItemEntity _self;
  final $Res Function(WishlistItemEntity) _then;

  /// Create a copy of WishlistItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? product = null,
    Object? addedAt = freezed,
  }) {
    return _then(_self.copyWith(
      productId: null == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      product: null == product
          ? _self.product
          : product // ignore: cast_nullable_to_non_nullable
              as ProductEntity,
      addedAt: freezed == addedAt
          ? _self.addedAt
          : addedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }

  /// Create a copy of WishlistItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProductEntityCopyWith<$Res> get product {
    return $ProductEntityCopyWith<$Res>(_self.product, (value) {
      return _then(_self.copyWith(product: value));
    });
  }
}

/// Adds pattern-matching-related methods to [WishlistItemEntity].
extension WishlistItemEntityPatterns on WishlistItemEntity {
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
    TResult Function(_WishlistItemEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WishlistItemEntity() when $default != null:
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
    TResult Function(_WishlistItemEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WishlistItemEntity():
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
    TResult? Function(_WishlistItemEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WishlistItemEntity() when $default != null:
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
            String productId, ProductEntity product, DateTime? addedAt)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WishlistItemEntity() when $default != null:
        return $default(_that.productId, _that.product, _that.addedAt);
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
    TResult Function(String productId, ProductEntity product, DateTime? addedAt)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WishlistItemEntity():
        return $default(_that.productId, _that.product, _that.addedAt);
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
            String productId, ProductEntity product, DateTime? addedAt)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WishlistItemEntity() when $default != null:
        return $default(_that.productId, _that.product, _that.addedAt);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _WishlistItemEntity implements WishlistItemEntity {
  const _WishlistItemEntity(
      {required this.productId, required this.product, this.addedAt});

  @override
  final String productId;
  @override
  final ProductEntity product;
  @override
  final DateTime? addedAt;

  /// Create a copy of WishlistItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WishlistItemEntityCopyWith<_WishlistItemEntity> get copyWith =>
      __$WishlistItemEntityCopyWithImpl<_WishlistItemEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WishlistItemEntity &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.product, product) || other.product == product) &&
            (identical(other.addedAt, addedAt) || other.addedAt == addedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, productId, product, addedAt);

  @override
  String toString() {
    return 'WishlistItemEntity(productId: $productId, product: $product, addedAt: $addedAt)';
  }
}

/// @nodoc
abstract mixin class _$WishlistItemEntityCopyWith<$Res>
    implements $WishlistItemEntityCopyWith<$Res> {
  factory _$WishlistItemEntityCopyWith(
          _WishlistItemEntity value, $Res Function(_WishlistItemEntity) _then) =
      __$WishlistItemEntityCopyWithImpl;
  @override
  @useResult
  $Res call({String productId, ProductEntity product, DateTime? addedAt});

  @override
  $ProductEntityCopyWith<$Res> get product;
}

/// @nodoc
class __$WishlistItemEntityCopyWithImpl<$Res>
    implements _$WishlistItemEntityCopyWith<$Res> {
  __$WishlistItemEntityCopyWithImpl(this._self, this._then);

  final _WishlistItemEntity _self;
  final $Res Function(_WishlistItemEntity) _then;

  /// Create a copy of WishlistItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? productId = null,
    Object? product = null,
    Object? addedAt = freezed,
  }) {
    return _then(_WishlistItemEntity(
      productId: null == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      product: null == product
          ? _self.product
          : product // ignore: cast_nullable_to_non_nullable
              as ProductEntity,
      addedAt: freezed == addedAt
          ? _self.addedAt
          : addedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }

  /// Create a copy of WishlistItemEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ProductEntityCopyWith<$Res> get product {
    return $ProductEntityCopyWith<$Res>(_self.product, (value) {
      return _then(_self.copyWith(product: value));
    });
  }
}

/// @nodoc
mixin _$WishlistEntity {
  List<WishlistItemEntity> get items;
  int get total;

  /// Create a copy of WishlistEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WishlistEntityCopyWith<WishlistEntity> get copyWith =>
      _$WishlistEntityCopyWithImpl<WishlistEntity>(
          this as WishlistEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WishlistEntity &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.total, total) || other.total == total));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(items), total);

  @override
  String toString() {
    return 'WishlistEntity(items: $items, total: $total)';
  }
}

/// @nodoc
abstract mixin class $WishlistEntityCopyWith<$Res> {
  factory $WishlistEntityCopyWith(
          WishlistEntity value, $Res Function(WishlistEntity) _then) =
      _$WishlistEntityCopyWithImpl;
  @useResult
  $Res call({List<WishlistItemEntity> items, int total});
}

/// @nodoc
class _$WishlistEntityCopyWithImpl<$Res>
    implements $WishlistEntityCopyWith<$Res> {
  _$WishlistEntityCopyWithImpl(this._self, this._then);

  final WishlistEntity _self;
  final $Res Function(WishlistEntity) _then;

  /// Create a copy of WishlistEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? items = null,
    Object? total = null,
  }) {
    return _then(_self.copyWith(
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<WishlistItemEntity>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [WishlistEntity].
extension WishlistEntityPatterns on WishlistEntity {
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
    TResult Function(_WishlistEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WishlistEntity() when $default != null:
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
    TResult Function(_WishlistEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WishlistEntity():
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
    TResult? Function(_WishlistEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WishlistEntity() when $default != null:
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
    TResult Function(List<WishlistItemEntity> items, int total)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WishlistEntity() when $default != null:
        return $default(_that.items, _that.total);
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
    TResult Function(List<WishlistItemEntity> items, int total) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WishlistEntity():
        return $default(_that.items, _that.total);
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
    TResult? Function(List<WishlistItemEntity> items, int total)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WishlistEntity() when $default != null:
        return $default(_that.items, _that.total);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _WishlistEntity extends WishlistEntity {
  const _WishlistEntity(
      {final List<WishlistItemEntity> items = const <WishlistItemEntity>[],
      this.total = 0})
      : _items = items,
        super._();

  final List<WishlistItemEntity> _items;
  @override
  @JsonKey()
  List<WishlistItemEntity> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  @JsonKey()
  final int total;

  /// Create a copy of WishlistEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WishlistEntityCopyWith<_WishlistEntity> get copyWith =>
      __$WishlistEntityCopyWithImpl<_WishlistEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WishlistEntity &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.total, total) || other.total == total));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_items), total);

  @override
  String toString() {
    return 'WishlistEntity(items: $items, total: $total)';
  }
}

/// @nodoc
abstract mixin class _$WishlistEntityCopyWith<$Res>
    implements $WishlistEntityCopyWith<$Res> {
  factory _$WishlistEntityCopyWith(
          _WishlistEntity value, $Res Function(_WishlistEntity) _then) =
      __$WishlistEntityCopyWithImpl;
  @override
  @useResult
  $Res call({List<WishlistItemEntity> items, int total});
}

/// @nodoc
class __$WishlistEntityCopyWithImpl<$Res>
    implements _$WishlistEntityCopyWith<$Res> {
  __$WishlistEntityCopyWithImpl(this._self, this._then);

  final _WishlistEntity _self;
  final $Res Function(_WishlistEntity) _then;

  /// Create a copy of WishlistEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? items = null,
    Object? total = null,
  }) {
    return _then(_WishlistEntity(
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<WishlistItemEntity>,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
