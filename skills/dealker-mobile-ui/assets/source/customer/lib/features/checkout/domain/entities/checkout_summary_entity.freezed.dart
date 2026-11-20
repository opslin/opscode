// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checkout_summary_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CheckoutSummaryEntity {
  double get subtotal;
  double get discount;
  double get deliveryFee;
  double get platformFee;
  double get total;
  int get itemCount;

  /// Create a copy of CheckoutSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CheckoutSummaryEntityCopyWith<CheckoutSummaryEntity> get copyWith =>
      _$CheckoutSummaryEntityCopyWithImpl<CheckoutSummaryEntity>(
          this as CheckoutSummaryEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CheckoutSummaryEntity &&
            (identical(other.subtotal, subtotal) ||
                other.subtotal == subtotal) &&
            (identical(other.discount, discount) ||
                other.discount == discount) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.platformFee, platformFee) ||
                other.platformFee == platformFee) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.itemCount, itemCount) ||
                other.itemCount == itemCount));
  }

  @override
  int get hashCode => Object.hash(runtimeType, subtotal, discount, deliveryFee,
      platformFee, total, itemCount);

  @override
  String toString() {
    return 'CheckoutSummaryEntity(subtotal: $subtotal, discount: $discount, deliveryFee: $deliveryFee, platformFee: $platformFee, total: $total, itemCount: $itemCount)';
  }
}

/// @nodoc
abstract mixin class $CheckoutSummaryEntityCopyWith<$Res> {
  factory $CheckoutSummaryEntityCopyWith(CheckoutSummaryEntity value,
          $Res Function(CheckoutSummaryEntity) _then) =
      _$CheckoutSummaryEntityCopyWithImpl;
  @useResult
  $Res call(
      {double subtotal,
      double discount,
      double deliveryFee,
      double platformFee,
      double total,
      int itemCount});
}

/// @nodoc
class _$CheckoutSummaryEntityCopyWithImpl<$Res>
    implements $CheckoutSummaryEntityCopyWith<$Res> {
  _$CheckoutSummaryEntityCopyWithImpl(this._self, this._then);

  final CheckoutSummaryEntity _self;
  final $Res Function(CheckoutSummaryEntity) _then;

  /// Create a copy of CheckoutSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? subtotal = null,
    Object? discount = null,
    Object? deliveryFee = null,
    Object? platformFee = null,
    Object? total = null,
    Object? itemCount = null,
  }) {
    return _then(_self.copyWith(
      subtotal: null == subtotal
          ? _self.subtotal
          : subtotal // ignore: cast_nullable_to_non_nullable
              as double,
      discount: null == discount
          ? _self.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryFee: null == deliveryFee
          ? _self.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      platformFee: null == platformFee
          ? _self.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as double,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      itemCount: null == itemCount
          ? _self.itemCount
          : itemCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [CheckoutSummaryEntity].
extension CheckoutSummaryEntityPatterns on CheckoutSummaryEntity {
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
    TResult Function(_CheckoutSummaryEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CheckoutSummaryEntity() when $default != null:
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
    TResult Function(_CheckoutSummaryEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CheckoutSummaryEntity():
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
    TResult? Function(_CheckoutSummaryEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CheckoutSummaryEntity() when $default != null:
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
    TResult Function(double subtotal, double discount, double deliveryFee,
            double platformFee, double total, int itemCount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CheckoutSummaryEntity() when $default != null:
        return $default(_that.subtotal, _that.discount, _that.deliveryFee,
            _that.platformFee, _that.total, _that.itemCount);
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
    TResult Function(double subtotal, double discount, double deliveryFee,
            double platformFee, double total, int itemCount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CheckoutSummaryEntity():
        return $default(_that.subtotal, _that.discount, _that.deliveryFee,
            _that.platformFee, _that.total, _that.itemCount);
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
    TResult? Function(double subtotal, double discount, double deliveryFee,
            double platformFee, double total, int itemCount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CheckoutSummaryEntity() when $default != null:
        return $default(_that.subtotal, _that.discount, _that.deliveryFee,
            _that.platformFee, _that.total, _that.itemCount);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CheckoutSummaryEntity implements CheckoutSummaryEntity {
  const _CheckoutSummaryEntity(
      {required this.subtotal,
      required this.discount,
      required this.deliveryFee,
      required this.platformFee,
      required this.total,
      this.itemCount = 0});

  @override
  final double subtotal;
  @override
  final double discount;
  @override
  final double deliveryFee;
  @override
  final double platformFee;
  @override
  final double total;
  @override
  @JsonKey()
  final int itemCount;

  /// Create a copy of CheckoutSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CheckoutSummaryEntityCopyWith<_CheckoutSummaryEntity> get copyWith =>
      __$CheckoutSummaryEntityCopyWithImpl<_CheckoutSummaryEntity>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CheckoutSummaryEntity &&
            (identical(other.subtotal, subtotal) ||
                other.subtotal == subtotal) &&
            (identical(other.discount, discount) ||
                other.discount == discount) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.platformFee, platformFee) ||
                other.platformFee == platformFee) &&
            (identical(other.total, total) || other.total == total) &&
            (identical(other.itemCount, itemCount) ||
                other.itemCount == itemCount));
  }

  @override
  int get hashCode => Object.hash(runtimeType, subtotal, discount, deliveryFee,
      platformFee, total, itemCount);

  @override
  String toString() {
    return 'CheckoutSummaryEntity(subtotal: $subtotal, discount: $discount, deliveryFee: $deliveryFee, platformFee: $platformFee, total: $total, itemCount: $itemCount)';
  }
}

/// @nodoc
abstract mixin class _$CheckoutSummaryEntityCopyWith<$Res>
    implements $CheckoutSummaryEntityCopyWith<$Res> {
  factory _$CheckoutSummaryEntityCopyWith(_CheckoutSummaryEntity value,
          $Res Function(_CheckoutSummaryEntity) _then) =
      __$CheckoutSummaryEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {double subtotal,
      double discount,
      double deliveryFee,
      double platformFee,
      double total,
      int itemCount});
}

/// @nodoc
class __$CheckoutSummaryEntityCopyWithImpl<$Res>
    implements _$CheckoutSummaryEntityCopyWith<$Res> {
  __$CheckoutSummaryEntityCopyWithImpl(this._self, this._then);

  final _CheckoutSummaryEntity _self;
  final $Res Function(_CheckoutSummaryEntity) _then;

  /// Create a copy of CheckoutSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? subtotal = null,
    Object? discount = null,
    Object? deliveryFee = null,
    Object? platformFee = null,
    Object? total = null,
    Object? itemCount = null,
  }) {
    return _then(_CheckoutSummaryEntity(
      subtotal: null == subtotal
          ? _self.subtotal
          : subtotal // ignore: cast_nullable_to_non_nullable
              as double,
      discount: null == discount
          ? _self.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryFee: null == deliveryFee
          ? _self.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      platformFee: null == platformFee
          ? _self.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as double,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      itemCount: null == itemCount
          ? _self.itemCount
          : itemCount // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
