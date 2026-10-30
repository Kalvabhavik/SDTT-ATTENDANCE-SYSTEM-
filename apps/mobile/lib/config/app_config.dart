import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig._();

  static const String usbBaseUrl = 'http://localhost:8000/api';
  static const String lanBaseUrl = 'http://10.0.4.99:8000/api';

  static const String supabaseUrl = 'https://weldmwxlhhhwsedkozli.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndlbGRtd3hsaGhod3NlZGtvemxpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTI2ODcyMTYsImV4cCI6MjEwODI2MzIxNn0.71uYa19AwHDujvDkfllGv_QsPyn-kd_LqZjr9N1u-98';

  static String _apiBaseUrl = const String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: usbBaseUrl,
  );

  static final ValueNotifier<String> activeUrlNotifier = ValueNotifier<String>(_apiBaseUrl);

  static String get apiBaseUrl => _apiBaseUrl;
  static set apiBaseUrl(String url) {
    final trimmed = url.trim();
    if (_apiBaseUrl != trimmed) {
      _apiBaseUrl = trimmed;
      activeUrlNotifier.value = trimmed;
    }
  }

  static String get alternateUrl {
    if (_apiBaseUrl.contains('localhost') || _apiBaseUrl.contains('127.0.0.1')) {
      return lanBaseUrl;
    }
    return usbBaseUrl;
  }

  static bool get isUsingLan => _apiBaseUrl.contains('10.0.4.99');

  static String get connectionModeLabel {
    if (isUsingLan) return 'Wi-Fi (10.0.4.99)';
    return 'USB (localhost)';
  }

  static void toggleServerUrl() {
    apiBaseUrl = alternateUrl;
  }

  static Uri get apiUri => Uri.parse(_apiBaseUrl);

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
