import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:dealker_app/core/theme/search_tokens.dart';
import 'package:dealker_app/core/utils/app_toast.dart';
import 'package:dealker_app/features/cart/presentation/providers/cart_provider.dart';
import 'package:dealker_app/features/categories/domain/entities/category_entity.dart';
import 'package:dealker_app/features/categories/presentation/providers/category_provider.dart';
import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/search/domain/entities/search_result_entity.dart';
import 'package:dealker_app/features/search/domain/search_filters.dart';
import 'package:dealker_app/features/search/presentation/providers/popular_searches_provider.dart';
import 'package:dealker_app/features/search/presentation/providers/search_history_provider.dart';
import 'package:dealker_app/features/search/presentation/providers/search_provider.dart';
import 'package:dealker_app/features/search/presentation/widgets/search_entry_view.dart';
import 'package:dealker_app/features/search/presentation/widgets/search_results_view.dart';
import 'package:dealker_app/features/search/presentation/widgets/search_sheets.dart';
import 'package:dealker_app/features/search/presentation/widgets/search_states.dart';
import 'package:dealker_app/features/search/presentation/widgets/search_suggest_view.dart';
import 'package:dealker_app/features/search/presentation/widgets/search_top_bar.dart';
import 'package:dealker_app/routing/route_names.dart';

/// What the page shows right now.
enum _Mode {
  /// Nothing typed: recent searches, popular right now, browse by category.
  entry,

  /// Typing: phrases, matching products and categories.
  suggest,

  /// A search was submitted: filters + the product grid.
  results,
}

/// Highest page count that is loaded automatically so filters / sorting see the
/// whole result list (`AppConstants.paginationLimit` products per page).
const int _kMaxAutoPages = 10;

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({this.initialQuery, super.key});

  /// Runs this search on open (e.g. a Top Brands card: `/search?q=Apple`).
  final String? initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focus = FocusNode();
  final SpeechToText _speech = SpeechToText();
  bool _listening = false;

  late final AnimationController _slide;
  late final Animation<Offset> _slideAnim;
  bool _dismissing = false;

  _Mode _mode = _Mode.entry;

  /// The query whose results are on screen (results mode).
  String _submitted = '';
  int _queryGeneration = 0;
  final List<ProductEntity> _all = <ProductEntity>[];
  int _page = 1;
  int _totalPages = 1;
  int _serverTotal = 0;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  SearchSort _sort = SearchSort.relevance;
  SearchFilters _filters = const SearchFilters();

  @override
  void initState() {
    super.initState();
    _slide = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      reverseDuration: const Duration(milliseconds: 220),
    );
    _slideAnim =
        Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _slide,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _slide.forward();
    final String initial = widget.initialQuery?.trim() ?? '';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (initial.isEmpty) {
        _focus.requestFocus();
      } else {
        _submit(initial);
      }
    });
  }

  @override
  void dispose() {
    if (_listening) unawaited(_speech.stop());
    _slide.dispose();
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  // ── navigation ────────────────────────────────────────────────────────────

  Future<void> _dismiss() async {
    if (_dismissing) return;
    _dismissing = true;
    await _slide.reverse();
    if (!mounted) return;
    final GoRouter router = GoRouter.of(context);
    if (router.canPop()) {
      context.pop();
    } else {
      context.go(RouteNames.home);
    }
  }

  /// Back: results → back to editing the query; anything else → leave search.
  void _onBack() {
    if (_mode == _Mode.results) {
      setState(() => _mode = _Mode.suggest);
      _focus.requestFocus();
      return;
    }
    unawaited(_dismiss());
  }

  // ── typing / submitting ───────────────────────────────────────────────────

  void _onChanged(String value) {
    final String q = value.trim();
    setState(() => _mode = q.isEmpty ? _Mode.entry : _Mode.suggest);
    ref.read(searchProvider.notifier).onQueryChanged(value);
  }

  void _fill(String text) {
    _controller
      ..text = text
      ..selection = TextSelection.collapsed(offset: text.length);
    _focus.requestFocus();
    _onChanged(text);
  }

  void _clear() {
    _controller.clear();
    _focus.requestFocus();
    _onChanged('');
  }

  /// Run [raw] as a search and show its results.
  void _submit(String raw) {
    final String q = raw.trim();
    if (q.isEmpty) return;
    _controller
      ..text = q
      ..selection = TextSelection.collapsed(offset: q.length);
    _focus.unfocus();

    final bool sameQuery = q == _submitted;
    _queryGeneration++;
    setState(() {
      _mode = _Mode.results;
      _loadingMore = false;
      if (!sameQuery) {
        _submitted = q;
        _all.clear();
        _page = 1;
        _totalPages = 1;
        _serverTotal = 0;
        _loadMoreFailed = false;
        _sort = SearchSort.relevance;
        _filters = const SearchFilters();
      }
    });

    final SearchNotifier notifier = ref.read(searchProvider.notifier);
    unawaited(
      notifier.saveToHistory(q).then((_) {
        if (mounted) ref.read(searchHistoryProvider.notifier).refresh();
      }),
    );

    final AsyncValue<SearchResultEntity> current = ref.read(searchProvider);
    final SearchResultEntity? loaded = current.asData?.value;
    if (loaded != null && notifier.currentQuery == q && !current.isLoading) {
      _applyFirstPage(loaded);
    } else {
      notifier.searchNow(q);
    }
  }

  void _applyFirstPage(SearchResultEntity result) {
    setState(() {
      _all
        ..clear()
        ..addAll(result.products);
      _page = result.pagination.page == 0 ? 1 : result.pagination.page;
      _totalPages = result.pagination.totalPages;
      _serverTotal = result.total > 0
          ? result.total
          : (result.pagination.total > 0
              ? result.pagination.total
              : result.products.length);
      _loadMoreFailed = false;
    });
    if (_needsEverything) unawaited(_loadAllPages());
  }

  bool get _hasMore => _page < _totalPages;

  /// Filtering and sorting only see loaded products, so while they are active
  /// the remaining pages are fetched too.
  bool get _needsEverything =>
      !_filters.isDefault || _sort != SearchSort.relevance;

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _submitted.isEmpty) return;
    final String q = _submitted;
    final generation = _queryGeneration;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });
    try {
      final SearchResultEntity r = await ref
          .read(searchProvider.notifier)
          .searchPage(query: q, page: _page + 1);
      if (!mounted || generation != _queryGeneration || q != _submitted) return;
      setState(() {
        final Set<String> have = _all.map((ProductEntity p) => p.id).toSet();
        _all.addAll(r.products.where((ProductEntity p) => have.add(p.id)));
        _page = r.pagination.page == 0 ? _page + 1 : r.pagination.page;
        _totalPages = r.pagination.totalPages;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted || generation != _queryGeneration || q != _submitted) return;
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
    }
  }

  Future<void> _loadAllPages() async {
    final generation = _queryGeneration;
    int guard = 0;
    while (mounted &&
        generation == _queryGeneration &&
        _hasMore &&
        !_loadMoreFailed &&
        _page < _kMaxAutoPages &&
        guard++ < _kMaxAutoPages) {
      await _loadMore();
    }
  }

  // ── filters / sort ────────────────────────────────────────────────────────

  List<ProductEntity> get _display => applySearch(_all, _filters, _sort);

  Future<void> _openFilters() async {
    _focus.unfocus();
    // Facets and counts are only right when every product is loaded.
    unawaited(_loadAllPages());
    final SearchFilters? picked = await showSearchFilterSheet(
      context,
      initial: _filters,
      products: _all,
      totalOnServer: _serverTotal,
    );
    if (picked == null || !mounted) return;
    setState(() => _filters = picked);
    if (_needsEverything) unawaited(_loadAllPages());
  }

  Future<void> _openSort() async {
    _focus.unfocus();
    final SearchSort? picked =
        await showSearchSortSheet(context, current: _sort);
    if (picked == null || !mounted) return;
    setState(() => _sort = picked);
    if (_needsEverything) unawaited(_loadAllPages());
  }

  void _toggleInStock() {
    setState(
      () => _filters = _filters.copyWith(inStockOnly: !_filters.inStockOnly),
    );
    if (_needsEverything) unawaited(_loadAllPages());
  }

  // ── voice ─────────────────────────────────────────────────────────────────

  // Initialised on first tap so the mic permission is not asked just because the
  // search page opened.
  Future<void> _toggleVoice() async {
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }
    final bool available = await _speech.initialize(
      onError: (_) {
        if (!mounted) return;
        setState(() => _listening = false);
        AppToast.show(
          context,
          'Could not start voice search. Please try again.',
          type: ToastType.warning,
        );
      },
      onStatus: (String status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
    );
    if (!available) {
      if (!mounted) return;
      AppToast.show(
        context,
        'Microphone access is needed for voice search.',
        type: ToastType.warning,
      );
      return;
    }
    if (!mounted) return;
    setState(() => _listening = true);
    _focus.requestFocus();
    await _speech.listen(
      onResult: (result) {
        if (!mounted) return;
        _controller.text = result.recognizedWords;
        _controller.selection =
            TextSelection.collapsed(offset: _controller.text.length);
        _onChanged(result.recognizedWords);
        if (result.finalResult) {
          setState(() => _listening = false);
          _submit(result.recognizedWords);
        }
      },
      listenOptions: SpeechListenOptions(
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  // ── build ─────────────────────────────────────────────────────────────────

  List<CategoryEntity> _browsable(List<CategoryEntity> all) => all
      .where((CategoryEntity c) => c.isActive && c.isParent && !c.isBundle)
      .toList();

  @override
  Widget build(BuildContext context) {
    final AsyncValue<SearchResultEntity> searchState =
        ref.watch(searchProvider);
    final List<String> recent = ref.watch(searchHistoryProvider);
    final List<CategoryEntity> categories = _browsable(
      ref.watch(categoryCollectionProvider).asData?.value ??
          const <CategoryEntity>[],
    );
    final List<String> popular =
        ref.watch(popularSearchesProvider).asData?.value ?? const <String>[];
    final int cartCount = ref.watch(cartCountProvider);

    // First page of a submitted search arrives (or a retry succeeds).
    ref.listen<AsyncValue<SearchResultEntity>>(searchProvider, (
      AsyncValue<SearchResultEntity>? prev,
      AsyncValue<SearchResultEntity> next,
    ) {
      next.whenData((SearchResultEntity result) {
        if (_mode != _Mode.results) return;
        if (ref.read(searchProvider.notifier).currentQuery != _submitted) {
          return;
        }
        _applyFirstPage(result);
      });
    });

    return PopScope<void>(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, void result) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: SearchTokens.canvas,
        body: SafeArea(
          child: SlideTransition(
            position: _slideAnim,
            child: Material(
              color: SearchTokens.canvas,
              child: Column(
                children: <Widget>[
                  ListenableBuilder(
                    listenable: _controller,
                    builder: (BuildContext context, Widget? _) => SearchTopBar(
                      controller: _controller,
                      focusNode: _focus,
                      listening: _listening,
                      onChanged: _onChanged,
                      onSubmitted: _submit,
                      onBack: _onBack,
                      onClear: _clear,
                      onMic: _toggleVoice,
                      onTap: () {
                        if (_mode == _Mode.results) {
                          setState(() => _mode = _Mode.suggest);
                        }
                      },
                      cartCount: _mode == _Mode.results && _all.isNotEmpty
                          ? cartCount
                          : null,
                      onCart: () => context.push(RouteNames.cart),
                    ),
                  ),
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 160),
                      child: KeyedSubtree(
                        key: ValueKey<_Mode>(_mode),
                        child: _body(
                          searchState,
                          recent: recent,
                          categories: categories,
                          popular: popular,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(
    AsyncValue<SearchResultEntity> state, {
    required List<String> recent,
    required List<CategoryEntity> categories,
    required List<String> popular,
  }) {
    switch (_mode) {
      case _Mode.entry:
        return SearchEntryView(
          recent: recent,
          popular: popular,
          categories: categories,
          onPick: _submit,
          onFill: _fill,
          onRemoveRecent: (String q) =>
              ref.read(searchHistoryProvider.notifier).removeQuery(q),
          onClearRecent: () =>
              ref.read(searchHistoryProvider.notifier).clearAll(),
          onCategory: (CategoryEntity c) =>
              context.push('/categories/${c.id}/products'),
          onAllCategories: () => context.push(RouteNames.categories),
        );
      case _Mode.suggest:
        return _suggestBody(state, categories);
      case _Mode.results:
        return _resultsBody(state, categories, popular);
    }
  }

  Widget _suggestBody(
    AsyncValue<SearchResultEntity> state,
    List<CategoryEntity> categories,
  ) {
    final String typed = _controller.text.trim();
    final bool fresh = ref.read(searchProvider.notifier).currentQuery == typed;
    final SearchResultEntity? data = fresh ? state.asData?.value : null;
    final List<ProductEntity> products =
        data?.products ?? const <ProductEntity>[];

    // Categories the matching products sit in, most matches first.
    final Map<String, int> byName = <String, int>{};
    for (final ProductEntity p in products) {
      final String? n = p.categoryName;
      if (n != null && n.isNotEmpty) byName[n] = (byName[n] ?? 0) + 1;
    }
    final List<({CategoryEntity category, int count})> cats =
        <({CategoryEntity category, int count})>[];
    for (final MapEntry<String, int> e in byName.entries) {
      final CategoryEntity? c =
          categories.where((CategoryEntity c) => c.name == e.key).firstOrNull;
      if (c != null) cats.add((category: c, count: e.value));
    }
    cats.sort((a, b) => b.count.compareTo(a.count));

    return SearchSuggestView(
      query: _controller.text,
      loading: !fresh || state.isLoading,
      products: products,
      total: data?.total ?? 0,
      categories: cats.take(3).toList(),
      onPick: _submit,
      onFill: _fill,
      onProduct: (ProductEntity p) => context.push('/product/${p.id}'),
      onViewAll: () => _submit(_controller.text),
      onCategory: (CategoryEntity c) =>
          context.push('/categories/${c.id}/products'),
    );
  }

  Widget _resultsBody(
    AsyncValue<SearchResultEntity> state,
    List<CategoryEntity> categories,
    List<String> popular,
  ) {
    final bool waiting = state.isLoading && _all.isEmpty;
    if (waiting) return const SearchSkeletonGrid();

    final Object? error = state.hasError ? state.error : null;
    if (error != null && _all.isEmpty) {
      return SearchErrorView(
        offline: error is SearchException && error.isOffline,
        onRetry: () => ref.read(searchProvider.notifier).retry(),
      );
    }

    if (_all.isEmpty) {
      return SearchNoResultsView(
        query: _submitted,
        popular: popular,
        onPick: _submit,
        onBrowse: () => context.push(RouteNames.categories),
      );
    }

    final List<ProductEntity> shown = _display;
    if (shown.isEmpty && !_hasMore) {
      return SearchNoResultsView(
        query: _submitted,
        popular: popular,
        filtered: true,
        onPick: _submit,
        onBrowse: () => context.push(RouteNames.categories),
        onClearFilters: () {
          setState(() {
            _filters = const SearchFilters();
            _sort = SearchSort.relevance;
          });
        },
      );
    }

    final int count = _filters.isDefault && !_hasMore
        ? _all.length
        : (_filters.isDefault ? _serverTotal : shown.length);
    return SearchResultsView(
      query: _submitted,
      products: shown,
      count: count,
      sort: _sort,
      filters: _filters,
      hasMore: _hasMore,
      loadingMore: _loadingMore,
      loadMoreFailed: _loadMoreFailed,
      onLoadMore: _loadMore,
      onSort: _openSort,
      onFilter: _openFilters,
      onToggleInStock: _toggleInStock,
    );
  }
}
