import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';
import 'package:lapak8new/features/admin/services/media_picker_service.dart';
import 'package:lapak8new/features/admin/widgets/admin_change_password_sheet.dart';
import 'package:lapak8new/features/admin/widgets/avatar_preview_dialog.dart';
import 'package:lapak8new/features/admin/widgets/documentation_media_previews.dart';
import 'package:lapak8new/features/admin/widgets/media_source_sheet.dart';
import 'package:lapak8new/features/dashboard/widgets/bantuan_pic_modal.dart';
import 'package:lapak8new/features/dashboard/widgets/dashboard_modals.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';

// Simpan di: lib/features/admin/screens/admin_profile_screen.dart
//
// Route (app_router.dart):
//   GoRoute(
//     path: '/admin/profile',
//     builder: (_, __) => const AdminProfileScreen(),
//   ),

// Warna lokal yang belum ada di AppColors.
const _fieldBg = Color(0xFFEFEDFB);
const _greenFg = Color(0xFF065F46);

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});

  @override
  State<AdminProfileScreen> createState() => _AdminProfileScreenState();
}

class _AdminProfileScreenState extends State<AdminProfileScreen> {
  // TODO: ganti dengan data admin dari backend.
  static const _name = 'Masadmin';
  static const _role = 'admin';
  static const _idNumber = '2122.10.408';
  static const _unit = 'Admin Lab RPL';

  /// Email tersimpan (bisa diubah lewat mode edit Data Pribadi).
  String _savedEmail = 'masadmin@gmail.com';

  /// Foto profil hasil pilihan lokal (frontend saja, belum tersimpan permanen).
  String _avatarPath = '';
  List<int>? _avatarBytes;

  late final MediaPickerService _picker = MediaPickerService();

  // Mode edit Data Pribadi (hanya email yang dapat diubah).
  bool _editingEmail = false;
  late final TextEditingController _emailCtrl =
      TextEditingController(text: _savedEmail);
  bool _emailTouched = false;

  bool _notifOn = true;

  static final RegExp _emailRegex =
      RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  bool get _emailChanged => _emailCtrl.text.trim() != _savedEmail;
  bool get _emailValid => _emailRegex.hasMatch(_emailCtrl.text.trim());
  bool get _canSaveEmail => _emailChanged && _emailValid;
  bool get _hasAvatar => _avatarBytes != null || _avatarPath.isNotEmpty;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  void _logout() {
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.block,
        title: 'Keluar Dari Akun\nAnda?',
        message: 'Anda dapat Masuk lagi kapan saja.',
        confirmText: 'Ya',
        confirmIcon: null,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
          onConfirm: () {
            context.go('/login');
          },
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
        content: Text(
          'Foto profil diperbarui.',
          style: AppTextStyles.bodySm(
            weight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: Column(
        children: [
          _buildTopBar(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.mobileGutter,
                AppSpacing.md,
                AppSpacing.mobileGutter,
                24,
              ),
              children: [
                _buildProfileCard(),
                const SizedBox(height: 16),
                _buildPersonalData(),
                const SizedBox(height: 16),
                _buildSettings(),
                const SizedBox(height: 16),
                _buildLogoutButton(),
                const SizedBox(height: 24),
                _buildFooter(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Top bar --------------------------------------------------------------
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
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Symbols.arrow_back,
                      color: AppColors.onSurface),
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

  // ---- Kartu profil ---------------------------------------------------------
  Widget _buildProfileCard() {
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
      child: Column(
        children: [
          SizedBox(
            width: 104,
            height: 104,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  margin: const EdgeInsets.only(top: 4, right: 4),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: AppColors.surfaceContainerLow, width: 4),
                  ),
                  child: _hasAvatar
                      ? LocalImagePreview(
                          path: _avatarPath, bytes: _avatarBytes)
                      : const Icon(Symbols.person,
                          size: 44, color: AppColors.primary),
                ),
                // Tombol kamera (kanan atas)
                Positioned(
                  right: -6,
                  top: -6,
                  child: GestureDetector(
                    onTap: _changeAvatar,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        shape: BoxShape.circle,
                        boxShadow: AppShadows.sm,
                      ),
                      child: const Icon(Symbols.photo_camera,
                          size: 18, color: AppColors.primary),
                    ),
                  ),
                ),
                // Badge terverifikasi (kanan bawah)
                Positioned(
                  right: 2,
                  bottom: 6,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: AppColors.surfaceContainerLowest, width: 2),
                    ),
                    child: const Icon(Symbols.check,
                        size: 14, weight: 700, color: AppColors.onPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _name,
            style: AppTextStyles.headlineMd(color: AppColors.onSurface)
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 3),
            decoration: BoxDecoration(
              color: _fieldBg,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              _role,
              style: AppTextStyles.labelSm(
                weight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'NIS/NIP: $_idNumber',
            style: AppTextStyles.bodySm(
              weight: FontWeight.w500,
              color: AppColors.slate600,
            ),
          ),
        ],
      ),
    );
  }

  // ---- Data pribadi ---------------------------------------------------------
  Widget _buildPersonalData() {
    return _Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Data Pribadi',
                  style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _buildEditButton(),
            ],
          ),
          const SizedBox(height: 14),
          const _InfoRow(
            icon: Symbols.badge,
            label: 'Nama Lengkap',
            value: _name,
            trailing: Icon(Symbols.lock, size: 20, color: AppColors.slate500),
          ),
          const SizedBox(height: 10),
          _buildEmailRow(),
          const SizedBox(height: 10),
          const _InfoRow(
            icon: Symbols.school,
            label: 'Kelas / Konsentrasi Keahlian',
            value: _unit,
            trailing: Icon(Symbols.lock, size: 20, color: AppColors.slate500),
          ),
        ],
      ),
    );
  }

  // Tombol Ubah / Simpan Data Pribadi (satu mekanisme state).
  Widget _buildEditButton() {
    final editing = _editingEmail;
    // Netral saat mode edit belum ada perubahan valid; biru saat siap simpan.
    final color = editing
        ? (_canSaveEmail ? AppColors.primary : AppColors.slate500)
        : AppColors.primary;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        if (!editing) {
          setState(() {
            _editingEmail = true;
            _emailTouched = false;
            _emailCtrl.text = _savedEmail;
          });
          return;
        }
        if (_canSaveEmail) {
          _saveEmail();
        } else if (!_emailChanged) {
          // Tidak ada perubahan -> keluar dari mode edit.
          setState(() => _editingEmail = false);
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(editing ? Symbols.check : Symbols.edit,
                size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              editing ? 'Simpan' : 'Ubah',
              style: AppTextStyles.labelMd(
                weight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailRow() {
    if (!_editingEmail) {
      return _InfoRow(
        icon: Symbols.alternate_email,
        label: 'Email Belajar',
        value: _savedEmail,
        trailing: const Icon(Symbols.check_circle, size: 22, color: _greenFg),
      );
    }
    return _EditableEmailRow(
      controller: _emailCtrl,
      errorText: _emailErrorText,
      onChanged: (_) => setState(() => _emailTouched = true),
    );
  }

  String? get _emailErrorText {
    if (!_emailTouched) return null;
    if (_emailCtrl.text.trim().isEmpty) return 'Email wajib diisi.';
    if (!_emailValid) return 'Format email tidak valid.';
    return null;
  }

  void _saveEmail() {
    if (!_canSaveEmail) return;
    setState(() {
      _savedEmail = _emailCtrl.text.trim();
      _editingEmail = false;
      _emailTouched = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        content: Text(
          'Data pribadi berhasil disimpan.',
          style: AppTextStyles.bodySm(
            weight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }

  // ---- Pengaturan & keamanan ------------------------------------------------
  Widget _buildSettings() {
    return _Card(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pengaturan & Keamanan',
            style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          _SettingRow(
            icon: Symbols.key,
            title: 'Ubah Kata Sandi',
            subtitle: 'Pembaruan rutin disarankan',
            trailing: const _Chevron(),
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black54,
                builder: (_) => const AdminChangePasswordSheet(),
              );
            },
          ),
          _SettingRow(
            icon: Symbols.notifications_active,
            title: 'Notifikasi & Pengingat',
            subtitle: 'Status peminjaman & tenggat',
            trailing: _buildSwitch(),
            onTap: () => setState(() => _notifOn = !_notifOn),
          ),
          _SettingRow(
            icon: Symbols.policy,
            title: 'Syarat & Ketentuan Sarpras',
            subtitle: 'Panduan pemakaian fasilitas',
            trailing: const _Chevron(),
            onTap: () {
              showDialog(
                context: context,
                barrierColor: Colors.black54,
                builder: (_) => const PeraturanModal(),
              );
            },
          ),
          _SettingRow(
            icon: Symbols.support_agent,
            title: 'Pusat Bantuan & PIC Sarpras',
            subtitle: 'WhatsApp admin SMKN 8',
            trailing: const _Chevron(),
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
    );
  }

  Widget _buildSwitch() {
    return Switch(
      value: _notifOn,
      onChanged: (v) => setState(() => _notifOn = v),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      thumbColor: WidgetStateProperty.all(Colors.white),
      trackColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? AppColors.primary
            : AppColors.slate500,
      ),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    );
  }

  // ---- Tombol keluar --------------------------------------------------------
  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _logout,
        icon: const Icon(Symbols.logout, size: 20),
        label: Text(
          'Keluar dari Akun',
          style: AppTextStyles.labelLg(
            weight: FontWeight.w700,
            color: AppColors.error,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.errorContainer,
          foregroundColor: AppColors.error,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Column(
      children: [
        Text(
          'LAPAK8 EduReserve v1.2.0 • SMKN 8 Malang',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSm(
            weight: FontWeight.w700,
            color: AppColors.slate600,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Sistem Manajemen Sarana & Prasarana Digital',
          textAlign: TextAlign.center,
          style: AppTextStyles.labelSm(
            weight: FontWeight.w500,
            color: AppColors.slate500,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Komponen kecil
// ---------------------------------------------------------------------------
class _Card extends StatelessWidget {
  const _Card({required this.child, required this.padding});
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.sm,
      ),
      child: child,
    );
  }
}

class _IconCircle extends StatelessWidget {
  const _IconCircle({required this.icon});
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: AppColors.primaryFixed,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: AppColors.primary),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.trailing,
  });

  final IconData icon;
  final String label;
  final String value;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 14, 10),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Row(
        children: [
          _IconCircle(icon: icon),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMd(
                    weight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          trailing,
        ],
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            _IconCircle(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyMd(
                      weight: FontWeight.w700,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w500,
                      color: AppColors.slate600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _Chevron extends StatelessWidget {
  const _Chevron();

  @override
  Widget build(BuildContext context) =>
      const Icon(Symbols.chevron_right, size: 24, color: AppColors.slate600);
}

class _EditableEmailRow extends StatelessWidget {
  const _EditableEmailRow({
    required this.controller,
    required this.onChanged,
    this.errorText,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 14, 10),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(AppRadius.base),
        border: Border.all(
          color: hasError ? AppColors.error : AppColors.primary,
          width: 1.2,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconCircle(icon: Symbols.alternate_email),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Email Belajar',
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
                TextField(
                  controller: controller,
                  onChanged: onChanged,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.bodyMd(
                    weight: FontWeight.w600,
                    color: AppColors.onSurface,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    hintText: 'nama@email.com',
                    hintStyle: AppTextStyles.bodyMd(
                        color: AppColors.outlineVariant),
                  ),
                ),
                if (hasError) ...[
                  const SizedBox(height: 4),
                  Text(
                    errorText!,
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w600,
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Symbols.check_circle, size: 22, color: _greenFg),
        ],
      ),
    );
  }
}

