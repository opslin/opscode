import 'package:dio/dio.dart';

import 'package:dealker_app/features/auctions/data/auction_view.dart';

/// Which list the Auctions page is showing.
enum AuctionTab { live, upcoming, ended, myBids }

enum AuctionSort {
  ending('ending', 'Ending soon'),
  newest('new', 'Newly listed'),
  priceAsc('price_asc', 'Price: low to high'),
  priceDesc('price_desc', 'Price: high to low'),
  bids('bids', 'Most bids');

  const AuctionSort(this.api, this.label);
  final String api;
  final String label;
}

/// `/auctions` (customer API). The server owns every price, count and state; this only asks and parses.
class AuctionRepository {
  const AuctionRepository(this._dio);
  final Dio _dio;

  Duration _offset(Object? serverTime) {
    final DateTime? s = DateTime.tryParse('$serverTime');
    return s == null ? Duration.zero : s.difference(DateTime.now());
  }

  List<AuctionView> _rows(Object? data, Duration off) => <AuctionView>[
        if (data is List)
          for (final Object? r in data)
            if (r is Map)
              AuctionView.fromJson(Map<String, dynamic>.from(r), off),
      ];

  Future<AuctionPage> browse({
    required AuctionTab tab,
    String q = '',
    AuctionSort sort = AuctionSort.ending,
    String? brand,
    String? categoryId,
    num? min,
    num? max,
    bool registrationOpen = false,
    int page = 1,
    int limit = 20,
  }) async {
    final Response<dynamic> r =
        await _dio.get<dynamic>('/auctions', queryParameters: <String, dynamic>{
      'tab': tab.name,
      'page': page,
      'limit': limit,
      'sort': sort.api,
      if (q.trim().isNotEmpty) 'q': q.trim(),
      if (brand != null) 'brand': brand,
      if (categoryId != null) 'categoryId': categoryId,
      if (min != null) 'min': min,
      if (max != null) 'max': max,
      if (registrationOpen) 'registration': 'open',
    });
    final Map<dynamic, dynamic> body = r.data as Map;
    final Duration off = _offset(body['server_time']);
    final Map<dynamic, dynamic> facets = body['facets'] is Map
        ? body['facets'] as Map
        : const <dynamic, dynamic>{};
    return AuctionPage(
      items: _rows(body['data'], off),
      total: ((body['pagination'] as Map?)?['total'] as num?)?.toInt() ?? 0,
      counts: AuctionCounts.fromJson(body['counts']),
      brands: <({String name, int count})>[
        for (final Object? b
            in (facets['brands'] as List? ?? const <Object?>[]))
          if (b is Map)
            (name: '${b['name']}', count: (b['count'] as num?)?.toInt() ?? 0),
      ],
      categories: <({String id, String name, int count})>[
        for (final Object? c
            in (facets['categories'] as List? ?? const <Object?>[]))
          if (c is Map)
            (
              id: '${c['id']}',
              name: '${c['name']}',
              count: (c['count'] as num?)?.toInt() ?? 0
            ),
      ],
    );
  }

  /// Everything the signed-in customer joined or won, in any state.
  Future<List<AuctionView>> myBids() async {
    final Response<dynamic> r = await _dio.get<dynamic>('/auctions/mine',
        queryParameters: <String, dynamic>{'tab': 'all', 'limit': 50});
    final Map<dynamic, dynamic> body = r.data as Map;
    return _rows(body['data'], _offset(body['server_time']));
  }

  Future<List<AuctionView>> watching() async {
    final Response<dynamic> r = await _dio.get<dynamic>('/auctions/watching');
    final Map<dynamic, dynamic> body = r.data as Map;
    return _rows(body['data'], _offset(body['server_time']));
  }

  Future<void> watch(String id, {required bool on}) async {
    if (on) {
      await _dio.post<dynamic>('/auctions/$id/watch');
    } else {
      await _dio.delete<dynamic>('/auctions/$id/watch');
    }
  }

  /// A bid of exactly the next minimum.
  Future<bool> bid(String id, num amount) async {
    final Response<dynamic> r = await _dio.post<dynamic>('/auctions/$id/bids',
        data: <String, dynamic>{'maxAmount': amount});
    final Object? d = r.data is Map ? (r.data as Map)['data'] : null;
    return d is Map && d['you_are_leading'] == true;
  }

  /// "Notify me": tell the server this customer wants to hear when any new auction goes live.
  Future<void> setNewAuctionAlerts({required bool on}) async {
    await _dio.put<dynamic>('/notifications/preferences',
        data: <String, dynamic>{'auctionAlerts': on});
  }

  Future<bool> newAuctionAlerts() async {
    final Response<dynamic> r =
        await _dio.get<dynamic>('/notifications/preferences');
    final Object? d = r.data is Map ? (r.data as Map)['data'] : null;
    return d is Map && d['auctionAlerts'] == true;
  }
}
