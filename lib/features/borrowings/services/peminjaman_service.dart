// lib/features/borrowings/services/peminjaman_service.dart
// Semua operasi peminjaman langsung ke Supabase (skema baru).

import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/peminjaman.dart';

class PeminjamanException implements Exception {
  const PeminjamanException(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}

class PeminjamanService {
  SupabaseClient get _db => Supabase.instance.client;

  // -------------------------------------------------------------------------
  // Ambil daftar fasilitas yang tersedia (untuk dropdown form)
  // -------------------------------------------------------------------------
  Future<List<FasilitasRingkas>> ambilFasilitas() async {
    try {
      final rows = await _db
          .from('fasilitas')
          .select('id, nama, total_unit, status, foto_url, lokasi(nama)')
          .eq('aktif', true)
          .eq('status', 'tersedia')
          .order('nama');
      return rows
          .map<FasilitasRingkas>(
            (r) => FasilitasRingkas.fromMap(r),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal memuat fasilitas: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Ambil daftar peminjaman milik user yang sedang login
  // -------------------------------------------------------------------------
  Future<List<Peminjaman>> ambilPeminjamanSaya() async {
    try {
      final rows = await _db
          .from('peminjaman')
          .select('''
            id, kode_booking, peminjam_id, kategori, nama_kegiatan,
            catatan_tujuan, mulai_pada, estimasi_kembali_pada, status,
            alasan_penolakan, diajukan_pada, disetujui_pada,
            diambil_pada, dikembalikan_pada, dibuat_pada,
            item_peminjaman(id, fasilitas_id, nama_fasilitas_snapshot, jumlah)
          ''')
          .eq('peminjam_id', _db.auth.currentUser!.id)
          .order('dibuat_pada', ascending: false);
      return rows
          .map<Peminjaman>(
            (r) => Peminjaman.fromMap(r),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal memuat peminjaman: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Ambil SEMUA peminjaman (admin/staf)
  // -------------------------------------------------------------------------
  Future<List<Peminjaman>> ambilSemuaPeminjaman({
    String? statusFilter,
    int halaman = 0,
    int perHalaman = 20,
  }) async {
    try {
      var query = _db
          .from('peminjaman')
          .select('''
            id, kode_booking, peminjam_id, kategori, nama_kegiatan,
            mulai_pada, estimasi_kembali_pada, status, diajukan_pada,
            dibuat_pada,
            pengguna!peminjam_id(nama_lengkap, nomor_induk),
            item_peminjaman(id, fasilitas_id, nama_fasilitas_snapshot, jumlah)
          ''');

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      final rows = await query
          .order('dibuat_pada', ascending: false)
          .range(halaman * perHalaman, (halaman + 1) * perHalaman - 1);

      return rows
          .map<Peminjaman>(
            (r) => Peminjaman.fromMap(r),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal memuat data: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Buat peminjaman baru
  // -------------------------------------------------------------------------
  Future<Peminjaman> buat({
    required String fasilitasId,
    required String namaFasilitas,
    required String kategori,
    required String namaKegiatan,
    required int jumlah,
    required DateTime mulaiPada,
    required DateTime estimasiKembaliPada,
    String? catatanTujuan,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw const PeminjamanException('Belum login.');

    final kodeBooking = _generateKode();

    try {
      // 1. Insert header peminjaman
      final rowPeminjaman = await _db
          .from('peminjaman')
          .insert({
            'kode_booking':           kodeBooking,
            'peminjam_id':            uid,
            'kategori':               kategori,
            'nama_kegiatan':          namaKegiatan.trim(),
            'catatan_tujuan':         catatanTujuan?.trim(),
            'mulai_pada':             mulaiPada.toUtc().toIso8601String(),
            'estimasi_kembali_pada':  estimasiKembaliPada.toUtc().toIso8601String(),
            'status':                 'menunggu_persetujuan',
          })
          .select()
          .single();

      final peminjamanId = rowPeminjaman['id'] as String;

      // 2. Insert item peminjaman
      await _db.from('item_peminjaman').insert({
        'peminjaman_id':            peminjamanId,
        'fasilitas_id':             fasilitasId,
        'nama_fasilitas_snapshot':  namaFasilitas,
        'jumlah':                   jumlah,
      });

      // 3. Muat ulang dengan relasi lengkap
      return await ambilDetailPeminjaman(peminjamanId);
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal membuat peminjaman: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Ambil detail satu peminjaman
  // -------------------------------------------------------------------------
  Future<Peminjaman> ambilDetailPeminjaman(String id) async {
    try {
      final row = await _db
          .from('peminjaman')
          .select('''
            id, kode_booking, peminjam_id, kategori, nama_kegiatan,
            catatan_tujuan, mulai_pada, estimasi_kembali_pada, status,
            alasan_penolakan, diajukan_pada, disetujui_pada,
            diambil_pada, dikembalikan_pada, dibuat_pada,
            pengguna!peminjam_id(nama_lengkap, nomor_induk),
            item_peminjaman(id, fasilitas_id, nama_fasilitas_snapshot, jumlah)
          ''')
          .eq('id', id)
          .single();
      return Peminjaman.fromMap(row);
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal memuat detail: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Batalkan peminjaman (hanya oleh peminjam sendiri, status menunggu)
  // -------------------------------------------------------------------------
  Future<void> batalkan(String id) async {
    try {
      await _db
          .from('peminjaman')
          .update({'status': 'dibatalkan'})
          .eq('id', id)
          .eq('peminjam_id', _db.auth.currentUser!.id)
          .eq('status', 'menunggu_persetujuan');
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal membatalkan: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Admin/staf: ubah status peminjaman
  // -------------------------------------------------------------------------
  Future<void> ubahStatus(
    String id, {
    required String status,
    String? alasanPenolakan,
  }) async {
    final Map<String, dynamic> data = {'status': status};

    if (status == 'disetujui')   data['disetujui_pada']   = DateTime.now().toUtc().toIso8601String();
    if (status == 'dipinjam')    data['diambil_pada']      = DateTime.now().toUtc().toIso8601String();
    if (status == 'dikembalikan') data['dikembalikan_pada'] = DateTime.now().toUtc().toIso8601String();
    if (alasanPenolakan != null) data['alasan_penolakan']  = alasanPenolakan;

    try {
      await _db.from('peminjaman').update(data).eq('id', id);
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal mengubah status: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Admin: setujui / tolak
  // -------------------------------------------------------------------------
  Future<void> setujui(String id) => ubahStatus(id, status: 'disetujui');

  Future<void> tolak(String id, {required String alasan}) =>
      ubahStatus(id, status: 'ditolak', alasanPenolakan: alasan);

  Future<void> tandaiDiambil(String id) => ubahStatus(id, status: 'dipinjam');

  Future<void> tandaiDikembalikan(String id) =>
      ubahStatus(id, status: 'dikembalikan');

  // -------------------------------------------------------------------------
  // Helper: generate kode booking unik  format: LPK-YYYYMMDD-XXXXX
  // -------------------------------------------------------------------------
  String _generateKode() {
    final now = DateTime.now();
    final tanggal =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final acak = (Random().nextInt(90000) + 10000).toString();
    return 'LPK-$tanggal-$acak';
  }
}

final peminjamanService = PeminjamanService();
