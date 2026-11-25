class BorrowingFacility {
  const BorrowingFacility({
    required this.id,
    required this.name,
    required this.location,
    required this.stock,
  });

  final String id;
  final String name;
  final String location;
  final int stock;

  factory BorrowingFacility.fromJson(Object? value) {
    if (value is! Map<String, dynamic> ||
        value['id'] is! String ||
        value['name'] is! String ||
        value['location'] is! String ||
        value['stock'] is! num) {
      throw const FormatException('Data fasilitas dari server tidak valid.');
    }
    return BorrowingFacility(
      id: value['id'] as String,
      name: value['name'] as String,
      location: value['location'] as String,
      stock: (value['stock'] as num).toInt(),
    );
  }
}

class Borrowing {
  const Borrowing({
    required this.id,
    required this.code,
    required this.facilityId,
    required this.facilityName,
    required this.location,
    required this.category,
    required this.eventName,
    required this.quantity,
    required this.startAt,
    required this.endAt,
    required this.status,
    required this.createdAt,
    this.userName,
    this.userIdentifier,
    this.decisionNote,
  });

  final String id;
  final String code;
  final String facilityId;
  final String facilityName;
  final String location;
  final String category;
  final String eventName;
  final int quantity;
  final DateTime startAt;
  final DateTime endAt;
  final String status;
  final DateTime createdAt;
  final String? userName;
  final String? userIdentifier;
  final String? decisionNote;

  factory Borrowing.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Data peminjaman dari server tidak valid.');
    }
    String requiredString(String key) {
      final item = value[key];
      if (item is! String) {
        throw FormatException('Kolom $key pada peminjaman tidak valid.');
      }
      return item;
    }

    DateTime requiredDate(String key) {
      final text = requiredString(key);
      final date = DateTime.tryParse(text);
      if (date == null) {
        throw FormatException('Tanggal $key pada peminjaman tidak valid.');
      }
      return date;
    }

    final quantity = value['quantity'];
    if (quantity is! num) {
      throw const FormatException('Jumlah peminjaman tidak valid.');
    }
    return Borrowing(
      id: requiredString('id'),
      code: requiredString('code'),
      facilityId: requiredString('facilityId'),
      facilityName: requiredString('facilityName'),
      location: requiredString('location'),
      category: requiredString('category'),
      eventName: requiredString('eventName'),
      quantity: quantity.toInt(),
      startAt: requiredDate('startAt'),
      endAt: requiredDate('endAt'),
      status: requiredString('status'),
      createdAt: requiredDate('createdAt'),
      userName: value['userName'] as String?,
      userIdentifier: value['userIdentifier'] as String?,
      decisionNote: value['decisionNote'] as String?,
    );
  }
}