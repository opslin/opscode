import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/core/network/dio_provider.dart';

const storeDays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
const storeDayNames = {
  'mon': 'Monday', 'tue': 'Tuesday', 'wed': 'Wednesday', 'thu': 'Thursday',
  'fri': 'Friday', 'sat': 'Saturday', 'sun': 'Sunday',
};

class DayHours {
  const DayHours({required this.open, required this.close, required this.closed});
  final String open; // HH:mm
  final String close;
  final bool closed;

  DayHours copyWith({String? open, String? close, bool? closed}) =>
      DayHours(open: open ?? this.open, close: close ?? this.close, closed: closed ?? this.closed);

  Map<String, dynamic> toJson() => {'open': open, 'close': close, 'closed': closed};
}

/// Opening hours, pickup, auto-accept and where order alerts go — the vendor's own store settings.
class StoreSettings {
  const StoreSettings({
    required this.autoAccept,
    required this.pickup,
    required this.email,
    required this.phone,
    required this.days,
  });
  final bool autoAccept;
  final bool pickup;
  final String email;
  final String phone;
  final Map<String, DayHours> days;

  StoreSettings copyWith({bool? autoAccept, bool? pickup, String? email, String? phone, Map<String, DayHours>? days}) =>
      StoreSettings(
          autoAccept: autoAccept ?? this.autoAccept,
          pickup: pickup ?? this.pickup,
          email: email ?? this.email,
          phone: phone ?? this.phone,
          days: days ?? this.days);

  factory StoreSettings.fromJson(Map<String, dynamic> j) {
    final d = (j['days'] as Map?)?.cast<String, dynamic>() ?? const {};
    return StoreSettings(
      autoAccept: j['autoAcceptOrders'] == true,
      pickup: j['pickup'] != false,
      email: '${j['notificationEmail'] ?? ''}',
      phone: '${j['notificationPhone'] ?? ''}',
      days: {
        for (final k in storeDays)
          k: () {
            final v = (d[k] as Map?)?.cast<String, dynamic>() ?? const {};
            return DayHours(
                open: '${v['open'] ?? '09:00'}', close: '${v['close'] ?? '21:00'}', closed: v['closed'] == true);
          }()
      },
    );
  }

  Map<String, dynamic> toJson() => {
        'autoAcceptOrders': autoAccept,
        'pickup': pickup,
        'notificationEmail': email.trim(),
        'notificationPhone': phone.trim(),
        'days': {for (final e in days.entries) e.key: e.value.toJson()},
      };
}

class StoreSettingsRepository {
  StoreSettingsRepository(this._dio);
  final Dio _dio;

  Future<StoreSettings> load() async {
    try {
      final r = await _dio.get<Map<String, dynamic>>('/vendor/store/settings');
      return StoreSettings.fromJson((r.data?['data'] as Map).cast<String, dynamic>());
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }

  Future<void> save(StoreSettings s) async {
    try {
      await _dio.put<Map<String, dynamic>>('/vendor/store/settings', data: s.toJson());
    } on DioException catch (e) {
      throw handleDioError(e);
    }
  }
}

final storeSettingsRepositoryProvider =
    Provider<StoreSettingsRepository>((ref) => StoreSettingsRepository(ref.watch(dioProvider)));

final storeSettingsProvider = FutureProvider.autoDispose<StoreSettings>(
    (ref) => ref.watch(storeSettingsRepositoryProvider).load());
