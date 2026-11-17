import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';

// Simpan di: lib/features/admin/screens/user_form_screen.dart
//
// Cara pakai:
//   Tambah : final data = await UserFormScreen.show(context);
//   Edit   : final data = await UserFormScreen.show(context, initial: data);
//   if (data != null) { /* kirim ke backend */ }

/// Data hasil pengisian form.
class UserFormData {
  const UserFormData({
    required this.name,
    required this.password,
    required this.email,
    required this.idNumber,
    required this.roleClass,
    required this.active,
    this.phone = '',
    this.photo,
  });

  final String name;
  final String password;
  final String email;
  final String idNumber; // NISN / NIP
  final String? roleClass; // kelas / unit
  final bool active;
  final String phone; // no. telepon (dipakai di mode edit)
  final Uint8List? photo;
}

// Warna lokal yang belum ada di AppColors.
const _greenFg = Color(0xFF065F46);

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.initial, this.isAdmin = false});

  /// Bila diisi, form berjalan dalam mode edit ("Kelola Akun ...").
  final UserFormData? initial;

  /// Bila true, judul menjadi "Kelola Akun Admin".
  final bool isAdmin;

  static Future<UserFormData?> show(
    BuildContext context, {
    UserFormData? initial,
    bool isAdmin = false,
  }) {
    return Navigator.of(context).push<UserFormData>(
      MaterialPageRoute<UserFormData>(
        builder: (_) => UserFormScreen(initial: initial, isAdmin: isAdmin),
      ),
    );
  }

  @override
  State<UserFormScreen> createState() => _UserFormScreenState();
}

class _UserFormScreenState extends State<UserFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  // TODO: ganti dengan daftar kelas / unit dari backend.
  static const _roleOptions = <String>[
    'X RPL 1',
    'XI RPL 1',
    'XII RPL 1',
    'X TKJ 3',
    'XI MM 2',
    'XII DKV 1',
    'Guru Kejuruan',
    'Staf Sarpras',
  ];

  String? _roleClass;
  bool _active = true;
  bool _hidePass = true;
  Uint8List? _photo;

  bool get _isEdit => widget.initial != null;

  // Pastikan nilai awal selalu ada di daftar dropdown.
  List<String> get _options => [
        ..._roleOptions,
        if (_roleClass != null && !_roleOptions.contains(_roleClass))
          _roleClass!,
      ];

  @override
  void initState() {
    super.initState();
    final i = widget.initial;
    if (i != null) {
      _nameCtrl.text = i.name;
      _passCtrl.text = i.password;
      _emailCtrl.text = i.email;
      _idCtrl.text = i.idNumber;
      _phoneCtrl.text = i.phone;
      _roleClass = i.roleClass;
      _active = i.active;
      _photo = i.photo;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _emailCtrl.dispose();
    _idCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  void _pickPhoto() {
    // TODO: pakai image_picker, lalu setState(() => _photo = bytes);
    // Batasi format JPG/PNG dan ukuran maks 2MB.
  }

  void _removePhoto() => setState(() => _photo = null);

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final data = UserFormData(
      name: _nameCtrl.text.trim(),
      password: _passCtrl.text,
      email: _emailCtrl.text.trim(),
      idNumber: _idCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      roleClass: _roleClass,
      active: _active,
      photo: _photo,
    );

    // Mode tambah: langsung simpan.
    if (!_isEdit) {
      Navigator.of(context).pop(data);
      return;
    }

    // Mode edit: minta konfirmasi dulu.
    showDialog(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.save,
        title: 'Simpan Perubahan?',
        message: 'Apakah Anda yakin ingin menyimpan seluruh perubahan data '
            'item sarpras atau akun ini ke dalam sistem?',
        confirmText: 'Ya, Simpan',
        onConfirm: () {
          // ConfirmDialog sudah menutup dialognya sendiri,
          // cukup tutup form sambil mengirim data.
          if (mounted) Navigator.of(context).pop(data);
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: AppColors.primaryFixed),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.mobileGutter,
                  16,
                  AppSpacing.mobileGutter,
                  24,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const _FieldLabel('Foto Pengguna'),
                      _buildPhoto(),
                      if (_photo != null) ...[
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _removePhoto,
                            style: TextButton.styleFrom(
                              foregroundColor: AppColors.error,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10),
                              minimumSize: const Size(0, 32),
                            ),
                            child: Text(
                              'Hapus Foto',
                              style: AppTextStyles.labelSm(
                                weight: FontWeight.w700,
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 6),
                        Text(
                          'Format yang didukung: JPG, PNG (maks. 2MB)',
                          style: AppTextStyles.labelSm(
                            weight: FontWeight.w500,
                            color: AppColors.slate600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      const _FieldLabel('Nama Lengkap', required: true),
                      _textField(
                        controller: _nameCtrl,
                        hint: 'Masukkan nama lengkap',
                        icon: Symbols.person,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Password', required: true),
                      _textField(
                        controller: _passCtrl,
                        hint: 'Masukkan Password',
                        icon: Symbols.key,
                        obscure: _hidePass,
                        suffix: IconButton(
                          onPressed: () =>
                              setState(() => _hidePass = !_hidePass),
                          icon: Icon(
                            _hidePass
                                ? Symbols.visibility
                                : Symbols.visibility_off,
                            size: 20,
                            color: AppColors.slate500,
                          ),
                        ),
                        validator: (v) {
                          // Mode edit: kosong = password tidak diubah.
                          if (_isEdit && (v == null || v.isEmpty)) return null;
                          if (v == null || v.length < 6) {
                            return 'Password minimal 6 karakter';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Email Akun Belajar / Sekolah',
                          required: true),
                      _textField(
                        controller: _emailCtrl,
                        hint: 'Masukkan email sekolah',
                        icon: Symbols.mail,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final t = v?.trim() ?? '';
                          if (t.isEmpty) return 'Email wajib diisi';
                          if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                              .hasMatch(t)) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                      ),
                      if (_isEdit) ...[
                        const SizedBox(height: 16),
                        const _FieldLabel('No telepon', required: true),
                        _textField(
                          controller: _phoneCtrl,
                          hint: 'Masukkan no telepon',
                          icon: Symbols.call,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            final t = v?.trim() ?? '';
                            if (t.isEmpty) return 'No telepon wajib diisi';
                            if (t.replaceAll(RegExp(r'\D'), '').length < 8) {
                              return 'No telepon tidak valid';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 16),
                      const _FieldLabel('Nomor Induk Siswa (NISN / NIP)'),
                      _textField(
                        controller: _idCtrl,
                        hint: 'Masukkan NISN / NIP',
                        icon: Symbols.badge,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Peran & Kelas / Unit'),
                      _buildRoleDropdown(),
                      const SizedBox(height: 16),
                      const _FieldLabel('Status Akun'),
                      _buildStatusToggle(),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ---- Header -------------------------------------------------------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.mobileGutter, 16, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin
                      ? 'Kelola Akun Admin'
                      : (_isEdit
                          ? 'Kelola Akun Pengguna'
                          : 'Tambah Akun Pengguna'),
                  style: AppTextStyles.headlineMd(color: AppColors.onSurface)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEdit
                      ? (widget.isAdmin
                          ? 'Perbarui detail informasi akun admin'
                          : 'Perbarui detail informasi akun pengguna')
                      : 'Buat akun pengguna',
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
          Material(
            color: AppColors.primaryFixed,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).pop(),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: Icon(Symbols.close, color: AppColors.onSurface),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Foto pengguna ------------------------------------------------------
  Widget _buildPhoto() {
    if (_photo == null) {
      return CustomPaint(
        painter: _DashedRRectPainter(color: AppColors.primary.fade(0.35)),
        child: Container(
          width: double.infinity,
          height: 160,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed.fade(0.3),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Symbols.add_a_photo,
                    color: AppColors.primary, size: 24),
              ),
              const SizedBox(height: 8),
              Text(
                'Unggah foto pengguna',
                style: AppTextStyles.bodySm(
                  weight: FontWeight.w600,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              _PhotoButton(label: 'Pilih Foto', onTap: _pickPhoto),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: double.infinity,
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.memory(_photo!, fit: BoxFit.cover),
            Positioned(
              right: 12,
              bottom: 12,
              child: _PhotoButton(label: 'Ganti Foto', onTap: _pickPhoto),
            ),
          ],
        ),
      ),
    );
  }

  // ---- Field --------------------------------------------------------------
  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
      prefixIcon: Icon(icon, size: 22, color: AppColors.slate600),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: AppColors.primaryFixed.fade(0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border(AppColors.primaryFixed),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.5),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTextStyles.bodyMd(color: AppColors.onSurface),
      decoration: _decoration(
        hint: hint,
        icon: icon,
        suffixIcon: suffix,
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _roleClass,
      isExpanded: true,
      icon: const Icon(Symbols.keyboard_arrow_down,
          color: AppColors.slate600),
      decoration: _decoration(hint: 'Pilih kelas / unit', icon: Symbols.school),
      style: AppTextStyles.bodyMd(color: AppColors.onSurface),
      borderRadius: BorderRadius.circular(16),
      items: [
        for (final o in _options)
          DropdownMenuItem(value: o, child: Text(o)),
      ],
      onChanged: (v) => setState(() => _roleClass = v),
    );
  }

  // ---- Status akun --------------------------------------------------------
  Widget _buildStatusToggle() {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.fade(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryFixed),
      ),
      child: Row(
        children: [
          Expanded(
            child: _statusSegment(
              label: 'Aktif',
              selected: _active,
              dotColor: _greenFg,
              showCheck: true,
              onTap: () => setState(() => _active = true),
            ),
          ),
          Expanded(
            child: _statusSegment(
              label: 'Ditangguhkan',
              selected: !_active,
              dotColor: AppColors.slate500,
              onTap: () => setState(() => _active = false),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusSegment({
    required String label,
    required bool selected,
    required Color dotColor,
    required VoidCallback onTap,
    bool showCheck = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.surfaceContainerLowest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: dotColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelMd(
                weight: FontWeight.w700,
                color: selected && showCheck
                    ? _greenFg
                    : (selected ? AppColors.onSurface : AppColors.slate600),
              ),
            ),
            if (selected && showCheck) ...[
              const SizedBox(width: 6),
              const Icon(Symbols.check, size: 16, color: _greenFg),
            ],
          ],
        ),
      ),
    );
  }

  // ---- Footer -------------------------------------------------------------
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.mobileGutter, 12, AppSpacing.mobileGutter, 12),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        border: Border(top: BorderSide(color: AppColors.primaryFixed)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: AppColors.slate500),
                ),
                child: Text(
                  'Batal',
                  style: AppTextStyles.labelLg(
                    weight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: const Icon(Symbols.save, size: 20),
                label: Text(
                  _isEdit ? 'Simpan Perubahan' : 'Tambahkan',
                  style: AppTextStyles.labelLg(
                    weight: FontWeight.w700,
                    color: AppColors.onPrimary,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Komponen kecil
// ---------------------------------------------------------------------------
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {this.required = false});
  final String text;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (required)
              const TextSpan(
                text: ' *',
                style: TextStyle(color: AppColors.error),
              ),
          ],
        ),
        style: AppTextStyles.labelMd(
          weight: FontWeight.w700,
          color: AppColors.onSurface,
        ),
      ),
    );
  }
}

class _PhotoButton extends StatelessWidget {
  const _PhotoButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.photo_camera,
                  size: 16, color: AppColors.onPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelMd(
                  weight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Garis putus-putus melengkung untuk area unggah foto.
class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(24),
      ));

    const dash = 7.0;
    const gap = 5.0;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
        d += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) => old.color != color;
}