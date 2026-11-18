import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  final String authId;
  final String name;
  final String? email;
  final String idNumber;
  final String role;

  const AppUser({
    required this.authId,
    required this.name,
    required this.email,
    required this.idNumber,
    required this.role,
  });

  bool get isAdmin => role == 'admin' || role == 'staff';
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
        .select('full_name, email, identity_number, role, is_active')
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
    );
    notifyListeners(); // router otomatis pindah halaman
    return true;
  }
}

final authProvider = AuthProvider();
