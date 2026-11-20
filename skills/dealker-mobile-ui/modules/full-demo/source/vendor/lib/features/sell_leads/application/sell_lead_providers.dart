import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/core/realtime/live_service.dart';

import 'package:dealker_vendor/features/sell_leads/data/sell_lead_models.dart';
import 'package:dealker_vendor/features/sell_leads/data/sell_lead_repository.dart';

final sellLeadRepositoryProvider = Provider<SellLeadRepository>(
    (ref) => SellLeadRepository(ref.watch(dioProvider)));

/// Family key = server tab (`pending` | `progress`).
final sellLeadsProvider = FutureProvider.autoDispose
    .family<SellLeadPage, String>(
        (ref, tab) {
      ref.watch(liveTickProvider);
      return ref.watch(sellLeadRepositoryProvider).list(tab: tab);
    });

final sellLeadProvider = FutureProvider.autoDispose.family<SellLead, String>(
    (ref, id) {
  ref.watch(liveTickProvider);
  return ref.watch(sellLeadRepositoryProvider).get(id);
});
