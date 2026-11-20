// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentEntity {
  String get id;
  String get orderId;
  double get amount;
  String get currency;
  String get status;
  DateTime get createdAt;
  String? get razorpayOrderId;
  String? get razorpayPaymentId;
  String? get method;

  /// Create a copy of PaymentEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PaymentEntityCopyWith<PaymentEntity> get copyWith =>
      _$PaymentEntityCopyWithImpl<PaymentEntity>(
          this as PaymentEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PaymentEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.razorpayOrderId, razorpayOrderId) ||
                other.razorpayOrderId == razorpayOrderId) &&
            (identical(other.razorpayPaymentId, razorpayPaymentId) ||
                other.razorpayPaymentId == razorpayPaymentId) &&
            (identical(other.method, method) || other.method == method));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, orderId, amount, currency,
      status, createdAt, razorpayOrderId, razorpayPaymentId, method);

  @override
  String toString() {
    return 'PaymentEntity(id: $id, orderId: $orderId, amount: $amount, currency: $currency, status: $status, createdAt: $createdAt, razorpayOrderId: $razorpayOrderId, razorpayPaymentId: $razorpayPaymentId, method: $method)';
  }
}

/// @nodoc
abstract mixin class $PaymentEntityCopyWith<$Res> {
  factory $PaymentEntityCopyWith(
          PaymentEntity value, $Res Function(PaymentEntity) _then) =
      _$PaymentEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String orderId,
      double amount,
      String currency,
      String status,
      DateTime createdAt,
      String? razorpayOrderId,
      String? razorpayPaymentId,
      String? method});
}

/// @nodoc
class _$PaymentEntityCopyWithImpl<$Res>
    implements $PaymentEntityCopyWith<$Res> {
  _$PaymentEntityCopyWithImpl(this._self, this._then);

  final PaymentEntity _self;
  final $Res Function(PaymentEntity) _then;

  /// Create a copy of PaymentEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? amount = null,
    Object? currency = null,
    Object? status = null,
    Object? createdAt = null,
    Object? razorpayOrderId = freezed,
    Object? razorpayPaymentId = freezed,
    Object? method = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: null == orderId
          ? _self.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      razorpayOrderId: freezed == razorpayOrderId
          ? _self.razorpayOrderId
          : razorpayOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
      razorpayPaymentId: freezed == razorpayPaymentId
          ? _self.razorpayPaymentId
          : razorpayPaymentId // ignore: cast_nullable_to_non_nullable
              as String?,
      method: freezed == method
          ? _self.method
          : method // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PaymentEntity].
extension PaymentEntityPatterns on PaymentEntity {
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
    TResult Function(_PaymentEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentEntity() when $default != null:
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
    TResult Function(_PaymentEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentEntity():
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
    TResult? Function(_PaymentEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentEntity() when $default != null:
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
            String id,
            String orderId,
            double amount,
            String currency,
            String status,
            DateTime createdAt,
            String? razorpayOrderId,
            String? razorpayPaymentId,
            String? method)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentEntity() when $default != null:
        return $default(
            _that.id,
            _that.orderId,
            _that.amount,
            _that.currency,
            _that.status,
            _that.createdAt,
            _that.razorpayOrderId,
            _that.razorpayPaymentId,
            _that.method);
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
            String id,
            String orderId,
            double amount,
            String currency,
            String status,
            DateTime createdAt,
            String? razorpayOrderId,
            String? razorpayPaymentId,
            String? method)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentEntity():
        return $default(
            _that.id,
            _that.orderId,
            _that.amount,
            _that.currency,
            _that.status,
            _that.createdAt,
            _that.razorpayOrderId,
            _that.razorpayPaymentId,
            _that.method);
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
            String id,
            String orderId,
            double amount,
            String currency,
            String status,
            DateTime createdAt,
            String? razorpayOrderId,
            String? razorpayPaymentId,
            String? method)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentEntity() when $default != null:
        return $default(
            _that.id,
            _that.orderId,
            _that.amount,
            _that.currency,
            _that.status,
            _that.createdAt,
            _that.razorpayOrderId,
            _that.razorpayPaymentId,
            _that.method);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PaymentEntity implements PaymentEntity {
  const _PaymentEntity(
      {required this.id,
      required this.orderId,
      required this.amount,
      required this.currency,
      required this.status,
      required this.createdAt,
      this.razorpayOrderId,
      this.razorpayPaymentId,
      this.method});

  @override
  final String id;
  @override
  final String orderId;
  @override
  final double amount;
  @override
  final String currency;
  @override
  final String status;
  @override
  final DateTime createdAt;
  @override
  final String? razorpayOrderId;
  @override
  final String? razorpayPaymentId;
  @override
  final String? method;

  /// Create a copy of PaymentEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PaymentEntityCopyWith<_PaymentEntity> get copyWith =>
      __$PaymentEntityCopyWithImpl<_PaymentEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PaymentEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderId, orderId) || other.orderId == orderId) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.currency, currency) ||
                other.currency == currency) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.razorpayOrderId, razorpayOrderId) ||
                other.razorpayOrderId == razorpayOrderId) &&
            (identical(other.razorpayPaymentId, razorpayPaymentId) ||
                other.razorpayPaymentId == razorpayPaymentId) &&
            (identical(other.method, method) || other.method == method));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, orderId, amount, currency,
      status, createdAt, razorpayOrderId, razorpayPaymentId, method);

  @override
  String toString() {
    return 'PaymentEntity(id: $id, orderId: $orderId, amount: $amount, currency: $currency, status: $status, createdAt: $createdAt, razorpayOrderId: $razorpayOrderId, razorpayPaymentId: $razorpayPaymentId, method: $method)';
  }
}

/// @nodoc
abstract mixin class _$PaymentEntityCopyWith<$Res>
    implements $PaymentEntityCopyWith<$Res> {
  factory _$PaymentEntityCopyWith(
          _PaymentEntity value, $Res Function(_PaymentEntity) _then) =
      __$PaymentEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String orderId,
      double amount,
      String currency,
      String status,
      DateTime createdAt,
      String? razorpayOrderId,
      String? razorpayPaymentId,
      String? method});
}

/// @nodoc
class __$PaymentEntityCopyWithImpl<$Res>
    implements _$PaymentEntityCopyWith<$Res> {
  __$PaymentEntityCopyWithImpl(this._self, this._then);

  final _PaymentEntity _self;
  final $Res Function(_PaymentEntity) _then;

  /// Create a copy of PaymentEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? orderId = null,
    Object? amount = null,
    Object? currency = null,
    Object? status = null,
    Object? createdAt = null,
    Object? razorpayOrderId = freezed,
    Object? razorpayPaymentId = freezed,
    Object? method = freezed,
  }) {
    return _then(_PaymentEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      orderId: null == orderId
          ? _self.orderId
          : orderId // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      razorpayOrderId: freezed == razorpayOrderId
          ? _self.razorpayOrderId
          : razorpayOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
      razorpayPaymentId: freezed == razorpayPaymentId
          ? _self.razorpayPaymentId
          : razorpayPaymentId // ignore: cast_nullable_to_non_nullable
              as String?,
      method: freezed == method
          ? _self.method
          : method // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
