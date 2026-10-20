import 'package:flutter/material.dart';

class BantuanPicModal extends StatelessWidget {
  const BantuanPicModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Pilih Bantuan PIC',
                        style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                      SizedBox(height: 2),
                      Text('Hubungi penanggung jawab unit sarana terkait',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
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

            // List PIC Cards
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _buildPicCard(
                      context,
                      icon: Icons.terminal,
                      iconColor: const Color(0xFF0037B0),
                      iconBg: const Color(0xFF0037B0).withValues(alpha: 0.1),
                      title: 'PIC Lab RPL',
                      subtitle: 'Pak Budi Santoso, S.Kom • Lab 1 & 2',
                      status: 'Online',
                      isOnline: true,
                      desc: 'Peminjaman PC workstation, drawing tablet wacom, lisensi IDE, & jadwal lab praktikum.',
                    ),
                    const SizedBox(height: 12),
                    _buildPicCard(
                      context,
                      icon: Icons.domain,
                      iconColor: const Color(0xFF505F76),
                      iconBg: const Color(0xFFD0E1FB),
                      title: 'PIC Sarpras Utama Sekolah',
                      subtitle: 'Ibu Sri Wahyuni, M.Pd • Ruang Logistik',
                      status: 'Jam Kerja',
                      isOnline: true,
                      desc: 'Peminjaman proyektor aula, kamera dokumentasi, wireless mic, tenda kegiatan, & genset.',
                    ),
                    const SizedBox(height: 12),
                    _buildPicCard(
                      context,
                      icon: Icons.precision_manufacturing,
                      iconColor: const Color(0xFF38485D),
                      iconBg: const Color(0xFFDAE2FD),
                      title: 'PIC Bengkel Mekatronika (Metro)',
                      subtitle: 'Pak Hendra Wijaya, S.T • Workshop Lt. 1',
                      status: 'Di Bengkel',
                      isOnline: false,
                      desc: 'Peralatan kit robotika, modul sensor IoT, osiloskop, solder station, & peralatan ukur teknik.',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Info Banner
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user, size: 20, color: Color(0xFF0037B0)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Semua kontak terverifikasi resmi oleh manajemen Sarpras SMKN 8 Malang untuk kemudahan siswa.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF434655), height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Close Button
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

  Widget _buildPicCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required String status,
    required bool isOnline,
    required String desc,
  }) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Menghubungi $title via WhatsApp...'), behavior: SnackBarBehavior.floating),
        );
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 22),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF0F172A), fontFamily: 'Outfit')),
                      const SizedBox(height: 2),
                      Text(subtitle,
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: isOnline ? const Color(0xFF004F35).withValues(alpha: 0.1) : const Color(0xFFD0E1FB),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(
                          color: isOnline ? const Color(0xFF006A48) : const Color(0xFF1D4ED8),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(status,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: isOnline ? const Color(0xFF004F35) : const Color(0xFF54647A),
                        )),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(desc, style: const TextStyle(fontSize: 11, color: Color(0xFF475569), height: 1.4)),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Hubungi via WhatsApp',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8))),
                Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF1D4ED8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
