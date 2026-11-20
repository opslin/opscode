import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/auctions/data/auction_repository.dart';
import 'package:dealker_app/features/auctions/data/auction_view.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_gate_controller.dart';

final Provider<AuctionRepository> auctionRepositoryProvider =
    Provider<AuctionRepository>(
        (Ref ref) => AuctionRepository(ref.watch(dioClientProvider)));

enum LoadFailure { none, offline, server }

/// Everything the Auctions page shows. Filters and the tab live here so the whole screen is one state.
class BrowseState {
  const BrowseState({
    this.tab = AuctionTab.live,
    this.sort = AuctionSort.ending,
    this.brand,
    this.categoryId,
    this.categories = const <({String id, String name, int count})>[],
    this.min,
    this.max,
    this.registrationOpen = false,
    this.query = '',
    this.items = const <AuctionView>[],
    this.counts = const AuctionCounts(),
    this.brands = const <({String name, int count})>[],
    this.total = 0,
    this.page = 1,
    this.loading = true,
    this.loadingMore = false,
    this.failure = LoadFailure.none,
    this.endingSoon = const <AuctionView>[],
    this.bids = const <AuctionView>[],
    this.bidsLoaded = false,
    this.bidsFailure = LoadFailure.none,
  });

  final AuctionTab tab;
  final AuctionSort sort;
  final String? brand;
  final String? categoryId;
  final List<({String id, String name, int count})> categories;
  final num? min;
  final num? max;
  final bool registrationOpen;
  final String query;
  final List<AuctionView> items;
  final AuctionCounts counts;
  final List<({String name, int count})> brands;
  final int total;
  final int page;
  final bool loading;
  final bool loadingMore;
  final LoadFailure failure;

  /// The strip above the grid: live auctions closest to ending.
  final List<AuctionView> endingSoon;

  /// My Bids tab.
  final List<AuctionView> bids;
  final bool bidsLoaded;
  final LoadFailure bidsFailure;

  bool get hasFilters =>
      brand != null ||
      categoryId != null ||
      min != null ||
      max != null ||
      registrationOpen ||
      query.isNotEmpty;
  bool get hasMore => items.length < total;

  /// Joined auctions that are running or about to start.
  int get activeBidCount =>
      bids.where((AuctionView a) => a.isLive || a.isUpcoming).length;

  BrowseState copyWith({
    AuctionTab? tab,
    AuctionSort? sort,
    Object? brand = _keep,
    Object? categoryId = _keep,
    List<({String id, String name, int count})>? categories,
    Object? min = _keep,
    Object? max = _keep,
    bool? registrationOpen,
    String? query,
    List<AuctionView>? items,
    AuctionCounts? counts,
    List<({String name, int count})>? brands,
    int? total,
    int? page,
    bool? loading,
    bool? loadingMore,
    LoadFailure? failure,
    List<AuctionView>? endingSoon,
    List<AuctionView>? bids,
    bool? bidsLoaded,
    LoadFailure? bidsFailure,
  }) =>
      BrowseState(
        tab: tab ?? this.tab,
        sort: sort ?? this.sort,
        brand: identical(brand, _keep) ? this.brand : brand as String?,
        categoryId: identical(categoryId, _keep)
            ? this.categoryId
            : categoryId as String?,
        categories: categories ?? this.categories,
        min: identical(min, _keep) ? this.min : min as num?,
        max: identical(max, _keep) ? this.max : max as num?,
        registrationOpen: registrationOpen ?? this.registrationOpen,
        query: query ?? this.query,
        items: items ?? this.items,
        counts: counts ?? this.counts,
        brands: brands ?? this.brands,
        total: total ?? this.total,
        page: page ?? this.page,
        loading: loading ?? this.loading,
        loadingMore: loadingMore ?? this.loadingMore,
        failure: failure ?? this.failure,
        endingSoon: endingSoon ?? this.endingSoon,
        bids: bids ?? this.bids,
        bidsLoaded: bidsLoaded ?? this.bidsLoaded,
        bidsFailure: bidsFailure ?? this.bidsFailure,
      );
}

const Object _keep = Object();

LoadFailure _failureOf(Object e) {
  if (e is DioException &&
      (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout)) {
    return LoadFailure.offline;
  }
  return LoadFailure.server;
}

class AuctionBrowse extends Notifier<BrowseState> {
  int _gen = 0;

  AuctionRepository get _repo => ref.read(auctionRepositoryProvider);

  @override
  BrowseState build() {
    Future<void>.microtask(refresh);
    return const BrowseState();
  }

  bool get _signedIn => ref.read(authGateControllerProvider).isAuthenticated;

  Future<void> setTab(AuctionTab t) async {
    if (t == state.tab) return;
    state = state.copyWith(
        tab: t,
        items: const <AuctionView>[],
        total: 0,
        page: 1,
        failure: LoadFailure.none,
        brand: null,
        categoryId: null);
    await refresh();
  }

  Future<void> apply({
    AuctionSort? sort,
    Object? brand = _keep,
    Object? categoryId = _keep,
    Object? min = _keep,
    Object? max = _keep,
    bool? registrationOpen,
    String? query,
  }) async {
    state = state.copyWith(
        sort: sort,
        brand: brand,
        categoryId: categoryId,
        min: min,
        max: max,
        registrationOpen: registrationOpen,
        query: query,
        page: 1);
    await refresh();
  }

  Future<void> clearFilters() => apply(
      brand: null,
      categoryId: null,
      min: null,
      max: null,
      registrationOpen: false);

  Future<void> refresh() async {
    final int gen = ++_gen;
    if (state.tab == AuctionTab.myBids) return _loadBids(gen);
    state = state.copyWith(loading: true, failure: LoadFailure.none, page: 1);
    try {
      final AuctionPage p = await _page(1);
      if (gen != _gen) return;
      List<AuctionView> soon = state.endingSoon;
      if (state.tab == AuctionTab.live) {
        soon = state.hasFilters || state.sort != AuctionSort.ending
            ? await _soon()
            : p.items.take(8).toList();
        if (gen != _gen) return;
      }
      state = state.copyWith(
        items: p.items,
        total: p.total,
        counts: p.counts,
        brands: p.brands,
        categories: p.categories.isNotEmpty || state.categoryId == null
            ? p.categories
            : null,
        loading: false,
        endingSoon: soon,
      );
    } catch (e) {
      if (gen != _gen) return;
      state = state.copyWith(loading: false, failure: _failureOf(e));
    }
    // My Bids badge + the bottom bar need the user's own list even on the other tabs.
    if (_signedIn && !state.bidsLoaded) unawaited(_quietBids());
  }

  /// Quiet refresh (no skeleton): keeps what is on screen, swaps in fresh prices and times.
  Future<void> softRefresh() async {
    if (state.tab == AuctionTab.myBids) return;
    final int gen = _gen;
    try {
      final AuctionPage p = await _page(1);
      if (gen != _gen) return;
      state = state.copyWith(
          items: p.items,
          total: p.total,
          counts: p.counts,
          brands: p.brands,
          page: 1,
          failure: LoadFailure.none,
          endingSoon: state.tab == AuctionTab.live &&
                  !state.hasFilters &&
                  state.sort == AuctionSort.ending
              ? p.items.take(8).toList()
              : null);
    } catch (_) {}
    if (_signedIn) unawaited(_quietBids());
  }

  Future<List<AuctionView>> _soon() async =>
      (await _repo.browse(tab: AuctionTab.live, limit: 8)).items;

  Future<AuctionPage> _page(int page) => _repo.browse(
        tab: switch (state.tab) {
          AuctionTab.myBids => AuctionTab.live,
          final AuctionTab t => t,
        },
        q: state.query,
        sort: state.sort,
        brand: state.brand,
        categoryId: state.categoryId,
        min: state.min,
        max: state.max,
        registrationOpen: state.registrationOpen,
        page: page,
      );

  Future<void> loadMore() async {
    if (state.loading ||
        state.loadingMore ||
        !state.hasMore ||
        state.tab == AuctionTab.myBids) return;
    final int gen = _gen;
    state = state.copyWith(loadingMore: true);
    try {
      final AuctionPage p = await _page(state.page + 1);
      if (gen != _gen) return;
      state = state.copyWith(
          items: <AuctionView>[...state.items, ...p.items],
          page: state.page + 1,
          loadingMore: false,
          total: p.total);
    } catch (_) {
      if (gen == _gen) state = state.copyWith(loadingMore: false);
    }
  }

  Future<void> _loadBids(int gen) async {
    if (!_signedIn) {
      state = state.copyWith(
          loading: false,
          bids: const <AuctionView>[],
          bidsLoaded: true,
          bidsFailure: LoadFailure.none);
      return;
    }
    state = state.copyWith(loading: true, bidsFailure: LoadFailure.none);
    try {
      final List<AuctionView> list = await _repo.myBids();
      if (gen != _gen) return;
      state = state.copyWith(bids: list, bidsLoaded: true, loading: false);
    } catch (e) {
      if (gen != _gen) return;
      state = state.copyWith(loading: false, bidsFailure: _failureOf(e));
    }
  }

  Future<void> _quietBids() async {
    try {
      final List<AuctionView> list = await _repo.myBids();
      state = state.copyWith(bids: list, bidsLoaded: true);
    } catch (_) {}
  }

  /// Heart / Remind me. Optimistic; rolls back if the server refuses.
  Future<bool> toggleWatch(String id) async {
    AuctionView? find(List<AuctionView> l) {
      for (final AuctionView a in l) {
        if (a.id == id) return a;
      }
      return null;
    }

    final AuctionView? cur =
        find(state.items) ?? find(state.endingSoon) ?? find(state.bids);
    if (cur == null) return false;
    final bool on = !cur.watching;
    _setWatch(id, on);
    try {
      await _repo.watch(id, on: on);
      return true;
    } catch (_) {
      _setWatch(id, !on);
      return false;
    }
  }

  void _setWatch(String id, bool on) {
    List<AuctionView> patch(List<AuctionView> l) => <AuctionView>[
          for (final AuctionView a in l)
            if (a.id == id)
              AuctionView(
                  <String, dynamic>{...a.raw, 'watching': on}, a.clockOffset)
            else
              a,
        ];
    state = state.copyWith(
      items: patch(state.items),
      endingSoon: patch(state.endingSoon),
      bids: patch(state.bids),
      counts: state.counts.copyWith(
          watching: (state.counts.watching + (on ? 1 : -1)).clamp(0, 9999)),
    );
  }
}

void unawaited(Future<void> f) {}

final NotifierProvider<AuctionBrowse, BrowseState> auctionBrowseProvider =
    NotifierProvider<AuctionBrowse, BrowseState>(AuctionBrowse.new);

final FutureProvider<List<AuctionView>> auctionWatchingProvider =
    FutureProvider.autoDispose<List<AuctionView>>(
        (Ref ref) => ref.watch(auctionRepositoryProvider).watching());
