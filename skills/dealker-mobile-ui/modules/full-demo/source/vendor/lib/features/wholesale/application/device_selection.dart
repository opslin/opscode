import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'package:dealker_vendor/features/wholesale/data/condition_report.dart';

/// Which devices of a used / refurbished / open-box listing the buyer is taking.
///
/// The number of selected devices ALWAYS equals the quantity: the first N available devices are picked by default,
/// un-ticking one automatically ticks the next available device, and ticking another device swaps it in.
/// Devices are loaded page by page, so a listing of 500 devices stays fast.
class DeviceSelection extends ChangeNotifier {
  DeviceSelection(this._dio, this.productId, int qty, {List<int>? initial, this.quantityFollows = false, this.minQty = 1, this.maxQty = 100000, this.onChanged})
      : _qty = qty,
        _initial = initial;

  final Dio _dio;
  final String productId;
  int _qty;
  final List<int>? _initial;

  /// Cart mode: ticking a device ADDS it (quantity goes up), un-ticking removes it (quantity goes down, never below [minQty]).
  /// Product-page mode (false): the quantity is fixed, un-ticking swaps in the next available device.
  final bool quantityFollows;
  final int minQty;
  final int maxQty;

  /// Called with the device numbers every time the selection changes.
  final void Function(List<int> nos)? onChanged;

  final Map<int, UnitBrief> loaded = {};
  int total = 0;
  int availableCount = 0;
  bool ready = false;
  bool loadingMore = false;
  List<int> selected = [];

  static const pageSize = 30;
  int get qty => _qty;
  bool get hasMore => loaded.length < total;

  Future<Map<String, dynamic>> _get(String path, [Map<String, dynamic>? q]) async {
    final r = await _dio.get<dynamic>('/product-page/units/$productId$path', queryParameters: q);
    return (((r.data as Map)['data']) as Map?)?.cast<String, dynamic>() ?? const {};
  }

  /// First available device numbers, lowest first (skipping [skip]).
  Future<List<int>> _firstAvailable(int n, {Set<int> skip = const {}}) async {
    final d = await _get('/first/${n + skip.length}');
    return [for (final v in (d['unit_nos'] as List? ?? const [])) (v as num).toInt()].where((x) => !skip.contains(x)).take(n).toList();
  }

  Future<void> init() async {
    try {
      await loadMore();
      selected = _initial != null && _initial.length == _qty ? [..._initial] : await _firstAvailable(_qty);
      ready = true;
    } catch (_) {
      ready = true;
    }
    notifyListeners();
  }

  Future<void> loadMore() async {
    if (loadingMore || (ready && !hasMore)) return;
    loadingMore = true;
    try {
      final d = await _get('', {'offset': loaded.length, 'limit': pageSize});
      total = (d['total'] as num?)?.toInt() ?? total;
      availableCount = (d['available_count'] as num?)?.toInt() ?? availableCount;
      for (final u in (d['items'] as List? ?? const [])) {
        final b = UnitBrief.fromJson((u as Map).cast<String, dynamic>());
        loaded[b.unitNo] = b;
      }
    } finally {
      loadingMore = false;
      notifyListeners();
    }
  }

  /// The quantity changed: add the next available devices, or drop the last ones.
  Future<void> setQty(int q) async {
    _qty = q;
    if (selected.length > q) {
      selected = selected.sublist(0, q);
    } else if (selected.length < q) {
      final more = await _firstAvailable(q - selected.length, skip: selected.toSet());
      selected = [...selected, ...more];
    }
    notifyListeners();
  }

  /// Returns a message when the tap could not be applied.
  Future<String?> toggle(int unitNo) async {
    final u = loaded[unitNo];
    if (u == null || !u.available) return null;
    if (quantityFollows) {
      if (selected.contains(unitNo)) {
        if (selected.length > minQty) {
          selected = selected.where((x) => x != unitNo).toList();
        } else {
          final repl = await _firstAvailable(1, skip: {...selected, unitNo});
          if (repl.isEmpty) return 'Minimum order is $minQty — no other device is available.';
          selected = [...selected.where((x) => x != unitNo), repl.first];
        }
      } else {
        if (selected.length >= maxQty) return 'Only $maxQty devices can be ordered.';
        selected = [...selected, unitNo];
      }
      _qty = selected.length;
    } else if (selected.contains(unitNo)) {
      // un-tick → the next available device takes its place so the count stays equal to the quantity
      final repl = await _firstAvailable(1, skip: {...selected, unitNo});
      if (repl.isEmpty) return 'No other device is available — change the quantity to take fewer.';
      selected = [...selected.where((x) => x != unitNo), repl.first];
    } else if (selected.length >= _qty) {
      selected = [...selected.sublist(0, selected.length - 1), unitNo]; // swap with the last one
    } else {
      selected = [...selected, unitNo];
    }
    notifyListeners();
    onChanged?.call(sorted);
    return null;
  }

  List<int> get sorted => [...selected]..sort();
}

/// First [n] available device numbers of a product, lowest first, skipping [skip].
Future<List<int>> fetchFirstAvailable(Dio dio, String productId, int n, {Set<int> skip = const {}}) async {
  final r = await dio.get<dynamic>('/product-page/units/$productId/first/${n + skip.length}');
  final d = (((r.data as Map)['data']) as Map?)?.cast<String, dynamic>() ?? const {};
  return [for (final v in (d['unit_nos'] as List? ?? const [])) (v as num).toInt()].where((x) => !skip.contains(x)).take(n).toList();
}
