import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/auth/application/auth_controller.dart';
import 'package:dealker_vendor/features/business_profile/data/business_models.dart';
import 'package:dealker_vendor/features/business_profile/data/business_repository.dart';
import 'package:dealker_vendor/features/profile/application/profile_providers.dart';

final businessRepositoryProvider = Provider<BusinessRepository>(
    (ref) => BusinessRepository(ref.watch(dioProvider)));

final businessVendorIdProvider = Provider<String?>(
    (ref) => ref.watch(authControllerProvider).session?.vendorId);

final businessProfileProvider =
    FutureProvider.autoDispose<BusinessProfile>((ref) {
  final id = ref.watch(businessVendorIdProvider);
  if (id == null) throw StateError('No vendor linked');
  return ref.watch(businessRepositoryProvider).load(id);
});

/// After a save: reload this screen and the Profile page header (name, "complete profile" banner).
void refreshBusinessProfile(WidgetRef ref) => ref
  ..invalidate(businessProfileProvider)
  ..invalidate(vendorInfoProvider);
