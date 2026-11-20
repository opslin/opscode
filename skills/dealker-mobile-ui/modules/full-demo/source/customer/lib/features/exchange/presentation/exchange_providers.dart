import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/exchange/data/exchange_models.dart';
import 'package:dealker_app/features/exchange/data/exchange_repository.dart';

final Provider<ExchangeRepository> exchangeRepositoryProvider =
    Provider<ExchangeRepository>(
  (Ref ref) => ExchangeRepository(ref.watch(dioClientProvider)),
);

final FutureProvider<ExchangeSummary> exchangeSummaryProvider =
    FutureProvider<ExchangeSummary>(
  (Ref ref) => ref.watch(exchangeRepositoryProvider).summary(),
);

final FutureProvider<List<ExchangeModel>> exchangeCatalogProvider =
    FutureProvider.autoDispose<List<ExchangeModel>>(
  (Ref ref) => ref.watch(exchangeRepositoryProvider).catalog(),
);

/// Plain view of the public summary (never throws — a failed call just hides the product-page card).
class ExchangeSummaryView {
  const ExchangeSummaryView({required this.enabled, required this.maxValue});
  final bool enabled;
  final double maxValue;
}

final Provider<ExchangeSummaryView> exchangeSummaryViewProvider =
    Provider<ExchangeSummaryView>((Ref ref) {
  final ExchangeSummary? s = ref.watch(exchangeSummaryProvider).asData?.value;
  return ExchangeSummaryView(
    enabled: s?.enabled ?? false,
    maxValue: s?.maxValue ?? 0,
  );
});

/// Is exchange offered on this product? A failed call just hides the card (never throws into the UI).
final exchangeForProductProvider =
    FutureProvider.autoDispose.family<ExchangeOffer, String>(
  (Ref ref, String productId) async {
    try {
      return await ref.watch(exchangeRepositoryProvider).forProduct(productId);
    } catch (_) {
      return ExchangeOffer.none;
    }
  },
);

final exchangeOptionsProvider =
    FutureProvider.autoDispose.family<ExchangeOptions, String>(
  (Ref ref, String productId) =>
      ref.watch(exchangeRepositoryProvider).options(productId),
);
