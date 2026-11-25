class AppUser {
  const AppUser({
    required this.id,
    required this.identifier,
    required this.name,
    required this.role,
    this.classroom,
  });

  final String id;
  final String identifier;
  final String name;
  final String role;
  final String? classroom;

  bool get isStaff => role == 'admin' || role == 'sarpras';

  factory AppUser.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['identifier'] is! String ||
        value['name'] is! String ||
        value['role'] is! String) {
      throw const FormatException('Data pengguna dari server tidak valid.');
    }
    return AppUser(
      id: value['id'] as String,
      identifier: value['identifier'] as String,
      name: value['name'] as String,
      role: value['role'] as String,
      classroom: value['classroom'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'identifier': identifier,
        'name': name,
        'role': role,
        'classroom': classroom,
      };
}
