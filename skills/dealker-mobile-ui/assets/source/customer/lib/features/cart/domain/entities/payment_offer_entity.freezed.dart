// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_offer_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentOfferEntity {
  String get id;
  String get title;
  String get provider;
  bool get isLocked;
  String? get description;
  String? get iconUrl;
  String get cashbackType;
  @JsonKey(fromJson: _paymentOfferAmountFromJson)
  double get cashbackAmount;
  @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
  double? get cashbackPercent;
  @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
  double? get maxCashback;
  @JsonKey(fromJson: _paymentOfferAmountFromJson)
  double get minOrderAmount;
  String? get lockMessage;
  @JsonKey(fromJson: _paymentOfferAmountFromJson)
  double get unlockProgress;

  /// Create a copy of PaymentOfferEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PaymentOfferEntityCopyWith<PaymentOfferEntity> get copyWith =>
      _$PaymentOfferEntityCopyWithImpl<PaymentOfferEntity>(
          this as PaymentOfferEntity, _$identity);

  /// Serializes this PaymentOfferEntity to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PaymentOfferEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.isLocked, isLocked) ||
                other.isLocked == isLocked) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl) &&
            (identical(other.cashbackType, cashbackType) ||
                other.cashbackType == cashbackType) &&
            (identical(other.cashbackAmount, cashbackAmount) ||
                other.cashbackAmount == cashbackAmount) &&
            (identical(other.cashbackPercent, cashbackPercent) ||
                other.cashbackPercent == cashbackPercent) &&
            (identical(other.maxCashback, maxCashback) ||
                other.maxCashback == maxCashback) &&
            (identical(other.minOrderAmount, minOrderAmount) ||
                other.minOrderAmount == minOrderAmount) &&
            (identical(other.lockMessage, lockMessage) ||
                other.lockMessage == lockMessage) &&
            (identical(other.unlockProgress, unlockProgress) ||
                other.unlockProgress == unlockProgress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      provider,
      isLocked,
      description,
      iconUrl,
      cashbackType,
      cashbackAmount,
      cashbackPercent,
      maxCashback,
      minOrderAmount,
      lockMessage,
      unlockProgress);

  @override
  String toString() {
    return 'PaymentOfferEntity(id: $id, title: $title, provider: $provider, isLocked: $isLocked, description: $description, iconUrl: $iconUrl, cashbackType: $cashbackType, cashbackAmount: $cashbackAmount, cashbackPercent: $cashbackPercent, maxCashback: $maxCashback, minOrderAmount: $minOrderAmount, lockMessage: $lockMessage, unlockProgress: $unlockProgress)';
  }
}

/// @nodoc
abstract mixin class $PaymentOfferEntityCopyWith<$Res> {
  factory $PaymentOfferEntityCopyWith(
          PaymentOfferEntity value, $Res Function(PaymentOfferEntity) _then) =
      _$PaymentOfferEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String title,
      String provider,
      bool isLocked,
      String? description,
      String? iconUrl,
      String cashbackType,
      @JsonKey(fromJson: _paymentOfferAmountFromJson) double cashbackAmount,
      @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
      double? cashbackPercent,
      @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
      double? maxCashback,
      @JsonKey(fromJson: _paymentOfferAmountFromJson) double minOrderAmount,
      String? lockMessage,
      @JsonKey(fromJson: _paymentOfferAmountFromJson) double unlockProgress});
}

/// @nodoc
class _$PaymentOfferEntityCopyWithImpl<$Res>
    implements $PaymentOfferEntityCopyWith<$Res> {
  _$PaymentOfferEntityCopyWithImpl(this._self, this._then);

  final PaymentOfferEntity _self;
  final $Res Function(PaymentOfferEntity) _then;

  /// Create a copy of PaymentOfferEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? provider = null,
    Object? isLocked = null,
    Object? description = freezed,
    Object? iconUrl = freezed,
    Object? cashbackType = null,
    Object? cashbackAmount = null,
    Object? cashbackPercent = freezed,
    Object? maxCashback = freezed,
    Object? minOrderAmount = null,
    Object? lockMessage = freezed,
    Object? unlockProgress = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      isLocked: null == isLocked
          ? _self.isLocked
          : isLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      iconUrl: freezed == iconUrl
          ? _self.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      cashbackType: null == cashbackType
          ? _self.cashbackType
          : cashbackType // ignore: cast_nullable_to_non_nullable
              as String,
      cashbackAmount: null == cashbackAmount
          ? _self.cashbackAmount
          : cashbackAmount // ignore: cast_nullable_to_non_nullable
              as double,
      cashbackPercent: freezed == cashbackPercent
          ? _self.cashbackPercent
          : cashbackPercent // ignore: cast_nullable_to_non_nullable
              as double?,
      maxCashback: freezed == maxCashback
          ? _self.maxCashback
          : maxCashback // ignore: cast_nullable_to_non_nullable
              as double?,
      minOrderAmount: null == minOrderAmount
          ? _self.minOrderAmount
          : minOrderAmount // ignore: cast_nullable_to_non_nullable
              as double,
      lockMessage: freezed == lockMessage
          ? _self.lockMessage
          : lockMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      unlockProgress: null == unlockProgress
          ? _self.unlockProgress
          : unlockProgress // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [PaymentOfferEntity].
extension PaymentOfferEntityPatterns on PaymentOfferEntity {
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
    TResult Function(_PaymentOfferEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentOfferEntity() when $default != null:
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
    TResult Function(_PaymentOfferEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentOfferEntity():
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
    TResult? Function(_PaymentOfferEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentOfferEntity() when $default != null:
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
            String title,
            String provider,
            bool isLocked,
            String? description,
            String? iconUrl,
            String cashbackType,
            @JsonKey(fromJson: _paymentOfferAmountFromJson)
            double cashbackAmount,
            @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
            double? cashbackPercent,
            @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
            double? maxCashback,
            @JsonKey(fromJson: _paymentOfferAmountFromJson)
            double minOrderAmount,
            String? lockMessage,
            @JsonKey(fromJson: _paymentOfferAmountFromJson)
            double unlockProgress)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentOfferEntity() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.provider,
            _that.isLocked,
            _that.description,
            _that.iconUrl,
            _that.cashbackType,
            _that.cashbackAmount,
            _that.cashbackPercent,
            _that.maxCashback,
            _that.minOrderAmount,
            _that.lockMessage,
            _that.unlockProgress);
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
            String title,
            String provider,
            bool isLocked,
            String? description,
            String? iconUrl,
            String cashbackType,
            @JsonKey(fromJson: _paymentOfferAmountFromJson)
            double cashbackAmount,
            @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
            double? cashbackPercent,
            @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
            double? maxCashback,
            @JsonKey(fromJson: _paymentOfferAmountFromJson)
            double minOrderAmount,
            String? lockMessage,
            @JsonKey(fromJson: _paymentOfferAmountFromJson)
            double unlockProgress)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentOfferEntity():
        return $default(
            _that.id,
            _that.title,
            _that.provider,
            _that.isLocked,
            _that.description,
            _that.iconUrl,
            _that.cashbackType,
            _that.cashbackAmount,
            _that.cashbackPercent,
            _that.maxCashback,
            _that.minOrderAmount,
            _that.lockMessage,
            _that.unlockProgress);
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
            String title,
            String provider,
            bool isLocked,
            String? description,
            String? iconUrl,
            String cashbackType,
            @JsonKey(fromJson: _paymentOfferAmountFromJson)
            double cashbackAmount,
            @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
            double? cashbackPercent,
            @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
            double? maxCashback,
            @JsonKey(fromJson: _paymentOfferAmountFromJson)
            double minOrderAmount,
            String? lockMessage,
            @JsonKey(fromJson: _paymentOfferAmountFromJson)
            double unlockProgress)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentOfferEntity() when $default != null:
        return $default(
            _that.id,
            _that.title,
            _that.provider,
            _that.isLocked,
            _that.description,
            _that.iconUrl,
            _that.cashbackType,
            _that.cashbackAmount,
            _that.cashbackPercent,
            _that.maxCashback,
            _that.minOrderAmount,
            _that.lockMessage,
            _that.unlockProgress);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PaymentOfferEntity extends PaymentOfferEntity {
  const _PaymentOfferEntity(
      {required this.id,
      required this.title,
      required this.provider,
      required this.isLocked,
      this.description,
      this.iconUrl,
      this.cashbackType = 'FLAT',
      @JsonKey(fromJson: _paymentOfferAmountFromJson) this.cashbackAmount = 0,
      @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
      this.cashbackPercent,
      @JsonKey(fromJson: _paymentOfferNullableAmountFromJson) this.maxCashback,
      @JsonKey(fromJson: _paymentOfferAmountFromJson) this.minOrderAmount = 0,
      this.lockMessage,
      @JsonKey(fromJson: _paymentOfferAmountFromJson) this.unlockProgress = 0})
      : super._();
  factory _PaymentOfferEntity.fromJson(Map<String, dynamic> json) =>
      _$PaymentOfferEntityFromJson(json);

  @override
  final String id;
  @override
  final String title;
  @override
  final String provider;
  @override
  final bool isLocked;
  @override
  final String? description;
  @override
  final String? iconUrl;
  @override
  @JsonKey()
  final String cashbackType;
  @override
  @JsonKey(fromJson: _paymentOfferAmountFromJson)
  final double cashbackAmount;
  @override
  @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
  final double? cashbackPercent;
  @override
  @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
  final double? maxCashback;
  @override
  @JsonKey(fromJson: _paymentOfferAmountFromJson)
  final double minOrderAmount;
  @override
  final String? lockMessage;
  @override
  @JsonKey(fromJson: _paymentOfferAmountFromJson)
  final double unlockProgress;

  /// Create a copy of PaymentOfferEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PaymentOfferEntityCopyWith<_PaymentOfferEntity> get copyWith =>
      __$PaymentOfferEntityCopyWithImpl<_PaymentOfferEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PaymentOfferEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PaymentOfferEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.provider, provider) ||
                other.provider == provider) &&
            (identical(other.isLocked, isLocked) ||
                other.isLocked == isLocked) &&
            (identical(other.description, description) ||
                other.description == description) &&
            (identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl) &&
            (identical(other.cashbackType, cashbackType) ||
                other.cashbackType == cashbackType) &&
            (identical(other.cashbackAmount, cashbackAmount) ||
                other.cashbackAmount == cashbackAmount) &&
            (identical(other.cashbackPercent, cashbackPercent) ||
                other.cashbackPercent == cashbackPercent) &&
            (identical(other.maxCashback, maxCashback) ||
                other.maxCashback == maxCashback) &&
            (identical(other.minOrderAmount, minOrderAmount) ||
                other.minOrderAmount == minOrderAmount) &&
            (identical(other.lockMessage, lockMessage) ||
                other.lockMessage == lockMessage) &&
            (identical(other.unlockProgress, unlockProgress) ||
                other.unlockProgress == unlockProgress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      title,
      provider,
      isLocked,
      description,
      iconUrl,
      cashbackType,
      cashbackAmount,
      cashbackPercent,
      maxCashback,
      minOrderAmount,
      lockMessage,
      unlockProgress);

  @override
  String toString() {
    return 'PaymentOfferEntity(id: $id, title: $title, provider: $provider, isLocked: $isLocked, description: $description, iconUrl: $iconUrl, cashbackType: $cashbackType, cashbackAmount: $cashbackAmount, cashbackPercent: $cashbackPercent, maxCashback: $maxCashback, minOrderAmount: $minOrderAmount, lockMessage: $lockMessage, unlockProgress: $unlockProgress)';
  }
}

/// @nodoc
abstract mixin class _$PaymentOfferEntityCopyWith<$Res>
    implements $PaymentOfferEntityCopyWith<$Res> {
  factory _$PaymentOfferEntityCopyWith(
          _PaymentOfferEntity value, $Res Function(_PaymentOfferEntity) _then) =
      __$PaymentOfferEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String title,
      String provider,
      bool isLocked,
      String? description,
      String? iconUrl,
      String cashbackType,
      @JsonKey(fromJson: _paymentOfferAmountFromJson) double cashbackAmount,
      @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
      double? cashbackPercent,
      @JsonKey(fromJson: _paymentOfferNullableAmountFromJson)
      double? maxCashback,
      @JsonKey(fromJson: _paymentOfferAmountFromJson) double minOrderAmount,
      String? lockMessage,
      @JsonKey(fromJson: _paymentOfferAmountFromJson) double unlockProgress});
}

/// @nodoc
class __$PaymentOfferEntityCopyWithImpl<$Res>
    implements _$PaymentOfferEntityCopyWith<$Res> {
  __$PaymentOfferEntityCopyWithImpl(this._self, this._then);

  final _PaymentOfferEntity _self;
  final $Res Function(_PaymentOfferEntity) _then;

  /// Create a copy of PaymentOfferEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? title = null,
    Object? provider = null,
    Object? isLocked = null,
    Object? description = freezed,
    Object? iconUrl = freezed,
    Object? cashbackType = null,
    Object? cashbackAmount = null,
    Object? cashbackPercent = freezed,
    Object? maxCashback = freezed,
    Object? minOrderAmount = null,
    Object? lockMessage = freezed,
    Object? unlockProgress = null,
  }) {
    return _then(_PaymentOfferEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      provider: null == provider
          ? _self.provider
          : provider // ignore: cast_nullable_to_non_nullable
              as String,
      isLocked: null == isLocked
          ? _self.isLocked
          : isLocked // ignore: cast_nullable_to_non_nullable
              as bool,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
      iconUrl: freezed == iconUrl
          ? _self.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      cashbackType: null == cashbackType
          ? _self.cashbackType
          : cashbackType // ignore: cast_nullable_to_non_nullable
              as String,
      cashbackAmount: null == cashbackAmount
          ? _self.cashbackAmount
          : cashbackAmount // ignore: cast_nullable_to_non_nullable
              as double,
      cashbackPercent: freezed == cashbackPercent
          ? _self.cashbackPercent
          : cashbackPercent // ignore: cast_nullable_to_non_nullable
              as double?,
      maxCashback: freezed == maxCashback
          ? _self.maxCashback
          : maxCashback // ignore: cast_nullable_to_non_nullable
              as double?,
      minOrderAmount: null == minOrderAmount
          ? _self.minOrderAmount
          : minOrderAmount // ignore: cast_nullable_to_non_nullable
              as double,
      lockMessage: freezed == lockMessage
          ? _self.lockMessage
          : lockMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      unlockProgress: null == unlockProgress
          ? _self.unlockProgress
          : unlockProgress // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

// dart format on
