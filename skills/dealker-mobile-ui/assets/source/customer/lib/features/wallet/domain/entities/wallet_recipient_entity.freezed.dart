// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'wallet_recipient_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$WalletRecipientEntity {
  String get id;
  String get name;
  String get phone;

  /// Create a copy of WalletRecipientEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $WalletRecipientEntityCopyWith<WalletRecipientEntity> get copyWith =>
      _$WalletRecipientEntityCopyWithImpl<WalletRecipientEntity>(
          this as WalletRecipientEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is WalletRecipientEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, phone);

  @override
  String toString() {
    return 'WalletRecipientEntity(id: $id, name: $name, phone: $phone)';
  }
}

/// @nodoc
abstract mixin class $WalletRecipientEntityCopyWith<$Res> {
  factory $WalletRecipientEntityCopyWith(WalletRecipientEntity value,
          $Res Function(WalletRecipientEntity) _then) =
      _$WalletRecipientEntityCopyWithImpl;
  @useResult
  $Res call({String id, String name, String phone});
}

/// @nodoc
class _$WalletRecipientEntityCopyWithImpl<$Res>
    implements $WalletRecipientEntityCopyWith<$Res> {
  _$WalletRecipientEntityCopyWithImpl(this._self, this._then);

  final WalletRecipientEntity _self;
  final $Res Function(WalletRecipientEntity) _then;

  /// Create a copy of WalletRecipientEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [WalletRecipientEntity].
extension WalletRecipientEntityPatterns on WalletRecipientEntity {
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
    TResult Function(_WalletRecipientEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WalletRecipientEntity() when $default != null:
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
    TResult Function(_WalletRecipientEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletRecipientEntity():
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
    TResult? Function(_WalletRecipientEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletRecipientEntity() when $default != null:
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
    TResult Function(String id, String name, String phone)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _WalletRecipientEntity() when $default != null:
        return $default(_that.id, _that.name, _that.phone);
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
    TResult Function(String id, String name, String phone) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletRecipientEntity():
        return $default(_that.id, _that.name, _that.phone);
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
    TResult? Function(String id, String name, String phone)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _WalletRecipientEntity() when $default != null:
        return $default(_that.id, _that.name, _that.phone);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _WalletRecipientEntity implements WalletRecipientEntity {
  const _WalletRecipientEntity(
      {required this.id, required this.name, required this.phone});

  @override
  final String id;
  @override
  final String name;
  @override
  final String phone;

  /// Create a copy of WalletRecipientEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$WalletRecipientEntityCopyWith<_WalletRecipientEntity> get copyWith =>
      __$WalletRecipientEntityCopyWithImpl<_WalletRecipientEntity>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _WalletRecipientEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, phone);

  @override
  String toString() {
    return 'WalletRecipientEntity(id: $id, name: $name, phone: $phone)';
  }
}

/// @nodoc
abstract mixin class _$WalletRecipientEntityCopyWith<$Res>
    implements $WalletRecipientEntityCopyWith<$Res> {
  factory _$WalletRecipientEntityCopyWith(_WalletRecipientEntity value,
          $Res Function(_WalletRecipientEntity) _then) =
      __$WalletRecipientEntityCopyWithImpl;
  @override
  @useResult
  $Res call({String id, String name, String phone});
}

/// @nodoc
class __$WalletRecipientEntityCopyWithImpl<$Res>
    implements _$WalletRecipientEntityCopyWith<$Res> {
  __$WalletRecipientEntityCopyWithImpl(this._self, this._then);

  final _WalletRecipientEntity _self;
  final $Res Function(_WalletRecipientEntity) _then;

  /// Create a copy of WalletRecipientEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? phone = null,
  }) {
    return _then(_WalletRecipientEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
