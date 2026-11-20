/// Rebuilds the classic section-manifest shape from the compact one.
///
/// When the app asks `GET /theme/tabs/:tab/sections?compact=1` the server sends every
/// distinct product once in `product_pool` and references it from the sections as
/// `"@<key>"` (the same product used to be repeated in ~8 sections, making the manifest
/// ~700 KB). Everything downstream still expects the classic shape — `products` lists of
/// full product maps, including inside `config.tabs[*]` — so this expands the references
/// back before parsing. A response without `product_pool` (old server, or a manifest
/// cached before this change) is returned untouched.
///
/// Pure Dart on purpose: no Flutter imports, so it can be unit-tested anywhere.
Map<String, dynamic> hydrateProductPool(Map<String, dynamic> json) {
  final Object? rawPool = json['product_pool'];
  if (rawPool is! Map) {
    return json;
  }

  final Map<String, dynamic> pool = <String, dynamic>{
    for (final MapEntry<Object?, Object?> entry in rawPool.entries)
      '${entry.key}': entry.value,
  };

  final Map<String, dynamic> hydrated = Map<String, dynamic>.from(json)
    ..remove('product_pool');
  hydrated['sections'] = _expand(json['sections'], pool);
  return hydrated;
}

bool _isPoolRef(Object? value, Map<String, dynamic> pool) =>
    value is String &&
    value.startsWith('@') &&
    pool.containsKey(value.substring(1));

Object? _expand(Object? node, Map<String, dynamic> pool) {
  if (node is List) {
    return node.map((Object? item) => _expand(item, pool)).toList();
  }
  if (node is Map) {
    final Map<String, dynamic> out = <String, dynamic>{};
    node.forEach((Object? rawKey, Object? value) {
      final String key = '$rawKey';
      if (key == 'products' &&
          value is List &&
          value.isNotEmpty &&
          value.every((Object? item) => _isPoolRef(item, pool))) {
        out[key] = value
            .map((Object? ref) => pool[(ref! as String).substring(1)])
            .toList();
      } else {
        out[key] = _expand(value, pool);
      }
    });
    return out;
  }
  return node;
}
