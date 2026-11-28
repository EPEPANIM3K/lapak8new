import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lapak8new/core/storage/supabase_media_service.dart';
import 'package:lapak8new/features/facilities/models/facility.dart';
import 'package:lapak8new/features/facilities/services/facility_stock_service.dart';

class FacilityException implements Exception {
  const FacilityException(this.message);
  final String message;

  @override
  String toString() => message;
}

class FacilityService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<List<Facility>> fetchFacilities({bool onlyActive = false}) async {
    try {
      var query = _db.from('fasilitas').select('*, lokasi(id, nama)');
      if (onlyActive) {
        query = query.eq('aktif', true);
      }
      final rows = await query.order('nama');
      final rowsWithStock = await facilityStockService.addStockToRows(rows);
      return rowsWithStock.map<Facility>(Facility.fromMap).toList();
    } on PostgrestException {
      throw const FacilityException(
        'Gagal memuat daftar barang. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  Future<List<Facility>> fetchPopularFacilities({int limit = 4}) async {
    try {
      final response = await _db.rpc(
        'fasilitas_populer_dashboard',
        params: {'p_limit': limit},
      );
      if (response is! List) {
        throw const FacilityException(
          'Data item populer dari server tidak valid.',
        );
      }
      final rowsWithStock = await facilityStockService.addStockToRows(response);
      return rowsWithStock
          .map<Facility>(Facility.fromMap)
          .toList(growable: false);
    } on PostgrestException {
      throw const FacilityException(
        'Gagal memuat item populer. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  Future<List<LokasiItem>> fetchLocations() async {
    try {
      final rows = await _db.from('lokasi').select('id, nama').order('nama');
      return rows
          .map<LokasiItem>(
            (r) => LokasiItem.fromMap(Map<String, dynamic>.from(r as Map)),
          )
          .toList();
    } on PostgrestException {
      throw const FacilityException(
        'Gagal memuat lokasi. Periksa koneksi lalu coba lagi.',
      );
    }
  }

  Future<String?> _resolveLokasiId({
    String? lokasiId,
    required String lokasiNama,
  }) async {
    if (lokasiId != null && lokasiId.isNotEmpty) return lokasiId;
    final trimmed = lokasiNama.trim();
    if (trimmed.isEmpty) return null;

    final existing = await _db
        .from('lokasi')
        .select('id')
        .ilike('nama', trimmed)
        .limit(1)
        .maybeSingle();
    if (existing != null && existing['id'] is String) {
      return existing['id'] as String;
    }

    try {
      final inserted = await _db
          .from('lokasi')
          .insert({'nama': trimmed})
          .select('id')
          .single();
      return inserted['id'] as String?;
    } on PostgrestException {
      return null;
    }
  }

  Future<Facility> createFacility({
    required String nama,
    required String kategori,
    String? lokasiId,
    required String lokasiNama,
    required int totalUnit,
    Uint8List? imageBytes,
    String? imageFileName,
  }) async {
    try {
      final resolvedLokasiId = await _resolveLokasiId(
        lokasiId: lokasiId,
        lokasiNama: lokasiNama,
      );

      String? fotoUrl;
      if (imageBytes != null) {
        fotoUrl = await supabaseMediaService.uploadImage(
          primaryBucket: 'fasilitas',
          folder: 'items',
          bytes: imageBytes,
          fileName: imageFileName ?? 'item.png',
        );
      }

      final payload = <String, dynamic>{
        'nama': nama.trim(),
        'total_unit': totalUnit,
        'status': totalUnit > 0 ? 'tersedia' : 'tidak_aktif',
        'aktif': true,
        if (resolvedLokasiId != null) 'lokasi_id': resolvedLokasiId,
        if (fotoUrl != null) 'foto_url': fotoUrl,
        if (kategori.trim().isNotEmpty) 'kategori': kategori.trim(),
      };

      final row = await _insertWithSchemaFallback(payload);
      return Facility.fromMap(row);
    } on MediaUploadException catch (e) {
      throw FacilityException(e.message);
    } on PostgrestException {
      throw const FacilityException(
        'Gagal menambah barang. Periksa data dan koneksi, lalu coba lagi.',
      );
    }
  }

  Future<Facility> updateFacility(
    String id, {
    required String nama,
    required String kategori,
    String? lokasiId,
    required String lokasiNama,
    required int totalUnit,
    Uint8List? imageBytes,
    String? imageFileName,
    String? existingFotoUrl,
    bool removePhoto = false,
  }) async {
    try {
      final resolvedLokasiId = await _resolveLokasiId(
        lokasiId: lokasiId,
        lokasiNama: lokasiNama,
      );

      String? fotoUrl = existingFotoUrl;
      if (imageBytes != null) {
        fotoUrl = await supabaseMediaService.uploadImage(
          primaryBucket: 'fasilitas',
          folder: id,
          bytes: imageBytes,
          fileName: imageFileName ?? 'item.png',
        );
      } else if (removePhoto) {
        fotoUrl = null;
      }

      final payload = <String, dynamic>{
        'nama': nama.trim(),
        'total_unit': totalUnit,
        'status': totalUnit > 0 ? 'tersedia' : 'tidak_aktif',
        if (resolvedLokasiId != null) 'lokasi_id': resolvedLokasiId,
        'foto_url': fotoUrl,
        if (kategori.trim().isNotEmpty) 'kategori': kategori.trim(),
      };

      final row = await _updateWithSchemaFallback(id, payload);
      return Facility.fromMap(row);
    } on MediaUploadException catch (e) {
      throw FacilityException(e.message);
    } on PostgrestException {
      throw const FacilityException(
        'Gagal memperbarui barang. Periksa data dan koneksi, lalu coba lagi.',
      );
    }
  }

  Future<void> deleteFacility(String id) async {
    try {
      await _db.from('fasilitas').delete().eq('id', id);
    } on PostgrestException catch (e) {
      if (e.code == '23503' ||
          e.message.toLowerCase().contains('foreign key')) {
        throw const FacilityException(
          'Barang tidak dapat dihapus karena masih memiliki riwayat peminjaman. '
          'Ubah jumlah unit menjadi 0 untuk menonaktifkannya.',
        );
      }
      throw const FacilityException(
        'Gagal menghapus barang. Periksa data terkait, lalu coba lagi.',
      );
    }
  }

  Future<Map<String, dynamic>> _insertWithSchemaFallback(
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _db
          .from('fasilitas')
          .insert(payload)
          .select('*, lokasi(id, nama)')
          .single();
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      if (payload.containsKey('kategori') &&
          e.message.toLowerCase().contains('kategori')) {
        throw const FacilityException(
          'Kategori belum dapat disimpan karena skema database belum diperbarui. '
          'Jalankan databasefix.sql di Supabase, lalu simpan barang kembali.',
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _updateWithSchemaFallback(
    String id,
    Map<String, dynamic> payload,
  ) async {
    try {
      final res = await _db
          .from('fasilitas')
          .update(payload)
          .eq('id', id)
          .select('*, lokasi(id, nama)')
          .single();
      return Map<String, dynamic>.from(res);
    } on PostgrestException catch (e) {
      if (payload.containsKey('kategori') &&
          e.message.toLowerCase().contains('kategori')) {
        throw const FacilityException(
          'Kategori belum dapat disimpan karena skema database belum diperbarui. '
          'Jalankan databasefix.sql di Supabase, lalu simpan perubahan kembali.',
        );
      }
      rethrow;
    }
  }
}

final FacilityService facilityService = FacilityService();
