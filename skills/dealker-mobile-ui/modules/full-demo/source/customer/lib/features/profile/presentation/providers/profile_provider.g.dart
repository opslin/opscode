// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProfileNotifier)
const profileProvider = ProfileNotifierProvider._();

final class ProfileNotifierProvider
    extends $AsyncNotifierProvider<ProfileNotifier, ProfileData> {
  const ProfileNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'profileProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$profileNotifierHash();

  @$internal
  @override
  ProfileNotifier create() => ProfileNotifier();
}

String _$profileNotifierHash() => r'f1c397142b0523953ad7f5f57e6ffd04a3854e6b';

abstract class _$ProfileNotifier extends $AsyncNotifier<ProfileData> {
  FutureOr<ProfileData> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<AsyncValue<ProfileData>, ProfileData>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<ProfileData>, ProfileData>,
        AsyncValue<ProfileData>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

@ProviderFor(userStats)
const userStatsProvider = UserStatsProvider._();

final class UserStatsProvider extends $FunctionalProvider<
        AsyncValue<UserStatsEntity>, UserStatsEntity, FutureOr<UserStatsEntity>>
    with $FutureModifier<UserStatsEntity>, $FutureProvider<UserStatsEntity> {
  const UserStatsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'userStatsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$userStatsHash();

  @$internal
  @override
  $FutureProviderElement<UserStatsEntity> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<UserStatsEntity> create(Ref ref) {
    return userStats(ref);
  }
}

String _$userStatsHash() => r'5a459a113082e8b3612dc690ded6723214fc2299';
