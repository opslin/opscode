// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'razorpay_order_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RazorpayOrderEntity {
  String get key;
  int get amount;
  String get razorpayOrderId;
  String get orderId;

  /// Create a copy of RazorpayOrderEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $RazorpayOrderEntityCopyWith<RazorpayOrderEntity> get copyWith =>
      _$RazorpayOrderEntityCopyWithImpl<RazorpayOrderEntity>(
          this as RazorpayOrderEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is RazorpayOrderEntity &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.razorpayOrderId, razorpayOrderId) ||
                other.razorpayOrderId == razorpayOrderId) &&
            (identical(other.orderId, orderId) || other.orderId == orderId));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, key, amount, razorpayOrderId, orderId);

  @override
  String toString() {
    return 'RazorpayOrderEntity(key: $key, amount: $amount, razorpayOrderId: $razorpayOrderId, orderId: $orderId)';
  }
}

/// @nodoc
abstract mixin class $RazorpayOrderEntityCopyWith<$Res> {
  factory $RazorpayOrderEntityCopyWith(
          RazorpayOrderEntity value, $Res Function(RazorpayOrderEntity) _then) =
      _$RazorpayOrderEntityCopyWithImpl;
  @useResult
  $Res call({String key, int amount, String razorpayOrderId, String orderId});
}

/// @nodoc
class _$RazorpayOrderEntityCopyWithImpl<$Res>
    implements $RazorpayOrderEntityCopyWith<$Res> {
  _$RazorpayOrderEntityCopyWithImpl(this._self, this._then);

  final RazorpayOrderEntity _self;
  final $Res Function(RazorpayOrderEntity) _then;

  /// Create a copy of RazorpayOrderEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? key = null,
    Object? amount = null,
    Object? razorpayOrderId = null,
    Object? orderId = null,
  }) {
    return _then(_self.copyWith(
      key: null == key
          ? _self.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      razorpayOrderId: null == razorpayOrderId
          ? _self.razorpayOrderId
          : razorpayOrderId // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: null == orderId
          ? _self.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [RazorpayOrderEntity].
extension RazorpayOrderEntityPatterns on RazorpayOrderEntity {
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
    TResult Function(_RazorpayOrderEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RazorpayOrderEntity() when $default != null:
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
    TResult Function(_RazorpayOrderEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RazorpayOrderEntity():
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
    TResult? Function(_RazorpayOrderEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RazorpayOrderEntity() when $default != null:
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
            String key, int amount, String razorpayOrderId, String orderId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _RazorpayOrderEntity() when $default != null:
        return $default(
            _that.key, _that.amount, _that.razorpayOrderId, _that.orderId);
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
            String key, int amount, String razorpayOrderId, String orderId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RazorpayOrderEntity():
        return $default(
            _that.key, _that.amount, _that.razorpayOrderId, _that.orderId);
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
            String key, int amount, String razorpayOrderId, String orderId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _RazorpayOrderEntity() when $default != null:
        return $default(
            _that.key, _that.amount, _that.razorpayOrderId, _that.orderId);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _RazorpayOrderEntity implements RazorpayOrderEntity {
  const _RazorpayOrderEntity(
      {required this.key,
      required this.amount,
      required this.razorpayOrderId,
      required this.orderId});

  @override
  final String key;
  @override
  final int amount;
  @override
  final String razorpayOrderId;
  @override
  final String orderId;

  /// Create a copy of RazorpayOrderEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$RazorpayOrderEntityCopyWith<_RazorpayOrderEntity> get copyWith =>
      __$RazorpayOrderEntityCopyWithImpl<_RazorpayOrderEntity>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _RazorpayOrderEntity &&
            (identical(other.key, key) || other.key == key) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.razorpayOrderId, razorpayOrderId) ||
                other.razorpayOrderId == razorpayOrderId) &&
            (identical(other.orderId, orderId) || other.orderId == orderId));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, key, amount, razorpayOrderId, orderId);

  @override
  String toString() {
    return 'RazorpayOrderEntity(key: $key, amount: $amount, razorpayOrderId: $razorpayOrderId, orderId: $orderId)';
  }
}

/// @nodoc
abstract mixin class _$RazorpayOrderEntityCopyWith<$Res>
    implements $RazorpayOrderEntityCopyWith<$Res> {
  factory _$RazorpayOrderEntityCopyWith(_RazorpayOrderEntity value,
          $Res Function(_RazorpayOrderEntity) _then) =
      __$RazorpayOrderEntityCopyWithImpl;
  @override
  @useResult
  $Res call({String key, int amount, String razorpayOrderId, String orderId});
}

/// @nodoc
class __$RazorpayOrderEntityCopyWithImpl<$Res>
    implements _$RazorpayOrderEntityCopyWith<$Res> {
  __$RazorpayOrderEntityCopyWithImpl(this._self, this._then);

  final _RazorpayOrderEntity _self;
  final $Res Function(_RazorpayOrderEntity) _then;

  /// Create a copy of RazorpayOrderEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? key = null,
    Object? amount = null,
    Object? razorpayOrderId = null,
    Object? orderId = null,
  }) {
    return _then(_RazorpayOrderEntity(
      key: null == key
          ? _self.key
          : key // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as int,
      razorpayOrderId: null == razorpayOrderId
          ? _self.razorpayOrderId
          : razorpayOrderId // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: null == orderId
          ? _self.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
