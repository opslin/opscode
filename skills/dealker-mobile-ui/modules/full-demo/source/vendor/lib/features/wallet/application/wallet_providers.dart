import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';
import 'package:dealker_vendor/features/wallet/data/wallet_models.dart';
import 'package:dealker_vendor/features/wallet/data/wallet_repository.dart';

final walletRepositoryProvider = Provider<WalletRepository>(
    (ref) => WalletRepository(ref.watch(dioProvider)));

final vendorWalletProvider = FutureProvider.autoDispose<VendorWallet>(
    (ref) => ref.watch(walletRepositoryProvider).balances());

final walletTxnsProvider = FutureProvider.autoDispose<List<WalletTxn>>(
    (ref) => ref.watch(walletRepositoryProvider).transactions());

/// Refresh everything that shows these balances (this screen and the Home tile).
void invalidateWallet(WidgetRef ref) => ref
  ..invalidate(vendorWalletProvider)
  ..invalidate(walletTxnsProvider)
  ..invalidate(walletSummaryProvider);
