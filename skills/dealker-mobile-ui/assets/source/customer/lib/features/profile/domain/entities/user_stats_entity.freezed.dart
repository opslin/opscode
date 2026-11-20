// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_stats_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserStatsEntity {
  int get totalOrders;
  double get totalSpent;
  int get loyaltyPoints;

  /// Create a copy of UserStatsEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserStatsEntityCopyWith<UserStatsEntity> get copyWith =>
      _$UserStatsEntityCopyWithImpl<UserStatsEntity>(
          this as UserStatsEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserStatsEntity &&
            (identical(other.totalOrders, totalOrders) ||
                other.totalOrders == totalOrders) &&
            (identical(other.totalSpent, totalSpent) ||
                other.totalSpent == totalSpent) &&
            (identical(other.loyaltyPoints, loyaltyPoints) ||
                other.loyaltyPoints == loyaltyPoints));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, totalOrders, totalSpent, loyaltyPoints);

  @override
  String toString() {
    return 'UserStatsEntity(totalOrders: $totalOrders, totalSpent: $totalSpent, loyaltyPoints: $loyaltyPoints)';
  }
}

/// @nodoc
abstract mixin class $UserStatsEntityCopyWith<$Res> {
  factory $UserStatsEntityCopyWith(
          UserStatsEntity value, $Res Function(UserStatsEntity) _then) =
      _$UserStatsEntityCopyWithImpl;
  @useResult
  $Res call({int totalOrders, double totalSpent, int loyaltyPoints});
}

/// @nodoc
class _$UserStatsEntityCopyWithImpl<$Res>
    implements $UserStatsEntityCopyWith<$Res> {
  _$UserStatsEntityCopyWithImpl(this._self, this._then);

  final UserStatsEntity _self;
  final $Res Function(UserStatsEntity) _then;

  /// Create a copy of UserStatsEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalOrders = null,
    Object? totalSpent = null,
    Object? loyaltyPoints = null,
  }) {
    return _then(_self.copyWith(
      totalOrders: null == totalOrders
          ? _self.totalOrders
          : totalOrders // ignore: cast_nullable_to_non_nullable
              as int,
      totalSpent: null == totalSpent
          ? _self.totalSpent
          : totalSpent // ignore: cast_nullable_to_non_nullable
              as double,
      loyaltyPoints: null == loyaltyPoints
          ? _self.loyaltyPoints
          : loyaltyPoints // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [UserStatsEntity].
extension UserStatsEntityPatterns on UserStatsEntity {
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
    TResult Function(_UserStatsEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserStatsEntity() when $default != null:
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
    TResult Function(_UserStatsEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserStatsEntity():
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
    TResult? Function(_UserStatsEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserStatsEntity() when $default != null:
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
    TResult Function(int totalOrders, double totalSpent, int loyaltyPoints)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserStatsEntity() when $default != null:
        return $default(
            _that.totalOrders, _that.totalSpent, _that.loyaltyPoints);
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
    TResult Function(int totalOrders, double totalSpent, int loyaltyPoints)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserStatsEntity():
        return $default(
            _that.totalOrders, _that.totalSpent, _that.loyaltyPoints);
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
    TResult? Function(int totalOrders, double totalSpent, int loyaltyPoints)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserStatsEntity() when $default != null:
        return $default(
            _that.totalOrders, _that.totalSpent, _that.loyaltyPoints);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _UserStatsEntity implements UserStatsEntity {
  const _UserStatsEntity(
      {this.totalOrders = 0, this.totalSpent = 0, this.loyaltyPoints = 0});

  @override
  @JsonKey()
  final int totalOrders;
  @override
  @JsonKey()
  final double totalSpent;
  @override
  @JsonKey()
  final int loyaltyPoints;

  /// Create a copy of UserStatsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserStatsEntityCopyWith<_UserStatsEntity> get copyWith =>
      __$UserStatsEntityCopyWithImpl<_UserStatsEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserStatsEntity &&
            (identical(other.totalOrders, totalOrders) ||
                other.totalOrders == totalOrders) &&
            (identical(other.totalSpent, totalSpent) ||
                other.totalSpent == totalSpent) &&
            (identical(other.loyaltyPoints, loyaltyPoints) ||
                other.loyaltyPoints == loyaltyPoints));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, totalOrders, totalSpent, loyaltyPoints);

  @override
  String toString() {
    return 'UserStatsEntity(totalOrders: $totalOrders, totalSpent: $totalSpent, loyaltyPoints: $loyaltyPoints)';
  }
}

/// @nodoc
abstract mixin class _$UserStatsEntityCopyWith<$Res>
    implements $UserStatsEntityCopyWith<$Res> {
  factory _$UserStatsEntityCopyWith(
          _UserStatsEntity value, $Res Function(_UserStatsEntity) _then) =
      __$UserStatsEntityCopyWithImpl;
  @override
  @useResult
  $Res call({int totalOrders, double totalSpent, int loyaltyPoints});
}

/// @nodoc
class __$UserStatsEntityCopyWithImpl<$Res>
    implements _$UserStatsEntityCopyWith<$Res> {
  __$UserStatsEntityCopyWithImpl(this._self, this._then);

  final _UserStatsEntity _self;
  final $Res Function(_UserStatsEntity) _then;

  /// Create a copy of UserStatsEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? totalOrders = null,
    Object? totalSpent = null,
    Object? loyaltyPoints = null,
  }) {
    return _then(_UserStatsEntity(
      totalOrders: null == totalOrders
          ? _self.totalOrders
          : totalOrders // ignore: cast_nullable_to_non_nullable
              as int,
      totalSpent: null == totalSpent
          ? _self.totalSpent
          : totalSpent // ignore: cast_nullable_to_non_nullable
              as double,
      loyaltyPoints: null == loyaltyPoints
          ? _self.loyaltyPoints
          : loyaltyPoints // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
