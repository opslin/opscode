import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/core/realtime/live_service.dart';

import 'package:dealker_vendor/features/repairs/data/repair_models.dart';
import 'package:dealker_vendor/features/repairs/data/repairs_repository.dart';

final repairsRepositoryProvider = Provider<RepairsRepository>(
    (ref) => RepairsRepository(ref.watch(dioProvider)));

/// Inbox tabs: all = new + quoted ("Pending"), rejected = requests this shop passed on.
final incomingProvider =
    FutureProvider.autoDispose.family<IncomingPage, String>(
  (ref, tab) {
    ref.watch(liveTickProvider);
    return ref.watch(repairsRepositoryProvider).incoming(tab);
  },
);

final incomingDetailProvider =
    FutureProvider.autoDispose.family<IncomingRequest, String>(
  (ref, id) {
    ref.watch(liveTickProvider);
    return ref.watch(repairsRepositoryProvider).incomingDetail(id);
  },
);

final suggestedQuoteProvider =
    FutureProvider.autoDispose.family<SuggestedQuote, String>(
  (ref, id) => ref.watch(repairsRepositoryProvider).suggestedQuote(id),
);

/// Accepted tab: jobs in progress ('active') and finished ones ('completed').
final jobsProvider = FutureProvider.autoDispose.family<List<JobRow>, String>(
  (ref, tab) {
    ref.watch(liveTickProvider);
    return ref.watch(repairsRepositoryProvider).jobs(tab);
  },
);

final jobProvider = FutureProvider.autoDispose.family<RepairJob, String>(
  (ref, id) {
    ref.watch(liveTickProvider);
    return ref.watch(repairsRepositoryProvider).job(id);
  },
);

final servicesProvider = FutureProvider.autoDispose<List<ServiceRow>>(
    (ref) => ref.watch(repairsRepositoryProvider).services());

final repairProfileProvider =
    FutureProvider.autoDispose<({bool accepting, int activeServices})>(
        (ref) => ref.watch(repairsRepositoryProvider).profile());

final catalogBrandsProvider = FutureProvider.autoDispose<List<CatalogBrand>>(
    (ref) => ref.watch(repairsRepositoryProvider).brands());

final catalogModelsProvider =
    FutureProvider.autoDispose.family<List<CatalogModel>, String>(
  (ref, brand) => ref.watch(repairsRepositoryProvider).models(brand),
);

final issueOptionsProvider =
    FutureProvider.autoDispose<List<RepairIssueOption>>(
        (ref) => ref.watch(repairsRepositoryProvider).issueOptions());

/// Phone picture for "Apple iPhone 14" from the shared device catalogue (real image, may be null).
final deviceImageProvider = FutureProvider.autoDispose
    .family<String?, ({String brand, String model})>((ref, d) async {
  final list = await ref.watch(catalogModelsProvider(d.brand).future);
  for (final m in list) {
    final n = m.name.toLowerCase(), want = d.model.toLowerCase().trim();
    if (n == want ||
        n == '${d.brand} $want'.toLowerCase().trim() ||
        n.endsWith(' $want')) return m.imageUrl;
  }
  return null;
});

/// Drop everything the inbox / job screens cache after a write.
void refreshRepairs(WidgetRef ref, {String? id}) {
  ref.invalidate(incomingProvider);
  ref.invalidate(jobsProvider);
  ref.invalidate(servicesProvider);
  if (id != null) {
    ref.invalidate(incomingDetailProvider(id));
    ref.invalidate(jobProvider(id));
  }
}
