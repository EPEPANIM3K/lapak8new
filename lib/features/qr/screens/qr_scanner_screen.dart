import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:zxing2/qrcode.dart' as zx;

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/borrowings/services/peminjaman_service.dart';

// Simpan di: lib/features/scanner/screens/qr_scanner_screen.dart

const _cameraBg = Color(0xFF0B1224);
const _frameBlue = Color(0xFF2563EB);

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  static const double _frameSize = 260;

  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  final ImagePicker _picker = ImagePicker();

  late final AnimationController _lineAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat(reverse: true);

  bool _busy = false; // true selama hasil scan sedang ditampilkan

  @override
  void dispose() {
    _lineAnim.dispose();
    _controller.dispose();
    super.dispose();
  }

  // -------------------------------------------------------------------------
  // Logika scan
  // -------------------------------------------------------------------------
  void _onDetect(BarcodeCapture capture) {
    if (_busy) return;
    final code = capture.barcodes.isEmpty
        ? null
        : capture.barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;
    _handleResult(code);
  }

  /// Pindai dari galeri. Di HP dicoba pemindai bawaan dulu; kalau gagal
  /// (atau di web), gambar dibaca dengan decoder Dart murni.
  Future<void> _pickFromGallery() async {
    if (_busy) return;
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      String? code;
      if (!kIsWeb) {
        try {
          final capture = await _controller.analyzeImage(file.path);
          if (capture != null && capture.barcodes.isNotEmpty) {
            code = capture.barcodes.first.rawValue;
          }
        } catch (_) {
          // lanjut ke decoder Dart di bawah
        }
      }
      if (code == null || code.isEmpty) {
        code = _decodeQrFromBytes(await file.readAsBytes());
      }
      _handleResult(code);
    } catch (_) {
      _handleResult(null);
    }
  }

  /// Membaca QR dari byte gambar (PNG/JPG). Berfungsi di semua platform.
  String? _decodeQrFromBytes(Uint8List bytes) {
    try {
      var image = img.decodeImage(bytes);
      if (image == null) return null;

      const maxSide = 1200;
      if (image.width > maxSide || image.height > maxSide) {
        image = image.width >= image.height
            ? img.copyResize(image, width: maxSide)
            : img.copyResize(image, height: maxSide);
      }

      final source = zx.RGBLuminanceSource(
        image.width,
        image.height,
        image
            .convert(numChannels: 4)
            .getBytes(order: img.ChannelOrder.abgr)
            .buffer
            .asInt32List(),
      );
      final bitmap = zx.BinaryBitmap(zx.HybridBinarizer(source));
      return zx.QRCodeReader().decode(bitmap).text;
    } catch (_) {
      return null;
    }
  }

  /// [code] null/kosong = QR tidak terbaca atau tidak valid.
  Future<void> _handleResult(String? code) async {
    if (_busy) return;
    setState(() => _busy = true);
    await _controller.stop();
    if (!mounted) return;

    try {
      if (code == null || code.isEmpty) {
        await _showResult(
          success: false,
          message: 'QR tidak terbaca. Coba pindai kembali.',
        );
        return;
      }

      final result = await peminjamanService.prosesQrAdmin(code);
      switch (result['tipe_tiket']) {
        case 'pengambilan':
          await _showResult(
            success: true,
            title: 'Pengambilan Berhasil',
            message:
                'Peminjaman ${result['kode_booking'] ?? ''} telah ditandai '
                'sedang dipinjam.',
          );
          break;
        case 'pengembalian':
          await _confirmQrReturn(result);
          break;
        default:
          throw const PeminjamanException(
            'Jenis tiket QR dari server tidak valid.',
          );
      }
    } on PeminjamanException catch (error) {
      await _showResult(success: false, message: error.pesan);
    } catch (_) {
      await _showResult(
        success: false,
        message:
            'Terjadi kesalahan saat memproses QR. Periksa koneksi lalu coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        await _controller.start();
      }
    }
  }

  Future<void> _confirmQrReturn(Map<String, dynamic> result) async {
    final borrowingId = result['peminjaman_id'];
    if (borrowingId is! String || borrowingId.isEmpty) {
      throw const PeminjamanException('ID peminjaman dari server tidak valid.');
    }
    final borrower = result['peminjam'];
    final borrowerName = borrower is Map
        ? borrower['nama_lengkap'] as String? ?? 'Peminjam LAPAK8'
        : 'Peminjam LAPAK8';
    final items = result['items'];
    final itemSummary = items is List
        ? items
              .whereType<Map>()
              .map((item) {
                final name = item['nama_fasilitas'] as String? ?? 'Barang';
                final quantity = item['jumlah'] as num? ?? 1;
                return '$name (${quantity.toInt()} unit)';
              })
              .join(', ')
        : 'Barang tidak diketahui';
    final late = result['terlambat'] == true;
    final noteController = TextEditingController();
    var condition = 'baik';
    final confirmation = await showDialog<Map<String, String?>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Konfirmasi Pengembalian'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Peminjam: $borrowerName'),
                const SizedBox(height: 8),
                Text('Barang: $itemSummary'),
                const SizedBox(height: 8),
                Text(
                  late ? 'Status: Terlambat' : 'Status: Belum terlambat',
                  style: TextStyle(
                    color: late ? AppColors.error : AppColors.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: condition,
                  decoration: const InputDecoration(
                    labelText: 'Kondisi barang',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'baik', child: Text('Baik')),
                    DropdownMenuItem(value: 'rusak', child: Text('Rusak')),
                    DropdownMenuItem(value: 'hilang', child: Text('Hilang')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => condition = value);
                    }
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Catatan (opsional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'kondisi': condition,
                'catatan': noteController.text,
              }),
              child: const Text('Konfirmasi'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();

    if (confirmation == null) {
      await _showResult(
        success: false,
        message:
            'Pengembalian belum dikonfirmasi. Tiket QR ini sudah digunakan; '
            'minta peminjam membuat QR baru untuk mencoba lagi.',
      );
      return;
    }

    await peminjamanService.selesaikanPengembalian(
      peminjamanId: borrowingId,
      kondisiBarang: confirmation['kondisi']!,
      catatan: confirmation['catatan'],
    );
    await _showResult(
      success: true,
      title: 'Pengembalian Selesai',
      message: 'Pengembalian ${result['kode_booking'] ?? ''} berhasil dicatat.',
    );
  }

  Future<void> _showResult({
    required bool success,
    required String message,
    String? title,
  }) async {
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => _ResultSheet(
        success: success,
        title: title,
        message: message,
        onPrimary: () => Navigator.pop(sheetContext),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: Column(
        children: [
          _buildAppBar(context),
          Expanded(child: _buildCameraArea()),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.4,
            ),
            child: const SingleChildScrollView(child: _QuickGuide()),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Container(
      color: AppColors.surfaceContainerLowest,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Symbols.arrow_back),
                color: AppColors.onSurface,
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    Navigator.maybePop(context);
                  }
                },
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  'Scan Tiket Akses',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm(
                    color: AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCameraArea() {
    return LayoutBuilder(
      builder: (context, c) {
        final center = Offset(c.maxWidth / 2, c.maxHeight * 0.42);
        final window = Rect.fromCenter(
          center: center,
          width: _frameSize,
          height: _frameSize,
        );

        return Container(
          color: _cameraBg,
          child: Stack(
            fit: StackFit.expand,
            children: [
              MobileScanner(
                controller: _controller,
                scanWindow: window,
                onDetect: _onDetect,
                errorBuilder: (context, error) => _CameraError(error: error),
              ),

              // Gelapkan area di luar frame.
              CustomPaint(painter: _DimPainter(window)),

              // Sudut frame.
              Positioned.fromRect(
                rect: window,
                child: CustomPaint(painter: _CornerPainter()),
              ),

              // Garis scan.
              AnimatedBuilder(
                animation: _lineAnim,
                builder: (context, _) {
                  final t = Curves.easeInOut.transform(_lineAnim.value);
                  final y = window.top + 16 + t * (_frameSize - 32);
                  return Positioned(
                    left: window.left + 8,
                    width: _frameSize - 16,
                    top: y,
                    child: Container(
                      height: 3,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: const LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xFF38BDF8),
                            Colors.transparent,
                          ],
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x8038BDF8),
                            blurRadius: 12,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Tombol simulasi (hanya saat debug).
              if (kDebugMode)
                Positioned(
                  top: 12,
                  left: 0,
                  right: 0,
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _TestChip(
                        label: 'Tes Berhasil',
                        icon: Symbols.check_circle,
                        color: const Color(0xFF34D399),
                        onTap: () => _handleResult('BK-2024-089'),
                      ),
                      _TestChip(
                        label: 'Tes Gagal',
                        icon: Symbols.error,
                        color: const Color(0xFFFCA5A5),
                        onTap: () => _handleResult(null),
                      ),
                    ],
                  ),
                ),

              // Kontrol bawah: lampu, galeri (bukan web), ganti kamera.
              Positioned(
                left: 16,
                right: 16,
                bottom: 20,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 16,
                  runSpacing: 12,
                  children: [
                    ValueListenableBuilder<MobileScannerState>(
                      valueListenable: _controller,
                      builder: (context, state, _) {
                        final on = state.torchState == TorchState.on;
                        return _RoundControl(
                          icon: on ? Symbols.flash_on : Symbols.flash_off,
                          highlighted: on,
                          onTap: _controller.toggleTorch,
                        );
                      },
                    ),
                    _GalleryButton(onTap: _pickFromGallery),
                    _RoundControl(
                      icon: Symbols.cameraswitch,
                      onTap: _controller.switchCamera,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Painter: overlay gelap dengan lubang di frame
// ---------------------------------------------------------------------------
class _DimPainter extends CustomPainter {
  _DimPainter(this.window);
  final Rect window;

  @override
  void paint(Canvas canvas, Size size) {
    final full = Path()..addRect(Offset.zero & size);
    final hole = Path()
      ..addRRect(RRect.fromRectAndRadius(window, const Radius.circular(20)));
    final path = Path.combine(PathOperation.difference, full, hole);
    canvas.drawPath(path, Paint()..color = _cameraBg.withValues(alpha: 0.6));
  }

  @override
  bool shouldRepaint(covariant _DimPainter old) => old.window != window;
}

// ---------------------------------------------------------------------------
// Painter: empat sudut biru
// ---------------------------------------------------------------------------
class _CornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const len = 36.0;
    const r = 20.0;
    final paint = Paint()
      ..color = _frameBlue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final w = size.width;
    final h = size.height;

    // kiri atas
    canvas.drawPath(
      Path()
        ..moveTo(0, len)
        ..lineTo(0, r)
        ..arcToPoint(const Offset(r, 0), radius: const Radius.circular(r))
        ..lineTo(len, 0),
      paint,
    );
    // kanan atas
    canvas.drawPath(
      Path()
        ..moveTo(w - len, 0)
        ..lineTo(w - r, 0)
        ..arcToPoint(Offset(w, r), radius: const Radius.circular(r))
        ..lineTo(w, len),
      paint,
    );
    // kiri bawah
    canvas.drawPath(
      Path()
        ..moveTo(0, h - len)
        ..lineTo(0, h - r)
        ..arcToPoint(
          Offset(r, h),
          radius: const Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(len, h),
      paint,
    );
    // kanan bawah
    canvas.drawPath(
      Path()
        ..moveTo(w - len, h)
        ..lineTo(w - r, h)
        ..arcToPoint(
          Offset(w, h - r),
          radius: const Radius.circular(r),
          clockwise: false,
        )
        ..lineTo(w, h - len),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------------------
// Komponen kecil
// ---------------------------------------------------------------------------
class _TestChip extends StatelessWidget {
  const _TestChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.14),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.labelSm(
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundControl extends StatelessWidget {
  const _RoundControl({
    required this.icon,
    required this.onTap,
    this.highlighted = false,
  });

  final IconData icon;
  final VoidCallback onTap;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: highlighted
          ? AppColors.primary
          : Colors.white.withValues(alpha: 0.18),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _GalleryButton extends StatelessWidget {
  const _GalleryButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.18),
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.photo_library, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pilih dari Galeri',
                style: AppTextStyles.labelLg(
                  weight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error});
  final MobileScannerException error;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    final message = denied
        ? (kIsWeb
              ? 'Izin kamera ditolak.\nIzinkan kamera untuk situs ini di browser, lalu muat ulang halaman.'
              : 'Izin kamera ditolak.\nAktifkan izin kamera di pengaturan aplikasi.')
        : (kIsWeb
              ? 'Kamera tidak dapat dibuka.\nCoba pakai "Pilih dari Galeri".'
              : 'Kamera tidak dapat dibuka.\nCoba pakai "Pilih dari Galeri".');
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Symbols.no_photography, color: Colors.white70, size: 48),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMd(color: Colors.white70),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Panduan akses cepat
// ---------------------------------------------------------------------------
class _QuickGuide extends StatelessWidget {
  const _QuickGuide();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.mobileGutter,
            20,
            AppSpacing.mobileGutter,
            16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Panduan Akses Cepat',
                style: AppTextStyles.headlineSm(
                  color: AppColors.onSurface,
                ).copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              const IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _GuideCard(
                        icon: Symbols.light_mode,
                        title: 'Pencahayaan Cukup',
                        body: 'Gunakan tombol lampu flash bila ruangan redup.',
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: _GuideCard(
                        icon: Symbols.confirmation_number,
                        title: 'Tiket Aktif',
                        body: 'Bisa dibuka dari menu "Pinjaman Saya".',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed.fade(0.35),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTextStyles.bodySm(
              weight: FontWeight.w700,
              color: AppColors.onSurface,
            ).copyWith(fontSize: 13),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: AppTextStyles.bodySm(
              weight: FontWeight.w500,
              color: AppColors.slate600,
            ).copyWith(fontSize: 12),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet hasil scan
// ---------------------------------------------------------------------------
class _ResultSheet extends StatelessWidget {
  const _ResultSheet({
    required this.success,
    required this.message,
    required this.onPrimary,
    this.title,
  });

  final bool success;
  final String message;
  final VoidCallback onPrimary;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final fg = success ? AppColors.onTertiaryFixedVariant : AppColors.error;
    final bg = success ? AppColors.tertiaryFixed : AppColors.errorContainer;

    return Container(
      padding: EdgeInsets.fromLTRB(
        24,
        24,
        24,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(
              success ? Symbols.check_circle : Symbols.error,
              size: 34,
              color: fg,
              fill: 1,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            title ?? (success ? 'Tiket Valid' : 'Scan Gagal'),
            style: AppTextStyles.headlineSm(
              color: AppColors.onSurface,
            ).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMd(color: AppColors.slate600),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: onPrimary,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
              child: Text(
                success ? 'Lanjut' : 'Scan Lagi',
                style: AppTextStyles.labelLg(
                  weight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}