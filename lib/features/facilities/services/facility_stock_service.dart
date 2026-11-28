import 'package:supabase_flutter/supabase_flutter.dart';

class FacilityStock {
  const FacilityStock({
    required this.facilityId,
    required this.totalUnit,
    required this.dipakai,
    required this.tersedia,
  });

  final String facilityId;
  final int totalUnit;
  final int dipakai;
  final int tersedia;

  factory FacilityStock.fromMap(Map<String, dynamic> map) {
    final id = map['fasilitas_id'];
    final total = map['total_unit'];
    final dipakai = map['dipakai'];
    final tersedia = map['tersedia'];
    if (id is! String || total is! num || dipakai is! num || tersedia is! num) {
      throw const FacilityStockException(
        'Data stok fasilitas tidak valid. Muat ulang halaman.',
      );
    }

    return FacilityStock(
      facilityId: id,
      totalUnit: total.toInt(),
      dipakai: dipakai.toInt(),
      tersedia: tersedia.toInt(),
    );
  }
}

class FacilityStockException implements Exception {
  const FacilityStockException(this.message);

  final String message;

  @override
  String toString() => message;
}

class FacilityStockService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<Map<String, FacilityStock>> fetchAll() async {
    try {
      final response = await _db.rpc('stok_fasilitas');
      if (response is! List) {
        throw const FacilityStockException(
          'Data stok fasilitas tidak valid. Muat ulang halaman.',
        );
      }

      final stocks = <String, FacilityStock>{};
      for (final row in response) {
        if (row is! Map) {
          throw const FacilityStockException(
            'Data stok fasilitas tidak valid. Muat ulang halaman.',
          );
        }
        final stock = FacilityStock.fromMap(Map<String, dynamic>.from(row));
        stocks[stock.facilityId] = stock;
      }
      return stocks;
    } on PostgrestException {
      throw const FacilityStockException(
        'Gagal memuat stok. Pastikan migrasi stok tersedia sudah dijalankan, '
        'periksa koneksi, lalu coba lagi.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> addStockToRows(
    Iterable<dynamic> rows,
  ) async {
    final stocks = await fetchAll();
    return rows
        .map((row) {
          if (row is! Map) {
            throw const FacilityStockException(
              'Data fasilitas tidak valid. Muat ulang halaman.',
            );
          }
          final data = Map<String, dynamic>.from(row);
          final id = data['id'];
          final stock = id is String ? stocks[id] : null;
          if (stock == null) {
            throw const FacilityStockException(
              'Stok fasilitas tidak ditemukan. Muat ulang halaman.',
            );
          }
          return <String, dynamic>{
            ...data,
            'total_unit': stock.totalUnit,
            'unit_tersedia': stock.tersedia,
            'unit_dipakai': stock.dipakai,
          };
        })
        .toList(growable: false);
  }
}

final FacilityStockService facilityStockService = FacilityStockService();
