import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'section_manifest_model.dart';

const _apiUrl = String.fromEnvironment(
  'THEME_BUILDER_API_URL',
  defaultValue: 'http://127.0.0.1:4500',
);
const _tab = String.fromEnvironment('THEME_BUILDER_TAB', defaultValue: 'all');
const _store = String.fromEnvironment(
  'THEME_BUILDER_STORE',
  defaultValue: 'zepto',
);
final _origin = Uri.parse(_apiUrl);
final _mediaPath = RegExp(r'^/api/v1/theme/media/[0-9a-f]{64}$');

String? publishedMediaUrl(String? value) =>
    value != null && _mediaPath.hasMatch(value)
    ? _origin.resolve(value).toString()
    : null;

final activeSectionManifestProvider =
    NotifierProvider.autoDispose<
      PublishedSectionManifest,
      SectionManifestResponse
    >(PublishedSectionManifest.new);

class PublishedSectionManifest extends Notifier<SectionManifestResponse> {
  @override
  SectionManifestResponse build() {
    final client = http.Client();
    final manifestUri = _origin
        .resolve('/api/v1/theme/tabs/${Uri.encodeComponent(_tab)}/sections')
        .replace(queryParameters: {'store_key': _store});
    var running = false;
    int? revision;

    Future<void> refresh() async {
      if (running) return;
      running = true;
      try {
        final response = await client
            .get(manifestUri)
            .timeout(const Duration(seconds: 3));
        if (response.statusCode != 200 || !ref.mounted) return;
        final envelope =
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final data = envelope['data'] as Map<String, dynamic>;
        final next = data['revision'] as int;
        if (next == revision) return;
        state = SectionManifestResponse.fromJson(data);
        revision = next;
      } on http.ClientException {
        // Keep the last published view while the local API is restarting.
      } on TimeoutException {
        // The next refresh can recover.
      } on FormatException {
        // Keep rendering the most recent valid version.
      } on TypeError {
        // Ignore a malformed response from an incompatible server.
      } finally {
        running = false;
      }
    }

    unawaited(Future<void>.microtask(refresh));
    final timer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(refresh()),
    );
    ref.onDispose(() {
      timer.cancel();
      client.close();
    });
    return SectionManifestResponse.empty;
  }
}
