import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/campaigns/application/campaign_draft.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_models.dart';
import 'package:dealker_vendor/features/campaigns/data/campaign_repository.dart';
import 'package:dealker_vendor/features/campaigns/data/demo_campaign_repository.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';

final campaignRepositoryProvider = Provider<CampaignRepository>(
  (ref) => demoHome
      ? _demoRepo ??= DemoCampaignRepository()
      : CampaignRepository(ref.watch(dioProvider)),
);
DemoCampaignRepository? _demoRepo; // keeps demo data alive across rebuilds

enum CampaignTab {
  all('All', null),
  active('Active', [CampaignStatus.active]),
  review('In review',
      [CampaignStatus.pending, CampaignStatus.draft, CampaignStatus.rejected]),
  paused('Paused', [CampaignStatus.paused, CampaignStatus.suspended]),
  ended('Ended', [CampaignStatus.ended]);

  const CampaignTab(this.label, this.statuses);
  final String label;
  final List<String>? statuses;

  int count(Map<String, int> counts) => statuses == null
      ? counts.values.fold(0, (a, b) => a + b)
      : statuses!.fold(0, (a, s) => a + (counts[s] ?? 0));
}

final adRulesProvider = FutureProvider.autoDispose<AdRules>(
  (ref) => ref.watch(campaignRepositoryProvider).rules(),
);

final adProductSearchProvider =
    FutureProvider.autoDispose.family<List<AdProduct>, String>(
  (ref, q) => ref.watch(campaignRepositoryProvider).products(q: q),
);

final bidEstimateProvider =
    FutureProvider.autoDispose.family<BidEstimate, String>(
  (ref, kw) => ref.watch(campaignRepositoryProvider).estimate(kw),
);

final campaignsProvider =
    FutureProvider.autoDispose.family<CampaignList, CampaignTab>(
  (ref, tab) =>
      ref.watch(campaignRepositoryProvider).list(statuses: tab.statuses),
);

final adsOverviewProvider = FutureProvider.autoDispose<AdsOverview>(
  (ref) => ref.watch(campaignRepositoryProvider).overview(),
);

final campaignDetailProvider =
    FutureProvider.autoDispose.family<CampaignDetail, String>(
  (ref, id) => ref.watch(campaignRepositoryProvider).detail(id),
);

final campaignReportProvider =
    FutureProvider.autoDispose.family<CampaignReport, String>(
  (ref, id) => ref.watch(campaignRepositoryProvider).report(id),
);

final adWalletProvider = FutureProvider.autoDispose<AdWallet>(
  (ref) => ref.watch(campaignRepositoryProvider).wallet(),
);

final walletStatementProvider = FutureProvider.autoDispose<WalletStatement>(
  (ref) => ref.watch(campaignRepositoryProvider).statement(),
);

final campaignDraftProvider =
    NotifierProvider.autoDispose<CampaignDraftNotifier, CampaignDraft>(
        CampaignDraftNotifier.new);

/// Refresh everything that shows the vendor's campaigns (and the home block).
void refreshCampaigns(WidgetRef ref, {String? id}) {
  ref
    ..invalidate(campaignsProvider)
    ..invalidate(adsOverviewProvider)
    ..invalidate(adWalletProvider)
    ..invalidate(activeCampaignsProvider);
  if (id != null) {
    ref
      ..invalidate(campaignDetailProvider(id))
      ..invalidate(campaignReportProvider(id));
  }
}
