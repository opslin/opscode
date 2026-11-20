// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'purchase_limit_status_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PurchaseLimitStatusEntity {
  String
      get productId; // Already computed server-side as the tighter of the per-order and
// per-window caps, net of what's currently in the customer's cart —
// the client only ever needs to read this, never re-derive it.
  int get remainingToAdd;
  bool get isAtLimit;
  String? get categoryId;
  String? get ruleLabel;
  int? get maxQtyPerOrder;
  int? get remainingThisOrder;
  bool? get windowEnabled;
  String? get windowPeriod;
  int? get windowCount;
  int? get maxQtyPerWindow;
  int? get usedInWindow;
  int? get remainingInWindow;

  /// Create a copy of PurchaseLimitStatusEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PurchaseLimitStatusEntityCopyWith<PurchaseLimitStatusEntity> get copyWith =>
      _$PurchaseLimitStatusEntityCopyWithImpl<PurchaseLimitStatusEntity>(
          this as PurchaseLimitStatusEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PurchaseLimitStatusEntity &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.remainingToAdd, remainingToAdd) ||
                other.remainingToAdd == remainingToAdd) &&
            (identical(other.isAtLimit, isAtLimit) ||
                other.isAtLimit == isAtLimit) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.ruleLabel, ruleLabel) ||
                other.ruleLabel == ruleLabel) &&
            (identical(other.maxQtyPerOrder, maxQtyPerOrder) ||
                other.maxQtyPerOrder == maxQtyPerOrder) &&
            (identical(other.remainingThisOrder, remainingThisOrder) ||
                other.remainingThisOrder == remainingThisOrder) &&
            (identical(other.windowEnabled, windowEnabled) ||
                other.windowEnabled == windowEnabled) &&
            (identical(other.windowPeriod, windowPeriod) ||
                other.windowPeriod == windowPeriod) &&
            (identical(other.windowCount, windowCount) ||
                other.windowCount == windowCount) &&
            (identical(other.maxQtyPerWindow, maxQtyPerWindow) ||
                other.maxQtyPerWindow == maxQtyPerWindow) &&
            (identical(other.usedInWindow, usedInWindow) ||
                other.usedInWindow == usedInWindow) &&
            (identical(other.remainingInWindow, remainingInWindow) ||
                other.remainingInWindow == remainingInWindow));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      productId,
      remainingToAdd,
      isAtLimit,
      categoryId,
      ruleLabel,
      maxQtyPerOrder,
      remainingThisOrder,
      windowEnabled,
      windowPeriod,
      windowCount,
      maxQtyPerWindow,
      usedInWindow,
      remainingInWindow);

  @override
  String toString() {
    return 'PurchaseLimitStatusEntity(productId: $productId, remainingToAdd: $remainingToAdd, isAtLimit: $isAtLimit, categoryId: $categoryId, ruleLabel: $ruleLabel, maxQtyPerOrder: $maxQtyPerOrder, remainingThisOrder: $remainingThisOrder, windowEnabled: $windowEnabled, windowPeriod: $windowPeriod, windowCount: $windowCount, maxQtyPerWindow: $maxQtyPerWindow, usedInWindow: $usedInWindow, remainingInWindow: $remainingInWindow)';
  }
}

/// @nodoc
abstract mixin class $PurchaseLimitStatusEntityCopyWith<$Res> {
  factory $PurchaseLimitStatusEntityCopyWith(PurchaseLimitStatusEntity value,
          $Res Function(PurchaseLimitStatusEntity) _then) =
      _$PurchaseLimitStatusEntityCopyWithImpl;
  @useResult
  $Res call(
      {String productId,
      int remainingToAdd,
      bool isAtLimit,
      String? categoryId,
      String? ruleLabel,
      int? maxQtyPerOrder,
      int? remainingThisOrder,
      bool? windowEnabled,
      String? windowPeriod,
      int? windowCount,
      int? maxQtyPerWindow,
      int? usedInWindow,
      int? remainingInWindow});
}

/// @nodoc
class _$PurchaseLimitStatusEntityCopyWithImpl<$Res>
    implements $PurchaseLimitStatusEntityCopyWith<$Res> {
  _$PurchaseLimitStatusEntityCopyWithImpl(this._self, this._then);

  final PurchaseLimitStatusEntity _self;
  final $Res Function(PurchaseLimitStatusEntity) _then;

  /// Create a copy of PurchaseLimitStatusEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? productId = null,
    Object? remainingToAdd = null,
    Object? isAtLimit = null,
    Object? categoryId = freezed,
    Object? ruleLabel = freezed,
    Object? maxQtyPerOrder = freezed,
    Object? remainingThisOrder = freezed,
    Object? windowEnabled = freezed,
    Object? windowPeriod = freezed,
    Object? windowCount = freezed,
    Object? maxQtyPerWindow = freezed,
    Object? usedInWindow = freezed,
    Object? remainingInWindow = freezed,
  }) {
    return _then(_self.copyWith(
      productId: null == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      remainingToAdd: null == remainingToAdd
          ? _self.remainingToAdd
          : remainingToAdd // ignore: cast_nullable_to_non_nullable
              as int,
      isAtLimit: null == isAtLimit
          ? _self.isAtLimit
          : isAtLimit // ignore: cast_nullable_to_non_nullable
              as bool,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      ruleLabel: freezed == ruleLabel
          ? _self.ruleLabel
          : ruleLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      maxQtyPerOrder: freezed == maxQtyPerOrder
          ? _self.maxQtyPerOrder
          : maxQtyPerOrder // ignore: cast_nullable_to_non_nullable
              as int?,
      remainingThisOrder: freezed == remainingThisOrder
          ? _self.remainingThisOrder
          : remainingThisOrder // ignore: cast_nullable_to_non_nullable
              as int?,
      windowEnabled: freezed == windowEnabled
          ? _self.windowEnabled
          : windowEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      windowPeriod: freezed == windowPeriod
          ? _self.windowPeriod
          : windowPeriod // ignore: cast_nullable_to_non_nullable
              as String?,
      windowCount: freezed == windowCount
          ? _self.windowCount
          : windowCount // ignore: cast_nullable_to_non_nullable
              as int?,
      maxQtyPerWindow: freezed == maxQtyPerWindow
          ? _self.maxQtyPerWindow
          : maxQtyPerWindow // ignore: cast_nullable_to_non_nullable
              as int?,
      usedInWindow: freezed == usedInWindow
          ? _self.usedInWindow
          : usedInWindow // ignore: cast_nullable_to_non_nullable
              as int?,
      remainingInWindow: freezed == remainingInWindow
          ? _self.remainingInWindow
          : remainingInWindow // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

/// Adds pattern-matching-related methods to [PurchaseLimitStatusEntity].
extension PurchaseLimitStatusEntityPatterns on PurchaseLimitStatusEntity {
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
    TResult Function(_PurchaseLimitStatusEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PurchaseLimitStatusEntity() when $default != null:
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
    TResult Function(_PurchaseLimitStatusEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PurchaseLimitStatusEntity():
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
    TResult? Function(_PurchaseLimitStatusEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PurchaseLimitStatusEntity() when $default != null:
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
            String productId,
            int remainingToAdd,
            bool isAtLimit,
            String? categoryId,
            String? ruleLabel,
            int? maxQtyPerOrder,
            int? remainingThisOrder,
            bool? windowEnabled,
            String? windowPeriod,
            int? windowCount,
            int? maxQtyPerWindow,
            int? usedInWindow,
            int? remainingInWindow)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PurchaseLimitStatusEntity() when $default != null:
        return $default(
            _that.productId,
            _that.remainingToAdd,
            _that.isAtLimit,
            _that.categoryId,
            _that.ruleLabel,
            _that.maxQtyPerOrder,
            _that.remainingThisOrder,
            _that.windowEnabled,
            _that.windowPeriod,
            _that.windowCount,
            _that.maxQtyPerWindow,
            _that.usedInWindow,
            _that.remainingInWindow);
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
            String productId,
            int remainingToAdd,
            bool isAtLimit,
            String? categoryId,
            String? ruleLabel,
            int? maxQtyPerOrder,
            int? remainingThisOrder,
            bool? windowEnabled,
            String? windowPeriod,
            int? windowCount,
            int? maxQtyPerWindow,
            int? usedInWindow,
            int? remainingInWindow)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PurchaseLimitStatusEntity():
        return $default(
            _that.productId,
            _that.remainingToAdd,
            _that.isAtLimit,
            _that.categoryId,
            _that.ruleLabel,
            _that.maxQtyPerOrder,
            _that.remainingThisOrder,
            _that.windowEnabled,
            _that.windowPeriod,
            _that.windowCount,
            _that.maxQtyPerWindow,
            _that.usedInWindow,
            _that.remainingInWindow);
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
            String productId,
            int remainingToAdd,
            bool isAtLimit,
            String? categoryId,
            String? ruleLabel,
            int? maxQtyPerOrder,
            int? remainingThisOrder,
            bool? windowEnabled,
            String? windowPeriod,
            int? windowCount,
            int? maxQtyPerWindow,
            int? usedInWindow,
            int? remainingInWindow)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PurchaseLimitStatusEntity() when $default != null:
        return $default(
            _that.productId,
            _that.remainingToAdd,
            _that.isAtLimit,
            _that.categoryId,
            _that.ruleLabel,
            _that.maxQtyPerOrder,
            _that.remainingThisOrder,
            _that.windowEnabled,
            _that.windowPeriod,
            _that.windowCount,
            _that.maxQtyPerWindow,
            _that.usedInWindow,
            _that.remainingInWindow);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PurchaseLimitStatusEntity implements PurchaseLimitStatusEntity {
  const _PurchaseLimitStatusEntity(
      {required this.productId,
      required this.remainingToAdd,
      required this.isAtLimit,
      this.categoryId,
      this.ruleLabel,
      this.maxQtyPerOrder,
      this.remainingThisOrder,
      this.windowEnabled,
      this.windowPeriod,
      this.windowCount,
      this.maxQtyPerWindow,
      this.usedInWindow,
      this.remainingInWindow});

  @override
  final String productId;
// Already computed server-side as the tighter of the per-order and
// per-window caps, net of what's currently in the customer's cart —
// the client only ever needs to read this, never re-derive it.
  @override
  final int remainingToAdd;
  @override
  final bool isAtLimit;
  @override
  final String? categoryId;
  @override
  final String? ruleLabel;
  @override
  final int? maxQtyPerOrder;
  @override
  final int? remainingThisOrder;
  @override
  final bool? windowEnabled;
  @override
  final String? windowPeriod;
  @override
  final int? windowCount;
  @override
  final int? maxQtyPerWindow;
  @override
  final int? usedInWindow;
  @override
  final int? remainingInWindow;

  /// Create a copy of PurchaseLimitStatusEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PurchaseLimitStatusEntityCopyWith<_PurchaseLimitStatusEntity>
      get copyWith =>
          __$PurchaseLimitStatusEntityCopyWithImpl<_PurchaseLimitStatusEntity>(
              this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PurchaseLimitStatusEntity &&
            (identical(other.productId, productId) ||
                other.productId == productId) &&
            (identical(other.remainingToAdd, remainingToAdd) ||
                other.remainingToAdd == remainingToAdd) &&
            (identical(other.isAtLimit, isAtLimit) ||
                other.isAtLimit == isAtLimit) &&
            (identical(other.categoryId, categoryId) ||
                other.categoryId == categoryId) &&
            (identical(other.ruleLabel, ruleLabel) ||
                other.ruleLabel == ruleLabel) &&
            (identical(other.maxQtyPerOrder, maxQtyPerOrder) ||
                other.maxQtyPerOrder == maxQtyPerOrder) &&
            (identical(other.remainingThisOrder, remainingThisOrder) ||
                other.remainingThisOrder == remainingThisOrder) &&
            (identical(other.windowEnabled, windowEnabled) ||
                other.windowEnabled == windowEnabled) &&
            (identical(other.windowPeriod, windowPeriod) ||
                other.windowPeriod == windowPeriod) &&
            (identical(other.windowCount, windowCount) ||
                other.windowCount == windowCount) &&
            (identical(other.maxQtyPerWindow, maxQtyPerWindow) ||
                other.maxQtyPerWindow == maxQtyPerWindow) &&
            (identical(other.usedInWindow, usedInWindow) ||
                other.usedInWindow == usedInWindow) &&
            (identical(other.remainingInWindow, remainingInWindow) ||
                other.remainingInWindow == remainingInWindow));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      productId,
      remainingToAdd,
      isAtLimit,
      categoryId,
      ruleLabel,
      maxQtyPerOrder,
      remainingThisOrder,
      windowEnabled,
      windowPeriod,
      windowCount,
      maxQtyPerWindow,
      usedInWindow,
      remainingInWindow);

  @override
  String toString() {
    return 'PurchaseLimitStatusEntity(productId: $productId, remainingToAdd: $remainingToAdd, isAtLimit: $isAtLimit, categoryId: $categoryId, ruleLabel: $ruleLabel, maxQtyPerOrder: $maxQtyPerOrder, remainingThisOrder: $remainingThisOrder, windowEnabled: $windowEnabled, windowPeriod: $windowPeriod, windowCount: $windowCount, maxQtyPerWindow: $maxQtyPerWindow, usedInWindow: $usedInWindow, remainingInWindow: $remainingInWindow)';
  }
}

/// @nodoc
abstract mixin class _$PurchaseLimitStatusEntityCopyWith<$Res>
    implements $PurchaseLimitStatusEntityCopyWith<$Res> {
  factory _$PurchaseLimitStatusEntityCopyWith(_PurchaseLimitStatusEntity value,
          $Res Function(_PurchaseLimitStatusEntity) _then) =
      __$PurchaseLimitStatusEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String productId,
      int remainingToAdd,
      bool isAtLimit,
      String? categoryId,
      String? ruleLabel,
      int? maxQtyPerOrder,
      int? remainingThisOrder,
      bool? windowEnabled,
      String? windowPeriod,
      int? windowCount,
      int? maxQtyPerWindow,
      int? usedInWindow,
      int? remainingInWindow});
}

/// @nodoc
class __$PurchaseLimitStatusEntityCopyWithImpl<$Res>
    implements _$PurchaseLimitStatusEntityCopyWith<$Res> {
  __$PurchaseLimitStatusEntityCopyWithImpl(this._self, this._then);

  final _PurchaseLimitStatusEntity _self;
  final $Res Function(_PurchaseLimitStatusEntity) _then;

  /// Create a copy of PurchaseLimitStatusEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? productId = null,
    Object? remainingToAdd = null,
    Object? isAtLimit = null,
    Object? categoryId = freezed,
    Object? ruleLabel = freezed,
    Object? maxQtyPerOrder = freezed,
    Object? remainingThisOrder = freezed,
    Object? windowEnabled = freezed,
    Object? windowPeriod = freezed,
    Object? windowCount = freezed,
    Object? maxQtyPerWindow = freezed,
    Object? usedInWindow = freezed,
    Object? remainingInWindow = freezed,
  }) {
    return _then(_PurchaseLimitStatusEntity(
      productId: null == productId
          ? _self.productId
          : productId // ignore: cast_nullable_to_non_nullable
              as String,
      remainingToAdd: null == remainingToAdd
          ? _self.remainingToAdd
          : remainingToAdd // ignore: cast_nullable_to_non_nullable
              as int,
      isAtLimit: null == isAtLimit
          ? _self.isAtLimit
          : isAtLimit // ignore: cast_nullable_to_non_nullable
              as bool,
      categoryId: freezed == categoryId
          ? _self.categoryId
          : categoryId // ignore: cast_nullable_to_non_nullable
              as String?,
      ruleLabel: freezed == ruleLabel
          ? _self.ruleLabel
          : ruleLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      maxQtyPerOrder: freezed == maxQtyPerOrder
          ? _self.maxQtyPerOrder
          : maxQtyPerOrder // ignore: cast_nullable_to_non_nullable
              as int?,
      remainingThisOrder: freezed == remainingThisOrder
          ? _self.remainingThisOrder
          : remainingThisOrder // ignore: cast_nullable_to_non_nullable
              as int?,
      windowEnabled: freezed == windowEnabled
          ? _self.windowEnabled
          : windowEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
      windowPeriod: freezed == windowPeriod
          ? _self.windowPeriod
          : windowPeriod // ignore: cast_nullable_to_non_nullable
              as String?,
      windowCount: freezed == windowCount
          ? _self.windowCount
          : windowCount // ignore: cast_nullable_to_non_nullable
              as int?,
      maxQtyPerWindow: freezed == maxQtyPerWindow
          ? _self.maxQtyPerWindow
          : maxQtyPerWindow // ignore: cast_nullable_to_non_nullable
              as int?,
      usedInWindow: freezed == usedInWindow
          ? _self.usedInWindow
          : usedInWindow // ignore: cast_nullable_to_non_nullable
              as int?,
      remainingInWindow: freezed == remainingInWindow
          ? _self.remainingInWindow
          : remainingInWindow // ignore: cast_nullable_to_non_nullable
              as int?,
    ));
  }
}

// dart format on
