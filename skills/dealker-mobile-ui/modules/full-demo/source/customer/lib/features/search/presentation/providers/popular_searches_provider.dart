import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/features/products/presentation/providers/product_list_provider.dart';
import 'package:dealker_app/features/search/domain/search_filters.dart';

/// "Popular right now": the brands of the best-selling (featured) products, most
/// frequent first. Real catalogue data — empty (section hidden) when it can't load.
final popularSearchesProvider = FutureProvider<List<String>>((Ref ref) async {
  final result = await ref.read(getFeaturedUseCaseProvider).call(limit: 30);
  final List<ProductEntity> products =
      result.fold((_) => const <ProductEntity>[], (List<ProductEntity> p) => p);
  return brandFacets(products)
      .map((BrandFacet b) => b.name)
      .take(8)
      .toList(growable: false);
});
