import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/core/storage/storage_config.dart';
import 'package:lapak8new/features/borrowings/models/peminjaman.dart';
import 'package:lapak8new/features/borrowings/services/peminjaman_service.dart';
import 'package:lapak8new/features/admin/models/return_documentation.dart';
import 'package:lapak8new/features/admin/services/admin_report_pdf_service.dart';
import 'package:lapak8new/features/admin/services/media_picker_service.dart';
import 'package:lapak8new/features/admin/services/documentation_repository.dart';
import 'package:lapak8new/features/admin/widgets/documentation_section.dart';
import 'package:lapak8new/features/admin/widgets/documentation_media_previews.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';
import 'package:lapak8new/shared/widgets/blurred_bottom_sheet.dart';
import 'package:lapak8new/shared/widgets/ms_icon.dart';
import 'package:lapak8new/shared/widgets/user_avatar.dart';

// Simpan di: lib/features/admin/screens/admin_borrowings_screen.dart
// Halaman Aktivitas admin: Peminjaman + Pengembalian (satu screen, dua tab).

// ---------------------------------------------------------------------------
// Jenis aktivitas + status
// ---------------------------------------------------------------------------
enum ActivityTab { peminjaman, pengembalian }

enum _LoanStatus {
  waiting,
  borrowed,
  approved,
  late,
  done,
  rejected,
  cancelled,
}

enum _ReturnStatus {
  pending,
  waitingPayment,
  waitingAdminConfirmation,
  returned,
  late,
  damaged,
}

// Warna status yang belum ada di AppColors (amber untuk "menunggu").
const _amberBg = Color(0xFFFFF1D6);
const _amberFg = Color(0xFFB45309);

class _Loan {
  const _Loan({
    required this.code,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.itemName,
    required this.serial,
    required this.itemIcon,
    required this.detailIcon,
    required this.detail,
    this.isTeacher = false,
    this.extra,
    this.extraColor,
    this.highlight,
    this.highlightColor,
    this.trailingDetail,
    this.note,
    this.avatarUrl,
    this.borrowingId,
    this.isLate = false,
  });

  final String code;
  final String name;
  final String subtitle;
  final _LoanStatus status;
  final String itemName;
  final String serial;
  final IconData itemIcon;
  final IconData detailIcon;
  final String detail; // teks biasa
  final bool isTeacher;
  final String? extra; // baris di bawah nama (rekam pinjam / sisa waktu)
  final Color? extraColor;
  final String? highlight; // potongan teks berwarna di akhir detail
  final Color? highlightColor;
  final String? trailingDetail; // mis. tanggal di kanan
  final String? note;
  final String? avatarUrl; // isi bila sudah ada foto profil
  final String? borrowingId;
  final bool isLate;

  String get initials {
    final parts = name.replaceAll('Drs. ', '').trim().split(' ');
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }
}

class _Return {
  const _Return({
    required this.borrowingId,
    required this.code,
    required this.name,
    required this.subtitle,
    required this.status,
    required this.itemName,
    required this.serial,
    required this.itemIcon,
    required this.detailIcon,
    required this.detail,
    this.highlight,
    this.highlightColor,
    this.avatarUrl,
    this.itemId,
    this.returnRequestedAt,
    this.dueAt,
    this.inspection,
  });

  final String borrowingId;
  final String code;
  final String name;
  final String subtitle;
  final _ReturnStatus status;
  final String itemName;
  final String serial;
  final IconData itemIcon;
  final IconData detailIcon;
  final String detail;
  final String? highlight;
  final Color? highlightColor;
  final String? avatarUrl;
  final String? itemId;
  final DateTime? returnRequestedAt;
  final DateTime? dueAt;
  final PemeriksaanPengembalian? inspection;
}

/// Hasil pemeriksaan kondisi barang dari form Cek Kondisi.
class InspectionResult {
  const InspectionResult({
    required this.condition,
    required this.description,
    required this.fine,
    this.documentationPhotos = const [],
    this.documentationVideo,
  });

  final String condition;
  final String description;
  final int fine;

  /// Dokumentasi kondisi barang yang dipilih saat pemeriksaan.
  final List<PendingDocumentationFile> documentationPhotos;
  final PendingDocumentationFile? documentationVideo;
}

class AdminBorrowingsScreen extends StatefulWidget {
  const AdminBorrowingsScreen({
    super.key,
    this.initialTab = ActivityTab.peminjaman,
    this.initialReturnInspectionId,
    this.initialReturnBorrowingId,
  });

  /// Tab yang terbuka saat halaman pertama kali tampil.
  /// Default: Peminjaman (sesuai menu "Aktivitas").
  final ActivityTab initialTab;
  final String? initialReturnInspectionId;
  final String? initialReturnBorrowingId;

  @override
  State<AdminBorrowingsScreen> createState() => _AdminBorrowingsScreenState();
}

class _AdminBorrowingsScreenState extends State<AdminBorrowingsScreen> {
  late ActivityTab _tab = widget.initialTab; // default: Peminjaman
  _LoanStatus? _loanFilter; // null = semua
  _ReturnStatus? _returnFilter; // null = semua
  String _query = '';
  final PeminjamanService _svc = peminjamanService;
  final DocumentationRepository _documentationRepository =
      DocumentationRepository();
  final Set<String> _updatingBorrowingIds = {};
  List<Peminjaman> _borrowings = [];
  List<_Loan> _loans = [];
  bool _isLoadingLoans = true;
  String? _loansError;
  bool _initialInspectionHandled = false;

  @override
  void initState() {
    super.initState();
    _loadLoans();
  }

  Future<void> _loadLoans({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        _isLoadingLoans = true;
        _loansError = null;
      });
    }
    try {
      final peminjaman = await _svc.ambilSemuaPeminjaman();
      if (!mounted) return;
      setState(() {
        _borrowings = peminjaman;
        _loans = peminjaman
            .where(
              (p) =>
                  p.status != StatusPeminjaman.menungguPengembalian &&
                  p.status != StatusPeminjaman.pelanggaran,
            )
            .map(_toLoan)
            .toList();
        _isLoadingLoans = false;
        _loansError = null;
      });
      final inspectionId = widget.initialReturnInspectionId;
      final borrowingId = widget.initialReturnBorrowingId;
      if (inspectionId != null &&
          borrowingId != null &&
          !_initialInspectionHandled) {
        _initialInspectionHandled = true;
        _Return? selectedReturn;
        for (final item in _returns) {
          if (item.borrowingId == borrowingId) {
            selectedReturn = item;
            break;
          }
        }
        final returnToInspect = selectedReturn;
        if (returnToInspect != null) {
          setState(() => _tab = ActivityTab.pengembalian);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _openInspection(returnToInspect, inspectionId: inspectionId);
            }
          });
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Transaksi pengembalian tidak ditemukan.'),
            ),
          );
        }
      }
    } on PeminjamanException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingLoans = false;
        _loansError = error.pesan;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingLoans = false;
        _loansError = error.toString();
      });
    }
  }

  _Loan _toLoan(Peminjaman p) {
    final status = switch (p.status) {
      StatusPeminjaman.menungguPersetujuan => _LoanStatus.waiting,
      StatusPeminjaman.disetujui => _LoanStatus.approved,
      StatusPeminjaman.dipinjam => _LoanStatus.borrowed,
      StatusPeminjaman.dikembalikan => _LoanStatus.done,
      StatusPeminjaman.ditolak => _LoanStatus.rejected,
      StatusPeminjaman.dibatalkan => _LoanStatus.cancelled,
      StatusPeminjaman.terlambat => _LoanStatus.late,
      _ => _LoanStatus.waiting,
    };
    final namaItem = p.items.isNotEmpty
        ? p.items.first.namaFasilitasSnapshot
        : '—';
    final jumlah = p.items.isNotEmpty ? p.items.first.jumlah : 0;
    return _Loan(
      code: p.kodeBooking,
      name: p.namaPeminjam ?? 'Pengguna LAPAK8',
      subtitle: p.nomorIndukPeminjam != null
          ? 'ID: ${p.nomorIndukPeminjam}'
          : 'Pengguna LAPAK8',
      status: status,
      itemName: namaItem,
      serial: '$jumlah unit • ${p.labelKategori}',
      itemIcon: Symbols.category,
      detailIcon: Symbols.schedule,
      detail:
          '${_formatDateTime(p.mulaiPada)} - ${_formatDateTime(p.estimasiKembaliPada)}',
      isTeacher: false,
      extra: p.namaKegiatan,
      extraColor: AppColors.primary,
      highlight: null,
      highlightColor: null,
      trailingDetail: null,
      note: p.alasanPenolakan,
      avatarUrl: p.fotoUrlPeminjam,
      borrowingId: p.id,
      isLate:
          p.status == StatusPeminjaman.terlambat ||
          DateTime.now().isAfter(p.estimasiKembaliPada),
    );
  }

  _Return? _toReturn(Peminjaman p) {
    final isReturned = p.status == StatusPeminjaman.dikembalikan;
    final status = switch (p.status) {
      StatusPeminjaman.dikembalikan => _ReturnStatus.returned,
      StatusPeminjaman.menungguPengembalian => _ReturnStatus.pending,
      StatusPeminjaman.pelanggaran =>
        p.pemeriksaanPengembalian?.statusPembayaran ==
                'menunggu_konfirmasi_admin'
            ? _ReturnStatus.waitingAdminConfirmation
            : _ReturnStatus.waitingPayment,
      _ => null,
    };
    if (status == null) return null;

    final firstItem = p.items.isEmpty ? null : p.items.first;
    final returnedAt = p.dikembalikanPada;
    final inspection = p.pemeriksaanPengembalian;
    return _Return(
      borrowingId: p.id,
      code: p.kodeBooking,
      name: p.namaPeminjam?.trim().isNotEmpty == true
          ? p.namaPeminjam!.trim()
          : 'Pengguna LAPAK8',
      subtitle: p.nomorIndukPeminjam != null
          ? 'ID: ${p.nomorIndukPeminjam}'
          : p.kelasPeminjam ?? 'Pengguna LAPAK8',
      status: status,
      itemName: firstItem?.namaFasilitasSnapshot ?? p.namaKegiatan,
      serial:
          '${p.items.fold<int>(0, (total, item) => total + item.jumlah)} '
          'unit • ${p.labelKategori}',
      itemIcon: Symbols.category,
      detailIcon: isReturned ? Symbols.check_circle : Symbols.schedule,
      detail: isReturned ? 'Dikembalikan: ' : 'Batas: ',
      highlight: _formatDateTime(
        isReturned
            ? returnedAt ?? p.estimasiKembaliPada
            : p.estimasiKembaliPada,
      ),
      highlightColor: status == _ReturnStatus.damaged
          ? AppColors.error
          : status == _ReturnStatus.returned
          ? AppColors.emerald500
          : null,
      avatarUrl: p.fotoUrlPeminjam,
      itemId: firstItem?.id,
      returnRequestedAt: p.dimintaKembaliPada,
      dueAt: p.estimasiKembaliPada,
      inspection: inspection,
    );
  }

  String _formatDateTime(DateTime value) {
    final date = value.toLocal();
    String twoDigits(int number) => number.toString().padLeft(2, '0');
    return '${twoDigits(date.day)}/${twoDigits(date.month)}/${date.year} '
        '${twoDigits(date.hour)}:${twoDigits(date.minute)}';
  }

  // Filter status per jenis aktivitas (tidak tercampur antar tab).
  static const _loanFilters = <(String, _LoanStatus?)>[
    ('Semua', null),
    ('Menunggu', _LoanStatus.waiting),
    ('Dipinjam', _LoanStatus.borrowed),
    ('Disetujui', _LoanStatus.approved),
    ('Terlambat', _LoanStatus.late),
    ('Selesai', _LoanStatus.done),
    ('Ditolak', _LoanStatus.rejected),
    ('Dibatalkan', _LoanStatus.cancelled),
  ];

  static const _returnFilters = <(String, _ReturnStatus?)>[
    ('Semua', null),
    ('Menunggu', _ReturnStatus.pending),
    ('Menunggu Pembayaran', _ReturnStatus.waitingPayment),
    ('Menunggu Konfirmasi Admin', _ReturnStatus.waitingAdminConfirmation),
    ('Selesai', _ReturnStatus.returned),
    ('Terlambat', _ReturnStatus.late),
    ('Rusak / Hilang', _ReturnStatus.damaged),
  ];

  bool get _isLoanTab => _tab == ActivityTab.peminjaman;

  List<_Loan> get _visibleLoans {
    final q = _query.trim().toLowerCase();
    return _loans.where((l) {
      if (_loanFilter != null && l.status != _loanFilter) return false;
      if (q.isEmpty) return true;
      return l.name.toLowerCase().contains(q) ||
          l.code.toLowerCase().contains(q) ||
          l.itemName.toLowerCase().contains(q) ||
          l.serial.toLowerCase().contains(q) ||
          l.subtitle.toLowerCase().contains(q);
    }).toList();
  }

  List<_Return> get _returns =>
      _borrowings.map(_toReturn).whereType<_Return>().toList();

  List<_Return> get _visibleReturns {
    final q = _query.trim().toLowerCase();
    return _returns.where((r) {
      if (_returnFilter != null && r.status != _returnFilter) return false;
      if (q.isEmpty) return true;
      return r.name.toLowerCase().contains(q) ||
          r.code.toLowerCase().contains(q) ||
          r.itemName.toLowerCase().contains(q) ||
          r.serial.toLowerCase().contains(q);
    }).toList();
  }

  int get _activeTotal => _isLoanTab ? _loans.length : _returns.length;

  // -------------------------------------------------------------------------
  // Aksi peminjaman (dengan popup konfirmasi gaya ConfirmDialog)
  // -------------------------------------------------------------------------
  void _confirmApprove(_Loan l) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.check,
        title: 'Setujui Peminjaman?',
        message:
            'Pastikan data peminjaman "${l.itemName}" (${l.serial}) '
            'atas nama ${l.name} sudah benar sebelum disetujui.',
        confirmText: 'Ya, Setujui',
        confirmIcon: Symbols.check,
        confirmColor: AppColors.primary,
        iconColor: AppColors.primary,
        iconBackground: AppColors.primaryFixed,
        onConfirm: () =>
            _updateBorrowingStatus(l, 'disetujui', 'Peminjaman disetujui.'),
      ),
    );
  }

  void _confirmReject(_Loan l) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.close,
        title: 'Tolak Peminjaman?',
        message:
            'Pengajuan "${l.itemName}" (${l.serial}) atas nama '
            '${l.name} akan ditolak.',
        confirmText: 'Ya, Tolak',
        confirmIcon: Symbols.close,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        onConfirm: () =>
            _updateBorrowingStatus(l, 'ditolak', 'Peminjaman ditolak.'),
      ),
    );
  }

  Future<void> _updateBorrowingStatus(
    _Loan loan,
    String status,
    String successMessage,
  ) async {
    final id = loan.borrowingId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID peminjaman tidak tersedia.')),
      );
      return;
    }
    setState(() => _updatingBorrowingIds.add(id));
    try {
      await _svc.ubahStatus(
        id,
        status: status,
        alasanPenolakan: status == 'ditolak'
            ? 'Ditolak oleh petugas Sarpras.'
            : null,
      );
      await _loadLoans(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } on PeminjamanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.pesan)));
    } finally {
      if (mounted) setState(() => _updatingBorrowingIds.remove(id));
    }
  }

  Future<void> _scanBorrowingQr(_Loan loan) async {
    final id = loan.borrowingId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID peminjaman tidak tersedia.')),
      );
      return;
    }

    setState(() => _updatingBorrowingIds.add(id));
    try {
      await context.push<void>('/scan', extra: {'peminjamanId': id});
      if (!mounted) return;
      await _loadLoans(showLoading: false);
    } finally {
      if (mounted) setState(() => _updatingBorrowingIds.remove(id));
    }
  }

  void _confirmSuspend(_Loan l) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.lock,
        title: 'Suspend Akun?',
        message:
            'Akun ${l.name} akan disuspend karena keterlambatan '
            'pengembalian "${l.itemName}".',
        confirmText: 'Ya, Suspend',
        confirmIcon: Symbols.lock,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        onConfirm: () {
          if (!mounted) return;
          // TODO: kirim aksi suspend ke backend, lalu refresh daftar.
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Akun di-suspend')));
        },
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Aksi pengembalian — alur verifikasi "Cek Kondisi"
  // -------------------------------------------------------------------------
  Future<void> _openInspection(_Return r, {String? inspectionId}) async {
    setState(() => _updatingBorrowingIds.add(r.borrowingId));
    try {
      var selectedInspectionId = inspectionId;
      if (selectedInspectionId == null) {
        final scanResult = await context.push<Map<String, dynamic>>(
          '/scan',
          extra: {'returnPeminjamanId': r.borrowingId},
        );
        if (!mounted || scanResult == null) return;
        final scannedId = scanResult['return_inspection_id'];
        if (scannedId is! String || scannedId.isEmpty) {
          throw const PeminjamanException(
            'Data pemeriksaan dari hasil scan QR tidak valid.',
          );
        }
        selectedInspectionId = scannedId;
      }
      if (selectedInspectionId.isEmpty) {
        throw const PeminjamanException(
          'Data pemeriksaan dari hasil scan QR tidak valid.',
        );
      }
      final resolvedInspectionId = selectedInspectionId;

      final result = await showBlurredBottomSheet<InspectionResult>(
        context: context,
        heightFactor: 0.92,
        builder: (_) => _ConditionInspectionSheet(
          item: r,
          inspectionId: resolvedInspectionId,
        ),
      );
      if (result == null || !mounted) return;

      var uploadedFiles = <DocumentationFile>[];
      var uploadWarnings = <String>[];
      final hasFiles =
          result.documentationPhotos.isNotEmpty ||
          result.documentationVideo != null;
      if (hasFiles) {
        final itemId = r.itemId;
        if (itemId == null) {
          throw const PeminjamanException(
            'Barang transaksi tidak ditemukan untuk menyimpan bukti.',
          );
        }
        final uploads = await _documentationRepository.uploadAll(
          returnId: resolvedInspectionId,
          borrowingId: r.borrowingId,
          itemId: itemId,
          photos: result.documentationPhotos,
          video: result.documentationVideo,
        );
        uploadWarnings = uploads.warnings;
        uploadedFiles = [
          ...uploads.photos,
          if (uploads.video != null) uploads.video!,
        ];
        if (uploadedFiles.isEmpty && uploadWarnings.isNotEmpty) {
          throw StorageApiException(
            'Bukti gagal diunggah, pemeriksaan belum disimpan. '
            '${uploadWarnings.join('\n')}',
            code: 'upload_failed',
          );
        }
      }

      final evidence = uploadedFiles
          .map(
            (file) => <String, dynamic>{
              'file_id': file.id,
              'jenis': file.isVideo ? 'video' : 'photo',
              'file_name': file.fileName,
              'mime_type': file.mime,
              'ukuran_byte': file.size,
            },
          )
          .toList(growable: false);

      await _svc.selesaikanPemeriksaanPengembalian(
        peminjamanId: r.borrowingId,
        pemeriksaanId: resolvedInspectionId,
        kondisiBarang: result.condition,
        denda: result.fine,
        keterangan: result.description,
        bukti: evidence,
      );
      await _loadLoans(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(
              result.condition == 'baik'
                  ? 'Pengembalian ${r.code} selesai diverifikasi.'
                  : 'Pemeriksaan ${r.code} tersimpan. Menunggu pembayaran denda.',
            ),
          ),
        );
      if (uploadWarnings.isNotEmpty && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(uploadWarnings.join('\n'))));
      }
    } on PeminjamanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.pesan)));
    } on StorageApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memeriksa pengembalian: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingBorrowingIds.remove(r.borrowingId));
      }
    }
  }

  Future<void> _confirmPaymentCompletion(_Return r) async {
    if (r.status != _ReturnStatus.waitingAdminConfirmation) return;

    var confirmed = false;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.payments,
        title: 'Konfirmasi Penyelesaian?',
        message:
            'Pengguna telah mengirim konfirmasi pembayaran denda untuk '
            'peminjaman ${r.code}. Konfirmasi ini akan menyelesaikan '
            'transaksi.',
        cancelText: 'Batal',
        confirmText: 'Ya, Selesaikan',
        confirmIcon: Symbols.check,
        confirmColor: AppColors.primary,
        iconColor: AppColors.primary,
        iconBackground: AppColors.primaryFixed,
        onConfirm: () => confirmed = true,
      ),
    );
    if (!confirmed || !mounted) return;

    setState(() => _updatingBorrowingIds.add(r.borrowingId));
    try {
      await _svc.konfirmasiPembayaranDendaAdmin(r.borrowingId);
      await _loadLoans(showLoading: false);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('Peminjaman ${r.code} telah diselesaikan.'),
          ),
        );
    } on PeminjamanException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.pesan)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengonfirmasi pembayaran: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _updatingBorrowingIds.remove(r.borrowingId));
      }
    }
  }

  // -------------------------------------------------------------------------
  // UI
  // -------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final loans = _visibleLoans;
    final returns = _visibleReturns;
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.mobileGutter,
          AppSpacing.md,
          AppSpacing.mobileGutter,
          AppSpacing.md,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Aktivitas',
                  style: AppTextStyles.headlineMd(color: AppColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kelola aktivitas peminjaman dan pengembalian barang sekolah.',
                  style: AppTextStyles.bodyMd(color: AppColors.slate600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _SyncRow(),
          const SizedBox(height: 16),
          _buildTabSwitcher(),
          const SizedBox(height: 16),
          _SearchField(
            hintText: _isLoanTab
                ? 'Cari peminjam, item, atau no. aset...'
                : 'Cari pengembalian, item, atau no. aset...',
            onChanged: (v) => setState(() => _query = v),
          ),
          const SizedBox(height: 16),
          _isLoanTab ? _buildLoanFilterChips() : _buildReturnFilterChips(),
          const SizedBox(height: 16),
          if (_isLoadingLoans)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_loansError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Text(
                    _loansError!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMd(color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loadLoans,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            ),
          if (_isLoanTab &&
              !_isLoadingLoans &&
              _loansError == null &&
              loans.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Tidak ada data peminjaman',
                  style: AppTextStyles.bodyMd(color: AppColors.slate500),
                ),
              ),
            ),
          if (!_isLoanTab &&
              !_isLoadingLoans &&
              _loansError == null &&
              returns.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Tidak ada data pengembalian',
                  style: AppTextStyles.bodyMd(color: AppColors.slate500),
                ),
              ),
            ),
          if (_isLoanTab)
            if (!_isLoadingLoans && _loansError == null)
              for (final l in loans) ...[
                _LoanCard(
                  loan: l,
                  isUpdating: _updatingBorrowingIds.contains(l.borrowingId),
                  onReject: () => _confirmReject(l),
                  onApprove: () => _confirmApprove(l),
                  onScanBorrowingQr: () => _scanBorrowingQr(l),
                  onSuspend: () => _confirmSuspend(l),
                ),
                const SizedBox(height: 16),
              ],
          if (!_isLoanTab)
            for (final r in returns) ...[
              _ReturnCard(
                item: r,
                isUpdating: _updatingBorrowingIds.contains(r.borrowingId),
                onCheck: () => _openInspection(r),
                onConfirmPayment: () => _confirmPaymentCompletion(r),
              ),
              const SizedBox(height: 16),
            ],
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.mobileGutter,
          AppSpacing.md,
          AppSpacing.mobileGutter,
          AppSpacing.md,
        ),
        child: _SummaryBar(total: _activeTotal, onExport: _exportReport),
      ),
    );
  }

  // Tab Peminjaman / Pengembalian
  Widget _buildTabSwitcher() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadows.sm,
      ),
      child: Row(
        children: [
          _tabButton(
            ActivityTab.peminjaman,
            'Peminjaman',
            Symbols.event_available,
          ),
          _tabButton(
            ActivityTab.pengembalian,
            'Pengembalian',
            Symbols.assignment_return,
          ),
        ],
      ),
    );
  }

  Widget _tabButton(ActivityTab tab, String label, IconData icon) {
    final selected = _tab == tab;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = tab),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.full),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              MsIcon(
                icon,
                size: 18,
                color: selected ? AppColors.onPrimary : AppColors.slate600,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.labelMd(
                  weight: FontWeight.w700,
                  color: selected ? AppColors.onPrimary : AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoanFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _loanFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, status) = _loanFilters[i];
          return _filterChip(
            label: label,
            count: _loanCount(status),
            selected: _loanFilter == status,
            onTap: () => setState(() => _loanFilter = status),
          );
        },
      ),
    );
  }

  Widget _buildReturnFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _returnFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, status) = _returnFilters[i];
          return _filterChip(
            label: label,
            count: _returnCount(status),
            selected: _returnFilter == status,
            onTap: () => setState(() => _returnFilter = status),
          );
        },
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.primary
              : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: selected ? null : AppShadows.sm,
        ),
        child: Text(
          '$label ($count)',
          style: AppTextStyles.labelMd(
            weight: FontWeight.w700,
            color: selected ? AppColors.onPrimary : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  int _loanCount(_LoanStatus? s) =>
      s == null ? _loans.length : _loans.where((l) => l.status == s).length;

  int _returnCount(_ReturnStatus? s) =>
      s == null ? _returns.length : _returns.where((r) => r.status == s).length;

  Future<void> _exportReport() async {
    final isLoanReport = _isLoanTab;
    final rows = isLoanReport
        ? _visibleLoans
              .map(
                (loan) => [
                  loan.code,
                  loan.name,
                  loan.subtitle,
                  loan.itemName,
                  loan.serial,
                  _loanStatusLabel(loan.status),
                  loan.detail,
                ],
              )
              .toList()
        : _visibleReturns
              .map(
                (item) => [
                  item.code,
                  item.name,
                  item.subtitle,
                  item.itemName,
                  item.serial,
                  _returnStatusLabel(item.status),
                  '${item.detail}${item.highlight ?? ''}',
                ],
              )
              .toList();

    try {
      await AdminReportPdfService.export(
        title: isLoanReport ? 'Rekap Peminjaman' : 'Rekap Pengembalian',
        filename: isLoanReport
            ? 'rekap-peminjaman.pdf'
            : 'rekap-pengembalian.pdf',
        headers: const [
          'Kode',
          'Peminjam',
          'Identitas',
          'Barang',
          'Jumlah/Kategori',
          'Status',
          'Jadwal',
        ],
        rows: rows,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat rekap PDF: $error')),
      );
    }
  }

  String _loanStatusLabel(_LoanStatus status) => switch (status) {
    _LoanStatus.waiting => 'Menunggu',
    _LoanStatus.borrowed => 'Dipinjam',
    _LoanStatus.approved => 'Disetujui',
    _LoanStatus.late => 'Terlambat',
    _LoanStatus.done => 'Selesai',
    _LoanStatus.rejected => 'Ditolak',
    _LoanStatus.cancelled => 'Dibatalkan',
  };

  String _returnStatusLabel(_ReturnStatus status) => switch (status) {
    _ReturnStatus.pending => 'Menunggu',
    _ReturnStatus.waitingPayment => 'Menunggu Pembayaran',
    _ReturnStatus.waitingAdminConfirmation => 'Menunggu Konfirmasi Admin',
    _ReturnStatus.returned => 'Selesai',
    _ReturnStatus.late => 'Terlambat',
    _ReturnStatus.damaged => 'Rusak / Hilang',
  };
}

// ---------------------------------------------------------------------------
// Baris "Sync Sarpras Live"
// ---------------------------------------------------------------------------
class _SyncRow extends StatelessWidget {
  const _SyncRow();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'Sync Sarpras Live',
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Terakhir diperbarui: 09:41 WIB',
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMd(
                weight: FontWeight.w500,
                color: AppColors.slate600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kolom pencarian
// ---------------------------------------------------------------------------
class _SearchField extends StatelessWidget {
  const _SearchField({required this.hintText, required this.onChanged});
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadows.sm,
      ),
      child: TextField(
        onChanged: onChanged,
        style: AppTextStyles.bodyMd(color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
          prefixIcon: const Icon(Symbols.search, color: AppColors.slate600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip status peminjaman
// ---------------------------------------------------------------------------
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final _LoanStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    IconData? icon;
    switch (status) {
      case _LoanStatus.waiting:
        label = 'Menunggu Konfirmasi';
        bg = _amberBg;
        fg = _amberFg;
      case _LoanStatus.borrowed:
        label = 'Sedang Dipinjam';
        bg = AppColors.primaryFixed;
        fg = AppColors.primary;
      case _LoanStatus.approved:
        label = 'Disetujui (Ready)';
        bg = AppColors.tertiaryFixed;
        fg = AppColors.onTertiaryFixedVariant;
      case _LoanStatus.late:
        label = 'Terlambat';
        bg = AppColors.errorContainer;
        fg = AppColors.error;
      case _LoanStatus.done:
        label = 'Dikembalikan';
        bg = AppColors.surfaceContainerLow;
        fg = AppColors.slate600;
        icon = Symbols.check_circle;
      case _LoanStatus.rejected:
        label = 'Ditolak';
        bg = AppColors.errorContainer;
        fg = AppColors.error;
        icon = Symbols.close;
      case _LoanStatus.cancelled:
        label = 'Dibatalkan';
        bg = AppColors.surfaceContainerLow;
        fg = AppColors.slate600;
        icon = Symbols.cancel;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: fg)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSm(weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip status pengembalian
// ---------------------------------------------------------------------------
class _ReturnStatusChip extends StatelessWidget {
  const _ReturnStatusChip({required this.status});
  final _ReturnStatus status;

  @override
  Widget build(BuildContext context) {
    late final String label;
    late final Color bg;
    late final Color fg;
    IconData? icon;
    switch (status) {
      case _ReturnStatus.pending:
        label = 'Menunggu Pengembalian';
        bg = _amberBg;
        fg = _amberFg;
      case _ReturnStatus.waitingPayment:
        label = 'Menunggu Pembayaran';
        bg = AppColors.errorContainer;
        fg = AppColors.error;
        icon = Symbols.payments;
      case _ReturnStatus.waitingAdminConfirmation:
        label = 'Menunggu Konfirmasi Admin';
        bg = _amberBg;
        fg = _amberFg;
        icon = Symbols.hourglass_top;
      case _ReturnStatus.returned:
        label = 'Selesai';
        bg = AppColors.tertiaryFixed;
        fg = AppColors.onTertiaryFixedVariant;
        icon = Symbols.check_circle;
      case _ReturnStatus.late:
        label = 'Terlambat';
        bg = AppColors.errorContainer;
        fg = AppColors.error;
      case _ReturnStatus.damaged:
        label = 'Rusak / Hilang';
        bg = AppColors.errorContainer;
        fg = AppColors.error;
        icon = Symbols.warning;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Icon(icon, size: 14, color: fg)
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSm(weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu peminjaman
// ---------------------------------------------------------------------------
class _LoanCard extends StatelessWidget {
  const _LoanCard({
    required this.loan,
    required this.onReject,
    required this.onApprove,
    required this.onScanBorrowingQr,
    required this.onSuspend,
    required this.isUpdating,
  });

  final _Loan loan;
  final VoidCallback onReject;
  final VoidCallback onApprove;
  final VoidCallback onScanBorrowingQr;
  final VoidCallback onSuspend;
  final bool isUpdating;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kode + status
          Row(
            children: [
              Text(
                '#',
                style: AppTextStyles.headlineSm(color: AppColors.primary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  loan.code.startsWith('BK') ? loan.code : '#${loan.code}',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm(
                    color: AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _StatusChip(status: loan.status),
            ],
          ),
          const SizedBox(height: 14),
          _buildPerson(),
          const SizedBox(height: 14),
          _buildItemBox(),
          if (loan.status == _LoanStatus.waiting) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _ActionButton(
                    label: 'Tolak',
                    icon: Symbols.close,
                    background: AppColors.errorContainer,
                    foreground: AppColors.error,
                    onPressed: isUpdating ? null : onReject,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ActionButton(
                    label: 'Setujui',
                    icon: Symbols.check,
                    background: AppColors.primary,
                    foreground: AppColors.onPrimary,
                    onPressed: isUpdating ? null : onApprove,
                  ),
                ),
              ],
            ),
          ],
          if (loan.status == _LoanStatus.approved) ...[
            const SizedBox(height: 16),
            _ActionButton(
              label: 'Scan QR Peminjaman',
              icon: Symbols.qr_code_scanner,
              background: AppColors.primary,
              foreground: AppColors.onPrimary,
              onPressed: isUpdating ? null : onScanBorrowingQr,
            ),
          ],
          if (loan.status == _LoanStatus.borrowed) ...[
            const SizedBox(height: 16),
            const _LoanStatusInfo(
              label: 'Sedang Dipinjam',
              icon: Symbols.check_circle,
            ),
          ],
          if (loan.status == _LoanStatus.late) ...[
            const SizedBox(height: 16),
            _ActionButton(
              label: 'Suspend Akun',
              icon: Symbols.lock,
              background: AppColors.errorContainer,
              foreground: AppColors.error,
              onPressed: onSuspend,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPerson() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(name: loan.name, imageUrl: loan.avatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      loan.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineSm(
                        color: AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (loan.isTeacher) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        'Guru',
                        style: AppTextStyles.labelSm(
                          weight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                loan.subtitle,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm(
                  weight: FontWeight.w500,
                  color: AppColors.slate600,
                ),
              ),
              if (loan.extra != null) ...[
                const SizedBox(height: 2),
                Text(
                  loan.extra!,
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w700,
                    color: loan.extraColor ?? AppColors.slate600,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loan.status == _LoanStatus.approved) ...[
                Icon(loan.itemIcon, size: 22, color: AppColors.primary),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  loan.itemName,
                  style: AppTextStyles.bodyMd(
                    weight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.fade(0.6),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  loan.serial,
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w700,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                loan.detailIcon,
                size: 16,
                color: loan.status == _LoanStatus.done
                    ? AppColors.emerald500
                    : AppColors.slate600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: loan.detail,
                    children: [
                      if (loan.highlight != null)
                        TextSpan(
                          text: loan.highlight,
                          style: TextStyle(
                            color: loan.highlightColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: AppColors.slate600,
                  ),
                ),
              ),
              if (loan.trailingDetail != null)
                Text(
                  loan.trailingDetail!,
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
            ],
          ),
          if (loan.note != null) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Symbols.fact_check,
                  size: 16,
                  color: AppColors.slate600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loan.note!,
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w500,
                      color: AppColors.slate600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu pengembalian (komponen & struktur konsisten dengan kartu peminjaman)
// ---------------------------------------------------------------------------
class _ReturnCard extends StatelessWidget {
  const _ReturnCard({
    required this.item,
    required this.isUpdating,
    required this.onCheck,
    required this.onConfirmPayment,
  });

  final _Return item;
  final bool isUpdating;
  final VoidCallback onCheck;
  final VoidCallback onConfirmPayment;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kode + status
          Row(
            children: [
              Text(
                '#',
                style: AppTextStyles.headlineSm(color: AppColors.primary),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  item.code,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm(
                    color: AppColors.onSurface,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              _ReturnStatusChip(status: item.status),
            ],
          ),
          const SizedBox(height: 14),
          _buildPerson(),
          const SizedBox(height: 14),
          _buildItemBox(),
          if (item.inspection?.bukti.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _ReturnEvidenceStrip(files: item.inspection!.bukti),
          ],
          if (item.status == _ReturnStatus.pending) ...[
            const SizedBox(height: 16),
            _ActionButton(
              label: isUpdating ? 'Memproses...' : 'Cek Kondisi',
              icon: Symbols.checklist,
              background: AppColors.primary,
              foreground: AppColors.onPrimary,
              onPressed: isUpdating ? null : onCheck,
            ),
          ] else if (item.status == _ReturnStatus.waitingAdminConfirmation) ...[
            const SizedBox(height: 16),
            _ActionButton(
              label: isUpdating ? 'Memproses...' : 'Konfirmasi Penyelesaian',
              icon: Symbols.check_circle,
              background: AppColors.primary,
              foreground: AppColors.onPrimary,
              onPressed: isUpdating ? null : onConfirmPayment,
            ),
          ] else ...[
            const SizedBox(height: 16),
            _InspectionResultStrip(item: item),
          ],
        ],
      ),
    );
  }

  Widget _buildPerson() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatar(name: item.name, imageUrl: item.avatarUrl),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      item.name,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineSm(
                        color: AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm(
                  weight: FontWeight.w500,
                  color: AppColors.slate600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildItemBox() {
    final note = item.inspection?.keterangan;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(item.itemIcon, size: 22, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.itemName,
                  style: AppTextStyles.bodyMd(
                    weight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.primaryFixed.fade(0.6),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  item.serial,
                  style: AppTextStyles.labelSm(
                    weight: FontWeight.w700,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                item.detailIcon,
                size: 16,
                color: item.status == _ReturnStatus.returned
                    ? AppColors.emerald500
                    : AppColors.slate600,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: item.detail,
                    children: [
                      if (item.highlight != null)
                        TextSpan(
                          text: item.highlight,
                          style: TextStyle(
                            color: item.highlightColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ],
          ),
          if (note?.isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Symbols.fact_check,
                  size: 16,
                  color: AppColors.slate600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    note!,
                    style: AppTextStyles.bodySm(
                      weight: FontWeight.w500,
                      color: AppColors.slate600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Strip ringkas hasil verifikasi pada kartu pengembalian (setelah dicek)
// ---------------------------------------------------------------------------
class _InspectionResultStrip extends StatelessWidget {
  const _InspectionResultStrip({required this.item});
  final _Return item;

  @override
  Widget build(BuildContext context) {
    final inspection = item.inspection;
    final hasViolation =
        inspection?.hasPelanggaran == true ||
        item.status == _ReturnStatus.damaged ||
        item.status == _ReturnStatus.waitingPayment ||
        item.status == _ReturnStatus.waitingAdminConfirmation;
    final bg = hasViolation
        ? AppColors.errorContainer
        : AppColors.tertiaryFixed;
    final fg = hasViolation
        ? AppColors.error
        : AppColors.onTertiaryFixedVariant;
    final icon = hasViolation ? Symbols.warning : Symbols.check_circle;
    final heading = switch (item.status) {
      _ReturnStatus.waitingPayment => 'Menunggu Pembayaran',
      _ReturnStatus.waitingAdminConfirmation => 'Menunggu Konfirmasi Admin',
      _ => inspection?.labelHasil ?? 'Pengembalian selesai',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MsIcon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  heading,
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w700,
                    color: fg,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kondisi: ${inspection?.labelKondisi ?? 'Tidak diketahui'}\n'
                  'Denda: ${inspection?.labelDenda ?? 'Tidak ada'}',
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: fg,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReturnEvidenceStrip extends StatelessWidget {
  const _ReturnEvidenceStrip({required this.files});

  final List<BuktiPemeriksaanPengembalian> files;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bukti Pemeriksaan',
            style: AppTextStyles.labelMd(
              weight: FontWeight.w700,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 126,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final file = files[index];
                if (file.jenis == 'video') {
                  return SizedBox(
                    width: 210,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _StoredVideoPreview(path: file.path),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          file.namaFile,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.labelSm(
                            weight: FontWeight.w600,
                            color: AppColors.slate600,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return SizedBox(
                  width: 104,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: RemoteMediaImage(
                            url: file.path,
                            fit: BoxFit.cover,
                            onTap: () => showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.black,
                              builder: (_) => SafeArea(
                                child: InteractiveViewer(
                                  child: RemoteMediaImage(
                                    url: file.path,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        file.namaFile,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.labelSm(
                          weight: FontWeight.w600,
                          color: AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoredVideoPreview extends StatefulWidget {
  const _StoredVideoPreview({required this.path});

  final String path;

  @override
  State<_StoredVideoPreview> createState() => _StoredVideoPreviewState();
}

class _StoredVideoPreviewState extends State<_StoredVideoPreview> {
  VideoPlayerController? _controller;
  bool _ready = false;
  bool _failed = false;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      final signedUrl = await Supabase.instance.client.storage
          .from(Lapak8StorageConfig.bucket)
          .createSignedUrl(widget.path, 60 * 60);
      if (!mounted) return;
      final controller = VideoPlayerController.networkUrl(Uri.parse(signedUrl))
        ..addListener(_updatePlaying);
      _controller = controller;
      await controller.initialize();
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  void _updatePlaying() {
    final playing = _controller?.value.isPlaying ?? false;
    if (mounted && playing != _playing) {
      setState(() => _playing = playing);
    }
  }

  @override
  void dispose() {
    _controller
      ?..removeListener(_updatePlaying)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return const ColoredBox(
        color: Color(0xFFE2E7FF),
        child: Center(child: Icon(Icons.videocam_off_outlined)),
      );
    }
    if (!_ready) {
      return const ColoredBox(
        color: Color(0xFFE2E7FF),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    return GestureDetector(
      onTap: () {
        final controller = _controller;
        if (controller == null) return;
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _controller!.value.size.width,
                height: _controller!.value.size.height,
                child: VideoPlayer(_controller!),
              ),
            ),
          ),
          if (!_playing)
            const Icon(Symbols.play_circle, color: Colors.white, size: 38),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom sheet: Form Pemeriksaan Kondisi Barang (Cek Kondisi)
// ---------------------------------------------------------------------------
class _ConditionInspectionSheet extends StatefulWidget {
  const _ConditionInspectionSheet({
    required this.item,
    required this.inspectionId,
  });
  final _Return item;
  final String inspectionId;

  @override
  State<_ConditionInspectionSheet> createState() =>
      _ConditionInspectionSheetState();
}

class _ConditionInspectionSheetState extends State<_ConditionInspectionSheet> {
  static const _conditionLabels = {
    'baik': 'Baik',
    'rusak': 'Rusak',
    'hilang': 'Hilang',
    'terlambat': 'Terlambat',
  };

  String _condition = 'baik';
  final _descCtrl = TextEditingController();
  final _fineCtrl = TextEditingController();
  bool _submitting = false;
  bool _touched = false;
  final MediaPickerService _docPicker = MediaPickerService();
  List<PendingDocumentationFile> _docPhotos = [];
  PendingDocumentationFile? _docVideo;

  bool get _hasViolation => _condition != 'baik';
  bool get _requiresDescription =>
      _condition == 'rusak' || _condition == 'hilang';

  @override
  void dispose() {
    _descCtrl.dispose();
    _fineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final parsedFine = int.tryParse(_fineCtrl.text.trim()) ?? 0;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.92,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 20),
                  _buildInfoCard(),
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    'Kondisi Barang',
                    'Pilih hasil pemeriksaan barang yang dikembalikan.',
                  ),
                  const SizedBox(height: 12),
                  _buildConditionChoices(),
                  if (_condition == 'terlambat') ...[
                    const SizedBox(height: 12),
                    _buildLateInfo(),
                  ],
                  const SizedBox(height: 24),
                  _buildSectionTitle(
                    _condition == 'rusak'
                        ? 'Deskripsi Kerusakan'
                        : _condition == 'hilang'
                        ? 'Keterangan Kehilangan'
                        : 'Keterangan',
                    _requiresDescription
                        ? 'Wajib diisi untuk mencatat temuan.'
                        : 'Keterangan tambahan (opsional).',
                  ),
                  const SizedBox(height: 12),
                  _buildDescriptionField(),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeOut,
                    switchOutCurve: Curves.easeIn,
                    transitionBuilder: (child, animation) => SizeTransition(
                      sizeFactor: animation,
                      alignment: Alignment.topCenter,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: _hasViolation
                        ? Padding(
                            key: const ValueKey('fine'),
                            padding: const EdgeInsets.only(top: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSectionTitle(
                                  'Denda / Sanksi',
                                  'Masukkan nominal denda yang ditentukan admin.',
                                ),
                                const SizedBox(height: 12),
                                _buildFineField(),
                                if (_touched && parsedFine <= 0) ...[
                                  const SizedBox(height: 8),
                                  _buildErrorText(
                                    'Nominal denda harus lebih besar dari nol.',
                                  ),
                                ],
                              ],
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('no-fine')),
                  ),
                  const SizedBox(height: 24),
                  DocumentationSection(
                    picker: _docPicker,
                    onChanged: (photos, video) {
                      _docPhotos = photos;
                      _docVideo = video;
                    },
                  ),
                  if (_touched &&
                      _requiresDescription &&
                      _descCtrl.text.trim().isEmpty) ...[
                    const SizedBox(height: 12),
                    _buildErrorText('Keterangan temuan wajib diisi.'),
                  ],
                ],
              ),
            ),
          ),
          // Tombol konfirmasi dinamis + batas aman
          Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              boxShadow: [
                BoxShadow(
                  color: AppColors.onSurface.fade(0.06),
                  offset: const Offset(0, -6),
                  blurRadius: 24,
                ),
              ],
            ),
            child: SafeArea(top: false, child: _buildSubmitButton()),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primaryFixed,
            shape: BoxShape.circle,
          ),
          child: const MsIcon(
            Symbols.checklist,
            size: 22,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Cek Kondisi Barang',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Verifikasi kondisi fisik barang saat dikembalikan.',
                style: TextStyle(fontSize: 13, color: AppColors.slate600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard() {
    final r = widget.item;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _infoLabel('Kode'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.code,
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLabel('Peminjam'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  r.name,
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w700,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLabel('Barang'),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${r.itemName} • ${r.serial}',
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _infoLabel(String t) => SizedBox(
    width: 64,
    child: Text(
      t,
      style: AppTextStyles.labelMd(
        weight: FontWeight.w500,
        color: AppColors.slate500,
      ),
    ),
  );

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.headlineSm(color: AppColors.onSurface),
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
    );
  }

  Widget _buildConditionChoices() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final entry in _conditionLabels.entries) ...[
            _ChecklistTile(
              label: entry.value,
              value: _condition == entry.key,
              accent: entry.key == 'baik' ? AppColors.primary : AppColors.error,
              onChanged: (_) => setState(() => _condition = entry.key),
            ),
            if (entry.key != _conditionLabels.keys.last)
              Divider(
                height: 1,
                thickness: 1,
                indent: 52,
                color: AppColors.outlineVariant.fade(0.5),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildLateInfo() {
    final dueAt = widget.item.dueAt;
    final returnRequestedAt = widget.item.returnRequestedAt;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _amberBg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'Batas pengembalian: ${_formatInspectionTime(dueAt)}\n'
        'Waktu pengajuan pengembalian: '
        '${_formatInspectionTime(returnRequestedAt)}',
        style: AppTextStyles.bodySm(weight: FontWeight.w600, color: _amberFg),
      ),
    );
  }

  String _formatInspectionTime(DateTime? value) {
    if (value == null) return '-';
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} $hour:$minute';
  }

  Widget _buildDescriptionField() {
    return TextField(
      controller: _descCtrl,
      onChanged: (_) => setState(() {}),
      maxLines: 3,
      minLines: 2,
      textCapitalization: TextCapitalization.sentences,
      style: AppTextStyles.bodyMd(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: switch (_condition) {
          'rusak' => 'Jelaskan bagian atau jenis kerusakan.',
          'hilang' => 'Jelaskan barang atau komponen yang hilang.',
          'terlambat' => 'Keterangan tambahan (opsional).',
          _ => 'Catatan tambahan (opsional).',
        },
        hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildFineField() {
    return TextField(
      controller: _fineCtrl,
      onChanged: (_) => setState(() => _touched = true),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: AppTextStyles.bodyMd(color: AppColors.onSurface),
      decoration: InputDecoration(
        hintText: 'Masukkan nominal dalam rupiah',
        hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        errorText:
            _touched &&
                _hasViolation &&
                (int.tryParse(_fineCtrl.text.trim()) ?? 0) <= 0
            ? 'Nominal harus lebih besar dari nol.'
            : null,
        prefixIcon: const MsIcon(
          Symbols.payments,
          size: 20,
          color: AppColors.error,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _buildErrorText(String msg) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const MsIcon(Symbols.info, size: 16, color: AppColors.error),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            msg,
            style: AppTextStyles.bodySm(
              weight: FontWeight.w600,
              color: AppColors.error,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubmitButton() {
    final hasViolation = _hasViolation;
    final bg = hasViolation ? AppColors.error : AppColors.primary;
    final fg = Colors.white;
    const icon = Symbols.check;
    const label = 'Konfirmasi Pemeriksaan';
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _submitting ? null : _submit,
        icon: _submitting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              )
            : MsIcon(icon, size: 20, color: fg),
        label: Text(
          _submitting ? 'Memproses...' : label,
          style: AppTextStyles.labelLg(weight: FontWeight.w700, color: fg),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          elevation: 0,
          shape: const StadiumBorder(),
          disabledBackgroundColor: bg.fade(0.35),
          disabledForegroundColor: Colors.white,
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _touched = true);
    final fine = int.tryParse(_fineCtrl.text.trim()) ?? 0;
    if ((_requiresDescription && _descCtrl.text.trim().isEmpty) ||
        (_hasViolation && fine <= 0)) {
      return;
    }

    setState(() => _submitting = true);
    if (!mounted) return;
    final result = InspectionResult(
      condition: _condition,
      description: _descCtrl.text.trim(),
      fine: _hasViolation ? fine : 0,
      documentationPhotos: List.of(_docPhotos),
      documentationVideo: _docVideo,
    );
    Navigator.of(context).pop(result);
  }
}

// ---------------------------------------------------------------------------
// Satu baris checklist pada form pemeriksaan
// ---------------------------------------------------------------------------
class _ChecklistTile extends StatelessWidget {
  const _ChecklistTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final Color accent;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => onChanged(!value),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: value ? accent : Colors.transparent,
                shape: BoxShape.circle,
                border: value
                    ? null
                    : Border.all(color: AppColors.outlineVariant, width: 2),
              ),
              child: value
                  ? const MsIcon(Symbols.check, size: 16, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMd(
                  weight: value ? FontWeight.w700 : FontWeight.w500,
                  color: value ? accent : AppColors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(
          label,
          style: AppTextStyles.labelLg(
            weight: FontWeight.w700,
            color: foreground,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

class _LoanStatusInfo extends StatelessWidget {
  const _LoanStatusInfo({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      enabled: false,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: const BoxDecoration(
          color: AppColors.primaryFixed,
          borderRadius: BorderRadius.all(Radius.circular(28)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.labelLg(
                weight: FontWeight.w700,
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bar ringkasan untuk total dan ekspor rekap PDF
// ---------------------------------------------------------------------------
class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.total, required this.onExport});

  final int total;
  final VoidCallback onExport;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mobileGutter,
        8,
        AppSpacing.mobileGutter,
        0,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(AppRadius.full),
          boxShadow: AppShadows.sm,
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '$total Total\nTransaksi',
                style: AppTextStyles.labelSm(
                  weight: FontWeight.w700,
                  color: AppColors.onSurface,
                ),
              ),
            ),
            _PillButton(
              icon: Symbols.download,
              label: 'Rekap\nPDF',
              background: AppColors.primaryFixed,
              foreground: AppColors.primary,
              onPressed: onExport,
            ),
          ],
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      shape: const StadiumBorder(),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: foreground),
              const SizedBox(width: 8),
              Text(
                label,
                textAlign: TextAlign.left,
                style: AppTextStyles.labelSm(
                  weight: FontWeight.w700,
                  color: foreground,
                ).copyWith(height: 1.15),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
