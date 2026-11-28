class NotificationRecord {
  const NotificationRecord({
    required this.id,
    required this.judul,
    required this.isi,
    this.userId,
    this.relatedEntity,
    this.relatedId,
    this.createdAt,
    this.sudahDibaca = false,
  });

  final String id;
  final String? userId;
  final String judul;
  final String isi;
  final String? relatedEntity;
  final String? relatedId;
  final DateTime? createdAt;
  final bool sudahDibaca;

  factory NotificationRecord.fromMap(Map<String, dynamic> map) {
    return NotificationRecord(
      id: map['id']?.toString() ?? '',
      userId: _nullableString(map['user_id']),
      judul: map['judul']?.toString() ?? '',
      isi: map['isi']?.toString() ?? '',
      relatedEntity: _nullableString(map['related_entity']),
      relatedId: _nullableString(map['related_id']),
      createdAt: _readDateTime(map['created_at']),
      sudahDibaca: _readBool(map['sudah_dibaca']),
    );
  }

  static String? _nullableString(Object? value) {
    if (value == null) return null;
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static bool _readBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      return value.toLowerCase() == 'true' || value == '1';
    }
    return false;
  }

  static DateTime? _readDateTime(Object? value) {
    if (value is DateTime) return value;
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}
