// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SearchNotifier)
const searchProvider = SearchNotifierProvider._();

final class SearchNotifierProvider
    extends $AsyncNotifierProvider<SearchNotifier, SearchResultEntity> {
  const SearchNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'searchProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$searchNotifierHash();

  @$internal
  @override
  SearchNotifier create() => SearchNotifier();
}

String _$searchNotifierHash() => r'20c3a4cdce9f76b5b575fc4152b08e981a9f4066';

abstract class _$SearchNotifier extends $AsyncNotifier<SearchResultEntity> {
  FutureOr<SearchResultEntity> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<AsyncValue<SearchResultEntity>, SearchResultEntity>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<AsyncValue<SearchResultEntity>, SearchResultEntity>,
        AsyncValue<SearchResultEntity>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
