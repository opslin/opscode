// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'bill_summary_entity.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BillSummaryEntity _$BillSummaryEntityFromJson(Map<String, dynamic> json) =>
    _BillSummaryEntity(
      itemTotal: ItemTotal.fromJson(json['itemTotal'] as Map<String, dynamic>),
      deliveryFee:
          DeliveryFeeInfo.fromJson(json['deliveryFee'] as Map<String, dynamic>),
      handlingFee:
          FeeInfo.fromJson(json['handlingFee'] as Map<String, dynamic>),
      lateNightFee: LateNightFeeInfo.fromJson(
          json['lateNightFee'] as Map<String, dynamic>),
      toPay: BillToPay.fromJson(json['toPay'] as Map<String, dynamic>),
      savings: SavingsBreakdownEntity.fromJson(
          json['savings'] as Map<String, dynamic>),
      deliveryEstimate: DeliveryEstimate.fromJson(
          json['deliveryEstimate'] as Map<String, dynamic>),
      couponDiscount: (json['couponDiscount'] as num?)?.toDouble() ?? 0,
      tipAmount: (json['tipAmount'] as num?)?.toDouble() ?? 0,
      itemCount: (json['itemCount'] as num?)?.toInt() ?? 0,
      platformFee: json['platformFee'] == null
          ? const FeeInfo()
          : FeeInfo.fromJson(json['platformFee'] as Map<String, dynamic>),
      smallCartFee: json['smallCartFee'] == null
          ? const FeeInfo()
          : FeeInfo.fromJson(json['smallCartFee'] as Map<String, dynamic>),
      distance: json['distance'] == null
          ? const DistanceInfo()
          : DistanceInfo.fromJson(json['distance'] as Map<String, dynamic>),
      freeDelivery: json['freeDelivery'] == null
          ? const FreeDeliveryInfo()
          : FreeDeliveryInfo.fromJson(
              json['freeDelivery'] as Map<String, dynamic>),
      totalPayable: (json['totalPayable'] as num?)?.toDouble() ?? 0,
      fees: (json['fees'] as List<dynamic>?)
              ?.map((e) => FeeLine.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <FeeLine>[],
      paymentMethods: json['paymentMethods'] == null
          ? const PaymentMethodsInfo()
          : PaymentMethodsInfo.fromJson(
              json['paymentMethods'] as Map<String, dynamic>),
      cartMilestone: json['cartMilestone'] == null
          ? const CartMilestoneProgress()
          : CartMilestoneProgress.fromJson(
              json['cartMilestone'] as Map<String, dynamic>),
      quickDelivery: json['quickDelivery'] == null
          ? const QuickDeliveryInfo()
          : QuickDeliveryInfo.fromJson(
              json['quickDelivery'] as Map<String, dynamic>),
      firstTimeOffer: json['firstTimeOffer'] == null
          ? null
          : FirstTimeOfferInfo.fromJson(
              json['firstTimeOffer'] as Map<String, dynamic>),
      firstTimeOfferTeaser: json['firstTimeOfferTeaser'] == null
          ? null
          : FirstTimeOfferTeaserInfo.fromJson(
              json['firstTimeOfferTeaser'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$BillSummaryEntityToJson(_BillSummaryEntity instance) =>
    <String, dynamic>{
      'itemTotal': instance.itemTotal,
      'deliveryFee': instance.deliveryFee,
      'handlingFee': instance.handlingFee,
      'lateNightFee': instance.lateNightFee,
      'toPay': instance.toPay,
      'savings': instance.savings,
      'deliveryEstimate': instance.deliveryEstimate,
      'couponDiscount': instance.couponDiscount,
      'tipAmount': instance.tipAmount,
      'itemCount': instance.itemCount,
      'platformFee': instance.platformFee,
      'smallCartFee': instance.smallCartFee,
      'distance': instance.distance,
      'freeDelivery': instance.freeDelivery,
      'totalPayable': instance.totalPayable,
      'fees': instance.fees,
      'paymentMethods': instance.paymentMethods,
      'cartMilestone': instance.cartMilestone,
      'quickDelivery': instance.quickDelivery,
      'firstTimeOffer': instance.firstTimeOffer,
      'firstTimeOfferTeaser': instance.firstTimeOfferTeaser,
    };

_ItemTotal _$ItemTotalFromJson(Map<String, dynamic> json) => _ItemTotal(
      original: (json['original'] as num?)?.toDouble() ?? 0,
      discounted: (json['discounted'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$ItemTotalToJson(_ItemTotal instance) =>
    <String, dynamic>{
      'original': instance.original,
      'discounted': instance.discounted,
    };

_DeliveryFeeInfo _$DeliveryFeeInfoFromJson(Map<String, dynamic> json) =>
    _DeliveryFeeInfo(
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      isFree: json['isFree'] as bool? ?? false,
      freeIn: (json['freeIn'] as num?)?.toDouble() ?? 0,
      originalAmount: (json['originalAmount'] as num?)?.toDouble() ?? 0,
      waiverReason: json['waiverReason'] as String?,
    );

Map<String, dynamic> _$DeliveryFeeInfoToJson(_DeliveryFeeInfo instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'isFree': instance.isFree,
      'freeIn': instance.freeIn,
      'originalAmount': instance.originalAmount,
      'waiverReason': instance.waiverReason,
    };

_FeeInfo _$FeeInfoFromJson(Map<String, dynamic> json) => _FeeInfo(
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      isFree: json['isFree'] as bool? ?? false,
      savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0,
      label: json['label'] as String?,
      description: json['description'] as String?,
    );

Map<String, dynamic> _$FeeInfoToJson(_FeeInfo instance) => <String, dynamic>{
      'amount': instance.amount,
      'isFree': instance.isFree,
      'savedAmount': instance.savedAmount,
      'label': instance.label,
      'description': instance.description,
    };

_LateNightFeeInfo _$LateNightFeeInfoFromJson(Map<String, dynamic> json) =>
    _LateNightFeeInfo(
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      isFree: json['isFree'] as bool? ?? false,
      savedAmount: (json['savedAmount'] as num?)?.toDouble() ?? 0,
      isLateNight: json['isLateNight'] as bool? ?? false,
    );

Map<String, dynamic> _$LateNightFeeInfoToJson(_LateNightFeeInfo instance) =>
    <String, dynamic>{
      'amount': instance.amount,
      'isFree': instance.isFree,
      'savedAmount': instance.savedAmount,
      'isLateNight': instance.isLateNight,
    };

_BillToPay _$BillToPayFromJson(Map<String, dynamic> json) => _BillToPay(
      original: (json['original'] as num?)?.toDouble() ?? 0,
      finalAmount: (json['final'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$BillToPayToJson(_BillToPay instance) =>
    <String, dynamic>{
      'original': instance.original,
      'final': instance.finalAmount,
    };

_DeliveryEstimate _$DeliveryEstimateFromJson(Map<String, dynamic> json) =>
    _DeliveryEstimate(
      minutes: (json['minutes'] as num?)?.toInt() ?? 30,
      label: json['label'] as String? ?? 'Delivering in 30 mins',
    );

Map<String, dynamic> _$DeliveryEstimateToJson(_DeliveryEstimate instance) =>
    <String, dynamic>{
      'minutes': instance.minutes,
      'label': instance.label,
    };

_DistanceInfo _$DistanceInfoFromJson(Map<String, dynamic> json) =>
    _DistanceInfo(
      km: (json['km'] as num?)?.toDouble(),
      label: json['label'] as String? ?? '',
      known: json['known'] as bool? ?? false,
    );

Map<String, dynamic> _$DistanceInfoToJson(_DistanceInfo instance) =>
    <String, dynamic>{
      'km': instance.km,
      'label': instance.label,
      'known': instance.known,
    };

_FreeDeliveryInfo _$FreeDeliveryInfoFromJson(Map<String, dynamic> json) =>
    _FreeDeliveryInfo(
      enabled: json['enabled'] as bool? ?? false,
      threshold: (json['threshold'] as num?)?.toDouble(),
      unlocked: json['unlocked'] as bool? ?? false,
      amountToUnlock: (json['amountToUnlock'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$FreeDeliveryInfoToJson(_FreeDeliveryInfo instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'threshold': instance.threshold,
      'unlocked': instance.unlocked,
      'amountToUnlock': instance.amountToUnlock,
    };

_CartMilestoneTier _$CartMilestoneTierFromJson(Map<String, dynamic> json) =>
    _CartMilestoneTier(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rewardType: json['rewardType'] as String? ?? '',
      minCartAmount: (json['minCartAmount'] as num?)?.toDouble() ?? 0,
      amountToUnlock: (json['amountToUnlock'] as num?)?.toDouble() ?? 0,
      message: json['message'] as String? ?? '',
      iconUrl: json['iconUrl'] as String?,
      cashbackAmount: (json['cashbackAmount'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$CartMilestoneTierToJson(_CartMilestoneTier instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'rewardType': instance.rewardType,
      'minCartAmount': instance.minCartAmount,
      'amountToUnlock': instance.amountToUnlock,
      'message': instance.message,
      'iconUrl': instance.iconUrl,
      'cashbackAmount': instance.cashbackAmount,
    };

_CartMilestoneLadderStep _$CartMilestoneLadderStepFromJson(
        Map<String, dynamic> json) =>
    _CartMilestoneLadderStep(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      minAmount: (json['minAmount'] as num?)?.toDouble() ?? 0,
      achieved: json['achieved'] as bool? ?? false,
      segmentProgress: (json['segmentProgress'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$CartMilestoneLadderStepToJson(
        _CartMilestoneLadderStep instance) =>
    <String, dynamic>{
      'id': instance.id,
      'label': instance.label,
      'minAmount': instance.minAmount,
      'achieved': instance.achieved,
      'segmentProgress': instance.segmentProgress,
    };

_CartMilestoneProgress _$CartMilestoneProgressFromJson(
        Map<String, dynamic> json) =>
    _CartMilestoneProgress(
      unlocked: json['unlocked'] == null
          ? null
          : CartMilestoneTier.fromJson(
              json['unlocked'] as Map<String, dynamic>),
      next: json['next'] == null
          ? null
          : CartMilestoneTier.fromJson(json['next'] as Map<String, dynamic>),
      ladder: (json['ladder'] as List<dynamic>?)
              ?.map((e) =>
                  CartMilestoneLadderStep.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const <CartMilestoneLadderStep>[],
    );

Map<String, dynamic> _$CartMilestoneProgressToJson(
        _CartMilestoneProgress instance) =>
    <String, dynamic>{
      'unlocked': instance.unlocked,
      'next': instance.next,
      'ladder': instance.ladder,
    };

_FeeLine _$FeeLineFromJson(Map<String, dynamic> json) => _FeeLine(
      code: json['code'] as String? ?? '',
      label: json['label'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      originalAmount: (json['originalAmount'] as num?)?.toDouble() ?? 0,
      waived: json['waived'] as bool? ?? false,
      description: json['description'] as String? ?? '',
    );

Map<String, dynamic> _$FeeLineToJson(_FeeLine instance) => <String, dynamic>{
      'code': instance.code,
      'label': instance.label,
      'amount': instance.amount,
      'originalAmount': instance.originalAmount,
      'waived': instance.waived,
      'description': instance.description,
    };

_CodPaymentInfo _$CodPaymentInfoFromJson(Map<String, dynamic> json) =>
    _CodPaymentInfo(
      enabled: json['enabled'] as bool? ?? true,
      available: json['available'] as bool? ?? true,
      minAmount: (json['minAmount'] as num?)?.toDouble() ?? 0,
      maxAmount: (json['maxAmount'] as num?)?.toDouble(),
      reason: json['reason'] as String?,
    );

Map<String, dynamic> _$CodPaymentInfoToJson(_CodPaymentInfo instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'available': instance.available,
      'minAmount': instance.minAmount,
      'maxAmount': instance.maxAmount,
      'reason': instance.reason,
    };

_MethodAvailability _$MethodAvailabilityFromJson(Map<String, dynamic> json) =>
    _MethodAvailability(
      enabled: json['enabled'] as bool? ?? true,
    );

Map<String, dynamic> _$MethodAvailabilityToJson(_MethodAvailability instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
    };

_PaymentMethodsInfo _$PaymentMethodsInfoFromJson(Map<String, dynamic> json) =>
    _PaymentMethodsInfo(
      cod: json['cod'] == null
          ? const CodPaymentInfo()
          : CodPaymentInfo.fromJson(json['cod'] as Map<String, dynamic>),
      razorpay: json['razorpay'] == null
          ? const MethodAvailability()
          : MethodAvailability.fromJson(
              json['razorpay'] as Map<String, dynamic>),
      wallet: json['wallet'] == null
          ? const MethodAvailability()
          : MethodAvailability.fromJson(json['wallet'] as Map<String, dynamic>),
      ledger: json['ledger'] == null
          ? const MethodAvailability()
          : MethodAvailability.fromJson(json['ledger'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PaymentMethodsInfoToJson(_PaymentMethodsInfo instance) =>
    <String, dynamic>{
      'cod': instance.cod,
      'razorpay': instance.razorpay,
      'wallet': instance.wallet,
      'ledger': instance.ledger,
    };

_FirstTimeOfferInfo _$FirstTimeOfferInfoFromJson(Map<String, dynamic> json) =>
    _FirstTimeOfferInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rewardType: json['rewardType'] as String? ?? '',
      discount: (json['discount'] as num?)?.toDouble() ?? 0,
      freeDelivery: json['freeDelivery'] as bool? ?? false,
      cashbackAmount: (json['cashbackAmount'] as num?)?.toDouble() ?? 0,
    );

Map<String, dynamic> _$FirstTimeOfferInfoToJson(_FirstTimeOfferInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'rewardType': instance.rewardType,
      'discount': instance.discount,
      'freeDelivery': instance.freeDelivery,
      'cashbackAmount': instance.cashbackAmount,
    };

_FirstTimeOfferTeaserInfo _$FirstTimeOfferTeaserInfoFromJson(
        Map<String, dynamic> json) =>
    _FirstTimeOfferTeaserInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      rewardType: json['rewardType'] as String? ?? '',
      amountToUnlock: (json['amountToUnlock'] as num?)?.toDouble() ?? 0,
      message: json['message'] as String? ?? '',
    );

Map<String, dynamic> _$FirstTimeOfferTeaserInfoToJson(
        _FirstTimeOfferTeaserInfo instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'rewardType': instance.rewardType,
      'amountToUnlock': instance.amountToUnlock,
      'message': instance.message,
    };

_QuickDeliveryInfo _$QuickDeliveryInfoFromJson(Map<String, dynamic> json) =>
    _QuickDeliveryInfo(
      enabled: json['enabled'] as bool? ?? false,
      amount: (json['amount'] as num?)?.toDouble() ?? 0,
      label: json['label'] as String? ?? 'Quick delivery fee',
      etaMinutes: (json['etaMinutes'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$QuickDeliveryInfoToJson(_QuickDeliveryInfo instance) =>
    <String, dynamic>{
      'enabled': instance.enabled,
      'amount': instance.amount,
      'label': instance.label,
      'etaMinutes': instance.etaMinutes,
    };
