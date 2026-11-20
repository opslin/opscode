// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'bill_summary_entity.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BillSummaryEntity {
  ItemTotal get itemTotal;
  DeliveryFeeInfo get deliveryFee;
  FeeInfo get handlingFee;
  LateNightFeeInfo get lateNightFee;
  BillToPay get toPay;
  SavingsBreakdownEntity get savings;
  DeliveryEstimate get deliveryEstimate;
  double get couponDiscount;
  double get tipAmount;
  int get itemCount; // ── Canonical dynamic-fee fields (backend TotalsEngine) ──────────
  FeeInfo get platformFee;
  FeeInfo get smallCartFee;
  DistanceInfo get distance;
  FreeDeliveryInfo get freeDelivery;
  double get totalPayable;
  List<FeeLine> get fees;
  PaymentMethodsInfo get paymentMethods;
  CartMilestoneProgress get cartMilestone;
  QuickDeliveryInfo get quickDelivery;
  FirstTimeOfferInfo? get firstTimeOffer;
  FirstTimeOfferTeaserInfo? get firstTimeOfferTeaser;

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BillSummaryEntityCopyWith<BillSummaryEntity> get copyWith =>
      _$BillSummaryEntityCopyWithImpl<BillSummaryEntity>(
          this as BillSummaryEntity, _$identity);

  /// Serializes this BillSummaryEntity to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BillSummaryEntity &&
            (identical(other.itemTotal, itemTotal) ||
                other.itemTotal == itemTotal) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.handlingFee, handlingFee) ||
                other.handlingFee == handlingFee) &&
            (identical(other.lateNightFee, lateNightFee) ||
                other.lateNightFee == lateNightFee) &&
            (identical(other.toPay, toPay) || other.toPay == toPay) &&
            (identical(other.savings, savings) || other.savings == savings) &&
            (identical(other.deliveryEstimate, deliveryEstimate) ||
                other.deliveryEstimate == deliveryEstimate) &&
            (identical(other.couponDiscount, couponDiscount) ||
                other.couponDiscount == couponDiscount) &&
            (identical(other.tipAmount, tipAmount) ||
                other.tipAmount == tipAmount) &&
            (identical(other.itemCount, itemCount) ||
                other.itemCount == itemCount) &&
            (identical(other.platformFee, platformFee) ||
                other.platformFee == platformFee) &&
            (identical(other.smallCartFee, smallCartFee) ||
                other.smallCartFee == smallCartFee) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            (identical(other.freeDelivery, freeDelivery) ||
                other.freeDelivery == freeDelivery) &&
            (identical(other.totalPayable, totalPayable) ||
                other.totalPayable == totalPayable) &&
            const DeepCollectionEquality().equals(other.fees, fees) &&
            (identical(other.paymentMethods, paymentMethods) ||
                other.paymentMethods == paymentMethods) &&
            (identical(other.cartMilestone, cartMilestone) ||
                other.cartMilestone == cartMilestone) &&
            (identical(other.quickDelivery, quickDelivery) ||
                other.quickDelivery == quickDelivery) &&
            (identical(other.firstTimeOffer, firstTimeOffer) ||
                other.firstTimeOffer == firstTimeOffer) &&
            (identical(other.firstTimeOfferTeaser, firstTimeOfferTeaser) ||
                other.firstTimeOfferTeaser == firstTimeOfferTeaser));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        itemTotal,
        deliveryFee,
        handlingFee,
        lateNightFee,
        toPay,
        savings,
        deliveryEstimate,
        couponDiscount,
        tipAmount,
        itemCount,
        platformFee,
        smallCartFee,
        distance,
        freeDelivery,
        totalPayable,
        const DeepCollectionEquality().hash(fees),
        paymentMethods,
        cartMilestone,
        quickDelivery,
        firstTimeOffer,
        firstTimeOfferTeaser
      ]);

  @override
  String toString() {
    return 'BillSummaryEntity(itemTotal: $itemTotal, deliveryFee: $deliveryFee, handlingFee: $handlingFee, lateNightFee: $lateNightFee, toPay: $toPay, savings: $savings, deliveryEstimate: $deliveryEstimate, couponDiscount: $couponDiscount, tipAmount: $tipAmount, itemCount: $itemCount, platformFee: $platformFee, smallCartFee: $smallCartFee, distance: $distance, freeDelivery: $freeDelivery, totalPayable: $totalPayable, fees: $fees, paymentMethods: $paymentMethods, cartMilestone: $cartMilestone, quickDelivery: $quickDelivery, firstTimeOffer: $firstTimeOffer, firstTimeOfferTeaser: $firstTimeOfferTeaser)';
  }
}

/// @nodoc
abstract mixin class $BillSummaryEntityCopyWith<$Res> {
  factory $BillSummaryEntityCopyWith(
          BillSummaryEntity value, $Res Function(BillSummaryEntity) _then) =
      _$BillSummaryEntityCopyWithImpl;
  @useResult
  $Res call(
      {ItemTotal itemTotal,
      DeliveryFeeInfo deliveryFee,
      FeeInfo handlingFee,
      LateNightFeeInfo lateNightFee,
      BillToPay toPay,
      SavingsBreakdownEntity savings,
      DeliveryEstimate deliveryEstimate,
      double couponDiscount,
      double tipAmount,
      int itemCount,
      FeeInfo platformFee,
      FeeInfo smallCartFee,
      DistanceInfo distance,
      FreeDeliveryInfo freeDelivery,
      double totalPayable,
      List<FeeLine> fees,
      PaymentMethodsInfo paymentMethods,
      CartMilestoneProgress cartMilestone,
      QuickDeliveryInfo quickDelivery,
      FirstTimeOfferInfo? firstTimeOffer,
      FirstTimeOfferTeaserInfo? firstTimeOfferTeaser});

  $ItemTotalCopyWith<$Res> get itemTotal;
  $DeliveryFeeInfoCopyWith<$Res> get deliveryFee;
  $FeeInfoCopyWith<$Res> get handlingFee;
  $LateNightFeeInfoCopyWith<$Res> get lateNightFee;
  $BillToPayCopyWith<$Res> get toPay;
  $SavingsBreakdownEntityCopyWith<$Res> get savings;
  $DeliveryEstimateCopyWith<$Res> get deliveryEstimate;
  $FeeInfoCopyWith<$Res> get platformFee;
  $FeeInfoCopyWith<$Res> get smallCartFee;
  $DistanceInfoCopyWith<$Res> get distance;
  $FreeDeliveryInfoCopyWith<$Res> get freeDelivery;
  $PaymentMethodsInfoCopyWith<$Res> get paymentMethods;
  $CartMilestoneProgressCopyWith<$Res> get cartMilestone;
  $QuickDeliveryInfoCopyWith<$Res> get quickDelivery;
  $FirstTimeOfferInfoCopyWith<$Res>? get firstTimeOffer;
  $FirstTimeOfferTeaserInfoCopyWith<$Res>? get firstTimeOfferTeaser;
}

/// @nodoc
class _$BillSummaryEntityCopyWithImpl<$Res>
    implements $BillSummaryEntityCopyWith<$Res> {
  _$BillSummaryEntityCopyWithImpl(this._self, this._then);

  final BillSummaryEntity _self;
  final $Res Function(BillSummaryEntity) _then;

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? itemTotal = null,
    Object? deliveryFee = null,
    Object? handlingFee = null,
    Object? lateNightFee = null,
    Object? toPay = null,
    Object? savings = null,
    Object? deliveryEstimate = null,
    Object? couponDiscount = null,
    Object? tipAmount = null,
    Object? itemCount = null,
    Object? platformFee = null,
    Object? smallCartFee = null,
    Object? distance = null,
    Object? freeDelivery = null,
    Object? totalPayable = null,
    Object? fees = null,
    Object? paymentMethods = null,
    Object? cartMilestone = null,
    Object? quickDelivery = null,
    Object? firstTimeOffer = freezed,
    Object? firstTimeOfferTeaser = freezed,
  }) {
    return _then(_self.copyWith(
      itemTotal: null == itemTotal
          ? _self.itemTotal
          : itemTotal // ignore: cast_nullable_to_non_nullable
              as ItemTotal,
      deliveryFee: null == deliveryFee
          ? _self.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as DeliveryFeeInfo,
      handlingFee: null == handlingFee
          ? _self.handlingFee
          : handlingFee // ignore: cast_nullable_to_non_nullable
              as FeeInfo,
      lateNightFee: null == lateNightFee
          ? _self.lateNightFee
          : lateNightFee // ignore: cast_nullable_to_non_nullable
              as LateNightFeeInfo,
      toPay: null == toPay
          ? _self.toPay
          : toPay // ignore: cast_nullable_to_non_nullable
              as BillToPay,
      savings: null == savings
          ? _self.savings
          : savings // ignore: cast_nullable_to_non_nullable
              as SavingsBreakdownEntity,
      deliveryEstimate: null == deliveryEstimate
          ? _self.deliveryEstimate
          : deliveryEstimate // ignore: cast_nullable_to_non_nullable
              as DeliveryEstimate,
      couponDiscount: null == couponDiscount
          ? _self.couponDiscount
          : couponDiscount // ignore: cast_nullable_to_non_nullable
              as double,
      tipAmount: null == tipAmount
          ? _self.tipAmount
          : tipAmount // ignore: cast_nullable_to_non_nullable
              as double,
      itemCount: null == itemCount
          ? _self.itemCount
          : itemCount // ignore: cast_nullable_to_non_nullable
              as int,
      platformFee: null == platformFee
          ? _self.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as FeeInfo,
      smallCartFee: null == smallCartFee
          ? _self.smallCartFee
          : smallCartFee // ignore: cast_nullable_to_non_nullable
              as FeeInfo,
      distance: null == distance
          ? _self.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as DistanceInfo,
      freeDelivery: null == freeDelivery
          ? _self.freeDelivery
          : freeDelivery // ignore: cast_nullable_to_non_nullable
              as FreeDeliveryInfo,
      totalPayable: null == totalPayable
          ? _self.totalPayable
          : totalPayable // ignore: cast_nullable_to_non_nullable
              as double,
      fees: null == fees
          ? _self.fees
          : fees // ignore: cast_nullable_to_non_nullable
              as List<FeeLine>,
      paymentMethods: null == paymentMethods
          ? _self.paymentMethods
          : paymentMethods // ignore: cast_nullable_to_non_nullable
              as PaymentMethodsInfo,
      cartMilestone: null == cartMilestone
          ? _self.cartMilestone
          : cartMilestone // ignore: cast_nullable_to_non_nullable
              as CartMilestoneProgress,
      quickDelivery: null == quickDelivery
          ? _self.quickDelivery
          : quickDelivery // ignore: cast_nullable_to_non_nullable
              as QuickDeliveryInfo,
      firstTimeOffer: freezed == firstTimeOffer
          ? _self.firstTimeOffer
          : firstTimeOffer // ignore: cast_nullable_to_non_nullable
              as FirstTimeOfferInfo?,
      firstTimeOfferTeaser: freezed == firstTimeOfferTeaser
          ? _self.firstTimeOfferTeaser
          : firstTimeOfferTeaser // ignore: cast_nullable_to_non_nullable
              as FirstTimeOfferTeaserInfo?,
    ));
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ItemTotalCopyWith<$Res> get itemTotal {
    return $ItemTotalCopyWith<$Res>(_self.itemTotal, (value) {
      return _then(_self.copyWith(itemTotal: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeliveryFeeInfoCopyWith<$Res> get deliveryFee {
    return $DeliveryFeeInfoCopyWith<$Res>(_self.deliveryFee, (value) {
      return _then(_self.copyWith(deliveryFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeeInfoCopyWith<$Res> get handlingFee {
    return $FeeInfoCopyWith<$Res>(_self.handlingFee, (value) {
      return _then(_self.copyWith(handlingFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LateNightFeeInfoCopyWith<$Res> get lateNightFee {
    return $LateNightFeeInfoCopyWith<$Res>(_self.lateNightFee, (value) {
      return _then(_self.copyWith(lateNightFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BillToPayCopyWith<$Res> get toPay {
    return $BillToPayCopyWith<$Res>(_self.toPay, (value) {
      return _then(_self.copyWith(toPay: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SavingsBreakdownEntityCopyWith<$Res> get savings {
    return $SavingsBreakdownEntityCopyWith<$Res>(_self.savings, (value) {
      return _then(_self.copyWith(savings: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeliveryEstimateCopyWith<$Res> get deliveryEstimate {
    return $DeliveryEstimateCopyWith<$Res>(_self.deliveryEstimate, (value) {
      return _then(_self.copyWith(deliveryEstimate: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeeInfoCopyWith<$Res> get platformFee {
    return $FeeInfoCopyWith<$Res>(_self.platformFee, (value) {
      return _then(_self.copyWith(platformFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeeInfoCopyWith<$Res> get smallCartFee {
    return $FeeInfoCopyWith<$Res>(_self.smallCartFee, (value) {
      return _then(_self.copyWith(smallCartFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DistanceInfoCopyWith<$Res> get distance {
    return $DistanceInfoCopyWith<$Res>(_self.distance, (value) {
      return _then(_self.copyWith(distance: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FreeDeliveryInfoCopyWith<$Res> get freeDelivery {
    return $FreeDeliveryInfoCopyWith<$Res>(_self.freeDelivery, (value) {
      return _then(_self.copyWith(freeDelivery: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PaymentMethodsInfoCopyWith<$Res> get paymentMethods {
    return $PaymentMethodsInfoCopyWith<$Res>(_self.paymentMethods, (value) {
      return _then(_self.copyWith(paymentMethods: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CartMilestoneProgressCopyWith<$Res> get cartMilestone {
    return $CartMilestoneProgressCopyWith<$Res>(_self.cartMilestone, (value) {
      return _then(_self.copyWith(cartMilestone: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuickDeliveryInfoCopyWith<$Res> get quickDelivery {
    return $QuickDeliveryInfoCopyWith<$Res>(_self.quickDelivery, (value) {
      return _then(_self.copyWith(quickDelivery: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FirstTimeOfferInfoCopyWith<$Res>? get firstTimeOffer {
    if (_self.firstTimeOffer == null) {
      return null;
    }

    return $FirstTimeOfferInfoCopyWith<$Res>(_self.firstTimeOffer!, (value) {
      return _then(_self.copyWith(firstTimeOffer: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FirstTimeOfferTeaserInfoCopyWith<$Res>? get firstTimeOfferTeaser {
    if (_self.firstTimeOfferTeaser == null) {
      return null;
    }

    return $FirstTimeOfferTeaserInfoCopyWith<$Res>(_self.firstTimeOfferTeaser!,
        (value) {
      return _then(_self.copyWith(firstTimeOfferTeaser: value));
    });
  }
}

/// Adds pattern-matching-related methods to [BillSummaryEntity].
extension BillSummaryEntityPatterns on BillSummaryEntity {
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
    TResult Function(_BillSummaryEntity value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BillSummaryEntity() when $default != null:
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
    TResult Function(_BillSummaryEntity value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillSummaryEntity():
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
    TResult? Function(_BillSummaryEntity value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillSummaryEntity() when $default != null:
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
            ItemTotal itemTotal,
            DeliveryFeeInfo deliveryFee,
            FeeInfo handlingFee,
            LateNightFeeInfo lateNightFee,
            BillToPay toPay,
            SavingsBreakdownEntity savings,
            DeliveryEstimate deliveryEstimate,
            double couponDiscount,
            double tipAmount,
            int itemCount,
            FeeInfo platformFee,
            FeeInfo smallCartFee,
            DistanceInfo distance,
            FreeDeliveryInfo freeDelivery,
            double totalPayable,
            List<FeeLine> fees,
            PaymentMethodsInfo paymentMethods,
            CartMilestoneProgress cartMilestone,
            QuickDeliveryInfo quickDelivery,
            FirstTimeOfferInfo? firstTimeOffer,
            FirstTimeOfferTeaserInfo? firstTimeOfferTeaser)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BillSummaryEntity() when $default != null:
        return $default(
            _that.itemTotal,
            _that.deliveryFee,
            _that.handlingFee,
            _that.lateNightFee,
            _that.toPay,
            _that.savings,
            _that.deliveryEstimate,
            _that.couponDiscount,
            _that.tipAmount,
            _that.itemCount,
            _that.platformFee,
            _that.smallCartFee,
            _that.distance,
            _that.freeDelivery,
            _that.totalPayable,
            _that.fees,
            _that.paymentMethods,
            _that.cartMilestone,
            _that.quickDelivery,
            _that.firstTimeOffer,
            _that.firstTimeOfferTeaser);
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
            ItemTotal itemTotal,
            DeliveryFeeInfo deliveryFee,
            FeeInfo handlingFee,
            LateNightFeeInfo lateNightFee,
            BillToPay toPay,
            SavingsBreakdownEntity savings,
            DeliveryEstimate deliveryEstimate,
            double couponDiscount,
            double tipAmount,
            int itemCount,
            FeeInfo platformFee,
            FeeInfo smallCartFee,
            DistanceInfo distance,
            FreeDeliveryInfo freeDelivery,
            double totalPayable,
            List<FeeLine> fees,
            PaymentMethodsInfo paymentMethods,
            CartMilestoneProgress cartMilestone,
            QuickDeliveryInfo quickDelivery,
            FirstTimeOfferInfo? firstTimeOffer,
            FirstTimeOfferTeaserInfo? firstTimeOfferTeaser)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillSummaryEntity():
        return $default(
            _that.itemTotal,
            _that.deliveryFee,
            _that.handlingFee,
            _that.lateNightFee,
            _that.toPay,
            _that.savings,
            _that.deliveryEstimate,
            _that.couponDiscount,
            _that.tipAmount,
            _that.itemCount,
            _that.platformFee,
            _that.smallCartFee,
            _that.distance,
            _that.freeDelivery,
            _that.totalPayable,
            _that.fees,
            _that.paymentMethods,
            _that.cartMilestone,
            _that.quickDelivery,
            _that.firstTimeOffer,
            _that.firstTimeOfferTeaser);
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
            ItemTotal itemTotal,
            DeliveryFeeInfo deliveryFee,
            FeeInfo handlingFee,
            LateNightFeeInfo lateNightFee,
            BillToPay toPay,
            SavingsBreakdownEntity savings,
            DeliveryEstimate deliveryEstimate,
            double couponDiscount,
            double tipAmount,
            int itemCount,
            FeeInfo platformFee,
            FeeInfo smallCartFee,
            DistanceInfo distance,
            FreeDeliveryInfo freeDelivery,
            double totalPayable,
            List<FeeLine> fees,
            PaymentMethodsInfo paymentMethods,
            CartMilestoneProgress cartMilestone,
            QuickDeliveryInfo quickDelivery,
            FirstTimeOfferInfo? firstTimeOffer,
            FirstTimeOfferTeaserInfo? firstTimeOfferTeaser)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillSummaryEntity() when $default != null:
        return $default(
            _that.itemTotal,
            _that.deliveryFee,
            _that.handlingFee,
            _that.lateNightFee,
            _that.toPay,
            _that.savings,
            _that.deliveryEstimate,
            _that.couponDiscount,
            _that.tipAmount,
            _that.itemCount,
            _that.platformFee,
            _that.smallCartFee,
            _that.distance,
            _that.freeDelivery,
            _that.totalPayable,
            _that.fees,
            _that.paymentMethods,
            _that.cartMilestone,
            _that.quickDelivery,
            _that.firstTimeOffer,
            _that.firstTimeOfferTeaser);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BillSummaryEntity extends BillSummaryEntity {
  const _BillSummaryEntity(
      {required this.itemTotal,
      required this.deliveryFee,
      required this.handlingFee,
      required this.lateNightFee,
      required this.toPay,
      required this.savings,
      required this.deliveryEstimate,
      this.couponDiscount = 0,
      this.tipAmount = 0,
      this.itemCount = 0,
      this.platformFee = const FeeInfo(),
      this.smallCartFee = const FeeInfo(),
      this.distance = const DistanceInfo(),
      this.freeDelivery = const FreeDeliveryInfo(),
      this.totalPayable = 0,
      final List<FeeLine> fees = const <FeeLine>[],
      this.paymentMethods = const PaymentMethodsInfo(),
      this.cartMilestone = const CartMilestoneProgress(),
      this.quickDelivery = const QuickDeliveryInfo(),
      this.firstTimeOffer,
      this.firstTimeOfferTeaser})
      : _fees = fees,
        super._();
  factory _BillSummaryEntity.fromJson(Map<String, dynamic> json) =>
      _$BillSummaryEntityFromJson(json);

  @override
  final ItemTotal itemTotal;
  @override
  final DeliveryFeeInfo deliveryFee;
  @override
  final FeeInfo handlingFee;
  @override
  final LateNightFeeInfo lateNightFee;
  @override
  final BillToPay toPay;
  @override
  final SavingsBreakdownEntity savings;
  @override
  final DeliveryEstimate deliveryEstimate;
  @override
  @JsonKey()
  final double couponDiscount;
  @override
  @JsonKey()
  final double tipAmount;
  @override
  @JsonKey()
  final int itemCount;
// ── Canonical dynamic-fee fields (backend TotalsEngine) ──────────
  @override
  @JsonKey()
  final FeeInfo platformFee;
  @override
  @JsonKey()
  final FeeInfo smallCartFee;
  @override
  @JsonKey()
  final DistanceInfo distance;
  @override
  @JsonKey()
  final FreeDeliveryInfo freeDelivery;
  @override
  @JsonKey()
  final double totalPayable;
  final List<FeeLine> _fees;
  @override
  @JsonKey()
  List<FeeLine> get fees {
    if (_fees is EqualUnmodifiableListView) return _fees;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_fees);
  }

  @override
  @JsonKey()
  final PaymentMethodsInfo paymentMethods;
  @override
  @JsonKey()
  final CartMilestoneProgress cartMilestone;
  @override
  @JsonKey()
  final QuickDeliveryInfo quickDelivery;
  @override
  final FirstTimeOfferInfo? firstTimeOffer;
  @override
  final FirstTimeOfferTeaserInfo? firstTimeOfferTeaser;

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BillSummaryEntityCopyWith<_BillSummaryEntity> get copyWith =>
      __$BillSummaryEntityCopyWithImpl<_BillSummaryEntity>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BillSummaryEntityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BillSummaryEntity &&
            (identical(other.itemTotal, itemTotal) ||
                other.itemTotal == itemTotal) &&
            (identical(other.deliveryFee, deliveryFee) ||
                other.deliveryFee == deliveryFee) &&
            (identical(other.handlingFee, handlingFee) ||
                other.handlingFee == handlingFee) &&
            (identical(other.lateNightFee, lateNightFee) ||
                other.lateNightFee == lateNightFee) &&
            (identical(other.toPay, toPay) || other.toPay == toPay) &&
            (identical(other.savings, savings) || other.savings == savings) &&
            (identical(other.deliveryEstimate, deliveryEstimate) ||
                other.deliveryEstimate == deliveryEstimate) &&
            (identical(other.couponDiscount, couponDiscount) ||
                other.couponDiscount == couponDiscount) &&
            (identical(other.tipAmount, tipAmount) ||
                other.tipAmount == tipAmount) &&
            (identical(other.itemCount, itemCount) ||
                other.itemCount == itemCount) &&
            (identical(other.platformFee, platformFee) ||
                other.platformFee == platformFee) &&
            (identical(other.smallCartFee, smallCartFee) ||
                other.smallCartFee == smallCartFee) &&
            (identical(other.distance, distance) ||
                other.distance == distance) &&
            (identical(other.freeDelivery, freeDelivery) ||
                other.freeDelivery == freeDelivery) &&
            (identical(other.totalPayable, totalPayable) ||
                other.totalPayable == totalPayable) &&
            const DeepCollectionEquality().equals(other._fees, _fees) &&
            (identical(other.paymentMethods, paymentMethods) ||
                other.paymentMethods == paymentMethods) &&
            (identical(other.cartMilestone, cartMilestone) ||
                other.cartMilestone == cartMilestone) &&
            (identical(other.quickDelivery, quickDelivery) ||
                other.quickDelivery == quickDelivery) &&
            (identical(other.firstTimeOffer, firstTimeOffer) ||
                other.firstTimeOffer == firstTimeOffer) &&
            (identical(other.firstTimeOfferTeaser, firstTimeOfferTeaser) ||
                other.firstTimeOfferTeaser == firstTimeOfferTeaser));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        itemTotal,
        deliveryFee,
        handlingFee,
        lateNightFee,
        toPay,
        savings,
        deliveryEstimate,
        couponDiscount,
        tipAmount,
        itemCount,
        platformFee,
        smallCartFee,
        distance,
        freeDelivery,
        totalPayable,
        const DeepCollectionEquality().hash(_fees),
        paymentMethods,
        cartMilestone,
        quickDelivery,
        firstTimeOffer,
        firstTimeOfferTeaser
      ]);

  @override
  String toString() {
    return 'BillSummaryEntity(itemTotal: $itemTotal, deliveryFee: $deliveryFee, handlingFee: $handlingFee, lateNightFee: $lateNightFee, toPay: $toPay, savings: $savings, deliveryEstimate: $deliveryEstimate, couponDiscount: $couponDiscount, tipAmount: $tipAmount, itemCount: $itemCount, platformFee: $platformFee, smallCartFee: $smallCartFee, distance: $distance, freeDelivery: $freeDelivery, totalPayable: $totalPayable, fees: $fees, paymentMethods: $paymentMethods, cartMilestone: $cartMilestone, quickDelivery: $quickDelivery, firstTimeOffer: $firstTimeOffer, firstTimeOfferTeaser: $firstTimeOfferTeaser)';
  }
}

/// @nodoc
abstract mixin class _$BillSummaryEntityCopyWith<$Res>
    implements $BillSummaryEntityCopyWith<$Res> {
  factory _$BillSummaryEntityCopyWith(
          _BillSummaryEntity value, $Res Function(_BillSummaryEntity) _then) =
      __$BillSummaryEntityCopyWithImpl;
  @override
  @useResult
  $Res call(
      {ItemTotal itemTotal,
      DeliveryFeeInfo deliveryFee,
      FeeInfo handlingFee,
      LateNightFeeInfo lateNightFee,
      BillToPay toPay,
      SavingsBreakdownEntity savings,
      DeliveryEstimate deliveryEstimate,
      double couponDiscount,
      double tipAmount,
      int itemCount,
      FeeInfo platformFee,
      FeeInfo smallCartFee,
      DistanceInfo distance,
      FreeDeliveryInfo freeDelivery,
      double totalPayable,
      List<FeeLine> fees,
      PaymentMethodsInfo paymentMethods,
      CartMilestoneProgress cartMilestone,
      QuickDeliveryInfo quickDelivery,
      FirstTimeOfferInfo? firstTimeOffer,
      FirstTimeOfferTeaserInfo? firstTimeOfferTeaser});

  @override
  $ItemTotalCopyWith<$Res> get itemTotal;
  @override
  $DeliveryFeeInfoCopyWith<$Res> get deliveryFee;
  @override
  $FeeInfoCopyWith<$Res> get handlingFee;
  @override
  $LateNightFeeInfoCopyWith<$Res> get lateNightFee;
  @override
  $BillToPayCopyWith<$Res> get toPay;
  @override
  $SavingsBreakdownEntityCopyWith<$Res> get savings;
  @override
  $DeliveryEstimateCopyWith<$Res> get deliveryEstimate;
  @override
  $FeeInfoCopyWith<$Res> get platformFee;
  @override
  $FeeInfoCopyWith<$Res> get smallCartFee;
  @override
  $DistanceInfoCopyWith<$Res> get distance;
  @override
  $FreeDeliveryInfoCopyWith<$Res> get freeDelivery;
  @override
  $PaymentMethodsInfoCopyWith<$Res> get paymentMethods;
  @override
  $CartMilestoneProgressCopyWith<$Res> get cartMilestone;
  @override
  $QuickDeliveryInfoCopyWith<$Res> get quickDelivery;
  @override
  $FirstTimeOfferInfoCopyWith<$Res>? get firstTimeOffer;
  @override
  $FirstTimeOfferTeaserInfoCopyWith<$Res>? get firstTimeOfferTeaser;
}

/// @nodoc
class __$BillSummaryEntityCopyWithImpl<$Res>
    implements _$BillSummaryEntityCopyWith<$Res> {
  __$BillSummaryEntityCopyWithImpl(this._self, this._then);

  final _BillSummaryEntity _self;
  final $Res Function(_BillSummaryEntity) _then;

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? itemTotal = null,
    Object? deliveryFee = null,
    Object? handlingFee = null,
    Object? lateNightFee = null,
    Object? toPay = null,
    Object? savings = null,
    Object? deliveryEstimate = null,
    Object? couponDiscount = null,
    Object? tipAmount = null,
    Object? itemCount = null,
    Object? platformFee = null,
    Object? smallCartFee = null,
    Object? distance = null,
    Object? freeDelivery = null,
    Object? totalPayable = null,
    Object? fees = null,
    Object? paymentMethods = null,
    Object? cartMilestone = null,
    Object? quickDelivery = null,
    Object? firstTimeOffer = freezed,
    Object? firstTimeOfferTeaser = freezed,
  }) {
    return _then(_BillSummaryEntity(
      itemTotal: null == itemTotal
          ? _self.itemTotal
          : itemTotal // ignore: cast_nullable_to_non_nullable
              as ItemTotal,
      deliveryFee: null == deliveryFee
          ? _self.deliveryFee
          : deliveryFee // ignore: cast_nullable_to_non_nullable
              as DeliveryFeeInfo,
      handlingFee: null == handlingFee
          ? _self.handlingFee
          : handlingFee // ignore: cast_nullable_to_non_nullable
              as FeeInfo,
      lateNightFee: null == lateNightFee
          ? _self.lateNightFee
          : lateNightFee // ignore: cast_nullable_to_non_nullable
              as LateNightFeeInfo,
      toPay: null == toPay
          ? _self.toPay
          : toPay // ignore: cast_nullable_to_non_nullable
              as BillToPay,
      savings: null == savings
          ? _self.savings
          : savings // ignore: cast_nullable_to_non_nullable
              as SavingsBreakdownEntity,
      deliveryEstimate: null == deliveryEstimate
          ? _self.deliveryEstimate
          : deliveryEstimate // ignore: cast_nullable_to_non_nullable
              as DeliveryEstimate,
      couponDiscount: null == couponDiscount
          ? _self.couponDiscount
          : couponDiscount // ignore: cast_nullable_to_non_nullable
              as double,
      tipAmount: null == tipAmount
          ? _self.tipAmount
          : tipAmount // ignore: cast_nullable_to_non_nullable
              as double,
      itemCount: null == itemCount
          ? _self.itemCount
          : itemCount // ignore: cast_nullable_to_non_nullable
              as int,
      platformFee: null == platformFee
          ? _self.platformFee
          : platformFee // ignore: cast_nullable_to_non_nullable
              as FeeInfo,
      smallCartFee: null == smallCartFee
          ? _self.smallCartFee
          : smallCartFee // ignore: cast_nullable_to_non_nullable
              as FeeInfo,
      distance: null == distance
          ? _self.distance
          : distance // ignore: cast_nullable_to_non_nullable
              as DistanceInfo,
      freeDelivery: null == freeDelivery
          ? _self.freeDelivery
          : freeDelivery // ignore: cast_nullable_to_non_nullable
              as FreeDeliveryInfo,
      totalPayable: null == totalPayable
          ? _self.totalPayable
          : totalPayable // ignore: cast_nullable_to_non_nullable
              as double,
      fees: null == fees
          ? _self._fees
          : fees // ignore: cast_nullable_to_non_nullable
              as List<FeeLine>,
      paymentMethods: null == paymentMethods
          ? _self.paymentMethods
          : paymentMethods // ignore: cast_nullable_to_non_nullable
              as PaymentMethodsInfo,
      cartMilestone: null == cartMilestone
          ? _self.cartMilestone
          : cartMilestone // ignore: cast_nullable_to_non_nullable
              as CartMilestoneProgress,
      quickDelivery: null == quickDelivery
          ? _self.quickDelivery
          : quickDelivery // ignore: cast_nullable_to_non_nullable
              as QuickDeliveryInfo,
      firstTimeOffer: freezed == firstTimeOffer
          ? _self.firstTimeOffer
          : firstTimeOffer // ignore: cast_nullable_to_non_nullable
              as FirstTimeOfferInfo?,
      firstTimeOfferTeaser: freezed == firstTimeOfferTeaser
          ? _self.firstTimeOfferTeaser
          : firstTimeOfferTeaser // ignore: cast_nullable_to_non_nullable
              as FirstTimeOfferTeaserInfo?,
    ));
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $ItemTotalCopyWith<$Res> get itemTotal {
    return $ItemTotalCopyWith<$Res>(_self.itemTotal, (value) {
      return _then(_self.copyWith(itemTotal: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeliveryFeeInfoCopyWith<$Res> get deliveryFee {
    return $DeliveryFeeInfoCopyWith<$Res>(_self.deliveryFee, (value) {
      return _then(_self.copyWith(deliveryFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeeInfoCopyWith<$Res> get handlingFee {
    return $FeeInfoCopyWith<$Res>(_self.handlingFee, (value) {
      return _then(_self.copyWith(handlingFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $LateNightFeeInfoCopyWith<$Res> get lateNightFee {
    return $LateNightFeeInfoCopyWith<$Res>(_self.lateNightFee, (value) {
      return _then(_self.copyWith(lateNightFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $BillToPayCopyWith<$Res> get toPay {
    return $BillToPayCopyWith<$Res>(_self.toPay, (value) {
      return _then(_self.copyWith(toPay: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $SavingsBreakdownEntityCopyWith<$Res> get savings {
    return $SavingsBreakdownEntityCopyWith<$Res>(_self.savings, (value) {
      return _then(_self.copyWith(savings: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DeliveryEstimateCopyWith<$Res> get deliveryEstimate {
    return $DeliveryEstimateCopyWith<$Res>(_self.deliveryEstimate, (value) {
      return _then(_self.copyWith(deliveryEstimate: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeeInfoCopyWith<$Res> get platformFee {
    return $FeeInfoCopyWith<$Res>(_self.platformFee, (value) {
      return _then(_self.copyWith(platformFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FeeInfoCopyWith<$Res> get smallCartFee {
    return $FeeInfoCopyWith<$Res>(_self.smallCartFee, (value) {
      return _then(_self.copyWith(smallCartFee: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $DistanceInfoCopyWith<$Res> get distance {
    return $DistanceInfoCopyWith<$Res>(_self.distance, (value) {
      return _then(_self.copyWith(distance: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FreeDeliveryInfoCopyWith<$Res> get freeDelivery {
    return $FreeDeliveryInfoCopyWith<$Res>(_self.freeDelivery, (value) {
      return _then(_self.copyWith(freeDelivery: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PaymentMethodsInfoCopyWith<$Res> get paymentMethods {
    return $PaymentMethodsInfoCopyWith<$Res>(_self.paymentMethods, (value) {
      return _then(_self.copyWith(paymentMethods: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CartMilestoneProgressCopyWith<$Res> get cartMilestone {
    return $CartMilestoneProgressCopyWith<$Res>(_self.cartMilestone, (value) {
      return _then(_self.copyWith(cartMilestone: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $QuickDeliveryInfoCopyWith<$Res> get quickDelivery {
    return $QuickDeliveryInfoCopyWith<$Res>(_self.quickDelivery, (value) {
      return _then(_self.copyWith(quickDelivery: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FirstTimeOfferInfoCopyWith<$Res>? get firstTimeOffer {
    if (_self.firstTimeOffer == null) {
      return null;
    }

    return $FirstTimeOfferInfoCopyWith<$Res>(_self.firstTimeOffer!, (value) {
      return _then(_self.copyWith(firstTimeOffer: value));
    });
  }

  /// Create a copy of BillSummaryEntity
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $FirstTimeOfferTeaserInfoCopyWith<$Res>? get firstTimeOfferTeaser {
    if (_self.firstTimeOfferTeaser == null) {
      return null;
    }

    return $FirstTimeOfferTeaserInfoCopyWith<$Res>(_self.firstTimeOfferTeaser!,
        (value) {
      return _then(_self.copyWith(firstTimeOfferTeaser: value));
    });
  }
}

/// @nodoc
mixin _$ItemTotal {
  double get original;
  double get discounted;

  /// Create a copy of ItemTotal
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $ItemTotalCopyWith<ItemTotal> get copyWith =>
      _$ItemTotalCopyWithImpl<ItemTotal>(this as ItemTotal, _$identity);

  /// Serializes this ItemTotal to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is ItemTotal &&
            (identical(other.original, original) ||
                other.original == original) &&
            (identical(other.discounted, discounted) ||
                other.discounted == discounted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, original, discounted);

  @override
  String toString() {
    return 'ItemTotal(original: $original, discounted: $discounted)';
  }
}

/// @nodoc
abstract mixin class $ItemTotalCopyWith<$Res> {
  factory $ItemTotalCopyWith(ItemTotal value, $Res Function(ItemTotal) _then) =
      _$ItemTotalCopyWithImpl;
  @useResult
  $Res call({double original, double discounted});
}

/// @nodoc
class _$ItemTotalCopyWithImpl<$Res> implements $ItemTotalCopyWith<$Res> {
  _$ItemTotalCopyWithImpl(this._self, this._then);

  final ItemTotal _self;
  final $Res Function(ItemTotal) _then;

  /// Create a copy of ItemTotal
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? original = null,
    Object? discounted = null,
  }) {
    return _then(_self.copyWith(
      original: null == original
          ? _self.original
          : original // ignore: cast_nullable_to_non_nullable
              as double,
      discounted: null == discounted
          ? _self.discounted
          : discounted // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [ItemTotal].
extension ItemTotalPatterns on ItemTotal {
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
    TResult Function(_ItemTotal value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ItemTotal() when $default != null:
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
    TResult Function(_ItemTotal value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ItemTotal():
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
    TResult? Function(_ItemTotal value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ItemTotal() when $default != null:
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
    TResult Function(double original, double discounted)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _ItemTotal() when $default != null:
        return $default(_that.original, _that.discounted);
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
    TResult Function(double original, double discounted) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ItemTotal():
        return $default(_that.original, _that.discounted);
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
    TResult? Function(double original, double discounted)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _ItemTotal() when $default != null:
        return $default(_that.original, _that.discounted);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _ItemTotal implements ItemTotal {
  const _ItemTotal({this.original = 0, this.discounted = 0});
  factory _ItemTotal.fromJson(Map<String, dynamic> json) =>
      _$ItemTotalFromJson(json);

  @override
  @JsonKey()
  final double original;
  @override
  @JsonKey()
  final double discounted;

  /// Create a copy of ItemTotal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ItemTotalCopyWith<_ItemTotal> get copyWith =>
      __$ItemTotalCopyWithImpl<_ItemTotal>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$ItemTotalToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _ItemTotal &&
            (identical(other.original, original) ||
                other.original == original) &&
            (identical(other.discounted, discounted) ||
                other.discounted == discounted));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, original, discounted);

  @override
  String toString() {
    return 'ItemTotal(original: $original, discounted: $discounted)';
  }
}

/// @nodoc
abstract mixin class _$ItemTotalCopyWith<$Res>
    implements $ItemTotalCopyWith<$Res> {
  factory _$ItemTotalCopyWith(
          _ItemTotal value, $Res Function(_ItemTotal) _then) =
      __$ItemTotalCopyWithImpl;
  @override
  @useResult
  $Res call({double original, double discounted});
}

/// @nodoc
class __$ItemTotalCopyWithImpl<$Res> implements _$ItemTotalCopyWith<$Res> {
  __$ItemTotalCopyWithImpl(this._self, this._then);

  final _ItemTotal _self;
  final $Res Function(_ItemTotal) _then;

  /// Create a copy of ItemTotal
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? original = null,
    Object? discounted = null,
  }) {
    return _then(_ItemTotal(
      original: null == original
          ? _self.original
          : original // ignore: cast_nullable_to_non_nullable
              as double,
      discounted: null == discounted
          ? _self.discounted
          : discounted // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$DeliveryFeeInfo {
  double get amount;
  bool get isFree;
  double get freeIn;
  double get originalAmount;
  String? get waiverReason;

  /// Create a copy of DeliveryFeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DeliveryFeeInfoCopyWith<DeliveryFeeInfo> get copyWith =>
      _$DeliveryFeeInfoCopyWithImpl<DeliveryFeeInfo>(
          this as DeliveryFeeInfo, _$identity);

  /// Serializes this DeliveryFeeInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DeliveryFeeInfo &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.isFree, isFree) || other.isFree == isFree) &&
            (identical(other.freeIn, freeIn) || other.freeIn == freeIn) &&
            (identical(other.originalAmount, originalAmount) ||
                other.originalAmount == originalAmount) &&
            (identical(other.waiverReason, waiverReason) ||
                other.waiverReason == waiverReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, amount, isFree, freeIn, originalAmount, waiverReason);

  @override
  String toString() {
    return 'DeliveryFeeInfo(amount: $amount, isFree: $isFree, freeIn: $freeIn, originalAmount: $originalAmount, waiverReason: $waiverReason)';
  }
}

/// @nodoc
abstract mixin class $DeliveryFeeInfoCopyWith<$Res> {
  factory $DeliveryFeeInfoCopyWith(
          DeliveryFeeInfo value, $Res Function(DeliveryFeeInfo) _then) =
      _$DeliveryFeeInfoCopyWithImpl;
  @useResult
  $Res call(
      {double amount,
      bool isFree,
      double freeIn,
      double originalAmount,
      String? waiverReason});
}

/// @nodoc
class _$DeliveryFeeInfoCopyWithImpl<$Res>
    implements $DeliveryFeeInfoCopyWith<$Res> {
  _$DeliveryFeeInfoCopyWithImpl(this._self, this._then);

  final DeliveryFeeInfo _self;
  final $Res Function(DeliveryFeeInfo) _then;

  /// Create a copy of DeliveryFeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? isFree = null,
    Object? freeIn = null,
    Object? originalAmount = null,
    Object? waiverReason = freezed,
  }) {
    return _then(_self.copyWith(
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      isFree: null == isFree
          ? _self.isFree
          : isFree // ignore: cast_nullable_to_non_nullable
              as bool,
      freeIn: null == freeIn
          ? _self.freeIn
          : freeIn // ignore: cast_nullable_to_non_nullable
              as double,
      originalAmount: null == originalAmount
          ? _self.originalAmount
          : originalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      waiverReason: freezed == waiverReason
          ? _self.waiverReason
          : waiverReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [DeliveryFeeInfo].
extension DeliveryFeeInfoPatterns on DeliveryFeeInfo {
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
    TResult Function(_DeliveryFeeInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeliveryFeeInfo() when $default != null:
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
    TResult Function(_DeliveryFeeInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeliveryFeeInfo():
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
    TResult? Function(_DeliveryFeeInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeliveryFeeInfo() when $default != null:
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
    TResult Function(double amount, bool isFree, double freeIn,
            double originalAmount, String? waiverReason)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeliveryFeeInfo() when $default != null:
        return $default(_that.amount, _that.isFree, _that.freeIn,
            _that.originalAmount, _that.waiverReason);
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
    TResult Function(double amount, bool isFree, double freeIn,
            double originalAmount, String? waiverReason)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeliveryFeeInfo():
        return $default(_that.amount, _that.isFree, _that.freeIn,
            _that.originalAmount, _that.waiverReason);
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
    TResult? Function(double amount, bool isFree, double freeIn,
            double originalAmount, String? waiverReason)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeliveryFeeInfo() when $default != null:
        return $default(_that.amount, _that.isFree, _that.freeIn,
            _that.originalAmount, _that.waiverReason);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DeliveryFeeInfo implements DeliveryFeeInfo {
  const _DeliveryFeeInfo(
      {this.amount = 0,
      this.isFree = false,
      this.freeIn = 0,
      this.originalAmount = 0,
      this.waiverReason});
  factory _DeliveryFeeInfo.fromJson(Map<String, dynamic> json) =>
      _$DeliveryFeeInfoFromJson(json);

  @override
  @JsonKey()
  final double amount;
  @override
  @JsonKey()
  final bool isFree;
  @override
  @JsonKey()
  final double freeIn;
  @override
  @JsonKey()
  final double originalAmount;
  @override
  final String? waiverReason;

  /// Create a copy of DeliveryFeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DeliveryFeeInfoCopyWith<_DeliveryFeeInfo> get copyWith =>
      __$DeliveryFeeInfoCopyWithImpl<_DeliveryFeeInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DeliveryFeeInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DeliveryFeeInfo &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.isFree, isFree) || other.isFree == isFree) &&
            (identical(other.freeIn, freeIn) || other.freeIn == freeIn) &&
            (identical(other.originalAmount, originalAmount) ||
                other.originalAmount == originalAmount) &&
            (identical(other.waiverReason, waiverReason) ||
                other.waiverReason == waiverReason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, amount, isFree, freeIn, originalAmount, waiverReason);

  @override
  String toString() {
    return 'DeliveryFeeInfo(amount: $amount, isFree: $isFree, freeIn: $freeIn, originalAmount: $originalAmount, waiverReason: $waiverReason)';
  }
}

/// @nodoc
abstract mixin class _$DeliveryFeeInfoCopyWith<$Res>
    implements $DeliveryFeeInfoCopyWith<$Res> {
  factory _$DeliveryFeeInfoCopyWith(
          _DeliveryFeeInfo value, $Res Function(_DeliveryFeeInfo) _then) =
      __$DeliveryFeeInfoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {double amount,
      bool isFree,
      double freeIn,
      double originalAmount,
      String? waiverReason});
}

/// @nodoc
class __$DeliveryFeeInfoCopyWithImpl<$Res>
    implements _$DeliveryFeeInfoCopyWith<$Res> {
  __$DeliveryFeeInfoCopyWithImpl(this._self, this._then);

  final _DeliveryFeeInfo _self;
  final $Res Function(_DeliveryFeeInfo) _then;

  /// Create a copy of DeliveryFeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? amount = null,
    Object? isFree = null,
    Object? freeIn = null,
    Object? originalAmount = null,
    Object? waiverReason = freezed,
  }) {
    return _then(_DeliveryFeeInfo(
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      isFree: null == isFree
          ? _self.isFree
          : isFree // ignore: cast_nullable_to_non_nullable
              as bool,
      freeIn: null == freeIn
          ? _self.freeIn
          : freeIn // ignore: cast_nullable_to_non_nullable
              as double,
      originalAmount: null == originalAmount
          ? _self.originalAmount
          : originalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      waiverReason: freezed == waiverReason
          ? _self.waiverReason
          : waiverReason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$FeeInfo {
  double get amount;
  bool get isFree;
  double
      get savedAmount; // Admin-configurable (dashboard Settings → Fees) — same label/description
// shown for this fee's admin-set text in the bill's info popup, kept in
// sync with the dashboard rather than hardcoded per fee in the app.
  String? get label;
  String? get description;

  /// Create a copy of FeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FeeInfoCopyWith<FeeInfo> get copyWith =>
      _$FeeInfoCopyWithImpl<FeeInfo>(this as FeeInfo, _$identity);

  /// Serializes this FeeInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FeeInfo &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.isFree, isFree) || other.isFree == isFree) &&
            (identical(other.savedAmount, savedAmount) ||
                other.savedAmount == savedAmount) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, amount, isFree, savedAmount, label, description);

  @override
  String toString() {
    return 'FeeInfo(amount: $amount, isFree: $isFree, savedAmount: $savedAmount, label: $label, description: $description)';
  }
}

/// @nodoc
abstract mixin class $FeeInfoCopyWith<$Res> {
  factory $FeeInfoCopyWith(FeeInfo value, $Res Function(FeeInfo) _then) =
      _$FeeInfoCopyWithImpl;
  @useResult
  $Res call(
      {double amount,
      bool isFree,
      double savedAmount,
      String? label,
      String? description});
}

/// @nodoc
class _$FeeInfoCopyWithImpl<$Res> implements $FeeInfoCopyWith<$Res> {
  _$FeeInfoCopyWithImpl(this._self, this._then);

  final FeeInfo _self;
  final $Res Function(FeeInfo) _then;

  /// Create a copy of FeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? isFree = null,
    Object? savedAmount = null,
    Object? label = freezed,
    Object? description = freezed,
  }) {
    return _then(_self.copyWith(
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      isFree: null == isFree
          ? _self.isFree
          : isFree // ignore: cast_nullable_to_non_nullable
              as bool,
      savedAmount: null == savedAmount
          ? _self.savedAmount
          : savedAmount // ignore: cast_nullable_to_non_nullable
              as double,
      label: freezed == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [FeeInfo].
extension FeeInfoPatterns on FeeInfo {
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
    TResult Function(_FeeInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FeeInfo() when $default != null:
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
    TResult Function(_FeeInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeeInfo():
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
    TResult? Function(_FeeInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeeInfo() when $default != null:
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
    TResult Function(double amount, bool isFree, double savedAmount,
            String? label, String? description)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FeeInfo() when $default != null:
        return $default(_that.amount, _that.isFree, _that.savedAmount,
            _that.label, _that.description);
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
    TResult Function(double amount, bool isFree, double savedAmount,
            String? label, String? description)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeeInfo():
        return $default(_that.amount, _that.isFree, _that.savedAmount,
            _that.label, _that.description);
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
    TResult? Function(double amount, bool isFree, double savedAmount,
            String? label, String? description)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeeInfo() when $default != null:
        return $default(_that.amount, _that.isFree, _that.savedAmount,
            _that.label, _that.description);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FeeInfo implements FeeInfo {
  const _FeeInfo(
      {this.amount = 0,
      this.isFree = false,
      this.savedAmount = 0,
      this.label,
      this.description});
  factory _FeeInfo.fromJson(Map<String, dynamic> json) =>
      _$FeeInfoFromJson(json);

  @override
  @JsonKey()
  final double amount;
  @override
  @JsonKey()
  final bool isFree;
  @override
  @JsonKey()
  final double savedAmount;
// Admin-configurable (dashboard Settings → Fees) — same label/description
// shown for this fee's admin-set text in the bill's info popup, kept in
// sync with the dashboard rather than hardcoded per fee in the app.
  @override
  final String? label;
  @override
  final String? description;

  /// Create a copy of FeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FeeInfoCopyWith<_FeeInfo> get copyWith =>
      __$FeeInfoCopyWithImpl<_FeeInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FeeInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FeeInfo &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.isFree, isFree) || other.isFree == isFree) &&
            (identical(other.savedAmount, savedAmount) ||
                other.savedAmount == savedAmount) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, amount, isFree, savedAmount, label, description);

  @override
  String toString() {
    return 'FeeInfo(amount: $amount, isFree: $isFree, savedAmount: $savedAmount, label: $label, description: $description)';
  }
}

/// @nodoc
abstract mixin class _$FeeInfoCopyWith<$Res> implements $FeeInfoCopyWith<$Res> {
  factory _$FeeInfoCopyWith(_FeeInfo value, $Res Function(_FeeInfo) _then) =
      __$FeeInfoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {double amount,
      bool isFree,
      double savedAmount,
      String? label,
      String? description});
}

/// @nodoc
class __$FeeInfoCopyWithImpl<$Res> implements _$FeeInfoCopyWith<$Res> {
  __$FeeInfoCopyWithImpl(this._self, this._then);

  final _FeeInfo _self;
  final $Res Function(_FeeInfo) _then;

  /// Create a copy of FeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? amount = null,
    Object? isFree = null,
    Object? savedAmount = null,
    Object? label = freezed,
    Object? description = freezed,
  }) {
    return _then(_FeeInfo(
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      isFree: null == isFree
          ? _self.isFree
          : isFree // ignore: cast_nullable_to_non_nullable
              as bool,
      savedAmount: null == savedAmount
          ? _self.savedAmount
          : savedAmount // ignore: cast_nullable_to_non_nullable
              as double,
      label: freezed == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String?,
      description: freezed == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$LateNightFeeInfo {
  double get amount;
  bool get isFree;
  double get savedAmount;
  bool get isLateNight;

  /// Create a copy of LateNightFeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $LateNightFeeInfoCopyWith<LateNightFeeInfo> get copyWith =>
      _$LateNightFeeInfoCopyWithImpl<LateNightFeeInfo>(
          this as LateNightFeeInfo, _$identity);

  /// Serializes this LateNightFeeInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is LateNightFeeInfo &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.isFree, isFree) || other.isFree == isFree) &&
            (identical(other.savedAmount, savedAmount) ||
                other.savedAmount == savedAmount) &&
            (identical(other.isLateNight, isLateNight) ||
                other.isLateNight == isLateNight));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, amount, isFree, savedAmount, isLateNight);

  @override
  String toString() {
    return 'LateNightFeeInfo(amount: $amount, isFree: $isFree, savedAmount: $savedAmount, isLateNight: $isLateNight)';
  }
}

/// @nodoc
abstract mixin class $LateNightFeeInfoCopyWith<$Res> {
  factory $LateNightFeeInfoCopyWith(
          LateNightFeeInfo value, $Res Function(LateNightFeeInfo) _then) =
      _$LateNightFeeInfoCopyWithImpl;
  @useResult
  $Res call({double amount, bool isFree, double savedAmount, bool isLateNight});
}

/// @nodoc
class _$LateNightFeeInfoCopyWithImpl<$Res>
    implements $LateNightFeeInfoCopyWith<$Res> {
  _$LateNightFeeInfoCopyWithImpl(this._self, this._then);

  final LateNightFeeInfo _self;
  final $Res Function(LateNightFeeInfo) _then;

  /// Create a copy of LateNightFeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? amount = null,
    Object? isFree = null,
    Object? savedAmount = null,
    Object? isLateNight = null,
  }) {
    return _then(_self.copyWith(
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      isFree: null == isFree
          ? _self.isFree
          : isFree // ignore: cast_nullable_to_non_nullable
              as bool,
      savedAmount: null == savedAmount
          ? _self.savedAmount
          : savedAmount // ignore: cast_nullable_to_non_nullable
              as double,
      isLateNight: null == isLateNight
          ? _self.isLateNight
          : isLateNight // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [LateNightFeeInfo].
extension LateNightFeeInfoPatterns on LateNightFeeInfo {
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
    TResult Function(_LateNightFeeInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LateNightFeeInfo() when $default != null:
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
    TResult Function(_LateNightFeeInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LateNightFeeInfo():
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
    TResult? Function(_LateNightFeeInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LateNightFeeInfo() when $default != null:
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
            double amount, bool isFree, double savedAmount, bool isLateNight)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _LateNightFeeInfo() when $default != null:
        return $default(
            _that.amount, _that.isFree, _that.savedAmount, _that.isLateNight);
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
            double amount, bool isFree, double savedAmount, bool isLateNight)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LateNightFeeInfo():
        return $default(
            _that.amount, _that.isFree, _that.savedAmount, _that.isLateNight);
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
            double amount, bool isFree, double savedAmount, bool isLateNight)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _LateNightFeeInfo() when $default != null:
        return $default(
            _that.amount, _that.isFree, _that.savedAmount, _that.isLateNight);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _LateNightFeeInfo implements LateNightFeeInfo {
  const _LateNightFeeInfo(
      {this.amount = 0,
      this.isFree = false,
      this.savedAmount = 0,
      this.isLateNight = false});
  factory _LateNightFeeInfo.fromJson(Map<String, dynamic> json) =>
      _$LateNightFeeInfoFromJson(json);

  @override
  @JsonKey()
  final double amount;
  @override
  @JsonKey()
  final bool isFree;
  @override
  @JsonKey()
  final double savedAmount;
  @override
  @JsonKey()
  final bool isLateNight;

  /// Create a copy of LateNightFeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LateNightFeeInfoCopyWith<_LateNightFeeInfo> get copyWith =>
      __$LateNightFeeInfoCopyWithImpl<_LateNightFeeInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$LateNightFeeInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _LateNightFeeInfo &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.isFree, isFree) || other.isFree == isFree) &&
            (identical(other.savedAmount, savedAmount) ||
                other.savedAmount == savedAmount) &&
            (identical(other.isLateNight, isLateNight) ||
                other.isLateNight == isLateNight));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, amount, isFree, savedAmount, isLateNight);

  @override
  String toString() {
    return 'LateNightFeeInfo(amount: $amount, isFree: $isFree, savedAmount: $savedAmount, isLateNight: $isLateNight)';
  }
}

/// @nodoc
abstract mixin class _$LateNightFeeInfoCopyWith<$Res>
    implements $LateNightFeeInfoCopyWith<$Res> {
  factory _$LateNightFeeInfoCopyWith(
          _LateNightFeeInfo value, $Res Function(_LateNightFeeInfo) _then) =
      __$LateNightFeeInfoCopyWithImpl;
  @override
  @useResult
  $Res call({double amount, bool isFree, double savedAmount, bool isLateNight});
}

/// @nodoc
class __$LateNightFeeInfoCopyWithImpl<$Res>
    implements _$LateNightFeeInfoCopyWith<$Res> {
  __$LateNightFeeInfoCopyWithImpl(this._self, this._then);

  final _LateNightFeeInfo _self;
  final $Res Function(_LateNightFeeInfo) _then;

  /// Create a copy of LateNightFeeInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? amount = null,
    Object? isFree = null,
    Object? savedAmount = null,
    Object? isLateNight = null,
  }) {
    return _then(_LateNightFeeInfo(
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      isFree: null == isFree
          ? _self.isFree
          : isFree // ignore: cast_nullable_to_non_nullable
              as bool,
      savedAmount: null == savedAmount
          ? _self.savedAmount
          : savedAmount // ignore: cast_nullable_to_non_nullable
              as double,
      isLateNight: null == isLateNight
          ? _self.isLateNight
          : isLateNight // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$BillToPay {
  double get original;
  @JsonKey(name: 'final')
  double get finalAmount;

  /// Create a copy of BillToPay
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $BillToPayCopyWith<BillToPay> get copyWith =>
      _$BillToPayCopyWithImpl<BillToPay>(this as BillToPay, _$identity);

  /// Serializes this BillToPay to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is BillToPay &&
            (identical(other.original, original) ||
                other.original == original) &&
            (identical(other.finalAmount, finalAmount) ||
                other.finalAmount == finalAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, original, finalAmount);

  @override
  String toString() {
    return 'BillToPay(original: $original, finalAmount: $finalAmount)';
  }
}

/// @nodoc
abstract mixin class $BillToPayCopyWith<$Res> {
  factory $BillToPayCopyWith(BillToPay value, $Res Function(BillToPay) _then) =
      _$BillToPayCopyWithImpl;
  @useResult
  $Res call({double original, @JsonKey(name: 'final') double finalAmount});
}

/// @nodoc
class _$BillToPayCopyWithImpl<$Res> implements $BillToPayCopyWith<$Res> {
  _$BillToPayCopyWithImpl(this._self, this._then);

  final BillToPay _self;
  final $Res Function(BillToPay) _then;

  /// Create a copy of BillToPay
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? original = null,
    Object? finalAmount = null,
  }) {
    return _then(_self.copyWith(
      original: null == original
          ? _self.original
          : original // ignore: cast_nullable_to_non_nullable
              as double,
      finalAmount: null == finalAmount
          ? _self.finalAmount
          : finalAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [BillToPay].
extension BillToPayPatterns on BillToPay {
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
    TResult Function(_BillToPay value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BillToPay() when $default != null:
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
    TResult Function(_BillToPay value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillToPay():
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
    TResult? Function(_BillToPay value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillToPay() when $default != null:
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
            double original, @JsonKey(name: 'final') double finalAmount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _BillToPay() when $default != null:
        return $default(_that.original, _that.finalAmount);
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
            double original, @JsonKey(name: 'final') double finalAmount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillToPay():
        return $default(_that.original, _that.finalAmount);
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
            double original, @JsonKey(name: 'final') double finalAmount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _BillToPay() when $default != null:
        return $default(_that.original, _that.finalAmount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _BillToPay implements BillToPay {
  const _BillToPay(
      {this.original = 0, @JsonKey(name: 'final') this.finalAmount = 0});
  factory _BillToPay.fromJson(Map<String, dynamic> json) =>
      _$BillToPayFromJson(json);

  @override
  @JsonKey()
  final double original;
  @override
  @JsonKey(name: 'final')
  final double finalAmount;

  /// Create a copy of BillToPay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$BillToPayCopyWith<_BillToPay> get copyWith =>
      __$BillToPayCopyWithImpl<_BillToPay>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$BillToPayToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _BillToPay &&
            (identical(other.original, original) ||
                other.original == original) &&
            (identical(other.finalAmount, finalAmount) ||
                other.finalAmount == finalAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, original, finalAmount);

  @override
  String toString() {
    return 'BillToPay(original: $original, finalAmount: $finalAmount)';
  }
}

/// @nodoc
abstract mixin class _$BillToPayCopyWith<$Res>
    implements $BillToPayCopyWith<$Res> {
  factory _$BillToPayCopyWith(
          _BillToPay value, $Res Function(_BillToPay) _then) =
      __$BillToPayCopyWithImpl;
  @override
  @useResult
  $Res call({double original, @JsonKey(name: 'final') double finalAmount});
}

/// @nodoc
class __$BillToPayCopyWithImpl<$Res> implements _$BillToPayCopyWith<$Res> {
  __$BillToPayCopyWithImpl(this._self, this._then);

  final _BillToPay _self;
  final $Res Function(_BillToPay) _then;

  /// Create a copy of BillToPay
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? original = null,
    Object? finalAmount = null,
  }) {
    return _then(_BillToPay(
      original: null == original
          ? _self.original
          : original // ignore: cast_nullable_to_non_nullable
              as double,
      finalAmount: null == finalAmount
          ? _self.finalAmount
          : finalAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$DeliveryEstimate {
  int get minutes;
  String get label;

  /// Create a copy of DeliveryEstimate
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DeliveryEstimateCopyWith<DeliveryEstimate> get copyWith =>
      _$DeliveryEstimateCopyWithImpl<DeliveryEstimate>(
          this as DeliveryEstimate, _$identity);

  /// Serializes this DeliveryEstimate to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DeliveryEstimate &&
            (identical(other.minutes, minutes) || other.minutes == minutes) &&
            (identical(other.label, label) || other.label == label));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, minutes, label);

  @override
  String toString() {
    return 'DeliveryEstimate(minutes: $minutes, label: $label)';
  }
}

/// @nodoc
abstract mixin class $DeliveryEstimateCopyWith<$Res> {
  factory $DeliveryEstimateCopyWith(
          DeliveryEstimate value, $Res Function(DeliveryEstimate) _then) =
      _$DeliveryEstimateCopyWithImpl;
  @useResult
  $Res call({int minutes, String label});
}

/// @nodoc
class _$DeliveryEstimateCopyWithImpl<$Res>
    implements $DeliveryEstimateCopyWith<$Res> {
  _$DeliveryEstimateCopyWithImpl(this._self, this._then);

  final DeliveryEstimate _self;
  final $Res Function(DeliveryEstimate) _then;

  /// Create a copy of DeliveryEstimate
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? minutes = null,
    Object? label = null,
  }) {
    return _then(_self.copyWith(
      minutes: null == minutes
          ? _self.minutes
          : minutes // ignore: cast_nullable_to_non_nullable
              as int,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [DeliveryEstimate].
extension DeliveryEstimatePatterns on DeliveryEstimate {
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
    TResult Function(_DeliveryEstimate value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeliveryEstimate() when $default != null:
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
    TResult Function(_DeliveryEstimate value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeliveryEstimate():
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
    TResult? Function(_DeliveryEstimate value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeliveryEstimate() when $default != null:
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
    TResult Function(int minutes, String label)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DeliveryEstimate() when $default != null:
        return $default(_that.minutes, _that.label);
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
    TResult Function(int minutes, String label) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeliveryEstimate():
        return $default(_that.minutes, _that.label);
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
    TResult? Function(int minutes, String label)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DeliveryEstimate() when $default != null:
        return $default(_that.minutes, _that.label);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DeliveryEstimate implements DeliveryEstimate {
  const _DeliveryEstimate(
      {this.minutes = 30, this.label = 'Delivering in 30 mins'});
  factory _DeliveryEstimate.fromJson(Map<String, dynamic> json) =>
      _$DeliveryEstimateFromJson(json);

  @override
  @JsonKey()
  final int minutes;
  @override
  @JsonKey()
  final String label;

  /// Create a copy of DeliveryEstimate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DeliveryEstimateCopyWith<_DeliveryEstimate> get copyWith =>
      __$DeliveryEstimateCopyWithImpl<_DeliveryEstimate>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DeliveryEstimateToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DeliveryEstimate &&
            (identical(other.minutes, minutes) || other.minutes == minutes) &&
            (identical(other.label, label) || other.label == label));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, minutes, label);

  @override
  String toString() {
    return 'DeliveryEstimate(minutes: $minutes, label: $label)';
  }
}

/// @nodoc
abstract mixin class _$DeliveryEstimateCopyWith<$Res>
    implements $DeliveryEstimateCopyWith<$Res> {
  factory _$DeliveryEstimateCopyWith(
          _DeliveryEstimate value, $Res Function(_DeliveryEstimate) _then) =
      __$DeliveryEstimateCopyWithImpl;
  @override
  @useResult
  $Res call({int minutes, String label});
}

/// @nodoc
class __$DeliveryEstimateCopyWithImpl<$Res>
    implements _$DeliveryEstimateCopyWith<$Res> {
  __$DeliveryEstimateCopyWithImpl(this._self, this._then);

  final _DeliveryEstimate _self;
  final $Res Function(_DeliveryEstimate) _then;

  /// Create a copy of DeliveryEstimate
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? minutes = null,
    Object? label = null,
  }) {
    return _then(_DeliveryEstimate(
      minutes: null == minutes
          ? _self.minutes
          : minutes // ignore: cast_nullable_to_non_nullable
              as int,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$DistanceInfo {
  double? get km;
  String get label;
  bool get known;

  /// Create a copy of DistanceInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $DistanceInfoCopyWith<DistanceInfo> get copyWith =>
      _$DistanceInfoCopyWithImpl<DistanceInfo>(
          this as DistanceInfo, _$identity);

  /// Serializes this DistanceInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is DistanceInfo &&
            (identical(other.km, km) || other.km == km) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.known, known) || other.known == known));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, km, label, known);

  @override
  String toString() {
    return 'DistanceInfo(km: $km, label: $label, known: $known)';
  }
}

/// @nodoc
abstract mixin class $DistanceInfoCopyWith<$Res> {
  factory $DistanceInfoCopyWith(
          DistanceInfo value, $Res Function(DistanceInfo) _then) =
      _$DistanceInfoCopyWithImpl;
  @useResult
  $Res call({double? km, String label, bool known});
}

/// @nodoc
class _$DistanceInfoCopyWithImpl<$Res> implements $DistanceInfoCopyWith<$Res> {
  _$DistanceInfoCopyWithImpl(this._self, this._then);

  final DistanceInfo _self;
  final $Res Function(DistanceInfo) _then;

  /// Create a copy of DistanceInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? km = freezed,
    Object? label = null,
    Object? known = null,
  }) {
    return _then(_self.copyWith(
      km: freezed == km
          ? _self.km
          : km // ignore: cast_nullable_to_non_nullable
              as double?,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      known: null == known
          ? _self.known
          : known // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [DistanceInfo].
extension DistanceInfoPatterns on DistanceInfo {
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
    TResult Function(_DistanceInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DistanceInfo() when $default != null:
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
    TResult Function(_DistanceInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DistanceInfo():
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
    TResult? Function(_DistanceInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DistanceInfo() when $default != null:
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
    TResult Function(double? km, String label, bool known)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _DistanceInfo() when $default != null:
        return $default(_that.km, _that.label, _that.known);
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
    TResult Function(double? km, String label, bool known) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DistanceInfo():
        return $default(_that.km, _that.label, _that.known);
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
    TResult? Function(double? km, String label, bool known)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _DistanceInfo() when $default != null:
        return $default(_that.km, _that.label, _that.known);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _DistanceInfo implements DistanceInfo {
  const _DistanceInfo({this.km, this.label = '', this.known = false});
  factory _DistanceInfo.fromJson(Map<String, dynamic> json) =>
      _$DistanceInfoFromJson(json);

  @override
  final double? km;
  @override
  @JsonKey()
  final String label;
  @override
  @JsonKey()
  final bool known;

  /// Create a copy of DistanceInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$DistanceInfoCopyWith<_DistanceInfo> get copyWith =>
      __$DistanceInfoCopyWithImpl<_DistanceInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$DistanceInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _DistanceInfo &&
            (identical(other.km, km) || other.km == km) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.known, known) || other.known == known));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, km, label, known);

  @override
  String toString() {
    return 'DistanceInfo(km: $km, label: $label, known: $known)';
  }
}

/// @nodoc
abstract mixin class _$DistanceInfoCopyWith<$Res>
    implements $DistanceInfoCopyWith<$Res> {
  factory _$DistanceInfoCopyWith(
          _DistanceInfo value, $Res Function(_DistanceInfo) _then) =
      __$DistanceInfoCopyWithImpl;
  @override
  @useResult
  $Res call({double? km, String label, bool known});
}

/// @nodoc
class __$DistanceInfoCopyWithImpl<$Res>
    implements _$DistanceInfoCopyWith<$Res> {
  __$DistanceInfoCopyWithImpl(this._self, this._then);

  final _DistanceInfo _self;
  final $Res Function(_DistanceInfo) _then;

  /// Create a copy of DistanceInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? km = freezed,
    Object? label = null,
    Object? known = null,
  }) {
    return _then(_DistanceInfo(
      km: freezed == km
          ? _self.km
          : km // ignore: cast_nullable_to_non_nullable
              as double?,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      known: null == known
          ? _self.known
          : known // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$FreeDeliveryInfo {
  bool get enabled;
  double? get threshold;
  bool get unlocked;
  double get amountToUnlock;

  /// Create a copy of FreeDeliveryInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FreeDeliveryInfoCopyWith<FreeDeliveryInfo> get copyWith =>
      _$FreeDeliveryInfoCopyWithImpl<FreeDeliveryInfo>(
          this as FreeDeliveryInfo, _$identity);

  /// Serializes this FreeDeliveryInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FreeDeliveryInfo &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold) &&
            (identical(other.unlocked, unlocked) ||
                other.unlocked == unlocked) &&
            (identical(other.amountToUnlock, amountToUnlock) ||
                other.amountToUnlock == amountToUnlock));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, enabled, threshold, unlocked, amountToUnlock);

  @override
  String toString() {
    return 'FreeDeliveryInfo(enabled: $enabled, threshold: $threshold, unlocked: $unlocked, amountToUnlock: $amountToUnlock)';
  }
}

/// @nodoc
abstract mixin class $FreeDeliveryInfoCopyWith<$Res> {
  factory $FreeDeliveryInfoCopyWith(
          FreeDeliveryInfo value, $Res Function(FreeDeliveryInfo) _then) =
      _$FreeDeliveryInfoCopyWithImpl;
  @useResult
  $Res call(
      {bool enabled, double? threshold, bool unlocked, double amountToUnlock});
}

/// @nodoc
class _$FreeDeliveryInfoCopyWithImpl<$Res>
    implements $FreeDeliveryInfoCopyWith<$Res> {
  _$FreeDeliveryInfoCopyWithImpl(this._self, this._then);

  final FreeDeliveryInfo _self;
  final $Res Function(FreeDeliveryInfo) _then;

  /// Create a copy of FreeDeliveryInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? threshold = freezed,
    Object? unlocked = null,
    Object? amountToUnlock = null,
  }) {
    return _then(_self.copyWith(
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      threshold: freezed == threshold
          ? _self.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double?,
      unlocked: null == unlocked
          ? _self.unlocked
          : unlocked // ignore: cast_nullable_to_non_nullable
              as bool,
      amountToUnlock: null == amountToUnlock
          ? _self.amountToUnlock
          : amountToUnlock // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [FreeDeliveryInfo].
extension FreeDeliveryInfoPatterns on FreeDeliveryInfo {
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
    TResult Function(_FreeDeliveryInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FreeDeliveryInfo() when $default != null:
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
    TResult Function(_FreeDeliveryInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FreeDeliveryInfo():
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
    TResult? Function(_FreeDeliveryInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FreeDeliveryInfo() when $default != null:
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
    TResult Function(bool enabled, double? threshold, bool unlocked,
            double amountToUnlock)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FreeDeliveryInfo() when $default != null:
        return $default(_that.enabled, _that.threshold, _that.unlocked,
            _that.amountToUnlock);
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
    TResult Function(bool enabled, double? threshold, bool unlocked,
            double amountToUnlock)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FreeDeliveryInfo():
        return $default(_that.enabled, _that.threshold, _that.unlocked,
            _that.amountToUnlock);
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
    TResult? Function(bool enabled, double? threshold, bool unlocked,
            double amountToUnlock)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FreeDeliveryInfo() when $default != null:
        return $default(_that.enabled, _that.threshold, _that.unlocked,
            _that.amountToUnlock);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FreeDeliveryInfo implements FreeDeliveryInfo {
  const _FreeDeliveryInfo(
      {this.enabled = false,
      this.threshold,
      this.unlocked = false,
      this.amountToUnlock = 0});
  factory _FreeDeliveryInfo.fromJson(Map<String, dynamic> json) =>
      _$FreeDeliveryInfoFromJson(json);

  @override
  @JsonKey()
  final bool enabled;
  @override
  final double? threshold;
  @override
  @JsonKey()
  final bool unlocked;
  @override
  @JsonKey()
  final double amountToUnlock;

  /// Create a copy of FreeDeliveryInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FreeDeliveryInfoCopyWith<_FreeDeliveryInfo> get copyWith =>
      __$FreeDeliveryInfoCopyWithImpl<_FreeDeliveryInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FreeDeliveryInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FreeDeliveryInfo &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.threshold, threshold) ||
                other.threshold == threshold) &&
            (identical(other.unlocked, unlocked) ||
                other.unlocked == unlocked) &&
            (identical(other.amountToUnlock, amountToUnlock) ||
                other.amountToUnlock == amountToUnlock));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, enabled, threshold, unlocked, amountToUnlock);

  @override
  String toString() {
    return 'FreeDeliveryInfo(enabled: $enabled, threshold: $threshold, unlocked: $unlocked, amountToUnlock: $amountToUnlock)';
  }
}

/// @nodoc
abstract mixin class _$FreeDeliveryInfoCopyWith<$Res>
    implements $FreeDeliveryInfoCopyWith<$Res> {
  factory _$FreeDeliveryInfoCopyWith(
          _FreeDeliveryInfo value, $Res Function(_FreeDeliveryInfo) _then) =
      __$FreeDeliveryInfoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool enabled, double? threshold, bool unlocked, double amountToUnlock});
}

/// @nodoc
class __$FreeDeliveryInfoCopyWithImpl<$Res>
    implements _$FreeDeliveryInfoCopyWith<$Res> {
  __$FreeDeliveryInfoCopyWithImpl(this._self, this._then);

  final _FreeDeliveryInfo _self;
  final $Res Function(_FreeDeliveryInfo) _then;

  /// Create a copy of FreeDeliveryInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? enabled = null,
    Object? threshold = freezed,
    Object? unlocked = null,
    Object? amountToUnlock = null,
  }) {
    return _then(_FreeDeliveryInfo(
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      threshold: freezed == threshold
          ? _self.threshold
          : threshold // ignore: cast_nullable_to_non_nullable
              as double?,
      unlocked: null == unlocked
          ? _self.unlocked
          : unlocked // ignore: cast_nullable_to_non_nullable
              as bool,
      amountToUnlock: null == amountToUnlock
          ? _self.amountToUnlock
          : amountToUnlock // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$CartMilestoneTier {
  String get id;
  String get name;
  String get rewardType;
  double get minCartAmount;
  double get amountToUnlock;
  String get message;
  String?
      get iconUrl; // Only ever populated on the `unlocked` tier of a CASHBACK-type
// milestone — the wallet credit the customer will actually earn on
// this order, computed server-side (CartMilestonesService.computeReward).
  double get cashbackAmount;

  /// Create a copy of CartMilestoneTier
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CartMilestoneTierCopyWith<CartMilestoneTier> get copyWith =>
      _$CartMilestoneTierCopyWithImpl<CartMilestoneTier>(
          this as CartMilestoneTier, _$identity);

  /// Serializes this CartMilestoneTier to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CartMilestoneTier &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rewardType, rewardType) ||
                other.rewardType == rewardType) &&
            (identical(other.minCartAmount, minCartAmount) ||
                other.minCartAmount == minCartAmount) &&
            (identical(other.amountToUnlock, amountToUnlock) ||
                other.amountToUnlock == amountToUnlock) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl) &&
            (identical(other.cashbackAmount, cashbackAmount) ||
                other.cashbackAmount == cashbackAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, rewardType,
      minCartAmount, amountToUnlock, message, iconUrl, cashbackAmount);

  @override
  String toString() {
    return 'CartMilestoneTier(id: $id, name: $name, rewardType: $rewardType, minCartAmount: $minCartAmount, amountToUnlock: $amountToUnlock, message: $message, iconUrl: $iconUrl, cashbackAmount: $cashbackAmount)';
  }
}

/// @nodoc
abstract mixin class $CartMilestoneTierCopyWith<$Res> {
  factory $CartMilestoneTierCopyWith(
          CartMilestoneTier value, $Res Function(CartMilestoneTier) _then) =
      _$CartMilestoneTierCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String rewardType,
      double minCartAmount,
      double amountToUnlock,
      String message,
      String? iconUrl,
      double cashbackAmount});
}

/// @nodoc
class _$CartMilestoneTierCopyWithImpl<$Res>
    implements $CartMilestoneTierCopyWith<$Res> {
  _$CartMilestoneTierCopyWithImpl(this._self, this._then);

  final CartMilestoneTier _self;
  final $Res Function(CartMilestoneTier) _then;

  /// Create a copy of CartMilestoneTier
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? rewardType = null,
    Object? minCartAmount = null,
    Object? amountToUnlock = null,
    Object? message = null,
    Object? iconUrl = freezed,
    Object? cashbackAmount = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rewardType: null == rewardType
          ? _self.rewardType
          : rewardType // ignore: cast_nullable_to_non_nullable
              as String,
      minCartAmount: null == minCartAmount
          ? _self.minCartAmount
          : minCartAmount // ignore: cast_nullable_to_non_nullable
              as double,
      amountToUnlock: null == amountToUnlock
          ? _self.amountToUnlock
          : amountToUnlock // ignore: cast_nullable_to_non_nullable
              as double,
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      iconUrl: freezed == iconUrl
          ? _self.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      cashbackAmount: null == cashbackAmount
          ? _self.cashbackAmount
          : cashbackAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [CartMilestoneTier].
extension CartMilestoneTierPatterns on CartMilestoneTier {
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
    TResult Function(_CartMilestoneTier value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneTier() when $default != null:
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
    TResult Function(_CartMilestoneTier value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneTier():
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
    TResult? Function(_CartMilestoneTier value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneTier() when $default != null:
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
            String name,
            String rewardType,
            double minCartAmount,
            double amountToUnlock,
            String message,
            String? iconUrl,
            double cashbackAmount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneTier() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.rewardType,
            _that.minCartAmount,
            _that.amountToUnlock,
            _that.message,
            _that.iconUrl,
            _that.cashbackAmount);
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
            String name,
            String rewardType,
            double minCartAmount,
            double amountToUnlock,
            String message,
            String? iconUrl,
            double cashbackAmount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneTier():
        return $default(
            _that.id,
            _that.name,
            _that.rewardType,
            _that.minCartAmount,
            _that.amountToUnlock,
            _that.message,
            _that.iconUrl,
            _that.cashbackAmount);
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
            String name,
            String rewardType,
            double minCartAmount,
            double amountToUnlock,
            String message,
            String? iconUrl,
            double cashbackAmount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneTier() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.rewardType,
            _that.minCartAmount,
            _that.amountToUnlock,
            _that.message,
            _that.iconUrl,
            _that.cashbackAmount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CartMilestoneTier implements CartMilestoneTier {
  const _CartMilestoneTier(
      {this.id = '',
      this.name = '',
      this.rewardType = '',
      this.minCartAmount = 0,
      this.amountToUnlock = 0,
      this.message = '',
      this.iconUrl,
      this.cashbackAmount = 0});
  factory _CartMilestoneTier.fromJson(Map<String, dynamic> json) =>
      _$CartMilestoneTierFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String rewardType;
  @override
  @JsonKey()
  final double minCartAmount;
  @override
  @JsonKey()
  final double amountToUnlock;
  @override
  @JsonKey()
  final String message;
  @override
  final String? iconUrl;
// Only ever populated on the `unlocked` tier of a CASHBACK-type
// milestone — the wallet credit the customer will actually earn on
// this order, computed server-side (CartMilestonesService.computeReward).
  @override
  @JsonKey()
  final double cashbackAmount;

  /// Create a copy of CartMilestoneTier
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CartMilestoneTierCopyWith<_CartMilestoneTier> get copyWith =>
      __$CartMilestoneTierCopyWithImpl<_CartMilestoneTier>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CartMilestoneTierToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CartMilestoneTier &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rewardType, rewardType) ||
                other.rewardType == rewardType) &&
            (identical(other.minCartAmount, minCartAmount) ||
                other.minCartAmount == minCartAmount) &&
            (identical(other.amountToUnlock, amountToUnlock) ||
                other.amountToUnlock == amountToUnlock) &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.iconUrl, iconUrl) || other.iconUrl == iconUrl) &&
            (identical(other.cashbackAmount, cashbackAmount) ||
                other.cashbackAmount == cashbackAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, rewardType,
      minCartAmount, amountToUnlock, message, iconUrl, cashbackAmount);

  @override
  String toString() {
    return 'CartMilestoneTier(id: $id, name: $name, rewardType: $rewardType, minCartAmount: $minCartAmount, amountToUnlock: $amountToUnlock, message: $message, iconUrl: $iconUrl, cashbackAmount: $cashbackAmount)';
  }
}

/// @nodoc
abstract mixin class _$CartMilestoneTierCopyWith<$Res>
    implements $CartMilestoneTierCopyWith<$Res> {
  factory _$CartMilestoneTierCopyWith(
          _CartMilestoneTier value, $Res Function(_CartMilestoneTier) _then) =
      __$CartMilestoneTierCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String rewardType,
      double minCartAmount,
      double amountToUnlock,
      String message,
      String? iconUrl,
      double cashbackAmount});
}

/// @nodoc
class __$CartMilestoneTierCopyWithImpl<$Res>
    implements _$CartMilestoneTierCopyWith<$Res> {
  __$CartMilestoneTierCopyWithImpl(this._self, this._then);

  final _CartMilestoneTier _self;
  final $Res Function(_CartMilestoneTier) _then;

  /// Create a copy of CartMilestoneTier
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? rewardType = null,
    Object? minCartAmount = null,
    Object? amountToUnlock = null,
    Object? message = null,
    Object? iconUrl = freezed,
    Object? cashbackAmount = null,
  }) {
    return _then(_CartMilestoneTier(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rewardType: null == rewardType
          ? _self.rewardType
          : rewardType // ignore: cast_nullable_to_non_nullable
              as String,
      minCartAmount: null == minCartAmount
          ? _self.minCartAmount
          : minCartAmount // ignore: cast_nullable_to_non_nullable
              as double,
      amountToUnlock: null == amountToUnlock
          ? _self.amountToUnlock
          : amountToUnlock // ignore: cast_nullable_to_non_nullable
              as double,
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      iconUrl: freezed == iconUrl
          ? _self.iconUrl
          : iconUrl // ignore: cast_nullable_to_non_nullable
              as String?,
      cashbackAmount: null == cashbackAmount
          ? _self.cashbackAmount
          : cashbackAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$CartMilestoneLadderStep {
  String get id;
  String get label;
  double get minAmount;
  bool get achieved;
  double get segmentProgress;

  /// Create a copy of CartMilestoneLadderStep
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CartMilestoneLadderStepCopyWith<CartMilestoneLadderStep> get copyWith =>
      _$CartMilestoneLadderStepCopyWithImpl<CartMilestoneLadderStep>(
          this as CartMilestoneLadderStep, _$identity);

  /// Serializes this CartMilestoneLadderStep to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CartMilestoneLadderStep &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.minAmount, minAmount) ||
                other.minAmount == minAmount) &&
            (identical(other.achieved, achieved) ||
                other.achieved == achieved) &&
            (identical(other.segmentProgress, segmentProgress) ||
                other.segmentProgress == segmentProgress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, label, minAmount, achieved, segmentProgress);

  @override
  String toString() {
    return 'CartMilestoneLadderStep(id: $id, label: $label, minAmount: $minAmount, achieved: $achieved, segmentProgress: $segmentProgress)';
  }
}

/// @nodoc
abstract mixin class $CartMilestoneLadderStepCopyWith<$Res> {
  factory $CartMilestoneLadderStepCopyWith(CartMilestoneLadderStep value,
          $Res Function(CartMilestoneLadderStep) _then) =
      _$CartMilestoneLadderStepCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String label,
      double minAmount,
      bool achieved,
      double segmentProgress});
}

/// @nodoc
class _$CartMilestoneLadderStepCopyWithImpl<$Res>
    implements $CartMilestoneLadderStepCopyWith<$Res> {
  _$CartMilestoneLadderStepCopyWithImpl(this._self, this._then);

  final CartMilestoneLadderStep _self;
  final $Res Function(CartMilestoneLadderStep) _then;

  /// Create a copy of CartMilestoneLadderStep
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? minAmount = null,
    Object? achieved = null,
    Object? segmentProgress = null,
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
      minAmount: null == minAmount
          ? _self.minAmount
          : minAmount // ignore: cast_nullable_to_non_nullable
              as double,
      achieved: null == achieved
          ? _self.achieved
          : achieved // ignore: cast_nullable_to_non_nullable
              as bool,
      segmentProgress: null == segmentProgress
          ? _self.segmentProgress
          : segmentProgress // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [CartMilestoneLadderStep].
extension CartMilestoneLadderStepPatterns on CartMilestoneLadderStep {
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
    TResult Function(_CartMilestoneLadderStep value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneLadderStep() when $default != null:
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
    TResult Function(_CartMilestoneLadderStep value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneLadderStep():
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
    TResult? Function(_CartMilestoneLadderStep value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneLadderStep() when $default != null:
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
    TResult Function(String id, String label, double minAmount, bool achieved,
            double segmentProgress)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneLadderStep() when $default != null:
        return $default(_that.id, _that.label, _that.minAmount, _that.achieved,
            _that.segmentProgress);
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
    TResult Function(String id, String label, double minAmount, bool achieved,
            double segmentProgress)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneLadderStep():
        return $default(_that.id, _that.label, _that.minAmount, _that.achieved,
            _that.segmentProgress);
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
    TResult? Function(String id, String label, double minAmount, bool achieved,
            double segmentProgress)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneLadderStep() when $default != null:
        return $default(_that.id, _that.label, _that.minAmount, _that.achieved,
            _that.segmentProgress);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CartMilestoneLadderStep implements CartMilestoneLadderStep {
  const _CartMilestoneLadderStep(
      {this.id = '',
      this.label = '',
      this.minAmount = 0,
      this.achieved = false,
      this.segmentProgress = 0});
  factory _CartMilestoneLadderStep.fromJson(Map<String, dynamic> json) =>
      _$CartMilestoneLadderStepFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String label;
  @override
  @JsonKey()
  final double minAmount;
  @override
  @JsonKey()
  final bool achieved;
  @override
  @JsonKey()
  final double segmentProgress;

  /// Create a copy of CartMilestoneLadderStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CartMilestoneLadderStepCopyWith<_CartMilestoneLadderStep> get copyWith =>
      __$CartMilestoneLadderStepCopyWithImpl<_CartMilestoneLadderStep>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CartMilestoneLadderStepToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CartMilestoneLadderStep &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.minAmount, minAmount) ||
                other.minAmount == minAmount) &&
            (identical(other.achieved, achieved) ||
                other.achieved == achieved) &&
            (identical(other.segmentProgress, segmentProgress) ||
                other.segmentProgress == segmentProgress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, label, minAmount, achieved, segmentProgress);

  @override
  String toString() {
    return 'CartMilestoneLadderStep(id: $id, label: $label, minAmount: $minAmount, achieved: $achieved, segmentProgress: $segmentProgress)';
  }
}

/// @nodoc
abstract mixin class _$CartMilestoneLadderStepCopyWith<$Res>
    implements $CartMilestoneLadderStepCopyWith<$Res> {
  factory _$CartMilestoneLadderStepCopyWith(_CartMilestoneLadderStep value,
          $Res Function(_CartMilestoneLadderStep) _then) =
      __$CartMilestoneLadderStepCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String label,
      double minAmount,
      bool achieved,
      double segmentProgress});
}

/// @nodoc
class __$CartMilestoneLadderStepCopyWithImpl<$Res>
    implements _$CartMilestoneLadderStepCopyWith<$Res> {
  __$CartMilestoneLadderStepCopyWithImpl(this._self, this._then);

  final _CartMilestoneLadderStep _self;
  final $Res Function(_CartMilestoneLadderStep) _then;

  /// Create a copy of CartMilestoneLadderStep
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? label = null,
    Object? minAmount = null,
    Object? achieved = null,
    Object? segmentProgress = null,
  }) {
    return _then(_CartMilestoneLadderStep(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      minAmount: null == minAmount
          ? _self.minAmount
          : minAmount // ignore: cast_nullable_to_non_nullable
              as double,
      achieved: null == achieved
          ? _self.achieved
          : achieved // ignore: cast_nullable_to_non_nullable
              as bool,
      segmentProgress: null == segmentProgress
          ? _self.segmentProgress
          : segmentProgress // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$CartMilestoneProgress {
  CartMilestoneTier? get unlocked;
  CartMilestoneTier? get next;
  List<CartMilestoneLadderStep> get ladder;

  /// Create a copy of CartMilestoneProgress
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CartMilestoneProgressCopyWith<CartMilestoneProgress> get copyWith =>
      _$CartMilestoneProgressCopyWithImpl<CartMilestoneProgress>(
          this as CartMilestoneProgress, _$identity);

  /// Serializes this CartMilestoneProgress to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CartMilestoneProgress &&
            (identical(other.unlocked, unlocked) ||
                other.unlocked == unlocked) &&
            (identical(other.next, next) || other.next == next) &&
            const DeepCollectionEquality().equals(other.ladder, ladder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, unlocked, next, const DeepCollectionEquality().hash(ladder));

  @override
  String toString() {
    return 'CartMilestoneProgress(unlocked: $unlocked, next: $next, ladder: $ladder)';
  }
}

/// @nodoc
abstract mixin class $CartMilestoneProgressCopyWith<$Res> {
  factory $CartMilestoneProgressCopyWith(CartMilestoneProgress value,
          $Res Function(CartMilestoneProgress) _then) =
      _$CartMilestoneProgressCopyWithImpl;
  @useResult
  $Res call(
      {CartMilestoneTier? unlocked,
      CartMilestoneTier? next,
      List<CartMilestoneLadderStep> ladder});

  $CartMilestoneTierCopyWith<$Res>? get unlocked;
  $CartMilestoneTierCopyWith<$Res>? get next;
}

/// @nodoc
class _$CartMilestoneProgressCopyWithImpl<$Res>
    implements $CartMilestoneProgressCopyWith<$Res> {
  _$CartMilestoneProgressCopyWithImpl(this._self, this._then);

  final CartMilestoneProgress _self;
  final $Res Function(CartMilestoneProgress) _then;

  /// Create a copy of CartMilestoneProgress
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? unlocked = freezed,
    Object? next = freezed,
    Object? ladder = null,
  }) {
    return _then(_self.copyWith(
      unlocked: freezed == unlocked
          ? _self.unlocked
          : unlocked // ignore: cast_nullable_to_non_nullable
              as CartMilestoneTier?,
      next: freezed == next
          ? _self.next
          : next // ignore: cast_nullable_to_non_nullable
              as CartMilestoneTier?,
      ladder: null == ladder
          ? _self.ladder
          : ladder // ignore: cast_nullable_to_non_nullable
              as List<CartMilestoneLadderStep>,
    ));
  }

  /// Create a copy of CartMilestoneProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CartMilestoneTierCopyWith<$Res>? get unlocked {
    if (_self.unlocked == null) {
      return null;
    }

    return $CartMilestoneTierCopyWith<$Res>(_self.unlocked!, (value) {
      return _then(_self.copyWith(unlocked: value));
    });
  }

  /// Create a copy of CartMilestoneProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CartMilestoneTierCopyWith<$Res>? get next {
    if (_self.next == null) {
      return null;
    }

    return $CartMilestoneTierCopyWith<$Res>(_self.next!, (value) {
      return _then(_self.copyWith(next: value));
    });
  }
}

/// Adds pattern-matching-related methods to [CartMilestoneProgress].
extension CartMilestoneProgressPatterns on CartMilestoneProgress {
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
    TResult Function(_CartMilestoneProgress value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneProgress() when $default != null:
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
    TResult Function(_CartMilestoneProgress value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneProgress():
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
    TResult? Function(_CartMilestoneProgress value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneProgress() when $default != null:
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
    TResult Function(CartMilestoneTier? unlocked, CartMilestoneTier? next,
            List<CartMilestoneLadderStep> ladder)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneProgress() when $default != null:
        return $default(_that.unlocked, _that.next, _that.ladder);
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
    TResult Function(CartMilestoneTier? unlocked, CartMilestoneTier? next,
            List<CartMilestoneLadderStep> ladder)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneProgress():
        return $default(_that.unlocked, _that.next, _that.ladder);
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
    TResult? Function(CartMilestoneTier? unlocked, CartMilestoneTier? next,
            List<CartMilestoneLadderStep> ladder)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CartMilestoneProgress() when $default != null:
        return $default(_that.unlocked, _that.next, _that.ladder);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CartMilestoneProgress implements CartMilestoneProgress {
  const _CartMilestoneProgress(
      {this.unlocked,
      this.next,
      final List<CartMilestoneLadderStep> ladder =
          const <CartMilestoneLadderStep>[]})
      : _ladder = ladder;
  factory _CartMilestoneProgress.fromJson(Map<String, dynamic> json) =>
      _$CartMilestoneProgressFromJson(json);

  @override
  final CartMilestoneTier? unlocked;
  @override
  final CartMilestoneTier? next;
  final List<CartMilestoneLadderStep> _ladder;
  @override
  @JsonKey()
  List<CartMilestoneLadderStep> get ladder {
    if (_ladder is EqualUnmodifiableListView) return _ladder;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_ladder);
  }

  /// Create a copy of CartMilestoneProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CartMilestoneProgressCopyWith<_CartMilestoneProgress> get copyWith =>
      __$CartMilestoneProgressCopyWithImpl<_CartMilestoneProgress>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CartMilestoneProgressToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CartMilestoneProgress &&
            (identical(other.unlocked, unlocked) ||
                other.unlocked == unlocked) &&
            (identical(other.next, next) || other.next == next) &&
            const DeepCollectionEquality().equals(other._ladder, _ladder));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, unlocked, next,
      const DeepCollectionEquality().hash(_ladder));

  @override
  String toString() {
    return 'CartMilestoneProgress(unlocked: $unlocked, next: $next, ladder: $ladder)';
  }
}

/// @nodoc
abstract mixin class _$CartMilestoneProgressCopyWith<$Res>
    implements $CartMilestoneProgressCopyWith<$Res> {
  factory _$CartMilestoneProgressCopyWith(_CartMilestoneProgress value,
          $Res Function(_CartMilestoneProgress) _then) =
      __$CartMilestoneProgressCopyWithImpl;
  @override
  @useResult
  $Res call(
      {CartMilestoneTier? unlocked,
      CartMilestoneTier? next,
      List<CartMilestoneLadderStep> ladder});

  @override
  $CartMilestoneTierCopyWith<$Res>? get unlocked;
  @override
  $CartMilestoneTierCopyWith<$Res>? get next;
}

/// @nodoc
class __$CartMilestoneProgressCopyWithImpl<$Res>
    implements _$CartMilestoneProgressCopyWith<$Res> {
  __$CartMilestoneProgressCopyWithImpl(this._self, this._then);

  final _CartMilestoneProgress _self;
  final $Res Function(_CartMilestoneProgress) _then;

  /// Create a copy of CartMilestoneProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? unlocked = freezed,
    Object? next = freezed,
    Object? ladder = null,
  }) {
    return _then(_CartMilestoneProgress(
      unlocked: freezed == unlocked
          ? _self.unlocked
          : unlocked // ignore: cast_nullable_to_non_nullable
              as CartMilestoneTier?,
      next: freezed == next
          ? _self.next
          : next // ignore: cast_nullable_to_non_nullable
              as CartMilestoneTier?,
      ladder: null == ladder
          ? _self._ladder
          : ladder // ignore: cast_nullable_to_non_nullable
              as List<CartMilestoneLadderStep>,
    ));
  }

  /// Create a copy of CartMilestoneProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CartMilestoneTierCopyWith<$Res>? get unlocked {
    if (_self.unlocked == null) {
      return null;
    }

    return $CartMilestoneTierCopyWith<$Res>(_self.unlocked!, (value) {
      return _then(_self.copyWith(unlocked: value));
    });
  }

  /// Create a copy of CartMilestoneProgress
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CartMilestoneTierCopyWith<$Res>? get next {
    if (_self.next == null) {
      return null;
    }

    return $CartMilestoneTierCopyWith<$Res>(_self.next!, (value) {
      return _then(_self.copyWith(next: value));
    });
  }
}

/// @nodoc
mixin _$FeeLine {
  String get code;
  String get label;
  double get amount;
  double get originalAmount;
  bool get waived;
  String get description;

  /// Create a copy of FeeLine
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FeeLineCopyWith<FeeLine> get copyWith =>
      _$FeeLineCopyWithImpl<FeeLine>(this as FeeLine, _$identity);

  /// Serializes this FeeLine to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FeeLine &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.originalAmount, originalAmount) ||
                other.originalAmount == originalAmount) &&
            (identical(other.waived, waived) || other.waived == waived) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, code, label, amount, originalAmount, waived, description);

  @override
  String toString() {
    return 'FeeLine(code: $code, label: $label, amount: $amount, originalAmount: $originalAmount, waived: $waived, description: $description)';
  }
}

/// @nodoc
abstract mixin class $FeeLineCopyWith<$Res> {
  factory $FeeLineCopyWith(FeeLine value, $Res Function(FeeLine) _then) =
      _$FeeLineCopyWithImpl;
  @useResult
  $Res call(
      {String code,
      String label,
      double amount,
      double originalAmount,
      bool waived,
      String description});
}

/// @nodoc
class _$FeeLineCopyWithImpl<$Res> implements $FeeLineCopyWith<$Res> {
  _$FeeLineCopyWithImpl(this._self, this._then);

  final FeeLine _self;
  final $Res Function(FeeLine) _then;

  /// Create a copy of FeeLine
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? code = null,
    Object? label = null,
    Object? amount = null,
    Object? originalAmount = null,
    Object? waived = null,
    Object? description = null,
  }) {
    return _then(_self.copyWith(
      code: null == code
          ? _self.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      originalAmount: null == originalAmount
          ? _self.originalAmount
          : originalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      waived: null == waived
          ? _self.waived
          : waived // ignore: cast_nullable_to_non_nullable
              as bool,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [FeeLine].
extension FeeLinePatterns on FeeLine {
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
    TResult Function(_FeeLine value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FeeLine() when $default != null:
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
    TResult Function(_FeeLine value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeeLine():
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
    TResult? Function(_FeeLine value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeeLine() when $default != null:
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
    TResult Function(String code, String label, double amount,
            double originalAmount, bool waived, String description)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FeeLine() when $default != null:
        return $default(_that.code, _that.label, _that.amount,
            _that.originalAmount, _that.waived, _that.description);
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
    TResult Function(String code, String label, double amount,
            double originalAmount, bool waived, String description)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeeLine():
        return $default(_that.code, _that.label, _that.amount,
            _that.originalAmount, _that.waived, _that.description);
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
    TResult? Function(String code, String label, double amount,
            double originalAmount, bool waived, String description)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FeeLine() when $default != null:
        return $default(_that.code, _that.label, _that.amount,
            _that.originalAmount, _that.waived, _that.description);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FeeLine implements FeeLine {
  const _FeeLine(
      {this.code = '',
      this.label = '',
      this.amount = 0,
      this.originalAmount = 0,
      this.waived = false,
      this.description = ''});
  factory _FeeLine.fromJson(Map<String, dynamic> json) =>
      _$FeeLineFromJson(json);

  @override
  @JsonKey()
  final String code;
  @override
  @JsonKey()
  final String label;
  @override
  @JsonKey()
  final double amount;
  @override
  @JsonKey()
  final double originalAmount;
  @override
  @JsonKey()
  final bool waived;
  @override
  @JsonKey()
  final String description;

  /// Create a copy of FeeLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FeeLineCopyWith<_FeeLine> get copyWith =>
      __$FeeLineCopyWithImpl<_FeeLine>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FeeLineToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FeeLine &&
            (identical(other.code, code) || other.code == code) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.originalAmount, originalAmount) ||
                other.originalAmount == originalAmount) &&
            (identical(other.waived, waived) || other.waived == waived) &&
            (identical(other.description, description) ||
                other.description == description));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, code, label, amount, originalAmount, waived, description);

  @override
  String toString() {
    return 'FeeLine(code: $code, label: $label, amount: $amount, originalAmount: $originalAmount, waived: $waived, description: $description)';
  }
}

/// @nodoc
abstract mixin class _$FeeLineCopyWith<$Res> implements $FeeLineCopyWith<$Res> {
  factory _$FeeLineCopyWith(_FeeLine value, $Res Function(_FeeLine) _then) =
      __$FeeLineCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String code,
      String label,
      double amount,
      double originalAmount,
      bool waived,
      String description});
}

/// @nodoc
class __$FeeLineCopyWithImpl<$Res> implements _$FeeLineCopyWith<$Res> {
  __$FeeLineCopyWithImpl(this._self, this._then);

  final _FeeLine _self;
  final $Res Function(_FeeLine) _then;

  /// Create a copy of FeeLine
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? code = null,
    Object? label = null,
    Object? amount = null,
    Object? originalAmount = null,
    Object? waived = null,
    Object? description = null,
  }) {
    return _then(_FeeLine(
      code: null == code
          ? _self.code
          : code // ignore: cast_nullable_to_non_nullable
              as String,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      originalAmount: null == originalAmount
          ? _self.originalAmount
          : originalAmount // ignore: cast_nullable_to_non_nullable
              as double,
      waived: null == waived
          ? _self.waived
          : waived // ignore: cast_nullable_to_non_nullable
              as bool,
      description: null == description
          ? _self.description
          : description // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$CodPaymentInfo {
  bool get enabled;
  bool get available;
  double get minAmount;
  double? get maxAmount;
  String? get reason;

  /// Create a copy of CodPaymentInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CodPaymentInfoCopyWith<CodPaymentInfo> get copyWith =>
      _$CodPaymentInfoCopyWithImpl<CodPaymentInfo>(
          this as CodPaymentInfo, _$identity);

  /// Serializes this CodPaymentInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CodPaymentInfo &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.available, available) ||
                other.available == available) &&
            (identical(other.minAmount, minAmount) ||
                other.minAmount == minAmount) &&
            (identical(other.maxAmount, maxAmount) ||
                other.maxAmount == maxAmount) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, enabled, available, minAmount, maxAmount, reason);

  @override
  String toString() {
    return 'CodPaymentInfo(enabled: $enabled, available: $available, minAmount: $minAmount, maxAmount: $maxAmount, reason: $reason)';
  }
}

/// @nodoc
abstract mixin class $CodPaymentInfoCopyWith<$Res> {
  factory $CodPaymentInfoCopyWith(
          CodPaymentInfo value, $Res Function(CodPaymentInfo) _then) =
      _$CodPaymentInfoCopyWithImpl;
  @useResult
  $Res call(
      {bool enabled,
      bool available,
      double minAmount,
      double? maxAmount,
      String? reason});
}

/// @nodoc
class _$CodPaymentInfoCopyWithImpl<$Res>
    implements $CodPaymentInfoCopyWith<$Res> {
  _$CodPaymentInfoCopyWithImpl(this._self, this._then);

  final CodPaymentInfo _self;
  final $Res Function(CodPaymentInfo) _then;

  /// Create a copy of CodPaymentInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? available = null,
    Object? minAmount = null,
    Object? maxAmount = freezed,
    Object? reason = freezed,
  }) {
    return _then(_self.copyWith(
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      available: null == available
          ? _self.available
          : available // ignore: cast_nullable_to_non_nullable
              as bool,
      minAmount: null == minAmount
          ? _self.minAmount
          : minAmount // ignore: cast_nullable_to_non_nullable
              as double,
      maxAmount: freezed == maxAmount
          ? _self.maxAmount
          : maxAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [CodPaymentInfo].
extension CodPaymentInfoPatterns on CodPaymentInfo {
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
    TResult Function(_CodPaymentInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CodPaymentInfo() when $default != null:
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
    TResult Function(_CodPaymentInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CodPaymentInfo():
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
    TResult? Function(_CodPaymentInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CodPaymentInfo() when $default != null:
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
    TResult Function(bool enabled, bool available, double minAmount,
            double? maxAmount, String? reason)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CodPaymentInfo() when $default != null:
        return $default(_that.enabled, _that.available, _that.minAmount,
            _that.maxAmount, _that.reason);
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
    TResult Function(bool enabled, bool available, double minAmount,
            double? maxAmount, String? reason)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CodPaymentInfo():
        return $default(_that.enabled, _that.available, _that.minAmount,
            _that.maxAmount, _that.reason);
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
    TResult? Function(bool enabled, bool available, double minAmount,
            double? maxAmount, String? reason)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CodPaymentInfo() when $default != null:
        return $default(_that.enabled, _that.available, _that.minAmount,
            _that.maxAmount, _that.reason);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _CodPaymentInfo implements CodPaymentInfo {
  const _CodPaymentInfo(
      {this.enabled = true,
      this.available = true,
      this.minAmount = 0,
      this.maxAmount,
      this.reason});
  factory _CodPaymentInfo.fromJson(Map<String, dynamic> json) =>
      _$CodPaymentInfoFromJson(json);

  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey()
  final bool available;
  @override
  @JsonKey()
  final double minAmount;
  @override
  final double? maxAmount;
  @override
  final String? reason;

  /// Create a copy of CodPaymentInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CodPaymentInfoCopyWith<_CodPaymentInfo> get copyWith =>
      __$CodPaymentInfoCopyWithImpl<_CodPaymentInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$CodPaymentInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CodPaymentInfo &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.available, available) ||
                other.available == available) &&
            (identical(other.minAmount, minAmount) ||
                other.minAmount == minAmount) &&
            (identical(other.maxAmount, maxAmount) ||
                other.maxAmount == maxAmount) &&
            (identical(other.reason, reason) || other.reason == reason));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType, enabled, available, minAmount, maxAmount, reason);

  @override
  String toString() {
    return 'CodPaymentInfo(enabled: $enabled, available: $available, minAmount: $minAmount, maxAmount: $maxAmount, reason: $reason)';
  }
}

/// @nodoc
abstract mixin class _$CodPaymentInfoCopyWith<$Res>
    implements $CodPaymentInfoCopyWith<$Res> {
  factory _$CodPaymentInfoCopyWith(
          _CodPaymentInfo value, $Res Function(_CodPaymentInfo) _then) =
      __$CodPaymentInfoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {bool enabled,
      bool available,
      double minAmount,
      double? maxAmount,
      String? reason});
}

/// @nodoc
class __$CodPaymentInfoCopyWithImpl<$Res>
    implements _$CodPaymentInfoCopyWith<$Res> {
  __$CodPaymentInfoCopyWithImpl(this._self, this._then);

  final _CodPaymentInfo _self;
  final $Res Function(_CodPaymentInfo) _then;

  /// Create a copy of CodPaymentInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? enabled = null,
    Object? available = null,
    Object? minAmount = null,
    Object? maxAmount = freezed,
    Object? reason = freezed,
  }) {
    return _then(_CodPaymentInfo(
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      available: null == available
          ? _self.available
          : available // ignore: cast_nullable_to_non_nullable
              as bool,
      minAmount: null == minAmount
          ? _self.minAmount
          : minAmount // ignore: cast_nullable_to_non_nullable
              as double,
      maxAmount: freezed == maxAmount
          ? _self.maxAmount
          : maxAmount // ignore: cast_nullable_to_non_nullable
              as double?,
      reason: freezed == reason
          ? _self.reason
          : reason // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
mixin _$MethodAvailability {
  bool get enabled;

  /// Create a copy of MethodAvailability
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $MethodAvailabilityCopyWith<MethodAvailability> get copyWith =>
      _$MethodAvailabilityCopyWithImpl<MethodAvailability>(
          this as MethodAvailability, _$identity);

  /// Serializes this MethodAvailability to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is MethodAvailability &&
            (identical(other.enabled, enabled) || other.enabled == enabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, enabled);

  @override
  String toString() {
    return 'MethodAvailability(enabled: $enabled)';
  }
}

/// @nodoc
abstract mixin class $MethodAvailabilityCopyWith<$Res> {
  factory $MethodAvailabilityCopyWith(
          MethodAvailability value, $Res Function(MethodAvailability) _then) =
      _$MethodAvailabilityCopyWithImpl;
  @useResult
  $Res call({bool enabled});
}

/// @nodoc
class _$MethodAvailabilityCopyWithImpl<$Res>
    implements $MethodAvailabilityCopyWith<$Res> {
  _$MethodAvailabilityCopyWithImpl(this._self, this._then);

  final MethodAvailability _self;
  final $Res Function(MethodAvailability) _then;

  /// Create a copy of MethodAvailability
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
  }) {
    return _then(_self.copyWith(
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [MethodAvailability].
extension MethodAvailabilityPatterns on MethodAvailability {
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
    TResult Function(_MethodAvailability value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MethodAvailability() when $default != null:
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
    TResult Function(_MethodAvailability value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MethodAvailability():
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
    TResult? Function(_MethodAvailability value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MethodAvailability() when $default != null:
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
    TResult Function(bool enabled)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _MethodAvailability() when $default != null:
        return $default(_that.enabled);
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
    TResult Function(bool enabled) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MethodAvailability():
        return $default(_that.enabled);
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
    TResult? Function(bool enabled)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _MethodAvailability() when $default != null:
        return $default(_that.enabled);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _MethodAvailability implements MethodAvailability {
  const _MethodAvailability({this.enabled = true});
  factory _MethodAvailability.fromJson(Map<String, dynamic> json) =>
      _$MethodAvailabilityFromJson(json);

  @override
  @JsonKey()
  final bool enabled;

  /// Create a copy of MethodAvailability
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$MethodAvailabilityCopyWith<_MethodAvailability> get copyWith =>
      __$MethodAvailabilityCopyWithImpl<_MethodAvailability>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$MethodAvailabilityToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _MethodAvailability &&
            (identical(other.enabled, enabled) || other.enabled == enabled));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, enabled);

  @override
  String toString() {
    return 'MethodAvailability(enabled: $enabled)';
  }
}

/// @nodoc
abstract mixin class _$MethodAvailabilityCopyWith<$Res>
    implements $MethodAvailabilityCopyWith<$Res> {
  factory _$MethodAvailabilityCopyWith(
          _MethodAvailability value, $Res Function(_MethodAvailability) _then) =
      __$MethodAvailabilityCopyWithImpl;
  @override
  @useResult
  $Res call({bool enabled});
}

/// @nodoc
class __$MethodAvailabilityCopyWithImpl<$Res>
    implements _$MethodAvailabilityCopyWith<$Res> {
  __$MethodAvailabilityCopyWithImpl(this._self, this._then);

  final _MethodAvailability _self;
  final $Res Function(_MethodAvailability) _then;

  /// Create a copy of MethodAvailability
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? enabled = null,
  }) {
    return _then(_MethodAvailability(
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$PaymentMethodsInfo {
  CodPaymentInfo get cod;
  MethodAvailability get razorpay;
  MethodAvailability
      get wallet; // Admin kill-switch (Settings → Payments) for the "Place Order" (B2B
// credit) button — independent of whether this particular customer's
// own business account is APPROVED and b2b_enabled (see
// myBusinessAccountProvider, which still gates it per-customer on the
// Flutter side). Field name kept as `ledger` to match the backend's
// existing bill-summary JSON shape.
  MethodAvailability get ledger;

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PaymentMethodsInfoCopyWith<PaymentMethodsInfo> get copyWith =>
      _$PaymentMethodsInfoCopyWithImpl<PaymentMethodsInfo>(
          this as PaymentMethodsInfo, _$identity);

  /// Serializes this PaymentMethodsInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PaymentMethodsInfo &&
            (identical(other.cod, cod) || other.cod == cod) &&
            (identical(other.razorpay, razorpay) ||
                other.razorpay == razorpay) &&
            (identical(other.wallet, wallet) || other.wallet == wallet) &&
            (identical(other.ledger, ledger) || other.ledger == ledger));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, cod, razorpay, wallet, ledger);

  @override
  String toString() {
    return 'PaymentMethodsInfo(cod: $cod, razorpay: $razorpay, wallet: $wallet, ledger: $ledger)';
  }
}

/// @nodoc
abstract mixin class $PaymentMethodsInfoCopyWith<$Res> {
  factory $PaymentMethodsInfoCopyWith(
          PaymentMethodsInfo value, $Res Function(PaymentMethodsInfo) _then) =
      _$PaymentMethodsInfoCopyWithImpl;
  @useResult
  $Res call(
      {CodPaymentInfo cod,
      MethodAvailability razorpay,
      MethodAvailability wallet,
      MethodAvailability ledger});

  $CodPaymentInfoCopyWith<$Res> get cod;
  $MethodAvailabilityCopyWith<$Res> get razorpay;
  $MethodAvailabilityCopyWith<$Res> get wallet;
  $MethodAvailabilityCopyWith<$Res> get ledger;
}

/// @nodoc
class _$PaymentMethodsInfoCopyWithImpl<$Res>
    implements $PaymentMethodsInfoCopyWith<$Res> {
  _$PaymentMethodsInfoCopyWithImpl(this._self, this._then);

  final PaymentMethodsInfo _self;
  final $Res Function(PaymentMethodsInfo) _then;

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? cod = null,
    Object? razorpay = null,
    Object? wallet = null,
    Object? ledger = null,
  }) {
    return _then(_self.copyWith(
      cod: null == cod
          ? _self.cod
          : cod // ignore: cast_nullable_to_non_nullable
              as CodPaymentInfo,
      razorpay: null == razorpay
          ? _self.razorpay
          : razorpay // ignore: cast_nullable_to_non_nullable
              as MethodAvailability,
      wallet: null == wallet
          ? _self.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as MethodAvailability,
      ledger: null == ledger
          ? _self.ledger
          : ledger // ignore: cast_nullable_to_non_nullable
              as MethodAvailability,
    ));
  }

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CodPaymentInfoCopyWith<$Res> get cod {
    return $CodPaymentInfoCopyWith<$Res>(_self.cod, (value) {
      return _then(_self.copyWith(cod: value));
    });
  }

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MethodAvailabilityCopyWith<$Res> get razorpay {
    return $MethodAvailabilityCopyWith<$Res>(_self.razorpay, (value) {
      return _then(_self.copyWith(razorpay: value));
    });
  }

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MethodAvailabilityCopyWith<$Res> get wallet {
    return $MethodAvailabilityCopyWith<$Res>(_self.wallet, (value) {
      return _then(_self.copyWith(wallet: value));
    });
  }

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MethodAvailabilityCopyWith<$Res> get ledger {
    return $MethodAvailabilityCopyWith<$Res>(_self.ledger, (value) {
      return _then(_self.copyWith(ledger: value));
    });
  }
}

/// Adds pattern-matching-related methods to [PaymentMethodsInfo].
extension PaymentMethodsInfoPatterns on PaymentMethodsInfo {
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
    TResult Function(_PaymentMethodsInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodsInfo() when $default != null:
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
    TResult Function(_PaymentMethodsInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodsInfo():
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
    TResult? Function(_PaymentMethodsInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodsInfo() when $default != null:
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
    TResult Function(CodPaymentInfo cod, MethodAvailability razorpay,
            MethodAvailability wallet, MethodAvailability ledger)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodsInfo() when $default != null:
        return $default(_that.cod, _that.razorpay, _that.wallet, _that.ledger);
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
    TResult Function(CodPaymentInfo cod, MethodAvailability razorpay,
            MethodAvailability wallet, MethodAvailability ledger)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodsInfo():
        return $default(_that.cod, _that.razorpay, _that.wallet, _that.ledger);
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
    TResult? Function(CodPaymentInfo cod, MethodAvailability razorpay,
            MethodAvailability wallet, MethodAvailability ledger)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PaymentMethodsInfo() when $default != null:
        return $default(_that.cod, _that.razorpay, _that.wallet, _that.ledger);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _PaymentMethodsInfo implements PaymentMethodsInfo {
  const _PaymentMethodsInfo(
      {this.cod = const CodPaymentInfo(),
      this.razorpay = const MethodAvailability(),
      this.wallet = const MethodAvailability(),
      this.ledger = const MethodAvailability()});
  factory _PaymentMethodsInfo.fromJson(Map<String, dynamic> json) =>
      _$PaymentMethodsInfoFromJson(json);

  @override
  @JsonKey()
  final CodPaymentInfo cod;
  @override
  @JsonKey()
  final MethodAvailability razorpay;
  @override
  @JsonKey()
  final MethodAvailability wallet;
// Admin kill-switch (Settings → Payments) for the "Place Order" (B2B
// credit) button — independent of whether this particular customer's
// own business account is APPROVED and b2b_enabled (see
// myBusinessAccountProvider, which still gates it per-customer on the
// Flutter side). Field name kept as `ledger` to match the backend's
// existing bill-summary JSON shape.
  @override
  @JsonKey()
  final MethodAvailability ledger;

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PaymentMethodsInfoCopyWith<_PaymentMethodsInfo> get copyWith =>
      __$PaymentMethodsInfoCopyWithImpl<_PaymentMethodsInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$PaymentMethodsInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PaymentMethodsInfo &&
            (identical(other.cod, cod) || other.cod == cod) &&
            (identical(other.razorpay, razorpay) ||
                other.razorpay == razorpay) &&
            (identical(other.wallet, wallet) || other.wallet == wallet) &&
            (identical(other.ledger, ledger) || other.ledger == ledger));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, cod, razorpay, wallet, ledger);

  @override
  String toString() {
    return 'PaymentMethodsInfo(cod: $cod, razorpay: $razorpay, wallet: $wallet, ledger: $ledger)';
  }
}

/// @nodoc
abstract mixin class _$PaymentMethodsInfoCopyWith<$Res>
    implements $PaymentMethodsInfoCopyWith<$Res> {
  factory _$PaymentMethodsInfoCopyWith(
          _PaymentMethodsInfo value, $Res Function(_PaymentMethodsInfo) _then) =
      __$PaymentMethodsInfoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {CodPaymentInfo cod,
      MethodAvailability razorpay,
      MethodAvailability wallet,
      MethodAvailability ledger});

  @override
  $CodPaymentInfoCopyWith<$Res> get cod;
  @override
  $MethodAvailabilityCopyWith<$Res> get razorpay;
  @override
  $MethodAvailabilityCopyWith<$Res> get wallet;
  @override
  $MethodAvailabilityCopyWith<$Res> get ledger;
}

/// @nodoc
class __$PaymentMethodsInfoCopyWithImpl<$Res>
    implements _$PaymentMethodsInfoCopyWith<$Res> {
  __$PaymentMethodsInfoCopyWithImpl(this._self, this._then);

  final _PaymentMethodsInfo _self;
  final $Res Function(_PaymentMethodsInfo) _then;

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? cod = null,
    Object? razorpay = null,
    Object? wallet = null,
    Object? ledger = null,
  }) {
    return _then(_PaymentMethodsInfo(
      cod: null == cod
          ? _self.cod
          : cod // ignore: cast_nullable_to_non_nullable
              as CodPaymentInfo,
      razorpay: null == razorpay
          ? _self.razorpay
          : razorpay // ignore: cast_nullable_to_non_nullable
              as MethodAvailability,
      wallet: null == wallet
          ? _self.wallet
          : wallet // ignore: cast_nullable_to_non_nullable
              as MethodAvailability,
      ledger: null == ledger
          ? _self.ledger
          : ledger // ignore: cast_nullable_to_non_nullable
              as MethodAvailability,
    ));
  }

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $CodPaymentInfoCopyWith<$Res> get cod {
    return $CodPaymentInfoCopyWith<$Res>(_self.cod, (value) {
      return _then(_self.copyWith(cod: value));
    });
  }

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MethodAvailabilityCopyWith<$Res> get razorpay {
    return $MethodAvailabilityCopyWith<$Res>(_self.razorpay, (value) {
      return _then(_self.copyWith(razorpay: value));
    });
  }

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MethodAvailabilityCopyWith<$Res> get wallet {
    return $MethodAvailabilityCopyWith<$Res>(_self.wallet, (value) {
      return _then(_self.copyWith(wallet: value));
    });
  }

  /// Create a copy of PaymentMethodsInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $MethodAvailabilityCopyWith<$Res> get ledger {
    return $MethodAvailabilityCopyWith<$Res>(_self.ledger, (value) {
      return _then(_self.copyWith(ledger: value));
    });
  }
}

/// @nodoc
mixin _$FirstTimeOfferInfo {
  String get id;
  String get name;
  String get rewardType;
  double get discount;
  bool
      get freeDelivery; // Only non-zero for rewardType WALLET_CASHBACK — the wallet credit the
// customer will actually earn on this order.
  double get cashbackAmount;

  /// Create a copy of FirstTimeOfferInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FirstTimeOfferInfoCopyWith<FirstTimeOfferInfo> get copyWith =>
      _$FirstTimeOfferInfoCopyWithImpl<FirstTimeOfferInfo>(
          this as FirstTimeOfferInfo, _$identity);

  /// Serializes this FirstTimeOfferInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FirstTimeOfferInfo &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rewardType, rewardType) ||
                other.rewardType == rewardType) &&
            (identical(other.discount, discount) ||
                other.discount == discount) &&
            (identical(other.freeDelivery, freeDelivery) ||
                other.freeDelivery == freeDelivery) &&
            (identical(other.cashbackAmount, cashbackAmount) ||
                other.cashbackAmount == cashbackAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, rewardType, discount,
      freeDelivery, cashbackAmount);

  @override
  String toString() {
    return 'FirstTimeOfferInfo(id: $id, name: $name, rewardType: $rewardType, discount: $discount, freeDelivery: $freeDelivery, cashbackAmount: $cashbackAmount)';
  }
}

/// @nodoc
abstract mixin class $FirstTimeOfferInfoCopyWith<$Res> {
  factory $FirstTimeOfferInfoCopyWith(
          FirstTimeOfferInfo value, $Res Function(FirstTimeOfferInfo) _then) =
      _$FirstTimeOfferInfoCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String rewardType,
      double discount,
      bool freeDelivery,
      double cashbackAmount});
}

/// @nodoc
class _$FirstTimeOfferInfoCopyWithImpl<$Res>
    implements $FirstTimeOfferInfoCopyWith<$Res> {
  _$FirstTimeOfferInfoCopyWithImpl(this._self, this._then);

  final FirstTimeOfferInfo _self;
  final $Res Function(FirstTimeOfferInfo) _then;

  /// Create a copy of FirstTimeOfferInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? rewardType = null,
    Object? discount = null,
    Object? freeDelivery = null,
    Object? cashbackAmount = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rewardType: null == rewardType
          ? _self.rewardType
          : rewardType // ignore: cast_nullable_to_non_nullable
              as String,
      discount: null == discount
          ? _self.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double,
      freeDelivery: null == freeDelivery
          ? _self.freeDelivery
          : freeDelivery // ignore: cast_nullable_to_non_nullable
              as bool,
      cashbackAmount: null == cashbackAmount
          ? _self.cashbackAmount
          : cashbackAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// Adds pattern-matching-related methods to [FirstTimeOfferInfo].
extension FirstTimeOfferInfoPatterns on FirstTimeOfferInfo {
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
    TResult Function(_FirstTimeOfferInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferInfo() when $default != null:
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
    TResult Function(_FirstTimeOfferInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferInfo():
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
    TResult? Function(_FirstTimeOfferInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferInfo() when $default != null:
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
    TResult Function(String id, String name, String rewardType, double discount,
            bool freeDelivery, double cashbackAmount)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferInfo() when $default != null:
        return $default(_that.id, _that.name, _that.rewardType, _that.discount,
            _that.freeDelivery, _that.cashbackAmount);
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
    TResult Function(String id, String name, String rewardType, double discount,
            bool freeDelivery, double cashbackAmount)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferInfo():
        return $default(_that.id, _that.name, _that.rewardType, _that.discount,
            _that.freeDelivery, _that.cashbackAmount);
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
    TResult? Function(String id, String name, String rewardType,
            double discount, bool freeDelivery, double cashbackAmount)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferInfo() when $default != null:
        return $default(_that.id, _that.name, _that.rewardType, _that.discount,
            _that.freeDelivery, _that.cashbackAmount);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FirstTimeOfferInfo implements FirstTimeOfferInfo {
  const _FirstTimeOfferInfo(
      {this.id = '',
      this.name = '',
      this.rewardType = '',
      this.discount = 0,
      this.freeDelivery = false,
      this.cashbackAmount = 0});
  factory _FirstTimeOfferInfo.fromJson(Map<String, dynamic> json) =>
      _$FirstTimeOfferInfoFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String rewardType;
  @override
  @JsonKey()
  final double discount;
  @override
  @JsonKey()
  final bool freeDelivery;
// Only non-zero for rewardType WALLET_CASHBACK — the wallet credit the
// customer will actually earn on this order.
  @override
  @JsonKey()
  final double cashbackAmount;

  /// Create a copy of FirstTimeOfferInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FirstTimeOfferInfoCopyWith<_FirstTimeOfferInfo> get copyWith =>
      __$FirstTimeOfferInfoCopyWithImpl<_FirstTimeOfferInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FirstTimeOfferInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FirstTimeOfferInfo &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rewardType, rewardType) ||
                other.rewardType == rewardType) &&
            (identical(other.discount, discount) ||
                other.discount == discount) &&
            (identical(other.freeDelivery, freeDelivery) ||
                other.freeDelivery == freeDelivery) &&
            (identical(other.cashbackAmount, cashbackAmount) ||
                other.cashbackAmount == cashbackAmount));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, id, name, rewardType, discount,
      freeDelivery, cashbackAmount);

  @override
  String toString() {
    return 'FirstTimeOfferInfo(id: $id, name: $name, rewardType: $rewardType, discount: $discount, freeDelivery: $freeDelivery, cashbackAmount: $cashbackAmount)';
  }
}

/// @nodoc
abstract mixin class _$FirstTimeOfferInfoCopyWith<$Res>
    implements $FirstTimeOfferInfoCopyWith<$Res> {
  factory _$FirstTimeOfferInfoCopyWith(
          _FirstTimeOfferInfo value, $Res Function(_FirstTimeOfferInfo) _then) =
      __$FirstTimeOfferInfoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String rewardType,
      double discount,
      bool freeDelivery,
      double cashbackAmount});
}

/// @nodoc
class __$FirstTimeOfferInfoCopyWithImpl<$Res>
    implements _$FirstTimeOfferInfoCopyWith<$Res> {
  __$FirstTimeOfferInfoCopyWithImpl(this._self, this._then);

  final _FirstTimeOfferInfo _self;
  final $Res Function(_FirstTimeOfferInfo) _then;

  /// Create a copy of FirstTimeOfferInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? rewardType = null,
    Object? discount = null,
    Object? freeDelivery = null,
    Object? cashbackAmount = null,
  }) {
    return _then(_FirstTimeOfferInfo(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rewardType: null == rewardType
          ? _self.rewardType
          : rewardType // ignore: cast_nullable_to_non_nullable
              as String,
      discount: null == discount
          ? _self.discount
          : discount // ignore: cast_nullable_to_non_nullable
              as double,
      freeDelivery: null == freeDelivery
          ? _self.freeDelivery
          : freeDelivery // ignore: cast_nullable_to_non_nullable
              as bool,
      cashbackAmount: null == cashbackAmount
          ? _self.cashbackAmount
          : cashbackAmount // ignore: cast_nullable_to_non_nullable
              as double,
    ));
  }
}

/// @nodoc
mixin _$FirstTimeOfferTeaserInfo {
  String get id;
  String get name;
  String get rewardType;
  double get amountToUnlock;
  String get message;

  /// Create a copy of FirstTimeOfferTeaserInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $FirstTimeOfferTeaserInfoCopyWith<FirstTimeOfferTeaserInfo> get copyWith =>
      _$FirstTimeOfferTeaserInfoCopyWithImpl<FirstTimeOfferTeaserInfo>(
          this as FirstTimeOfferTeaserInfo, _$identity);

  /// Serializes this FirstTimeOfferTeaserInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is FirstTimeOfferTeaserInfo &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rewardType, rewardType) ||
                other.rewardType == rewardType) &&
            (identical(other.amountToUnlock, amountToUnlock) ||
                other.amountToUnlock == amountToUnlock) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, rewardType, amountToUnlock, message);

  @override
  String toString() {
    return 'FirstTimeOfferTeaserInfo(id: $id, name: $name, rewardType: $rewardType, amountToUnlock: $amountToUnlock, message: $message)';
  }
}

/// @nodoc
abstract mixin class $FirstTimeOfferTeaserInfoCopyWith<$Res> {
  factory $FirstTimeOfferTeaserInfoCopyWith(FirstTimeOfferTeaserInfo value,
          $Res Function(FirstTimeOfferTeaserInfo) _then) =
      _$FirstTimeOfferTeaserInfoCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String rewardType,
      double amountToUnlock,
      String message});
}

/// @nodoc
class _$FirstTimeOfferTeaserInfoCopyWithImpl<$Res>
    implements $FirstTimeOfferTeaserInfoCopyWith<$Res> {
  _$FirstTimeOfferTeaserInfoCopyWithImpl(this._self, this._then);

  final FirstTimeOfferTeaserInfo _self;
  final $Res Function(FirstTimeOfferTeaserInfo) _then;

  /// Create a copy of FirstTimeOfferTeaserInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? rewardType = null,
    Object? amountToUnlock = null,
    Object? message = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rewardType: null == rewardType
          ? _self.rewardType
          : rewardType // ignore: cast_nullable_to_non_nullable
              as String,
      amountToUnlock: null == amountToUnlock
          ? _self.amountToUnlock
          : amountToUnlock // ignore: cast_nullable_to_non_nullable
              as double,
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [FirstTimeOfferTeaserInfo].
extension FirstTimeOfferTeaserInfoPatterns on FirstTimeOfferTeaserInfo {
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
    TResult Function(_FirstTimeOfferTeaserInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferTeaserInfo() when $default != null:
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
    TResult Function(_FirstTimeOfferTeaserInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferTeaserInfo():
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
    TResult? Function(_FirstTimeOfferTeaserInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferTeaserInfo() when $default != null:
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
    TResult Function(String id, String name, String rewardType,
            double amountToUnlock, String message)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferTeaserInfo() when $default != null:
        return $default(_that.id, _that.name, _that.rewardType,
            _that.amountToUnlock, _that.message);
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
    TResult Function(String id, String name, String rewardType,
            double amountToUnlock, String message)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferTeaserInfo():
        return $default(_that.id, _that.name, _that.rewardType,
            _that.amountToUnlock, _that.message);
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
    TResult? Function(String id, String name, String rewardType,
            double amountToUnlock, String message)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _FirstTimeOfferTeaserInfo() when $default != null:
        return $default(_that.id, _that.name, _that.rewardType,
            _that.amountToUnlock, _that.message);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _FirstTimeOfferTeaserInfo implements FirstTimeOfferTeaserInfo {
  const _FirstTimeOfferTeaserInfo(
      {this.id = '',
      this.name = '',
      this.rewardType = '',
      this.amountToUnlock = 0,
      this.message = ''});
  factory _FirstTimeOfferTeaserInfo.fromJson(Map<String, dynamic> json) =>
      _$FirstTimeOfferTeaserInfoFromJson(json);

  @override
  @JsonKey()
  final String id;
  @override
  @JsonKey()
  final String name;
  @override
  @JsonKey()
  final String rewardType;
  @override
  @JsonKey()
  final double amountToUnlock;
  @override
  @JsonKey()
  final String message;

  /// Create a copy of FirstTimeOfferTeaserInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$FirstTimeOfferTeaserInfoCopyWith<_FirstTimeOfferTeaserInfo> get copyWith =>
      __$FirstTimeOfferTeaserInfoCopyWithImpl<_FirstTimeOfferTeaserInfo>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$FirstTimeOfferTeaserInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _FirstTimeOfferTeaserInfo &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.rewardType, rewardType) ||
                other.rewardType == rewardType) &&
            (identical(other.amountToUnlock, amountToUnlock) ||
                other.amountToUnlock == amountToUnlock) &&
            (identical(other.message, message) || other.message == message));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, id, name, rewardType, amountToUnlock, message);

  @override
  String toString() {
    return 'FirstTimeOfferTeaserInfo(id: $id, name: $name, rewardType: $rewardType, amountToUnlock: $amountToUnlock, message: $message)';
  }
}

/// @nodoc
abstract mixin class _$FirstTimeOfferTeaserInfoCopyWith<$Res>
    implements $FirstTimeOfferTeaserInfoCopyWith<$Res> {
  factory _$FirstTimeOfferTeaserInfoCopyWith(_FirstTimeOfferTeaserInfo value,
          $Res Function(_FirstTimeOfferTeaserInfo) _then) =
      __$FirstTimeOfferTeaserInfoCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String rewardType,
      double amountToUnlock,
      String message});
}

/// @nodoc
class __$FirstTimeOfferTeaserInfoCopyWithImpl<$Res>
    implements _$FirstTimeOfferTeaserInfoCopyWith<$Res> {
  __$FirstTimeOfferTeaserInfoCopyWithImpl(this._self, this._then);

  final _FirstTimeOfferTeaserInfo _self;
  final $Res Function(_FirstTimeOfferTeaserInfo) _then;

  /// Create a copy of FirstTimeOfferTeaserInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? rewardType = null,
    Object? amountToUnlock = null,
    Object? message = null,
  }) {
    return _then(_FirstTimeOfferTeaserInfo(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      rewardType: null == rewardType
          ? _self.rewardType
          : rewardType // ignore: cast_nullable_to_non_nullable
              as String,
      amountToUnlock: null == amountToUnlock
          ? _self.amountToUnlock
          : amountToUnlock // ignore: cast_nullable_to_non_nullable
              as double,
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// @nodoc
mixin _$QuickDeliveryInfo {
  bool get enabled;
  double get amount;
  String get label;

  /// Promised delivery time once the customer opts in — distinct from
  /// the normal always-shown [DeliveryEstimate].
  int get etaMinutes;

  /// Create a copy of QuickDeliveryInfo
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $QuickDeliveryInfoCopyWith<QuickDeliveryInfo> get copyWith =>
      _$QuickDeliveryInfoCopyWithImpl<QuickDeliveryInfo>(
          this as QuickDeliveryInfo, _$identity);

  /// Serializes this QuickDeliveryInfo to a JSON map.
  Map<String, dynamic> toJson();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is QuickDeliveryInfo &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.etaMinutes, etaMinutes) ||
                other.etaMinutes == etaMinutes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, enabled, amount, label, etaMinutes);

  @override
  String toString() {
    return 'QuickDeliveryInfo(enabled: $enabled, amount: $amount, label: $label, etaMinutes: $etaMinutes)';
  }
}

/// @nodoc
abstract mixin class $QuickDeliveryInfoCopyWith<$Res> {
  factory $QuickDeliveryInfoCopyWith(
          QuickDeliveryInfo value, $Res Function(QuickDeliveryInfo) _then) =
      _$QuickDeliveryInfoCopyWithImpl;
  @useResult
  $Res call({bool enabled, double amount, String label, int etaMinutes});
}

/// @nodoc
class _$QuickDeliveryInfoCopyWithImpl<$Res>
    implements $QuickDeliveryInfoCopyWith<$Res> {
  _$QuickDeliveryInfoCopyWithImpl(this._self, this._then);

  final QuickDeliveryInfo _self;
  final $Res Function(QuickDeliveryInfo) _then;

  /// Create a copy of QuickDeliveryInfo
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? enabled = null,
    Object? amount = null,
    Object? label = null,
    Object? etaMinutes = null,
  }) {
    return _then(_self.copyWith(
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      etaMinutes: null == etaMinutes
          ? _self.etaMinutes
          : etaMinutes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// Adds pattern-matching-related methods to [QuickDeliveryInfo].
extension QuickDeliveryInfoPatterns on QuickDeliveryInfo {
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
    TResult Function(_QuickDeliveryInfo value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _QuickDeliveryInfo() when $default != null:
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
    TResult Function(_QuickDeliveryInfo value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _QuickDeliveryInfo():
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
    TResult? Function(_QuickDeliveryInfo value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _QuickDeliveryInfo() when $default != null:
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
    TResult Function(bool enabled, double amount, String label, int etaMinutes)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _QuickDeliveryInfo() when $default != null:
        return $default(
            _that.enabled, _that.amount, _that.label, _that.etaMinutes);
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
    TResult Function(bool enabled, double amount, String label, int etaMinutes)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _QuickDeliveryInfo():
        return $default(
            _that.enabled, _that.amount, _that.label, _that.etaMinutes);
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
            bool enabled, double amount, String label, int etaMinutes)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _QuickDeliveryInfo() when $default != null:
        return $default(
            _that.enabled, _that.amount, _that.label, _that.etaMinutes);
      case _:
        return null;
    }
  }
}

/// @nodoc
@JsonSerializable()
class _QuickDeliveryInfo implements QuickDeliveryInfo {
  const _QuickDeliveryInfo(
      {this.enabled = false,
      this.amount = 0,
      this.label = 'Quick delivery fee',
      this.etaMinutes = 0});
  factory _QuickDeliveryInfo.fromJson(Map<String, dynamic> json) =>
      _$QuickDeliveryInfoFromJson(json);

  @override
  @JsonKey()
  final bool enabled;
  @override
  @JsonKey()
  final double amount;
  @override
  @JsonKey()
  final String label;

  /// Promised delivery time once the customer opts in — distinct from
  /// the normal always-shown [DeliveryEstimate].
  @override
  @JsonKey()
  final int etaMinutes;

  /// Create a copy of QuickDeliveryInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$QuickDeliveryInfoCopyWith<_QuickDeliveryInfo> get copyWith =>
      __$QuickDeliveryInfoCopyWithImpl<_QuickDeliveryInfo>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$QuickDeliveryInfoToJson(
      this,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _QuickDeliveryInfo &&
            (identical(other.enabled, enabled) || other.enabled == enabled) &&
            (identical(other.amount, amount) || other.amount == amount) &&
            (identical(other.label, label) || other.label == label) &&
            (identical(other.etaMinutes, etaMinutes) ||
                other.etaMinutes == etaMinutes));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode =>
      Object.hash(runtimeType, enabled, amount, label, etaMinutes);

  @override
  String toString() {
    return 'QuickDeliveryInfo(enabled: $enabled, amount: $amount, label: $label, etaMinutes: $etaMinutes)';
  }
}

/// @nodoc
abstract mixin class _$QuickDeliveryInfoCopyWith<$Res>
    implements $QuickDeliveryInfoCopyWith<$Res> {
  factory _$QuickDeliveryInfoCopyWith(
          _QuickDeliveryInfo value, $Res Function(_QuickDeliveryInfo) _then) =
      __$QuickDeliveryInfoCopyWithImpl;
  @override
  @useResult
  $Res call({bool enabled, double amount, String label, int etaMinutes});
}

/// @nodoc
class __$QuickDeliveryInfoCopyWithImpl<$Res>
    implements _$QuickDeliveryInfoCopyWith<$Res> {
  __$QuickDeliveryInfoCopyWithImpl(this._self, this._then);

  final _QuickDeliveryInfo _self;
  final $Res Function(_QuickDeliveryInfo) _then;

  /// Create a copy of QuickDeliveryInfo
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? enabled = null,
    Object? amount = null,
    Object? label = null,
    Object? etaMinutes = null,
  }) {
    return _then(_QuickDeliveryInfo(
      enabled: null == enabled
          ? _self.enabled
          : enabled // ignore: cast_nullable_to_non_nullable
              as bool,
      amount: null == amount
          ? _self.amount
          : amount // ignore: cast_nullable_to_non_nullable
              as double,
      label: null == label
          ? _self.label
          : label // ignore: cast_nullable_to_non_nullable
              as String,
      etaMinutes: null == etaMinutes
          ? _self.etaMinutes
          : etaMinutes // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
