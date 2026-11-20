// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'checkout_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CheckoutState {
  AddressEntity? get selectedAddress;
  CouponEntity? get appliedCoupon;
  PaymentMethod get paymentMethod;
  CartValidationEntity? get validatedCart;
  CheckoutStep get currentStep;
  bool get isPlacingOrder;
  String? get errorMessage; // Delivery slot — null means ASAP (default)
  SelectedDeliverySlot?
      get selectedDeliverySlot; // Wallet-balance toggle — explicit opt-in only, same convention as
// Quick Delivery. Applies on top of `paymentMethod`, offsetting the
// total rather than replacing the method.
  bool get useWallet;

  /// Create a copy of CheckoutState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CheckoutStateCopyWith<CheckoutState> get copyWith =>
      _$CheckoutStateCopyWithImpl<CheckoutState>(
          this as CheckoutState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CheckoutState &&
            (identical(other.selectedAddress, selectedAddress) ||
                other.selectedAddress == selectedAddress) &&
            (identical(other.appliedCoupon, appliedCoupon) ||
                other.appliedCoupon == appliedCoupon) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.validatedCart, validatedCart) ||
                other.validatedCart == validatedCart) &&
            (identical(other.currentStep, currentStep) ||
                other.currentStep == currentStep) &&
            (identical(other.isPlacingOrder, isPlacingOrder) ||
                other.isPlacingOrder == isPlacingOrder) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.selectedDeliverySlot, selectedDeliverySlot) ||
                other.selectedDeliverySlot == selectedDeliverySlot) &&
            (identical(other.useWallet, useWallet) ||
                other.useWallet == useWallet));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      selectedAddress,
      appliedCoupon,
      paymentMethod,
      validatedCart,
      currentStep,
      isPlacingOrder,
      errorMessage,
      selectedDeliverySlot,
      useWallet);

  @override
  String toString() {
    return 'CheckoutState(selectedAddress: $selectedAddress, appliedCoupon: $appliedCoupon, paymentMethod: $paymentMethod, validatedCart: $validatedCart, currentStep: $currentStep, isPlacingOrder: $isPlacingOrder, errorMessage: $errorMessage, selectedDeliverySlot: $selectedDeliverySlot, useWallet: $useWallet)';
  }
}

/// @nodoc
abstract mixin class $CheckoutStateCopyWith<$Res> {
  factory $CheckoutStateCopyWith(
          CheckoutState value, $Res Function(CheckoutState) _then) =
      _$CheckoutStateCopyWithImpl;
  @useResult
  $Res call(
      {AddressEntity? selectedAddress,
      CouponEntity? appliedCoupon,
      PaymentMethod paymentMethod,
      CartValidationEntity? validatedCart,
      CheckoutStep currentStep,
      bool isPlacingOrder,
      String? errorMessage,
      SelectedDeliverySlot? selectedDeliverySlot,
      bool useWallet});

  $AddressEntityCopyWith<$Res>? get selectedAddress;
  $CouponEntityCopyWith<$Res>? get appliedCoupon;
}

/// @nodoc
class _$CheckoutStateCopyWithImpl<$Res>
    implements $CheckoutStateCopyWith<$Res> {
  _$CheckoutStateCopyWithImpl(this._self, this._then);

  final CheckoutState _self;
  final $Res Function(CheckoutState) _then;

  /// Create a copy of CheckoutState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedAddress = freezed,
    Object? appliedCoupon = freezed,
    Object? paymentMethod = null,
    Object? validatedCart = freezed,
    Object? currentStep = null,
    Object? isPlacingOrder = null,
    Object? errorMessage = freezed,
    Object? selectedDeliverySlot = freezed,
    Object? useWallet = null,
  }) {
    return _then(_self.copyWith(
      selectedAddress: freezed == selectedAddress
          ? _self.selectedAddress
          : selectedAddress // ignore: cast_nullable_to_non_nullable
              as AddressEntity?,
      appliedCoupon: freezed == appliedCoupon
          ? _self.appliedCoupon
          : appliedCoupon // ignore: cast_nullable_to_non_nullable
              as CouponEntity?,
      paymentMethod: null == paymentMethod
          ? _self.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as PaymentMethod,
      validatedCart: freezed == validatedCart
          ? _self.validatedCart
          : validatedCart // ignore: cast_nullable_to_non_nullable
              as CartValidationEntity?,
      currentStep: null == currentStep
          ? _self.currentStep
          : currentStep // ignore: cast_nullable_to_non_nullable
              as CheckoutStep,
      isPlacingOrder: null == isPlacingOrder
          ? _self.isPlacingOrder
          : isPlacingOrder // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      selectedDeliverySlot: freezed == selectedDeliverySlot
          ? _self.selectedDeliverySlot
          : selectedDeliverySlot // ignore: cast_nullable_to_non_nullable
              as SelectedDeliverySlot?,
      useWallet: null == useWallet
          ? _self.useWallet
          : useWallet // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of CheckoutState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AddressEntityCopyWith<$Res>? get selectedAddress {
    if (_self.selectedAddress == null) {
      return null;
    }

    return $AddressEntityCopyWith<$Res>(_self.selectedAddress!, (value) {
      return _then(_self.copyWith(selectedAddress: value));
    });
  }

  /// Create a copy of CheckoutState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CouponEntityCopyWith<$Res>? get appliedCoupon {
    if (_self.appliedCoupon == null) {
      return null;
    }

    return $CouponEntityCopyWith<$Res>(_self.appliedCoupon!, (value) {
      return _then(_self.copyWith(appliedCoupon: value));
    });
  }
}

/// Adds pattern-matching-related methods to [CheckoutState].
extension CheckoutStatePatterns on CheckoutState {
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
    TResult Function(_CheckoutState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CheckoutState() when $default != null:
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
    TResult Function(_CheckoutState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CheckoutState():
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
    TResult? Function(_CheckoutState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CheckoutState() when $default != null:
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
            AddressEntity? selectedAddress,
            CouponEntity? appliedCoupon,
            PaymentMethod paymentMethod,
            CartValidationEntity? validatedCart,
            CheckoutStep currentStep,
            bool isPlacingOrder,
            String? errorMessage,
            SelectedDeliverySlot? selectedDeliverySlot,
            bool useWallet)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CheckoutState() when $default != null:
        return $default(
            _that.selectedAddress,
            _that.appliedCoupon,
            _that.paymentMethod,
            _that.validatedCart,
            _that.currentStep,
            _that.isPlacingOrder,
            _that.errorMessage,
            _that.selectedDeliverySlot,
            _that.useWallet);
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
            AddressEntity? selectedAddress,
            CouponEntity? appliedCoupon,
            PaymentMethod paymentMethod,
            CartValidationEntity? validatedCart,
            CheckoutStep currentStep,
            bool isPlacingOrder,
            String? errorMessage,
            SelectedDeliverySlot? selectedDeliverySlot,
            bool useWallet)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CheckoutState():
        return $default(
            _that.selectedAddress,
            _that.appliedCoupon,
            _that.paymentMethod,
            _that.validatedCart,
            _that.currentStep,
            _that.isPlacingOrder,
            _that.errorMessage,
            _that.selectedDeliverySlot,
            _that.useWallet);
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
            AddressEntity? selectedAddress,
            CouponEntity? appliedCoupon,
            PaymentMethod paymentMethod,
            CartValidationEntity? validatedCart,
            CheckoutStep currentStep,
            bool isPlacingOrder,
            String? errorMessage,
            SelectedDeliverySlot? selectedDeliverySlot,
            bool useWallet)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CheckoutState() when $default != null:
        return $default(
            _that.selectedAddress,
            _that.appliedCoupon,
            _that.paymentMethod,
            _that.validatedCart,
            _that.currentStep,
            _that.isPlacingOrder,
            _that.errorMessage,
            _that.selectedDeliverySlot,
            _that.useWallet);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CheckoutState implements CheckoutState {
  const _CheckoutState(
      {this.selectedAddress,
      this.appliedCoupon,
      this.paymentMethod = PaymentMethod.online,
      this.validatedCart,
      this.currentStep = CheckoutStep.address,
      this.isPlacingOrder = false,
      this.errorMessage,
      this.selectedDeliverySlot,
      this.useWallet = false});

  @override
  final AddressEntity? selectedAddress;
  @override
  final CouponEntity? appliedCoupon;
  @override
  @JsonKey()
  final PaymentMethod paymentMethod;
  @override
  final CartValidationEntity? validatedCart;
  @override
  @JsonKey()
  final CheckoutStep currentStep;
  @override
  @JsonKey()
  final bool isPlacingOrder;
  @override
  final String? errorMessage;
// Delivery slot — null means ASAP (default)
  @override
  final SelectedDeliverySlot? selectedDeliverySlot;
// Wallet-balance toggle — explicit opt-in only, same convention as
// Quick Delivery. Applies on top of `paymentMethod`, offsetting the
// total rather than replacing the method.
  @override
  @JsonKey()
  final bool useWallet;

  /// Create a copy of CheckoutState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CheckoutStateCopyWith<_CheckoutState> get copyWith =>
      __$CheckoutStateCopyWithImpl<_CheckoutState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CheckoutState &&
            (identical(other.selectedAddress, selectedAddress) ||
                other.selectedAddress == selectedAddress) &&
            (identical(other.appliedCoupon, appliedCoupon) ||
                other.appliedCoupon == appliedCoupon) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.validatedCart, validatedCart) ||
                other.validatedCart == validatedCart) &&
            (identical(other.currentStep, currentStep) ||
                other.currentStep == currentStep) &&
            (identical(other.isPlacingOrder, isPlacingOrder) ||
                other.isPlacingOrder == isPlacingOrder) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.selectedDeliverySlot, selectedDeliverySlot) ||
                other.selectedDeliverySlot == selectedDeliverySlot) &&
            (identical(other.useWallet, useWallet) ||
                other.useWallet == useWallet));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      selectedAddress,
      appliedCoupon,
      paymentMethod,
      validatedCart,
      currentStep,
      isPlacingOrder,
      errorMessage,
      selectedDeliverySlot,
      useWallet);

  @override
  String toString() {
    return 'CheckoutState(selectedAddress: $selectedAddress, appliedCoupon: $appliedCoupon, paymentMethod: $paymentMethod, validatedCart: $validatedCart, currentStep: $currentStep, isPlacingOrder: $isPlacingOrder, errorMessage: $errorMessage, selectedDeliverySlot: $selectedDeliverySlot, useWallet: $useWallet)';
  }
}

/// @nodoc
abstract mixin class _$CheckoutStateCopyWith<$Res>
    implements $CheckoutStateCopyWith<$Res> {
  factory _$CheckoutStateCopyWith(
          _CheckoutState value, $Res Function(_CheckoutState) _then) =
      __$CheckoutStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {AddressEntity? selectedAddress,
      CouponEntity? appliedCoupon,
      PaymentMethod paymentMethod,
      CartValidationEntity? validatedCart,
      CheckoutStep currentStep,
      bool isPlacingOrder,
      String? errorMessage,
      SelectedDeliverySlot? selectedDeliverySlot,
      bool useWallet});

  @override
  $AddressEntityCopyWith<$Res>? get selectedAddress;
  @override
  $CouponEntityCopyWith<$Res>? get appliedCoupon;
}

/// @nodoc
class __$CheckoutStateCopyWithImpl<$Res>
    implements _$CheckoutStateCopyWith<$Res> {
  __$CheckoutStateCopyWithImpl(this._self, this._then);

  final _CheckoutState _self;
  final $Res Function(_CheckoutState) _then;

  /// Create a copy of CheckoutState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? selectedAddress = freezed,
    Object? appliedCoupon = freezed,
    Object? paymentMethod = null,
    Object? validatedCart = freezed,
    Object? currentStep = null,
    Object? isPlacingOrder = null,
    Object? errorMessage = freezed,
    Object? selectedDeliverySlot = freezed,
    Object? useWallet = null,
  }) {
    return _then(_CheckoutState(
      selectedAddress: freezed == selectedAddress
          ? _self.selectedAddress
          : selectedAddress // ignore: cast_nullable_to_non_nullable
              as AddressEntity?,
      appliedCoupon: freezed == appliedCoupon
          ? _self.appliedCoupon
          : appliedCoupon // ignore: cast_nullable_to_non_nullable
              as CouponEntity?,
      paymentMethod: null == paymentMethod
          ? _self.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as PaymentMethod,
      validatedCart: freezed == validatedCart
          ? _self.validatedCart
          : validatedCart // ignore: cast_nullable_to_non_nullable
              as CartValidationEntity?,
      currentStep: null == currentStep
          ? _self.currentStep
          : currentStep // ignore: cast_nullable_to_non_nullable
              as CheckoutStep,
      isPlacingOrder: null == isPlacingOrder
          ? _self.isPlacingOrder
          : isPlacingOrder // ignore: cast_nullable_to_non_nullable
              as bool,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      selectedDeliverySlot: freezed == selectedDeliverySlot
          ? _self.selectedDeliverySlot
          : selectedDeliverySlot // ignore: cast_nullable_to_non_nullable
              as SelectedDeliverySlot?,
      useWallet: null == useWallet
          ? _self.useWallet
          : useWallet // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of CheckoutState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $AddressEntityCopyWith<$Res>? get selectedAddress {
    if (_self.selectedAddress == null) {
      return null;
    }

    return $AddressEntityCopyWith<$Res>(_self.selectedAddress!, (value) {
      return _then(_self.copyWith(selectedAddress: value));
    });
  }

  /// Create a copy of CheckoutState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CouponEntityCopyWith<$Res>? get appliedCoupon {
    if (_self.appliedCoupon == null) {
      return null;
    }

    return $CouponEntityCopyWith<$Res>(_self.appliedCoupon!, (value) {
      return _then(_self.copyWith(appliedCoupon: value));
    });
  }
}

// dart format on
