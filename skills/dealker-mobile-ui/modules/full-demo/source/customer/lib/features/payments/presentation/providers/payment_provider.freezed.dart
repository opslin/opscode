// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'payment_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PaymentState {
  bool get isLoading;
  bool
      get isVerifying; // Set while the checkout SDK has reported an error that ISN'T a
// confirmed user cancellation and we're checking with the backend
// before deciding anything — and again, with a different
// [pendingMessage], if that check exhausts its bounded wait with no
// definitive answer yet. Never means "failed"; the UI must not show a
// dead-end error while this is true.
  bool get isPendingConfirmation;
  String? get pendingMessage;
  String? get errorMessage;
  PaymentEntity? get lastPayment;
  String? get activeOrderId;
  String? get activeRazorpayOrderId;
  bool get isWalletTopupFlow;

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PaymentStateCopyWith<PaymentState> get copyWith =>
      _$PaymentStateCopyWithImpl<PaymentState>(
          this as PaymentState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PaymentState &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isVerifying, isVerifying) ||
                other.isVerifying == isVerifying) &&
            (identical(other.isPendingConfirmation, isPendingConfirmation) ||
                other.isPendingConfirmation == isPendingConfirmation) &&
            (identical(other.pendingMessage, pendingMessage) ||
                other.pendingMessage == pendingMessage) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.lastPayment, lastPayment) ||
                other.lastPayment == lastPayment) &&
            (identical(other.activeOrderId, activeOrderId) ||
                other.activeOrderId == activeOrderId) &&
            (identical(other.activeRazorpayOrderId, activeRazorpayOrderId) ||
                other.activeRazorpayOrderId == activeRazorpayOrderId) &&
            (identical(other.isWalletTopupFlow, isWalletTopupFlow) ||
                other.isWalletTopupFlow == isWalletTopupFlow));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isLoading,
      isVerifying,
      isPendingConfirmation,
      pendingMessage,
      errorMessage,
      lastPayment,
      activeOrderId,
      activeRazorpayOrderId,
      isWalletTopupFlow);

  @override
  String toString() {
    return 'PaymentState(isLoading: $isLoading, isVerifying: $isVerifying, isPendingConfirmation: $isPendingConfirmation, pendingMessage: $pendingMessage, errorMessage: $errorMessage, lastPayment: $lastPayment, activeOrderId: $activeOrderId, activeRazorpayOrderId: $activeRazorpayOrderId, isWalletTopupFlow: $isWalletTopupFlow)';
  }
}

/// @nodoc
abstract mixin class $PaymentStateCopyWith<$Res> {
  factory $PaymentStateCopyWith(
          PaymentState value, $Res Function(PaymentState) _then) =
      _$PaymentStateCopyWithImpl;
  @useResult
  $Res call(
      {bool isLoading,
      bool isVerifying,
      bool isPendingConfirmation,
      String? pendingMessage,
      String? errorMessage,
      PaymentEntity? lastPayment,
      String? activeOrderId,
      String? activeRazorpayOrderId,
      bool isWalletTopupFlow});

  $PaymentEntityCopyWith<$Res>? get lastPayment;
}

/// @nodoc
class _$PaymentStateCopyWithImpl<$Res> implements $PaymentStateCopyWith<$Res> {
  _$PaymentStateCopyWithImpl(this._self, this._then);

  final PaymentState _self;
  final $Res Function(PaymentState) _then;

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? isLoading = null,
    Object? isVerifying = null,
    Object? isPendingConfirmation = null,
    Object? pendingMessage = freezed,
    Object? errorMessage = freezed,
    Object? lastPayment = freezed,
    Object? activeOrderId = freezed,
    Object? activeRazorpayOrderId = freezed,
    Object? isWalletTopupFlow = null,
  }) {
    return _then(_self.copyWith(
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isVerifying: null == isVerifying
          ? _self.isVerifying
          : isVerifying // ignore: cast_nullable_to_non_nullable
              as bool,
      isPendingConfirmation: null == isPendingConfirmation
          ? _self.isPendingConfirmation
          : isPendingConfirmation // ignore: cast_nullable_to_non_nullable
              as bool,
      pendingMessage: freezed == pendingMessage
          ? _self.pendingMessage
          : pendingMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastPayment: freezed == lastPayment
          ? _self.lastPayment
          : lastPayment // ignore: cast_nullable_to_non_nullable
              as PaymentEntity?,
      activeOrderId: freezed == activeOrderId
          ? _self.activeOrderId
          : activeOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
      activeRazorpayOrderId: freezed == activeRazorpayOrderId
          ? _self.activeRazorpayOrderId
          : activeRazorpayOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
      isWalletTopupFlow: null == isWalletTopupFlow
          ? _self.isWalletTopupFlow
          : isWalletTopupFlow // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PaymentEntityCopyWith<$Res>? get lastPayment {
    if (_self.lastPayment == null) {
      return null;
    }

    return $PaymentEntityCopyWith<$Res>(_self.lastPayment!, (value) {
      return _then(_self.copyWith(lastPayment: value));
    });
  }
}

/// Adds pattern-matching-related methods to [PaymentState].
extension PaymentStatePatterns on PaymentState {
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
    TResult Function(_PaymentState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentState() when $default != null:
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
    TResult Function(_PaymentState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentState():
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
    TResult? Function(_PaymentState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentState() when $default != null:
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
            bool isLoading,
            bool isVerifying,
            bool isPendingConfirmation,
            String? pendingMessage,
            String? errorMessage,
            PaymentEntity? lastPayment,
            String? activeOrderId,
            String? activeRazorpayOrderId,
            bool isWalletTopupFlow)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentState() when $default != null:
        return $default(
            _that.isLoading,
            _that.isVerifying,
            _that.isPendingConfirmation,
            _that.pendingMessage,
            _that.errorMessage,
            _that.lastPayment,
            _that.activeOrderId,
            _that.activeRazorpayOrderId,
            _that.isWalletTopupFlow);
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
            bool isLoading,
            bool isVerifying,
            bool isPendingConfirmation,
            String? pendingMessage,
            String? errorMessage,
            PaymentEntity? lastPayment,
            String? activeOrderId,
            String? activeRazorpayOrderId,
            bool isWalletTopupFlow)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentState():
        return $default(
            _that.isLoading,
            _that.isVerifying,
            _that.isPendingConfirmation,
            _that.pendingMessage,
            _that.errorMessage,
            _that.lastPayment,
            _that.activeOrderId,
            _that.activeRazorpayOrderId,
            _that.isWalletTopupFlow);
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
            bool isLoading,
            bool isVerifying,
            bool isPendingConfirmation,
            String? pendingMessage,
            String? errorMessage,
            PaymentEntity? lastPayment,
            String? activeOrderId,
            String? activeRazorpayOrderId,
            bool isWalletTopupFlow)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentState() when $default != null:
        return $default(
            _that.isLoading,
            _that.isVerifying,
            _that.isPendingConfirmation,
            _that.pendingMessage,
            _that.errorMessage,
            _that.lastPayment,
            _that.activeOrderId,
            _that.activeRazorpayOrderId,
            _that.isWalletTopupFlow);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PaymentState implements PaymentState {
  const _PaymentState(
      {this.isLoading = false,
      this.isVerifying = false,
      this.isPendingConfirmation = false,
      this.pendingMessage,
      this.errorMessage,
      this.lastPayment,
      this.activeOrderId,
      this.activeRazorpayOrderId,
      this.isWalletTopupFlow = false});

  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isVerifying;
// Set while the checkout SDK has reported an error that ISN'T a
// confirmed user cancellation and we're checking with the backend
// before deciding anything — and again, with a different
// [pendingMessage], if that check exhausts its bounded wait with no
// definitive answer yet. Never means "failed"; the UI must not show a
// dead-end error while this is true.
  @override
  @JsonKey()
  final bool isPendingConfirmation;
  @override
  final String? pendingMessage;
  @override
  final String? errorMessage;
  @override
  final PaymentEntity? lastPayment;
  @override
  final String? activeOrderId;
  @override
  final String? activeRazorpayOrderId;
  @override
  @JsonKey()
  final bool isWalletTopupFlow;

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PaymentStateCopyWith<_PaymentState> get copyWith =>
      __$PaymentStateCopyWithImpl<_PaymentState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PaymentState &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isVerifying, isVerifying) ||
                other.isVerifying == isVerifying) &&
            (identical(other.isPendingConfirmation, isPendingConfirmation) ||
                other.isPendingConfirmation == isPendingConfirmation) &&
            (identical(other.pendingMessage, pendingMessage) ||
                other.pendingMessage == pendingMessage) &&
            (identical(other.errorMessage, errorMessage) ||
                other.errorMessage == errorMessage) &&
            (identical(other.lastPayment, lastPayment) ||
                other.lastPayment == lastPayment) &&
            (identical(other.activeOrderId, activeOrderId) ||
                other.activeOrderId == activeOrderId) &&
            (identical(other.activeRazorpayOrderId, activeRazorpayOrderId) ||
                other.activeRazorpayOrderId == activeRazorpayOrderId) &&
            (identical(other.isWalletTopupFlow, isWalletTopupFlow) ||
                other.isWalletTopupFlow == isWalletTopupFlow));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      isLoading,
      isVerifying,
      isPendingConfirmation,
      pendingMessage,
      errorMessage,
      lastPayment,
      activeOrderId,
      activeRazorpayOrderId,
      isWalletTopupFlow);

  @override
  String toString() {
    return 'PaymentState(isLoading: $isLoading, isVerifying: $isVerifying, isPendingConfirmation: $isPendingConfirmation, pendingMessage: $pendingMessage, errorMessage: $errorMessage, lastPayment: $lastPayment, activeOrderId: $activeOrderId, activeRazorpayOrderId: $activeRazorpayOrderId, isWalletTopupFlow: $isWalletTopupFlow)';
  }
}

/// @nodoc
abstract mixin class _$PaymentStateCopyWith<$Res>
    implements $PaymentStateCopyWith<$Res> {
  factory _$PaymentStateCopyWith(
          _PaymentState value, $Res Function(_PaymentState) _then) =
      __$PaymentStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool isLoading,
      bool isVerifying,
      bool isPendingConfirmation,
      String? pendingMessage,
      String? errorMessage,
      PaymentEntity? lastPayment,
      String? activeOrderId,
      String? activeRazorpayOrderId,
      bool isWalletTopupFlow});

  @override
  $PaymentEntityCopyWith<$Res>? get lastPayment;
}

/// @nodoc
class __$PaymentStateCopyWithImpl<$Res>
    implements _$PaymentStateCopyWith<$Res> {
  __$PaymentStateCopyWithImpl(this._self, this._then);

  final _PaymentState _self;
  final $Res Function(_PaymentState) _then;

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? isLoading = null,
    Object? isVerifying = null,
    Object? isPendingConfirmation = null,
    Object? pendingMessage = freezed,
    Object? errorMessage = freezed,
    Object? lastPayment = freezed,
    Object? activeOrderId = freezed,
    Object? activeRazorpayOrderId = freezed,
    Object? isWalletTopupFlow = null,
  }) {
    return _then(_PaymentState(
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isVerifying: null == isVerifying
          ? _self.isVerifying
          : isVerifying // ignore: cast_nullable_to_non_nullable
              as bool,
      isPendingConfirmation: null == isPendingConfirmation
          ? _self.isPendingConfirmation
          : isPendingConfirmation // ignore: cast_nullable_to_non_nullable
              as bool,
      pendingMessage: freezed == pendingMessage
          ? _self.pendingMessage
          : pendingMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      errorMessage: freezed == errorMessage
          ? _self.errorMessage
          : errorMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      lastPayment: freezed == lastPayment
          ? _self.lastPayment
          : lastPayment // ignore: cast_nullable_to_non_nullable
              as PaymentEntity?,
      activeOrderId: freezed == activeOrderId
          ? _self.activeOrderId
          : activeOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
      activeRazorpayOrderId: freezed == activeRazorpayOrderId
          ? _self.activeRazorpayOrderId
          : activeRazorpayOrderId // ignore: cast_nullable_to_non_nullable
              as String?,
      isWalletTopupFlow: null == isWalletTopupFlow
          ? _self.isWalletTopupFlow
          : isWalletTopupFlow // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of PaymentState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PaymentEntityCopyWith<$Res>? get lastPayment {
    if (_self.lastPayment == null) {
      return null;
    }

    return $PaymentEntityCopyWith<$Res>(_self.lastPayment!, (value) {
      return _then(_self.copyWith(lastPayment: value));
    });
  }
}

// dart format on
