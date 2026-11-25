import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/lapak8_api_client.dart';
import '../models/app_user.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    FlutterSecureStorage? storage,
    Lapak8ApiClient? apiClient,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        apiClient = apiClient ?? Lapak8ApiClient() {
    _authService = AuthService(this.apiClient);
  }

  static const _sessionKey = 'lapak8_auth_session';
  final FlutterSecureStorage _storage;
  final Lapak8ApiClient apiClient;
  late final AuthService _authService;

  AppUser? _user;
  AppUser? get user => _user;
  bool get isAuthenticated => _user != null;

  Future<void> restoreSession() async {
    final saved = await _storage.read(key: _sessionKey);
    if (saved == null) return;
    try {
      final value = jsonDecode(saved);
      if (value is! Map<String, dynamic> ||
          value['token'] is! String ||
          value['user'] is! Map<String, dynamic>) {
        throw const FormatException('Sesi tersimpan tidak valid.');
      }
      apiClient.accessToken = value['token'] as String;
      _user = AppUser.fromJson(value['user']);
    } on FormatException {
      await _storage.delete(key: _sessionKey);
    }
  }

  Future<AppUser> signIn({
    required String identifier,
    required String password,
    required bool rememberMe,
  }) async {
    final session = await _authService.login(identifier, password);
    apiClient.accessToken = session.token;
    _user = session.user;
    if (rememberMe) {
      await _storage.write(
        key: _sessionKey,
        value: jsonEncode({
          'token': session.token,
          'user': session.user.toJson(),
        }),
      );
    } else {
      await _storage.delete(key: _sessionKey);
    }
    notifyListeners();
    return session.user;
  }

  Future<void> signOut() async {
    await _storage.delete(key: _sessionKey);
    apiClient.accessToken = null;
    _user = null;
    notifyListeners();
  }
}

final AuthProvider authProvider = AuthProvider();