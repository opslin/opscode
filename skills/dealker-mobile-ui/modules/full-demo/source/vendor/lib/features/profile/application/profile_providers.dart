import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';
import 'package:dealker_vendor/features/profile/data/demo_profile_repository.dart';
import 'package:dealker_vendor/features/profile/data/profile_models.dart';
import 'package:dealker_vendor/features/profile/data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => demoHome
      ? DemoProfileRepository()
      : ProfileRepository(ref.watch(dioProvider)),
);

/// May fail for accounts without `vendors.view`; the page then falls back to
/// the session's display name and hides the "complete profile" banner.
final vendorInfoProvider = FutureProvider.autoDispose<VendorProfileInfo>((ref) {
  final id = ref.watch(authControllerProvider).session?.vendorId;
  if (id == null) throw StateError('No vendor linked');
  return ref.watch(profileRepositoryProvider).vendor(id);
});

final membershipProvider = FutureProvider.autoDispose<Membership>(
  (ref) => ref.watch(profileRepositoryProvider).membership(),
);

final listingCountsProvider = FutureProvider.autoDispose<ListingCounts>(
  (ref) => ref.watch(profileRepositoryProvider).listingCounts(),
);

void refreshProfile(WidgetRef ref) {
  ref
    ..invalidate(vendorInfoProvider)
    ..invalidate(membershipProvider)
    ..invalidate(listingCountsProvider)
    ..invalidate(allOrdersProvider)
    ..invalidate(newOrdersProvider)
    ..invalidate(walletSummaryProvider);
}
