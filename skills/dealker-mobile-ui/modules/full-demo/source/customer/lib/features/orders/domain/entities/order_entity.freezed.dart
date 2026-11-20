// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'order_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$OrderEntity {
  String get id;
  String get orderNumber;
  OrderStatus get status;
  List<OrderItemEntity> get items;
  double get subtotal;
  double get discount;
  double get deliveryFee;
  double get platformFee;
  double get total;
  Map<String, dynamic> get deliveryAddress;
  String get paymentMethod;
  String get paymentStatus;
  DateTime
      get createdAt; // Wallet-balance toggle checkout feature — the portion of `total`
// covered by wallet, on top of paymentMethod, regardless of whether
// that's COD or ONLINE. 0 for orders placed before this feature, or
// where the customer never used the toggle.
  double
      get walletAmountUsed; // The server's own status word (ORDER_PLACED, SHIPPED, RETURNED…); `status`
// above folds several of them together.
  String get rawStatus;
  String?
      get cancelledReason; // When the server moved the order into each status (raw status word →
// first time), from the status history.
  Map<String, DateTime> get statusTimes;
  DateTime? get paymentExpiresAt;
  String? get razorpayPaymentId;
  String? get couponCode;
  DateTime? get deliveredAt;
  DateTime? get cancelledAt;
  DateTime? get estimatedDelivery;
  Map<String, dynamic> get tracking;
  List<OrderTimelineEntity> get timeline; // Delivery slot fields
  String get deliveryMode;
  String? get scheduledSlotLabel;
  DateTime? get scheduledSlotStart;
  DateTime?
      get scheduledSlotEnd; // 4-digit code the customer reads out to the rider on delivery.
// Only present while the assignment is ACCEPTED/IN_TRANSIT.
  String?
      get deliveryOtp; // "Place Order" B2B credit — null for every non-B2B order.
// 'PENDING' until an admin approves it, 'APPROVED' after. There is no
// credit limit; "amount owed" is total minus b2bAmountSettled, settled
// per-order via b2bSettlements rather than an account-level balance.
  String? get b2bApprovalStatus;
  double get b2bAmountSettled;
  DateTime? get b2bPaymentDueDate;
  List<B2BSettlementEntity> get b2bSettlements;

  /// Create a copy of OrderEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $OrderEntityCopyWith<OrderEntity> get copyWith =>
      _$OrderEntityCopyWithImpl<OrderEntity>(this as OrderEntity, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is OrderEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderNumber, orderNumber) ||
                other.orderNumber == orderNumber) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other.items, items) &&
            (identical(other.subtotal, subtotal) ||
                other.subtotal == subtotal) &&
            (identical(other.discount, discount) ||
                other.discount == discount) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.platformFee, platformFee) ||
                other.platformFee == platformFee) &&
            (identical(other.total, total) || other.total == total) &&
            const DeepCollectionEquality()
                .equals(other.deliveryAddress, deliveryAddress) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.paymentStatus, paymentStatus) ||
                other.paymentStatus == paymentStatus) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.walletAmountUsed, walletAmountUsed) ||
                other.walletAmountUsed == walletAmountUsed) &&
            (identical(other.rawStatus, rawStatus) ||
                other.rawStatus == rawStatus) &&
            (identical(other.cancelledReason, cancelledReason) ||
                other.cancelledReason == cancelledReason) &&
            const DeepCollectionEquality()
                .equals(other.statusTimes, statusTimes) &&
            (identical(other.paymentExpiresAt, paymentExpiresAt) ||
                other.paymentExpiresAt == paymentExpiresAt) &&
            (identical(other.razorpayPaymentId, razorpayPaymentId) ||
                other.razorpayPaymentId == razorpayPaymentId) &&
            (identical(other.couponCode, couponCode) ||
                other.couponCode == couponCode) &&
            (identical(other.deliveredAt, deliveredAt) ||
                other.deliveredAt == deliveredAt) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.estimatedDelivery, estimatedDelivery) ||
                other.estimatedDelivery == estimatedDelivery) &&
            const DeepCollectionEquality().equals(other.tracking, tracking) &&
            const DeepCollectionEquality().equals(other.timeline, timeline) &&
            (identical(other.deliveryMode, deliveryMode) ||
                other.deliveryMode == deliveryMode) &&
            (identical(other.scheduledSlotLabel, scheduledSlotLabel) ||
                other.scheduledSlotLabel == scheduledSlotLabel) &&
            (identical(other.scheduledSlotStart, scheduledSlotStart) ||
                other.scheduledSlotStart == scheduledSlotStart) &&
            (identical(other.scheduledSlotEnd, scheduledSlotEnd) ||
                other.scheduledSlotEnd == scheduledSlotEnd) &&
            (identical(other.deliveryOtp, deliveryOtp) ||
                other.deliveryOtp == deliveryOtp) &&
            (identical(other.b2bApprovalStatus, b2bApprovalStatus) ||
                other.b2bApprovalStatus == b2bApprovalStatus) &&
            (identical(other.b2bAmountSettled, b2bAmountSettled) ||
                other.b2bAmountSettled == b2bAmountSettled) &&
            (identical(other.b2bPaymentDueDate, b2bPaymentDueDate) ||
                other.b2bPaymentDueDate == b2bPaymentDueDate) &&
            const DeepCollectionEquality()
                .equals(other.b2bSettlements, b2bSettlements));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        orderNumber,
        status,
        const DeepCollectionEquality().hash(items),
        subtotal,
        discount,
        deliveryFee,
        platformFee,
        total,
        const DeepCollectionEquality().hash(deliveryAddress),
        paymentMethod,
        paymentStatus,
        createdAt,
        walletAmountUsed,
        rawStatus,
        cancelledReason,
        const DeepCollectionEquality().hash(statusTimes),
        paymentExpiresAt,
        razorpayPaymentId,
        couponCode,
        deliveredAt,
        cancelledAt,
        estimatedDelivery,
        const DeepCollectionEquality().hash(tracking),
        const DeepCollectionEquality().hash(timeline),
        deliveryMode,
        scheduledSlotLabel,
        scheduledSlotStart,
        scheduledSlotEnd,
        deliveryOtp,
        b2bApprovalStatus,
        b2bAmountSettled,
        b2bPaymentDueDate,
        const DeepCollectionEquality().hash(b2bSettlements)
      ]);

  @override
  String toString() {
    return 'OrderEntity(id: $id, orderNumber: $orderNumber, status: $status, items: $items, subtotal: $subtotal, discount: $discount, deliveryFee: $deliveryFee, platformFee: $platformFee, total: $total, deliveryAddress: $deliveryAddress, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, createdAt: $createdAt, walletAmountUsed: $walletAmountUsed, rawStatus: $rawStatus, cancelledReason: $cancelledReason, statusTimes: $statusTimes, paymentExpiresAt: $paymentExpiresAt, razorpayPaymentId: $razorpayPaymentId, couponCode: $couponCode, deliveredAt: $deliveredAt, cancelledAt: $cancelledAt, estimatedDelivery: $estimatedDelivery, tracking: $tracking, timeline: $timeline, deliveryMode: $deliveryMode, scheduledSlotLabel: $scheduledSlotLabel, scheduledSlotStart: $scheduledSlotStart, scheduledSlotEnd: $scheduledSlotEnd, deliveryOtp: $deliveryOtp, b2bApprovalStatus: $b2bApprovalStatus, b2bAmountSettled: $b2bAmountSettled, b2bPaymentDueDate: $b2bPaymentDueDate, b2bSettlements: $b2bSettlements)';
  }
}

/// @nodoc
abstract mixin class $OrderEntityCopyWith<$Res> {
  factory $OrderEntityCopyWith(
          OrderEntity value, $Res Function(OrderEntity) _then) =
      _$OrderEntityCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String orderNumber,
      OrderStatus status,
      List<OrderItemEntity> items,
      double subtotal,
      double discount,
      double deliveryFee,
      double platformFee,
      double total,
      Map<String, dynamic> deliveryAddress,
      String paymentMethod,
      String paymentStatus,
      DateTime createdAt,
      double walletAmountUsed,
      String rawStatus,
      String? cancelledReason,
      Map<String, DateTime> statusTimes,
      DateTime? paymentExpiresAt,
      String? razorpayPaymentId,
      String? couponCode,
      DateTime? deliveredAt,
      DateTime? cancelledAt,
      DateTime? estimatedDelivery,
      Map<String, dynamic> tracking,
      List<OrderTimelineEntity> timeline,
      String deliveryMode,
      String? scheduledSlotLabel,
      DateTime? scheduledSlotStart,
      DateTime? scheduledSlotEnd,
      String? deliveryOtp,
      String? b2bApprovalStatus,
      double b2bAmountSettled,
      DateTime? b2bPaymentDueDate,
      List<B2BSettlementEntity> b2bSettlements});
}

/// @nodoc
class _$OrderEntityCopyWithImpl<$Res> implements $OrderEntityCopyWith<$Res> {
  _$OrderEntityCopyWithImpl(this._self, this._then);

  final OrderEntity _self;
  final $Res Function(OrderEntity) _then;

  /// Create a copy of OrderEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? orderNumber = null,
    Object? status = null,
    Object? items = null,
    Object? subtotal = null,
    Object? discount = null,
    Object? deliveryFee = null,
    Object? platformFee = null,
    Object? total = null,
    Object? deliveryAddress = null,
    Object? paymentMethod = null,
    Object? paymentStatus = null,
    Object? createdAt = null,
    Object? walletAmountUsed = null,
    Object? rawStatus = null,
    Object? cancelledReason = freezed,
    Object? statusTimes = null,
    Object? paymentExpiresAt = freezed,
    Object? razorpayPaymentId = freezed,
    Object? couponCode = freezed,
    Object? deliveredAt = freezed,
    Object? cancelledAt = freezed,
    Object? estimatedDelivery = freezed,
    Object? tracking = null,
    Object? timeline = null,
    Object? deliveryMode = null,
    Object? scheduledSlotLabel = freezed,
    Object? scheduledSlotStart = freezed,
    Object? scheduledSlotEnd = freezed,
    Object? deliveryOtp = freezed,
    Object? b2bApprovalStatus = freezed,
    Object? b2bAmountSettled = null,
    Object? b2bPaymentDueDate = freezed,
    Object? b2bSettlements = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      orderNumber: null == orderNumber
          ? _self.orderNumber
          : orderNumber // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as OrderStatus,
      items: null == items
          ? _self.items
          : items // ignore: cast_nullable_to_non_nullable
              as List<OrderItemEntity>,
      subtotal: null == subtotal
          ? _self.subtotal
          : subtotal // ignore: cast_nullable_to_non_nullable
              as double,
      discount: null == discount
          ? _self.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryFee: null == deliveryFee
          ? _self.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      platformFee: null == platformFee
          ? _self.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as double,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryAddress: null == deliveryAddress
          ? _self.deliveryAddress
          : deliveryAddress // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      paymentMethod: null == paymentMethod
          ? _self.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      paymentStatus: null == paymentStatus
          ? _self.paymentStatus
          : paymentStatus // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      walletAmountUsed: null == walletAmountUsed
          ? _self.walletAmountUsed
          : walletAmountUsed // ignore: cast_nullable_to_non_nullable
              as double,
      rawStatus: null == rawStatus
          ? _self.rawStatus
          : rawStatus // ignore: cast_nullable_to_non_nullable
              as String,
      cancelledReason: freezed == cancelledReason
          ? _self.cancelledReason
          : cancelledReason // ignore: cast_nullable_to_non_nullable
              as String?,
      statusTimes: null == statusTimes
          ? _self.statusTimes
          : statusTimes // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
      paymentExpiresAt: freezed == paymentExpiresAt
          ? _self.paymentExpiresAt
          : paymentExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      razorpayPaymentId: freezed == razorpayPaymentId
          ? _self.razorpayPaymentId
          : razorpayPaymentId // ignore: cast_nullable_to_non_nullable
              as String?,
      couponCode: freezed == couponCode
          ? _self.couponCode
          : couponCode // ignore: cast_nullable_to_non_nullable
              as String?,
      deliveredAt: freezed == deliveredAt
          ? _self.deliveredAt
          : deliveredAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _self.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimatedDelivery: freezed == estimatedDelivery
          ? _self.estimatedDelivery
          : estimatedDelivery // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      tracking: null == tracking
          ? _self.tracking
          : tracking // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      timeline: null == timeline
          ? _self.timeline
          : timeline // ignore: cast_nullable_to_non_nullable
              as List<OrderTimelineEntity>,
      deliveryMode: null == deliveryMode
          ? _self.deliveryMode
          : deliveryMode // ignore: cast_nullable_to_non_nullable
              as String,
      scheduledSlotLabel: freezed == scheduledSlotLabel
          ? _self.scheduledSlotLabel
          : scheduledSlotLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledSlotStart: freezed == scheduledSlotStart
          ? _self.scheduledSlotStart
          : scheduledSlotStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      scheduledSlotEnd: freezed == scheduledSlotEnd
          ? _self.scheduledSlotEnd
          : scheduledSlotEnd // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deliveryOtp: freezed == deliveryOtp
          ? _self.deliveryOtp
          : deliveryOtp // ignore: cast_nullable_to_non_nullable
              as String?,
      b2bApprovalStatus: freezed == b2bApprovalStatus
          ? _self.b2bApprovalStatus
          : b2bApprovalStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      b2bAmountSettled: null == b2bAmountSettled
          ? _self.b2bAmountSettled
          : b2bAmountSettled // ignore: cast_nullable_to_non_nullable
              as double,
      b2bPaymentDueDate: freezed == b2bPaymentDueDate
          ? _self.b2bPaymentDueDate
          : b2bPaymentDueDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      b2bSettlements: null == b2bSettlements
          ? _self.b2bSettlements
          : b2bSettlements // ignore: cast_nullable_to_non_nullable
              as List<B2BSettlementEntity>,
    ));
  }
}

/// Adds pattern-matching-related methods to [OrderEntity].
extension OrderEntityPatterns on OrderEntity {
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
    TResult Function(_OrderEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OrderEntity() when $default != null:
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
    TResult Function(_OrderEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderEntity():
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
    TResult? Function(_OrderEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderEntity() when $default != null:
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
            String orderNumber,
            OrderStatus status,
            List<OrderItemEntity> items,
            double subtotal,
            double discount,
            double deliveryFee,
            double platformFee,
            double total,
            Map<String, dynamic> deliveryAddress,
            String paymentMethod,
            String paymentStatus,
            DateTime createdAt,
            double walletAmountUsed,
            String rawStatus,
            String? cancelledReason,
            Map<String, DateTime> statusTimes,
            DateTime? paymentExpiresAt,
            String? razorpayPaymentId,
            String? couponCode,
            DateTime? deliveredAt,
            DateTime? cancelledAt,
            DateTime? estimatedDelivery,
            Map<String, dynamic> tracking,
            List<OrderTimelineEntity> timeline,
            String deliveryMode,
            String? scheduledSlotLabel,
            DateTime? scheduledSlotStart,
            DateTime? scheduledSlotEnd,
            String? deliveryOtp,
            String? b2bApprovalStatus,
            double b2bAmountSettled,
            DateTime? b2bPaymentDueDate,
            List<B2BSettlementEntity> b2bSettlements)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _OrderEntity() when $default != null:
        return $default(
            _that.id,
            _that.orderNumber,
            _that.status,
            _that.items,
            _that.subtotal,
            _that.discount,
            _that.deliveryFee,
            _that.platformFee,
            _that.total,
            _that.deliveryAddress,
            _that.paymentMethod,
            _that.paymentStatus,
            _that.createdAt,
            _that.walletAmountUsed,
            _that.rawStatus,
            _that.cancelledReason,
            _that.statusTimes,
            _that.paymentExpiresAt,
            _that.razorpayPaymentId,
            _that.couponCode,
            _that.deliveredAt,
            _that.cancelledAt,
            _that.estimatedDelivery,
            _that.tracking,
            _that.timeline,
            _that.deliveryMode,
            _that.scheduledSlotLabel,
            _that.scheduledSlotStart,
            _that.scheduledSlotEnd,
            _that.deliveryOtp,
            _that.b2bApprovalStatus,
            _that.b2bAmountSettled,
            _that.b2bPaymentDueDate,
            _that.b2bSettlements);
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
            String orderNumber,
            OrderStatus status,
            List<OrderItemEntity> items,
            double subtotal,
            double discount,
            double deliveryFee,
            double platformFee,
            double total,
            Map<String, dynamic> deliveryAddress,
            String paymentMethod,
            String paymentStatus,
            DateTime createdAt,
            double walletAmountUsed,
            String rawStatus,
            String? cancelledReason,
            Map<String, DateTime> statusTimes,
            DateTime? paymentExpiresAt,
            String? razorpayPaymentId,
            String? couponCode,
            DateTime? deliveredAt,
            DateTime? cancelledAt,
            DateTime? estimatedDelivery,
            Map<String, dynamic> tracking,
            List<OrderTimelineEntity> timeline,
            String deliveryMode,
            String? scheduledSlotLabel,
            DateTime? scheduledSlotStart,
            DateTime? scheduledSlotEnd,
            String? deliveryOtp,
            String? b2bApprovalStatus,
            double b2bAmountSettled,
            DateTime? b2bPaymentDueDate,
            List<B2BSettlementEntity> b2bSettlements)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderEntity():
        return $default(
            _that.id,
            _that.orderNumber,
            _that.status,
            _that.items,
            _that.subtotal,
            _that.discount,
            _that.deliveryFee,
            _that.platformFee,
            _that.total,
            _that.deliveryAddress,
            _that.paymentMethod,
            _that.paymentStatus,
            _that.createdAt,
            _that.walletAmountUsed,
            _that.rawStatus,
            _that.cancelledReason,
            _that.statusTimes,
            _that.paymentExpiresAt,
            _that.razorpayPaymentId,
            _that.couponCode,
            _that.deliveredAt,
            _that.cancelledAt,
            _that.estimatedDelivery,
            _that.tracking,
            _that.timeline,
            _that.deliveryMode,
            _that.scheduledSlotLabel,
            _that.scheduledSlotStart,
            _that.scheduledSlotEnd,
            _that.deliveryOtp,
            _that.b2bApprovalStatus,
            _that.b2bAmountSettled,
            _that.b2bPaymentDueDate,
            _that.b2bSettlements);
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
            String orderNumber,
            OrderStatus status,
            List<OrderItemEntity> items,
            double subtotal,
            double discount,
            double deliveryFee,
            double platformFee,
            double total,
            Map<String, dynamic> deliveryAddress,
            String paymentMethod,
            String paymentStatus,
            DateTime createdAt,
            double walletAmountUsed,
            String rawStatus,
            String? cancelledReason,
            Map<String, DateTime> statusTimes,
            DateTime? paymentExpiresAt,
            String? razorpayPaymentId,
            String? couponCode,
            DateTime? deliveredAt,
            DateTime? cancelledAt,
            DateTime? estimatedDelivery,
            Map<String, dynamic> tracking,
            List<OrderTimelineEntity> timeline,
            String deliveryMode,
            String? scheduledSlotLabel,
            DateTime? scheduledSlotStart,
            DateTime? scheduledSlotEnd,
            String? deliveryOtp,
            String? b2bApprovalStatus,
            double b2bAmountSettled,
            DateTime? b2bPaymentDueDate,
            List<B2BSettlementEntity> b2bSettlements)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _OrderEntity() when $default != null:
        return $default(
            _that.id,
            _that.orderNumber,
            _that.status,
            _that.items,
            _that.subtotal,
            _that.discount,
            _that.deliveryFee,
            _that.platformFee,
            _that.total,
            _that.deliveryAddress,
            _that.paymentMethod,
            _that.paymentStatus,
            _that.createdAt,
            _that.walletAmountUsed,
            _that.rawStatus,
            _that.cancelledReason,
            _that.statusTimes,
            _that.paymentExpiresAt,
            _that.razorpayPaymentId,
            _that.couponCode,
            _that.deliveredAt,
            _that.cancelledAt,
            _that.estimatedDelivery,
            _that.tracking,
            _that.timeline,
            _that.deliveryMode,
            _that.scheduledSlotLabel,
            _that.scheduledSlotStart,
            _that.scheduledSlotEnd,
            _that.deliveryOtp,
            _that.b2bApprovalStatus,
            _that.b2bAmountSettled,
            _that.b2bPaymentDueDate,
            _that.b2bSettlements);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _OrderEntity extends OrderEntity {
  const _OrderEntity(
      {required this.id,
      required this.orderNumber,
      required this.status,
      required final List<OrderItemEntity> items,
      required this.subtotal,
      required this.discount,
      required this.deliveryFee,
      required this.platformFee,
      required this.total,
      required final Map<String, dynamic> deliveryAddress,
      required this.paymentMethod,
      required this.paymentStatus,
      required this.createdAt,
      this.walletAmountUsed = 0,
      this.rawStatus = '',
      this.cancelledReason,
      final Map<String, DateTime> statusTimes = const <String, DateTime>{},
      this.paymentExpiresAt,
      this.razorpayPaymentId,
      this.couponCode,
      this.deliveredAt,
      this.cancelledAt,
      this.estimatedDelivery,
      final Map<String, dynamic> tracking = const <String, dynamic>{},
      final List<OrderTimelineEntity> timeline = const <OrderTimelineEntity>[],
      this.deliveryMode = 'ASAP',
      this.scheduledSlotLabel,
      this.scheduledSlotStart,
      this.scheduledSlotEnd,
      this.deliveryOtp,
      this.b2bApprovalStatus,
      this.b2bAmountSettled = 0,
      this.b2bPaymentDueDate,
      final List<B2BSettlementEntity> b2bSettlements =
          const <B2BSettlementEntity>[]})
      : _items = items,
        _deliveryAddress = deliveryAddress,
        _statusTimes = statusTimes,
        _tracking = tracking,
        _timeline = timeline,
        _b2bSettlements = b2bSettlements,
        super._();

  @override
  final String id;
  @override
  final String orderNumber;
  @override
  final OrderStatus status;
  final List<OrderItemEntity> _items;
  @override
  List<OrderItemEntity> get items {
    if (_items is EqualUnmodifiableListView) return _items;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_items);
  }

  @override
  final double subtotal;
  @override
  final double discount;
  @override
  final double deliveryFee;
  @override
  final double platformFee;
  @override
  final double total;
  final Map<String, dynamic> _deliveryAddress;
  @override
  Map<String, dynamic> get deliveryAddress {
    if (_deliveryAddress is EqualUnmodifiableMapView) return _deliveryAddress;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_deliveryAddress);
  }

  @override
  final String paymentMethod;
  @override
  final String paymentStatus;
  @override
  final DateTime createdAt;
// Wallet-balance toggle checkout feature — the portion of `total`
// covered by wallet, on top of paymentMethod, regardless of whether
// that's COD or ONLINE. 0 for orders placed before this feature, or
// where the customer never used the toggle.
  @override
  @JsonKey()
  final double walletAmountUsed;
// The server's own status word (ORDER_PLACED, SHIPPED, RETURNED…); `status`
// above folds several of them together.
  @override
  @JsonKey()
  final String rawStatus;
  @override
  final String? cancelledReason;
// When the server moved the order into each status (raw status word →
// first time), from the status history.
  final Map<String, DateTime> _statusTimes;
// When the server moved the order into each status (raw status word →
// first time), from the status history.
  @override
  @JsonKey()
  Map<String, DateTime> get statusTimes {
    if (_statusTimes is EqualUnmodifiableMapView) return _statusTimes;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_statusTimes);
  }

  @override
  final DateTime? paymentExpiresAt;
  @override
  final String? razorpayPaymentId;
  @override
  final String? couponCode;
  @override
  final DateTime? deliveredAt;
  @override
  final DateTime? cancelledAt;
  @override
  final DateTime? estimatedDelivery;
  final Map<String, dynamic> _tracking;
  @override
  @JsonKey()
  Map<String, dynamic> get tracking {
    if (_tracking is EqualUnmodifiableMapView) return _tracking;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_tracking);
  }

  final List<OrderTimelineEntity> _timeline;
  @override
  @JsonKey()
  List<OrderTimelineEntity> get timeline {
    if (_timeline is EqualUnmodifiableListView) return _timeline;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_timeline);
  }

// Delivery slot fields
  @override
  @JsonKey()
  final String deliveryMode;
  @override
  final String? scheduledSlotLabel;
  @override
  final DateTime? scheduledSlotStart;
  @override
  final DateTime? scheduledSlotEnd;
// 4-digit code the customer reads out to the rider on delivery.
// Only present while the assignment is ACCEPTED/IN_TRANSIT.
  @override
  final String? deliveryOtp;
// "Place Order" B2B credit — null for every non-B2B order.
// 'PENDING' until an admin approves it, 'APPROVED' after. There is no
// credit limit; "amount owed" is total minus b2bAmountSettled, settled
// per-order via b2bSettlements rather than an account-level balance.
  @override
  final String? b2bApprovalStatus;
  @override
  @JsonKey()
  final double b2bAmountSettled;
  @override
  final DateTime? b2bPaymentDueDate;
  final List<B2BSettlementEntity> _b2bSettlements;
  @override
  @JsonKey()
  List<B2BSettlementEntity> get b2bSettlements {
    if (_b2bSettlements is EqualUnmodifiableListView) return _b2bSettlements;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_b2bSettlements);
  }

  /// Create a copy of OrderEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$OrderEntityCopyWith<_OrderEntity> get copyWith =>
      __$OrderEntityCopyWithImpl<_OrderEntity>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _OrderEntity &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.orderNumber, orderNumber) ||
                other.orderNumber == orderNumber) &&
            (identical(other.status, status) || other.status == status) &&
            const DeepCollectionEquality().equals(other._items, _items) &&
            (identical(other.subtotal, subtotal) ||
                other.subtotal == subtotal) &&
            (identical(other.discount, discount) ||
                other.discount == discount) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.platformFee, platformFee) ||
                other.platformFee == platformFee) &&
            (identical(other.total, total) || other.total == total) &&
            const DeepCollectionEquality()
                .equals(other._deliveryAddress, _deliveryAddress) &&
            (identical(other.paymentMethod, paymentMethod) ||
                other.paymentMethod == paymentMethod) &&
            (identical(other.paymentStatus, paymentStatus) ||
                other.paymentStatus == paymentStatus) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.walletAmountUsed, walletAmountUsed) ||
                other.walletAmountUsed == walletAmountUsed) &&
            (identical(other.rawStatus, rawStatus) ||
                other.rawStatus == rawStatus) &&
            (identical(other.cancelledReason, cancelledReason) ||
                other.cancelledReason == cancelledReason) &&
            const DeepCollectionEquality()
                .equals(other._statusTimes, _statusTimes) &&
            (identical(other.paymentExpiresAt, paymentExpiresAt) ||
                other.paymentExpiresAt == paymentExpiresAt) &&
            (identical(other.razorpayPaymentId, razorpayPaymentId) ||
                other.razorpayPaymentId == razorpayPaymentId) &&
            (identical(other.couponCode, couponCode) ||
                other.couponCode == couponCode) &&
            (identical(other.deliveredAt, deliveredAt) ||
                other.deliveredAt == deliveredAt) &&
            (identical(other.cancelledAt, cancelledAt) ||
                other.cancelledAt == cancelledAt) &&
            (identical(other.estimatedDelivery, estimatedDelivery) ||
                other.estimatedDelivery == estimatedDelivery) &&
            const DeepCollectionEquality().equals(other._tracking, _tracking) &&
            const DeepCollectionEquality().equals(other._timeline, _timeline) &&
            (identical(other.deliveryMode, deliveryMode) ||
                other.deliveryMode == deliveryMode) &&
            (identical(other.scheduledSlotLabel, scheduledSlotLabel) ||
                other.scheduledSlotLabel == scheduledSlotLabel) &&
            (identical(other.scheduledSlotStart, scheduledSlotStart) ||
                other.scheduledSlotStart == scheduledSlotStart) &&
            (identical(other.scheduledSlotEnd, scheduledSlotEnd) ||
                other.scheduledSlotEnd == scheduledSlotEnd) &&
            (identical(other.deliveryOtp, deliveryOtp) ||
                other.deliveryOtp == deliveryOtp) &&
            (identical(other.b2bApprovalStatus, b2bApprovalStatus) ||
                other.b2bApprovalStatus == b2bApprovalStatus) &&
            (identical(other.b2bAmountSettled, b2bAmountSettled) ||
                other.b2bAmountSettled == b2bAmountSettled) &&
            (identical(other.b2bPaymentDueDate, b2bPaymentDueDate) ||
                other.b2bPaymentDueDate == b2bPaymentDueDate) &&
            const DeepCollectionEquality()
                .equals(other._b2bSettlements, _b2bSettlements));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        orderNumber,
        status,
        const DeepCollectionEquality().hash(_items),
        subtotal,
        discount,
        deliveryFee,
        platformFee,
        total,
        const DeepCollectionEquality().hash(_deliveryAddress),
        paymentMethod,
        paymentStatus,
        createdAt,
        walletAmountUsed,
        rawStatus,
        cancelledReason,
        const DeepCollectionEquality().hash(_statusTimes),
        paymentExpiresAt,
        razorpayPaymentId,
        couponCode,
        deliveredAt,
        cancelledAt,
        estimatedDelivery,
        const DeepCollectionEquality().hash(_tracking),
        const DeepCollectionEquality().hash(_timeline),
        deliveryMode,
        scheduledSlotLabel,
        scheduledSlotStart,
        scheduledSlotEnd,
        deliveryOtp,
        b2bApprovalStatus,
        b2bAmountSettled,
        b2bPaymentDueDate,
        const DeepCollectionEquality().hash(_b2bSettlements)
      ]);

  @override
  String toString() {
    return 'OrderEntity(id: $id, orderNumber: $orderNumber, status: $status, items: $items, subtotal: $subtotal, discount: $discount, deliveryFee: $deliveryFee, platformFee: $platformFee, total: $total, deliveryAddress: $deliveryAddress, paymentMethod: $paymentMethod, paymentStatus: $paymentStatus, createdAt: $createdAt, walletAmountUsed: $walletAmountUsed, rawStatus: $rawStatus, cancelledReason: $cancelledReason, statusTimes: $statusTimes, paymentExpiresAt: $paymentExpiresAt, razorpayPaymentId: $razorpayPaymentId, couponCode: $couponCode, deliveredAt: $deliveredAt, cancelledAt: $cancelledAt, estimatedDelivery: $estimatedDelivery, tracking: $tracking, timeline: $timeline, deliveryMode: $deliveryMode, scheduledSlotLabel: $scheduledSlotLabel, scheduledSlotStart: $scheduledSlotStart, scheduledSlotEnd: $scheduledSlotEnd, deliveryOtp: $deliveryOtp, b2bApprovalStatus: $b2bApprovalStatus, b2bAmountSettled: $b2bAmountSettled, b2bPaymentDueDate: $b2bPaymentDueDate, b2bSettlements: $b2bSettlements)';
  }
}

/// @nodoc
abstract mixin class _$OrderEntityCopyWith<$Res>
    implements $OrderEntityCopyWith<$Res> {
  factory _$OrderEntityCopyWith(
          _OrderEntity value, $Res Function(_OrderEntity) _then) =
      __$OrderEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String orderNumber,
      OrderStatus status,
      List<OrderItemEntity> items,
      double subtotal,
      double discount,
      double deliveryFee,
      double platformFee,
      double total,
      Map<String, dynamic> deliveryAddress,
      String paymentMethod,
      String paymentStatus,
      DateTime createdAt,
      double walletAmountUsed,
      String rawStatus,
      String? cancelledReason,
      Map<String, DateTime> statusTimes,
      DateTime? paymentExpiresAt,
      String? razorpayPaymentId,
      String? couponCode,
      DateTime? deliveredAt,
      DateTime? cancelledAt,
      DateTime? estimatedDelivery,
      Map<String, dynamic> tracking,
      List<OrderTimelineEntity> timeline,
      String deliveryMode,
      String? scheduledSlotLabel,
      DateTime? scheduledSlotStart,
      DateTime? scheduledSlotEnd,
      String? deliveryOtp,
      String? b2bApprovalStatus,
      double b2bAmountSettled,
      DateTime? b2bPaymentDueDate,
      List<B2BSettlementEntity> b2bSettlements});
}

/// @nodoc
class __$OrderEntityCopyWithImpl<$Res> implements _$OrderEntityCopyWith<$Res> {
  __$OrderEntityCopyWithImpl(this._self, this._then);

  final _OrderEntity _self;
  final $Res Function(_OrderEntity) _then;

  /// Create a copy of OrderEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? orderNumber = null,
    Object? status = null,
    Object? items = null,
    Object? subtotal = null,
    Object? discount = null,
    Object? deliveryFee = null,
    Object? platformFee = null,
    Object? total = null,
    Object? deliveryAddress = null,
    Object? paymentMethod = null,
    Object? paymentStatus = null,
    Object? createdAt = null,
    Object? walletAmountUsed = null,
    Object? rawStatus = null,
    Object? cancelledReason = freezed,
    Object? statusTimes = null,
    Object? paymentExpiresAt = freezed,
    Object? razorpayPaymentId = freezed,
    Object? couponCode = freezed,
    Object? deliveredAt = freezed,
    Object? cancelledAt = freezed,
    Object? estimatedDelivery = freezed,
    Object? tracking = null,
    Object? timeline = null,
    Object? deliveryMode = null,
    Object? scheduledSlotLabel = freezed,
    Object? scheduledSlotStart = freezed,
    Object? scheduledSlotEnd = freezed,
    Object? deliveryOtp = freezed,
    Object? b2bApprovalStatus = freezed,
    Object? b2bAmountSettled = null,
    Object? b2bPaymentDueDate = freezed,
    Object? b2bSettlements = null,
  }) {
    return _then(_OrderEntity(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      orderNumber: null == orderNumber
          ? _self.orderNumber
          : orderNumber // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as OrderStatus,
      items: null == items
          ? _self._items
          : items // ignore: cast_nullable_to_non_nullable
              as List<OrderItemEntity>,
      subtotal: null == subtotal
          ? _self.subtotal
          : subtotal // ignore: cast_nullable_to_non_nullable
              as double,
      discount: null == discount
          ? _self.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryFee: null == deliveryFee
          ? _self.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as double,
      platformFee: null == platformFee
          ? _self.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as double,
      total: null == total
          ? _self.total
          : total // ignore: cast_nullable_to_non_nullable
              as double,
      deliveryAddress: null == deliveryAddress
          ? _self._deliveryAddress
          : deliveryAddress // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      paymentMethod: null == paymentMethod
          ? _self.paymentMethod
          : paymentMethod // ignore: cast_nullable_to_non_nullable
              as String,
      paymentStatus: null == paymentStatus
          ? _self.paymentStatus
          : paymentStatus // ignore: cast_nullable_to_non_nullable
              as String,
      createdAt: null == createdAt
          ? _self.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      walletAmountUsed: null == walletAmountUsed
          ? _self.walletAmountUsed
          : walletAmountUsed // ignore: cast_nullable_to_non_nullable
              as double,
      rawStatus: null == rawStatus
          ? _self.rawStatus
          : rawStatus // ignore: cast_nullable_to_non_nullable
              as String,
      cancelledReason: freezed == cancelledReason
          ? _self.cancelledReason
          : cancelledReason // ignore: cast_nullable_to_non_nullable
              as String?,
      statusTimes: null == statusTimes
          ? _self._statusTimes
          : statusTimes // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
      paymentExpiresAt: freezed == paymentExpiresAt
          ? _self.paymentExpiresAt
          : paymentExpiresAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      razorpayPaymentId: freezed == razorpayPaymentId
          ? _self.razorpayPaymentId
          : razorpayPaymentId // ignore: cast_nullable_to_non_nullable
              as String?,
      couponCode: freezed == couponCode
          ? _self.couponCode
          : couponCode // ignore: cast_nullable_to_non_nullable
              as String?,
      deliveredAt: freezed == deliveredAt
          ? _self.deliveredAt
          : deliveredAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      cancelledAt: freezed == cancelledAt
          ? _self.cancelledAt
          : cancelledAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      estimatedDelivery: freezed == estimatedDelivery
          ? _self.estimatedDelivery
          : estimatedDelivery // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      tracking: null == tracking
          ? _self._tracking
          : tracking // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>,
      timeline: null == timeline
          ? _self._timeline
          : timeline // ignore: cast_nullable_to_non_nullable
              as List<OrderTimelineEntity>,
      deliveryMode: null == deliveryMode
          ? _self.deliveryMode
          : deliveryMode // ignore: cast_nullable_to_non_nullable
              as String,
      scheduledSlotLabel: freezed == scheduledSlotLabel
          ? _self.scheduledSlotLabel
          : scheduledSlotLabel // ignore: cast_nullable_to_non_nullable
              as String?,
      scheduledSlotStart: freezed == scheduledSlotStart
          ? _self.scheduledSlotStart
          : scheduledSlotStart // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      scheduledSlotEnd: freezed == scheduledSlotEnd
          ? _self.scheduledSlotEnd
          : scheduledSlotEnd // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      deliveryOtp: freezed == deliveryOtp
          ? _self.deliveryOtp
          : deliveryOtp // ignore: cast_nullable_to_non_nullable
              as String?,
      b2bApprovalStatus: freezed == b2bApprovalStatus
          ? _self.b2bApprovalStatus
          : b2bApprovalStatus // ignore: cast_nullable_to_non_nullable
              as String?,
      b2bAmountSettled: null == b2bAmountSettled
          ? _self.b2bAmountSettled
          : b2bAmountSettled // ignore: cast_nullable_to_non_nullable
              as double,
      b2bPaymentDueDate: freezed == b2bPaymentDueDate
          ? _self.b2bPaymentDueDate
          : b2bPaymentDueDate // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      b2bSettlements: null == b2bSettlements
          ? _self._b2bSettlements
          : b2bSettlements // ignore: cast_nullable_to_non_nullable
              as List<B2BSettlementEntity>,
    ));
  }
}

// dart format on
