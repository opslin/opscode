import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/deals/data/deal_models.dart';
import 'package:dealker_vendor/features/deals/data/deal_repository.dart';

final dealRepositoryProvider =
    Provider<DealRepository>((ref) => DealRepository(ref.watch(dioProvider)));

final openDealsProvider = FutureProvider.autoDispose<List<OpenDeal>>(
    (ref) => ref.watch(dealRepositoryProvider).list());

final openDealProvider = FutureProvider.autoDispose.family<OpenDealDetail, String>(
    (ref, id) => ref.watch(dealRepositoryProvider).detail(id));

final dealListingsProvider = FutureProvider.autoDispose.family<List<DealListing>, String>(
    (ref, id) => ref.watch(dealRepositoryProvider).listings(id));
