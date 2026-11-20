// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'review_eligibility_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReviewEligibilityEntity {
  bool get canReview;
  String? get reason;
  String? get orderId;

  /// Create a copy of ReviewEligibilityEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ReviewEligibilityEntityCopyWith<ReviewEligibilityEntity> get copyWith =>
      _$ReviewEligibilityEntityCopyWithImpl<ReviewEligibilityEntity>(
          this as ReviewEligibilityEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ReviewEligibilityEntity &&
            (identical(other.canReview, canReview) ||
                other.canReview == canReview) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.orderId, orderId) || other.orderId == orderId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, canReview, reason, orderId);

  @override
  String toString() {
    return 'ReviewEligibilityEntity(canReview: $canReview, reason: $reason, orderId: $orderId)';
  }
}

/// @nodoc
abstract mixin class $ReviewEligibilityEntityCopyWith<$Res> {
  factory $ReviewEligibilityEntityCopyWith(ReviewEligibilityEntity value,
          $Res Function(ReviewEligibilityEntity) _then) =
      _$ReviewEligibilityEntityCopyWithImpl;
  @useResult
  $Res call({bool canReview, String? reason, String? orderId});
}

/// @nodoc
class _$ReviewEligibilityEntityCopyWithImpl<$Res>
    implements $ReviewEligibilityEntityCopyWith<$Res> {
  _$ReviewEligibilityEntityCopyWithImpl(this._self, this._then);

  final ReviewEligibilityEntity _self;
  final $Res Function(ReviewEligibilityEntity) _then;

  /// Create a copy of ReviewEligibilityEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? canReview = null,
    Object? reason = freezed,
    Object? orderId = freezed,
  }) {
    return _then(_self.copyWith(
      canReview: null == canReview
          ? _self.canReview
          : canReview // ignore: cast_nullable_to_non_nullable
              as bool,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      orderId: freezed == orderId
          ? _self.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [ReviewEligibilityEntity].
extension ReviewEligibilityEntityPatterns on ReviewEligibilityEntity {
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
    TResult Function(_ReviewEligibilityEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReviewEligibilityEntity() when $default != null:
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
    TResult Function(_ReviewEligibilityEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReviewEligibilityEntity():
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
    TResult? Function(_ReviewEligibilityEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReviewEligibilityEntity() when $default != null:
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
    TResult Function(bool canReview, String? reason, String? orderId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ReviewEligibilityEntity() when $default != null:
        return $default(_that.canReview, _that.reason, _that.orderId);
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
    TResult Function(bool canReview, String? reason, String? orderId) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReviewEligibilityEntity():
        return $default(_that.canReview, _that.reason, _that.orderId);
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
    TResult? Function(bool canReview, String? reason, String? orderId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ReviewEligibilityEntity() when $default != null:
        return $default(_that.canReview, _that.reason, _that.orderId);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _ReviewEligibilityEntity implements ReviewEligibilityEntity {
  const _ReviewEligibilityEntity(
      {required this.canReview, this.reason, this.orderId});

  @override
  final bool canReview;
  @override
  final String? reason;
  @override
  final String? orderId;

  /// Create a copy of ReviewEligibilityEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ReviewEligibilityEntityCopyWith<_ReviewEligibilityEntity> get copyWith =>
      __$ReviewEligibilityEntityCopyWithImpl<_ReviewEligibilityEntity>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ReviewEligibilityEntity &&
            (identical(other.canReview, canReview) ||
                other.canReview == canReview) &&
            (identical(other.reason, reason) || other.reason == reason) &&
            (identical(other.orderId, orderId) || other.orderId == orderId));
  }

  @override
  int get hashCode => Object.hash(runtimeType, canReview, reason, orderId);

  @override
  String toString() {
    return 'ReviewEligibilityEntity(canReview: $canReview, reason: $reason, orderId: $orderId)';
  }
}

/// @nodoc
abstract mixin class _$ReviewEligibilityEntityCopyWith<$Res>
    implements $ReviewEligibilityEntityCopyWith<$Res> {
  factory _$ReviewEligibilityEntityCopyWith(_ReviewEligibilityEntity value,
          $Res Function(_ReviewEligibilityEntity) _then) =
      __$ReviewEligibilityEntityCopyWithImpl;
  @override
  @useResult
  $Res call({bool canReview, String? reason, String? orderId});
}

/// @nodoc
class __$ReviewEligibilityEntityCopyWithImpl<$Res>
    implements _$ReviewEligibilityEntityCopyWith<$Res> {
  __$ReviewEligibilityEntityCopyWithImpl(this._self, this._then);

  final _ReviewEligibilityEntity _self;
  final $Res Function(_ReviewEligibilityEntity) _then;

  /// Create a copy of ReviewEligibilityEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? canReview = null,
    Object? reason = freezed,
    Object? orderId = freezed,
  }) {
    return _then(_ReviewEligibilityEntity(
      canReview: null == canReview
          ? _self.canReview
          : canReview // ignore: cast_nullable_to_non_nullable
              as bool,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
      orderId: freezed == orderId
          ? _self.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
