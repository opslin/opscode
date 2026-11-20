import 'package:dio/dio.dart';

import 'package:dealker_vendor/features/profile/data/profile_models.dart';
import 'package:dealker_vendor/features/profile/data/profile_repository.dart';

/// DEMO ONLY (`.env` DEMO_HOME=true) — sample profile so the page can be reviewed
/// without a vendor login. Delete with the switch in `profile_providers.dart`.
class DemoProfileRepository extends ProfileRepository {
  DemoProfileRepository() : super(Dio());

  @override
  Future<VendorProfileInfo> vendor(String vendorId) async =>
      const VendorProfileInfo(
          name: 'DMobileMart', status: 'VERIFIED', profileComplete: false);

  @override
  Future<Membership> membership() async => const Membership(
      tier: 'PREMIUM',
      planName: 'Gold',
      daysLeft: 41,
      listingLimit: 100,
      listingsUsed: 7);

  @override
  Future<ListingCounts> listingCounts() async =>
      const ListingCounts(live: 32, pending: 5);
}
