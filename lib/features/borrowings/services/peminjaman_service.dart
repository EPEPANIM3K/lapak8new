// lib/features/borrowings/services/peminjaman_service.dart
// Semua operasi peminjaman langsung ke Supabase (skema baru).

import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/peminjaman.dart';

class PeminjamanException implements Exception {
  const PeminjamanException(this.pesan);
  final String pesan;
  @override
  String toString() => pesan;
}

class AktivitasPeminjamanMingguan {
  const AktivitasPeminjamanMingguan({
    required this.pengajuan,
    required this.pengembalian,
  });

  final List<DateTime> pengajuan;
  final List<DateTime> pengembalian;
}

class StatistikPeminjamanPengguna {
  const StatistikPeminjamanPengguna({
    required this.selesai,
    required this.terlambat,
  });

  final int selesai;
  final int terlambat;
}

class PeminjamanService {
  SupabaseClient get _db => Supabase.instance.client;

  Future<int> hitungMenungguPersetujuan() async {
    try {
      final response = await _db
          .from('peminjaman')
          .select('id')
          .eq('status', 'menunggu_persetujuan')
          .count(CountOption.exact);
      return response.count;
    } on PostgrestException catch (e) {
      throw PeminjamanException(
        'Gagal menghitung peminjaman yang menunggu persetujuan: ${e.message}',
      );
    }
  }

  Future<int> hitungPeminjamanAktif() async {
    try {
      final response = await _db
          .from('peminjaman')
          .select('id')
          .inFilter('status', ['dipinjam', 'terlambat'])
          .count(CountOption.exact);
      return response.count;
    } on PostgrestException catch (e) {
      throw PeminjamanException(
        'Gagal menghitung peminjaman aktif: ${e.message}',
      );
    }
  }

  Future<StatistikPeminjamanPengguna> ambilStatistikPeminjamanSaya() async {
    final userId = _db.auth.currentUser?.id;
    if (userId == null) throw const PeminjamanException('Belum login.');

    try {
      final rows = await _db
          .from('peminjaman')
          .select('status, estimasi_kembali_pada, dikembalikan_pada')
          .eq('peminjam_id', userId)
          .inFilter('status', ['dikembalikan', 'terlambat']);

      var lateCount = 0;
      for (final row in rows) {
        final status = row['status'] as String;
        final returnedAt = row['dikembalikan_pada'] as String?;
        final dueAt = row['estimasi_kembali_pada'] as String;
        if (status == 'terlambat' ||
            (returnedAt != null &&
                DateTime.parse(returnedAt).isAfter(DateTime.parse(dueAt)))) {
          lateCount++;
        }
      }

      return StatistikPeminjamanPengguna(
        selesai: rows.length,
        terlambat: lateCount,
      );
    } on PostgrestException catch (e) {
      throw PeminjamanException(
        'Gagal memuat statistik peminjaman: ${e.message}',
      );
    }
  }

  Future<AktivitasPeminjamanMingguan> ambilAktivitasMingguan() async {
    final now = DateTime.now();
    final mulai = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6)).toUtc().toIso8601String();
    final akhir = now.toUtc().toIso8601String();

    try {
      final rows = await Future.wait([
        _db
            .from('peminjaman')
            .select('diajukan_pada')
            .gte('diajukan_pada', mulai)
            .lte('diajukan_pada', akhir),
        _db
            .from('peminjaman')
            .select('dikembalikan_pada')
            .gte('dikembalikan_pada', mulai)
            .lte('dikembalikan_pada', akhir),
      ]);

      return AktivitasPeminjamanMingguan(
        pengajuan: rows[0]
            .map<DateTime>(
              (row) => DateTime.parse(row['diajukan_pada'] as String),
            )
            .toList(),
        pengembalian: rows[1]
            .map<DateTime>(
              (row) => DateTime.parse(row['dikembalikan_pada'] as String),
            )
            .toList(),
      );
    } on PostgrestException catch (e) {
      throw PeminjamanException(
        'Gagal memuat aktivitas mingguan: ${e.message}',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Ambil daftar fasilitas yang tersedia (untuk dropdown form)
  // -------------------------------------------------------------------------
  Future<List<FasilitasRingkas>> ambilFasilitas() async {
    try {
      final rows = await _db
          .from('fasilitas')
          .select(
            'id, nama, kategori, total_unit, status, foto_url, lokasi(nama)',
          )
          .eq('aktif', true)
          .eq('status', 'tersedia')
          .gt('total_unit', 0)
          .order('nama');
      return rows
          .map<FasilitasRingkas>(
            (r) => FasilitasRingkas.fromMap(r as Map<String, dynamic>),
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
            diambil_pada, dikembalikan_pada, dibuat_pada:created_at,
            item_peminjaman(id, fasilitas_id, nama_fasilitas_snapshot, jumlah, fasilitas(foto_url))
          ''')
          .eq('peminjam_id', _db.auth.currentUser!.id)
          .order('created_at', ascending: false);
      return rows
          .map<Peminjaman>((r) => Peminjaman.fromMap(r as Map<String, dynamic>))
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
      var query = _db.from('peminjaman').select('''
            id, kode_booking, peminjam_id, kategori, nama_kegiatan,
            mulai_pada, estimasi_kembali_pada, status, diajukan_pada,
            alasan_penolakan, dibuat_pada:created_at,
            pengguna!peminjam_id(nama_lengkap, nomor_induk, kelas_atau_unit),
            item_peminjaman(
              id, fasilitas_id, nama_fasilitas_snapshot, jumlah,
              fasilitas(foto_url)
            )
          ''');

      if (statusFilter != null) {
        query = query.eq('status', statusFilter);
      }

      final rows = await query
          .order('created_at', ascending: false)
          .range(halaman * perHalaman, (halaman + 1) * perHalaman - 1);

      return rows
          .map<Peminjaman>((r) => Peminjaman.fromMap(r as Map<String, dynamic>))
          .toList();
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal memuat data: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Buat peminjaman baru
  // -------------------------------------------------------------------------
  // -------------------------------------------------------------------------
  // Ambil riwayat peminjaman milik user (dikembalikan, terlambat, ditolak, dibatalkan)
  // -------------------------------------------------------------------------
  Future<List<Peminjaman>> ambilRiwayatSaya() async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw const PeminjamanException('Belum login.');
    try {
      final rows = await _db
          .from('peminjaman')
          .select('''
            id, kode_booking, peminjam_id, kategori, nama_kegiatan,
            catatan_tujuan, mulai_pada, estimasi_kembali_pada, status,
            diajukan_pada, disetujui_pada, diambil_pada, dikembalikan_pada,
            alasan_penolakan,
            dibuat_pada:created_at,
            item_peminjaman(
              id, fasilitas_id, nama_fasilitas_snapshot, jumlah,
              fasilitas(foto_url)
            ),
            persetujuan_peminjaman(alasan_penolakan)
          ''')
          .eq('peminjam_id', uid)
          .inFilter('status', [
            'dikembalikan',
            'terlambat',
            'ditolak',
            'dibatalkan',
          ])
          .order('created_at', ascending: false);
      return rows
          .map<Peminjaman>(
            (row) => Peminjaman.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal memuat riwayat: ${e.message}');
    }
  }

  // -------------------------------------------------------------------------
  // Ambil riwayat peminjaman selesai untuk admin (dikembalikan & terlambat)
  // -------------------------------------------------------------------------
  Future<List<Peminjaman>> ambilSemuaRiwayat({
    int halaman = 0,
    int perHalaman = 50,
  }) async {
    try {
      final rows = await _db
          .from('peminjaman')
          .select('''
            id, kode_booking, peminjam_id, kategori, nama_kegiatan,
            mulai_pada, estimasi_kembali_pada, status, diajukan_pada,
            dikembalikan_pada, alasan_penolakan, dibuat_pada:created_at,
            pengguna!peminjam_id(nama_lengkap, nomor_induk, kelas_atau_unit),
            item_peminjaman(
              id, fasilitas_id, nama_fasilitas_snapshot, jumlah,
              fasilitas(foto_url)
            )
          ''')
          .inFilter('status', ['dikembalikan', 'terlambat'])
          .order('created_at', ascending: false)
          .range(halaman * perHalaman, (halaman + 1) * perHalaman - 1);

      return rows
          .map<Peminjaman>(
            (row) => Peminjaman.fromMap(Map<String, dynamic>.from(row as Map)),
          )
          .toList();
    } on PostgrestException catch (e) {
      throw PeminjamanException('Gagal memuat riwayat: ${e.message}');
    }
  }

  Future<Peminjaman> buat({
    required List<ItemPeminjamanInput> items,
    required String kategori,
    required String namaKegiatan,
    required DateTime mulaiPada,
    required DateTime estimasiKembaliPada,
    String? catatanTujuan,
  }) async {
    final uid = _db.auth.currentUser?.id;
    if (uid == null) throw const PeminjamanException('Belum login.');
    if (items.isEmpty) {
      throw const PeminjamanException(
        'Pilih barang atau ruangan terlebih dahulu.',
      );
    }
    if (items.any((item) => item.jumlah < 1)) {
      throw const PeminjamanException('Jumlah barang harus minimal 1 unit.');
    }

    try {
      final response = await _db.rpc(
        'ajukan_peminjaman',
        params: {
          'p_kategori': kategori,
          'p_nama_kegiatan': namaKegiatan.trim(),
          'p_mulai_pada': mulaiPada.toUtc().toIso8601String(),
          'p_estimasi_kembali_pada': estimasiKembaliPada
              .toUtc()
              .toIso8601String(),
          'p_items': items
              .map(
                (item) => {
                  'fasilitas_id': item.fasilitasId,
                  'jumlah': item.jumlah,
                },
              )
              .toList(),
          'p_catatan_tujuan': catatanTujuan?.trim(),
        },
      );
      if (response is! String || response.isEmpty) {
        throw const PeminjamanException(
          'Server tidak mengembalikan ID peminjaman.',
        );
      }

      return await ambilDetailPeminjaman(response);
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
            diambil_pada, dikembalikan_pada, dibuat_pada:created_at,
            pengguna!peminjam_id(nama_lengkap, nomor_induk, kelas_atau_unit),
            item_peminjaman(id, fasilitas_id, nama_fasilitas_snapshot, jumlah, fasilitas(foto_url))
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
      await _db.rpc('batalkan_peminjaman', params: {'p_peminjaman_id': id});
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
    try {
      await _db.rpc(
        'proses_peminjaman_admin',
        params: {
          'p_peminjaman_id': id,
          'p_status': status,
          'p_alasan_penolakan': alasanPenolakan,
        },
      );
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
}

final peminjamanService = PeminjamanService();
