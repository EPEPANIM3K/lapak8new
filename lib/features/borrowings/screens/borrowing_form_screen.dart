import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lapak8new/features/facilities/services/facility_stock_service.dart';

import '../models/peminjaman.dart';
import '../services/peminjaman_service.dart';
import '../utils/booking_date_window.dart';

DateTime _firstBookableRoomDate() {
  final today = DateUtils.dateOnly(DateTime.now());
  for (var daysAhead = 0; daysAhead <= 7; daysAhead++) {
    final date = today.add(Duration(days: daysAhead));
    if (date.weekday != DateTime.saturday && date.weekday != DateTime.sunday) {
      return date;
    }
  }
  return today;
}

// =============================================================================
// Entry point — memuat fasilitas, lalu memilih UI berdasarkan kategori.
// =============================================================================
class BorrowingFormScreen extends StatefulWidget {
  const BorrowingFormScreen({super.key, this.initialFacilityId});

  final String? initialFacilityId;

  @override
  State<BorrowingFormScreen> createState() => _BorrowingFormScreenState();
}

class _BorrowingFormScreenState extends State<BorrowingFormScreen> {
  static const _background = Color(0xFFF4F7FC);
  static const _red = Color(0xFFDC2626);

  final _peminjamanService = peminjamanService;
  List<FasilitasRingkas> _fasilitas = [];
  FasilitasRingkas? _initialFacility;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _peminjamanService.ambilFasilitas().timeout(
        const Duration(seconds: 15),
      );
      if (!mounted) return;
      FasilitasRingkas? initial;
      if (widget.initialFacilityId != null) {
        for (final f in list) {
          if (f.id == widget.initialFacilityId && f.tersedia) {
            initial = f;
            break;
          }
        }
      }
      final available = list.where((f) => f.tersedia);
      initial ??= available.isEmpty ? null : available.first;
      setState(() {
        _fasilitas = list;
        _initialFacility = initial;
        _isLoading = false;
      });
    } on PeminjamanException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.pesan;
      });
    } on FacilityStockException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.message;
      });
    } on FormatException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Format data fasilitas tidak valid. Coba muat ulang halaman.';
      });
    } on TypeError {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Data fasilitas tidak valid. Coba muat ulang halaman.';
      });
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Pemuatan terlalu lama. Periksa koneksi lalu coba lagi.';
      });
    } on Exception {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error =
            'Gagal memuat daftar barang dan ruangan. Periksa koneksi, lalu coba lagi.';
      });
    }
  }

  Widget _stateScaffold({required Widget content}) => Theme(
    data: ThemeData(
      fontFamily: GoogleFonts.outfit().fontFamily,
      useMaterial3: true,
    ),
    child: Scaffold(
      backgroundColor: _background,
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => context.pop(),
                ),
                const Text(
                  'Formulir Booking',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ],
            ),
          ),
          Expanded(child: content),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return _stateScaffold(
        content: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Memuat daftar barang dan ruangan...'),
            ],
          ),
        ),
      );
    }

    if (_error != null) {
      return _stateScaffold(
        content: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: _red, size: 36),
                const SizedBox(height: 8),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Coba lagi'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_fasilitas.isEmpty) {
      return _stateScaffold(
        content: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF64748B),
                  size: 40,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Belum ada barang atau ruangan yang tersedia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Muat ulang'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_fasilitas.any((facility) => facility.tersedia)) {
      return _stateScaffold(
        content: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF64748B),
                  size: 40,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Stok habis. Belum ada barang atau ruangan yang tersedia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Muat ulang'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Penentuan form berdasarkan isRuangan (case-insensitive: Ruangan, ruangan, RuanGan, etc.)
    final facility = _initialFacility ?? _fasilitas.first;
    if (facility.isRuangan) {
      return _RoomBookingForm(
        fasilitas: _fasilitas,
        initialFacility: facility,
        peminjamanService: _peminjamanService,
      );
    } else {
      return _ItemBookingForm(
        fasilitas: _fasilitas,
        initialFacility: facility,
        peminjamanService: _peminjamanService,
      );
    }
  }
}

// =============================================================================
// CALENDAR DAY MODEL UNTUK RUANGAN
// =============================================================================
enum CalStatus { available, full, selected, unavailable }

class CalDay {
  final int day;
  final DateTime? date;
  final String fullLabel;
  final CalStatus status;
  final bool isOffset;

  CalDay({
    required this.day,
    this.date,
    this.fullLabel = '',
    this.status = CalStatus.unavailable,
    this.isOffset = false,
  });
}

// =============================================================================
// 1. ROOM BOOKING FORM — Khusus Kategori Ruangan
// =============================================================================
class _RoomBookingForm extends StatefulWidget {
  const _RoomBookingForm({
    required this.fasilitas,
    required this.initialFacility,
    required this.peminjamanService,
  });

  final List<FasilitasRingkas> fasilitas;
  final FasilitasRingkas initialFacility;
  final PeminjamanService peminjamanService;

  @override
  State<_RoomBookingForm> createState() => _RoomBookingFormState();
}

class _RoomBookingFormState extends State<_RoomBookingForm> {
  // ----- Theme constants -----
  static const Color surface = Color(0xFFF6F8FE);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF0037B0);
  static const Color onSurface = Color(0xFF131B2E);
  static const Color onSurfaceVariant = Color(0xFF5A6275);
  static const Color slate100 = Color(0xFFF1F5F9);
  static const Color slate200 = Color(0xFFE2E8F0);
  static const Color slate300 = Color(0xFFCBD5E1);
  static const Color slate400 = Color(0xFF94A3B8);
  static const Color slate500 = Color(0xFF64748B);
  static const Color slate600 = Color(0xFF475569);
  static const Color slate700 = Color(0xFF334155);
  static const Color emerald500 = Color(0xFF10B981);
  static const Color emerald600 = Color(0xFF059669);
  static const Color emerald100 = Color(0xFFD1FAE5);
  static const Color emerald950 = Color(0xFF022C22);
  static const Color emerald700 = Color(0xFF047857);
  static const Color rose600 = Color(0xFFE11D48);
  static const Color rose950 = Color(0xFF4C0519);
  static const Color rose700 = Color(0xFFBE123C);
  static const Color rose100 = Color(0xFFFFE4E6);
  static const Color red400 = Color(0xFFF87171);
  static const Color badgeBlueBg = Color(0xFFE8F0FE);

  // ----- State -----
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _kegiatanController = TextEditingController();

  late FasilitasRingkas _selectedRoom;
  bool _calendarOpen = false;
  late DateTime _selectedDate;

  int _jamMulai = 8;
  int _jamSelesai = 12;
  int _units = 1;
  bool _termsAccepted = true;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedRoom = widget.initialFacility;
    _selectedDate = _firstBookableRoomDate();
  }

  // Conflict check: 09-11 or 13-14 already booked
  bool get _hasConflict {
    final s = _jamMulai;
    final e = _jamSelesai;
    final clash1 = s < 11 && e > 9;
    final clash2 = s < 14 && e > 13;
    return clash1 || clash2;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _kegiatanController.dispose();
    super.dispose();
  }

  void _updateStart(int v) {
    setState(() {
      _jamMulai = v;
      if (_jamSelesai <= _jamMulai) {
        _jamSelesai = (_jamMulai + 1).clamp(0, 16);
      }
    });
  }

  void _updateEnd(int v) {
    setState(() {
      _jamSelesai = v;
      if (_jamSelesai <= _jamMulai) {
        _jamMulai = (_jamSelesai - 1).clamp(0, 15);
      }
    });
  }

  void _stepItem(int delta) {
    if (_selectedRoom.unitTersedia <= 0) return;
    setState(() {
      _units = (_units + delta).clamp(
        1,
        _selectedRoom.unitTersedia.clamp(1, 99),
      );
    });
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? const Color(0xFFDC2626)
              : const Color(0xFF059669),
        ),
      );
  }

  Future<void> _submitBooking() async {
    if (!isBookingDateWithinWindow(
          date: _selectedDate,
          today: DateTime.now(),
          maxDaysAhead: 7,
        ) ||
        _selectedDate.weekday == DateTime.saturday ||
        _selectedDate.weekday == DateTime.sunday) {
      _showMessage(
        'Tanggal peminjaman ruangan harus hari ini hingga 7 hari ke depan.',
        error: true,
      );
      return;
    }
    if (_hasConflict) {
      _showMessage(
        'Jadwal bentrok dengan peminjaman lain. Silakan pilih jam lain.',
        error: true,
      );
      return;
    }
    if (_selectedRoom.unitTersedia <= 0 ||
        _units > _selectedRoom.unitTersedia) {
      _showMessage(
        'Stok ruangan tidak mencukupi. Muat ulang form dan pilih jumlah lain.',
        error: true,
      );
      return;
    }
    if (_kegiatanController.text.trim().isEmpty) {
      _showMessage('Isi nama kegiatan atau kebutuhan.', error: true);
      return;
    }
    if (!_termsAccepted) {
      _showMessage(
        'Setujui peraturan peminjaman dan SOP terlebih dahulu.',
        error: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final mulai = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _jamMulai,
      );
      final selesai = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _jamSelesai,
      );

      await widget.peminjamanService.buat(
        items: [
          ItemPeminjamanInput(
            fasilitasId: _selectedRoom.id,
            namaFasilitas: _selectedRoom.nama,
            jumlah: _units,
          ),
        ],
        kategori: 'praktik',
        namaKegiatan: _kegiatanController.text.trim(),
        mulaiPada: mulai,
        estimasiKembaliPada: selesai,
      );
      if (!mounted) return;
      _showMessage('Pengajuan peminjaman berhasil dikirim!');
      context.go('/borrowings');
    } on PeminjamanException catch (e) {
      if (!mounted) return;
      _showMessage(e.pesan, error: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _showRoomPicker() async {
    final rooms = widget.fasilitas.where((f) => f.isRuangan).toList();
    final picked = await showModalBottomSheet<FasilitasRingkas>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FacilityPickerSheet(facilities: rooms),
    );
    if (!mounted || picked == null) return;
    if (!picked.tersedia) {
      _showMessage('Ruangan tersebut tidak tersedia.', error: true);
      return;
    }
    setState(() => _selectedRoom = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        fontFamily: GoogleFonts.outfit().fontFamily,
        scaffoldBackgroundColor: surface,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primary, primary: primary),
      ),
      child: Scaffold(
        backgroundColor: surface,
        body: Stack(
          children: [
            // Main scrollable content
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 56 + 12, bottom: 96),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 448),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildLocationCard(),
                        const SizedBox(height: 14),
                        _buildDateSection(),
                        const SizedBox(height: 14),
                        _buildTimeSection(),
                        const SizedBox(height: 14),
                        _buildScheduleCard(),
                        const SizedBox(height: 14),
                        _buildAvailabilityBox(),
                        const SizedBox(height: 14),
                        _buildQuantityAndEventForm(),
                        const SizedBox(height: 14),
                        _buildTermsCheckbox(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Top App Bar
            _BookingTopBar(onBack: () => context.pop()),
            // Bottom sticky action bar
            _BookingBottomBar(
              isSubmitting: _isSubmitting,
              onSubmit: _submitBooking,
            ),
          ],
        ),
      ),
    );
  }

  // ---------- Location Card ----------
  Widget _buildLocationCard() {
    final room = _selectedRoom;
    return GestureDetector(
      onTap: _showRoomPicker,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: surfaceLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: slate100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: 72,
                height: 72,
                color: const Color(0xFFEAEDFF),
                child: room.fotoUrl != null && room.fotoUrl!.isNotEmpty
                    ? Image.network(
                        room.fotoUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.computer,
                          color: Color(0xFF5A6275),
                          size: 34,
                        ),
                      )
                    : const Icon(
                        Icons.computer,
                        color: Color(0xFF5A6275),
                        size: 34,
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: badgeBlueBg,
                      borderRadius: BorderRadius.circular(50),
                    ),
                    child: Text(
                      room.kategori.isEmpty ? 'Ruangan' : room.kategori,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    room.nama,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: onSurface,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 2),
                  _iconTextRow(Icons.location_on, room.lokasi),
                  const SizedBox(height: 2),
                  _iconTextRow(
                    Icons.info_outline,
                    room.unitTersedia > 0
                        ? 'Tersedia ${room.unitTersedia} unit'
                        : 'Stok habis',
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 20, color: slate400),
          ],
        ),
      ),
    );
  }

  Widget _iconTextRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: slate500),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: onSurfaceVariant),
          ),
        ),
      ],
    );
  }

  // ---------- Date Section ----------
  Widget _buildDateSection() {
    return _BookingDateSection(
      selectedDate: _selectedDate,
      calendarOpen: _calendarOpen,
      minDaysAhead: 0,
      maxDaysAhead: 7,
      markWeekendsFull: true,
      onToggleCalendar: () => setState(() => _calendarOpen = !_calendarOpen),
      onDateSelected: (date) {
        setState(() {
          _selectedDate = date;
          _calendarOpen = false;
        });
      },
    );
  }

  // ---------- Time Section ----------
  Widget _buildTimeSection() {
    return _BookingTimeSection(
      jamMulai: _jamMulai,
      jamSelesai: _jamSelesai,
      endOptions: const [9, 10, 11, 12, 13, 14, 15, 16],
      onStartChanged: _updateStart,
      onEndChanged: _updateEnd,
    );
  }

  // ---------- Schedule Card ----------
  Widget _buildScheduleCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.bar_chart, size: 20, color: primary),
              SizedBox(width: 8),
              Text(
                'Jadwal Barang pada Tanggal Ini',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '07.00',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: slate600,
                ),
              ),
              Text(
                '16.00',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: slate600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // Timeline bar
          ClipRRect(
            borderRadius: BorderRadius.circular(50),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  Expanded(flex: 222, child: Container(color: emerald500)),
                  Expanded(flex: 222, child: Container(color: red400)),
                  Expanded(flex: 222, child: Container(color: emerald500)),
                  Expanded(flex: 111, child: Container(color: red400)),
                  Expanded(flex: 222, child: Container(color: emerald500)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Legend
          Row(
            children: [
              _legendDot(emerald500, 'Tersedia'),
              const SizedBox(width: 16),
              _legendDot(red400, 'Terpesan'),
            ],
          ),
          const SizedBox(height: 10),
          // Sub-card booked schedule
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Jadwal yang Sudah Dipesan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                _bookedRow('09.00 – 11.00'),
                const SizedBox(height: 6),
                _bookedRow('13.00 – 14.00'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: slate600)),
      ],
    );
  }

  Widget _bookedRow(String range) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          range,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: onSurface,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFFFEE2E2),
            borderRadius: BorderRadius.circular(50),
          ),
          child: const Text(
            'Terpesan',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFFEF4444),
            ),
          ),
        ),
      ],
    );
  }

  // ---------- Availability Box ----------
  Widget _buildAvailabilityBox() {
    final conflict = _hasConflict;
    final bg = conflict ? rose100 : const Color(0xFFDCFCE7);
    final border = conflict ? rose100 : emerald100;
    final iconColor = conflict ? rose600 : emerald600;
    final titleColor = conflict ? rose950 : emerald950;
    final descColor = conflict ? rose700 : emerald700;
    final iconData = conflict ? Icons.warning : Icons.check_circle;
    final title = conflict
        ? 'Jadwal bentrok dengan peminjaman lain.'
        : 'Waktu yang Anda pilih tersedia.';
    final desc = conflict
        ? 'Silakan pilih rentang jam yang bebas dari tanda terpesan.'
        : _selectedRoom.unitTersedia > 0
        ? 'Stok tersisa: ${_selectedRoom.unitTersedia} unit'
        : 'Stok habis';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(iconData, size: 22, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(desc, style: TextStyle(fontSize: 12, color: descColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Quantity & Event Form ----------
  Widget _buildQuantityAndEventForm() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: surfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.inventory_2, size: 18, color: primary),
                      SizedBox(width: 6),
                      Text(
                        'Jumlah Item',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Maks. ${_selectedRoom.unitTersedia} Unit',
                    style: const TextStyle(fontSize: 12, color: slate500),
                  ),
                ],
              ),
              // Stepper
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: slate100,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _stepperBtn(
                      icon: Icons.remove,
                      bg: Colors.white,
                      fg: slate700,
                      onTap: () => _stepItem(-1),
                    ),
                    SizedBox(
                      width: 56,
                      child: Text(
                        '$_units Unit',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: onSurface,
                        ),
                      ),
                    ),
                    _stepperBtn(
                      icon: Icons.add,
                      bg: primary,
                      fg: Colors.white,
                      onTap: () => _stepItem(1),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: slate100),
          const SizedBox(height: 10),
          const Text(
            'Nama Kegiatan / Kebutuhan',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: slate700,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _kegiatanController,
            style: const TextStyle(fontSize: 13, color: onSurface),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              hintText: 'Praktik Uji Coba Aplikasi Web Siswa',
              hintStyle: const TextStyle(fontSize: 13, color: slate400),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: slate200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: primary, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepperBtn({
    required IconData icon,
    required Color bg,
    required Color fg,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      elevation: 1,
      shadowColor: Colors.black12,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(icon, size: 16, color: fg),
        ),
      ),
    );
  }

  // ---------- Terms Checkbox ----------
  Widget _buildTermsCheckbox() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: SizedBox(
              width: 16,
              height: 16,
              child: Checkbox(
                value: _termsAccepted,
                onChanged: (v) => setState(() => _termsAccepted = v ?? false),
                activeColor: primary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
                side: const BorderSide(color: slate300),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _termsAccepted = !_termsAccepted),
              child: Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontSize: 12,
                    color: slate600,
                    height: 1.5,
                    fontFamily: GoogleFonts.outfit().fontFamily,
                  ),
                  children: const [
                    TextSpan(text: 'Saya menyetujui seluruh '),
                    TextSpan(
                      text: 'SOP Laboratorium',
                      style: TextStyle(
                        color: primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' dan bertanggung jawab penuh atas penggunaan fasilitas.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// 2. ITEM BOOKING FORM — Khusus Kategori Lain Selain Ruangan
// =============================================================================
class _ItemBookingForm extends StatefulWidget {
  const _ItemBookingForm({
    required this.fasilitas,
    required this.initialFacility,
    required this.peminjamanService,
  });

  final List<FasilitasRingkas> fasilitas;
  final FasilitasRingkas initialFacility;
  final PeminjamanService peminjamanService;

  @override
  State<_ItemBookingForm> createState() => _ItemBookingFormState();
}

class _ItemBookingFormState extends State<_ItemBookingForm> {
  // ----- Colors -----
  static const Color brandBlue = Color(0xFF0037B0);
  static const Color bgColor = Color(0xFFF6F8FE);
  static const Color textColor = Color(0xFF131B2E);
  static const Color mutedColor = Color(0xFF64748B);
  static const Color slateBg = Color(0xFFE2E8F0);
  static const Color slateBorder = Color(0xFFCBD5E1);

  final ScrollController _scrollController = ScrollController();
  final TextEditingController _activityController = TextEditingController();
  final Map<String, int> _selectedItems = {};

  DateTime _selectedDate = DateUtils.dateOnly(DateTime.now());
  bool _calendarOpen = false;
  int _jamMulai = 8;
  int _jamSelesai = 12;
  bool _isSubmitting = false;

  List<_CartEntry> get _cartEntries {
    final entries = <_CartEntry>[];
    for (final e in _selectedItems.entries) {
      for (final f in widget.fasilitas) {
        if (f.id == e.key) {
          entries.add(_CartEntry(facility: f, quantity: e.value));
          break;
        }
      }
    }
    return entries;
  }

  int get totalTypes => _cartEntries.length;
  int get totalUnits => _cartEntries.fold(0, (sum, i) => sum + i.quantity);

  void _updateStart(int value) {
    setState(() {
      _jamMulai = value;
      if (_jamSelesai <= _jamMulai) {
        _jamSelesai = (_jamMulai + 1).clamp(8, 17);
      }
    });
  }

  void _updateEnd(int value) {
    setState(() {
      _jamSelesai = value;
      if (_jamSelesai <= _jamMulai) {
        _jamMulai = (_jamSelesai - 1).clamp(7, 16);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    final availableFacilities = widget.fasilitas.where(
      (facility) => facility.tersedia,
    );
    final initial = widget.initialFacility.tersedia
        ? widget.initialFacility
        : availableFacilities.isEmpty
        ? null
        : availableFacilities.first;
    if (initial != null && !initial.isRuangan) {
      _selectedItems[initial.id] = 1;
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _activityController.dispose();
    super.dispose();
  }

  void _changeQty(String id, int delta) {
    FasilitasRingkas? facility;
    for (final f in widget.fasilitas) {
      if (f.id == id) {
        facility = f;
        break;
      }
    }
    if (facility == null) return;
    final current = _selectedItems[id] ?? 1;
    if (facility.unitTersedia <= 0) return;
    final next = (current + delta).clamp(1, facility.unitTersedia).toInt();
    setState(() => _selectedItems[id] = next);
  }

  Future<void> _showItemPicker() async {
    final items = widget.fasilitas.where((f) => !f.isRuangan).toList();
    final picked = await showModalBottomSheet<FasilitasRingkas>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _FacilityPickerSheet(facilities: items),
    );
    if (!mounted || picked == null) return;
    if (!picked.tersedia) {
      _showMessage('Barang tersebut tidak tersedia.', error: true);
      return;
    }
    setState(() => _selectedItems.putIfAbsent(picked.id, () => 1));
  }

  void _showMessage(String message, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: error
              ? const Color(0xFFDC2626)
              : const Color(0xFF059669),
        ),
      );
  }

  Future<void> _submit() async {
    if (!isBookingDateWithinWindow(
      date: _selectedDate,
      today: DateTime.now(),
      maxDaysAhead: 1,
    )) {
      _showMessage(
        'Tanggal peminjaman barang hanya tersedia hari ini atau besok.',
        error: true,
      );
      return;
    }
    if (_selectedItems.isEmpty) {
      _showMessage('Pilih barang terlebih dahulu.', error: true);
      return;
    }
    if (_cartEntries.any(
      (entry) => entry.quantity > entry.facility.unitTersedia,
    )) {
      _showMessage(
        'Stok salah satu barang berubah atau tidak mencukupi. Muat ulang form.',
        error: true,
      );
      return;
    }
    if (_activityController.text.trim().isEmpty) {
      _showMessage('Isi nama kegiatan atau kebutuhan.', error: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final mulai = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _jamMulai,
      );
      final selesai = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _jamSelesai,
      );
      final items = _cartEntries
          .map(
            (e) => ItemPeminjamanInput(
              fasilitasId: e.facility.id,
              namaFasilitas: e.facility.nama,
              jumlah: e.quantity,
            ),
          )
          .toList();

      await widget.peminjamanService.buat(
        items: items,
        kategori: 'praktik',
        namaKegiatan: _activityController.text.trim(),
        mulaiPada: mulai,
        estimasiKembaliPada: selesai,
      );
      if (!mounted) return;
      _showMessage('Pengajuan peminjaman berhasil dikirim!');
      context.go('/borrowings');
    } on PeminjamanException catch (e) {
      if (!mounted) return;
      _showMessage(e.pesan, error: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        fontFamily: GoogleFonts.outfit().fontFamily,
        scaffoldBackgroundColor: bgColor,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandBlue,
          primary: brandBlue,
        ),
      ),
      child: Scaffold(
        backgroundColor: bgColor,
        body: Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.only(top: 56 + 12, bottom: 96),
                child: Center(
                  child: Container(
                    width: double.infinity,
                    constraints: const BoxConstraints(maxWidth: 448),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBookingHeaderCard(),
                        const SizedBox(height: 14),
                        _buildLoanDateSection(),
                        const SizedBox(height: 14),
                        _buildLoanTimeSection(),
                        const SizedBox(height: 14),
                        _buildActivityNameSection(),
                        const SizedBox(height: 14),
                        _buildItemListSection(),
                        const SizedBox(height: 14),
                        _buildStockBanner(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            _BookingTopBar(onBack: () => context.pop()),
            _BookingBottomBar(isSubmitting: _isSubmitting, onSubmit: _submit),
          ],
        ),
      ),
    );
  }

  // ---------- Booking Header Card ----------
  Widget _buildBookingHeaderCard() {
    final first = _cartEntries.isNotEmpty ? _cartEntries.first.facility : null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              width: 80,
              height: 80,
              color: const Color(0xFFECFDF5),
              child: first?.fotoUrl != null && first!.fotoUrl!.isNotEmpty
                  ? Image.network(
                      first.fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.computer,
                        color: Color(0xFF059669),
                        size: 40,
                      ),
                    )
                  : const Icon(
                      Icons.computer,
                      color: Color(0xFF059669),
                      size: 40,
                    ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDBEAFE).withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Peminjaman Barang',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: brandBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Pilih barang yang ingin dipinjam',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Pastikan jumlah tidak melebihi stok yang tersedia',
                  style: TextStyle(
                    fontSize: 12,
                    color: mutedColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, size: 20, color: Color(0xFF94A3B8)),
        ],
      ),
    );
  }

  // ---------- Item List Section ----------
  Widget _buildItemListSection() {
    final items = _cartEntries;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Section Header
        const Row(
          children: [
            Icon(Icons.inventory_2_outlined, size: 20, color: brandBlue),
            SizedBox(width: 8),
            Text(
              'Daftar Barang',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Item cards
        ...items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: EdgeInsets.only(bottom: index < items.length - 1 ? 10 : 0),
            child: _buildItemCard(item),
          );
        }),
        const SizedBox(height: 10),
        // Add Item Button
        OutlinedButton(
          onPressed: _showItemPicker,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            side: const BorderSide(color: Color(0xFF2563EB)),
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  color: brandBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.add, size: 12, color: Colors.white),
              ),
              const SizedBox(width: 8),
              const Text(
                'Tambah Barang',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: brandBlue,
                ),
              ),
            ],
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 14),
          // Summary
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: slateBg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: slateBorder.withValues(alpha: 0.7)),
            ),
            child: Column(
              children: [
                _summaryRow(
                  icon: Icons.list,
                  label: 'Total Jenis Barang',
                  value: '$totalTypes Jenis',
                ),
                const SizedBox(height: 8),
                _summaryRow(
                  icon: Icons.inventory_2_outlined,
                  label: 'Total Unit Dipinjam',
                  value: '$totalUnits Unit',
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _summaryRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: brandBlue),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
            ),
          ],
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildItemCard(_CartEntry item) {
    final facility = item.facility;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 56,
              height: 56,
              color: const Color(0xFFF1F5F9),
              child: facility.fotoUrl != null && facility.fotoUrl!.isNotEmpty
                  ? Image.network(
                      facility.fotoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.devices_other,
                        color: Color(0xFF64748B),
                      ),
                    )
                  : const Icon(Icons.devices_other, color: Color(0xFF64748B)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  facility.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
                Text(
                  facility.kategori.isEmpty ? 'Barang' : facility.kategori,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: mutedColor),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF059669),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      facility.unitTersedia > 0
                          ? 'Tersedia ${facility.unitTersedia} unit'
                          : 'Stok habis',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF047857),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Stepper
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _circleBtn(
                bg: const Color(0xFFEFF6FF),
                fg: const Color(0xFF2563EB),
                icon: Icons.remove,
                onTap: () {
                  if (item.quantity > 1) _changeQty(facility.id, -1);
                },
              ),
              SizedBox(
                width: 42,
                child: Text(
                  '${item.quantity} Unit',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                ),
              ),
              _circleBtn(
                bg: brandBlue,
                fg: Colors.white,
                icon: Icons.add,
                onTap: () {
                  if (item.quantity < facility.unitTersedia) {
                    _changeQty(facility.id, 1);
                  }
                },
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => setState(() => _selectedItems.remove(facility.id)),
                child: const Icon(
                  Icons.delete_outline,
                  size: 16,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _circleBtn({
    required Color bg,
    required Color fg,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: bg,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          child: Icon(icon, size: 14, color: fg),
        ),
      ),
    );
  }

  // ---------- Date Section ----------
  Widget _buildLoanDateSection() {
    return _BookingDateSection(
      selectedDate: _selectedDate,
      calendarOpen: _calendarOpen,
      minDaysAhead: 0,
      maxDaysAhead: 1,
      markWeekendsFull: false,
      onToggleCalendar: () => setState(() => _calendarOpen = !_calendarOpen),
      onDateSelected: (date) {
        setState(() {
          _selectedDate = date;
          _calendarOpen = false;
        });
      },
    );
  }

  Widget _buildLoanTimeSection() {
    return _BookingTimeSection(
      jamMulai: _jamMulai,
      jamSelesai: _jamSelesai,
      endOptions: const [8, 9, 10, 11, 12, 13, 14, 15, 16, 17],
      onStartChanged: _updateStart,
      onEndChanged: _updateEnd,
    );
  }

  // ---------- Activity Name ----------
  Widget _buildActivityNameSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: brandBlue),
              SizedBox(width: 6),
              Text(
                'Nama Kegiatan / Kebutuhan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _activityController,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 13, color: textColor),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF8FAFC),
              hintText: 'Praktik Uji Coba Aplikasi Web Siswa',
              hintStyle: const TextStyle(
                fontSize: 13,
                color: Color(0xFF94A3B8),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: brandBlue, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------- Stock Banner ----------
  Widget _buildStockBanner() {
    final hasItems = _cartEntries.isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasItems
            ? const Color(0xFFD1FAE5).withValues(alpha: 0.8)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasItems ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: hasItems
                  ? const Color(0xFF059669)
                  : const Color(0xFFB45309),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasItems ? Icons.check : Icons.info_outline,
              size: 16,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasItems
                      ? 'Stok mencukupi untuk peminjaman ini'
                      : 'Pilih barang terlebih dahulu',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: hasItems
                        ? const Color(0xFF065F46)
                        : const Color(0xFF92400E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasItems
                      ? 'Semua barang tersedia sesuai waktu yang dipilih.'
                      : 'Gunakan tombol Tambah Barang untuk memilih.',
                  style: TextStyle(
                    fontSize: 12,
                    color: hasItems
                        ? const Color(0xFF047857)
                        : const Color(0xFF92400E),
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

// =============================================================================
// Shared Models & Widgets
// =============================================================================
class _BookingTopBar extends StatelessWidget {
  const _BookingTopBar({required this.onBack});

  final VoidCallback onBack;

  static const _surface = Color(0xFFF6F8FE);
  static const _onSurface = Color(0xFF131B2E);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: 0.9),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFEAEDFF), width: 0.6),
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SizedBox(
            height: 56,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _iconBtn(icon: Icons.arrow_back, onTap: onBack),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Formulir Booking',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _onSurface,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconBtn({required IconData icon, required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, size: 22, color: _onSurface),
        ),
      ),
    );
  }
}

class _BookingBottomBar extends StatelessWidget {
  const _BookingBottomBar({required this.isSubmitting, required this.onSubmit});

  final bool isSubmitting;
  final VoidCallback onSubmit;

  static const _surface = Color(0xFFF6F8FE);
  static const _primary = Color(0xFF0037B0);

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: _surface.withValues(alpha: 0.95),
          border: const Border(
            top: BorderSide(color: Color(0xFFEAEDFF), width: 0.6),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: SafeArea(
          top: false,
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 448),
              width: double.infinity,
              child: SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFFCBD5E1),
                    elevation: 4,
                    shadowColor: _primary.withValues(alpha: 0.25),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(50),
                    ),
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Lanjut ke Konfirmasi',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                                letterSpacing: -0.1,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingDateSection extends StatelessWidget {
  const _BookingDateSection({
    required this.selectedDate,
    required this.calendarOpen,
    required this.minDaysAhead,
    required this.maxDaysAhead,
    required this.markWeekendsFull,
    required this.onToggleCalendar,
    required this.onDateSelected,
  });

  final DateTime selectedDate;
  final bool calendarOpen;
  final int minDaysAhead;
  final int maxDaysAhead;
  final bool markWeekendsFull;
  final VoidCallback onToggleCalendar;
  final ValueChanged<DateTime> onDateSelected;

  static const _primary = Color(0xFF0037B0);
  static const _onSurface = Color(0xFF131B2E);
  static const _badgeBlueBg = Color(0xFFE8F0FE);
  static const _dateCardBg = Color(0xFFEDF2FE);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.calendar_month, size: 20, color: _primary),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Tanggal Peminjaman',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _onSurface,
                ),
              ),
            ),
            GestureDetector(
              onTap: onToggleCalendar,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: _badgeBlueBg,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.edit, size: 14, color: _primary),
                    SizedBox(width: 4),
                    Text(
                      'Ubah',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onToggleCalendar,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _dateCardBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 22, color: _primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _formatBookingDate(selectedDate),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          child: calendarOpen
              ? _BookingCalendar(
                  selectedDate: selectedDate,
                  minDaysAhead: minDaysAhead,
                  maxDaysAhead: maxDaysAhead,
                  markWeekendsFull: markWeekendsFull,
                  onDateSelected: onDateSelected,
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _BookingTimeSection extends StatelessWidget {
  const _BookingTimeSection({
    required this.jamMulai,
    required this.jamSelesai,
    required this.endOptions,
    required this.onStartChanged,
    required this.onEndChanged,
  });

  final int jamMulai;
  final int jamSelesai;
  final List<int> endOptions;
  final ValueChanged<int> onStartChanged;
  final ValueChanged<int> onEndChanged;

  static const _primary = Color(0xFF0037B0);
  static const _onSurface = Color(0xFF131B2E);
  static const _slate700 = Color(0xFF334155);
  static const _dateCardBg = Color(0xFFEDF2FE);

  @override
  Widget build(BuildContext context) {
    final duration = jamSelesai - jamMulai;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Row(
          children: [
            Icon(Icons.schedule, size: 20, color: _primary),
            SizedBox(width: 8),
            Text(
              'Waktu Peminjaman',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _BookingTimeSelectCard(
                label: 'Jam Mulai',
                value: jamMulai,
                options: const [7, 8, 9, 10, 11, 12, 13, 14, 15],
                onChanged: onStartChanged,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _BookingTimeSelectCard(
                label: 'Jam Selesai',
                value: jamSelesai,
                options: endOptions,
                onChanged: onEndChanged,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: _dateCardBg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.schedule, size: 18, color: _slate700),
                  SizedBox(width: 8),
                  Text(
                    'Durasi Peminjaman',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _slate700,
                    ),
                  ),
                ],
              ),
              Text(
                '$duration Jam',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _onSurface,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatBookingDate(DateTime date) {
  const weekdays = [
    'Senin',
    'Selasa',
    'Rabu',
    'Kamis',
    'Jumat',
    'Sabtu',
    'Minggu',
  ];
  const months = [
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];
  return '${weekdays[date.weekday - 1]}, ${date.day} ${months[date.month - 1]} ${date.year}';
}

class _BookingCalendar extends StatefulWidget {
  const _BookingCalendar({
    required this.selectedDate,
    required this.minDaysAhead,
    required this.maxDaysAhead,
    required this.onDateSelected,
    this.markWeekendsFull = false,
  });

  final DateTime selectedDate;
  final int minDaysAhead;
  final int maxDaysAhead;
  final ValueChanged<DateTime> onDateSelected;
  final bool markWeekendsFull;

  @override
  State<_BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends State<_BookingCalendar> {
  static const _surface = Color(0xFFFFFFFF);
  static const _primary = Color(0xFF0037B0);
  static const _onSurface = Color(0xFF131B2E);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate300 = Color(0xFFCBD5E1);
  static const _slate400 = Color(0xFF94A3B8);
  static const _slate500 = Color(0xFF64748B);
  static const _slate600 = Color(0xFF475569);
  static const _emerald500 = Color(0xFF10B981);
  static const _rose500 = Color(0xFFF43F5E);

  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    _visibleMonth = DateTime(
      widget.selectedDate.year,
      widget.selectedDate.month,
    );
  }

  @override
  void didUpdateWidget(covariant _BookingCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.year != widget.selectedDate.year ||
        oldWidget.selectedDate.month != widget.selectedDate.month) {
      _visibleMonth = DateTime(
        widget.selectedDate.year,
        widget.selectedDate.month,
      );
    }
  }

  List<CalDay> get _days {
    final firstOfMonth = DateTime(_visibleMonth.year, _visibleMonth.month);
    final daysInMonth = DateTime(
      _visibleMonth.year,
      _visibleMonth.month + 1,
      0,
    ).day;
    final previousMonthDays = DateTime(
      _visibleMonth.year,
      _visibleMonth.month,
      0,
    ).day;
    final minDate = DateUtils.dateOnly(
      DateTime.now().add(Duration(days: widget.minDaysAhead)),
    );
    final maxDate = DateUtils.dateOnly(
      DateTime.now().add(Duration(days: widget.maxDaysAhead)),
    );
    final cells = <CalDay>[];

    for (var i = 1; i < firstOfMonth.weekday; i++) {
      cells.add(
        CalDay(
          day: previousMonthDays - firstOfMonth.weekday + i + 1,
          isOffset: true,
        ),
      );
    }
    for (var day = 1; day <= daysInMonth; day++) {
      final date = DateTime(_visibleMonth.year, _visibleMonth.month, day);
      final isSelected = DateUtils.isSameDay(date, widget.selectedDate);
      final isUnavailable = date.isBefore(minDate) || date.isAfter(maxDate);
      final isFull =
          widget.markWeekendsFull &&
          (date.weekday == DateTime.saturday ||
              date.weekday == DateTime.sunday);
      final status = isUnavailable
          ? CalStatus.unavailable
          : isSelected
          ? CalStatus.selected
          : isFull
          ? CalStatus.full
          : CalStatus.available;
      cells.add(CalDay(day: day, date: date, status: status));
    }
    var nextMonthDay = 1;
    while (cells.length % 7 != 0) {
      cells.add(CalDay(day: nextMonthDay++, isOffset: true));
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    const monthNames = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    final days = _days;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () => setState(
                  () => _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month - 1,
                  ),
                ),
                icon: const Icon(Icons.chevron_left, color: _slate600),
              ),
              Expanded(
                child: Text(
                  '${monthNames[_visibleMonth.month - 1]} ${_visibleMonth.year}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _onSurface,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: 30,
                  height: 30,
                ),
                onPressed: () => setState(
                  () => _visibleMonth = DateTime(
                    _visibleMonth.year,
                    _visibleMonth.month + 1,
                  ),
                ),
                icon: const Icon(Icons.chevron_right, color: _slate600),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _slate100,
                  borderRadius: BorderRadius.circular(50),
                ),
                child: Text(
                  'H+${widget.minDaysAhead} - H+${widget.maxDaysAhead}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: _slate500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in ['Sen', 'Sel', 'Rab', 'Kam', 'Jum'])
                Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _slate400,
                      ),
                    ),
                  ),
                ),
              Expanded(
                child: Center(
                  child: Text(
                    'Sab',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _rose500,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Center(
                  child: Text(
                    'Min',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _rose500,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          for (var row = 0; row < days.length; row += 7)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  for (var column = 0; column < 7; column++)
                    Expanded(child: _buildDayCell(days[row + column])),
                ],
              ),
            ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: _slate100),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _legend(_emerald500, 'Tersedia'),
              if (widget.markWeekendsFull) ...[
                const SizedBox(width: 12),
                _legend(_rose500, 'Penuh'),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDayCell(CalDay day) {
    if (day.isOffset) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        alignment: Alignment.center,
        child: Text(
          '${day.day}',
          style: const TextStyle(fontSize: 12, color: _slate300),
        ),
      );
    }
    final selected = day.status == CalStatus.selected;
    final full = day.status == CalStatus.full;
    final unavailable = day.status == CalStatus.unavailable;
    return GestureDetector(
      onTap: unavailable || full
          ? null
          : () => widget.onDateSelected(day.date!),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6),
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        decoration: BoxDecoration(
          color: selected ? _primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              '${day.day}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: unavailable
                    ? _slate300
                    : selected
                    ? Colors.white
                    : _onSurface,
              ),
            ),
            const SizedBox(height: 2),
            if (!unavailable)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: full ? _rose500 : _emerald500,
                  shape: BoxShape.circle,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: _slate600)),
      ],
    );
  }
}

class _BookingTimeSelectCard extends StatelessWidget {
  const _BookingTimeSelectCard({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  static const _surface = Color(0xFFFFFFFF);
  static const _onSurface = Color(0xFF131B2E);
  static const _slate100 = Color(0xFFF1F5F9);
  static const _slate500 = Color(0xFF64748B);
  static const _slate700 = Color(0xFF334155);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _slate100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _slate500,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: options.contains(value) ? value : options.first,
                    isDense: true,
                    icon: const SizedBox.shrink(),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _onSurface,
                      fontFamily: GoogleFonts.outfit().fontFamily,
                    ),
                    dropdownColor: _surface,
                    borderRadius: BorderRadius.circular(12),
                    items: options
                        .map(
                          (hour) => DropdownMenuItem<int>(
                            value: hour,
                            child: Text(
                              '${hour.toString().padLeft(2, '0')}:00',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (hour) {
                      if (hour != null) onChanged(hour);
                    },
                  ),
                ),
              ),
              const Icon(Icons.expand_more, size: 20, color: _slate700),
            ],
          ),
        ],
      ),
    );
  }
}

class _CartEntry {
  const _CartEntry({required this.facility, required this.quantity});
  final FasilitasRingkas facility;
  final int quantity;
}

class _FacilityPickerSheet extends StatelessWidget {
  const _FacilityPickerSheet({required this.facilities});
  final List<FasilitasRingkas> facilities;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Pilih Barang atau Ruangan',
                      style: TextStyle(
                        color: Color(0xFF0F172A),
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            if (facilities.isEmpty)
              const Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                  'Belum ada yang tersedia.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: facilities.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final facility = facilities[index];
                    return ListTile(
                      enabled: facility.tersedia,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Icon(
                          facility.isRuangan
                              ? Icons.meeting_room_outlined
                              : Icons.devices_other,
                          color: const Color(0xFF1D4ED8),
                        ),
                      ),
                      title: Text(facility.nama),
                      subtitle: Text(
                        '${facility.kategori.isEmpty ? 'Barang' : facility.kategori} · ${facility.lokasi}',
                      ),
                      trailing: Text(
                        facility.tersedia
                            ? '${facility.unitTersedia} tersedia'
                            : 'Stok habis',
                        style: TextStyle(
                          color: facility.tersedia
                              ? const Color(0xFF059669)
                              : const Color(0xFF94A3B8),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: facility.tersedia
                          ? () => Navigator.pop(context, facility)
                          : null,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
