// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'coupon_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CouponEntity {
  String get code;
  CouponDiscountType get discountType;
  double get discountValue;
  double get discountAmount;
  double get minOrderAmount;
  double get maxDiscount;
  String? get description;
  String?
      get terms; // CASHBACK/FREE_DELIVERY coupons never reduce the bill (discountAmount
// stays 0 for both, by backend design) — they produce a separate
// effect instead, carried in these two fields.
  double get cashbackAmount;
  bool
      get freeDelivery; // Scope this coupon was validated with — null/empty on both means it
// applies to the whole cart. Used to locally re-check "does the coupon
// still apply?" whenever cart contents change (see
// checkout_provider.dart#_syncCart) without another server round trip.
  List<String>? get applicableCategoryIds;
  List<String>? get applicableProductIds;

  /// Create a copy of CouponEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CouponEntityCopyWith<CouponEntity> get copyWith =>
      _$CouponEntityCopyWithImpl<CouponEntity>(
          this as CouponEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CouponEntity &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.discountType, discountType) ||
                other.discountType == discountType) &&
            (identical(other.discountValue, discountValue) ||
                other.discountValue == discountValue) &&
            (identical(other.discountAmount, discountAmount) ||
                other.discountAmount == discountAmount) &&
            (identical(other.minOrderAmount, minOrderAmount) ||
                other.minOrderAmount == minOrderAmount) &&
            (identical(other.maxDiscount, maxDiscount) ||
                other.maxDiscount == maxDiscount) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.terms, terms) || other.terms == terms) &&
            (identical(other.cashbackAmount, cashbackAmount) ||
                other.cashbackAmount == cashbackAmount) &&
            (identical(other.freeDelivery, freeDelivery) ||
                other.freeDelivery == freeDelivery) &&
            const DeepCollectionEquality()
                .equals(other.applicableCategoryIds, applicableCategoryIds) &&
            const DeepCollectionEquality()
                .equals(other.applicableProductIds, applicableProductIds));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      code,
      discountType,
      discountValue,
      discountAmount,
      minOrderAmount,
      maxDiscount,
      description,
      terms,
      cashbackAmount,
      freeDelivery,
      const DeepCollectionEquality().hash(applicableCategoryIds),
      const DeepCollectionEquality().hash(applicableProductIds));

  @override
  String toString() {
    return 'CouponEntity(code: $code, discountType: $discountType, discountValue: $discountValue, discountAmount: $discountAmount, minOrderAmount: $minOrderAmount, maxDiscount: $maxDiscount, description: $description, terms: $terms, cashbackAmount: $cashbackAmount, freeDelivery: $freeDelivery, applicableCategoryIds: $applicableCategoryIds, applicableProductIds: $applicableProductIds)';
  }
}

/// @nodoc
abstract mixin class $CouponEntityCopyWith<$Res> {
  factory $CouponEntityCopyWith(
          CouponEntity value, $Res Function(CouponEntity) _then) =
      _$CouponEntityCopyWithImpl;
  @useResult
  $Res call(
      {String code,
      CouponDiscountType discountType,
      double discountValue,
      double discountAmount,
      double minOrderAmount,
      double maxDiscount,
      String? description,
      String? terms,
      double cashbackAmount,
      bool freeDelivery,
      List<String>? applicableCategoryIds,
      List<String>? applicableProductIds});
}

/// @nodoc
class _$CouponEntityCopyWithImpl<$Res> implements $CouponEntityCopyWith<$Res> {
  _$CouponEntityCopyWithImpl(this._self, this._then);

  final CouponEntity _self;
  final $Res Function(CouponEntity) _then;

  /// Create a copy of CouponEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? discountType = null,
    Object? discountValue = null,
    Object? discountAmount = null,
    Object? minOrderAmount = null,
    Object? maxDiscount = null,
    Object? description = freezed,
    Object? terms = freezed,
    Object? cashbackAmount = null,
    Object? freeDelivery = null,
    Object? applicableCategoryIds = freezed,
    Object? applicableProductIds = freezed,
  }) {
    return _then(_self.copyWith(
      code: null == code
          ? _self.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      discountType: null == discountType
          ? _self.discountType
          : discountType // ignore: cast_nullable_to_non_nullable
              as CouponDiscountType,
      discountValue: null == discountValue
          ? _self.discountValue
          : discountValue // ignore: cast_nullable_to_non_nullable
              as double,
      discountAmount: null == discountAmount
          ? _self.discountAmount
          : discountAmount // ignore: cast_nullable_to_non_nullable
              as double,
      minOrderAmount: null == minOrderAmount
          ? _self.minOrderAmount
          : minOrderAmount // ignore: cast_nullable_to_non_nullable
              as double,
      maxDiscount: null == maxDiscount
          ? _self.maxDiscount
          : maxDiscount // ignore: cast_nullable_to_non_nullable
              as double,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      terms: freezed == terms
          ? _self.terms
          : terms // ignore: cast_nullable_to_non_nullable
              as String?,
      cashbackAmount: null == cashbackAmount
          ? _self.cashbackAmount
          : cashbackAmount // ignore: cast_nullable_to_non_nullable
              as double,
      freeDelivery: null == freeDelivery
          ? _self.freeDelivery
          : freeDelivery // ignore: cast_nullable_to_non_nullable
              as bool,
      applicableCategoryIds: freezed == applicableCategoryIds
          ? _self.applicableCategoryIds
          : applicableCategoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      applicableProductIds: freezed == applicableProductIds
          ? _self.applicableProductIds
          : applicableProductIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

/// Adds pattern-matching-related methods to [CouponEntity].
extension CouponEntityPatterns on CouponEntity {
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
    TResult Function(_CouponEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CouponEntity() when $default != null:
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
    TResult Function(_CouponEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CouponEntity():
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
    TResult? Function(_CouponEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CouponEntity() when $default != null:
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
            String code,
            CouponDiscountType discountType,
            double discountValue,
            double discountAmount,
            double minOrderAmount,
            double maxDiscount,
            String? description,
            String? terms,
            double cashbackAmount,
            bool freeDelivery,
            List<String>? applicableCategoryIds,
            List<String>? applicableProductIds)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CouponEntity() when $default != null:
        return $default(
            _that.code,
            _that.discountType,
            _that.discountValue,
            _that.discountAmount,
            _that.minOrderAmount,
            _that.maxDiscount,
            _that.description,
            _that.terms,
            _that.cashbackAmount,
            _that.freeDelivery,
            _that.applicableCategoryIds,
            _that.applicableProductIds);
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
            String code,
            CouponDiscountType discountType,
            double discountValue,
            double discountAmount,
            double minOrderAmount,
            double maxDiscount,
            String? description,
            String? terms,
            double cashbackAmount,
            bool freeDelivery,
            List<String>? applicableCategoryIds,
            List<String>? applicableProductIds)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CouponEntity():
        return $default(
            _that.code,
            _that.discountType,
            _that.discountValue,
            _that.discountAmount,
            _that.minOrderAmount,
            _that.maxDiscount,
            _that.description,
            _that.terms,
            _that.cashbackAmount,
            _that.freeDelivery,
            _that.applicableCategoryIds,
            _that.applicableProductIds);
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
            String code,
            CouponDiscountType discountType,
            double discountValue,
            double discountAmount,
            double minOrderAmount,
            double maxDiscount,
            String? description,
            String? terms,
            double cashbackAmount,
            bool freeDelivery,
            List<String>? applicableCategoryIds,
            List<String>? applicableProductIds)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CouponEntity() when $default != null:
        return $default(
            _that.code,
            _that.discountType,
            _that.discountValue,
            _that.discountAmount,
            _that.minOrderAmount,
            _that.maxDiscount,
            _that.description,
            _that.terms,
            _that.cashbackAmount,
            _that.freeDelivery,
            _that.applicableCategoryIds,
            _that.applicableProductIds);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CouponEntity implements CouponEntity {
  const _CouponEntity(
      {required this.code,
      required this.discountType,
      required this.discountValue,
      required this.discountAmount,
      required this.minOrderAmount,
      required this.maxDiscount,
      this.description,
      this.terms,
      this.cashbackAmount = 0,
      this.freeDelivery = false,
      final List<String>? applicableCategoryIds,
      final List<String>? applicableProductIds})
      : _applicableCategoryIds = applicableCategoryIds,
        _applicableProductIds = applicableProductIds;

  @override
  final String code;
  @override
  final CouponDiscountType discountType;
  @override
  final double discountValue;
  @override
  final double discountAmount;
  @override
  final double minOrderAmount;
  @override
  final double maxDiscount;
  @override
  final String? description;
  @override
  final String? terms;
// CASHBACK/FREE_DELIVERY coupons never reduce the bill (discountAmount
// stays 0 for both, by backend design) — they produce a separate
// effect instead, carried in these two fields.
  @override
  @JsonKey()
  final double cashbackAmount;
  @override
  @JsonKey()
  final bool freeDelivery;
// Scope this coupon was validated with — null/empty on both means it
// applies to the whole cart. Used to locally re-check "does the coupon
// still apply?" whenever cart contents change (see
// checkout_provider.dart#_syncCart) without another server round trip.
  final List<String>? _applicableCategoryIds;
// Scope this coupon was validated with — null/empty on both means it
// applies to the whole cart. Used to locally re-check "does the coupon
// still apply?" whenever cart contents change (see
// checkout_provider.dart#_syncCart) without another server round trip.
  @override
  List<String>? get applicableCategoryIds {
    final value = _applicableCategoryIds;
    if (value == null) return null;
    if (_applicableCategoryIds is EqualUnmodifiableListView)
      return _applicableCategoryIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  final List<String>? _applicableProductIds;
  @override
  List<String>? get applicableProductIds {
    final value = _applicableProductIds;
    if (value == null) return null;
    if (_applicableProductIds is EqualUnmodifiableListView)
      return _applicableProductIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(value);
  }

  /// Create a copy of CouponEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CouponEntityCopyWith<_CouponEntity> get copyWith =>
      __$CouponEntityCopyWithImpl<_CouponEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CouponEntity &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.discountType, discountType) ||
                other.discountType == discountType) &&
            (identical(other.discountValue, discountValue) ||
                other.discountValue == discountValue) &&
            (identical(other.discountAmount, discountAmount) ||
                other.discountAmount == discountAmount) &&
            (identical(other.minOrderAmount, minOrderAmount) ||
                other.minOrderAmount == minOrderAmount) &&
            (identical(other.maxDiscount, maxDiscount) ||
                other.maxDiscount == maxDiscount) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.terms, terms) || other.terms == terms) &&
            (identical(other.cashbackAmount, cashbackAmount) ||
                other.cashbackAmount == cashbackAmount) &&
            (identical(other.freeDelivery, freeDelivery) ||
                other.freeDelivery == freeDelivery) &&
            const DeepCollectionEquality()
                .equals(other._applicableCategoryIds, _applicableCategoryIds) &&
            const DeepCollectionEquality()
                .equals(other._applicableProductIds, _applicableProductIds));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      code,
      discountType,
      discountValue,
      discountAmount,
      minOrderAmount,
      maxDiscount,
      description,
      terms,
      cashbackAmount,
      freeDelivery,
      const DeepCollectionEquality().hash(_applicableCategoryIds),
      const DeepCollectionEquality().hash(_applicableProductIds));

  @override
  String toString() {
    return 'CouponEntity(code: $code, discountType: $discountType, discountValue: $discountValue, discountAmount: $discountAmount, minOrderAmount: $minOrderAmount, maxDiscount: $maxDiscount, description: $description, terms: $terms, cashbackAmount: $cashbackAmount, freeDelivery: $freeDelivery, applicableCategoryIds: $applicableCategoryIds, applicableProductIds: $applicableProductIds)';
  }
}

/// @nodoc
abstract mixin class _$CouponEntityCopyWith<$Res>
    implements $CouponEntityCopyWith<$Res> {
  factory _$CouponEntityCopyWith(
          _CouponEntity value, $Res Function(_CouponEntity) _then) =
      __$CouponEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String code,
      CouponDiscountType discountType,
      double discountValue,
      double discountAmount,
      double minOrderAmount,
      double maxDiscount,
      String? description,
      String? terms,
      double cashbackAmount,
      bool freeDelivery,
      List<String>? applicableCategoryIds,
      List<String>? applicableProductIds});
}

/// @nodoc
class __$CouponEntityCopyWithImpl<$Res>
    implements _$CouponEntityCopyWith<$Res> {
  __$CouponEntityCopyWithImpl(this._self, this._then);

  final _CouponEntity _self;
  final $Res Function(_CouponEntity) _then;

  /// Create a copy of CouponEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? code = null,
    Object? discountType = null,
    Object? discountValue = null,
    Object? discountAmount = null,
    Object? minOrderAmount = null,
    Object? maxDiscount = null,
    Object? description = freezed,
    Object? terms = freezed,
    Object? cashbackAmount = null,
    Object? freeDelivery = null,
    Object? applicableCategoryIds = freezed,
    Object? applicableProductIds = freezed,
  }) {
    return _then(_CouponEntity(
      code: null == code
          ? _self.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      discountType: null == discountType
          ? _self.discountType
          : discountType // ignore: cast_nullable_to_non_nullable
              as CouponDiscountType,
      discountValue: null == discountValue
          ? _self.discountValue
          : discountValue // ignore: cast_nullable_to_non_nullable
              as double,
      discountAmount: null == discountAmount
          ? _self.discountAmount
          : discountAmount // ignore: cast_nullable_to_non_nullable
              as double,
      minOrderAmount: null == minOrderAmount
          ? _self.minOrderAmount
          : minOrderAmount // ignore: cast_nullable_to_non_nullable
              as double,
      maxDiscount: null == maxDiscount
          ? _self.maxDiscount
          : maxDiscount // ignore: cast_nullable_to_non_nullable
              as double,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      terms: freezed == terms
          ? _self.terms
          : terms // ignore: cast_nullable_to_non_nullable
              as String?,
      cashbackAmount: null == cashbackAmount
          ? _self.cashbackAmount
          : cashbackAmount // ignore: cast_nullable_to_non_nullable
              as double,
      freeDelivery: null == freeDelivery
          ? _self.freeDelivery
          : freeDelivery // ignore: cast_nullable_to_non_nullable
              as bool,
      applicableCategoryIds: freezed == applicableCategoryIds
          ? _self._applicableCategoryIds
          : applicableCategoryIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
      applicableProductIds: freezed == applicableProductIds
          ? _self._applicableProductIds
          : applicableProductIds // ignore: cast_nullable_to_non_nullable
              as List<String>?,
    ));
  }
}

// dart format on
