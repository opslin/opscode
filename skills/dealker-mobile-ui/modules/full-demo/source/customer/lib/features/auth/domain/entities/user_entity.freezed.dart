// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserEntity {
  String get id;
  String get phone;
  String get role;
  String? get name;
  String? get email;
  String? get avatarUrl;
  int? get loyaltyPoints;
  String? get referralCode;

  /// 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED' — null when the
  /// user has never applied for a business (B2B/wholesale) account.
  String? get b2bStatus;

  /// Whether the customer has switched B2B pricing on. Only meaningful
  /// (and only ever true) when [b2bStatus] is 'APPROVED'.
  bool? get b2bEnabled;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserEntityCopyWith<UserEntity> get copyWith =>
      _$UserEntityCopyWithImpl<UserEntity>(this as UserEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is UserEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.loyaltyPoints, loyaltyPoints) ||
                other.loyaltyPoints == loyaltyPoints) &&
            (identical(other.referralCode, referralCode) ||
                other.referralCode == referralCode) &&
            (identical(other.b2bStatus, b2bStatus) ||
                other.b2bStatus == b2bStatus) &&
            (identical(other.b2bEnabled, b2bEnabled) ||
                other.b2bEnabled == b2bEnabled));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, phone, role, name, email,
      avatarUrl, loyaltyPoints, referralCode, b2bStatus, b2bEnabled);

  @override
  String toString() {
    return 'UserEntity(id: $id, phone: $phone, role: $role, name: $name, email: $email, avatarUrl: $avatarUrl, loyaltyPoints: $loyaltyPoints, referralCode: $referralCode, b2bStatus: $b2bStatus, b2bEnabled: $b2bEnabled)';
  }
}

/// @nodoc
abstract mixin class $UserEntityCopyWith<$Res> {
  factory $UserEntityCopyWith(
          UserEntity value, $Res Function(UserEntity) _then) =
      _$UserEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String phone,
      String role,
      String? name,
      String? email,
      String? avatarUrl,
      int? loyaltyPoints,
      String? referralCode,
      String? b2bStatus,
      bool? b2bEnabled});
}

/// @nodoc
class _$UserEntityCopyWithImpl<$Res> implements $UserEntityCopyWith<$Res> {
  _$UserEntityCopyWithImpl(this._self, this._then);

  final UserEntity _self;
  final $Res Function(UserEntity) _then;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? phone = null,
    Object? role = null,
    Object? name = freezed,
    Object? email = freezed,
    Object? avatarUrl = freezed,
    Object? loyaltyPoints = freezed,
    Object? referralCode = freezed,
    Object? b2bStatus = freezed,
    Object? b2bEnabled = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _self.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      loyaltyPoints: freezed == loyaltyPoints
          ? _self.loyaltyPoints
          : loyaltyPoints // ignore: cast_nullable_to_non_nullable
              as int?,
      referralCode: freezed == referralCode
          ? _self.referralCode
          : referralCode // ignore: cast_nullable_to_non_nullable
              as String?,
      b2bStatus: freezed == b2bStatus
          ? _self.b2bStatus
          : b2bStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      b2bEnabled: freezed == b2bEnabled
          ? _self.b2bEnabled
          : b2bEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

/// Adds pattern-matching-related methods to [UserEntity].
extension UserEntityPatterns on UserEntity {
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
    TResult Function(_UserEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserEntity() when $default != null:
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
    TResult Function(_UserEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserEntity():
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
    TResult? Function(_UserEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserEntity() when $default != null:
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
            String phone,
            String role,
            String? name,
            String? email,
            String? avatarUrl,
            int? loyaltyPoints,
            String? referralCode,
            String? b2bStatus,
            bool? b2bEnabled)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _UserEntity() when $default != null:
        return $default(
            _that.id,
            _that.phone,
            _that.role,
            _that.name,
            _that.email,
            _that.avatarUrl,
            _that.loyaltyPoints,
            _that.referralCode,
            _that.b2bStatus,
            _that.b2bEnabled);
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
            String phone,
            String role,
            String? name,
            String? email,
            String? avatarUrl,
            int? loyaltyPoints,
            String? referralCode,
            String? b2bStatus,
            bool? b2bEnabled)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserEntity():
        return $default(
            _that.id,
            _that.phone,
            _that.role,
            _that.name,
            _that.email,
            _that.avatarUrl,
            _that.loyaltyPoints,
            _that.referralCode,
            _that.b2bStatus,
            _that.b2bEnabled);
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
            String phone,
            String role,
            String? name,
            String? email,
            String? avatarUrl,
            int? loyaltyPoints,
            String? referralCode,
            String? b2bStatus,
            bool? b2bEnabled)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _UserEntity() when $default != null:
        return $default(
            _that.id,
            _that.phone,
            _that.role,
            _that.name,
            _that.email,
            _that.avatarUrl,
            _that.loyaltyPoints,
            _that.referralCode,
            _that.b2bStatus,
            _that.b2bEnabled);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _UserEntity extends UserEntity {
  const _UserEntity(
      {required this.id,
      required this.phone,
      required this.role,
      this.name,
      this.email,
      this.avatarUrl,
      this.loyaltyPoints,
      this.referralCode,
      this.b2bStatus,
      this.b2bEnabled})
      : super._();

  @override
  final String id;
  @override
  final String phone;
  @override
  final String role;
  @override
  final String? name;
  @override
  final String? email;
  @override
  final String? avatarUrl;
  @override
  final int? loyaltyPoints;
  @override
  final String? referralCode;

  /// 'PENDING' | 'APPROVED' | 'REJECTED' | 'SUSPENDED' — null when the
  /// user has never applied for a business (B2B/wholesale) account.
  @override
  final String? b2bStatus;

  /// Whether the customer has switched B2B pricing on. Only meaningful
  /// (and only ever true) when [b2bStatus] is 'APPROVED'.
  @override
  final bool? b2bEnabled;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$UserEntityCopyWith<_UserEntity> get copyWith =>
      __$UserEntityCopyWithImpl<_UserEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _UserEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.avatarUrl, avatarUrl) ||
                other.avatarUrl == avatarUrl) &&
            (identical(other.loyaltyPoints, loyaltyPoints) ||
                other.loyaltyPoints == loyaltyPoints) &&
            (identical(other.referralCode, referralCode) ||
                other.referralCode == referralCode) &&
            (identical(other.b2bStatus, b2bStatus) ||
                other.b2bStatus == b2bStatus) &&
            (identical(other.b2bEnabled, b2bEnabled) ||
                other.b2bEnabled == b2bEnabled));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, phone, role, name, email,
      avatarUrl, loyaltyPoints, referralCode, b2bStatus, b2bEnabled);

  @override
  String toString() {
    return 'UserEntity(id: $id, phone: $phone, role: $role, name: $name, email: $email, avatarUrl: $avatarUrl, loyaltyPoints: $loyaltyPoints, referralCode: $referralCode, b2bStatus: $b2bStatus, b2bEnabled: $b2bEnabled)';
  }
}

/// @nodoc
abstract mixin class _$UserEntityCopyWith<$Res>
    implements $UserEntityCopyWith<$Res> {
  factory _$UserEntityCopyWith(
          _UserEntity value, $Res Function(_UserEntity) _then) =
      __$UserEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String phone,
      String role,
      String? name,
      String? email,
      String? avatarUrl,
      int? loyaltyPoints,
      String? referralCode,
      String? b2bStatus,
      bool? b2bEnabled});
}

/// @nodoc
class __$UserEntityCopyWithImpl<$Res> implements _$UserEntityCopyWith<$Res> {
  __$UserEntityCopyWithImpl(this._self, this._then);

  final _UserEntity _self;
  final $Res Function(_UserEntity) _then;

  /// Create a copy of UserEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? phone = null,
    Object? role = null,
    Object? name = freezed,
    Object? email = freezed,
    Object? avatarUrl = freezed,
    Object? loyaltyPoints = freezed,
    Object? referralCode = freezed,
    Object? b2bStatus = freezed,
    Object? b2bEnabled = freezed,
  }) {
    return _then(_UserEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      name: freezed == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String?,
      email: freezed == email
          ? _self.email
          : email // ignore: cast_nullable_to_non_nullable
              as String?,
      avatarUrl: freezed == avatarUrl
          ? _self.avatarUrl
          : avatarUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      loyaltyPoints: freezed == loyaltyPoints
          ? _self.loyaltyPoints
          : loyaltyPoints // ignore: cast_nullable_to_non_nullable
              as int?,
      referralCode: freezed == referralCode
          ? _self.referralCode
          : referralCode // ignore: cast_nullable_to_non_nullable
              as String?,
      b2bStatus: freezed == b2bStatus
          ? _self.b2bStatus
          : b2bStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      b2bEnabled: freezed == b2bEnabled
          ? _self.b2bEnabled
          : b2bEnabled // ignore: cast_nullable_to_non_nullable
              as bool?,
    ));
  }
}

// dart format on
