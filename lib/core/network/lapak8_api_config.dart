import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

class Lapak8ApiConfig {
  Lapak8ApiConfig._();

  static const String _configuredBaseUrl =
      String.fromEnvironment('LAPAK8_API_BASE_URL');

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _stripTrailingSlash(_configuredBaseUrl);
    }
    if (!kIsWeb && Platform.isAndroid) return 'http://10.0.2.2:8788';
    return 'http://127.0.0.1:8788';
  }

  static Uri uri(String path, [Map<String, String>? query]) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalizedPath').replace(
      queryParameters: query == null || query.isEmpty ? null : query,
    );
  }

  static String _stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
