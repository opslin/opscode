import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:dealker_app/core/analytics/analytics_service.dart';
import 'package:dealker_app/core/constants/app_constants.dart';
import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/core/errors/failure.dart';
import 'package:dealker_app/core/utils/debouncer.dart';
import 'package:dealker_app/features/search/data/datasources/search_remote_datasource.dart';
import 'package:dealker_app/features/search/data/local/search_history_datasource.dart';
import 'package:dealker_app/features/search/data/repositories/search_repository_impl.dart';
import 'package:dealker_app/features/search/domain/entities/search_result_entity.dart';
import 'package:dealker_app/features/search/domain/repositories/search_repository.dart';
import 'package:dealker_app/features/search/domain/usecases/clear_history.dart';
import 'package:dealker_app/features/search/domain/usecases/save_history.dart';
import 'package:dealker_app/features/search/domain/usecases/search_products_usecase.dart';

part 'search_provider.g.dart';

/// Why a search failed — lets the screen tell "you're offline" from "server error".
class SearchException implements Exception {
  const SearchException(this.failure);

  final Failure failure;

  bool get isOffline => failure is NetworkFailure;

  String get message => failure.message;

  @override
  String toString() => message;
}

final searchRemoteDataSourceProvider = Provider<SearchRemoteDataSource>((
  Ref ref,
) {
  return SearchRemoteDataSource(ref.watch(apiClientProvider));
});

final searchHistoryDataSourceProvider = Provider<SearchHistoryDataSource>((
  Ref ref,
) {
  return const SearchHistoryDataSource();
});

final searchRepositoryProvider = Provider<SearchRepository>((Ref ref) {
  return SearchRepositoryImpl(
    remoteDataSource: ref.watch(searchRemoteDataSourceProvider),
    historyDataSource: ref.watch(searchHistoryDataSourceProvider),
  );
});

final searchProductsUseCaseProvider =
    Provider<SearchProductsUseCase>((Ref ref) {
  return SearchProductsUseCase(ref.watch(searchRepositoryProvider));
});

final saveHistoryUseCaseProvider = Provider<SaveHistoryUseCase>((Ref ref) {
  return SaveHistoryUseCase(ref.watch(searchRepositoryProvider));
});

final clearHistoryUseCaseProvider = Provider<ClearHistoryUseCase>((Ref ref) {
  return ClearHistoryUseCase(ref.watch(searchRepositoryProvider));
});

@riverpod
class SearchNotifier extends _$SearchNotifier {
  final Debouncer _debouncer = Debouncer(
    delay: const Duration(milliseconds: AppConstants.searchDebounceMs),
  );

  String _currentQuery = '';
  int _generation = 0;

  String get currentQuery => _currentQuery;

  @override
  Future<SearchResultEntity> build() {
    ref.onDispose(_debouncer.dispose);
    return Future<SearchResultEntity>.value(SearchResultEntity.empty());
  }

  void onQueryChanged(String query) {
    final trimmedQuery = query.trim();
    _currentQuery = trimmedQuery;
    final generation = ++_generation;

    if (trimmedQuery.isEmpty) {
      _debouncer.cancel();
      state = AsyncData(SearchResultEntity.empty());
      return;
    }

    state = const AsyncLoading<SearchResultEntity>();
    _debouncer.run(() {
      unawaited(_search(trimmedQuery, generation));
    });
  }

  /// Search right now (a submitted query: no debounce).
  void searchNow(String query) {
    final trimmedQuery = query.trim();
    _currentQuery = trimmedQuery;
    final generation = ++_generation;
    _debouncer.cancel();

    if (trimmedQuery.isEmpty) {
      state = AsyncData(SearchResultEntity.empty());
      return;
    }

    state = const AsyncLoading<SearchResultEntity>();
    unawaited(_search(trimmedQuery, generation));
  }

  Future<void> retry() async {
    if (_currentQuery.isEmpty) {
      return;
    }

    state = const AsyncLoading<SearchResultEntity>();
    final generation = ++_generation;
    await _search(_currentQuery, generation);
  }

  Future<SearchResultEntity> searchPage({
    required String query,
    required int page,
    int limit = AppConstants.paginationLimit,
  }) async {
    final result = await ref.read(searchProductsUseCaseProvider).call(
          query: query,
          page: page,
          limit: limit,
        );

    return result.fold((failure) {
      throw SearchException(failure);
    }, (data) {
      return data;
    });
  }

  /// Remembers a query the customer actually submitted (not every keystroke).
  Future<void> saveToHistory(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      return;
    }
    await ref.read(saveHistoryUseCaseProvider).call(trimmed);
  }

  Future<void> _search(String query, int generation) async {
    final result = await ref.read(searchProductsUseCaseProvider).call(
          query: query,
          page: 1,
          limit: AppConstants.paginationLimit,
        );

    if (!ref.mounted || generation != _generation || query != _currentQuery) {
      return;
    }

    state = result.fold(
      (failure) => AsyncError<SearchResultEntity>(
        SearchException(failure),
        StackTrace.current,
      ),
      (data) {
        final resultCount = data.total > 0 ? data.total : data.products.length;
        unawaited(
          ref.read(analyticsServiceProvider).logSearch(
                query,
                resultCount,
              ),
        );
        return AsyncData<SearchResultEntity>(data);
      },
    );
  }
}
