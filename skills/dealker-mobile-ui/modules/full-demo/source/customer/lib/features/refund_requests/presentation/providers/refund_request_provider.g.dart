// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'refund_request_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The latest refund request for one order — null when none exists yet.
/// Drives the order-detail screen's status card and whether "Request
/// Refund" should still be offered.

@ProviderFor(refundRequestByOrder)
const refundRequestByOrderProvider = RefundRequestByOrderFamily._();

/// The latest refund request for one order — null when none exists yet.
/// Drives the order-detail screen's status card and whether "Request
/// Refund" should still be offered.

final class RefundRequestByOrderProvider extends $FunctionalProvider<
        AsyncValue<RefundRequestStatusEntity?>,
        RefundRequestStatusEntity?,
        FutureOr<RefundRequestStatusEntity?>>
    with
        $FutureModifier<RefundRequestStatusEntity?>,
        $FutureProvider<RefundRequestStatusEntity?> {
  /// The latest refund request for one order — null when none exists yet.
  /// Drives the order-detail screen's status card and whether "Request
  /// Refund" should still be offered.
  const RefundRequestByOrderProvider._(
      {required RefundRequestByOrderFamily super.from,
      required String super.argument})
      : super(
          retry: null,
          name: r'refundRequestByOrderProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$refundRequestByOrderHash();

  @override
  String toString() {
    return r'refundRequestByOrderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RefundRequestStatusEntity?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RefundRequestStatusEntity?> create(Ref ref) {
    final argument = this.argument as String;
    return refundRequestByOrder(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is RefundRequestByOrderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$refundRequestByOrderHash() =>
    r'2367a8a23eab6c72b59fb13162314f464bffaaf6';

/// The latest refund request for one order — null when none exists yet.
/// Drives the order-detail screen's status card and whether "Request
/// Refund" should still be offered.

final class RefundRequestByOrderFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<RefundRequestStatusEntity?>,
            String> {
  const RefundRequestByOrderFamily._()
      : super(
          retry: null,
          name: r'refundRequestByOrderProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// The latest refund request for one order — null when none exists yet.
  /// Drives the order-detail screen's status card and whether "Request
  /// Refund" should still be offered.

  RefundRequestByOrderProvider call(
    String orderId,
  ) =>
      RefundRequestByOrderProvider._(argument: orderId, from: this);

  @override
  String toString() => r'refundRequestByOrderProvider';
}

@ProviderFor(RefundRequestNotifier)
const refundRequestProvider = RefundRequestNotifierProvider._();

final class RefundRequestNotifierProvider
    extends $NotifierProvider<RefundRequestNotifier, AsyncValue<void>> {
  const RefundRequestNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'refundRequestProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$refundRequestNotifierHash();

  @$internal
  @override
  RefundRequestNotifier create() => RefundRequestNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<void> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AsyncValue<void>>(value),
    );
  }
}

String _$refundRequestNotifierHash() =>
    r'022a9ac6859fefd1c14f905dd54a911948eabc27';

abstract class _$RefundRequestNotifier extends $Notifier<AsyncValue<void>> {
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
