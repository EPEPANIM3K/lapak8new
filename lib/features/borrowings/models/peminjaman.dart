// lib/features/borrowings/models/peminjaman.dart
// Model untuk sistem peminjaman — mengikuti skema database baru (Indonesia).

// ---------------------------------------------------------------------------
// Fasilitas ringkas (untuk dropdown form peminjaman)
// ---------------------------------------------------------------------------
class FasilitasRingkas {
  const FasilitasRingkas({
    required this.id,
    required this.nama,
    required this.lokasi,
    required this.totalUnit,
    required this.status,
    this.fotoUrl,
  });

  final String id;
  final String nama;
  final String lokasi; // nama lokasi (join dari tabel lokasi)
  final int totalUnit;
  final String status; // 'tersedia' | 'pemeliharaan' | 'tidak_aktif'
  final String? fotoUrl;

  bool get tersedia => status == 'tersedia' && totalUnit > 0;

  factory FasilitasRingkas.fromMap(Map<String, dynamic> map) {
    final lokasi = map['lokasi'] as Map<String, dynamic>?;
    return FasilitasRingkas(
      id: map['id'] as String,
      nama: map['nama'] as String,
      lokasi: lokasi?['nama'] as String? ?? '-',
      totalUnit: (map['total_unit'] as num).toInt(),
      status: map['status'] as String,
      fotoUrl: map['foto_url'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Item dalam satu peminjaman
// ---------------------------------------------------------------------------
class ItemPeminjaman {
  const ItemPeminjaman({
    required this.id,
    required this.fasilitasId,
    required this.namaFasilitasSnapshot,
    required this.jumlah,
    this.fotoUrl,
  });

  final String id;
  final String fasilitasId;
  final String namaFasilitasSnapshot;
  final int jumlah;
  final String? fotoUrl;

  factory ItemPeminjaman.fromMap(Map<String, dynamic> map) => ItemPeminjaman(
    id: map['id'] as String,
    fasilitasId: map['fasilitas_id'] as String,
    namaFasilitasSnapshot: map['nama_fasilitas_snapshot'] as String,
    jumlah: (map['jumlah'] as num).toInt(),
    fotoUrl:
        (map['fasilitas'] as Map<String, dynamic>?)?['foto_url'] as String?,
  );
}

// ---------------------------------------------------------------------------
// Status peminjaman
// ---------------------------------------------------------------------------
enum StatusPeminjaman {
  menungguPersetujuan,
  disetujui,
  ditolak,
  dibatalkan,
  dipinjam,
  dikembalikan,
  terlambat,
  tidak_dikenal;

  static StatusPeminjaman dariString(String nilai) => switch (nilai) {
    'menunggu_persetujuan' => menungguPersetujuan,
    'disetujui' => disetujui,
    'ditolak' => ditolak,
    'dibatalkan' => dibatalkan,
    'dipinjam' => dipinjam,
    'dikembalikan' => dikembalikan,
    'terlambat' => terlambat,
    _ => tidak_dikenal,
  };

  String get nilaiDb => switch (this) {
    StatusPeminjaman.menungguPersetujuan => 'menunggu_persetujuan',
    StatusPeminjaman.disetujui => 'disetujui',
    StatusPeminjaman.ditolak => 'ditolak',
    StatusPeminjaman.dibatalkan => 'dibatalkan',
    StatusPeminjaman.dipinjam => 'dipinjam',
    StatusPeminjaman.dikembalikan => 'dikembalikan',
    StatusPeminjaman.terlambat => 'terlambat',
    StatusPeminjaman.tidak_dikenal => 'tidak_dikenal',
  };

  String get label => switch (this) {
    StatusPeminjaman.menungguPersetujuan => 'Menunggu Persetujuan',
    StatusPeminjaman.disetujui => 'Disetujui',
    StatusPeminjaman.ditolak => 'Ditolak',
    StatusPeminjaman.dibatalkan => 'Dibatalkan',
    StatusPeminjaman.dipinjam => 'Sedang Dipinjam',
    StatusPeminjaman.dikembalikan => 'Dikembalikan',
    StatusPeminjaman.terlambat => 'Terlambat',
    StatusPeminjaman.tidak_dikenal => 'Tidak Dikenal',
  };
}

// ---------------------------------------------------------------------------
// Model utama Peminjaman
// ---------------------------------------------------------------------------
class Peminjaman {
  const Peminjaman({
    required this.id,
    required this.kodeBooking,
    required this.peminjamId,
    required this.kategori,
    required this.namaKegiatan,
    required this.mulaiPada,
    required this.estimasiKembaliPada,
    required this.status,
    required this.diajukanPada,
    required this.dibuatPada,
    this.catatanTujuan,
    this.alasanPenolakan,
    this.disetujuiPada,
    this.diambilPada,
    this.dikembalikanPada,
    this.namaPeminjam,
    this.nomorIndukPeminjam,
    this.kelasPeminjam,
    this.items = const [],
  });

  final String id;
  final String kodeBooking;
  final String peminjamId;
  final String kategori;
  final String namaKegiatan;
  final String? catatanTujuan;
  final DateTime mulaiPada;
  final DateTime estimasiKembaliPada;
  final StatusPeminjaman status;
  final String? alasanPenolakan;
  final DateTime diajukanPada;
  final DateTime? disetujuiPada;
  final DateTime? diambilPada;
  final DateTime? dikembalikanPada;
  final DateTime dibuatPada;

  // Data join (opsional, dimuat bersama query)
  final String? namaPeminjam;
  final String? nomorIndukPeminjam;
  final String? kelasPeminjam;
  final List<ItemPeminjaman> items;

  String get labelKategori => switch (kategori) {
    'praktik' => 'Praktik',
    'ekskul' => 'Ekskul / IT',
    _ => 'Lainnya',
  };

  factory Peminjaman.fromMap(Map<String, dynamic> map) {
    DateTime? tanggal(String key) {
      final v = map[key];
      if (v == null) return null;
      return DateTime.tryParse(v as String);
    }

    final peminjam = map['pengguna'] as Map<String, dynamic>?;
    final rawItems = map['item_peminjaman'] as List<dynamic>?;
    final rawApprovals = map['persetujuan_peminjaman'] as List<dynamic>?;
    final rejectionReason =
        map['alasan_penolakan'] as String? ??
        rawApprovals
            ?.whereType<Map>()
            .map((approval) => approval['alasan_penolakan'])
            .whereType<String>()
            .firstWhere((reason) => reason.trim().isNotEmpty, orElse: () => '');

    return Peminjaman(
      id: map['id'] as String,
      kodeBooking: map['kode_booking'] as String,
      peminjamId: map['peminjam_id'] as String,
      kategori: map['kategori'] as String,
      namaKegiatan: map['nama_kegiatan'] as String,
      catatanTujuan: map['catatan_tujuan'] as String?,
      mulaiPada: DateTime.parse(map['mulai_pada'] as String),
      estimasiKembaliPada: DateTime.parse(
        map['estimasi_kembali_pada'] as String,
      ),
      status: StatusPeminjaman.dariString(map['status'] as String),
      alasanPenolakan: rejectionReason?.isEmpty == true
          ? null
          : rejectionReason,
      diajukanPada: DateTime.parse(map['diajukan_pada'] as String),
      disetujuiPada: tanggal('disetujui_pada'),
      diambilPada: tanggal('diambil_pada'),
      dikembalikanPada: tanggal('dikembalikan_pada'),
      dibuatPada: DateTime.parse(map['dibuat_pada'] as String),
      namaPeminjam: peminjam?['nama_lengkap'] as String?,
      nomorIndukPeminjam: peminjam?['nomor_induk'] as String?,
      kelasPeminjam: peminjam?['kelas_atau_unit'] as String?,
      items:
          rawItems
              ?.map((e) => ItemPeminjaman.fromMap(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }
}
