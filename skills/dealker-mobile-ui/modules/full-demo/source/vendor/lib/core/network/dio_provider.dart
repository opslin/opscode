import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_vendor/core/constants/api_constants.dart';
import 'package:dealker_vendor/core/constants/app_constants.dart';
import 'package:dealker_vendor/core/errors/error_handler.dart';
import 'package:dealker_vendor/core/network/api_interceptor.dart';
import 'package:dealker_vendor/core/network/refresh_interceptor.dart';
import 'package:dealker_vendor/core/storage/secure_storage_service.dart';

final secureStorageProvider =
    Provider<SecureStorageService>((ref) => SecureStorageService());

/// Fired by the refresh interceptor when the refresh token is rejected; the
/// auth controller listens and drops the session.
final forceLogoutProvider =
    NotifierProvider<ForceLogoutSignal, int>(ForceLogoutSignal.new);

class ForceLogoutSignal extends Notifier<int> {
  @override
  int build() => 0;
  void fire() => state++;
}

/// The server refuses an empty body on a request labelled `application/json`, so action calls with no data send `{}`.
class _EmptyJsonBodyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final m = options.method.toUpperCase();
    if (options.data == null &&
        (m == 'POST' || m == 'PUT' || m == 'PATCH' || m == 'DELETE')) {
      options.data = <String, dynamic>{};
    }
    handler.next(options);
  }
}

final dioProvider = Provider<Dio>((ref) {
  final storage = ref.watch(secureStorageProvider);
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout:
          const Duration(seconds: AppConstants.connectTimeoutSeconds),
      receiveTimeout:
          const Duration(seconds: AppConstants.receiveTimeoutSeconds),
      contentType: 'application/json',
    ),
  );
  dio.interceptors.addAll([
    _EmptyJsonBodyInterceptor(),
    ApiInterceptor(storage),
    RefreshInterceptor(
      dio: dio,
      secureStorageService: storage,
      onForceLogout: () => ref.read(forceLogoutProvider.notifier).fire(),
    ),
    ErrorHandlerInterceptor(),
  ]);
  return dio;
});
