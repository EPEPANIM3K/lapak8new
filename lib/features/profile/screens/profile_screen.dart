import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/profile_modals.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';
import 'package:lapak8new/features/admin/services/media_picker_service.dart';
import 'package:lapak8new/features/admin/widgets/avatar_preview_dialog.dart';
import 'package:lapak8new/features/admin/widgets/documentation_media_previews.dart';
import 'package:lapak8new/features/admin/widgets/media_source_sheet.dart';
import 'package:lapak8new/features/dashboard/widgets/bantuan_pic_modal.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // State untuk Switch Notifikasi
  bool _isNotificationEnabled = true;

  // Foto profil hasil pilihan lokal (frontend saja, belum tersimpan permanen).
  final MediaPickerService _picker = MediaPickerService();
  String _avatarPath = '';
  List<int>? _avatarBytes;
  bool get _hasAvatar => _avatarBytes != null || _avatarPath.isNotEmpty;

  // ---- Ganti foto profil ----------------------------------------------------
  Future<void> _changeAvatar() async {
    final source = await showMediaSourceSheet(
      context,
      isPhoto: true,
      title: 'Ganti Foto Profil',
      subtitle: 'Pilih sumber foto profil Anda.',
    );
    if (source == null || !mounted) return;

    final outcome =
        await _picker.pickPhotos(source: source, remainingSlots: 1);
    if (!mounted) return;

    if (outcome.files.isEmpty) {
      if (outcome.message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(outcome.message!),
          ),
        );
      }
      return;
    }

    await _showAvatarPreview(outcome.files.first);
  }

  Future<void> _showAvatarPreview(PendingDocumentationFile file) async {
    final use = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AvatarPreviewDialog(file: file),
    );
    if (use != true || !mounted) return;

    setState(() {
      _avatarPath = file.localPath;
      _avatarBytes = file.bytes;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        content: const Text(
          'Foto profil diperbarui.',
          style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white),
        ),
      ),
    );
  }

  // ===== Palette Warna =====
  static const cSurface = Color(0xFFFAF8FF);
  static const cSurfaceLowest = Color(0xFFFFFFFF);
  static const cSurfaceContainerLow = Color(0xFFF2F3FF);
  static const cSurfaceContainer = Color(0xFFEAEDFF);
  static const cSurfaceContainerHigh = Color(0xFFE2E7FF);
  static const cSurfaceContainerHighest = Color(0xFFDAE2FD);
  static const cPrimary = Color(0xFF0037B0);
  static const cPrimaryFixed = Color(0xFFDCE1FF);
  static const cTertiary = Color(0xFF004F35);
  static const cError = Color(0xFFBA1A1A);
  static const cErrorContainer = Color(0xFFFFDAD6);
  static const cOnSurface = Color(0xFF131B2E);
  static const cOnSurfaceVariant = Color(0xFF434655);
  static const cSecondary = Color(0xFF505F76);
  static const cOutline = Color(0xFF747686);

  void _showLogoutModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: cSurfaceLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Drag Handle
                Container(
                  width: 48, height: 6,
                  decoration: BoxDecoration(color: cSurfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
                ),
                const SizedBox(height: 20),
                // Icon Warning
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(color: cErrorContainer, shape: BoxShape.circle),
                  child: const Icon(Icons.warning_amber_rounded, size: 32, color: cError),
                ),
                const SizedBox(height: 16),
                // Text
                const Text('Yakin Ingin Keluar?',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w700, color: cOnSurface)),
                const SizedBox(height: 8),
                const Text('Anda harus memasukkan kembali NISN dan kata sandi untuk mengajukan atau memeriksa peminjaman sarana.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: cSecondary, height: 1.5)),
                const SizedBox(height: 24),
                // Buttons
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton.icon(
                     onPressed: () {
                       Navigator.pop(context); // Tutup modal
                       context.go('/login');
                       ScaffoldMessenger.of(context).showSnackBar(
                         const SnackBar(content: Text('Berhasil keluar dari akun LAPAK8.'), behavior: SnackBarBehavior.floating),
                       );
                     },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text('Ya, Keluar', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cError, foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      backgroundColor: cSurfaceContainerHigh, foregroundColor: cOnSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                    ),
                    child: const Text('Batal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---- Top bar (sama dengan Pengaturan Profil Admin) ------------------------
  Widget _buildTopBar() {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: AppShadows.sm,
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.arrow_back, color: AppColors.onSurface),
                ),
              ),
              Text(
                'Pengaturan Profil',
                style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                    .copyWith(fontWeight: FontWeight.w700, fontSize: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cSurface,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        children: [
          // ================= PROFILE HEADER CARD =================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cSurfaceLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              children: [
                // Avatar & Badges
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 96, height: 96,
                      clipBehavior: Clip.antiAlias,
                      decoration: const BoxDecoration(color: cSurfaceContainerHigh, shape: BoxShape.circle),
                      child: _hasAvatar
                          ? LocalImagePreview(path: _avatarPath, bytes: _avatarBytes)
                          : const Icon(Icons.person, size: 48, color: cPrimary), // Placeholder
                    ),
                    // Verified Badge
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: cPrimary, shape: BoxShape.circle),
                        child: const Icon(Icons.verified, size: 16, color: Colors.white),
                      ),
                    ),
                    // Edit Camera Button
                    Positioned(
                      top: -4, right: -4,
                      child: GestureDetector(
                        onTap: _changeAvatar,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(color: cSurfaceLowest, shape: BoxShape.circle),
                          child: const Icon(Icons.photo_camera, size: 18, color: cPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Name
                const Text('Alifia Zahra',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w600, color: cOnSurface)),
                const SizedBox(height: 8),
                // Role Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: cSurfaceContainerHigh, borderRadius: BorderRadius.circular(999)),
                  child: const Text('Siswa • XII RPL 1',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: cPrimary)),
                ),
                const SizedBox(height: 4),
                // NIS
                const Text('NIS: 2122.10.408',
                  style: TextStyle(fontSize: 12, color: cSecondary)),
                const SizedBox(height: 16),
                // Stats Strip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: cSurfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          children: const [
                            Text('14', style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600, color: cPrimary)),
                            SizedBox(height: 2),
                            Text('Peminjaman Selesai', style: TextStyle(fontSize: 11, color: cSecondary)),
                          ],
                        ),
                      ),
                      Container(width: 1, height: 32, color: cOutline.withValues(alpha: 0.2)),
                      Expanded(
                        child: Column(
                          children: const [
                            Text('0', style: TextStyle(fontFamily: 'Outfit', fontSize: 18, fontWeight: FontWeight.w600, color: cTertiary)),
                            SizedBox(height: 2),
                            Text('Terlambat/Denda', style: TextStyle(fontSize: 11, color: cSecondary)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ================= PENGATURAN & KEAMANAN =================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cSurfaceLowest,
              borderRadius: BorderRadius.circular(16),
              boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 4, offset: Offset(0, 2))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Pengaturan & Keamanan',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 16, fontWeight: FontWeight.w600, color: cOnSurface)),
                const SizedBox(height: 16),
                
                // 1. Ubah Kata Sandi
                _buildSettingsItem(
                  icon: Icons.key,
                  title: 'Ubah Kata Sandi',
                  subtitle: 'Pembaruan rutin disarankan',
                  trailing: const Icon(Icons.chevron_right, color: cOutline),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const ChangePasswordModal(),
                    );
                  },
                ),
                const SizedBox(height: 8),

                // 2. Ubah Nomor Telepon (MENU BARU)
                _buildSettingsItem(
                  icon: Icons.phone_android,
                  title: 'Ubah Nomor Telepon',
                  subtitle: 'Nomor WhatsApp aktif',
                  trailing: const Icon(Icons.chevron_right, color: cOutline),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => const ChangePhoneModal(),
                    );
                  },
                ),
                const SizedBox(height: 8),

                // 3. Notifikasi & Pengingat (Toggle)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(color: cSurfaceLowest, borderRadius: BorderRadius.circular(16)),
                  child: Row(
                    children: [
                      Container(
                        width: 36, height: 36,
                        decoration: const BoxDecoration(color: cSurfaceContainer, shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_active, size: 20, color: cOnSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Notifikasi & Pengingat',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cOnSurface)),
                            SizedBox(height: 2),
                            Text('Status peminjaman & tenggat',
                              style: TextStyle(fontSize: 11, color: cSecondary)),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isNotificationEnabled,
                        onChanged: (val) {
                          setState(() {
                            _isNotificationEnabled = val;
                          });
                        },
                        activeThumbColor: cPrimary,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // 4. Pusat Bantuan & PIC
                _buildSettingsItem(
                  icon: Icons.support_agent,
                  title: 'Pusat Bantuan & PIC Sarpras',
                  subtitle: 'WhatsApp admin SMKN 8',
                  trailing: const Icon(Icons.chevron_right, color: cOutline),
                  onTap: () {
                    showDialog(
                      context: context,
                      barrierColor: Colors.black54,
                      builder: (_) => const BantuanPicModal(),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ================= TOMBOL LOGOUT =================
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _showLogoutModal,
              icon: const Icon(Icons.logout, size: 20),
              label: const Text('Keluar dari Akun', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: cErrorContainer,
                foregroundColor: cError,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // ================= FOOTER APP INFO =================
          Column(
            children: const [
              Text('LAPAK8 EduReserve v1.2.0 • SMKN 8 Malang',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: cSecondary)),
              SizedBox(height: 2),
              Text('Sistem Manajemen Sarana & Prasarana Digital',
                style: TextStyle(fontSize: 10, color: cOutline)),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
          ),
        ],
      ),
    );
  }

  // Widget Helper untuk Item Pengaturan
  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cSurfaceLowest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(color: cSurfaceContainer, shape: BoxShape.circle),
              child: Icon(icon, size: 20, color: cOnSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: cOnSurface)),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 11, color: cSecondary)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}