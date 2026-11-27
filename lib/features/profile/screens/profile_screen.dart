import 'dart:typed_data';

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
import 'package:lapak8new/features/admin/services/user_repository.dart';
import 'package:lapak8new/features/auth/providers/auth_provider.dart';
import 'package:lapak8new/features/borrowings/services/peminjaman_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isNotificationEnabled = true;
  bool _isLoadingNotificationPreference = true;
  bool _isSavingNotificationPreference = false;
  bool _isLoadingBorrowingStats = true;
  bool _borrowingStatsFailed = false;
  int _completedBorrowings = 0;
  int _lateBorrowings = 0;

  // Foto lokal dipakai sebagai preview setelah upload tersimpan.
  final MediaPickerService _picker = MediaPickerService();
  String _avatarPath = '';
  List<int>? _avatarBytes;
  String? get _fotoUrl => authProvider.user?.fotoUrl;
  @override
  void initState() {
    super.initState();
    _loadProfileSettings();
  }

  Future<void> _loadProfileSettings() async {
    await Future.wait([_loadNotificationPreference(), _loadBorrowingStats()]);
  }

  Future<void> _loadNotificationPreference() async {
    try {
      final enabled = await authProvider.loadNotificationPreference();
      if (!mounted) return;
      setState(() {
        _isNotificationEnabled = enabled;
        _isLoadingNotificationPreference = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoadingNotificationPreference = false);
      _showMessage('Gagal memuat preferensi notifikasi: $error', isError: true);
    }
  }

  Future<void> _loadBorrowingStats() async {
    try {
      final stats = await peminjamanService.ambilStatistikPeminjamanSaya();
      if (!mounted) return;
      setState(() {
        _completedBorrowings = stats.selesai;
        _lateBorrowings = stats.terlambat;
        _isLoadingBorrowingStats = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingBorrowingStats = false;
        _borrowingStatsFailed = true;
      });
      _showMessage('Gagal memuat statistik peminjaman: $error', isError: true);
    }
  }

  Future<void> _setNotificationPreference(bool enabled) async {
    if (_isSavingNotificationPreference || _isLoadingNotificationPreference) {
      return;
    }
    final previous = _isNotificationEnabled;
    setState(() {
      _isNotificationEnabled = enabled;
      _isSavingNotificationPreference = true;
    });
    try {
      await authProvider.saveNotificationPreference(enabled);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isNotificationEnabled = previous);
      _showMessage(
        'Gagal menyimpan preferensi notifikasi: $error',
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _isSavingNotificationPreference = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: isError ? cError : AppColors.primary,
          content: Text(message),
        ),
      );
  }

  // ---- Ganti foto profil ----------------------------------------------------
  Future<void> _changeAvatar() async {
    final source = await showMediaSourceSheet(
      context,
      isPhoto: true,
      title: 'Ganti Foto Profil',
      subtitle: 'Pilih sumber foto profil Anda.',
    );
    if (source == null || !mounted) return;

    final outcome = await _picker.pickPhotos(source: source, remainingSlots: 1);
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

    final userId = authProvider.user?.id;
    final bytes = file.bytes;
    if (userId == null || bytes == null) {
      _showMessage(
        'Foto tidak dapat disimpan. Coba pilih foto lain.',
        isError: true,
      );
      return;
    }
    try {
      await userRepository.uploadAndSaveProfilePhoto(
        userId: userId,
        bytes: bytes is Uint8List ? bytes : Uint8List.fromList(bytes),
        fileName: file.fileName,
      );
      await authProvider.refreshProfil();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Gagal menyimpan foto profil: $error', isError: true);
      return;
    }

    if (!mounted) return;
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
            color: Colors.white,
          ),
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
      builder: (modalContext) {
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
                  width: 48,
                  height: 6,
                  decoration: BoxDecoration(
                    color: cSurfaceContainerHighest,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 20),
                // Icon Warning
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: cErrorContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 32,
                    color: cError,
                  ),
                ),
                const SizedBox(height: 16),
                // Text
                const Text(
                  'Yakin Ingin Keluar?',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: cOnSurface,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Anda harus memasukkan kembali NISN dan kata sandi untuk mengajukan atau memeriksa peminjaman sarana.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: cSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 24),
                // Buttons
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(modalContext); // Tutup modal
                      await authProvider.signOut();
                      if (!mounted) return;
                      context.go('/login');
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Berhasil keluar dari akun LAPAK8.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.logout, size: 18),
                    label: const Text(
                      'Ya, Keluar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cError,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: TextButton(
                    onPressed: () => Navigator.pop(modalContext),
                    style: TextButton.styleFrom(
                      backgroundColor: cSurfaceContainerHigh,
                      foregroundColor: cOnSurface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Batal',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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
                  icon: const Icon(
                    Icons.arrow_back,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              Text(
                'Pengaturan Profil',
                style: AppTextStyles.headlineSm(
                  color: AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700, fontSize: 18),
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
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Avatar & Badges
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 96,
                            height: 96,
                            clipBehavior: Clip.antiAlias,
                            decoration: const BoxDecoration(
                              color: cSurfaceContainerHigh,
                              shape: BoxShape.circle,
                            ),
                            child:
                                (_avatarBytes != null || _avatarPath.isNotEmpty)
                                ? LocalImagePreview(
                                    path: _avatarPath,
                                    bytes: _avatarBytes,
                                  )
                                : (_fotoUrl != null && _fotoUrl!.isNotEmpty)
                                ? Image.network(
                                    _fotoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.person,
                                      size: 48,
                                      color: cPrimary,
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 48,
                                    color: cPrimary,
                                  ),
                          ),
                          // Verified Badge
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: cPrimary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.verified,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          // Edit Camera Button
                          Positioned(
                            top: -4,
                            right: -4,
                            child: GestureDetector(
                              onTap: _changeAvatar,
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: cSurfaceLowest,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.photo_camera,
                                  size: 18,
                                  color: cPrimary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Name
                      Text(
                        authProvider.user?.namaLengkap ?? 'Pengguna',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: cOnSurface,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Role Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: cSurfaceContainerHigh,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          [
                            switch (authProvider.user?.peran) {
                              'siswa' => 'Siswa',
                              'guru' => 'Guru',
                              'staf' => 'Staf',
                              'admin' => 'Admin',
                              _ => 'Pengguna',
                            },
                            if (authProvider.user?.kelasAtauUnit
                                    ?.trim()
                                    .isNotEmpty ==
                                true)
                              authProvider.user!.kelasAtauUnit!.trim(),
                          ].join(' • '),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: cPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      // NIS
                      Text(
                        '${authProvider.user?.peran == 'siswa' ? 'NIS' : 'NIP'}: '
                        '${authProvider.user?.nomorInduk ?? ''}',
                        style: const TextStyle(fontSize: 12, color: cSecondary),
                      ),
                      const SizedBox(height: 16),
                      // Stats Strip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cSurfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    _isLoadingBorrowingStats
                                        ? '...'
                                        : _borrowingStatsFailed
                                        ? '—'
                                        : '$_completedBorrowings',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: cPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Peminjaman Selesai',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              width: 1,
                              height: 32,
                              color: cOutline.withValues(alpha: 0.2),
                            ),
                            Expanded(
                              child: Column(
                                children: [
                                  Text(
                                    _isLoadingBorrowingStats
                                        ? '...'
                                        : _borrowingStatsFailed
                                        ? '—'
                                        : '$_lateBorrowings',
                                    style: const TextStyle(
                                      fontFamily: 'Outfit',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: cTertiary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Terlambat',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cSecondary,
                                    ),
                                  ),
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
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0D000000),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Pengaturan & Keamanan',
                        style: TextStyle(
                          fontFamily: 'Outfit',
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: cOnSurface,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Ubah Kata Sandi
                      _buildSettingsItem(
                        icon: Icons.key,
                        title: 'Ubah Kata Sandi',
                        subtitle: 'Pembaruan rutin disarankan',
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: cOutline,
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => ChangePasswordModal(
                              onSave: (currentPassword, newPassword) =>
                                  authProvider.changePassword(
                                    currentPassword: currentPassword,
                                    newPassword: newPassword,
                                  ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // 2. Ubah Nomor Telepon (MENU BARU)
                      _buildSettingsItem(
                        icon: Icons.phone_android,
                        title: 'Ubah Nomor Telepon',
                        subtitle: 'Nomor WhatsApp aktif',
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: cOutline,
                        ),
                        onTap: () {
                          showDialog(
                            context: context,
                            builder: (context) => ChangePhoneModal(
                              initialPhone: authProvider.user?.telepon ?? '',
                              onSave: authProvider.updatePhoneNumber,
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),

                      // 3. Notifikasi & Pengingat (Toggle)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: cSurfaceLowest,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: const BoxDecoration(
                                color: cSurfaceContainer,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_active,
                                size: 20,
                                color: cOnSurfaceVariant,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Notifikasi & Pengingat',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cOnSurface,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Preferensi tersimpan di akun',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: cSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _isNotificationEnabled,
                              onChanged:
                                  _isLoadingNotificationPreference ||
                                      _isSavingNotificationPreference
                                  ? null
                                  : _setNotificationPreference,
                              activeThumbColor: cPrimary,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // 4. Pusat Bantuan
                      _buildSettingsItem(
                        icon: Icons.support_agent,
                        title: 'Pusat Bantuan',
                        subtitle: 'Tanya ALLOC8 AI seputar peminjaman',
                        trailing: const Icon(
                          Icons.chevron_right,
                          color: cOutline,
                        ),
                        onTap: () => context.push('/chat'),
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
                    label: const Text(
                      'Keluar dari Akun',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cErrorContainer,
                      foregroundColor: cError,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ================= FOOTER APP INFO =================
                Column(
                  children: const [
                    Text(
                      'LAPAK8 EduReserve v1.2.0 • SMKN 8 Malang',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: cSecondary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sistem Manajemen Sarana & Prasarana Digital',
                      style: TextStyle(fontSize: 10, color: cOutline),
                    ),
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
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: cSurfaceContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: cOnSurfaceVariant),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cOnSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: cSecondary),
                  ),
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
