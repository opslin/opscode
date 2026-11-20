import 'package:dio/dio.dart';

import 'package:dealker_app/core/constants/storage_keys.dart';
import 'package:dealker_app/core/storage/hive_service.dart';

/// Sends the guest storefront token (see `bootstrapGuestStorefront`) with
/// every request. The backend only reads it when the caller is not signed
/// in; it scopes public catalogue reads (products, banners, sections) to the
/// shop serving the device's location. Signed-in customers are scoped by
/// their saved address instead, so the header is inert for them.
class StorefrontTokenInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final token = HiveService.settingsBox.get(StorageKeys.storefrontToken);
    if (token is String && token.isNotEmpty) {
      options.headers['x-storefront-token'] = token;
    }
    handler.next(options);
  }
}
