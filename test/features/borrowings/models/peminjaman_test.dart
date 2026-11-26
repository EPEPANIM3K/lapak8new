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
    expect(borrowing.items.single.fasilitasId, 'asset-id');
    expect(borrowing.items.single.fotoUrl, 'https://example.com/proyektor.png');
  });
}
