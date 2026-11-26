import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Model pengguna yang sedang login
// ---------------------------------------------------------------------------
class AppUser {
  const AppUser({
    required this.id,
    required this.namaLengkap,
    required this.email,
    required this.nomorInduk,
    required this.peran,
    this.kelasAtauUnit,
    this.telepon,
    this.fotoUrl,
  });

  final String id; // = auth.uid()
  final String namaLengkap;
  final String? email;
  final String nomorInduk; // NISN / NIP
  final String peran; // 'siswa' | 'guru' | 'staf' | 'admin'
  final String? kelasAtauUnit;
  final String? telepon;
  final String? fotoUrl;

  bool get isAdmin => peran == 'admin';
  bool get isStaf => peran == 'staf';
  bool get isAdminAtauStaf => peran == 'admin' || peran == 'staf';
}

// ---------------------------------------------------------------------------
// Provider autentikasi (Supabase)
// ---------------------------------------------------------------------------
class AuthProvider extends ChangeNotifier {
  SupabaseClient get _db => Supabase.instance.client;

  AppUser? _user;
  String? _error;

  AppUser? get user => _user;
  String? get error => _error;
  bool get sudahLogin => _user != null;
  bool get isAdmin => _user?.isAdmin ?? false;
  bool get isAdminAtauStaf => _user?.isAdminAtauStaf ?? false;

  // -------------------------------------------------------------------------
  // Init — panggil sekali di main() setelah Supabase.initialize()
  // -------------------------------------------------------------------------
  Future<void> init() async {
    final session = _db.auth.currentSession;
    if (session != null) {
      final ok = await _muatProfil(session.user.id);
      if (!ok) await _db.auth.signOut();
    }

    _db.auth.onAuthStateChange.listen((data) {
      if (data.event == AuthChangeEvent.signedOut && _user != null) {
        _user = null;
        notifyListeners();
      }
    });
  }

  // -------------------------------------------------------------------------
  // Login
  // -------------------------------------------------------------------------
  Future<bool> signIn(String email, String password) async {
    _error = null;
    try {
      final res = await _db.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      final uid = res.user?.id;
      if (uid == null) {
        _error = 'Login gagal';
        return false;
      }
      final ok = await _muatProfil(uid);
      if (!ok) await _db.auth.signOut();
      return ok;
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

  // -------------------------------------------------------------------------
  // Logout
  // -------------------------------------------------------------------------
  Future<void> signOut() async {
    await _db.auth.signOut();
    _user = null;
    notifyListeners();
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final currentUser = _db.auth.currentUser;
    final email = currentUser?.email ?? _user?.email;
    if (currentUser == null || email == null || email.isEmpty) {
      throw StateError('Sesi akun tidak tersedia. Silakan masuk kembali.');
    }

    final verified = await _db.auth.signInWithPassword(
      email: email,
      password: currentPassword,
    );
    if (verified.user?.id != currentUser.id) {
      throw StateError('Verifikasi akun gagal. Silakan masuk kembali.');
    }

    await _db.auth.updateUser(UserAttributes(password: newPassword));
  }

  Future<void> updatePhoneNumber(String phone) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sesi akun tidak tersedia. Silakan masuk kembali.');
    }

    await _db.functions.invoke(
      'manage-users',
      body: {'action': 'set_phone', 'id': userId, 'phone': phone},
    );
    await refreshProfil();
  }

  Future<bool> loadNotificationPreference() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sesi akun tidak tersedia. Silakan masuk kembali.');
    }

    final response = await _db.functions.invoke(
      'manage-users',
      body: {'action': 'get_notification_preference'},
    );
    final data = response.data;
    if (data is! Map || data['enabled'] is! bool) {
      throw StateError('Preferensi notifikasi dari server tidak valid.');
    }
    return data['enabled'] as bool;
  }

  Future<void> saveNotificationPreference(bool enabled) async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Sesi akun tidak tersedia. Silakan masuk kembali.');
    }

    await _db.functions.invoke(
      'manage-users',
      body: {'action': 'set_notification_preference', 'enabled': enabled},
    );
  }

  // -------------------------------------------------------------------------
  // Muat profil dari tabel pengguna (skema baru)
  // -------------------------------------------------------------------------
  Future<bool> _muatProfil(String authId) async {
    try {
      final row = await _db
          .from('pengguna')
          .select(
            'nama_lengkap, email, nomor_induk, peran, kelas_atau_unit, telepon, foto_url, aktif',
          )
          .eq('id', authId)
          .maybeSingle();

      if (row == null) {
        _error = 'Akun belum terdaftar di sistem';
        return false;
      }
      if (row['aktif'] == false) {
        _error = 'Akun ini dinonaktifkan. Hubungi petugas.';
        return false;
      }

      _user = AppUser(
        id: authId,
        namaLengkap: row['nama_lengkap'] as String,
        email: row['email'] as String?,
        nomorInduk: row['nomor_induk'] as String? ?? '',
        peran: row['peran'] as String,
        kelasAtauUnit: row['kelas_atau_unit'] as String?,
        telepon: row['telepon'] as String?,
        fotoUrl: row['foto_url'] as String?,
      );
      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Gagal memuat profil: $e';
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Refresh profil (misal setelah edit akun sendiri)
  // -------------------------------------------------------------------------
  Future<void> refreshProfil() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) return;
    await _muatProfil(uid);
  }
}

final authProvider = AuthProvider();
