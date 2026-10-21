class AppConfig {
  const AppConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:8000/api',
  );

  static Uri get apiUri => Uri.parse(apiBaseUrl);

  static Uri websocketUri(String ticket) {
    final uri = apiUri;
    final scheme = uri.scheme == 'https' ? 'wss' : 'ws';
    final basePath = uri.path.endsWith('/')
        ? uri.path.substring(0, uri.path.length - 1)
        : uri.path;
    return uri.replace(
      scheme: scheme,
      path: '$basePath/ws',
      queryParameters: {'ticket': ticket},
    );
  }
}
