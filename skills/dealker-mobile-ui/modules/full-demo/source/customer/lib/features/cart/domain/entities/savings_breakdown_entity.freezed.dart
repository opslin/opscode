// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'savings_breakdown_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SavingsBreakdownEntity {
  double get total;
  @JsonKey(name: 'breakdown')
  List<SavingsLineItem> get items;

  /// Create a copy of SavingsBreakdownEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SavingsBreakdownEntityCopyWith<SavingsBreakdownEntity> get copyWith =>
      _$SavingsBreakdownEntityCopyWithImpl<SavingsBreakdownEntity>(
          this as SavingsBreakdownEntity, _$identity);

  /// Serializes this SavingsBreakdownEntity to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SavingsBreakdownEntity &&
            (identical(other.total, total) || other.total == total) &&
            const DeepCollectionEquality().equals(other.items, items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, total, const DeepCollectionEquality().hash(items));

  @override
  String toString() {
    return 'SavingsBreakdownEntity(total: $total, items: $items)';
  }
}

/// @nodoc
abstract mixin class $SavingsBreakdownEntityCopyWith<$Res> {
  factory $SavingsBreakdownEntityCopyWith(SavingsBreakdownEntity value,
          $Res Function(SavingsBreakdownEntity) _then) =
      _$SavingsBreakdownEntityCopyWithImpl;
  @useResult
  $Res call(
      {double total, @JsonKey(name: 'breakdown') List<SavingsLineItem> items});
}

/// @nodoc
class _$SavingsBreakdownEntityCopyWithImpl<$Res>
    implements $SavingsBreakdownEntityCopyWith<$Res> {
  _$SavingsBreakdownEntityCopyWithImpl(this._self, this._then);

  final SavingsBreakdownEntity _self;
  final $Res Function(SavingsBreakdownEntity) _then;

  /// Create a copy of SavingsBreakdownEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? total = null,
    Object? items = null,
  }) {
    return _then(_self.copyWith(
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<SavingsLineItem>,
    ));
  }
}

/// Adds pattern-matching-related methods to [SavingsBreakdownEntity].
extension SavingsBreakdownEntityPatterns on SavingsBreakdownEntity {
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
    TResult Function(_SavingsBreakdownEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SavingsBreakdownEntity() when $default != null:
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
    TResult Function(_SavingsBreakdownEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavingsBreakdownEntity():
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
    TResult? Function(_SavingsBreakdownEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavingsBreakdownEntity() when $default != null:
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
    TResult Function(double total,
            @JsonKey(name: 'breakdown') List<SavingsLineItem> items)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SavingsBreakdownEntity() when $default != null:
        return $default(_that.total, _that.items);
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
    TResult Function(double total,
            @JsonKey(name: 'breakdown') List<SavingsLineItem> items)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavingsBreakdownEntity():
        return $default(_that.total, _that.items);
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
    TResult? Function(double total,
            @JsonKey(name: 'breakdown') List<SavingsLineItem> items)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavingsBreakdownEntity() when $default != null:
        return $default(_that.total, _that.items);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SavingsBreakdownEntity implements SavingsBreakdownEntity {
  const _SavingsBreakdownEntity(
      {this.total = 0,
      @JsonKey(name: 'breakdown')
      final List<SavingsLineItem> items = const <SavingsLineItem>[]})
      : _items = items;
  factory _SavingsBreakdownEntity.fromJson(Map<String, dynamic> json) =>
      _$SavingsBreakdownEntityFromJson(json);

  @override
  @JsonKey()
  final double total;
  final List<SavingsLineItem> _items;
  @override
  @JsonKey(name: 'breakdown')
  List<SavingsLineItem> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  /// Create a copy of SavingsBreakdownEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SavingsBreakdownEntityCopyWith<_SavingsBreakdownEntity> get copyWith =>
      __$SavingsBreakdownEntityCopyWithImpl<_SavingsBreakdownEntity>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SavingsBreakdownEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SavingsBreakdownEntity &&
            (identical(other.total, total) || other.total == total) &&
            const DeepCollectionEquality().equals(other._items, _items));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, total, const DeepCollectionEquality().hash(_items));

  @override
  String toString() {
    return 'SavingsBreakdownEntity(total: $total, items: $items)';
  }
}

/// @nodoc
abstract mixin class _$SavingsBreakdownEntityCopyWith<$Res>
    implements $SavingsBreakdownEntityCopyWith<$Res> {
  factory _$SavingsBreakdownEntityCopyWith(_SavingsBreakdownEntity value,
          $Res Function(_SavingsBreakdownEntity) _then) =
      __$SavingsBreakdownEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {double total, @JsonKey(name: 'breakdown') List<SavingsLineItem> items});
}

/// @nodoc
class __$SavingsBreakdownEntityCopyWithImpl<$Res>
    implements _$SavingsBreakdownEntityCopyWith<$Res> {
  __$SavingsBreakdownEntityCopyWithImpl(this._self, this._then);

  final _SavingsBreakdownEntity _self;
  final $Res Function(_SavingsBreakdownEntity) _then;

  /// Create a copy of SavingsBreakdownEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? total = null,
    Object? items = null,
  }) {
    return _then(_SavingsBreakdownEntity(
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<SavingsLineItem>,
    ));
  }
}

/// @nodoc
mixin _$SavingsLineItem {
  String get type;
  String get label;
  double get amount;

  /// Create a copy of SavingsLineItem
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SavingsLineItemCopyWith<SavingsLineItem> get copyWith =>
      _$SavingsLineItemCopyWithImpl<SavingsLineItem>(
          this as SavingsLineItem, _$identity);

  /// Serializes this SavingsLineItem to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SavingsLineItem &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, label, amount);

  @override
  String toString() {
    return 'SavingsLineItem(type: $type, label: $label, amount: $amount)';
  }
}

/// @nodoc
abstract mixin class $SavingsLineItemCopyWith<$Res> {
  factory $SavingsLineItemCopyWith(
          SavingsLineItem value, $Res Function(SavingsLineItem) _then) =
      _$SavingsLineItemCopyWithImpl;
  @useResult
  $Res call({String type, String label, double amount});
}

/// @nodoc
class _$SavingsLineItemCopyWithImpl<$Res>
    implements $SavingsLineItemCopyWith<$Res> {
  _$SavingsLineItemCopyWithImpl(this._self, this._then);

  final SavingsLineItem _self;
  final $Res Function(SavingsLineItem) _then;

  /// Create a copy of SavingsLineItem
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? label = null,
    Object? amount = null,
  }) {
    return _then(_self.copyWith(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [SavingsLineItem].
extension SavingsLineItemPatterns on SavingsLineItem {
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
    TResult Function(_SavingsLineItem value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SavingsLineItem() when $default != null:
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
    TResult Function(_SavingsLineItem value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavingsLineItem():
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
    TResult? Function(_SavingsLineItem value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavingsLineItem() when $default != null:
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
    TResult Function(String type, String label, double amount)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SavingsLineItem() when $default != null:
        return $default(_that.type, _that.label, _that.amount);
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
    TResult Function(String type, String label, double amount) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavingsLineItem():
        return $default(_that.type, _that.label, _that.amount);
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
    TResult? Function(String type, String label, double amount)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SavingsLineItem() when $default != null:
        return $default(_that.type, _that.label, _that.amount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _SavingsLineItem implements SavingsLineItem {
  const _SavingsLineItem(
      {required this.type, required this.label, this.amount = 0});
  factory _SavingsLineItem.fromJson(Map<String, dynamic> json) =>
      _$SavingsLineItemFromJson(json);

  @override
  final String type;
  @override
  final String label;
  @override
  @JsonKey()
  final double amount;

  /// Create a copy of SavingsLineItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SavingsLineItemCopyWith<_SavingsLineItem> get copyWith =>
      __$SavingsLineItemCopyWithImpl<_SavingsLineItem>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$SavingsLineItemToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SavingsLineItem &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.amount, amount) || other.amount == amount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, type, label, amount);

  @override
  String toString() {
    return 'SavingsLineItem(type: $type, label: $label, amount: $amount)';
  }
}

/// @nodoc
abstract mixin class _$SavingsLineItemCopyWith<$Res>
    implements $SavingsLineItemCopyWith<$Res> {
  factory _$SavingsLineItemCopyWith(
          _SavingsLineItem value, $Res Function(_SavingsLineItem) _then) =
      __$SavingsLineItemCopyWithImpl;
  @override
  @useResult
  $Res call({String type, String label, double amount});
}

/// @nodoc
class __$SavingsLineItemCopyWithImpl<$Res>
    implements _$SavingsLineItemCopyWith<$Res> {
  __$SavingsLineItemCopyWithImpl(this._self, this._then);

  final _SavingsLineItem _self;
  final $Res Function(_SavingsLineItem) _then;

  /// Create a copy of SavingsLineItem
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? type = null,
    Object? label = null,
    Object? amount = null,
  }) {
    return _then(_SavingsLineItem(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

// dart format on
