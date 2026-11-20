// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'category_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(categoryCollection)
const categoryCollectionProvider = CategoryCollectionProvider._();

final class CategoryCollectionProvider extends $FunctionalProvider<
        AsyncValue<List<CategoryEntity>>,
        List<CategoryEntity>,
        FutureOr<List<CategoryEntity>>>
    with
        $FutureModifier<List<CategoryEntity>>,
        $FutureProvider<List<CategoryEntity>> {
  const CategoryCollectionProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'categoryCollectionProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$categoryCollectionHash();

  @$internal
  @override
  $FutureProviderElement<List<CategoryEntity>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<CategoryEntity>> create(Ref ref) {
    return categoryCollection(ref);
  }
}

String _$categoryCollectionHash() =>
    r'f2fffef2e5656a63e90b7f13fa01c394d2c129e5';
