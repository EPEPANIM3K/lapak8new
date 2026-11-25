<<<<<<< HEAD
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
=======
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  final String authId;
  final String name;
  final String? email;
  final String idNumber;
  final String role;
  final String? classOrUnit;

  const AppUser({
    required this.authId,
    required this.name,
    required this.email,
    required this.idNumber,
    required this.role,
    this.classOrUnit,
  });

  bool get isAdmin => role == 'admin';
}

class AuthProvider extends ChangeNotifier {
  SupabaseClient get _client => Supabase.instance.client;

  AppUser? _user;
  String? _error;

  AppUser? get user => _user;
  String? get error => _error;
  bool get isLoggedIn => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;

  /// Panggil sekali di main() untuk memulihkan sesi yang tersimpan.
  Future<void> init() async {
    final session = _client.auth.currentSession;
    if (session != null) {
      final ok = await _loadProfile(session.user.id);
      if (!ok) await _client.auth.signOut();
    }

    // Kalau sesi berakhir / logout dari tempat lain, bersihkan status.
    _client.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && _user != null) {
        _user = null;
        notifyListeners();
      }
    });
  }

  Future<bool> signIn(String email, String password) async {
    _error = null;
    try {
      final res = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final uid = res.user?.id;
      if (uid == null) {
        _error = 'Login gagal';
        return false;
      }

      final ok = await _loadProfile(uid);
      if (!ok) {
        await _client.auth.signOut();
        return false;
      }
      return true;
    } on AuthException catch (e) {
      _error = e.message.toLowerCase().contains('invalid login')
          ? 'Email atau kata sandi salah'
          : e.message;
      return false;
    } catch (_) {
      _error = 'Tidak bisa terhubung ke server. Cek koneksi internet.';
      return false;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<bool> _loadProfile(String authId) async {
    final row = await _client
        .from('profiles')
        .select(
          'full_name, email, identity_number, role, class_or_unit, is_active',
        )
        .eq('id', authId)
        .maybeSingle();

    if (row == null) {
      _error = 'Akun belum terdaftar di data pengguna';
      return false;
    }
    if (row['is_active'] == false) {
      _error = 'Akun ini dinonaktifkan. Hubungi petugas.';
      return false;
    }

    _user = AppUser(
      authId: authId,
      name: row['full_name'] as String,
      email: row['email'] as String?,
      idNumber: row['identity_number'] as String? ?? '',
      role: row['role'] as String,
      classOrUnit: row['class_or_unit'] as String?,
    );
    notifyListeners(); // router otomatis pindah halaman
    return true;
  }
}

final authProvider = AuthProvider();
>>>>>>> c4d3b6adf1f29467316add0189fb5d57a0cafedd
