import 'package:supabase_flutter/supabase_flutter.dart';

class AppUser {
  const AppUser({
    required this.id,
    required this.nama,
    required this.email,
    required this.role,
    required this.isActive,
    this.kelas,
    this.nisn,
    this.nomorTelepon,
  });

  final String id;
  final String nama;
  final String email;
  final String role;
  final bool isActive;
  final String? kelas;
  final String? nisn;
  final String? nomorTelepon;

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'] as String,
    nama: map['full_name'] as String,
    email: map['email'] as String? ?? '',
    role: map['role'] as String,
    isActive: map['is_active'] as bool? ?? true,
    kelas: map['class_or_unit'] as String?,
    nisn: map['identity_number'] as String?,
    nomorTelepon: map['phone'] as String?,
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

class UserRepository {
  SupabaseClient get _db => Supabase.instance.client;

  Future<UserPage> fetchUsers({
    String query = '',
    int page = 0,
    int pageSize = 10,
    String? role,
    List<String>? roles,
    bool? suspended,
  }) async {
    final q = query.trim().replaceAll(RegExp(r'[,()%*\\"]'), ' ');
    var request = _db
        .from('profiles')
        .select(
          'id, full_name, email, identity_number, class_or_unit, phone, role, is_active',
        )
        .neq('role', 'admin');

    if (q.isNotEmpty) {
      request = request.or(
        'full_name.ilike.%$q%,email.ilike.%$q%,identity_number.ilike.%$q%,class_or_unit.ilike.%$q%',
      );
    }
    if (roles != null) {
      request = request.inFilter('role', roles);
    } else if (role != null) {
      request = request.eq('role', role);
    }
    if (suspended != null) request = request.eq('is_active', !suspended);

    final response = await request
        .order('full_name')
        .range(page * pageSize, (page + 1) * pageSize - 1)
        .count(CountOption.exact);
    return UserPage(
      items: response.data.map<AppUser>(AppUser.fromMap).toList(),
      total: response.count,
    );
  }

  Future<UserStats> fetchStats() async {
    final results = await Future.wait([
      _countUsers(role: 'student'),
      _countStaff(),
      _countUsers(active: false),
    ]);
    return UserStats(
      students: results[0],
      staff: results[1],
      suspended: results[2],
    );
  }

  Future<int> _countUsers({String? role, bool? active}) async {
    var request = _db.from('profiles').select('id').neq('role', 'admin');
    if (role != null) request = request.eq('role', role);
    if (active != null) request = request.eq('is_active', active);
    final response = await request.limit(1).count(CountOption.exact);
    return response.count;
  }

  Future<int> _countStaff() async {
    final response = await _db
        .from('profiles')
        .select('id')
        .inFilter('role', ['teacher', 'staff'])
        .limit(1)
        .count(CountOption.exact);
    return response.count;
  }

  Future<void> setActive(String userId, bool active) async {
    await _db.rpc(
      'admin_update_managed_profile',
      params: {
        'p_profile_id': userId,
        'p_full_name': null,
        'p_phone': null,
        'p_identity_number': null,
        'p_class_or_unit': null,
        'p_role': null,
        'p_is_active': active,
      },
    );
  }

  Future<void> updateUser(
    String userId, {
    required String nama,
    String? phone,
    String? kelas,
    String? nisn,
    required String role,
    required bool active,
  }) async {
    await _db.rpc(
      'admin_update_managed_profile',
      params: {
        'p_profile_id': userId,
        'p_full_name': nama,
        'p_phone': _optionalValue(phone),
        'p_identity_number': _optionalValue(nisn),
        'p_class_or_unit': _optionalValue(kelas),
        'p_role': role,
        'p_is_active': active,
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
    required String role,
    String? kelas,
    String? nisn,
    String? nomorTelepon,
    bool active = true,
  }) async {
    final data = await _callFunction({
      'action': 'create',
      'nama': nama,
      'email': email,
      'password': password,
      'role': role,
      'kelas': kelas,
      'nisn': nisn,
      'nomor_telepon': nomorTelepon,
      'active': active,
    });
    final id = data['id'];
    if (id is! String || id.isEmpty) {
      throw const UserRepositoryException(
        'Server tidak mengembalikan ID akun yang dibuat.',
      );
    }
    return id;
  }

  Future<void> resetPassword(String accountId, String newPassword) async {
    await _callFunction({
      'action': 'set_password',
      'id': accountId,
      'password': newPassword,
    });
  }

  String? _optionalValue(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  Future<Map<String, dynamic>> _callFunction(Map<String, dynamic> body) async {
    try {
      final response = await _db.functions.invoke('manage-users', body: body);
      if (response.data is! Map) {
        throw const UserRepositoryException(
          'Server mengembalikan respons yang tidak valid.',
        );
      }
      return Map<String, dynamic>.from(response.data as Map);
    } on FunctionException catch (error) {
      final details = error.details;
      final message = details is Map && details['error'] != null
          ? details['error'].toString()
          : 'Permintaan gagal (kode ${error.status}).';
      throw UserRepositoryException(message);
    }
  }
}

class UserRepositoryException implements Exception {
  const UserRepositoryException(this.message);

  final String message;

  @override
  String toString() => message;
}

final UserRepository userRepository = UserRepository();
