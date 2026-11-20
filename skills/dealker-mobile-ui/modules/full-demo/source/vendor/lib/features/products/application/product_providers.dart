import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/errors/failure.dart';
import 'package:dealker_vendor/core/network/dio_provider.dart';
import 'package:dealker_vendor/features/home/application/home_providers.dart';
import 'package:dealker_vendor/features/products/application/product_draft.dart';
import 'package:dealker_vendor/features/products/data/demo_product_repository.dart';
import 'package:dealker_vendor/features/products/data/product_catalog.dart';
import 'package:dealker_vendor/features/products/data/product_models.dart';
import 'package:dealker_vendor/features/products/data/product_repository.dart';
import 'package:dealker_vendor/features/profile/application/profile_providers.dart';

final productRepositoryProvider = Provider<ProductRepository>(
  (ref) => demoHome
      ? _demoRepo ??= DemoProductRepository()
      : ProductRepository(ref.watch(dioProvider)),
);
DemoProductRepository? _demoRepo; // keeps demo data alive across rebuilds

enum ProductTab {
  all('All', null),
  pending('Pending', 'PENDING'),
  live('Live', 'APPROVED'),
  rejected('Rejected', 'REJECTED');

  const ProductTab(this.label, this.approval);
  final String label;
  final String? approval;

  int count(ListingStats s) => switch (this) {
        ProductTab.all => s.total,
        ProductTab.pending => s.pending,
        ProductTab.live => s.approved,
        ProductTab.rejected => s.rejected,
      };
}

final listingStatsProvider = FutureProvider.autoDispose<ListingStats>(
  (ref) => ref.watch(productRepositoryProvider).stats(),
);

final productSearchQueryProvider =
    NotifierProvider.autoDispose<_SearchQuery, String>(_SearchQuery.new);

class _SearchQuery extends Notifier<String> {
  @override
  String build() => '';
  void set(String v) => state = v;
}

final myProductsProvider =
    FutureProvider.autoDispose.family<ListingPage, ProductTab>((ref, tab) {
  final q = ref.watch(productSearchQueryProvider);
  return ref
      .watch(productRepositoryProvider)
      .list(approval: tab.approval, search: q);
});

final productDetailProvider =
    FutureProvider.autoDispose.family<ListingDetail, String>(
  (ref, id) => ref.watch(productRepositoryProvider).detail(id),
);

final categoriesProvider = FutureProvider<List<CategoryOption>>(
  (ref) => ref.watch(productRepositoryProvider).categories(),
);

/// Everything the type picker offers: the four built-ins plus every other
/// top-level category (including types vendors added).
final productTypesProvider = Provider<List<ProductType>>((ref) {
  final cats = ref.watch(categoriesProvider).asData?.value ??
      const <CategoryOption>[];
  return productTypesFrom(cats);
});

final addDraftProvider =
    NotifierProvider.autoDispose<ProductDraftNotifier, ProductDraft>(
        ProductDraftNotifier.new);

/// Reload everything that lists the vendor's products (and the profile counts).
void refreshProducts(WidgetRef ref) {
  ref
    ..invalidate(myProductsProvider)
    ..invalidate(listingStatsProvider)
    ..invalidate(listingCountsProvider)
    ..invalidate(membershipProvider);
}

// ── can this vendor list right now? ─────────────────────────────────────

enum ReadinessIssue { kycPending, suspended, limitReached, nearLimit }

class Readiness {
  const Readiness(this.issue, this.message, {this.blocks = false});
  final ReadinessIssue issue;
  final String message;
  final bool blocks;
}

/// Pre-flight check shown before the vendor starts typing, so a blocked
/// vendor hears why up front instead of after 8 steps. A failed lookup never
/// blocks — the server still enforces every rule on submit.
final readinessProvider = FutureProvider.autoDispose<Readiness?>((ref) async {
  String? status;
  try {
    status = (await ref.watch(vendorInfoProvider.future)).status;
  } catch (_) {}
  if (status != null) {
    switch (status) {
      case 'SUSPENDED':
      case 'DEACTIVATED':
      case 'REJECTED':
        return const Readiness(ReadinessIssue.suspended,
            'Your vendor account is not active, so new products can’t be listed. Contact Dealkr support for help.',
            blocks: true);
      case 'VERIFIED':
      case 'ACTIVE':
        break;
      case 'CORRECTION_REQUIRED':
        return const Readiness(ReadinessIssue.kycPending,
            'Your KYC needs corrections. Update your documents to start listing products.',
            blocks: true);
      default:
        return const Readiness(ReadinessIssue.kycPending,
            'Complete your KYC to start listing products. Your store goes live once it is verified.',
            blocks: true);
    }
  }
  try {
    final m = await ref.watch(membershipProvider.future);
    final lim = m.listingLimit;
    final used = m.listingsUsed;
    if (lim != null && used != null) {
      if (used >= lim) {
        return Readiness(ReadinessIssue.limitReached,
            'Your ${m.planName} plan allows $lim listings and you have $used. Upgrade your plan to add more.',
            blocks: true);
      }
      if (lim - used <= 3) {
        return Readiness(ReadinessIssue.nearLimit,
            '$used of $lim listings used on your ${m.planName} plan.');
      }
    }
  } catch (_) {}
  return null;
});

/// Turns a server failure into something a vendor can act on.
({String title, String message}) explainFailure(Object e) {
  final msg =
      e is Failure ? e.message : 'Something went wrong. Please try again.';
  final low = msg.toLowerCase();
  if (low.contains('kyc') || low.contains('store is not active')) {
    return (
      title: 'Complete your KYC first',
      message:
          'Your store isn’t active yet, so products can’t be listed. Finish KYC verification and try again.'
    );
  }
  if (low.contains('plan allows') ||
      low.contains('upgrade your subscription')) {
    return (title: 'Listing limit reached', message: msg);
  }
  if (e is AuthFailure) {
    return (
      title: 'Not allowed',
      message:
          'This account can’t list products. Sign in with your vendor account.'
    );
  }
  if (e is NetworkFailure) {
    return (title: 'No connection', message: msg);
  }
  return (title: 'Couldn’t submit', message: msg);
}
