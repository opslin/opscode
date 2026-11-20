// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'address_model.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AddressModel {
  String get id;
  String get addressLine1;
  String get city;
  String get pincode;
  String get label;
  String get state;
  @JsonKey(name: 'lat', fromJson: _addressDoubleFromJson)
  double get latitude;
  @JsonKey(name: 'lng', fromJson: _addressDoubleFromJson)
  double get longitude;
  String? get addressLine2;
  String? get receiverName;
  String? get receiverPhone;
  @JsonKey(name: 'isDefault')
  bool get isDefault;

  /// Create a copy of AddressModel
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AddressModelCopyWith<AddressModel> get copyWith =>
      _$AddressModelCopyWithImpl<AddressModel>(
          this as AddressModel, _$identity);

  /// Serializes this AddressModel to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AddressModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.addressLine1, addressLine1) ||
                other.addressLine1 == addressLine1) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.pincode, pincode) || other.pincode == pincode) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.state, state) || other.state == state) &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      addressLine1,
      city,
      pincode,
      label,
      state,
      latitude,
      longitude,
      addressLine2,
      receiverName,
      receiverPhone,
      isDefault);

  @override
  String toString() {
    return 'AddressModel(id: $id, addressLine1: $addressLine1, city: $city, pincode: $pincode, label: $label, state: $state, latitude: $latitude, longitude: $longitude, addressLine2: $addressLine2, receiverName: $receiverName, receiverPhone: $receiverPhone, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class $AddressModelCopyWith<$Res> {
  factory $AddressModelCopyWith(
          AddressModel value, $Res Function(AddressModel) _then) =
      _$AddressModelCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String addressLine1,
      String city,
      String pincode,
      String label,
      String state,
      @JsonKey(name: 'lat', fromJson: _addressDoubleFromJson) double latitude,
      @JsonKey(name: 'lng', fromJson: _addressDoubleFromJson) double longitude,
      String? addressLine2,
      String? receiverName,
      String? receiverPhone,
      @JsonKey(name: 'isDefault') bool isDefault});
}

/// @nodoc
class _$AddressModelCopyWithImpl<$Res> implements $AddressModelCopyWith<$Res> {
  _$AddressModelCopyWithImpl(this._self, this._then);

  final AddressModel _self;
  final $Res Function(AddressModel) _then;

  /// Create a copy of AddressModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? addressLine1 = null,
    Object? city = null,
    Object? pincode = null,
    Object? label = null,
    Object? state = null,
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
      addressLine1: null == addressLine1
          ? _self.addressLine1
          : addressLine1 // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _self.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      pincode: null == pincode
          ? _self.pincode
          : pincode // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
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

/// Adds pattern-matching-related methods to [AddressModel].
extension AddressModelPatterns on AddressModel {
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
    TResult Function(_AddressModel value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AddressModel() when $default != null:
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
    TResult Function(_AddressModel value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddressModel():
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
    TResult? Function(_AddressModel value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddressModel() when $default != null:
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
            String addressLine1,
            String city,
            String pincode,
            String label,
            String state,
            @JsonKey(name: 'lat', fromJson: _addressDoubleFromJson)
            double latitude,
            @JsonKey(name: 'lng', fromJson: _addressDoubleFromJson)
            double longitude,
            String? addressLine2,
            String? receiverName,
            String? receiverPhone,
            @JsonKey(name: 'isDefault') bool isDefault)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AddressModel() when $default != null:
        return $default(
            _that.id,
            _that.addressLine1,
            _that.city,
            _that.pincode,
            _that.label,
            _that.state,
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
            String addressLine1,
            String city,
            String pincode,
            String label,
            String state,
            @JsonKey(name: 'lat', fromJson: _addressDoubleFromJson)
            double latitude,
            @JsonKey(name: 'lng', fromJson: _addressDoubleFromJson)
            double longitude,
            String? addressLine2,
            String? receiverName,
            String? receiverPhone,
            @JsonKey(name: 'isDefault') bool isDefault)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddressModel():
        return $default(
            _that.id,
            _that.addressLine1,
            _that.city,
            _that.pincode,
            _that.label,
            _that.state,
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
            String addressLine1,
            String city,
            String pincode,
            String label,
            String state,
            @JsonKey(name: 'lat', fromJson: _addressDoubleFromJson)
            double latitude,
            @JsonKey(name: 'lng', fromJson: _addressDoubleFromJson)
            double longitude,
            String? addressLine2,
            String? receiverName,
            String? receiverPhone,
            @JsonKey(name: 'isDefault') bool isDefault)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AddressModel() when $default != null:
        return $default(
            _that.id,
            _that.addressLine1,
            _that.city,
            _that.pincode,
            _that.label,
            _that.state,
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
@JsonSerializable()
class _AddressModel extends AddressModel {
  const _AddressModel(
      {required this.id,
      required this.addressLine1,
      required this.city,
      required this.pincode,
      this.label = 'Home',
      this.state = '',
      @JsonKey(name: 'lat', fromJson: _addressDoubleFromJson) this.latitude = 0,
      @JsonKey(name: 'lng', fromJson: _addressDoubleFromJson)
      this.longitude = 0,
      this.addressLine2,
      this.receiverName,
      this.receiverPhone,
      @JsonKey(name: 'isDefault') this.isDefault = false})
      : super._();
  factory _AddressModel.fromJson(Map<String, dynamic> json) =>
      _$AddressModelFromJson(json);

  @override
  final String id;
  @override
  final String addressLine1;
  @override
  final String city;
  @override
  final String pincode;
  @override
  @JsonKey()
  final String label;
  @override
  @JsonKey()
  final String state;
  @override
  @JsonKey(name: 'lat', fromJson: _addressDoubleFromJson)
  final double latitude;
  @override
  @JsonKey(name: 'lng', fromJson: _addressDoubleFromJson)
  final double longitude;
  @override
  final String? addressLine2;
  @override
  final String? receiverName;
  @override
  final String? receiverPhone;
  @override
  @JsonKey(name: 'isDefault')
  final bool isDefault;

  /// Create a copy of AddressModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AddressModelCopyWith<_AddressModel> get copyWith =>
      __$AddressModelCopyWithImpl<_AddressModel>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$AddressModelToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AddressModel &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.addressLine1, addressLine1) ||
                other.addressLine1 == addressLine1) &&
            (identical(other.city, city) || other.city == city) &&
            (identical(other.pincode, pincode) || other.pincode == pincode) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.state, state) || other.state == state) &&
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

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      addressLine1,
      city,
      pincode,
      label,
      state,
      latitude,
      longitude,
      addressLine2,
      receiverName,
      receiverPhone,
      isDefault);

  @override
  String toString() {
    return 'AddressModel(id: $id, addressLine1: $addressLine1, city: $city, pincode: $pincode, label: $label, state: $state, latitude: $latitude, longitude: $longitude, addressLine2: $addressLine2, receiverName: $receiverName, receiverPhone: $receiverPhone, isDefault: $isDefault)';
  }
}

/// @nodoc
abstract mixin class _$AddressModelCopyWith<$Res>
    implements $AddressModelCopyWith<$Res> {
  factory _$AddressModelCopyWith(
          _AddressModel value, $Res Function(_AddressModel) _then) =
      __$AddressModelCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String addressLine1,
      String city,
      String pincode,
      String label,
      String state,
      @JsonKey(name: 'lat', fromJson: _addressDoubleFromJson) double latitude,
      @JsonKey(name: 'lng', fromJson: _addressDoubleFromJson) double longitude,
      String? addressLine2,
      String? receiverName,
      String? receiverPhone,
      @JsonKey(name: 'isDefault') bool isDefault});
}

/// @nodoc
class __$AddressModelCopyWithImpl<$Res>
    implements _$AddressModelCopyWith<$Res> {
  __$AddressModelCopyWithImpl(this._self, this._then);

  final _AddressModel _self;
  final $Res Function(_AddressModel) _then;

  /// Create a copy of AddressModel
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? addressLine1 = null,
    Object? city = null,
    Object? pincode = null,
    Object? label = null,
    Object? state = null,
    Object? latitude = null,
    Object? longitude = null,
    Object? addressLine2 = freezed,
    Object? receiverName = freezed,
    Object? receiverPhone = freezed,
    Object? isDefault = null,
  }) {
    return _then(_AddressModel(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      addressLine1: null == addressLine1
          ? _self.addressLine1
          : addressLine1 // ignore: cast_nullable_to_non_nullable
              as String,
      city: null == city
          ? _self.city
          : city // ignore: cast_nullable_to_non_nullable
              as String,
      pincode: null == pincode
          ? _self.pincode
          : pincode // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      state: null == state
          ? _self.state
          : state // ignore: cast_nullable_to_non_nullable
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
