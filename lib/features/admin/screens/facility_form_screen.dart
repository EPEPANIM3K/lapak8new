import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';

// Simpan di: lib/features/admin/screens/facility_form_screen.dart

/// Data form barang. Dikirim ke form saat mode edit, dan dikembalikan
/// (lewat `context.pop(data)`) saat pengguna menyimpan.
class FacilityFormData {
  const FacilityFormData({
    required this.name,
    this.category = '',
    required this.location,
    required this.units,
    this.imageUrl,
    this.imagePath,
  });

  final String name;
  final String category;
  final String location;
  final int units;
  final String? imageUrl; // foto yang sudah ada di server
  final String? imagePath; // foto baru yang dipilih dari galeri
}

/// Mode tambah: `initial == null`. Mode edit: kirim data barang di `initial`.
class FacilityFormScreen extends StatefulWidget {
  const FacilityFormScreen({super.key, this.initial});

  final FacilityFormData? initial;

  @override
  State<FacilityFormScreen> createState() => _FacilityFormScreenState();
}

class _FacilityFormScreenState extends State<FacilityFormScreen> {
  static const int _maxBytes = 5 * 1024 * 1024; // 5 MB

  // TODO: ambil daftar lokasi dari backend.
  static const List<String> _baseLocations = [
    'Studio MM Lt. 2',
    'Sarpras Gedung A',
    'Gudang Sarpras',
    'Lab RPL 1',
    'Lab Jaringan',
  ];

  final _formKey = GlobalKey<FormState>();
  final _picker = ImagePicker();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late String? _location;
  late int _units;
  String? _imagePath;
  String? _imageUrl;

  bool get _isEdit => widget.initial != null;

  List<String> get _locations {
    final loc = widget.initial?.location;
    if (loc != null && loc.isNotEmpty && !_baseLocations.contains(loc)) {
      return [loc, ..._baseLocations];
    }
    return _baseLocations;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _categoryCtrl = TextEditingController(text: d?.category ?? '');
    _location = (d?.location.isNotEmpty ?? false) ? d!.location : null;
    _units = d?.units ?? 1;
    _imagePath = d?.imagePath;
    _imageUrl = d?.imageUrl;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Aksi
  // -------------------------------------------------------------------------
  Future<void> _pickPhoto() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null) return;

    final ext = file.path.split('.').last.toLowerCase();
    if (!['jpg', 'jpeg', 'png'].contains(ext)) {
      _toast('Format foto harus JPG atau PNG.');
      return;
    }
    if (await file.length() > _maxBytes) {
      _toast('Ukuran foto maksimal 5MB.');
      return;
    }
    setState(() => _imagePath = file.path);
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_isEdit) {
      await showDialog<void>(
        context: context,
        builder: (_) => ConfirmDialog(
          icon: Symbols.save,
          title: 'Simpan perubahan?',
          message: 'Perubahan data barang akan diperbarui di inventaris.',
          confirmText: 'Ya, Simpan',
          onConfirm: _submit,
        ),
      );
      return;
    }
    _submit();
  }

  void _submit() {
    if (!mounted) return;
    context.pop(
      FacilityFormData(
        name: _nameCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        location: _location!,
        units: _units,
        imageUrl: _imageUrl,
        imagePath: _imagePath,
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
            _buildHeader(context),
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
                      const _FieldLabel('Foto Item Inventaris'),
                      _buildPhoto(),
                      const SizedBox(height: 6),
                      Text(
                        'Format yang didukung: JPG, PNG (maks. 5MB)',
                        style: AppTextStyles.labelSm(
                          weight: FontWeight.w500,
                          color: AppColors.slate600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Judul Item / Nama Barang',
                          required: true),
                      TextFormField(
                        controller: _nameCtrl,
                        textCapitalization: TextCapitalization.words,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration(
                          hint: 'Masukkan nama barang',
                          icon: Symbols.inventory_2,
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Nama barang wajib diisi'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Kategori'),
                      TextFormField(
                        controller: _categoryCtrl,
                        textInputAction: TextInputAction.next,
                        decoration: _decoration(
                          hint: 'Masukkan subjudul, kategori, atau merk',
                          icon: Symbols.sell,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Lokasi Penyimpanan / Peminjaman',
                          required: true),
                      DropdownButtonFormField<String>(
                        value: _location,
                        isExpanded: true,
                        icon: const Icon(Symbols.keyboard_arrow_down,
                            color: AppColors.slate600),
                        decoration: _decoration(
                          hint: 'Pilih lokasi',
                          icon: Symbols.location_on,
                        ),
                        style: AppTextStyles.bodyMd(color: AppColors.onSurface),
                        borderRadius: BorderRadius.circular(16),
                        items: [
                          for (final l in _locations)
                            DropdownMenuItem(value: l, child: Text(l)),
                        ],
                        onChanged: (v) => setState(() => _location = v),
                        validator: (v) =>
                            v == null ? 'Lokasi wajib dipilih' : null,
                      ),
                      const SizedBox(height: 16),
                      const _FieldLabel('Jumlah Unit Item', required: true),
                      _UnitStepper(
                        value: _units,
                        onChanged: (v) => setState(() => _units = v),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            _buildFooter(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.mobileGutter, 16, 12, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Item' : 'Tambah Item',
                  style: AppTextStyles.headlineMd(color: AppColors.onSurface)
                      .copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  _isEdit
                      ? 'Perbarui detail informasi barang inventaris'
                      : 'Tambahkan informasi barang inventaris',
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
              onTap: () => context.pop(),
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

  Widget _buildFooter(BuildContext context) {
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
                onPressed: () => context.pop(),
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
                onPressed: _save,
                icon: const Icon(Symbols.save, size: 20),
                label: Text(
                  _isEdit ? 'Simpan Perubahan' : 'Simpan Item',
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

  Widget _buildPhoto() {
    final hasImage = _imagePath != null || _imageUrl != null;

    if (!hasImage) {
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
                'Unggah foto barang sarpras',
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

    final Widget image = _imagePath != null
        ? Image.file(File(_imagePath!), fit: BoxFit.cover)
        : Image.network(
            _imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppColors.primaryFixed,
              alignment: Alignment.center,
              child: const Icon(Symbols.image,
                  size: 40, color: AppColors.primary),
            ),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: SizedBox(
        width: double.infinity,
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            image,
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

  InputDecoration _decoration({required String hint, required IconData icon}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: c, width: w),
        );
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
      prefixIcon: Icon(icon, size: 22, color: AppColors.slate600),
      filled: true,
      fillColor: AppColors.primaryFixed.fade(0.35),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: border(AppColors.primaryFixed),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 1.5),
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

class _UnitStepper extends StatelessWidget {
  const _UnitStepper({required this.value, required this.onChanged});

  static const int _min = 0;
  static const int _max = 999;

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.fade(0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primaryFixed),
      ),
      child: Row(
        children: [
          const Icon(Symbols.layers, size: 22, color: AppColors.slate600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Unit tersedia di inventaris',
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.bodySm(
                weight: FontWeight.w500,
                color: AppColors.onSurface,
              ),
            ),
          ),
          _RoundStepButton(
            icon: Symbols.remove,
            onTap: value > _min ? () => onChanged(value - 1) : null,
          ),
          SizedBox(
            width: 40,
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSm(color: AppColors.primary)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          _RoundStepButton(
            icon: Symbols.add,
            onTap: value < _max ? () => onChanged(value + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _RoundStepButton extends StatelessWidget {
  const _RoundStepButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerLowest,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black26,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null ? AppColors.slate500 : AppColors.onSurface,
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