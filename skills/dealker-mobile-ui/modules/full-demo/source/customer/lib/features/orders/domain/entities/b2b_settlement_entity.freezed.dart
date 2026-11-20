// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'b2b_settlement_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$B2BSettlementEntity {
  String get id;
  String get method;
  double get amount;
  DateTime get createdAt;
  String? get note;

  /// Create a copy of B2BSettlementEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $B2BSettlementEntityCopyWith<B2BSettlementEntity> get copyWith =>
      _$B2BSettlementEntityCopyWithImpl<B2BSettlementEntity>(
          this as B2BSettlementEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is B2BSettlementEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.method, method) || other.method == method) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.note, note) || other.note == note));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, method, amount, createdAt, note);

  @override
  String toString() {
    return 'B2BSettlementEntity(id: $id, method: $method, amount: $amount, createdAt: $createdAt, note: $note)';
  }
}

/// @nodoc
abstract mixin class $B2BSettlementEntityCopyWith<$Res> {
  factory $B2BSettlementEntityCopyWith(
          B2BSettlementEntity value, $Res Function(B2BSettlementEntity) _then) =
      _$B2BSettlementEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String method,
      double amount,
      DateTime createdAt,
      String? note});
}

/// @nodoc
class _$B2BSettlementEntityCopyWithImpl<$Res>
    implements $B2BSettlementEntityCopyWith<$Res> {
  _$B2BSettlementEntityCopyWithImpl(this._self, this._then);

  final B2BSettlementEntity _self;
  final $Res Function(B2BSettlementEntity) _then;

  /// Create a copy of B2BSettlementEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? method = null,
    Object? amount = null,
    Object? createdAt = null,
    Object? note = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _self.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [B2BSettlementEntity].
extension B2BSettlementEntityPatterns on B2BSettlementEntity {
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
    TResult Function(_B2BSettlementEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _B2BSettlementEntity() when $default != null:
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
    TResult Function(_B2BSettlementEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _B2BSettlementEntity():
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
    TResult? Function(_B2BSettlementEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _B2BSettlementEntity() when $default != null:
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
    TResult Function(String id, String method, double amount,
            DateTime createdAt, String? note)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _B2BSettlementEntity() when $default != null:
        return $default(
            _that.id, _that.method, _that.amount, _that.createdAt, _that.note);
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
    TResult Function(String id, String method, double amount,
            DateTime createdAt, String? note)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _B2BSettlementEntity():
        return $default(
            _that.id, _that.method, _that.amount, _that.createdAt, _that.note);
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
    TResult? Function(String id, String method, double amount,
            DateTime createdAt, String? note)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _B2BSettlementEntity() when $default != null:
        return $default(
            _that.id, _that.method, _that.amount, _that.createdAt, _that.note);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _B2BSettlementEntity implements B2BSettlementEntity {
  const _B2BSettlementEntity(
      {required this.id,
      required this.method,
      required this.amount,
      required this.createdAt,
      this.note});

  @override
  final String id;
  @override
  final String method;
  @override
  final double amount;
  @override
  final DateTime createdAt;
  @override
  final String? note;

  /// Create a copy of B2BSettlementEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$B2BSettlementEntityCopyWith<_B2BSettlementEntity> get copyWith =>
      __$B2BSettlementEntityCopyWithImpl<_B2BSettlementEntity>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _B2BSettlementEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.method, method) || other.method == method) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.note, note) || other.note == note));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, id, method, amount, createdAt, note);

  @override
  String toString() {
    return 'B2BSettlementEntity(id: $id, method: $method, amount: $amount, createdAt: $createdAt, note: $note)';
  }
}

/// @nodoc
abstract mixin class _$B2BSettlementEntityCopyWith<$Res>
    implements $B2BSettlementEntityCopyWith<$Res> {
  factory _$B2BSettlementEntityCopyWith(_B2BSettlementEntity value,
          $Res Function(_B2BSettlementEntity) _then) =
      __$B2BSettlementEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String method,
      double amount,
      DateTime createdAt,
      String? note});
}

/// @nodoc
class __$B2BSettlementEntityCopyWithImpl<$Res>
    implements _$B2BSettlementEntityCopyWith<$Res> {
  __$B2BSettlementEntityCopyWithImpl(this._self, this._then);

  final _B2BSettlementEntity _self;
  final $Res Function(_B2BSettlementEntity) _then;

  /// Create a copy of B2BSettlementEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? method = null,
    Object? amount = null,
    Object? createdAt = null,
    Object? note = freezed,
  }) {
    return _then(_B2BSettlementEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      method: null == method
          ? _self.method
          : method // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      note: freezed == note
          ? _self.note
          : note // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
