// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'unread_count_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(unreadCount)
const unreadCountProvider = UnreadCountProvider._();

final class UnreadCountProvider extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  const UnreadCountProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'unreadCountProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$unreadCountHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return unreadCount(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$unreadCountHash() => r'2b5d877517208fd38069c10691a04ec2f2045146';
