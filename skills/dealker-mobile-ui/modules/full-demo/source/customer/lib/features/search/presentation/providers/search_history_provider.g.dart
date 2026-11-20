// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_history_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(SearchHistoryNotifier)
const searchHistoryProvider = SearchHistoryNotifierProvider._();

final class SearchHistoryNotifierProvider
    extends $NotifierProvider<SearchHistoryNotifier, List<String>> {
  const SearchHistoryNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'searchHistoryProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$searchHistoryNotifierHash();

  @$internal
  @override
  SearchHistoryNotifier create() => SearchHistoryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$searchHistoryNotifierHash() =>
    r'09eb7ae0507f610201ce4fbbcfd404ccae7dc993';

abstract class _$SearchHistoryNotifier extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<String>, List<String>>,
        List<String>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
