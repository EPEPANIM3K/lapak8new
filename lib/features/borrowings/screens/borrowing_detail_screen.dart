// lib/features/borrowings/screens/borrowing_detail_screen.dart
// Detail peminjaman — ditampilkan sebagai bottom sheet.

import 'package:flutter/material.dart';

import '../models/peminjaman.dart';


class BorrowingDetailSheet extends StatelessWidget {
  const BorrowingDetailSheet({super.key, required this.peminjaman});

  final Peminjaman peminjaman;

  static const _primary          = Color(0xFF0037B0);
  static const _surfaceLow       = Color(0xFFF2F3FF);
  static const _surfaceLowest    = Color(0xFFFFFFFF);
  static const _onSurface        = Color(0xFF131B2E);
  static const _onSurfaceVariant = Color(0xFF434655);
  static const _error            = Color(0xFFBA1A1A);
  static const _outline          = Color(0xFFC4C5D7);

  Color _statusColor(StatusPeminjaman s) => switch (s) {
    StatusPeminjaman.menungguPersetujuan => const Color(0xFFB45309),
    StatusPeminjaman.disetujui           => const Color(0xFF065F46),
    StatusPeminjaman.dipinjam            => _primary,
    StatusPeminjaman.dikembalikan        => const Color(0xFF065F46),
    StatusPeminjaman.ditolak             => _error,
    StatusPeminjaman.dibatalkan          => const Color(0xFF64748B),
    StatusPeminjaman.terlambat           => _error,
    _                                    => _onSurfaceVariant,
  };

  @override
  Widget build(BuildContext context) {
    final p = peminjaman;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: _surfaceLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              // Handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: _outline,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.kodeBooking,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: _onSurface,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(p.status).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              p.status.label,
                              style: TextStyle(
                                color: _statusColor(p.status),
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Konten
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _SectionTitle('Informasi Kegiatan'),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Kategori',    value: p.labelKategori),
                    _InfoRow(label: 'Nama Acara',  value: p.namaKegiatan),
                    if (p.catatanTujuan != null && p.catatanTujuan!.isNotEmpty)
                      _InfoRow(label: 'Catatan',   value: p.catatanTujuan!),
                    const SizedBox(height: 20),

                    _SectionTitle('Waktu Peminjaman'),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Mulai',      value: _fmtDt(p.mulaiPada)),
                    _InfoRow(label: 'Estimasi Kembali', value: _fmtDt(p.estimasiKembaliPada)),
                    if (p.diambilPada != null)
                      _InfoRow(label: 'Diambil',  value: _fmtDt(p.diambilPada!)),
                    if (p.dikembalikanPada != null)
                      _InfoRow(label: 'Dikembalikan', value: _fmtDt(p.dikembalikanPada!)),
                    const SizedBox(height: 20),

                    if (p.items.isNotEmpty) ...[
                      _SectionTitle('Item Dipinjam'),
                      const SizedBox(height: 8),
                      for (final item in p.items)
                        Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: _surfaceLow,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.inventory_2, color: _primary, size: 20),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.namaFasilitasSnapshot,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: _onSurface,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.jumlah} unit',
                                style: const TextStyle(color: _onSurfaceVariant, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],

                    _SectionTitle('Riwayat Status'),
                    const SizedBox(height: 8),
                    _InfoRow(label: 'Diajukan',   value: _fmtDt(p.diajukanPada)),
                    if (p.disetujuiPada != null)
                      _InfoRow(label: 'Disetujui', value: _fmtDt(p.disetujuiPada!)),
                    if (p.alasanPenolakan != null && p.alasanPenolakan!.isNotEmpty)
                      _InfoRow(label: 'Alasan Penolakan', value: p.alasanPenolakan!),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtDt(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','Mei','Jun','Jul','Agu','Sep','Okt','Nov','Des'];
    return '${dt.day} ${months[dt.month - 1]} ${dt.year}, '
        '${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 14,
      color: Color(0xFF131B2E),
    ),
  );
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: Color(0xFF434655)),
            ),
          ),
          const Text(': ', style: TextStyle(color: Color(0xFF434655))),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF131B2E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
