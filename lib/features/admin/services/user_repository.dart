// lib/features/admin/services/user_repository.dart
// Menggunakan skema baru: tabel "pengguna" dengan kolom Indonesia.

import 'package:supabase_flutter/supabase_flutter.dart';

// ---------------------------------------------------------------------------
// Model pengguna untuk layar admin (berbeda dari AppUser di auth_provider)
// ---------------------------------------------------------------------------
class AppUser {
  const AppUser({
    required this.id,
    required this.nama,
    required this.email,
    required this.peran,
    required this.aktif,
    this.kelas,
    this.nomorInduk,
    this.nomorTelepon,
  });

  final String id;
  final String nama;
  final String email;
  final String peran;   // 'siswa' | 'guru' | 'staf' | 'admin'
  final bool aktif;
  final String? kelas;         // kelas_atau_unit
  final String? nomorInduk;    // NISN / NIP
  final String? nomorTelepon;

  bool get isActive => aktif;
  bool get isSiswa  => peran == 'siswa';
  bool get isGuru   => peran == 'guru';
  bool get isStaf   => peran == 'staf';

  /// Label role yang tampil di UI.
  String get roleLabel => switch (peran) {
    'siswa' => 'Siswa',
    'guru'  => 'Guru',
    'staf'  => 'Staf',
    _       => peran,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id:            map['id'] as String,
    nama:          map['nama_lengkap'] as String,
    email:         map['email'] as String? ?? '',
    peran:         map['peran'] as String,
    aktif:         map['aktif'] as bool? ?? true,
    kelas:         map['kelas_atau_unit'] as String?,
    nomorInduk:    map['nomor_induk'] as String?,
    nomorTelepon:  map['telepon'] as String?,
  );
}

class UserPage {
  const UserPage({required this.items, required this.total});

  final List<AppUser> items;
  final int total;

  int totalPages(int pageSize) => total == 0 ? 1 : (total / pageSize).ceil();
}

class UserStats {
  const UserStats({
    required this.students,
    required this.staff,
    required this.suspended,
  });

  final int students;
  final int staff;
  final int suspended;
}

// ---------------------------------------------------------------------------
// Repository
// ---------------------------------------------------------------------------
class UserRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<UserPage> fetchUsers({
    String query = '',
    int page = 0,
    int pageSize = 10,
    String? peran,
    List<String>? peranList,
    bool? suspended,
  }) async {
    final q = query.trim().replaceAll(RegExp(r'[,()%*\\""]'), ' ');
    var request = _db
        .from('pengguna')
        .select(
          'id, nama_lengkap, email, nomor_induk, kelas_atau_unit, telepon, peran, aktif',
        )
        .neq('peran', 'admin');

    if (q.isNotEmpty) {
      request = request.or(
        'nama_lengkap.ilike.%$q%,email.ilike.%$q%,nomor_induk.ilike.%$q%,kelas_atau_unit.ilike.%$q%',
      );
    }
    if (peranList != null) {
      request = request.inFilter('peran', peranList);
    } else if (peran != null) {
      request = request.eq('peran', peran);
    }
    if (suspended != null) request = request.eq('aktif', !suspended);

    final response = await request
        .order('nama_lengkap')
        .range(page * pageSize, (page + 1) * pageSize - 1)
        .count(CountOption.exact);
    return UserPage(
      items: response.data.map<AppUser>(AppUser.fromMap).toList(),
      total: response.count,
    );
  }

  Future<UserStats> fetchStats() async {
    final results = await Future.wait([
      _countUsers(peran: 'siswa'),
      _countStaff(),
      _countUsers(aktif: false),
    ]);
    return UserStats(
      students: results[0],
      staff: results[1],
      suspended: results[2],
    );
  }

  Future<int> _countUsers({String? peran, bool? aktif}) async {
    var request = _db.from('pengguna').select('id').neq('peran', 'admin');
    if (peran != null) request = request.eq('peran', peran);
    if (aktif != null) request = request.eq('aktif', aktif);
    final response = await request.limit(1).count(CountOption.exact);
    return response.count;
  }

  Future<int> _countStaff() async {
    final response = await _db
        .from('pengguna')
        .select('id')
        .inFilter('peran', ['guru', 'staf'])
        .limit(1)
        .count(CountOption.exact);
    return response.count;
  }

  Future<void> setActive(String userId, bool aktif) async {
    await _db.rpc(
      'admin_perbarui_pengguna',
      params: {
        'p_pengguna_id':     userId,
        'p_nama_lengkap':    null,
        'p_telepon':         null,
        'p_nomor_induk':     null,
        'p_kelas_atau_unit': null,
        'p_peran':           null,
        'p_aktif':           aktif,
      },
    );
  }

  Future<void> updateUser(
    String userId, {
    required String nama,
    String? phone,
    String? kelas,
    String? nomorInduk,
    required String peran,
    required bool aktif,
  }) async {
    await _db.rpc(
      'admin_perbarui_pengguna',
      params: {
        'p_pengguna_id':     userId,
        'p_nama_lengkap':    nama,
        'p_telepon':         _optional(phone),
        'p_nomor_induk':     _optional(nomorInduk),
        'p_kelas_atau_unit': _optional(kelas),
        'p_peran':           peran,
        'p_aktif':           aktif,
      },
    );
  }

  Future<void> updateEmail(String userId, String email) async {
    await _callFunction({'action': 'set_email', 'id': userId, 'email': email});
  }

  Future<String> createAccount({
    required String nama,
    required String email,
    required String password,
    required String peran,          // 'siswa' | 'guru' | 'staf'
    String? kelas,
    String? nomorInduk,
    String? nomorTelepon,
    bool aktif = true,
  }) async {
    final result = await _callFunction({
      'action':          'create',
      'nama':            nama,
      'email':           email,
      'password':        password,
      'peran':           peran,
      'kelas':           kelas,
      'nomor_induk':     nomorInduk,
      'nomor_telepon':   nomorTelepon,
      'aktif':           aktif,
    });
    final id = result['id'];
    if (id == null) throw const UserRepositoryException('ID akun baru tidak ditemukan.');
    return id.toString();
  }

  Future<void> resetPassword(String userId, String newPassword) async {
    await _callFunction({
      'action':   'set_password',
      'id':       userId,
      'password': newPassword,
    });
  }

  Future<void> deleteUser(String userId) async {
    await _callFunction({'action': 'delete', 'id': userId});
  }

  /// Panggil Edge Function `manage-users` dan kembalikan body JSON-nya.
  Future<Map<String, dynamic>> _callFunction(Map<String, dynamic> body) async {
    try {
      final response = await _db.functions.invoke(
        'manage-users',
        body: body,
      );
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {};
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : 'Permintaan gagal (kode ${error.status}).';
      final detail = details is Map ? details['detail']?.toString() : null;
      throw UserRepositoryException(
        detail != null && detail.isNotEmpty ? '$message $detail' : message,
      );
    }
  }

  dynamic _optional(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }
}

class UserRepositoryException implements Exception {
  const UserRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

final UserRepository userRepository = UserRepository();
