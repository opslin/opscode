// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tracking_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(riderLocationStream)
const riderLocationStreamProvider = RiderLocationStreamProvider._();

final class RiderLocationStreamProvider extends $FunctionalProvider<
        AsyncValue<RiderLocationEntity>,
        RiderLocationEntity,
        Stream<RiderLocationEntity>>
    with
        $FutureModifier<RiderLocationEntity>,
        $StreamProvider<RiderLocationEntity> {
  const RiderLocationStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'riderLocationStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$riderLocationStreamHash();

  @$internal
  @override
  $StreamProviderElement<RiderLocationEntity> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<RiderLocationEntity> create(Ref ref) {
    return riderLocationStream(ref);
  }
}

String _$riderLocationStreamHash() =>
    r'374f2cf0195ca68a4418862708b9236a8a4b91b8';

@ProviderFor(notificationStream)
const notificationStreamProvider = NotificationStreamProvider._();

final class NotificationStreamProvider extends $FunctionalProvider<
        AsyncValue<NotificationEvent>,
        NotificationEvent,
        Stream<NotificationEvent>>
    with
        $FutureModifier<NotificationEvent>,
        $StreamProvider<NotificationEvent> {
  const NotificationStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'notificationStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$notificationStreamHash();

  @$internal
  @override
  $StreamProviderElement<NotificationEvent> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<NotificationEvent> create(Ref ref) {
    return notificationStream(ref);
  }
}

String _$notificationStreamHash() =>
    r'96626223e54cfb8afa8d60605a784ada3372de8d';

@ProviderFor(unreadNotificationCount)
const unreadNotificationCountProvider = UnreadNotificationCountProvider._();

final class UnreadNotificationCountProvider
    extends $FunctionalProvider<int, int, int> with $Provider<int> {
  const UnreadNotificationCountProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'unreadNotificationCountProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$unreadNotificationCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadNotificationCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadNotificationCountHash() =>
    r'18834563e7faf888ae2522447078bf7542eada31';
