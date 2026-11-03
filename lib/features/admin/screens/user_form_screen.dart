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
const _fieldBg = Color(0xFFEFEDFB);
const _outline = Color(0xFFC4C5D5);
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
    return showDialog<UserFormData>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => UserFormScreen(initial: initial, isAdmin: isAdmin),
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
          if (mounted) Navigator.of(context).pop(data);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.9;
    return Dialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      elevation: 6,
      clipBehavior: Clip.antiAlias,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 420, maxHeight: maxHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(),
            const Divider(height: 1, color: AppColors.surfaceContainerLow),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPhotoCard(),
                      const SizedBox(height: 16),
                      _label('Nama Lengkap', required: true),
                      _textField(
                        controller: _nameCtrl,
                        hint: 'Masukkan nama lengkap',
                        icon: Symbols.person,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _label('Password', required: true),
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
                      _label('Email Akun Belajar / Sekolah', required: true),
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
                        _label('No telepon', required: true),
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
                      _label('Nomor Induk Siswa (NISN / NIP)'),
                      _textField(
                        controller: _idCtrl,
                        hint: 'Masukkan NISN / NIP',
                        icon: Symbols.badge,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      _label('Peran & Kelas / Unit'),
                      _buildRoleDropdown(),
                      const SizedBox(height: 16),
                      _label('Status Akun'),
                      _buildStatusToggle(),
                    ],
                  ),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.surfaceContainerLow),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ---- Header ---------------------------------------------------------------
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdmin
                      ? 'Kelola Akun Admin'
                      : (_isEdit ? 'Kelola Akun Pengguna' : 'Tambah Akun Pengguna'),
                  style: AppTextStyles.headlineSm(color: AppColors.onSurface)
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
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: const Icon(Symbols.close,
                  size: 22, color: AppColors.slate600),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Kartu foto -----------------------------------------------------------
  Widget _buildPhotoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 76,
            height: 76,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppColors.primaryFixed,
                    borderRadius: BorderRadius.circular(22),
                    image: _photo == null
                        ? null
                        : DecorationImage(
                            image: MemoryImage(_photo!),
                            fit: BoxFit.cover,
                          ),
                  ),
                  child: _photo == null
                      ? const Icon(Symbols.person,
                          size: 30, color: AppColors.slate600)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: _fieldBg, width: 2),
                      ),
                      child: const Icon(Symbols.add,
                          size: 16, color: AppColors.onPrimary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Material(
                      color: AppColors.primary,
                      shape: const StadiumBorder(),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: _pickPhoto,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Symbols.photo_camera,
                                  size: 16, color: AppColors.onPrimary),
                              const SizedBox(width: 6),
                              Text(
                                'Pilih Foto',
                                style: AppTextStyles.labelSm(
                                  weight: FontWeight.w700,
                                  color: AppColors.onPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: _photo == null ? null : _removePhoto,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, 32),
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        foregroundColor: AppColors.error,
                        disabledForegroundColor: AppColors.slate500,
                      ),
                      child: Text(
                        'Hapus',
                        style: AppTextStyles.labelSm(
                          weight: FontWeight.w700,
                          color: _photo == null
                              ? AppColors.slate500
                              : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Format: JPG, PNG (maks. 2MB)',
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w500,
                    color: AppColors.slate600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---- Field ----------------------------------------------------------------
  Widget _label(String text, {bool required = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 6),
      child: Text.rich(
        TextSpan(
          text: text,
          children: [
            if (required)
              const TextSpan(
                text: '  *',
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

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool obscure = false,
    Widget? suffix,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    OutlineInputBorder border([Color? color]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.full),
          borderSide: color == null
              ? BorderSide.none
              : BorderSide(color: color, width: 1.5),
        );

    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTextStyles.bodyMd(color: AppColors.onSurface),
      decoration: InputDecoration(
        filled: true,
        fillColor: _fieldBg,
        hintText: hint,
        hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
        prefixIcon: Icon(icon, size: 22, color: AppColors.slate600),
        suffixIcon: suffix,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: border(),
        enabledBorder: border(),
        focusedBorder: border(AppColors.primary),
        errorBorder: border(AppColors.error),
        focusedErrorBorder: border(AppColors.error),
      ),
    );
  }

  Widget _buildRoleDropdown() {
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          const Icon(Symbols.school, size: 22, color: AppColors.slate600),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _roleClass,
                isExpanded: true,
                borderRadius: BorderRadius.circular(20),
                dropdownColor: AppColors.surfaceContainerLowest,
                icon: const Icon(Symbols.keyboard_arrow_down,
                    color: AppColors.slate600),
                hint: Text(
                  'Pilih kelas / unit',
                  style: AppTextStyles.bodyMd(color: AppColors.onSurface),
                ),
                style: AppTextStyles.bodyMd(color: AppColors.onSurface),
                items: [
                  for (final o in _options)
                    DropdownMenuItem(value: o, child: Text(o)),
                ],
                onChanged: (v) => setState(() => _roleClass = v),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---- Status akun ----------------------------------------------------------
  Widget _buildStatusToggle() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: _fieldBg,
        borderRadius: BorderRadius.circular(AppRadius.full),
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
          color: selected ? AppColors.surfaceContainerLowest : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: selected ? AppShadows.sm : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
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

  // ---- Footer ---------------------------------------------------------------
  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  shape: const StadiumBorder(),
                  side: const BorderSide(color: _outline),
                  foregroundColor: AppColors.slate600,
                ),
                child: Text(
                  'Batal',
                  style: AppTextStyles.labelLg(
                    weight: FontWeight.w700,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SizedBox(
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _submit,
                icon: _isEdit
                    ? const Icon(Symbols.save, size: 20)
                    : const SizedBox.shrink(),
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