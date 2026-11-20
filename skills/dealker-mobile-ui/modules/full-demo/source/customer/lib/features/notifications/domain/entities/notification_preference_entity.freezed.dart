// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_preference_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationPreferenceEntity {
  bool get orderUpdates;
  bool get promotions;
  bool get newProducts;
  bool get priceDrops;
  bool get deliveryUpdates;

  /// Create a copy of NotificationPreferenceEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NotificationPreferenceEntityCopyWith<NotificationPreferenceEntity>
      get copyWith => _$NotificationPreferenceEntityCopyWithImpl<
              NotificationPreferenceEntity>(
          this as NotificationPreferenceEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NotificationPreferenceEntity &&
            (identical(other.orderUpdates, orderUpdates) ||
                other.orderUpdates == orderUpdates) &&
            (identical(other.promotions, promotions) ||
                other.promotions == promotions) &&
            (identical(other.newProducts, newProducts) ||
                other.newProducts == newProducts) &&
            (identical(other.priceDrops, priceDrops) ||
                other.priceDrops == priceDrops) &&
            (identical(other.deliveryUpdates, deliveryUpdates) ||
                other.deliveryUpdates == deliveryUpdates));
  }

  @override
  int get hashCode => Object.hash(runtimeType, orderUpdates, promotions,
      newProducts, priceDrops, deliveryUpdates);

  @override
  String toString() {
    return 'NotificationPreferenceEntity(orderUpdates: $orderUpdates, promotions: $promotions, newProducts: $newProducts, priceDrops: $priceDrops, deliveryUpdates: $deliveryUpdates)';
  }
}

/// @nodoc
abstract mixin class $NotificationPreferenceEntityCopyWith<$Res> {
  factory $NotificationPreferenceEntityCopyWith(
          NotificationPreferenceEntity value,
          $Res Function(NotificationPreferenceEntity) _then) =
      _$NotificationPreferenceEntityCopyWithImpl;
  @useResult
  $Res call(
      {bool orderUpdates,
      bool promotions,
      bool newProducts,
      bool priceDrops,
      bool deliveryUpdates});
}

/// @nodoc
class _$NotificationPreferenceEntityCopyWithImpl<$Res>
    implements $NotificationPreferenceEntityCopyWith<$Res> {
  _$NotificationPreferenceEntityCopyWithImpl(this._self, this._then);

  final NotificationPreferenceEntity _self;
  final $Res Function(NotificationPreferenceEntity) _then;

  /// Create a copy of NotificationPreferenceEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderUpdates = null,
    Object? promotions = null,
    Object? newProducts = null,
    Object? priceDrops = null,
    Object? deliveryUpdates = null,
  }) {
    return _then(_self.copyWith(
      orderUpdates: null == orderUpdates
          ? _self.orderUpdates
          : orderUpdates // ignore: cast_nullable_to_non_nullable
              as bool,
      promotions: null == promotions
          ? _self.promotions
          : promotions // ignore: cast_nullable_to_non_nullable
              as bool,
      newProducts: null == newProducts
          ? _self.newProducts
          : newProducts // ignore: cast_nullable_to_non_nullable
              as bool,
      priceDrops: null == priceDrops
          ? _self.priceDrops
          : priceDrops // ignore: cast_nullable_to_non_nullable
              as bool,
      deliveryUpdates: null == deliveryUpdates
          ? _self.deliveryUpdates
          : deliveryUpdates // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [NotificationPreferenceEntity].
extension NotificationPreferenceEntityPatterns on NotificationPreferenceEntity {
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
    TResult Function(_NotificationPreferenceEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NotificationPreferenceEntity() when $default != null:
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
    TResult Function(_NotificationPreferenceEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationPreferenceEntity():
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
    TResult? Function(_NotificationPreferenceEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationPreferenceEntity() when $default != null:
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
    TResult Function(bool orderUpdates, bool promotions, bool newProducts,
            bool priceDrops, bool deliveryUpdates)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NotificationPreferenceEntity() when $default != null:
        return $default(_that.orderUpdates, _that.promotions, _that.newProducts,
            _that.priceDrops, _that.deliveryUpdates);
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
    TResult Function(bool orderUpdates, bool promotions, bool newProducts,
            bool priceDrops, bool deliveryUpdates)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationPreferenceEntity():
        return $default(_that.orderUpdates, _that.promotions, _that.newProducts,
            _that.priceDrops, _that.deliveryUpdates);
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
    TResult? Function(bool orderUpdates, bool promotions, bool newProducts,
            bool priceDrops, bool deliveryUpdates)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationPreferenceEntity() when $default != null:
        return $default(_that.orderUpdates, _that.promotions, _that.newProducts,
            _that.priceDrops, _that.deliveryUpdates);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _NotificationPreferenceEntity implements NotificationPreferenceEntity {
  const _NotificationPreferenceEntity(
      {this.orderUpdates = true,
      this.promotions = true,
      this.newProducts = true,
      this.priceDrops = true,
      this.deliveryUpdates = true});

  @override
  @JsonKey()
  final bool orderUpdates;
  @override
  @JsonKey()
  final bool promotions;
  @override
  @JsonKey()
  final bool newProducts;
  @override
  @JsonKey()
  final bool priceDrops;
  @override
  @JsonKey()
  final bool deliveryUpdates;

  /// Create a copy of NotificationPreferenceEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NotificationPreferenceEntityCopyWith<_NotificationPreferenceEntity>
      get copyWith => __$NotificationPreferenceEntityCopyWithImpl<
          _NotificationPreferenceEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NotificationPreferenceEntity &&
            (identical(other.orderUpdates, orderUpdates) ||
                other.orderUpdates == orderUpdates) &&
            (identical(other.promotions, promotions) ||
                other.promotions == promotions) &&
            (identical(other.newProducts, newProducts) ||
                other.newProducts == newProducts) &&
            (identical(other.priceDrops, priceDrops) ||
                other.priceDrops == priceDrops) &&
            (identical(other.deliveryUpdates, deliveryUpdates) ||
                other.deliveryUpdates == deliveryUpdates));
  }

  @override
  int get hashCode => Object.hash(runtimeType, orderUpdates, promotions,
      newProducts, priceDrops, deliveryUpdates);

  @override
  String toString() {
    return 'NotificationPreferenceEntity(orderUpdates: $orderUpdates, promotions: $promotions, newProducts: $newProducts, priceDrops: $priceDrops, deliveryUpdates: $deliveryUpdates)';
  }
}

/// @nodoc
abstract mixin class _$NotificationPreferenceEntityCopyWith<$Res>
    implements $NotificationPreferenceEntityCopyWith<$Res> {
  factory _$NotificationPreferenceEntityCopyWith(
          _NotificationPreferenceEntity value,
          $Res Function(_NotificationPreferenceEntity) _then) =
      __$NotificationPreferenceEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool orderUpdates,
      bool promotions,
      bool newProducts,
      bool priceDrops,
      bool deliveryUpdates});
}

/// @nodoc
class __$NotificationPreferenceEntityCopyWithImpl<$Res>
    implements _$NotificationPreferenceEntityCopyWith<$Res> {
  __$NotificationPreferenceEntityCopyWithImpl(this._self, this._then);

  final _NotificationPreferenceEntity _self;
  final $Res Function(_NotificationPreferenceEntity) _then;

  /// Create a copy of NotificationPreferenceEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? orderUpdates = null,
    Object? promotions = null,
    Object? newProducts = null,
    Object? priceDrops = null,
    Object? deliveryUpdates = null,
  }) {
    return _then(_NotificationPreferenceEntity(
      orderUpdates: null == orderUpdates
          ? _self.orderUpdates
          : orderUpdates // ignore: cast_nullable_to_non_nullable
              as bool,
      promotions: null == promotions
          ? _self.promotions
          : promotions // ignore: cast_nullable_to_non_nullable
              as bool,
      newProducts: null == newProducts
          ? _self.newProducts
          : newProducts // ignore: cast_nullable_to_non_nullable
              as bool,
      priceDrops: null == priceDrops
          ? _self.priceDrops
          : priceDrops // ignore: cast_nullable_to_non_nullable
              as bool,
      deliveryUpdates: null == deliveryUpdates
          ? _self.deliveryUpdates
          : deliveryUpdates // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
