import 'dart:io' show File;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/services/media_picker_service.dart';
import 'package:lapak8new/features/admin/widgets/avatar_preview_dialog.dart';
import 'package:lapak8new/features/admin/widgets/media_source_sheet.dart';
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
    this.role = 'student',
    required this.active,
    this.phone = '',
    this.photo,
    this.photoFileName,
    this.photoUrl,
    this.removePhoto = false,
    this.userSubcategory,
  });

  final String name;
  final String password;
  final String email;
  final String idNumber; // NISN / NIP
  final String? roleClass; // kelas (khusus siswa/guru)
  final String role; // student | teacher | staff | petugas | user
  final bool active;
  final String phone; // no. telepon (dipakai di mode edit)
  final Uint8List? photo;
  final String? photoFileName;
  final String? photoUrl;
  final bool removePhoto;
  /// Sub-kategori untuk role 'user': 'siswa' atau 'guru'.
  /// Null jika role 'petugas'.
  final String? userSubcategory;
}

// Warna lokal yang belum ada di AppColors.
const _greenFg = Color(0xFF065F46);

class UserFormScreen extends StatefulWidget {
  const UserFormScreen({super.key, this.initial, this.isAdmin = false});

  /// Bila diisi, form berjalan dalam mode edit ("Kelola Akun ...").
  final UserFormData? initial;

  /// Bila true, form ditampilkan dalam konteks menu administrator.
  final bool isAdmin;

  static Future<UserFormData?> show(
    BuildContext context, {
    UserFormData? initial,
    bool isAdmin = false,
  }) {
    return showDialog<UserFormData>(
      context: context,
      barrierDismissible: false,
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
  final _picker = MediaPickerService();

  /// Pilihan kelas (hanya nama kelas, tanpa prefix peran).
  static const _kelasOptions = <String>[
    'X RPL 1',
    'XI RPL 1',
    'XII RPL 1',
    'X TKJ 3',
    'XI MM 2',
    'XI Multimedia (DKV)',
    'XII DKV 1',
  ];

  String? _kelas;
  /// 'petugas' | 'siswa' | 'guru'
  String _role = 'siswa';
  bool _active = true;
  bool _hidePass = true;
  Uint8List? _photo;
  String? _photoFileName;
  String? _photoUrl;
  bool _removePhoto = false;

  bool get _isEdit => widget.initial != null;
  bool get _hasPhoto => _photo != null || (_photoUrl != null && _photoUrl!.isNotEmpty);
  bool get _isPetugas => _role == 'petugas';

  List<String> get _kelasChoices {
    final options = [..._kelasOptions];
    if (_kelas != null && _kelas!.isNotEmpty && !options.contains(_kelas)) {
      options.add(_kelas!);
    }
    return options;
  }

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
      _active = i.active;
      _photo = i.photo;
      _photoFileName = i.photoFileName;
      _photoUrl = i.photoUrl;
      _applyInitialRole(i);
    }
  }

  void _applyInitialRole(UserFormData i) {
    final role = i.role.toLowerCase().trim();
    final sub = i.userSubcategory?.toLowerCase().trim();
    if (role == 'staff' || role == 'petugas' || role == 'staf') {
      _role = 'petugas';
      // Preserve existing class/unit for staff/petugas to avoid data loss on edit.
      _kelas = i.roleClass;
      return;
    }
    _role = (role == 'teacher' || role == 'guru' || sub == 'guru')
        ? 'guru'
        : 'siswa';
    _kelas = i.roleClass;
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

  Future<void> _pickPhoto() async {
    final source = await showMediaSourceSheet(
      context,
      isPhoto: true,
      title: 'Tambah Foto Pengguna',
      subtitle: 'Pilih sumber foto pengguna.',
    );
    if (source == null || !mounted) return;

    final outcome = await _picker.pickPhotos(source: source, remainingSlots: 1);
    if (!mounted) return;

    if (outcome.files.isEmpty) {
      if (outcome.message != null) _showSnack(outcome.message!);
      return;
    }

    final file = outcome.files.first;
    if (file.size > 10 * 1024 * 1024) {
      _showSnack('Ukuran foto maksimal 10MB.');
      return;
    }

    final use = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => AvatarPreviewDialog(file: file),
    );
    if (use != true || !mounted) return;

    Uint8List? bytes = file.bytes == null ? null : Uint8List.fromList(file.bytes!);
    if (bytes == null && !kIsWeb && file.localPath.isNotEmpty) {
      bytes = await File(file.localPath).readAsBytes();
    }
    if (bytes == null || !mounted) return;
    setState(() {
      _photo = bytes;
      _photoFileName = file.fileName;
      _removePhoto = false;
    });
  }

  void _removePhotoAction() => setState(() {
        _photo = null;
        _photoFileName = null;
        _photoUrl = null;
        _removePhoto = true;
      });

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final data = UserFormData(
      name: _nameCtrl.text.trim(),
      password: _passCtrl.text,
      email: _emailCtrl.text.trim(),
      idNumber: _idCtrl.text.trim(),
      phone: _phoneCtrl.text.trim(),
      roleClass: _kelas,
      role: _mapRoleToLegacy(_role),
      active: _active,
      photo: _photo,
      photoFileName: _photoFileName,
      photoUrl: _photoUrl,
      removePhoto: _removePhoto,
      userSubcategory: _role == 'petugas' ? null : _role,
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

  /// Mapping UI role -> legacy role string for UserFormData compatibility.
  String _mapRoleToLegacy(String role) {
    switch (role.toLowerCase().trim()) {
      case 'petugas':
        return 'staff';
      case 'guru':
        return 'teacher';
      case 'siswa':
      default:
        return 'student';
    }
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: AppColors.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 480, maxHeight: maxHeight),
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
                      const SizedBox(height: 6),
                      Text(
                        'Format yang didukung: Semua format gambar (maks. 10MB)',
                        style: AppTextStyles.labelSm(
                          weight: FontWeight.w500,
                          color: AppColors.slate600,
                        ),
                      ),
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
                      _FieldLabel('Password', required: !_isEdit),
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
                      const SizedBox(height: 16),
                      const _FieldLabel('Nomor Induk Siswa (NISN / NIP)',
                          required: true),
                      _textField(
                        controller: _idCtrl,
                        hint: 'Masukkan NISN / NIP',
                        icon: Symbols.badge,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nomor induk wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      _FieldLabel('Kelas', required: !_isPetugas),
                      _buildKelasDropdown(),
                      const SizedBox(height: 16),
                      const _FieldLabel('Role', required: true),
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
                      ? (_isEdit ? 'Kelola Akun Admin' : 'Tambah Akun Pengguna')
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
    return CustomPaint(
      painter: _DashedRRectPainter(color: AppColors.primary.fade(0.35)),
      child: Container(
        height: 100,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primaryFixed.fade(0.3),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                width: 76,
                height: 76,
                child: _photo != null
                    ? Image.memory(
                        _photo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: AppColors.surfaceContainerLowest,
                          child: Icon(Symbols.person,
                              color: AppColors.primary, size: 36),
                        ),
                      )
                    : (_photoUrl != null && _photoUrl!.isNotEmpty)
                        ? Image.network(
                            _photoUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const ColoredBox(
                              color: AppColors.surfaceContainerLowest,
                              child: Icon(Symbols.person,
                                  color: AppColors.primary, size: 36),
                            ),
                          )
                        : const ColoredBox(
                            color: AppColors.surfaceContainerLowest,
                            child: Icon(Symbols.person,
                                color: AppColors.primary, size: 36),
                          ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unggah foto pengguna',
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w600,
                      color: AppColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _PhotoButton(
                        label: _hasPhoto ? 'Ganti Foto' : 'Pilih Foto',
                        onTap: _pickPhoto,
                      ),
                      if (_hasPhoto)
                        TextButton(
                          onPressed: _removePhotoAction,
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.error,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: const Size(0, 32),
                          ),
                          child: Text(
                            'Hapus',
                            style: AppTextStyles.labelSm(
                              weight: FontWeight.w700,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
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

  // ---- Kelas dropdown -----------------------------------------------------
  Widget _buildKelasDropdown() {
    final choices = _kelasChoices;
    return _ModernDropdown<String>(
      value: _kelas,
      hint: _isPetugas ? 'Tidak diperlukan untuk Petugas' : 'Pilih kelas',
      icon: Symbols.school,
      enabled: !_isPetugas,
      items: [
        for (final kelas in choices)
          _ModernDropdownItem(value: kelas, label: kelas),
      ],
      validator: (v) {
        if (_isPetugas) return null;
        if (v == null || v.trim().isEmpty) return 'Kelas wajib dipilih';
        return null;
      },
      onChanged: _isPetugas
          ? null
          : (value) {
              if (value == null) return;
              setState(() => _kelas = value);
            },
    );
  }

  // ---- Role dropdown ------------------------------------------------------
  Widget _buildRoleDropdown() {
    return _ModernDropdown<String>(
      value: _role,
      hint: 'Pilih role',
      icon: Symbols.manage_accounts,
      items: const [
        _ModernDropdownItem(value: 'petugas', label: 'Petugas'),
        _ModernDropdownItem(value: 'siswa', label: 'Siswa'),
        _ModernDropdownItem(value: 'guru', label: 'Guru'),
      ],
      validator: (v) {
        if (v == null || v.isEmpty) return 'Role wajib dipilih';
        return null;
      },
      onChanged: (value) {
        if (value == null) return;
        setState(() {
          _role = value;
          if (_role == 'petugas') {
            // Kelas hanya relevan untuk Siswa/Guru. Kosongkan agar
            // kelas tidak ikut tersimpan untuk Petugas.
            _kelas = null;
          }
        });
      },
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

class _ModernDropdownItem<T> {
  const _ModernDropdownItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

class _ModernDropdown<T> extends StatefulWidget {
  const _ModernDropdown({
    required this.items,
    required this.onChanged,
    this.value,
    this.hint,
    this.icon,
    this.validator,
    this.enabled = true,
  });

  final List<_ModernDropdownItem<T>> items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final String? hint;
  final IconData? icon;
  final String? Function(T?)? validator;
  final bool enabled;

  @override
  State<_ModernDropdown<T>> createState() => _ModernDropdownState<T>();
}

class _ModernDropdownState<T> extends State<_ModernDropdown<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  final GlobalKey _fieldKey = GlobalKey();
  OverlayEntry? _overlay;
  late final AnimationController _controller;
  late final Animation<double> _expand;
  late final Animation<double> _fade;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      reverseDuration: const Duration(milliseconds: 140),
    );
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    _expand = curved;
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _overlay?.remove();
    _overlay = null;
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ModernDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _close();
      });
    }
    if (widget.value != oldWidget.value && _open) {
      _overlay?.markNeedsBuild();
    }
  }

  _ModernDropdownItem<T>? get _selectedItem {
    for (final item in widget.items) {
      if (item.value == widget.value) return item;
    }
    return null;
  }

  void _toggle() {
    if (!widget.enabled || widget.onChanged == null) return;
    if (_open) {
      _close();
    } else {
      _openOverlay();
    }
  }

  void _openOverlay() {
    if (_open) return;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _overlay = OverlayEntry(builder: _buildOverlay);
    overlay.insert(_overlay!);
    setState(() => _open = true);
    _controller.forward(from: 0);
  }

  void _close() {
    if (!_open) return;
    if (mounted) setState(() => _open = false);
    _controller.stop();
    _overlay?.remove();
    _overlay = null;
  }

  void _select(_ModernDropdownItem<T> item) {
    widget.onChanged?.call(item.value);
    _close();
  }

  Widget _buildOverlay(BuildContext context) {
    final renderBox = _fieldKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return const SizedBox.shrink();
    final size = renderBox.size;
    final offset = renderBox.localToGlobal(Offset.zero);
    final screen = MediaQuery.sizeOf(context);
    final spaceBelow = screen.height - offset.dy - size.height - 12;
    final spaceAbove = offset.dy - 12;
    final openAbove = spaceBelow < 220 && spaceAbove > spaceBelow;
    final maxHeight = (openAbove ? spaceAbove : spaceBelow)
        .clamp(140.0, 280.0)
        .toDouble();

    final menu = FadeTransition(
      opacity: _fade,
      child: SizeTransition(
        sizeFactor: _expand,
        alignment: openAbove ? Alignment.bottomCenter : Alignment.topCenter,
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(maxHeight: maxHeight),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primaryFixed),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x1A191C1E),
                  blurRadius: 16,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 6),
              shrinkWrap: true,
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final selected = item.value == widget.value;
                return InkWell(
                  onTap: () => _select(item),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    color: selected
                        ? AppColors.primaryFixed.fade(0.45)
                        : Colors.transparent,
                    child: Row(
                      children: [
                        if (item.icon != null) ...[
                          Icon(
                            item.icon,
                            size: 18,
                            color: selected
                                ? AppColors.primary
                                : AppColors.slate600,
                          ),
                          const SizedBox(width: 10),
                        ],
                        Expanded(
                          child: Text(
                            item.label,
                            style: AppTextStyles.bodyMd(
                              weight:
                                  selected ? FontWeight.w700 : FontWeight.w500,
                              color: selected
                                  ? AppColors.primary
                                  : AppColors.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (selected)
                          const Icon(Symbols.check_rounded,
                              size: 18, color: AppColors.primary),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    final positioned = openAbove
        ? Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.topLeft,
              followerAnchor: Alignment.bottomLeft,
              offset: const Offset(0, -6),
              child: menu,
            ),
          )
        : Positioned(
            width: size.width,
            child: CompositedTransformFollower(
              link: _link,
              showWhenUnlinked: false,
              targetAnchor: Alignment.bottomLeft,
              followerAnchor: Alignment.topLeft,
              offset: const Offset(0, 6),
              child: menu,
            ),
          );

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _close,
            child: const SizedBox.expand(),
          ),
        ),
        positioned,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selectedItem;
    final enabled = widget.enabled && widget.onChanged != null;

    return FormField<T>(
      initialValue: widget.value,
      validator: widget.validator,
      builder: (field) {
        final hasError = field.hasError;
        final borderColor = !enabled
            ? AppColors.primaryFixed.fade(0.7)
            : hasError
                ? AppColors.error
                : _open
                    ? AppColors.primary
                    : AppColors.primaryFixed;
        final bgColor = enabled
            ? AppColors.primaryFixed.fade(0.35)
            : AppColors.surfaceContainerLow;

        final trigger = CompositedTransformTarget(
          link: _link,
          child: GestureDetector(
            key: _fieldKey,
            onTap: enabled ? _toggle : null,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              curve: Curves.easeOut,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: borderColor,
                  width: _open ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon ?? Symbols.expand_more,
                    size: 22,
                    color: enabled ? AppColors.slate600 : AppColors.slate400,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      selected?.label ?? widget.hint ?? 'Pilih',
                      style: selected != null
                          ? AppTextStyles.bodyMd(
                              color: enabled
                                  ? AppColors.onSurface
                                  : AppColors.slate500,
                            )
                          : AppTextStyles.bodyMd(color: AppColors.slate500),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  AnimatedRotation(
                    turns: _open ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOutCubic,
                    child: Icon(
                      Symbols.keyboard_arrow_down,
                      color: enabled ? AppColors.slate600 : AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

        // Keep FormField value in sync
        if (field.value != widget.value) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (field.mounted) field.didChange(widget.value);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            trigger,
            if (hasError)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 6),
                child: Text(
                  field.errorText ?? '',
                  style: AppTextStyles.labelSm(color: AppColors.error),
                ),
              ),
          ],
        );
      },
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