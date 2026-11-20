// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notification_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(socketNotificationStream)
const socketNotificationStreamProvider = SocketNotificationStreamProvider._();

final class SocketNotificationStreamProvider extends $FunctionalProvider<
        AsyncValue<NotificationEvent>,
        NotificationEvent,
        Stream<NotificationEvent>>
    with
        $FutureModifier<NotificationEvent>,
        $StreamProvider<NotificationEvent> {
  const SocketNotificationStreamProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'socketNotificationStreamProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$socketNotificationStreamHash();

  @$internal
  @override
  $StreamProviderElement<NotificationEvent> $createElement(
          $ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<NotificationEvent> create(Ref ref) {
    return socketNotificationStream(ref);
  }
}

String _$socketNotificationStreamHash() =>
    r'ddc5ddc22514f506dc9909c54cb3caf4aef88727';

@ProviderFor(NotificationNotifier)
const notificationProvider = NotificationNotifierProvider._();

final class NotificationNotifierProvider
    extends $AsyncNotifierProvider<NotificationNotifier, NotificationsState> {
  const NotificationNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'notificationProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$notificationNotifierHash();

  @$internal
  @override
  NotificationNotifier create() => NotificationNotifier();
}

String _$notificationNotifierHash() =>
    r'90fe867a50722f8122ef086556580c4030e6ba54';

abstract class _$NotificationNotifier
    extends $AsyncNotifier<NotificationsState> {
  FutureOr<NotificationsState> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<NotificationsState>, NotificationsState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<NotificationsState>, NotificationsState>,
        AsyncValue<NotificationsState>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(NotificationPreferences)
const notificationPreferencesProvider = NotificationPreferencesProvider._();

final class NotificationPreferencesProvider extends $AsyncNotifierProvider<
    NotificationPreferences, NotificationPreferenceEntity> {
  const NotificationPreferencesProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'notificationPreferencesProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$notificationPreferencesHash();

  @$internal
  @override
  NotificationPreferences create() => NotificationPreferences();
}

String _$notificationPreferencesHash() =>
    r'9b5765ff328dc30c056a0955188572f4963d4f12';

abstract class _$NotificationPreferences
    extends $AsyncNotifier<NotificationPreferenceEntity> {
  FutureOr<NotificationPreferenceEntity> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<NotificationPreferenceEntity>,
        NotificationPreferenceEntity>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<NotificationPreferenceEntity>,
            NotificationPreferenceEntity>,
        AsyncValue<NotificationPreferenceEntity>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
