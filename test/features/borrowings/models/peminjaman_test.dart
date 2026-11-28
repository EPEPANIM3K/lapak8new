import 'package:flutter_test/flutter_test.dart';
import 'package:lapak8new/features/borrowings/models/peminjaman.dart';

void main() {
  test('treats room category case-insensitively', () {
    for (final category in ['Ruangan', 'ruangan', 'RuanGan', ' ruangan ']) {
      final facility = FasilitasRingkas(
        id: 'room-id',
        nama: 'Lab',
        kategori: category,
        lokasi: 'Gedung A',
        totalUnit: 1,
        status: 'tersedia',
      );

      expect(facility.isRuangan, isTrue, reason: category);
    }
  });

  test('maps available borrowing stock separately from physical capacity', () {
    final facility = FasilitasRingkas.fromMap({
      'id': 'facility-id',
      'nama': 'Proyektor',
      'kategori': 'Barang',
      'total_unit': 2,
      'unit_tersedia': 1,
      'status': 'tersedia',
    });

    expect(facility.totalUnit, 2);
    expect(facility.unitTersedia, 1);
    expect(facility.tersedia, isTrue);
  });

  test('maps history fields and rejection reason from approval records', () {
    final borrowing = Peminjaman.fromMap({
      'id': 'booking-id',
      'kode_booking': 'LPK-20261126-12345',
      'peminjam_id': 'user-id',
      'kategori': 'praktik',
      'nama_kegiatan': 'Kegiatan kelas',
      'mulai_pada': '2026-11-25T09:00:00Z',
      'estimasi_kembali_pada': '2026-11-25T12:00:00Z',
      'status': 'ditolak',
      'diajukan_pada': '2026-11-24T08:00:00Z',
      'dibuat_pada': '2026-11-24T08:00:00Z',
      'pengguna': {
        'nama_lengkap': 'Nama Peminjam',
        'foto_url': 'https://example.com/avatar.png',
      },
      'persetujuan_peminjaman': [
        {'alasan_penolakan': 'Jadwal tidak tersedia'},
      ],
      'item_peminjaman': [
        {
          'id': 'item-id',
          'fasilitas_id': 'asset-id',
          'nama_fasilitas_snapshot': 'Proyektor',
          'jumlah': 1,
          'fasilitas': {'foto_url': 'https://example.com/proyektor.png'},
        },
      ],
    });

    expect(borrowing.alasanPenolakan, 'Jadwal tidak tersedia');
    expect(borrowing.fotoUrlPeminjam, 'https://example.com/avatar.png');
    expect(borrowing.items.single.fasilitasId, 'asset-id');
    expect(borrowing.items.single.fotoUrl, 'https://example.com/proyektor.png');
  });

  test('maps return review, penalty, and evidence fields', () {
    final borrowing = Peminjaman.fromMap({
      'id': 'booking-id',
      'kode_booking': 'LPK-20261126-12345',
      'peminjam_id': 'user-id',
      'kategori': 'praktik',
      'nama_kegiatan': 'Kegiatan kelas',
      'mulai_pada': '2026-11-25T09:00:00Z',
      'estimasi_kembali_pada': '2026-11-25T12:00:00Z',
      'status': 'pelanggaran',
      'diajukan_pada': '2026-11-24T08:00:00Z',
      'dibuat_pada': '2026-11-24T08:00:00Z',
      'return_requested_at': '2026-11-25T12:30:00Z',
      'return_inspections': [
        {
          'id': 'old-inspection-id',
          'status': 'selesai',
          'kondisi_barang': 'baik',
          'jenis_pelanggaran': null,
          'denda': 0,
          'updated_at': '2026-11-25T12:00:00Z',
          'return_documentation': [],
        },
        {
          'id': 'inspection-id',
          'status': 'menunggu_pembayaran',
          'updated_at': '2026-11-25T13:00:00Z',
          'kondisi_barang': 'terlambat',
          'jenis_pelanggaran': 'terlambat',
          'denda': 75000,
          'keterangan_pelanggaran': 'Dikembalikan melewati batas waktu.',
          'status_pembayaran': 'menunggu_pembayaran',
          'diperiksa_pada': '2026-11-25T13:00:00Z',
          'dibayar_pada': null,
          'return_documentation': [
            {
              'file_id': 'evidence-1',
              'jenis': 'photo',
              'file_name': 'kondisi.jpg',
              'file_path': '/api/v1/inspections/id/file/evidence-1',
              'mime_type': 'image/jpeg',
              'ukuran_byte': 1024,
            },
          ],
        },
      ],
      'item_peminjaman': [],
    });

    expect(borrowing.status, StatusPeminjaman.pelanggaran);
    expect(
      borrowing.dimintaKembaliPada,
      DateTime.parse('2026-11-25T12:30:00Z'),
    );
    expect(borrowing.pemeriksaanPengembalian?.denda, 75000);
    expect(
      borrowing.pemeriksaanPengembalian?.bukti.single.namaFile,
      'kondisi.jpg',
    );
  });

  test('summarizes completed return condition and penalty', () {
    final cases = {
      'baik': ('Selesai', 'Pengembalian selesai', 'Tidak ada'),
      'rusak': ('Pelanggaran Selesai', 'Pelanggaran diselesaikan', 'Rp120.000'),
      'hilang': ('Hilang', 'Pelanggaran diselesaikan', 'Rp120.000'),
      'terlambat': (
        'Terlambat Selesai',
        'Pelanggaran diselesaikan',
        'Rp120.000',
      ),
    };

    for (final entry in cases.entries) {
      final hasViolation = entry.key != 'baik';
      final inspection = PemeriksaanPengembalian(
        id: 'inspection-${entry.key}',
        status: 'selesai',
        kondisiBarang: entry.key,
        jenisPelanggaran: hasViolation ? entry.key : null,
        denda: hasViolation ? 120000 : 0,
        keterangan: null,
        statusPembayaran: hasViolation ? 'dikonfirmasi' : 'tidak_ada',
        diperiksaPada: null,
        dibayarPada: null,
        pembayaranDikonfirmasiOleh: null,
        bukti: const [],
      );

      expect(inspection.labelStatusAkhir, entry.value.$1);
      expect(inspection.labelHasil, entry.value.$2);
      expect(inspection.labelDenda, entry.value.$3);
    }
  });
}
