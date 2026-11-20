// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nav_button_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NavButtonEntity {
  String get id;
  String get label;
  NavButtonDestinationType get destinationType;
  String get destinationValue;
  NavButtonIconType get iconType; // PRESET fields.
  String? get iconKey;
  String?
      get accentColor; // CUSTOM fields — customIconActiveUrl is required when iconType is
// custom (enforced server-side); customIconInactiveUrl is optional
// and falls back to the active image when absent.
  String? get customIconActiveUrl;
  String? get customIconInactiveUrl;
  bool get passIdentity;

  /// Create a copy of NavButtonEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NavButtonEntityCopyWith<NavButtonEntity> get copyWith =>
      _$NavButtonEntityCopyWithImpl<NavButtonEntity>(
          this as NavButtonEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NavButtonEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.destinationType, destinationType) ||
                other.destinationType == destinationType) &&
            (identical(other.destinationValue, destinationValue) ||
                other.destinationValue == destinationValue) &&
            (identical(other.iconType, iconType) ||
                other.iconType == iconType) &&
            (identical(other.iconKey, iconKey) || other.iconKey == iconKey) &&
            (identical(other.accentColor, accentColor) ||
                other.accentColor == accentColor) &&
            (identical(other.customIconActiveUrl, customIconActiveUrl) ||
                other.customIconActiveUrl == customIconActiveUrl) &&
            (identical(other.customIconInactiveUrl, customIconInactiveUrl) ||
                other.customIconInactiveUrl == customIconInactiveUrl) &&
            (identical(other.passIdentity, passIdentity) ||
                other.passIdentity == passIdentity));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      label,
      destinationType,
      destinationValue,
      iconType,
      iconKey,
      accentColor,
      customIconActiveUrl,
      customIconInactiveUrl,
      passIdentity);

  @override
  String toString() {
    return 'NavButtonEntity(id: $id, label: $label, destinationType: $destinationType, destinationValue: $destinationValue, iconType: $iconType, iconKey: $iconKey, accentColor: $accentColor, customIconActiveUrl: $customIconActiveUrl, customIconInactiveUrl: $customIconInactiveUrl, passIdentity: $passIdentity)';
  }
}

/// @nodoc
abstract mixin class $NavButtonEntityCopyWith<$Res> {
  factory $NavButtonEntityCopyWith(
          NavButtonEntity value, $Res Function(NavButtonEntity) _then) =
      _$NavButtonEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String label,
      NavButtonDestinationType destinationType,
      String destinationValue,
      NavButtonIconType iconType,
      String? iconKey,
      String? accentColor,
      String? customIconActiveUrl,
      String? customIconInactiveUrl,
      bool passIdentity});
}

/// @nodoc
class _$NavButtonEntityCopyWithImpl<$Res>
    implements $NavButtonEntityCopyWith<$Res> {
  _$NavButtonEntityCopyWithImpl(this._self, this._then);

  final NavButtonEntity _self;
  final $Res Function(NavButtonEntity) _then;

  /// Create a copy of NavButtonEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? destinationType = null,
    Object? destinationValue = null,
    Object? iconType = null,
    Object? iconKey = freezed,
    Object? accentColor = freezed,
    Object? customIconActiveUrl = freezed,
    Object? customIconInactiveUrl = freezed,
    Object? passIdentity = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      destinationType: null == destinationType
          ? _self.destinationType
          : destinationType // ignore: cast_nullable_to_non_nullable
              as NavButtonDestinationType,
      destinationValue: null == destinationValue
          ? _self.destinationValue
          : destinationValue // ignore: cast_nullable_to_non_nullable
              as String,
      iconType: null == iconType
          ? _self.iconType
          : iconType // ignore: cast_nullable_to_non_nullable
              as NavButtonIconType,
      iconKey: freezed == iconKey
          ? _self.iconKey
          : iconKey // ignore: cast_nullable_to_non_nullable
              as String?,
      accentColor: freezed == accentColor
          ? _self.accentColor
          : accentColor // ignore: cast_nullable_to_non_nullable
              as String?,
      customIconActiveUrl: freezed == customIconActiveUrl
          ? _self.customIconActiveUrl
          : customIconActiveUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      customIconInactiveUrl: freezed == customIconInactiveUrl
          ? _self.customIconInactiveUrl
          : customIconInactiveUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      passIdentity: null == passIdentity
          ? _self.passIdentity
          : passIdentity // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [NavButtonEntity].
extension NavButtonEntityPatterns on NavButtonEntity {
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
    TResult Function(_NavButtonEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NavButtonEntity() when $default != null:
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
    TResult Function(_NavButtonEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NavButtonEntity():
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
    TResult? Function(_NavButtonEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NavButtonEntity() when $default != null:
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
            String label,
            NavButtonDestinationType destinationType,
            String destinationValue,
            NavButtonIconType iconType,
            String? iconKey,
            String? accentColor,
            String? customIconActiveUrl,
            String? customIconInactiveUrl,
            bool passIdentity)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NavButtonEntity() when $default != null:
        return $default(
            _that.id,
            _that.label,
            _that.destinationType,
            _that.destinationValue,
            _that.iconType,
            _that.iconKey,
            _that.accentColor,
            _that.customIconActiveUrl,
            _that.customIconInactiveUrl,
            _that.passIdentity);
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
            String label,
            NavButtonDestinationType destinationType,
            String destinationValue,
            NavButtonIconType iconType,
            String? iconKey,
            String? accentColor,
            String? customIconActiveUrl,
            String? customIconInactiveUrl,
            bool passIdentity)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NavButtonEntity():
        return $default(
            _that.id,
            _that.label,
            _that.destinationType,
            _that.destinationValue,
            _that.iconType,
            _that.iconKey,
            _that.accentColor,
            _that.customIconActiveUrl,
            _that.customIconInactiveUrl,
            _that.passIdentity);
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
            String label,
            NavButtonDestinationType destinationType,
            String destinationValue,
            NavButtonIconType iconType,
            String? iconKey,
            String? accentColor,
            String? customIconActiveUrl,
            String? customIconInactiveUrl,
            bool passIdentity)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NavButtonEntity() when $default != null:
        return $default(
            _that.id,
            _that.label,
            _that.destinationType,
            _that.destinationValue,
            _that.iconType,
            _that.iconKey,
            _that.accentColor,
            _that.customIconActiveUrl,
            _that.customIconInactiveUrl,
            _that.passIdentity);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _NavButtonEntity implements NavButtonEntity {
  const _NavButtonEntity(
      {required this.id,
      required this.label,
      required this.destinationType,
      required this.destinationValue,
      this.iconType = NavButtonIconType.preset,
      this.iconKey,
      this.accentColor,
      this.customIconActiveUrl,
      this.customIconInactiveUrl,
      this.passIdentity = false});

  @override
  final String id;
  @override
  final String label;
  @override
  final NavButtonDestinationType destinationType;
  @override
  final String destinationValue;
  @override
  @JsonKey()
  final NavButtonIconType iconType;
// PRESET fields.
  @override
  final String? iconKey;
  @override
  final String? accentColor;
// CUSTOM fields — customIconActiveUrl is required when iconType is
// custom (enforced server-side); customIconInactiveUrl is optional
// and falls back to the active image when absent.
  @override
  final String? customIconActiveUrl;
  @override
  final String? customIconInactiveUrl;
  @override
  @JsonKey()
  final bool passIdentity;

  /// Create a copy of NavButtonEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NavButtonEntityCopyWith<_NavButtonEntity> get copyWith =>
      __$NavButtonEntityCopyWithImpl<_NavButtonEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NavButtonEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.destinationType, destinationType) ||
                other.destinationType == destinationType) &&
            (identical(other.destinationValue, destinationValue) ||
                other.destinationValue == destinationValue) &&
            (identical(other.iconType, iconType) ||
                other.iconType == iconType) &&
            (identical(other.iconKey, iconKey) || other.iconKey == iconKey) &&
            (identical(other.accentColor, accentColor) ||
                other.accentColor == accentColor) &&
            (identical(other.customIconActiveUrl, customIconActiveUrl) ||
                other.customIconActiveUrl == customIconActiveUrl) &&
            (identical(other.customIconInactiveUrl, customIconInactiveUrl) ||
                other.customIconInactiveUrl == customIconInactiveUrl) &&
            (identical(other.passIdentity, passIdentity) ||
                other.passIdentity == passIdentity));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      label,
      destinationType,
      destinationValue,
      iconType,
      iconKey,
      accentColor,
      customIconActiveUrl,
      customIconInactiveUrl,
      passIdentity);

  @override
  String toString() {
    return 'NavButtonEntity(id: $id, label: $label, destinationType: $destinationType, destinationValue: $destinationValue, iconType: $iconType, iconKey: $iconKey, accentColor: $accentColor, customIconActiveUrl: $customIconActiveUrl, customIconInactiveUrl: $customIconInactiveUrl, passIdentity: $passIdentity)';
  }
}

/// @nodoc
abstract mixin class _$NavButtonEntityCopyWith<$Res>
    implements $NavButtonEntityCopyWith<$Res> {
  factory _$NavButtonEntityCopyWith(
          _NavButtonEntity value, $Res Function(_NavButtonEntity) _then) =
      __$NavButtonEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String label,
      NavButtonDestinationType destinationType,
      String destinationValue,
      NavButtonIconType iconType,
      String? iconKey,
      String? accentColor,
      String? customIconActiveUrl,
      String? customIconInactiveUrl,
      bool passIdentity});
}

/// @nodoc
class __$NavButtonEntityCopyWithImpl<$Res>
    implements _$NavButtonEntityCopyWith<$Res> {
  __$NavButtonEntityCopyWithImpl(this._self, this._then);

  final _NavButtonEntity _self;
  final $Res Function(_NavButtonEntity) _then;

  /// Create a copy of NavButtonEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? destinationType = null,
    Object? destinationValue = null,
    Object? iconType = null,
    Object? iconKey = freezed,
    Object? accentColor = freezed,
    Object? customIconActiveUrl = freezed,
    Object? customIconInactiveUrl = freezed,
    Object? passIdentity = null,
  }) {
    return _then(_NavButtonEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      destinationType: null == destinationType
          ? _self.destinationType
          : destinationType // ignore: cast_nullable_to_non_nullable
              as NavButtonDestinationType,
      destinationValue: null == destinationValue
          ? _self.destinationValue
          : destinationValue // ignore: cast_nullable_to_non_nullable
              as String,
      iconType: null == iconType
          ? _self.iconType
          : iconType // ignore: cast_nullable_to_non_nullable
              as NavButtonIconType,
      iconKey: freezed == iconKey
          ? _self.iconKey
          : iconKey // ignore: cast_nullable_to_non_nullable
              as String?,
      accentColor: freezed == accentColor
          ? _self.accentColor
          : accentColor // ignore: cast_nullable_to_non_nullable
              as String?,
      customIconActiveUrl: freezed == customIconActiveUrl
          ? _self.customIconActiveUrl
          : customIconActiveUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      customIconInactiveUrl: freezed == customIconInactiveUrl
          ? _self.customIconInactiveUrl
          : customIconInactiveUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      passIdentity: null == passIdentity
          ? _self.passIdentity
          : passIdentity // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
