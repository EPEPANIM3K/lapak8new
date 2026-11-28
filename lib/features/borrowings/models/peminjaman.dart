// lib/features/borrowings/models/peminjaman.dart
// Model untuk sistem peminjaman — mengikuti skema database baru (Indonesia).

// ---------------------------------------------------------------------------
// Fasilitas ringkas (untuk dropdown form peminjaman)
// ---------------------------------------------------------------------------
class FasilitasRingkas {
  const FasilitasRingkas({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.lokasi,
    required this.totalUnit,
    required this.status,
    this.unitTersedia = 0,
    this.fotoUrl,
  });

  final String id;
  final String nama;
  final String kategori;
  final String lokasi; // nama lokasi (join dari tabel lokasi)
  final int totalUnit;
  final int unitTersedia;
  final String status; // 'tersedia' | 'pemeliharaan' | 'tidak_aktif'
  final String? fotoUrl;

  bool get tersedia => status == 'tersedia' && unitTersedia > 0;
  bool get isRuangan => kategori.trim().toLowerCase() == 'ruangan';

  factory FasilitasRingkas.fromMap(Map<String, dynamic> map) {
    final lokasi = map['lokasi'] as Map<String, dynamic>?;
    return FasilitasRingkas(
      id: map['id'] as String,
      nama: map['nama'] as String,
      kategori: map['kategori'] as String? ?? '',
      lokasi: lokasi?['nama'] as String? ?? '-',
      totalUnit: (map['total_unit'] as num).toInt(),
      unitTersedia: (map['unit_tersedia'] as num?)?.toInt() ?? 0,
      status: map['status'] as String,
      fotoUrl: map['foto_url'] as String?,
    );
  }
}

class ItemPeminjamanInput {
  const ItemPeminjamanInput({
    required this.fasilitasId,
    required this.namaFasilitas,
    required this.jumlah,
  });

  final String fasilitasId;
  final String namaFasilitas;
  final int jumlah;
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
  menungguPengembalian,
  pelanggaran,
  dikembalikan,
  terlambat,
  // ignore: constant_identifier_names
  tidak_dikenal;

  static StatusPeminjaman dariString(String nilai) => switch (nilai) {
    'menunggu_persetujuan' => menungguPersetujuan,
    'disetujui' => disetujui,
    'ditolak' => ditolak,
    'dibatalkan' => dibatalkan,
    'dipinjam' => dipinjam,
    'menunggu_pengembalian' => menungguPengembalian,
    'pelanggaran' => pelanggaran,
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
    StatusPeminjaman.menungguPengembalian => 'menunggu_pengembalian',
    StatusPeminjaman.pelanggaran => 'pelanggaran',
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
    StatusPeminjaman.menungguPengembalian => 'Menunggu Pengembalian',
    StatusPeminjaman.pelanggaran => 'Pelanggaran',
    StatusPeminjaman.dikembalikan => 'Selesai',
    StatusPeminjaman.terlambat => 'Terlambat',
    StatusPeminjaman.tidak_dikenal => 'Tidak Dikenal',
  };
}

class BuktiPemeriksaanPengembalian {
  const BuktiPemeriksaanPengembalian({
    required this.fileId,
    required this.jenis,
    required this.namaFile,
    required this.path,
    required this.mimeType,
    required this.ukuranByte,
  });

  final String fileId;
  final String jenis;
  final String namaFile;
  final String path;
  final String mimeType;
  final int ukuranByte;

  factory BuktiPemeriksaanPengembalian.fromMap(Map<String, dynamic> map) =>
      BuktiPemeriksaanPengembalian(
        fileId: map['file_id'] as String? ?? '',
        jenis: map['jenis'] as String? ?? 'photo',
        namaFile: map['file_name'] as String? ?? 'Bukti',
        path: map['file_path'] as String? ?? '',
        mimeType: map['mime_type'] as String? ?? 'application/octet-stream',
        ukuranByte: (map['ukuran_byte'] as num?)?.toInt() ?? 0,
      );
}

class PemeriksaanPengembalian {
  const PemeriksaanPengembalian({
    required this.id,
    required this.status,
    required this.kondisiBarang,
    required this.jenisPelanggaran,
    required this.denda,
    required this.keterangan,
    required this.statusPembayaran,
    required this.diperiksaPada,
    required this.dibayarPada,
    required this.pembayaranDikonfirmasiOleh,
    required this.bukti,
  });

  final String id;
  final String status;
  final String? kondisiBarang;
  final String? jenisPelanggaran;
  final int denda;
  final String? keterangan;
  final String statusPembayaran;
  final DateTime? diperiksaPada;
  final DateTime? dibayarPada;
  final String? pembayaranDikonfirmasiOleh;
  final List<BuktiPemeriksaanPengembalian> bukti;

  String get labelKondisi =>
      switch ((kondisiBarang ?? jenisPelanggaran)?.toLowerCase()) {
        'baik' => 'Baik',
        'rusak' => 'Rusak',
        'hilang' => 'Hilang',
        'terlambat' => 'Terlambat',
        _ => 'Tidak diketahui',
      };

  String get labelStatusAkhir =>
      switch ((kondisiBarang ?? jenisPelanggaran)?.toLowerCase()) {
        'rusak' => 'Pelanggaran Selesai',
        'hilang' => 'Hilang',
        'terlambat' => 'Terlambat Selesai',
        _ => 'Selesai',
      };

  bool get hasPelanggaran {
    final condition = (kondisiBarang ?? jenisPelanggaran)?.toLowerCase();
    return jenisPelanggaran != null ||
        denda > 0 ||
        (condition != null && condition != 'baik');
  }

  String get labelHasil =>
      hasPelanggaran ? 'Pelanggaran diselesaikan' : 'Pengembalian selesai';

  String get labelDenda {
    if (denda <= 0) return 'Tidak ada';
    final digits = denda.toString();
    final grouped = StringBuffer();
    for (var index = 0; index < digits.length; index++) {
      if (index > 0 && (digits.length - index) % 3 == 0) grouped.write('.');
      grouped.write(digits[index]);
    }
    return 'Rp$grouped';
  }

  factory PemeriksaanPengembalian.fromMap(Map<String, dynamic> map) {
    DateTime? date(String key) {
      final value = map[key];
      return value is String ? DateTime.tryParse(value) : null;
    }

    final evidence = map['return_documentation'];
    return PemeriksaanPengembalian(
      id: map['id'] as String,
      status: map['status'] as String? ?? 'menunggu',
      kondisiBarang: map['kondisi_barang'] as String?,
      jenisPelanggaran: map['jenis_pelanggaran'] as String?,
      denda: (map['denda'] as num?)?.round() ?? 0,
      keterangan: map['keterangan_pelanggaran'] as String?,
      statusPembayaran: map['status_pembayaran'] as String? ?? 'tidak_ada',
      diperiksaPada: date('diperiksa_pada'),
      dibayarPada: date('dibayar_pada'),
      pembayaranDikonfirmasiOleh:
          map['pembayaran_dikonfirmasi_oleh'] as String?,
      bukti: evidence is List
          ? evidence
                .whereType<Map<String, dynamic>>()
                .map(BuktiPemeriksaanPengembalian.fromMap)
                .toList(growable: false)
          : const [],
    );
  }
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
    this.dimintaKembaliPada,
    this.kondisiBarang,
    this.catatanPengembalian,
    this.pemeriksaanPengembalian,
    this.namaPeminjam,
    this.fotoUrlPeminjam,
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
  final DateTime? dimintaKembaliPada;
  final String? kondisiBarang; // 'baik' | 'rusak' | 'hilang'
  final String? catatanPengembalian;
  final PemeriksaanPengembalian? pemeriksaanPengembalian;
  final DateTime dibuatPada;

  // Data join (opsional, dimuat bersama query)
  final String? namaPeminjam;
  final String? fotoUrlPeminjam;
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
    final rawInspections = map['return_inspections'];
    Map<String, dynamic>? inspectionMap;
    if (rawInspections is List) {
      final inspections = rawInspections
          .whereType<Map<String, dynamic>>()
          .toList();
      DateTime inspectionTime(Map<String, dynamic> inspection) =>
          DateTime.tryParse(
            (inspection['updated_at'] ?? inspection['dibuat_pada'] ?? '')
                .toString(),
          ) ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
      inspections.sort(
        (a, b) => inspectionTime(b).compareTo(inspectionTime(a)),
      );
      if (inspections.isNotEmpty) {
        inspectionMap = inspections.first;
      }
    } else if (rawInspections is Map<String, dynamic>) {
      inspectionMap = rawInspections;
    }
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
      dimintaKembaliPada: tanggal('return_requested_at'),
      kondisiBarang: map['kondisi_barang'] as String?,
      catatanPengembalian: map['catatan_pengembalian'] as String?,
      pemeriksaanPengembalian: inspectionMap == null
          ? null
          : PemeriksaanPengembalian.fromMap(inspectionMap),
      dibuatPada: DateTime.parse(map['dibuat_pada'] as String),
      namaPeminjam: peminjam?['nama_lengkap'] as String?,
      fotoUrlPeminjam: peminjam?['foto_url'] as String?,
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
