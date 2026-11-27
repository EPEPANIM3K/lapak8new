import '../../../core/network/lapak8_api_client.dart';
import '../models/borrowing.dart';

class BorrowingService {
  BorrowingService({required Lapak8ApiClient client}) : _client = client;

  final Lapak8ApiClient _client;

  Future<List<BorrowingFacility>> fetchFacilities() async {
    final response = await _client.get('/api/v1/facilities');
    final data = response['data'];
    if (data is! List) {
      throw const Lapak8ApiException(
        'Daftar fasilitas dari server tidak valid.',
      );
    }
    return data.map(BorrowingFacility.fromJson).toList();
  }

  Future<List<Borrowing>> fetchBorrowings() async {
    final response = await _client.get('/api/v1/borrowings');
    final data = response['data'];
    if (data is! List) {
      throw const Lapak8ApiException(
        'Daftar peminjaman dari server tidak valid.',
      );
    }
    return data.map(Borrowing.fromJson).toList();
  }

  Future<Borrowing> create({
    required String facilityId,
    required String category,
    required String eventName,
    required int quantity,
    required DateTime startAt,
    required DateTime endAt,
  }) async {
    final response = await _client.post(
      '/api/v1/borrowings',
      body: {
        'facilityId': facilityId,
        'category': category,
        'eventName': eventName,
        'quantity': quantity,
        'startAt': startAt.toUtc().toIso8601String(),
        'endAt': endAt.toUtc().toIso8601String(),
      },
    );
    return Borrowing.fromJson(response['data']);
  }

  Future<void> cancel(String id) async {
    await _client.post('/api/v1/borrowings/$id/cancel');
  }

  Future<void> updateStatus(
    String id, {
    required String status,
    String? note,
  }) async {
    await _client.patch(
      '/api/v1/borrowings/$id/status',
      body: {'status': status, if (note != null) 'note': note},
    );
  }
}
