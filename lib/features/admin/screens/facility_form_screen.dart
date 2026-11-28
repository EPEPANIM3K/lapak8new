import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/services/media_picker_service.dart';
import 'package:lapak8new/features/admin/widgets/media_source_sheet.dart';
import 'package:lapak8new/features/facilities/models/facility.dart';
import 'package:lapak8new/shared/widgets/blurred_bottom_sheet.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';

// Simpan di: lib/features/admin/screens/facility_form_screen.dart

/// Data form barang. Dikirim ke form saat mode edit, dan dikembalikan
/// (lewat `Navigator.pop(data)`) saat pengguna menyimpan.
class FacilityFormData {
  const FacilityFormData({
    required this.name,
    this.category = '',
    required this.location,
    this.locationId,
    required this.units,
    this.imageUrl,
    this.imageBytes,
    this.imageFileName,
    this.removePhoto = false,
  });

  final String name;
  final String category;
  final String location;
  final String? locationId;
  final int units;
  final String? imageUrl; // foto yang sudah ada di server
  final Uint8List? imageBytes; // foto baru yang dipilih
  final String? imageFileName;
  final bool removePhoto;
}

/// Mode tambah: `initial == null`. Mode edit: kirim data barang di `initial`.
class FacilityFormScreen extends StatefulWidget {
  const FacilityFormScreen({
    super.key,
    this.initial,
    this.locations = const [],
  });

  final FacilityFormData? initial;
  final List<LokasiItem> locations;

  static Future<FacilityFormData?> show(
    BuildContext context, {
    FacilityFormData? initial,
    List<LokasiItem> locations = const [],
  }) {
    return showBlurredBottomSheet<FacilityFormData>(
      context: context,
      heightFactor: 0.9,
      maxWidth: 480,
      showDragHandle: true,
      builder: (_) =>
          FacilityFormScreen(initial: initial, locations: locations),
    );
  }

  @override
  State<FacilityFormScreen> createState() => _FacilityFormScreenState();
}

class _FacilityFormScreenState extends State<FacilityFormScreen> {
  static const int _maxBytes = 10 * 1024 * 1024; // 10 MB

  static const List<String> _fallbackLocations = [
    'Studio MM Lt. 2',
    'Sarpras Gedung A',
    'Gudang Sarpras',
    'Lab RPL 1',
    'Lab Jaringan',
  ];

  final _formKey = GlobalKey<FormState>();
  final _picker = MediaPickerService();

  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late String? _location;
  late int _units;
  Uint8List? _imageBytes;
  String? _imageFileName;
  String? _imageUrl;
  bool _removePhoto = false;

  bool get _isEdit => widget.initial != null;

  List<String> get _locationNames {
    final names = widget.locations.isNotEmpty
        ? widget.locations.map((l) => l.nama).toList()
        : [..._fallbackLocations];
    final initialLoc = widget.initial?.location;
    if (initialLoc != null &&
        initialLoc.isNotEmpty &&
        initialLoc != '-' &&
        !names.contains(initialLoc)) {
      names.insert(0, initialLoc);
    }
    return names;
  }

  String? _findLocationId(String name) {
    for (final loc in widget.locations) {
      if (loc.nama == name) return loc.id;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _nameCtrl = TextEditingController(text: d?.name ?? '');
    _categoryCtrl = TextEditingController(text: d?.category ?? '');
    _location = (d?.location.isNotEmpty ?? false) && d!.location != '-'
        ? d.location
        : null;
    _units = d?.units ?? 1;
    _imageBytes = d?.imageBytes;
    _imageFileName = d?.imageFileName;
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
    final source = await showMediaSourceSheet(
      context,
      isPhoto: true,
      title: 'Foto Item Inventaris',
      subtitle: 'Pilih sumber foto barang (semua format didukung).',
    );
    if (source == null || !mounted) return;

    final outcome = await _picker.pickPhotos(source: source, remainingSlots: 1);
    if (!mounted) return;

    if (outcome.files.isEmpty) {
      if (outcome.message != null) _toast(outcome.message!);
      return;
    }

    final file = outcome.files.first;
    if (file.size > _maxBytes) {
      _toast('Ukuran foto maksimal 10MB.');
      return;
    }

    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      _toast('Gagal membaca berkas foto.');
      return;
    }

    setState(() {
      _imageBytes = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
      _imageFileName = file.fileName;
      _removePhoto = false;
    });
  }

  void _clearPhoto() {
    setState(() {
      _imageBytes = null;
      _imageFileName = null;
      _imageUrl = null;
      _removePhoto = true;
    });
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
    final loc = _location!;
    Navigator.of(context).pop(
      FacilityFormData(
        name: _nameCtrl.text.trim(),
        category: _categoryCtrl.text.trim(),
        location: loc,
        locationId: _findLocationId(loc),
        units: _units,
        imageUrl: _imageUrl,
        imageBytes: _imageBytes,
        imageFileName: _imageFileName,
        removePhoto: _removePhoto,
      ),
    );
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        const Divider(height: 1, color: AppColors.primaryFixed),
        Expanded(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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
                    'Format yang didukung: Semua format gambar (maks. 10MB)',
                    style: AppTextStyles.labelSm(
                      weight: FontWeight.w500,
                      color: AppColors.slate600,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const _FieldLabel('Judul Item / Nama Barang', required: true),
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
                  const _FieldLabel(
                    'Lokasi Penyimpanan / Peminjaman',
                    required: true,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _location,
                    isExpanded: true,
                    icon: const Icon(
                      Symbols.keyboard_arrow_down,
                      color: AppColors.slate600,
                    ),
                    decoration: _decoration(
                      hint: 'Pilih lokasi',
                      icon: Symbols.location_on,
                    ),
                    style: AppTextStyles.bodyMd(color: AppColors.onSurface),
                    borderRadius: BorderRadius.circular(16),
                    items: [
                      for (final l in _locationNames)
                        DropdownMenuItem(value: l, child: Text(l)),
                    ],
                    onChanged: (v) => setState(() => _location = v),
                    validator: (v) => v == null ? 'Lokasi wajib dipilih' : null,
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
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.mobileGutter, 16, 16, 14),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isEdit ? 'Edit Item' : 'Tambah Item',
                  style: AppTextStyles.headlineMd(
                    color: AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w800),
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
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mobileGutter,
        12,
        AppSpacing.mobileGutter,
        12,
      ),
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
    final hasImage =
        _imageBytes != null || (_imageUrl != null && _imageUrl!.isNotEmpty);

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
                child: const Icon(
                  Symbols.add_a_photo,
                  color: AppColors.primary,
                  size: 24,
                ),
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

    final fallback = Container(
      color: AppColors.primaryFixed,
      alignment: Alignment.center,
      child: const Icon(Symbols.image, size: 40, color: AppColors.primary),
    );

    final Widget image = _imageBytes != null
        ? Image.memory(
            _imageBytes!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          )
        : Image.network(
            _imageUrl!,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
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
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Material(
                    color: AppColors.errorContainer,
                    shape: const StadiumBorder(),
                    child: InkWell(
                      customBorder: const StadiumBorder(),
                      onTap: _clearPhoto,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Text(
                          'Hapus',
                          style: AppTextStyles.labelMd(
                            weight: FontWeight.w700,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PhotoButton(label: 'Ganti Foto', onTap: _pickPhoto),
                ],
              ),
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
              const Icon(
                Symbols.photo_camera,
                size: 16,
                color: AppColors.onPrimary,
              ),
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
              style: AppTextStyles.headlineSm(
                color: AppColors.primary,
              ).copyWith(fontWeight: FontWeight.w800),
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
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24)),
      );

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
