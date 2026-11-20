// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'banner_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BannerEntity {
  String get id;
  String get imageUrl;
  String get linkType;
  int get sortOrder;
  String? get title;
  String? get subtitle;
  String? get linkValue;

  /// Create a copy of BannerEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BannerEntityCopyWith<BannerEntity> get copyWith =>
      _$BannerEntityCopyWithImpl<BannerEntity>(
          this as BannerEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BannerEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.linkType, linkType) ||
                other.linkType == linkType) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.linkValue, linkValue) ||
                other.linkValue == linkValue));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, imageUrl, linkType,
      sortOrder, title, subtitle, linkValue);

  @override
  String toString() {
    return 'BannerEntity(id: $id, imageUrl: $imageUrl, linkType: $linkType, sortOrder: $sortOrder, title: $title, subtitle: $subtitle, linkValue: $linkValue)';
  }
}

/// @nodoc
abstract mixin class $BannerEntityCopyWith<$Res> {
  factory $BannerEntityCopyWith(
          BannerEntity value, $Res Function(BannerEntity) _then) =
      _$BannerEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String imageUrl,
      String linkType,
      int sortOrder,
      String? title,
      String? subtitle,
      String? linkValue});
}

/// @nodoc
class _$BannerEntityCopyWithImpl<$Res> implements $BannerEntityCopyWith<$Res> {
  _$BannerEntityCopyWithImpl(this._self, this._then);

  final BannerEntity _self;
  final $Res Function(BannerEntity) _then;

  /// Create a copy of BannerEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? imageUrl = null,
    Object? linkType = null,
    Object? sortOrder = null,
    Object? title = freezed,
    Object? subtitle = freezed,
    Object? linkValue = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: null == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String,
      linkType: null == linkType
          ? _self.linkType
          : linkType // ignore: cast_nullable_to_non_nullable
              as String,
      sortOrder: null == sortOrder
          ? _self.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      subtitle: freezed == subtitle
          ? _self.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String?,
      linkValue: freezed == linkValue
          ? _self.linkValue
          : linkValue // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [BannerEntity].
extension BannerEntityPatterns on BannerEntity {
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
    TResult Function(_BannerEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BannerEntity() when $default != null:
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
    TResult Function(_BannerEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BannerEntity():
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
    TResult? Function(_BannerEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BannerEntity() when $default != null:
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
    TResult Function(String id, String imageUrl, String linkType, int sortOrder,
            String? title, String? subtitle, String? linkValue)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BannerEntity() when $default != null:
        return $default(_that.id, _that.imageUrl, _that.linkType,
            _that.sortOrder, _that.title, _that.subtitle, _that.linkValue);
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
    TResult Function(String id, String imageUrl, String linkType, int sortOrder,
            String? title, String? subtitle, String? linkValue)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BannerEntity():
        return $default(_that.id, _that.imageUrl, _that.linkType,
            _that.sortOrder, _that.title, _that.subtitle, _that.linkValue);
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
    TResult? Function(String id, String imageUrl, String linkType,
            int sortOrder, String? title, String? subtitle, String? linkValue)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BannerEntity() when $default != null:
        return $default(_that.id, _that.imageUrl, _that.linkType,
            _that.sortOrder, _that.title, _that.subtitle, _that.linkValue);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _BannerEntity implements BannerEntity {
  const _BannerEntity(
      {required this.id,
      required this.imageUrl,
      required this.linkType,
      required this.sortOrder,
      this.title,
      this.subtitle,
      this.linkValue});

  @override
  final String id;
  @override
  final String imageUrl;
  @override
  final String linkType;
  @override
  final int sortOrder;
  @override
  final String? title;
  @override
  final String? subtitle;
  @override
  final String? linkValue;

  /// Create a copy of BannerEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BannerEntityCopyWith<_BannerEntity> get copyWith =>
      __$BannerEntityCopyWithImpl<_BannerEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BannerEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.linkType, linkType) ||
                other.linkType == linkType) &&
            (identical(other.sortOrder, sortOrder) ||
                other.sortOrder == sortOrder) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.subtitle, subtitle) ||
                other.subtitle == subtitle) &&
            (identical(other.linkValue, linkValue) ||
                other.linkValue == linkValue));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, imageUrl, linkType,
      sortOrder, title, subtitle, linkValue);

  @override
  String toString() {
    return 'BannerEntity(id: $id, imageUrl: $imageUrl, linkType: $linkType, sortOrder: $sortOrder, title: $title, subtitle: $subtitle, linkValue: $linkValue)';
  }
}

/// @nodoc
abstract mixin class _$BannerEntityCopyWith<$Res>
    implements $BannerEntityCopyWith<$Res> {
  factory _$BannerEntityCopyWith(
          _BannerEntity value, $Res Function(_BannerEntity) _then) =
      __$BannerEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String imageUrl,
      String linkType,
      int sortOrder,
      String? title,
      String? subtitle,
      String? linkValue});
}

/// @nodoc
class __$BannerEntityCopyWithImpl<$Res>
    implements _$BannerEntityCopyWith<$Res> {
  __$BannerEntityCopyWithImpl(this._self, this._then);

  final _BannerEntity _self;
  final $Res Function(_BannerEntity) _then;

  /// Create a copy of BannerEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? imageUrl = null,
    Object? linkType = null,
    Object? sortOrder = null,
    Object? title = freezed,
    Object? subtitle = freezed,
    Object? linkValue = freezed,
  }) {
    return _then(_BannerEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      imageUrl: null == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String,
      linkType: null == linkType
          ? _self.linkType
          : linkType // ignore: cast_nullable_to_non_nullable
              as String,
      sortOrder: null == sortOrder
          ? _self.sortOrder
          : sortOrder // ignore: cast_nullable_to_non_nullable
              as int,
      title: freezed == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String?,
      subtitle: freezed == subtitle
          ? _self.subtitle
          : subtitle // ignore: cast_nullable_to_non_nullable
              as String?,
      linkValue: freezed == linkValue
          ? _self.linkValue
          : linkValue // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
