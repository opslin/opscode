// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'tip_preset_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$TipPresetEntity {
  @JsonKey(fromJson: _tipPresetAmountFromJson)
  double get amount;
  String? get emoji;

  /// Create a copy of TipPresetEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TipPresetEntityCopyWith<TipPresetEntity> get copyWith =>
      _$TipPresetEntityCopyWithImpl<TipPresetEntity>(
          this as TipPresetEntity, _$identity);

  /// Serializes this TipPresetEntity to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TipPresetEntity &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.emoji, emoji) || other.emoji == emoji));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, amount, emoji);

  @override
  String toString() {
    return 'TipPresetEntity(amount: $amount, emoji: $emoji)';
  }
}

/// @nodoc
abstract mixin class $TipPresetEntityCopyWith<$Res> {
  factory $TipPresetEntityCopyWith(
          TipPresetEntity value, $Res Function(TipPresetEntity) _then) =
      _$TipPresetEntityCopyWithImpl;
  @useResult
  $Res call(
      {@JsonKey(fromJson: _tipPresetAmountFromJson) double amount,
      String? emoji});
}

/// @nodoc
class _$TipPresetEntityCopyWithImpl<$Res>
    implements $TipPresetEntityCopyWith<$Res> {
  _$TipPresetEntityCopyWithImpl(this._self, this._then);

  final TipPresetEntity _self;
  final $Res Function(TipPresetEntity) _then;

  /// Create a copy of TipPresetEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? emoji = freezed,
  }) {
    return _then(_self.copyWith(
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      emoji: freezed == emoji
          ? _self.emoji
          : emoji // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [TipPresetEntity].
extension TipPresetEntityPatterns on TipPresetEntity {
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
    TResult Function(_TipPresetEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TipPresetEntity() when $default != null:
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
    TResult Function(_TipPresetEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TipPresetEntity():
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
    TResult? Function(_TipPresetEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TipPresetEntity() when $default != null:
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
    TResult Function(@JsonKey(fromJson: _tipPresetAmountFromJson) double amount,
            String? emoji)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TipPresetEntity() when $default != null:
        return $default(_that.amount, _that.emoji);
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
    TResult Function(@JsonKey(fromJson: _tipPresetAmountFromJson) double amount,
            String? emoji)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TipPresetEntity():
        return $default(_that.amount, _that.emoji);
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
            @JsonKey(fromJson: _tipPresetAmountFromJson) double amount,
            String? emoji)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TipPresetEntity() when $default != null:
        return $default(_that.amount, _that.emoji);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _TipPresetEntity implements TipPresetEntity {
  const _TipPresetEntity(
      {@JsonKey(fromJson: _tipPresetAmountFromJson) required this.amount,
      this.emoji});
  factory _TipPresetEntity.fromJson(Map<String, dynamic> json) =>
      _$TipPresetEntityFromJson(json);

  @override
  @JsonKey(fromJson: _tipPresetAmountFromJson)
  final double amount;
  @override
  final String? emoji;

  /// Create a copy of TipPresetEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TipPresetEntityCopyWith<_TipPresetEntity> get copyWith =>
      __$TipPresetEntityCopyWithImpl<_TipPresetEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$TipPresetEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TipPresetEntity &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.emoji, emoji) || other.emoji == emoji));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, amount, emoji);

  @override
  String toString() {
    return 'TipPresetEntity(amount: $amount, emoji: $emoji)';
  }
}

/// @nodoc
abstract mixin class _$TipPresetEntityCopyWith<$Res>
    implements $TipPresetEntityCopyWith<$Res> {
  factory _$TipPresetEntityCopyWith(
          _TipPresetEntity value, $Res Function(_TipPresetEntity) _then) =
      __$TipPresetEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {@JsonKey(fromJson: _tipPresetAmountFromJson) double amount,
      String? emoji});
}

/// @nodoc
class __$TipPresetEntityCopyWithImpl<$Res>
    implements _$TipPresetEntityCopyWith<$Res> {
  __$TipPresetEntityCopyWithImpl(this._self, this._then);

  final _TipPresetEntity _self;
  final $Res Function(_TipPresetEntity) _then;

  /// Create a copy of TipPresetEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? amount = null,
    Object? emoji = freezed,
  }) {
    return _then(_TipPresetEntity(
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      emoji: freezed == emoji
          ? _self.emoji
          : emoji // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
