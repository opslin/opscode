import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/payouts/data/payout_models.dart';
import 'package:dealker_vendor/features/payouts/data/payout_repository.dart';

final payoutRepositoryProvider = Provider<PayoutRepository>(
    (ref) => PayoutRepository(ref.watch(dioProvider)));

/// Family key = status filter ('' = all, otherwise PAID / PROCESSING / …).
final payoutsProvider = FutureProvider.autoDispose.family<PayoutPage, String>(
    (ref, status) => ref.watch(payoutRepositoryProvider).list(status: status));
