import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/lapak_header.dart';
import '../../dashboard/widgets/qr_ticket_modal.dart';

class MyBorrowingsScreen extends StatefulWidget {
  const MyBorrowingsScreen({super.key});
  @override
  State<MyBorrowingsScreen> createState() => _MyBorrowingsScreenState();
}

class _MyBorrowingsScreenState extends State<MyBorrowingsScreen> {
  static const _avatarUrl =
      'https://lh3.googleusercontent.com/aida-public/AB6AXuCM9TBr73lAvJae_M-j8bVPXa69t9E8fJjw6s1fOkJB9Rwn5SdnSrc2vwOfl_FwiSc0PAsKLZ3OrWbOxQRw_0Nv8TltDOZ-YW8v68X2WTQJl29s3nRn2_K2GuSWHAvMZpMCZJe6iBeZDp5yEl_7IcjmKNNuCgejx9XkiISbISzKzJKsN4oi8-ZVu-ddev07E4AA7eAz81C-Lou8NTkx4lFKRMgys8zcncLJEU3cjaxS9X4CrRZuET7Y';

  static const cSurface = Color(0xFFFAF8FF);
  static const cSurfaceLowest = Color(0xFFFFFFFF);
  static const cSurfaceLow = Color(0xFFF2F3FF);
  static const cSurfaceContainer = Color(0xFFEAEDFF);
  static const cSurfaceHigh = Color(0xFFE2E7FF);
  static const cOnSurface = Color(0xFF131B2E);
  static const cOnSurfaceVariant = Color(0xFF434655);
  static const cPrimary = Color(0xFF0037B0);
  static const cPrimaryContainer = Color(0xFF1D4ED8);
  static const cPrimaryFixed = Color(0xFFDCE1FF);
  static const cTertiary = Color(0xFF004F35);
  static const cTertiaryContainer = Color(0xFF006A48);
  static const cTertiaryFixed = Color(0xFF6FFBBE);
  static const cError = Color(0xFFBA1A1A);
  static const cErrorContainer = Color(0xFFFFDAD6);
  static const cOnErrorContainer = Color(0xFF93000A);
  static const cSecondary = Color(0xFF505F76);
  static const cSecondaryContainer = Color(0xFFD0E1FB);
  static const cOnSecondaryContainer = Color(0xFF54647A);
  static const cOutlineVariant = Color(0xFFC4C5D7);

  String _tab = 'aktif';

  void _switchTab(String t) => setState(() => _tab = t);

  void _showQrModal() {
    showDialog(
      context: context,
      builder: (_) => const QrTicketModal(),
    );
  }

  void _cancelBooking() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Batalkan Reservasi?'),
        content: const Text('Apakah Anda yakin ingin membatalkan reservasi Lab Komputer & RPL 1?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tidak')),
          FilledButton(
            onPressed: () { Navigator.pop(context); ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Permohonan pembatalan sedang diproses ke petugas Sarpras.')),
            ); },
            child: const Text('Ya, Batalkan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.paddingOf(context);

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          // Header
          const LapakHeader(avatarUrl: _avatarUrl),
          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(children: [
                        _tabBtn('aktif', 'Peminjaman Aktif', count: 2),
                        const SizedBox(width: 8),
                        _tabBtn('menunggu', 'Menunggu Persetujuan', count: 1),
                        const SizedBox(width: 8),
                        _tabBtn('riwayat', 'Selesai & Riwayat', count: 5),
                      ]),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                    child: _tabContent(),
                  ),
                ],
              ),
            ),
          ),
          // Bottom Nav
          AppBottomNav(
            items: AppBottomNav.userItems,
            currentIndex: 2,
            onTap: (_) {},
          ),
        ],
      ),
    );
  }

  Widget _tabBtn(String key, String label, {required int count}) {
    final selected = _tab == key;
    return GestureDetector(
      onTap: () => _switchTab(key),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cPrimary : cSurfaceLowest,
          borderRadius: BorderRadius.circular(999),
          boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontFamily: 'Plus Jakarta Sans', fontSize: 12, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : cOnSurfaceVariant)),
          const SizedBox(width: 6),
          Container(
            width: 20, height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? cSurface : cSurfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Text('$count', style: TextStyle(
              fontFamily: 'Plus Jakarta Sans', fontSize: 11, fontWeight: FontWeight.w700,
              color: selected ? cPrimary : cOnSurface)),
          ),
        ]),
      ),
    );
  }

  Widget _tabContent() {
    switch (_tab) {
      case 'aktif': return _cardAktif();
      case 'menunggu': return _cardMenunggu();
      default: return _cardDitolak();
    }
  }

  // ===== CARD AKTIF =====
  Widget _cardAktif() => _cardWrapper(children: [
    _rowTop('BK-20250912-004', _statusApproved()),
    const SizedBox(height: 12),
    _facilityRow('Laboratorium Komputer & RPL 1', 'Approved by Pak Ahmad Fauzi', Icons.verified_user, cPrimary,
      image: 'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=300&q=80',
      icon: Icons.desktop_windows),
    const SizedBox(height: 12),
    _scheduleBox('Jadwal Penggunaan', 'Hari ini, 18 Sep 2025 • 13:30 - 15:30 WIB', cPrimary, Icons.calendar_today),
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity, height: 44,
      child: ElevatedButton.icon(
        onPressed: _showQrModal,
        icon: const Icon(Icons.qr_code_scanner, size: 20),
        label: const Text('Tampilkan QR Pass Peminjaman'),
        style: ElevatedButton.styleFrom(
          backgroundColor: cPrimaryContainer, foregroundColor: Colors.white,
          elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
    ),
    const SizedBox(height: 8),
    Row(children: [
      Expanded(child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.info_outline, size: 18),
        label: const Text('Rincian Fasilitas'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cOnSurface, backgroundColor: cSurfaceContainer,
          side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          minimumSize: const Size(0, 44),
        ),
      )),
      const SizedBox(width: 8),
      SizedBox(height: 44, child: TextButton(
        onPressed: _cancelBooking,
        style: TextButton.styleFrom(
          backgroundColor: cErrorContainer.withValues(alpha: 0.4),
          foregroundColor: cError,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
        child: const Text('Batalkan'),
      )),
    ]),
  ]);

  // ===== CARD MENUNGGU =====
  Widget _cardMenunggu() => _cardWrapper(children: [
    _rowTop('BK-20250914-012', _statusPending()),
    const SizedBox(height: 12),
    _facilityRow('Aula Utama Graha Cendekia', 'PIC: Pak Hendra (Sarpras)', Icons.assignment_ind, cSecondary,
      image: 'https://images.unsplash.com/photo-1519167758481-83f550bb49b3?auto=format&fit=crop&w=300&q=80',
      icon: Icons.theater_comedy),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cSurfaceContainer, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.flag_outlined, size: 14, color: cOnSurfaceVariant),
        SizedBox(width: 4),
        Text('Keperluan: Seminar Workshop OSIS', style: TextStyle(fontSize: 11, color: cOnSurfaceVariant)),
      ]),
    ),
    const SizedBox(height: 12),
    _scheduleBox('Rencana Waktu', 'Senin, 22 Sep 2025 • 08:00 - 14:00 WIB', cSecondary, Icons.event),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cSurfaceContainer.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(16)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('STATUS VERIFIKASI RUANGAN', style: TextStyle(
          fontSize: 11, fontWeight: FontWeight.w700, color: cOnSurfaceVariant, letterSpacing: 0.5)),
        const SizedBox(height: 8),
        _stepDone('Pengajuan Berhasil Dikirim', '12 Sep 2025, 09:15 WIB'),
        _stepActive('Review & Verifikasi PIC', 'Sedang diproses oleh Sarpras'),
        _stepInactive('Konfirmasi Kunci & Akses', 'Menunggu ACC Kepala Bagian'),
      ]),
    ),
    const SizedBox(height: 12),
    Row(children: [
      Expanded(child: OutlinedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.edit_note, size: 18),
        label: const Text('Edit Pengajuan'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cOnSurface, backgroundColor: cSurfaceContainer,
          side: BorderSide.none, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          minimumSize: const Size(0, 44),
        ),
      )),
      const SizedBox(width: 8),
      Expanded(child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.chat_bubble_outline, size: 16),
        label: const Text('Hubungi PIC'),
        style: ElevatedButton.styleFrom(
          backgroundColor: cTertiaryFixed, foregroundColor: const Color(0xFF002113),
          elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
          minimumSize: const Size(0, 44),
        ),
      )),
    ]),
  ]);

  // ===== CARD DITOLAK =====
  Widget _cardDitolak() => _cardWrapper(children: [
    _rowTop('BK-20250910-098', _statusRejected()),
    const SizedBox(height: 12),
    _facilityRow('Kamera DSLR Canon EOS 80D', 'Unit Multimedia Sekolah', Icons.info_outline, cError,
      image: 'https://images.unsplash.com/photo-1516035069371-29a1b244cc32?auto=format&fit=crop&w=300&q=80',
      icon: Icons.photo_camera),
    const SizedBox(height: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: cSurfaceContainer, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.schedule, size: 14, color: cOnSurfaceVariant),
        SizedBox(width: 4),
        Text('Diajukan: 10 Sep 2025', style: TextStyle(fontSize: 11, color: cOnSurfaceVariant)),
      ]),
    ),
    const SizedBox(height: 12),
    Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: cErrorContainer.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(16)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.report_problem_outlined, color: cError, size: 20),
        const SizedBox(width: 8),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Catatan Penolakan PIC:', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cOnErrorContainer)),
          SizedBox(height: 2),
          Text('"Bentrok dengan jadwal liputan dokumentasi Ujian Sekolah & Asesmen Nasional. Silakan ajukan kamera cadangan (Sony Alpha a6000)."',
            style: TextStyle(fontSize: 12, color: cOnSurfaceVariant, height: 1.4)),
        ])),
      ]),
    ),
    const SizedBox(height: 12),
    SizedBox(
      width: double.infinity, height: 44,
      child: ElevatedButton.icon(
        onPressed: () {},
        icon: const Icon(Icons.sync_alt, size: 18),
        label: const Text('Pilih Fasilitas / Alat Alternatif'),
        style: ElevatedButton.styleFrom(
          backgroundColor: cSecondaryContainer, foregroundColor: cOnSecondaryContainer,
          elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        ),
      ),
    ),
  ]);

  // ---------- helpers ----------
  Widget _cardWrapper({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cSurfaceLowest, borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
  );

  Widget _rowTop(String id, Widget status) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(children: [
        const Text('BOOKING ID', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cOnSurfaceVariant, letterSpacing: 0.6)),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: cSurfaceContainer, borderRadius: BorderRadius.circular(999)),
          child: Text('#$id', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: cOnSurface)),
        ),
      ]),
      status,
    ],
  );

  Widget _statusApproved() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: cTertiaryFixed.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: const [
      Icon(Icons.circle, size: 8, color: cTertiaryContainer),
      SizedBox(width: 4),
      Text('Disetujui', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cTertiary)),
    ]),
  );

  Widget _statusPending() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: cSecondaryContainer, borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: const [
      Icon(Icons.hourglass_top, size: 12, color: cOnSecondaryContainer),
      SizedBox(width: 4),
      Text('Menunggu Review', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cOnSecondaryContainer)),
    ]),
  );

  Widget _statusRejected() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: cErrorContainer, borderRadius: BorderRadius.circular(999)),
    child: Row(mainAxisSize: MainAxisSize.min, children: const [
      Icon(Icons.cancel_outlined, size: 12, color: cOnErrorContainer),
      SizedBox(width: 4),
      Text('Ditolak', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: cOnErrorContainer)),
    ]),
  );

  Widget _facilityRow(String title, String subtitle, IconData subIcon, Color subColor,
      {required String image, required IconData icon}) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      width: 80, height: 80, clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: cSurfaceContainer),
      child: Stack(fit: StackFit.expand, children: [
        Image.network(image, fit: BoxFit.cover,
          loadingBuilder: (_, child, p) => p == null ? child : Container(color: cSurfaceContainer),
          errorBuilder: (_, __, ___) => Container(color: cSurfaceContainer, child: Icon(icon, color: cOutlineVariant)),
        ),
        Positioned(bottom: 4, right: 4, child: Icon(icon, size: 18, color: Colors.white)),
      ]),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(
        fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: cOnSurface, letterSpacing: -0.2)),
      const SizedBox(height: 2),
      Row(children: [
        Icon(subIcon, size: 14, color: subColor),
        const SizedBox(width: 4),
        Expanded(child: Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, color: cOnSurfaceVariant))),
      ]),
    ])),
  ]);

  Widget _scheduleBox(String label, String value, Color color, IconData icon) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(color: cSurfaceLow, borderRadius: BorderRadius.circular(12)),
    child: Row(children: [
      Icon(icon, color: color, size: 22),
      const SizedBox(width: 8),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontSize: 10, color: cOnSurfaceVariant)),
        const SizedBox(height: 1),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cOnSurface)),
      ])),
    ]),
  );

  Widget _stepDone(String title, String subtitle) => _stepRow(
    color: cPrimaryContainer, icon: Icons.check, iconColor: Colors.white,
    title: title, titleColor: cOnSurface, subtitle: subtitle, subtitleColor: cOnSurfaceVariant,
  );

  Widget _stepActive(String title, String subtitle) => _stepRow(
    color: cSecondaryContainer, icon: Icons.hourglass_empty, iconColor: cOnSecondaryContainer,
    title: title, titleColor: cOnSurface, subtitle: subtitle, subtitleColor: cPrimary, bold: true,
  );

  Widget _stepInactive(String title, String subtitle) => _stepRow(
    color: cSurfaceHigh, icon: Icons.key, iconColor: cOnSurfaceVariant,
    title: title, titleColor: cOnSurfaceVariant, subtitle: subtitle, subtitleColor: cOnSurfaceVariant.withValues(alpha: 0.8),
  );

  Widget _stepRow({
    required Color color, required IconData icon, required Color iconColor,
    required String title, required Color titleColor,
    required String subtitle, required Color subtitleColor, bool bold = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: iconColor),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontSize: 12, fontWeight: bold ? FontWeight.w700 : FontWeight.w600, color: titleColor)),
        Text(subtitle, style: TextStyle(fontSize: 11, color: subtitleColor)),
      ])),
    ]),
  );
}


