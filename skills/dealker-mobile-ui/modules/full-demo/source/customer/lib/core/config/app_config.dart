final class AppConfig {
  const AppConfig._({
    required this.baseUrl,
    required this.socketUrl,
    required this.webBaseUrl,
    required this.sslPins,
  });

  factory AppConfig.fromEnvironment() {
    return AppConfig.fromValues(
      baseUrl: const String.fromEnvironment(
        'BASE_URL',
        defaultValue: defaultBaseUrl,
      ),
      socketUrl: const String.fromEnvironment('SOCKET_URL'),
      webBaseUrl: const String.fromEnvironment(
        'WEB_BASE_URL',
        defaultValue: defaultWebBaseUrl,
      ),
      pin: const String.fromEnvironment('SSL_PIN_SHA256'),
      backupPin: const String.fromEnvironment('SSL_PIN_SHA256_BACKUP'),
      pinList: const String.fromEnvironment('SSL_PIN_SHA256_LIST'),
    );
  }

  factory AppConfig.fromValues({
    required String baseUrl,
    String socketUrl = '',
    String webBaseUrl = defaultWebBaseUrl,
    String pin = '',
    String backupPin = '',
    String pinList = '',
  }) {
    final String normalizedBase = _normalizeUrl(baseUrl);
    final String effectiveBase =
        normalizedBase.isEmpty ? defaultBaseUrl : normalizedBase;
    final String normalizedSocket = _normalizeUrl(socketUrl);
    final String normalizedWeb = _normalizeUrl(webBaseUrl);

    return AppConfig._(
      baseUrl: effectiveBase,
      socketUrl: normalizedSocket.isEmpty
          ? _socketOrigin(effectiveBase)
          : normalizedSocket,
      webBaseUrl: normalizedWeb.isEmpty ? defaultWebBaseUrl : normalizedWeb,
      sslPins: List<String>.unmodifiable(
        <String>{
          if (pin.trim().isNotEmpty) pin.trim(),
          if (backupPin.trim().isNotEmpty) backupPin.trim(),
          ...pinList
              .split(',')
              .map((String value) => value.trim())
              .where((String value) => value.isNotEmpty),
        },
      ),
    );
  }

  static const String defaultBaseUrl =
      'https://api.dealker.agnixstudio.in/api/v1';
  static const String defaultWebBaseUrl = 'https://dealker.in';

  final String baseUrl;
  final String socketUrl;
  final String webBaseUrl;
  final List<String> sslPins;

  static String _normalizeUrl(String value) {
    var normalized = value.trim();
    while (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }

  static String _socketOrigin(String baseUrl) {
    final Uri? uri = Uri.tryParse(baseUrl);
    if (uri == null || uri.scheme.isEmpty || uri.host.isEmpty) {
      return '';
    }
    return uri.replace(path: '', query: null, fragment: null).toString();
  }
}
