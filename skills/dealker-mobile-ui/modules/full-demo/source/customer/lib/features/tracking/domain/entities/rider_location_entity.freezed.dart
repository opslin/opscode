// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'rider_location_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RiderLocationEntity {
  String get orderId;
  double get latitude;
  double get longitude;
  DateTime get updatedAt;
  double? get bearing;
  double? get speed;

  /// Create a copy of RiderLocationEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RiderLocationEntityCopyWith<RiderLocationEntity> get copyWith =>
      _$RiderLocationEntityCopyWithImpl<RiderLocationEntity>(
          this as RiderLocationEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RiderLocationEntity &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.bearing, bearing) || other.bearing == bearing) &&
            (identical(other.speed, speed) || other.speed == speed));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, orderId, latitude, longitude, updatedAt, bearing, speed);

  @override
  String toString() {
    return 'RiderLocationEntity(orderId: $orderId, latitude: $latitude, longitude: $longitude, updatedAt: $updatedAt, bearing: $bearing, speed: $speed)';
  }
}

/// @nodoc
abstract mixin class $RiderLocationEntityCopyWith<$Res> {
  factory $RiderLocationEntityCopyWith(
          RiderLocationEntity value, $Res Function(RiderLocationEntity) _then) =
      _$RiderLocationEntityCopyWithImpl;
  @useResult
  $Res call(
      {String orderId,
      double latitude,
      double longitude,
      DateTime updatedAt,
      double? bearing,
      double? speed});
}

/// @nodoc
class _$RiderLocationEntityCopyWithImpl<$Res>
    implements $RiderLocationEntityCopyWith<$Res> {
  _$RiderLocationEntityCopyWithImpl(this._self, this._then);

  final RiderLocationEntity _self;
  final $Res Function(RiderLocationEntity) _then;

  /// Create a copy of RiderLocationEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? orderId = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? updatedAt = null,
    Object? bearing = freezed,
    Object? speed = freezed,
  }) {
    return _then(_self.copyWith(
      orderId: null == orderId
          ? _self.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      bearing: freezed == bearing
          ? _self.bearing
          : bearing // ignore: cast_nullable_to_non_nullable
              as double?,
      speed: freezed == speed
          ? _self.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

/// Adds pattern-matching-related methods to [RiderLocationEntity].
extension RiderLocationEntityPatterns on RiderLocationEntity {
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
    TResult Function(_RiderLocationEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RiderLocationEntity() when $default != null:
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
    TResult Function(_RiderLocationEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RiderLocationEntity():
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
    TResult? Function(_RiderLocationEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RiderLocationEntity() when $default != null:
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
    TResult Function(String orderId, double latitude, double longitude,
            DateTime updatedAt, double? bearing, double? speed)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RiderLocationEntity() when $default != null:
        return $default(_that.orderId, _that.latitude, _that.longitude,
            _that.updatedAt, _that.bearing, _that.speed);
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
    TResult Function(String orderId, double latitude, double longitude,
            DateTime updatedAt, double? bearing, double? speed)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RiderLocationEntity():
        return $default(_that.orderId, _that.latitude, _that.longitude,
            _that.updatedAt, _that.bearing, _that.speed);
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
    TResult? Function(String orderId, double latitude, double longitude,
            DateTime updatedAt, double? bearing, double? speed)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RiderLocationEntity() when $default != null:
        return $default(_that.orderId, _that.latitude, _that.longitude,
            _that.updatedAt, _that.bearing, _that.speed);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _RiderLocationEntity implements RiderLocationEntity {
  const _RiderLocationEntity(
      {required this.orderId,
      required this.latitude,
      required this.longitude,
      required this.updatedAt,
      this.bearing,
      this.speed});

  @override
  final String orderId;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final DateTime updatedAt;
  @override
  final double? bearing;
  @override
  final double? speed;

  /// Create a copy of RiderLocationEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RiderLocationEntityCopyWith<_RiderLocationEntity> get copyWith =>
      __$RiderLocationEntityCopyWithImpl<_RiderLocationEntity>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RiderLocationEntity &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.updatedAt, updatedAt) ||
                other.updatedAt == updatedAt) &&
            (identical(other.bearing, bearing) || other.bearing == bearing) &&
            (identical(other.speed, speed) || other.speed == speed));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, orderId, latitude, longitude, updatedAt, bearing, speed);

  @override
  String toString() {
    return 'RiderLocationEntity(orderId: $orderId, latitude: $latitude, longitude: $longitude, updatedAt: $updatedAt, bearing: $bearing, speed: $speed)';
  }
}

/// @nodoc
abstract mixin class _$RiderLocationEntityCopyWith<$Res>
    implements $RiderLocationEntityCopyWith<$Res> {
  factory _$RiderLocationEntityCopyWith(_RiderLocationEntity value,
          $Res Function(_RiderLocationEntity) _then) =
      __$RiderLocationEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String orderId,
      double latitude,
      double longitude,
      DateTime updatedAt,
      double? bearing,
      double? speed});
}

/// @nodoc
class __$RiderLocationEntityCopyWithImpl<$Res>
    implements _$RiderLocationEntityCopyWith<$Res> {
  __$RiderLocationEntityCopyWithImpl(this._self, this._then);

  final _RiderLocationEntity _self;
  final $Res Function(_RiderLocationEntity) _then;

  /// Create a copy of RiderLocationEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? orderId = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? updatedAt = null,
    Object? bearing = freezed,
    Object? speed = freezed,
  }) {
    return _then(_RiderLocationEntity(
      orderId: null == orderId
          ? _self.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      updatedAt: null == updatedAt
          ? _self.updatedAt
          : updatedAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      bearing: freezed == bearing
          ? _self.bearing
          : bearing // ignore: cast_nullable_to_non_nullable
              as double?,
      speed: freezed == speed
          ? _self.speed
          : speed // ignore: cast_nullable_to_non_nullable
              as double?,
    ));
  }
}

// dart format on
