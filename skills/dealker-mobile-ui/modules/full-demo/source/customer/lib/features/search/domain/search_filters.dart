import 'package:dealker_app/features/products/domain/entities/product_entity.dart';
import 'package:dealker_app/shared/widgets/dealker_product_card.dart';

/// How the results are ordered. The server returns "relevance"; the rest is
/// applied on the products loaded so far.
enum SearchSort {
  relevance('Relevance', 'Relevance'),
  priceLow('Price: Low to High', 'Price: Low'),
  priceHigh('Price: High to Low', 'Price: High'),
  rating('Customer rating', 'Rating'),
  popularity('Popularity', 'Popularity');

  const SearchSort(this.label, this.pillLabel);

  /// In the sort sheet.
  final String label;

  /// On the results page's sort pill (kept short so the chips stay on one line).
  final String pillLabel;
}

/// A price band shown as a quick chip under the price slider.
class PriceBand {
  const PriceBand(this.label, this.min, this.max);

  final String label;
  final double? min;
  final double? max;
}

/// The brand a product belongs to: the catalogue brand, else the first word of
/// the name (store names read "Apple iPhone 15", "boAt Rockerz 450").
String brandOf(ProductEntity p) {
  final String brand = (p.brand ?? '').trim();
  if (brand.isNotEmpty) return brand;
  final String first = p.name.trim().split(RegExp(r'\s+')).first;
  return first.length > 1 ? first : '';
}

class SearchFilters {
  const SearchFilters({
    this.brands = const <String>{},
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.inStockOnly = false,
  });

  /// Selected brand names (compared case-insensitively).
  final Set<String> brands;
  final double? minPrice;
  final double? maxPrice;

  /// 4 → "4★ & above".
  final double? minRating;
  final bool inStockOnly;

  bool get hasPrice => minPrice != null || maxPrice != null;

  /// Number shown on the Filter button's badge (in stock has its own chip).
  int get activeCount =>
      (brands.isNotEmpty ? 1 : 0) +
      (hasPrice ? 1 : 0) +
      (minRating != null ? 1 : 0) +
      (inStockOnly ? 1 : 0);

  bool get isDefault => activeCount == 0;

  SearchFilters copyWith({
    Set<String>? brands,
    Object? minPrice = _keep,
    Object? maxPrice = _keep,
    Object? minRating = _keep,
    bool? inStockOnly,
  }) {
    return SearchFilters(
      brands: brands ?? this.brands,
      minPrice:
          identical(minPrice, _keep) ? this.minPrice : minPrice as double?,
      maxPrice:
          identical(maxPrice, _keep) ? this.maxPrice : maxPrice as double?,
      minRating:
          identical(minRating, _keep) ? this.minRating : minRating as double?,
      inStockOnly: inStockOnly ?? this.inStockOnly,
    );
  }

  bool matches(ProductEntity p) {
    if (inStockOnly && !p.inStock) return false;
    if (brands.isNotEmpty &&
        !brands
            .any((String b) => b.toLowerCase() == brandOf(p).toLowerCase())) {
      return false;
    }
    final double price = p.effectivePrice;
    if (minPrice != null && price < minPrice!) return false;
    if (maxPrice != null && price > maxPrice!) return false;
    if (minRating != null && !(p.hasRating && p.avgRating >= minRating!)) {
      return false;
    }
    return true;
  }

  static const Object _keep = Object();
}

/// Filters then orders [all]; the server order is kept for [SearchSort.relevance].
List<ProductEntity> applySearch(
  List<ProductEntity> all,
  SearchFilters filters,
  SearchSort sort,
) {
  final List<ProductEntity> out =
      all.where(filters.matches).toList(growable: true);
  switch (sort) {
    case SearchSort.relevance:
      break;
    case SearchSort.priceLow:
      out.sort((a, b) => a.effectivePrice.compareTo(b.effectivePrice));
    case SearchSort.priceHigh:
      out.sort((a, b) => b.effectivePrice.compareTo(a.effectivePrice));
    case SearchSort.rating:
      out.sort((a, b) => b.avgRating.compareTo(a.avgRating));
    case SearchSort.popularity:
      out.sort((a, b) => b.totalSold.compareTo(a.totalSold));
  }
  return out;
}

class BrandFacet {
  const BrandFacet(this.name, this.count);

  final String name;
  final int count;
}

/// Brands of [products] with how many products each has, biggest first.
List<BrandFacet> brandFacets(List<ProductEntity> products) {
  final Map<String, ({String name, int count})> byKey =
      <String, ({String name, int count})>{};
  for (final ProductEntity p in products) {
    final String name = brandOf(p);
    if (name.isEmpty) continue;
    final String key = name.toLowerCase();
    final prev = byKey[key];
    byKey[key] = (name: prev?.name ?? name, count: (prev?.count ?? 0) + 1);
  }
  final List<BrandFacet> out = byKey.values
      .map((v) => BrandFacet(v.name, v.count))
      .toList()
    ..sort((a, b) {
      final int c = b.count.compareTo(a.count);
      return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  return out;
}

/// "iphone 15" typed → short phrases to complete it, made from real product
/// names: the typed words completed to whole words, then one word further.
List<String> querySuggestions(String query, List<ProductEntity> products) {
  final List<String> typed = query
      .toLowerCase()
      .trim()
      .split(RegExp(r'\s+'))
      .where((String w) => w.isNotEmpty)
      .toList();
  if (typed.isEmpty) return const <String>[];

  final List<String> exact = <String>[];
  final List<String> longer = <String>[];
  for (final ProductEntity p in products) {
    final List<String> words = splitNameAndVariant(p.name)
        .name
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((String w) => w.isNotEmpty)
        .toList();
    for (int s = 0; s + typed.length <= words.length; s++) {
      bool ok = true;
      for (int k = 0; k < typed.length; k++) {
        if (!words[s + k].startsWith(typed[k])) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      final int end = s + typed.length;
      exact.add(words.sublist(s, end).join(' '));
      if (end < words.length) {
        longer.add(words.sublist(s, end + 1).join(' '));
      }
      break;
    }
  }
  final List<String> out = <String>[];
  for (final String phrase in <String>[...exact, ...longer]) {
    if (!out.contains(phrase)) out.add(phrase);
    if (out.length >= 6) break;
  }
  return out;
}
