import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dealker_app/core/constants/api_constants.dart';
import 'package:dealker_app/core/constants/app_constants.dart';
import 'package:dealker_app/core/network/app_availability_provider.dart';
import 'package:dealker_app/core/errors/error_handler.dart';
import 'package:dealker_app/core/network/api_interceptor.dart';
import 'package:dealker_app/core/network/availability_interceptor.dart';
import 'package:dealker_app/core/network/connectivity_interceptor.dart';
import 'package:dealker_app/core/network/loading_activity_interceptor.dart';
import 'package:dealker_app/core/network/logger_interceptor.dart';
import 'package:dealker_app/core/network/network_monitor.dart';
import 'package:dealker_app/core/network/price_mode_interceptor.dart';
import 'package:dealker_app/core/network/refresh_interceptor.dart';
import 'package:dealker_app/core/network/network_activity_provider.dart';
import 'package:dealker_app/core/security/certificate_pinning.dart';
import 'package:dealker_app/core/socket/socket_service.dart';
import 'package:dealker_app/core/storage/secure_storage_service.dart';
import 'package:dealker_app/core/network/storefront_token_interceptor.dart';
import 'package:dealker_app/features/auth/presentation/providers/auth_notifier.dart';

/// Every request is labelled `application/json`, and the server refuses an empty JSON body
/// ("Body cannot be empty when content-type is set to 'application/json'"). Action calls such as
/// POST /repairs/:id/pay/razorpay/order carry no data, so send `{}` instead of nothing.
class EmptyJsonBodyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final String m = options.method.toUpperCase();
    if (options.data == null && (m == 'POST' || m == 'PUT' || m == 'PATCH')) {
      options.data = <String, dynamic>{};
    }
    handler.next(options);
  }
}

class DioClient {
  DioClient._();

  static Dio create(Ref ref) {
    final secureStorageService = SecureStorageService();
    final availabilityController = ref.read(appAvailabilityProvider.notifier);
    final dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.baseUrl,
        connectTimeout: const Duration(
          seconds: AppConstants.connectTimeoutSeconds,
        ),
        receiveTimeout: const Duration(
          seconds: AppConstants.receiveTimeoutSeconds,
        ),
        contentType: 'application/json',
      ),
    );

    dio.interceptors.addAll(<Interceptor>[
      EmptyJsonBodyInterceptor(),
      LoadingActivityInterceptor(ref.read(networkActivityProvider.notifier)),
      ConnectivityInterceptor(
        NetworkMonitor(),
        onOfflineDetected: availabilityController.reportOffline,
      ),
      if (CertificatePinning.createInterceptor() case final pinning?) pinning,
      ApiInterceptor(secureStorageService),
      PriceModeInterceptor(),
      StorefrontTokenInterceptor(),
      RefreshInterceptor(
        dio: dio,
        secureStorageService: secureStorageService,
        onTokenRefreshed: (accessToken) {
          ref.read(socketServiceProvider).reconnect(accessToken);
        },
        // When refresh token is also expired, force-logout the user so they
        // are redirected to the phone login screen instead of seeing a raw
        // "Invalid or expired refresh token" snackbar.
        onForceLogout: () {
          try {
            ref.read(authNotifierProvider.notifier).logout();
          } catch (_) {
            // Logout is best-effort — if the notifier is already disposed,
            // the user will be redirected on the next navigation attempt.
          }
        },
      ),
    ]);

    final logger = createLoggerInterceptor();
    if (logger != null) {
      dio.interceptors.add(logger);
    }

    dio.interceptors.add(ErrorHandlerInterceptor());
    dio.interceptors.add(AvailabilityInterceptor(availabilityController));
    return dio;
  }
}
