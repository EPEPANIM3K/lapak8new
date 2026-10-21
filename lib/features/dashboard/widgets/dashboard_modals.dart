import 'package:flutter/material.dart';

// ==========================================
// 1. MODAL JADWAL AULA (JAM OPERASIONAL)
// ==========================================
class AulaScheduleModal extends StatefulWidget {
  const AulaScheduleModal({super.key});

  @override
  State<AulaScheduleModal> createState() => _AulaScheduleModalState();
}

class _AulaScheduleModalState extends State<AulaScheduleModal> {
  // State untuk tab yang dipilih (0: Senin-Kamis, 1: Jumat, 2: Sabtu)
  int _selectedTab = 0;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFF2563EB), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text(
                              'Jam Operasional Fasilitas',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1D4ED8)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Jadwal Buka & Tutup',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Jam Operasional Layanan Sarpras & Lab SMKN 8 Malang',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Tombol Close
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- Tabs ---
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTab(0, 'Senin - Kamis'),
                  const SizedBox(width: 8),
                  _buildTab(1, 'Jumat'),
                  const SizedBox(width: 8),
                  _buildTab(2, 'Sabtu / Libur'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // --- List Jadwal ---
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildScheduleCard(
                      time: '07:00 - 15:30 WIB',
                      status: 'Buka Sekarang',
                      isOpen: true,
                      isPulsing: true,
                      title: 'Ruang Layanan Sarpras & Teknisi',
                      desc: 'Pengambilan & pengembalian barang, e-tiket QR',
                      isBlue: false,
                    ),
                    const SizedBox(height: 10),
                    _buildScheduleCard(
                      time: '07:30 - 16:00 WIB',
                      status: 'Buka',
                      isOpen: true,
                      title: 'Laboratorium RPL (Lab 1 & Lab 2)',
                      desc: 'Praktik pemrograman, sertifikasi & peminjaman alat',
                      isBlue: false,
                    ),
                    const SizedBox(height: 10),
                    _buildScheduleCard(
                      time: '07:30 - 15:30 WIB',
                      status: 'Buka',
                      isOpen: true,
                      title: 'Laboratorium TKJ & Jaringan',
                      desc: 'Peminjaman toolkit, kabel tester, dan perangkat jaringan',
                      isBlue: false,
                    ),
                    const SizedBox(height: 10),
                    _buildScheduleCard(
                      time: '08:00 - 17:00 WIB',
                      status: 'Khusus Booking',
                      isOpen: true,
                      title: 'Aula Utama Serbaguna',
                      desc: 'Wajib reservasi H-1 sebelum penggunaan ruangan',
                      isBlue: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Footer Buttons ---
            Container(
              padding: const EdgeInsets.only(top: 16),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: Color(0xFFF1F5F9), width: 1)),
              ),
              child: Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Ajukan Peminjaman', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 40,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFFF1F5F9),
                        foregroundColor: const Color(0xFF475569),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                      child: const Text('Tutup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1D4ED8) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard({
    required String time,
    required String status,
    required bool isOpen,
    required String title,
    required String desc,
    bool isPulsing = false,
    bool isBlue = false,
  }) {
    final bgColor = isBlue ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5);
    final borderColor = isBlue ? const Color(0xFFBFDBFE) : const Color(0xFFA7F3D0);
    final textColor = isBlue ? const Color(0xFF1E40AF) : const Color(0xFF065F46);
    final iconColor = isBlue ? const Color(0xFF2563EB) : const Color(0xFF059669);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.schedule, size: 14, color: iconColor),
                  const SizedBox(width: 4),
                  Text(time, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor, fontFamily: 'monospace')),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isBlue ? const Color(0xFFDBEAFE) : const Color(0xFFD1FAE5),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPulsing)
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                      )
                    else
                      Icon(Icons.circle, size: 6, color: iconColor),
                    const SizedBox(width: 4),
                    Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF475569))),
        ],
      ),
    );
  }
}


// ==========================================
// 2. MODAL PERATURAN PEMINJAMAN
// ==========================================
class PeraturanModal extends StatelessWidget {
  const PeraturanModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 6, height: 6, decoration: const BoxDecoration(color: Color(0xFFF59E0B), shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            const Text(
                              'Tata Tertib & Ketentuan',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFFB45309)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Peraturan Peminjaman',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'SOP Sarana & Prasarana SMKN 8 Malang',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                // Tombol Close
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // --- List Rules ---
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildRuleItem(
                      icon: Icons.assignment,
                      title: '1. Pengajuan & Persetujuan',
                      desc: 'Booking wajib diajukan minimal H-1 sebelum pemakaian dan telah disetujui PIC Sarpras.',
                    ),
                    const SizedBox(height: 10),
                    _buildRuleItem(
                      icon: Icons.badge,
                      title: '2. Pengambilan & E-Tiket',
                      desc: 'Tunjukkan QR Tiket dan Kartu Pelajar saat pengambilan barang di ruang teknisi.',
                    ),
                    const SizedBox(height: 10),
                    _buildRuleItem(
                      icon: Icons.schedule,
                      title: '3. Ketepatan Waktu & Cek Fisik',
                      desc: 'Pengembalian maksimal 15 menit sebelum jam operasional berakhir. Cek kondisi fisik bersama petugas.',
                    ),
                    const SizedBox(height: 10),
                    _buildRuleItem(
                      icon: Icons.warning_amber_rounded,
                      title: '4. Tanggung Jawab & Denda',
                      desc: 'Kerusakan atau kehilangan sarpras menjadi tanggung jawab peminjam sesuai SOP sekolah.',
                      isWarning: true,
                    ),
                    const SizedBox(height: 16),

                    // --- Info Box ---
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF).withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFDBEAFE)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline, size: 18, color: Color(0xFF1D4ED8)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Butuh perpanjangan waktu? Hubungi PIC Sarpras melalui fitur Chat Bantuan.',
                              style: TextStyle(fontSize: 10, color: Color(0xFF1E3A8A), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // --- Footer Buttons ---
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.check_circle, size: 16),
                      label: const Text('Saya Mengerti & Setuju', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.w600, fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1D4ED8),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  backgroundColor: const Color(0xFFF1F5F9),
                  foregroundColor: const Color(0xFF475569),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Tutup', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRuleItem({
    required IconData icon,
    required String title,
    required String desc,
    bool isWarning = false,
  }) {
    final iconColor = isWarning ? const Color(0xFFD97706) : const Color(0xFF1D4ED8);
    final iconBg = isWarning ? const Color(0xFFFFFBEB) : const Color(0xFFEFF6FF);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(fontSize: 10, color: Color(0xFF475569), height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}