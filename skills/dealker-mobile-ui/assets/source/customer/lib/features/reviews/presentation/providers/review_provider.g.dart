// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'review_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(reviewEligibility)
const reviewEligibilityProvider = ReviewEligibilityFamily._();

final class ReviewEligibilityProvider extends $FunctionalProvider<
        AsyncValue<ReviewEligibilityEntity>,
        ReviewEligibilityEntity,
        FutureOr<ReviewEligibilityEntity>>
    with
        $FutureModifier<ReviewEligibilityEntity>,
        $FutureProvider<ReviewEligibilityEntity> {
  const ReviewEligibilityProvider._(
      {required ReviewEligibilityFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'reviewEligibilityProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$reviewEligibilityHash();

  @override
  String toString() {
    return r'reviewEligibilityProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ReviewEligibilityEntity> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ReviewEligibilityEntity> create(Ref ref) {
    final argument = this.argument as String;
    return reviewEligibility(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ReviewEligibilityProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$reviewEligibilityHash() => r'1ba1c643eb839d4338b1a992269c0c3dc7caa287';

final class ReviewEligibilityFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ReviewEligibilityEntity>, String> {
  const ReviewEligibilityFamily._()
      : super(
          retry: null,
          name: r'reviewEligibilityProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  ReviewEligibilityProvider call(
    String productId,
  ) =>
      ReviewEligibilityProvider._(argument: productId, from: this);

  @override
  String toString() => r'reviewEligibilityProvider';
}

@ProviderFor(orderReviews)
const orderReviewsProvider = OrderReviewsFamily._();

final class OrderReviewsProvider extends $FunctionalProvider<
        AsyncValue<
            Map<
                String,
                ({
                  String? comment,
                  int rating,
                })>>,
        Map<
            String,
            ({
              String? comment,
              int rating,
            })>,
        FutureOr<
            Map<
                String,
                ({
                  String? comment,
                  int rating,
                })>>>
    with
        $FutureModifier<
            Map<
                String,
                ({
                  String? comment,
                  int rating,
                })>>,
        $FutureProvider<
            Map<
                String,
                ({
                  String? comment,
                  int rating,
                })>> {
  const OrderReviewsProvider._(
      {required OrderReviewsFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'orderReviewsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$orderReviewsHash();

  @override
  String toString() {
    return r'orderReviewsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<
      Map<
          String,
          ({
            String? comment,
            int rating,
          })>> $createElement($ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<
      Map<
          String,
          ({
            String? comment,
            int rating,
          })>> create(Ref ref) {
    final argument = this.argument as String;
    return orderReviews(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is OrderReviewsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$orderReviewsHash() => r'58dd8c7bfd40d1a19626d7ecce3c240b63a63c25';

final class OrderReviewsFamily extends $Family
    with
        $FunctionalFamilyOverride<
            FutureOr<
                Map<
                    String,
                    ({
                      String? comment,
                      int rating,
                    })>>,
            String> {
  const OrderReviewsFamily._()
      : super(
          retry: null,
          name: r'orderReviewsProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  OrderReviewsProvider call(
    String orderId,
  ) =>
      OrderReviewsProvider._(argument: orderId, from: this);

  @override
  String toString() => r'orderReviewsProvider';
}

@ProviderFor(ReviewNotifier)
const reviewProvider = ReviewNotifierProvider._();

final class ReviewNotifierProvider
    extends $NotifierProvider<ReviewNotifier, AsyncValue<void>> {
  const ReviewNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'reviewProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$reviewNotifierHash();

  @$internal
  @override
  ReviewNotifier create() => ReviewNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$reviewNotifierHash() => r'aa4605082ffb948ef6f8f0aaedbfbfe3e84a7f82';

abstract class _$ReviewNotifier extends $Notifier<AsyncValue<void>> {
  AsyncValue<void> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<void>, AsyncValue<void>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<void>, AsyncValue<void>>,
        AsyncValue<void>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
