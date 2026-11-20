import 'dart:async';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dealker_app/core/network/picked_file_upload.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/di/providers.dart';
import 'package:dealker_app/features/repair/repair_models.dart';

Map<String, dynamic> _data(dynamic r) {
  final dynamic d = r is Map ? r['data'] : null;
  return d is Map ? Map<String, dynamic>.from(d) : <String, dynamic>{};
}

List<Map<String, dynamic>> _list(dynamic r) {
  final dynamic d = r is Map ? r['data'] : null;
  return <Map<String, dynamic>>[
    if (d is List)
      for (final dynamic e in d)
        if (e is Map) Map<String, dynamic>.from(e),
  ];
}

/// True when [e] means "no connection" rather than "the server said no".
bool isOfflineError(Object e) =>
    e is DioException &&
    (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout);

// ── config & catalogue ─────────────────────────────────────────────────────

class RepairConfig {
  const RepairConfig({
    required this.issues,
    required this.maxImages,
    required this.maxVideos,
    required this.diagnosticFee,
    required this.marketplace,
    this.searchRadiusKm,
    this.offerWindowHours,
  });

  final List<RepairIssue> issues;
  final int maxImages;
  final int maxVideos;
  final double diagnosticFee;
  final bool marketplace;
  final int? searchRadiusKm;
  final int? offerWindowHours;
}

final repairConfigProvider =
    FutureProvider.autoDispose<RepairConfig>((Ref ref) async {
  final Response<dynamic> r =
      await ref.watch(dioClientProvider).get<dynamic>('/repairs/config');
  final Map<String, dynamic> d = _data(r.data);
  final Map<String, dynamic> s = d['settings'] is Map
      ? Map<String, dynamic>.from(d['settings'] as Map)
      : <String, dynamic>{};
  final List<RepairIssue> issues = <RepairIssue>[
    if (d['issues'] is List)
      for (final dynamic i in d['issues'] as List)
        if (i is Map) RepairIssue('${i['key']}', '${i['label']}'),
  ];
  return RepairConfig(
    issues: issues,
    maxImages: (s['maxImages'] as num?)?.toInt() ?? 6,
    maxVideos: (s['maxVideos'] as num?)?.toInt() ?? 1,
    diagnosticFee: (s['diagnosticFee'] as num?)?.toDouble() ?? 0,
    marketplace: s['marketplaceEnabled'] != false,
    searchRadiusKm: (s['searchRadiusKm'] as num?)?.toInt(),
    offerWindowHours: (s['offerWindowHours'] as num?)?.toInt(),
  );
});

class RepairBrand {
  const RepairBrand(this.name, this.logoUrl);

  final String name;
  final String? logoUrl;
}

class RepairModel {
  const RepairModel(
    this.name,
    this.category,
    this.imageUrl, {
    this.series,
    this.brand,
  });

  final String name;
  final String? category;
  final String? imageUrl;
  final String? series;
  final String? brand;
}

const String kRepairCategory = 'Smartphone';

final repairBrandsProvider =
    FutureProvider.autoDispose<List<RepairBrand>>((Ref ref) async {
  final Response<dynamic> r = await ref.watch(dioClientProvider).get<dynamic>(
    '/repairs/catalogue/brands',
    queryParameters: <String, dynamic>{'category': kRepairCategory},
  );
  return _list(r.data)
      .map(
        (Map<String, dynamic> b) =>
            RepairBrand('${b['name']}', b['logoUrl'] as String?),
      )
      .toList(growable: false);
});

final repairModelsProvider = FutureProvider.autoDispose
    .family<List<RepairModel>, String>((Ref ref, String brand) async {
  final Response<dynamic> r = await ref.watch(dioClientProvider).get<dynamic>(
    '/repairs/catalogue/models',
    queryParameters: <String, dynamic>{
      'brand': brand,
      'category': kRepairCategory,
    },
  );
  return _list(r.data)
      .map(
        (Map<String, dynamic> m) => RepairModel(
          '${m['name']}',
          m['category'] as String?,
          m['imageUrl'] as String?,
          series: m['series'] as String?,
          brand: m['brand'] as String?,
        ),
      )
      .toList(growable: false);
});

/// Catalogue-wide model search ("s24", "redmi note") across every brand.
final repairModelSearchProvider = FutureProvider.autoDispose
    .family<List<RepairModel>, String>((Ref ref, String q) async {
  final Response<dynamic> r = await ref.watch(dioClientProvider).get<dynamic>(
    '/repairs/catalogue/models',
    queryParameters: <String, dynamic>{'q': q, 'category': kRepairCategory},
  );
  return _list(r.data)
      .map(
        (Map<String, dynamic> m) => RepairModel(
          '${m['name']}',
          m['category'] as String?,
          m['imageUrl'] as String?,
          series: m['series'] as String?,
          brand: m['brand'] as String?,
        ),
      )
      .toList(growable: false);
});

class RecentDevice {
  const RecentDevice(this.brand, this.model);

  final String brand;
  final String model;
  String get name => '$brand $model';
}

final repairRecentDevicesProvider =
    FutureProvider.autoDispose<List<RecentDevice>>((Ref ref) async {
  final Response<dynamic> r = await ref
      .watch(dioClientProvider)
      .get<dynamic>('/repairs/devices/recent');
  return _list(r.data)
      .map(
        (Map<String, dynamic> d) =>
            RecentDevice('${d['brand']}', '${d['model']}'),
      )
      .toList(growable: false);
});

// ── customer's requests ────────────────────────────────────────────────────

class RepairList {
  const RepairList(this.items);

  final List<RepairRequest> items;

  static const Set<String> _closed = <String>{
    'CANCELLED',
    'REJECTED',
    'FAILED',
    'ESTIMATE_REJECTED',
  };

  List<RepairRequest> get active => items
      .where((RepairRequest r) => !r.completed && !_closed.contains(r.status))
      .toList(growable: false);
  List<RepairRequest> get completed =>
      items.where((RepairRequest r) => r.completed).toList(growable: false);
  List<RepairRequest> get cancelled => items
      .where((RepairRequest r) => _closed.contains(r.status))
      .toList(growable: false);
}

final repairMineProvider =
    FutureProvider.autoDispose<RepairList>((Ref ref) async {
  final Response<dynamic> r = await ref.watch(dioClientProvider).get<dynamic>(
    '/repairs/mine',
    queryParameters: <String, dynamic>{'limit': 50},
  );
  final dynamic items = _data(r.data)['items'];
  return RepairList(<RepairRequest>[
    if (items is List)
      for (final dynamic i in items)
        if (i is Map) RepairRequest.fromListJson(Map<String, dynamic>.from(i)),
  ]);
});

final repairRequestProvider = FutureProvider.autoDispose
    .family<RepairRequest, String>((Ref ref, String id) async {
  final Response<dynamic> r =
      await ref.watch(dioClientProvider).get<dynamic>('/repairs/$id');
  return RepairRequest.fromJson(_data(r.data));
});

/// `requestId|sort` where sort is best | nearest | lowest_price | highest_rating.
final repairOffersProvider = FutureProvider.autoDispose
    .family<RepairOffers, String>((Ref ref, String key) async {
  final List<String> p = key.split('|');
  final Response<dynamic> r = await ref.watch(dioClientProvider).get<dynamic>(
    '/repairs/${p.first}/offers',
    queryParameters: <String, dynamic>{'sort': p.length > 1 ? p[1] : 'best'},
  );
  return RepairOffers.fromJson(_data(r.data));
});

final repairPayOptionsProvider =
    FutureProvider.autoDispose.family<RepairPayOptions, String>(
  (Ref ref, String id) => ref.watch(repairApiProvider).payOptions(id),
);

final repairTrackingProvider = FutureProvider.autoDispose
    .family<RepairTracking, String>((Ref ref, String id) async {
  final Response<dynamic> r =
      await ref.watch(dioClientProvider).get<dynamic>('/repairs/$id/tracking');
  return RepairTracking.fromJson(_data(r.data));
});

/// Saved addresses of the customer (id, label, lines, pincode, lat/lng, default).
class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.line1,
    required this.isDefault,
    this.line2,
    this.city,
    this.pincode,
    this.lat,
    this.lng,
  });

  factory SavedAddress.fromJson(Map<String, dynamic> j) => SavedAddress(
        id: '${j['id']}',
        label: '${j['label'] ?? 'Address'}',
        line1: '${j['addressLine1'] ?? ''}',
        line2: j['addressLine2'] as String?,
        city: j['city'] as String?,
        pincode: j['pincode'] as String?,
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
        isDefault: j['isDefault'] == true,
      );

  final String id;
  final String label;
  final String line1;
  final String? line2;
  final String? city;
  final String? pincode;
  final double? lat;
  final double? lng;
  final bool isDefault;

  /// "Salt Lake, Kolkata 700091" style second line.
  String get area => <String>[
        if ((city ?? '').isNotEmpty) city!,
        if ((pincode ?? '').isNotEmpty) pincode!,
      ].join(' ');

  String get full =>
      <String>[line1, if ((line2 ?? '').isNotEmpty) line2!].join(', ');
}

final repairAddressesProvider =
    FutureProvider.autoDispose<List<SavedAddress>>((Ref ref) async {
  final Response<dynamic> r =
      await ref.watch(dioClientProvider).get<dynamic>('/addresses');
  return _list(r.data).map(SavedAddress.fromJson).toList(growable: false);
});

// ── actions ────────────────────────────────────────────────────────────────

/// Every write the repair journey makes. Throws [DioException] on failure.
class RepairApi {
  const RepairApi(this._dio);

  final Dio _dio;

  /// Uploads one photo / video to the private evidence store; returns its media id.
  Future<String> uploadMedia(XFile file) async {
    final Response<dynamic> r = await _dio.post<dynamic>(
      '/repairs/media',
      data: FormData.fromMap(
        <String, dynamic>{'files': await pickedFileMultipart(file)},
      ),
      options: Options(
        sendTimeout: const Duration(seconds: 120),
        receiveTimeout: const Duration(seconds: 120),
      ),
    );
    final dynamic files = _data(r.data)['files'];
    if (files is! List || files.isEmpty) throw StateError('Upload failed');
    final Map<String, dynamic> first =
        Map<String, dynamic>.from(files.first as Map);
    if (first['ok'] != true) {
      throw StateError('${first['message'] ?? 'Upload failed'}');
    }
    return '${(first['media'] as Map)['id']}';
  }

  Future<void> deleteMedia(String id) async {
    try {
      await _dio.delete<dynamic>('/repairs/media/$id');
    } catch (_) {}
  }

  /// Publishes a marketplace request; returns its id.
  Future<String> create({
    required String brand,
    required String model,
    required List<String> issues,
    required String addressId,
    String? description,
    List<String> mediaIds = const <String>[],
  }) async {
    final Response<dynamic> r = await _dio.post<dynamic>(
      '/repairs',
      data: <String, dynamic>{
        'channel': 'B2C',
        'serviceMode': 'PICKUP',
        'addressId': addressId,
        'marketplace': true,
        if ((description ?? '').trim().isNotEmpty)
          'description': description!.trim(),
        if (mediaIds.isNotEmpty) 'mediaIds': mediaIds,
        'items': <Map<String, dynamic>>[
          <String, dynamic>{
            'brand': brand,
            'model': model,
            'category': kRepairCategory,
            'problemCategory': issues.first,
            'problemCategories': issues,
            if ((description ?? '').trim().isNotEmpty)
              'problemDescription': description!.trim(),
            'warrantyStatus': 'OUT_OF_WARRANTY',
          },
        ],
      },
    );
    return '${_data(r.data)['id']}';
  }

  Future<void> selectPickup({
    required String requestId,
    required String offerId,
    required String addressId,
    required DateTime slot,
  }) =>
      _dio.post<dynamic>(
        '/repairs/$requestId/offers/$offerId/select',
        data: <String, dynamic>{
          'fulfilment': 'PICKUP_DELIVERY',
          'addressId': addressId,
          'pickupSlot': slot.toUtc().toIso8601String(),
        },
      );

  Future<void> selectStoreVisit({
    required String requestId,
    required String offerId,
    required DateTime appointmentAt,
  }) =>
      _dio.post<dynamic>(
        '/repairs/$requestId/offers/$offerId/select',
        data: <String, dynamic>{
          'fulfilment': 'SHOP_VISIT',
          'appointmentAt': appointmentAt.toUtc().toIso8601String(),
        },
      );

  Future<void> approveEstimate(String id) => _dio.post<dynamic>(
        '/repairs/$id/approve-estimate',
        data: <String, dynamic>{},
      );

  Future<void> rejectEstimate(String id, String reason) => _dio.post<dynamic>(
        '/repairs/$id/reject-estimate',
        data: <String, dynamic>{'reason': reason},
      );

  Future<void> cancel(String id, String reason) => _dio.post<dynamic>(
        '/repairs/$id/cancel',
        data: <String, dynamic>{'reason': reason},
      );

  Future<void> rate(String id, int stars, String? review) => _dio.post<dynamic>(
        '/repairs/$id/rate',
        data: <String, dynamic>{
          'stars': stars,
          if ((review ?? '').trim().isNotEmpty) 'review': review!.trim(),
        },
      );

  Future<void> reopen(String id, String reason) => _dio.post<dynamic>(
        '/repairs/$id/reopen',
        data: <String, dynamic>{'reason': reason},
      );

  // ── chat with the chosen shop ────────────────────────────────────────────

  Future<List<RepairMessage>> messages(String id) async {
    final Response<dynamic> r =
        await _dio.get<dynamic>('/repairs/$id/messages');
    final dynamic m = _data(r.data)['messages'];
    return <RepairMessage>[
      if (m is List)
        for (final dynamic e in m)
          if (e is Map) RepairMessage.fromJson(Map<String, dynamic>.from(e)),
    ];
  }

  Future<void> sendMessage(String id, String body) =>
      _dio.post<dynamic>('/repairs/$id/messages',
          data: <String, dynamic>{'body': body});

  // ── QC mismatch answer ───────────────────────────────────────────────────

  Future<void> answerMismatch(String id, int mismatchId, String choice) =>
      _dio.post<dynamic>(
        '/repairs/$id/mismatch/respond',
        data: <String, dynamic>{'mismatchId': mismatchId, 'choice': choice},
      );

  // ── pay in the app ───────────────────────────────────────────────────────

  Future<RepairPayOptions> payOptions(String id) async {
    final Response<dynamic> r = await _dio.get<dynamic>('/repairs/$id/pay');
    return RepairPayOptions.fromJson(_data(r.data));
  }

  Future<void> payWallet(String id, String key) =>
      _dio.post<dynamic>('/repairs/$id/pay/wallet',
          data: <String, dynamic>{'idempotencyKey': key});

  Future<Map<String, dynamic>> payOrder(String id) async {
    final Response<dynamic> r =
        await _dio.post<dynamic>('/repairs/$id/pay/razorpay/order');
    return _data(r.data);
  }

  Future<void> payVerify(String id,
          {required String orderId,
          required String paymentId,
          required String signature}) =>
      _dio.post<dynamic>(
        '/repairs/$id/pay/razorpay/verify',
        data: <String, dynamic>{
          'razorpayOrderId': orderId,
          'razorpayPaymentId': paymentId,
          'razorpaySignature': signature
        },
      );

  /// The tax invoice PDF of a finished repair.
  Future<List<int>> invoicePdf(String invoiceId) async {
    final Response<List<int>> r = await _dio.get<List<int>>(
      '/sales-invoices/$invoiceId/pdf',
      options: Options(responseType: ResponseType.bytes),
    );
    return r.data ?? const <int>[];
  }
}

class RepairMessage {
  const RepairMessage(
      {required this.id, required this.mine, required this.body, this.at});

  factory RepairMessage.fromJson(Map<String, dynamic> j) => RepairMessage(
      id: (j['id'] as num?)?.toInt() ?? 0,
      mine: j['mine'] == true,
      body: '${j['body'] ?? ''}',
      at: DateTime.tryParse('${j['at']}')?.toLocal());

  final int id;
  final bool mine;
  final String body;
  final DateTime? at;
}

class RepairPayOptions {
  const RepairPayOptions(
      {required this.total,
      required this.paid,
      required this.due,
      required this.online,
      required this.walletBalance,
      this.kind,
      this.amount});

  factory RepairPayOptions.fromJson(Map<String, dynamic> j) {
    final Map<String, dynamic> now = j['payNow'] is Map
        ? Map<String, dynamic>.from(j['payNow'] as Map)
        : <String, dynamic>{};
    final Map<String, dynamic> m = j['methods'] is Map
        ? Map<String, dynamic>.from(j['methods'] as Map)
        : <String, dynamic>{};
    return RepairPayOptions(
      total: (j['total'] as num?)?.toDouble() ?? 0,
      paid: (j['paid'] as num?)?.toDouble() ?? 0,
      due: (j['due'] as num?)?.toDouble() ?? 0,
      kind: now['kind'] as String?,
      amount: (now['amount'] as num?)?.toDouble(),
      online: m['online'] == true,
      walletBalance: (j['walletBalance'] as num?)?.toDouble() ?? 0,
    );
  }

  final double total;
  final double paid;
  final double due;
  final String? kind; // ADVANCE | BALANCE
  final double? amount;
  final bool online;
  final double walletBalance;
}

final repairApiProvider =
    Provider<RepairApi>((Ref ref) => RepairApi(ref.watch(dioClientProvider)));

// ── request draft (device → problems → location) ───────────────────────────

class RepairPhoto {
  const RepairPhoto({
    required this.file,
    this.mediaId,
    this.uploading = false,
    this.failed = false,
  });

  final XFile file;
  String get path => file.path;
  bool get isVideo {
    if (file.mimeType?.startsWith('video/') ?? false) return true;
    final name = file.name.toLowerCase();
    return name.endsWith('.mp4') ||
        name.endsWith('.mov') ||
        name.endsWith('.m4v') ||
        name.endsWith('.3gp') ||
        name.endsWith('.webm');
  }

  final String? mediaId;
  final bool uploading;
  final bool failed;

  RepairPhoto copyWith({String? mediaId, bool? uploading, bool? failed}) =>
      RepairPhoto(
        file: file,
        mediaId: mediaId ?? this.mediaId,
        uploading: uploading ?? this.uploading,
        failed: failed ?? this.failed,
      );
}

class RepairDraft {
  const RepairDraft({
    this.brand,
    this.model,
    this.modelImage,
    this.issues = const <String>[],
    this.notes = '',
    this.photos = const <RepairPhoto>[],
    this.addressId,
  });

  final String? brand;
  final String? model;
  final String? modelImage;
  final List<String> issues;
  final String notes;
  final List<RepairPhoto> photos;
  final String? addressId;

  bool get hasDevice => (brand ?? '').isNotEmpty && (model ?? '').isNotEmpty;
  String get deviceName => '${brand ?? ''} ${model ?? ''}'.trim();
  bool get uploading => photos.any((RepairPhoto p) => p.uploading);

  RepairDraft copyWith({
    Object? brand = _keep,
    Object? model = _keep,
    Object? modelImage = _keep,
    List<String>? issues,
    String? notes,
    List<RepairPhoto>? photos,
    Object? addressId = _keep,
  }) =>
      RepairDraft(
        brand: identical(brand, _keep) ? this.brand : brand as String?,
        model: identical(model, _keep) ? this.model : model as String?,
        modelImage: identical(modelImage, _keep)
            ? this.modelImage
            : modelImage as String?,
        issues: issues ?? this.issues,
        notes: notes ?? this.notes,
        photos: photos ?? this.photos,
        addressId:
            identical(addressId, _keep) ? this.addressId : addressId as String?,
      );

  static const Object _keep = Object();
}

class RepairDraftNotifier extends Notifier<RepairDraft> {
  @override
  RepairDraft build() => const RepairDraft();

  void reset({List<String> issues = const <String>[]}) =>
      state = RepairDraft(issues: issues);

  void setBrand(String brand) {
    if (state.brand == brand) return;
    state = state.copyWith(brand: brand, model: null, modelImage: null);
  }

  void setDevice(String brand, String model, String? image) =>
      state = state.copyWith(brand: brand, model: model, modelImage: image);

  void toggleIssue(String key) {
    final List<String> next = <String>[...state.issues];
    next.contains(key) ? next.remove(key) : next.add(key);
    state = state.copyWith(issues: next);
  }

  void setNotes(String v) => state = state.copyWith(notes: v);

  void setAddress(String? id) => state = state.copyWith(addressId: id);

  /// Adds a picked file and uploads it straight away so the thumbnail can show
  /// progress, a failure with Retry, or a finished upload.
  Future<void> addPhoto(XFile file) async {
    final path = file.path;
    state = state.copyWith(
      photos: <RepairPhoto>[
        ...state.photos,
        RepairPhoto(file: file, uploading: true),
      ],
    );
    await _upload(path);
  }

  Future<void> retryPhoto(String path) async {
    _patch(path, (RepairPhoto p) => p.copyWith(uploading: true, failed: false));
    await _upload(path);
  }

  Future<void> _upload(String path) async {
    try {
      final photo = state.photos.where((item) => item.path == path).firstOrNull;
      if (photo == null) return;
      final String id =
          await ref.read(repairApiProvider).uploadMedia(photo.file);
      _patch(
        path,
        (RepairPhoto p) =>
            p.copyWith(mediaId: id, uploading: false, failed: false),
      );
    } catch (_) {
      _patch(
        path,
        (RepairPhoto p) => p.copyWith(uploading: false, failed: true),
      );
    }
  }

  void removePhoto(String path) {
    final RepairPhoto? p =
        state.photos.where((RepairPhoto x) => x.path == path).firstOrNull;
    if (p?.mediaId != null) {
      unawaited(ref.read(repairApiProvider).deleteMedia(p!.mediaId!));
    }
    state = state.copyWith(
      photos: state.photos.where((RepairPhoto x) => x.path != path).toList(),
    );
  }

  void _patch(String path, RepairPhoto Function(RepairPhoto) f) {
    state = state.copyWith(
      photos: <RepairPhoto>[
        for (final RepairPhoto p in state.photos) p.path == path ? f(p) : p,
      ],
    );
  }
}

final repairDraftProvider =
    NotifierProvider<RepairDraftNotifier, RepairDraft>(RepairDraftNotifier.new);

/// Customer-facing status wording used by pills and lists.
String repairStatusLabel(RepairRequest r) {
  if (r.awaitingOffers) {
    if (r.offerCount > 0) {
      return '${r.offerCount} shop${r.offerCount == 1 ? '' : 's'} nearby';
    }
    return 'Choose a shop';
  }
  return switch (r.status) {
    'ACCEPTED' => 'Shop chosen',
    'INSPECTION' => 'At repair shop',
    'ESTIMATE_SENT' => 'Review new price',
    'ESTIMATE_APPROVED' => 'Price confirmed',
    'IN_REPAIR' => 'In repair',
    'QC_PENDING' => 'Quality check',
    'REPAIRED' => 'Ready',
    'READY_FOR_DELIVERY' =>
      r.isStore ? 'Ready to collect' : 'Ready for delivery',
    'COMPLETED' => 'Completed',
    'CANCELLED' => 'Cancelled',
    'REJECTED' => 'Rejected',
    'ESTIMATE_REJECTED' => 'Price declined',
    'FAILED' => 'Couldn’t be repaired',
    _ => r.status,
  };
}
