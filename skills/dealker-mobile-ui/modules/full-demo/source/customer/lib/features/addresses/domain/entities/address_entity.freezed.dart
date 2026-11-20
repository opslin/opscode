// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'address_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AddressEntity {
  String get id;
  String get label;
  String get name;
  String get phone;
  String get addressLine1;
  String get city;
  String get state;
  String get pincode;
  double get latitude;
  double get longitude;
  String? get addressLine2;
  String? get receiverName;
  String? get receiverPhone;
  bool get isDefault;

  /// Create a copy of AddressEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AddressEntityCopyWith<AddressEntity> get copyWith =>
      _$AddressEntityCopyWithImpl<AddressEntity>(
          this as AddressEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AddressEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.addressLine1, addressLine1) ||
                other.addressLine1 == addressLine1) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.pincode, pincode) || other.pincode == pincode) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.addressLine2, addressLine2) ||
                other.addressLine2 == addressLine2) &&
            (identical(other.receiverName, receiverName) ||
                other.receiverName == receiverName) &&
            (identical(other.receiverPhone, receiverPhone) ||
                other.receiverPhone == receiverPhone) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      label,
      name,
      phone,
      addressLine1,
      city,
      state,
      pincode,
      latitude,
      longitude,
      addressLine2,
      receiverName,
      receiverPhone,
      isDefault);

  @override
  String toString() {
    return 'AddressEntity(id: $id, label: $label, name: $name, phone: $phone, addressLine1: $addressLine1, city: $city, state: $state, pincode: $pincode, latitude: $latitude, longitude: $longitude, addressLine2: $addressLine2, receiverName: $receiverName, receiverPhone: $receiverPhone, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class $AddressEntityCopyWith<$Res> {
  factory $AddressEntityCopyWith(
          AddressEntity value, $Res Function(AddressEntity) _then) =
      _$AddressEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String label,
      String name,
      String phone,
      String addressLine1,
      String city,
      String state,
      String pincode,
      double latitude,
      double longitude,
      String? addressLine2,
      String? receiverName,
      String? receiverPhone,
      bool isDefault});
}

/// @nodoc
class _$AddressEntityCopyWithImpl<$Res>
    implements $AddressEntityCopyWith<$Res> {
  _$AddressEntityCopyWithImpl(this._self, this._then);

  final AddressEntity _self;
  final $Res Function(AddressEntity) _then;

  /// Create a copy of AddressEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? name = null,
    Object? phone = null,
    Object? addressLine1 = null,
    Object? city = null,
    Object? state = null,
    Object? pincode = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? addressLine2 = freezed,
    Object? receiverName = freezed,
    Object? receiverPhone = freezed,
    Object? isDefault = null,
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
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      addressLine1: null == addressLine1
          ? _self.addressLine1
          : addressLine1 // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _self.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      pincode: null == pincode
          ? _self.pincode
          : pincode // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      addressLine2: freezed == addressLine2
          ? _self.addressLine2
          : addressLine2 // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverName: freezed == receiverName
          ? _self.receiverName
          : receiverName // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverPhone: freezed == receiverPhone
          ? _self.receiverPhone
          : receiverPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [AddressEntity].
extension AddressEntityPatterns on AddressEntity {
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
    TResult Function(_AddressEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AddressEntity() when $default != null:
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
    TResult Function(_AddressEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddressEntity():
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
    TResult? Function(_AddressEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddressEntity() when $default != null:
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
            String name,
            String phone,
            String addressLine1,
            String city,
            String state,
            String pincode,
            double latitude,
            double longitude,
            String? addressLine2,
            String? receiverName,
            String? receiverPhone,
            bool isDefault)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AddressEntity() when $default != null:
        return $default(
            _that.id,
            _that.label,
            _that.name,
            _that.phone,
            _that.addressLine1,
            _that.city,
            _that.state,
            _that.pincode,
            _that.latitude,
            _that.longitude,
            _that.addressLine2,
            _that.receiverName,
            _that.receiverPhone,
            _that.isDefault);
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
            String name,
            String phone,
            String addressLine1,
            String city,
            String state,
            String pincode,
            double latitude,
            double longitude,
            String? addressLine2,
            String? receiverName,
            String? receiverPhone,
            bool isDefault)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddressEntity():
        return $default(
            _that.id,
            _that.label,
            _that.name,
            _that.phone,
            _that.addressLine1,
            _that.city,
            _that.state,
            _that.pincode,
            _that.latitude,
            _that.longitude,
            _that.addressLine2,
            _that.receiverName,
            _that.receiverPhone,
            _that.isDefault);
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
            String name,
            String phone,
            String addressLine1,
            String city,
            String state,
            String pincode,
            double latitude,
            double longitude,
            String? addressLine2,
            String? receiverName,
            String? receiverPhone,
            bool isDefault)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddressEntity() when $default != null:
        return $default(
            _that.id,
            _that.label,
            _that.name,
            _that.phone,
            _that.addressLine1,
            _that.city,
            _that.state,
            _that.pincode,
            _that.latitude,
            _that.longitude,
            _that.addressLine2,
            _that.receiverName,
            _that.receiverPhone,
            _that.isDefault);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AddressEntity implements AddressEntity {
  const _AddressEntity(
      {required this.id,
      required this.label,
      required this.name,
      required this.phone,
      required this.addressLine1,
      required this.city,
      required this.state,
      required this.pincode,
      required this.latitude,
      required this.longitude,
      this.addressLine2,
      this.receiverName,
      this.receiverPhone,
      this.isDefault = false});

  @override
  final String id;
  @override
  final String label;
  @override
  final String name;
  @override
  final String phone;
  @override
  final String addressLine1;
  @override
  final String city;
  @override
  final String state;
  @override
  final String pincode;
  @override
  final double latitude;
  @override
  final double longitude;
  @override
  final String? addressLine2;
  @override
  final String? receiverName;
  @override
  final String? receiverPhone;
  @override
  @JsonKey()
  final bool isDefault;

  /// Create a copy of AddressEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AddressEntityCopyWith<_AddressEntity> get copyWith =>
      __$AddressEntityCopyWithImpl<_AddressEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AddressEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.addressLine1, addressLine1) ||
                other.addressLine1 == addressLine1) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.pincode, pincode) || other.pincode == pincode) &&
            (identical(other.latitude, latitude) ||
                other.latitude == latitude) &&
            (identical(other.longitude, longitude) ||
                other.longitude == longitude) &&
            (identical(other.addressLine2, addressLine2) ||
                other.addressLine2 == addressLine2) &&
            (identical(other.receiverName, receiverName) ||
                other.receiverName == receiverName) &&
            (identical(other.receiverPhone, receiverPhone) ||
                other.receiverPhone == receiverPhone) &&
            (identical(other.isDefault, isDefault) ||
                other.isDefault == isDefault));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      label,
      name,
      phone,
      addressLine1,
      city,
      state,
      pincode,
      latitude,
      longitude,
      addressLine2,
      receiverName,
      receiverPhone,
      isDefault);

  @override
  String toString() {
    return 'AddressEntity(id: $id, label: $label, name: $name, phone: $phone, addressLine1: $addressLine1, city: $city, state: $state, pincode: $pincode, latitude: $latitude, longitude: $longitude, addressLine2: $addressLine2, receiverName: $receiverName, receiverPhone: $receiverPhone, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class _$AddressEntityCopyWith<$Res>
    implements $AddressEntityCopyWith<$Res> {
  factory _$AddressEntityCopyWith(
          _AddressEntity value, $Res Function(_AddressEntity) _then) =
      __$AddressEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String label,
      String name,
      String phone,
      String addressLine1,
      String city,
      String state,
      String pincode,
      double latitude,
      double longitude,
      String? addressLine2,
      String? receiverName,
      String? receiverPhone,
      bool isDefault});
}

/// @nodoc
class __$AddressEntityCopyWithImpl<$Res>
    implements _$AddressEntityCopyWith<$Res> {
  __$AddressEntityCopyWithImpl(this._self, this._then);

  final _AddressEntity _self;
  final $Res Function(_AddressEntity) _then;

  /// Create a copy of AddressEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? name = null,
    Object? phone = null,
    Object? addressLine1 = null,
    Object? city = null,
    Object? state = null,
    Object? pincode = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? addressLine2 = freezed,
    Object? receiverName = freezed,
    Object? receiverPhone = freezed,
    Object? isDefault = null,
  }) {
    return _then(_AddressEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      addressLine1: null == addressLine1
          ? _self.addressLine1
          : addressLine1 // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _self.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
              as String,
      pincode: null == pincode
          ? _self.pincode
          : pincode // ignore: cast_nullable_to_non_nullable
              as String,
      latitude: null == latitude
          ? _self.latitude
          : latitude // ignore: cast_nullable_to_non_nullable
              as double,
      longitude: null == longitude
          ? _self.longitude
          : longitude // ignore: cast_nullable_to_non_nullable
              as double,
      addressLine2: freezed == addressLine2
          ? _self.addressLine2
          : addressLine2 // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverName: freezed == receiverName
          ? _self.receiverName
          : receiverName // ignore: cast_nullable_to_non_nullable
              as String?,
      receiverPhone: freezed == receiverPhone
          ? _self.receiverPhone
          : receiverPhone // ignore: cast_nullable_to_non_nullable
              as String?,
      isDefault: null == isDefault
          ? _self.isDefault
          : isDefault // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
