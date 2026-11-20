// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'notification_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$NotificationEntity {
  String get id;
  String get type;
  String get title;
  String get body;
  DateTime get createdAt;
  bool get isRead;
  DateTime? get readAt;
  String? get imageUrl;
  String? get deepLink;
  Map<String, dynamic> get data;

  /// Create a copy of NotificationEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $NotificationEntityCopyWith<NotificationEntity> get copyWith =>
      _$NotificationEntityCopyWithImpl<NotificationEntity>(
          this as NotificationEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is NotificationEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.readAt, readAt) || other.readAt == readAt) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.deepLink, deepLink) ||
                other.deepLink == deepLink) &&
            const DeepCollectionEquality().equals(other.data, data));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      title,
      body,
      createdAt,
      isRead,
      readAt,
      imageUrl,
      deepLink,
      const DeepCollectionEquality().hash(data));

  @override
  String toString() {
    return 'NotificationEntity(id: $id, type: $type, title: $title, body: $body, createdAt: $createdAt, isRead: $isRead, readAt: $readAt, imageUrl: $imageUrl, deepLink: $deepLink, data: $data)';
  }
}

/// @nodoc
abstract mixin class $NotificationEntityCopyWith<$Res> {
  factory $NotificationEntityCopyWith(
          NotificationEntity value, $Res Function(NotificationEntity) _then) =
      _$NotificationEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String type,
      String title,
      String body,
      DateTime createdAt,
      bool isRead,
      DateTime? readAt,
      String? imageUrl,
      String? deepLink,
      Map<String, dynamic> data});
}

/// @nodoc
class _$NotificationEntityCopyWithImpl<$Res>
    implements $NotificationEntityCopyWith<$Res> {
  _$NotificationEntityCopyWithImpl(this._self, this._then);

  final NotificationEntity _self;
  final $Res Function(NotificationEntity) _then;

  /// Create a copy of NotificationEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? body = null,
    Object? createdAt = null,
    Object? isRead = null,
    Object? readAt = freezed,
    Object? imageUrl = freezed,
    Object? deepLink = freezed,
    Object? data = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRead: null == isRead
          ? _self.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      readAt: freezed == readAt
          ? _self.readAt
          : readAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      deepLink: freezed == deepLink
          ? _self.deepLink
          : deepLink // ignore: cast_nullable_to_non_nullable
              as String?,
      data: null == data
          ? _self.data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

/// Adds pattern-matching-related methods to [NotificationEntity].
extension NotificationEntityPatterns on NotificationEntity {
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
    TResult Function(_NotificationEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NotificationEntity() when $default != null:
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
    TResult Function(_NotificationEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationEntity():
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
    TResult? Function(_NotificationEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationEntity() when $default != null:
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
            String type,
            String title,
            String body,
            DateTime createdAt,
            bool isRead,
            DateTime? readAt,
            String? imageUrl,
            String? deepLink,
            Map<String, dynamic> data)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _NotificationEntity() when $default != null:
        return $default(
            _that.id,
            _that.type,
            _that.title,
            _that.body,
            _that.createdAt,
            _that.isRead,
            _that.readAt,
            _that.imageUrl,
            _that.deepLink,
            _that.data);
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
            String type,
            String title,
            String body,
            DateTime createdAt,
            bool isRead,
            DateTime? readAt,
            String? imageUrl,
            String? deepLink,
            Map<String, dynamic> data)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationEntity():
        return $default(
            _that.id,
            _that.type,
            _that.title,
            _that.body,
            _that.createdAt,
            _that.isRead,
            _that.readAt,
            _that.imageUrl,
            _that.deepLink,
            _that.data);
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
            String type,
            String title,
            String body,
            DateTime createdAt,
            bool isRead,
            DateTime? readAt,
            String? imageUrl,
            String? deepLink,
            Map<String, dynamic> data)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _NotificationEntity() when $default != null:
        return $default(
            _that.id,
            _that.type,
            _that.title,
            _that.body,
            _that.createdAt,
            _that.isRead,
            _that.readAt,
            _that.imageUrl,
            _that.deepLink,
            _that.data);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _NotificationEntity extends NotificationEntity {
  const _NotificationEntity(
      {required this.id,
      required this.type,
      required this.title,
      required this.body,
      required this.createdAt,
      this.isRead = false,
      this.readAt,
      this.imageUrl,
      this.deepLink,
      final Map<String, dynamic> data = const <String, dynamic>{}})
      : _data = data,
        super._();

  @override
  final String id;
  @override
  final String type;
  @override
  final String title;
  @override
  final String body;
  @override
  final DateTime createdAt;
  @override
  @JsonKey()
  final bool isRead;
  @override
  final DateTime? readAt;
  @override
  final String? imageUrl;
  @override
  final String? deepLink;
  final Map<String, dynamic> _data;
  @override
  @JsonKey()
  Map<String, dynamic> get data {
    if (_data is EqualUnmodifiableMapView) return _data;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_data);
  }

  /// Create a copy of NotificationEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$NotificationEntityCopyWith<_NotificationEntity> get copyWith =>
      __$NotificationEntityCopyWithImpl<_NotificationEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _NotificationEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.title, title) || other.title == title) &&
            (identical(other.body, body) || other.body == body) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.isRead, isRead) || other.isRead == isRead) &&
            (identical(other.readAt, readAt) || other.readAt == readAt) &&
            (identical(other.imageUrl, imageUrl) ||
                other.imageUrl == imageUrl) &&
            (identical(other.deepLink, deepLink) ||
                other.deepLink == deepLink) &&
            const DeepCollectionEquality().equals(other._data, _data));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      type,
      title,
      body,
      createdAt,
      isRead,
      readAt,
      imageUrl,
      deepLink,
      const DeepCollectionEquality().hash(_data));

  @override
  String toString() {
    return 'NotificationEntity(id: $id, type: $type, title: $title, body: $body, createdAt: $createdAt, isRead: $isRead, readAt: $readAt, imageUrl: $imageUrl, deepLink: $deepLink, data: $data)';
  }
}

/// @nodoc
abstract mixin class _$NotificationEntityCopyWith<$Res>
    implements $NotificationEntityCopyWith<$Res> {
  factory _$NotificationEntityCopyWith(
          _NotificationEntity value, $Res Function(_NotificationEntity) _then) =
      __$NotificationEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String type,
      String title,
      String body,
      DateTime createdAt,
      bool isRead,
      DateTime? readAt,
      String? imageUrl,
      String? deepLink,
      Map<String, dynamic> data});
}

/// @nodoc
class __$NotificationEntityCopyWithImpl<$Res>
    implements _$NotificationEntityCopyWith<$Res> {
  __$NotificationEntityCopyWithImpl(this._self, this._then);

  final _NotificationEntity _self;
  final $Res Function(_NotificationEntity) _then;

  /// Create a copy of NotificationEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? type = null,
    Object? title = null,
    Object? body = null,
    Object? createdAt = null,
    Object? isRead = null,
    Object? readAt = freezed,
    Object? imageUrl = freezed,
    Object? deepLink = freezed,
    Object? data = null,
  }) {
    return _then(_NotificationEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as String,
      title: null == title
          ? _self.title
          : title // ignore: cast_nullable_to_non_nullable
              as String,
      body: null == body
          ? _self.body
          : body // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      isRead: null == isRead
          ? _self.isRead
          : isRead // ignore: cast_nullable_to_non_nullable
              as bool,
      readAt: freezed == readAt
          ? _self.readAt
          : readAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      imageUrl: freezed == imageUrl
          ? _self.imageUrl
          : imageUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      deepLink: freezed == deepLink
          ? _self.deepLink
          : deepLink // ignore: cast_nullable_to_non_nullable
              as String?,
      data: null == data
          ? _self._data
          : data // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
    ));
  }
}

// dart format on
