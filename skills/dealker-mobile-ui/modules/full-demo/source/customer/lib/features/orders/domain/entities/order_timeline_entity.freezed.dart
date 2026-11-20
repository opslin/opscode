// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_timeline_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrderTimelineEntity {
  OrderTimelineType get type;
  OrderStatus get status;
  DateTime get timestamp;
  String? get message;

  /// Create a copy of OrderTimelineEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $OrderTimelineEntityCopyWith<OrderTimelineEntity> get copyWith =>
      _$OrderTimelineEntityCopyWithImpl<OrderTimelineEntity>(
          this as OrderTimelineEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is OrderTimelineEntity &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, type, status, timestamp, message);

  @override
  String toString() {
    return 'OrderTimelineEntity(type: $type, status: $status, timestamp: $timestamp, message: $message)';
  }
}

/// @nodoc
abstract mixin class $OrderTimelineEntityCopyWith<$Res> {
  factory $OrderTimelineEntityCopyWith(
          OrderTimelineEntity value, $Res Function(OrderTimelineEntity) _then) =
      _$OrderTimelineEntityCopyWithImpl;
  @useResult
  $Res call(
      {OrderTimelineType type,
      OrderStatus status,
      DateTime timestamp,
      String? message});
}

/// @nodoc
class _$OrderTimelineEntityCopyWithImpl<$Res>
    implements $OrderTimelineEntityCopyWith<$Res> {
  _$OrderTimelineEntityCopyWithImpl(this._self, this._then);

  final OrderTimelineEntity _self;
  final $Res Function(OrderTimelineEntity) _then;

  /// Create a copy of OrderTimelineEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? status = null,
    Object? timestamp = null,
    Object? message = freezed,
  }) {
    return _then(_self.copyWith(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as OrderTimelineType,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as OrderStatus,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      message: freezed == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [OrderTimelineEntity].
extension OrderTimelineEntityPatterns on OrderTimelineEntity {
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
    TResult Function(_OrderTimelineEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OrderTimelineEntity() when $default != null:
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
    TResult Function(_OrderTimelineEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderTimelineEntity():
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
    TResult? Function(_OrderTimelineEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderTimelineEntity() when $default != null:
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
    TResult Function(OrderTimelineType type, OrderStatus status,
            DateTime timestamp, String? message)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OrderTimelineEntity() when $default != null:
        return $default(
            _that.type, _that.status, _that.timestamp, _that.message);
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
    TResult Function(OrderTimelineType type, OrderStatus status,
            DateTime timestamp, String? message)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderTimelineEntity():
        return $default(
            _that.type, _that.status, _that.timestamp, _that.message);
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
    TResult? Function(OrderTimelineType type, OrderStatus status,
            DateTime timestamp, String? message)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderTimelineEntity() when $default != null:
        return $default(
            _that.type, _that.status, _that.timestamp, _that.message);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _OrderTimelineEntity implements OrderTimelineEntity {
  const _OrderTimelineEntity(
      {required this.type,
      required this.status,
      required this.timestamp,
      this.message});

  @override
  final OrderTimelineType type;
  @override
  final OrderStatus status;
  @override
  final DateTime timestamp;
  @override
  final String? message;

  /// Create a copy of OrderTimelineEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$OrderTimelineEntityCopyWith<_OrderTimelineEntity> get copyWith =>
      __$OrderTimelineEntityCopyWithImpl<_OrderTimelineEntity>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _OrderTimelineEntity &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.message, message) || other.message == message));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, type, status, timestamp, message);

  @override
  String toString() {
    return 'OrderTimelineEntity(type: $type, status: $status, timestamp: $timestamp, message: $message)';
  }
}

/// @nodoc
abstract mixin class _$OrderTimelineEntityCopyWith<$Res>
    implements $OrderTimelineEntityCopyWith<$Res> {
  factory _$OrderTimelineEntityCopyWith(_OrderTimelineEntity value,
          $Res Function(_OrderTimelineEntity) _then) =
      __$OrderTimelineEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {OrderTimelineType type,
      OrderStatus status,
      DateTime timestamp,
      String? message});
}

/// @nodoc
class __$OrderTimelineEntityCopyWithImpl<$Res>
    implements _$OrderTimelineEntityCopyWith<$Res> {
  __$OrderTimelineEntityCopyWithImpl(this._self, this._then);

  final _OrderTimelineEntity _self;
  final $Res Function(_OrderTimelineEntity) _then;

  /// Create a copy of OrderTimelineEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? type = null,
    Object? status = null,
    Object? timestamp = null,
    Object? message = freezed,
  }) {
    return _then(_OrderTimelineEntity(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as OrderTimelineType,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as OrderStatus,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      message: freezed == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
