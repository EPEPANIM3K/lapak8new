class LokasiItem {
  const LokasiItem({
    required this.id,
    required this.nama,
  });

  final String id;
  final String nama;

  factory LokasiItem.fromMap(Map<String, dynamic> map) => LokasiItem(
        id: map['id'] as String,
        nama: map['nama'] as String? ?? '-',
      );
}

class Facility {
  const Facility({
    required this.id,
    required this.nama,
    required this.kategori,
    required this.lokasiId,
    required this.lokasiNama,
    required this.totalUnit,
    required this.unitTersedia,
    required this.status,
    required this.aktif,
    this.fotoUrl,
    this.deskripsi,
  });

  final String id;
  final String nama;
  final String kategori;
  final String? lokasiId;
  final String lokasiNama;
  final int totalUnit;
  final int unitTersedia;
  final String status; // 'tersedia' | 'pemeliharaan' | 'tidak_aktif'
  final bool aktif;
  final String? fotoUrl;
  final String? deskripsi;

  bool get isAvailable => aktif && status == 'tersedia' && unitTersedia > 0;
  int get unitDipinjam => (totalUnit - unitTersedia).clamp(0, totalUnit);

  factory Facility.fromMap(Map<String, dynamic> map) {
    final lokasiObj = map['lokasi'];
    String? locId = map['lokasi_id'] as String?;
    String locName = '-';
    if (lokasiObj is Map<String, dynamic>) {
      locId ??= lokasiObj['id'] as String?;
      locName = (lokasiObj['nama'] as String?) ?? '-';
    } else if (map['lokasi_nama'] is String) {
      locName = map['lokasi_nama'] as String;
    }

    final total = (map['total_unit'] as num?)?.toInt() ?? 0;
    final availableRaw = (map['unit_tersedia'] as num?)?.toInt() ??
        (map['tersedia_unit'] as num?)?.toInt();
    final status = (map['status'] as String?) ?? 'tersedia';
    final aktif = (map['aktif'] as bool?) ?? true;
    final available = availableRaw ?? (status == 'tersedia' && aktif ? total : 0);

    final rawCat = (map['kategori'] as String?) ??
        (map['subjudul'] as String?) ??
        (map['merk'] as String?) ??
        '';

    return Facility(
      id: map['id'] as String,
      nama: (map['nama'] as String?) ?? 'Tanpa Nama',
      kategori: rawCat.trim().isEmpty ? 'SARPRAS UMUM' : rawCat.trim().toUpperCase(),
      lokasiId: locId,
      lokasiNama: locName,
      totalUnit: total,
      unitTersedia: available,
      status: status,
      aktif: aktif,
      fotoUrl: map['foto_url'] as String?,
      deskripsi: map['deskripsi'] as String?,
    );
  }
}
