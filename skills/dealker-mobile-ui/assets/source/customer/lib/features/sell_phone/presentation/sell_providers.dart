import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/exchange/data/exchange_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_models.dart';
import 'package:dealker_app/features/sell_phone/data/sell_repository.dart';

final Provider<SellRepository> sellRepositoryProvider =
    Provider<SellRepository>(
  (Ref ref) => SellRepository(ref.watch(dioClientProvider)),
);

final FutureProvider<SellConfig> sellConfigProvider =
    FutureProvider.autoDispose<SellConfig>(
  (Ref ref) => ref.watch(sellRepositoryProvider).config(),
);

final FutureProvider<List<ExchangeModel>> sellCatalogProvider =
    FutureProvider.autoDispose<List<ExchangeModel>>(
  (Ref ref) => ref.watch(sellRepositoryProvider).catalog(),
);

final FutureProvider<List<SellListItem>> mySalesProvider =
    FutureProvider.autoDispose<List<SellListItem>>(
  (Ref ref) => ref.watch(sellRepositoryProvider).mine(),
);

final sellJourneyProvider =
    FutureProvider.autoDispose.family<SellJourney, String>(
  (Ref ref, String id) => ref.watch(sellRepositoryProvider).journey(id),
);

final sellOffersProvider =
    FutureProvider.autoDispose.family<SellOffers, String>(
  (Ref ref, String id) => ref.watch(sellRepositoryProvider).offers(id),
);

final sellThreadsProvider =
    FutureProvider.autoDispose.family<List<SellThreadSummary>, String>(
  (Ref ref, String id) => ref.watch(sellRepositoryProvider).threads(id),
);
