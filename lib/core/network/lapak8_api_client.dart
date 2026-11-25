import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'lapak8_api_config.dart';

class Lapak8ApiException implements Exception {
  const Lapak8ApiException(
    this.message, {
    this.code,
    this.statusCode,
  });

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class Lapak8ApiClient {
  Lapak8ApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  String? _accessToken;

  set accessToken(String? value) => _accessToken = value;

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String>? query,
  }) =>
      _send('GET', path, query: query);

  Future<Map<String, dynamic>> post(
    String path, {
    Map<String, Object?>? body,
    bool authenticated = true,
  }) =>
      _send('POST', path, body: body, authenticated: authenticated);

  Future<Map<String, dynamic>> patch(
    String path, {
    required Map<String, Object?> body,
  }) =>
      _send('PATCH', path, body: body);

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Map<String, Object?>? body,
    bool authenticated = true,
  }) async {
    final headers = <String, String>{'content-type': 'application/json'};
    if (authenticated && _accessToken != null) {
      headers['authorization'] = 'Bearer $_accessToken';
    }
    final uri = Lapak8ApiConfig.uri(path, query);
    try {
      final response = await switch (method) {
        'GET' => _client.get(uri, headers: headers),
        'POST' => _client.post(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const <String, Object?>{}),
          ),
        'PATCH' => _client.patch(
            uri,
            headers: headers,
            body: jsonEncode(body ?? const <String, Object?>{}),
          ),
        _ => throw StateError('Metode HTTP tidak didukung: $method'),
      }.timeout(const Duration(seconds: 20));
      final Map<String, dynamic> payload;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Respons bukan object JSON.');
        }
        payload = decoded;
      } on FormatException {
        throw const Lapak8ApiException('Respons server LAPAK8 tidak valid.');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = payload['error'];
        final code = error is Map<String, dynamic> ? error['code'] : null;
        final message = error is Map<String, dynamic> ? error['message'] : null;
        throw Lapak8ApiException(
          message is String ? message : 'Permintaan ke server gagal.',
          code: code is String ? code : null,
          statusCode: response.statusCode,
        );
      }
      return payload;
    } on TimeoutException {
      throw Lapak8ApiException(
        'Server LAPAK8 tidak merespons di ${Lapak8ApiConfig.baseUrl}.',
      );
    } on http.ClientException {
      throw Lapak8ApiException(
        'Tidak dapat terhubung ke server LAPAK8 di ${Lapak8ApiConfig.baseUrl}.',
      );
    }
  }
}
