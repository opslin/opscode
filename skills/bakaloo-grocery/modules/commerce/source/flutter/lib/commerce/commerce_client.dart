import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:bakaloo_flutter_app/demo/storefront.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

final serviceOrigin = Uri.parse(
  const String.fromEnvironment(
    'THEME_BUILDER_API_URL',
    defaultValue: 'http://127.0.0.1:4500',
  ),
);

const _requestTimeout = Duration(seconds: 5);
final _uploadPath = RegExp(r'^/api/v1/theme/media/[0-9a-f]{64}$');

class CheckoutFailure implements Exception {
  const CheckoutFailure(this.message);
  final String message;

  @override
  String toString() => message;
}

final catalogProvider =
    NotifierProvider.autoDispose<LocalCatalog, List<ProductEntity>?>(
      LocalCatalog.new,
    );

class LocalCatalog extends Notifier<List<ProductEntity>?> {
  @override
  List<ProductEntity>? build() {
    final client = http.Client();
    bool refreshing = false;
    String? previous;

    Future<void> refresh() async {
      if (refreshing || !ref.mounted) return;
      refreshing = true;
      try {
        final response = await client
            .get(serviceOrigin.resolve('/api/v1/catalog'))
            .timeout(_requestTimeout);
        if (response.statusCode != 200 || !ref.mounted) return;
        final body = utf8.decode(response.bodyBytes);
        if (previous == body) return;
        final envelope = jsonDecode(body) as Map<String, dynamic>;
        state = (envelope['data'] as List)
            .whereType<Map<String, dynamic>>()
            .map((raw) {
              final image = raw['image'];
              return ProductEntity.fromJson({
                ...raw,
                if (image is String && _uploadPath.hasMatch(image))
                  'image': serviceOrigin.resolve(image).toString(),
              });
            })
            .toList(growable: false);
        previous = body;
      } on http.ClientException {
        // Keep the last catalog while the API restarts.
      } on TimeoutException {
        // Try again on the next refresh.
      } on FormatException {
        // Keep rendering the most recent valid catalog.
      } on TypeError {
        // Ignore a malformed response from an incompatible API.
      } finally {
        refreshing = false;
      }
    }

    unawaited(Future<void>.microtask(refresh));
    final timer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => unawaited(refresh()),
    );
    ref.onDispose(() {
      timer.cancel();
      client.close();
    });
    return null;
  }
}

Future<Map<String, dynamic>> checkoutRequest(
  String path,
  Map<String, Object> body,
) async {
  final http.Response response;
  try {
    response = await http
        .post(
          serviceOrigin.resolve('/api/v1/checkout/$path'),
          headers: {'content-type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(_requestTimeout);
  } on http.ClientException {
    throw const CheckoutFailure(
      'Could not reach the local checkout. Try again.',
    );
  } on TimeoutException {
    throw const CheckoutFailure('Checkout timed out. Try again.');
  }
  final envelope =
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  if (response.statusCode >= 400) {
    throw CheckoutFailure(
      envelope['message'] as String? ?? 'Checkout could not be completed.',
    );
  }
  return envelope['data'] as Map<String, dynamic>;
}

String checkoutReference() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}
