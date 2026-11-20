import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:http_certificate_pinning/http_certificate_pinning.dart';

import 'package:dealker_app/core/constants/api_constants.dart';

class CertificatePinning {
  CertificatePinning._();

  static Interceptor? createInterceptor() {
    // The browser owns TLS validation; platform certificate pinning is native-only.
    if (kIsWeb || kDebugMode) {
      return null;
    }

    final baseUrl = ApiConstants.baseUrl.trim();
    final uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme.toLowerCase() != 'https') {
      return null;
    }

    final fingerprints = ApiConstants.appConfig.sslPins;
    if (fingerprints.isEmpty) {
      return null;
    }

    return CertificatePinningInterceptor(
      allowedSHAFingerprints: fingerprints,
      timeout: 50,
    );
  }

}
