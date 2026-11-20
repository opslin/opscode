// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallet_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WalletEntity {
  double get balance;
  String get currency;

  /// Create a copy of WalletEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WalletEntityCopyWith<WalletEntity> get copyWith =>
      _$WalletEntityCopyWithImpl<WalletEntity>(
          this as WalletEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WalletEntity &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.currency, currency) ||
                other.currency == currency));
  }

  @override
  int get hashCode => Object.hash(runtimeType, balance, currency);

  @override
  String toString() {
    return 'WalletEntity(balance: $balance, currency: $currency)';
  }
}

/// @nodoc
abstract mixin class $WalletEntityCopyWith<$Res> {
  factory $WalletEntityCopyWith(
          WalletEntity value, $Res Function(WalletEntity) _then) =
      _$WalletEntityCopyWithImpl;
  @useResult
  $Res call({double balance, String currency});
}

/// @nodoc
class _$WalletEntityCopyWithImpl<$Res> implements $WalletEntityCopyWith<$Res> {
  _$WalletEntityCopyWithImpl(this._self, this._then);

  final WalletEntity _self;
  final $Res Function(WalletEntity) _then;

  /// Create a copy of WalletEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? balance = null,
    Object? currency = null,
  }) {
    return _then(_self.copyWith(
      balance: null == balance
          ? _self.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [WalletEntity].
extension WalletEntityPatterns on WalletEntity {
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
    TResult Function(_WalletEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WalletEntity() when $default != null:
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
    TResult Function(_WalletEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletEntity():
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
    TResult? Function(_WalletEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletEntity() when $default != null:
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
    TResult Function(double balance, String currency)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WalletEntity() when $default != null:
        return $default(_that.balance, _that.currency);
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
    TResult Function(double balance, String currency) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletEntity():
        return $default(_that.balance, _that.currency);
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
    TResult? Function(double balance, String currency)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletEntity() when $default != null:
        return $default(_that.balance, _that.currency);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _WalletEntity implements WalletEntity {
  const _WalletEntity({required this.balance, this.currency = 'INR'});

  @override
  final double balance;
  @override
  @JsonKey()
  final String currency;

  /// Create a copy of WalletEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WalletEntityCopyWith<_WalletEntity> get copyWith =>
      __$WalletEntityCopyWithImpl<_WalletEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WalletEntity &&
            (identical(other.balance, balance) || other.balance == balance) &&
            (identical(other.currency, currency) ||
                other.currency == currency));
  }

  @override
  int get hashCode => Object.hash(runtimeType, balance, currency);

  @override
  String toString() {
    return 'WalletEntity(balance: $balance, currency: $currency)';
  }
}

/// @nodoc
abstract mixin class _$WalletEntityCopyWith<$Res>
    implements $WalletEntityCopyWith<$Res> {
  factory _$WalletEntityCopyWith(
          _WalletEntity value, $Res Function(_WalletEntity) _then) =
      __$WalletEntityCopyWithImpl;
  @override
  @useResult
  $Res call({double balance, String currency});
}

/// @nodoc
class __$WalletEntityCopyWithImpl<$Res>
    implements _$WalletEntityCopyWith<$Res> {
  __$WalletEntityCopyWithImpl(this._self, this._then);

  final _WalletEntity _self;
  final $Res Function(_WalletEntity) _then;

  /// Create a copy of WalletEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? balance = null,
    Object? currency = null,
  }) {
    return _then(_WalletEntity(
      balance: null == balance
          ? _self.balance
          : balance // ignore: cast_nullable_to_non_nullable
              as double,
      currency: null == currency
          ? _self.currency
          : currency // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
