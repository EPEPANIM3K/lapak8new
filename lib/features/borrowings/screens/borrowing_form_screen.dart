import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/lapak8_api_client.dart';
import '../models/borrowing.dart';
import '../services/borrowing_service.dart';

class BorrowingFormScreen extends StatefulWidget {
  const BorrowingFormScreen({super.key});
  @override
  State<BorrowingFormScreen> createState() => _BorrowingFormScreenState();
}

class _BorrowingFormScreenState extends State<BorrowingFormScreen> {
  // ===== Palette (LENGKAP) =====
  static const cSurface = Color(0xFFFAF8FF);
  static const cSurfaceLowest = Color(0xFFFFFFFF);
  static const cSurfaceLow = Color(0xFFF2F3FF);
  static const cSurfaceContainer = Color(0xFFEAEDFF);
  static const cSurfaceHigh = Color(0xFFE2E7FF);
  static const cOnSurface = Color(0xFF131B2E);
  static const cOnSurfaceVariant = Color(0xFF434655);
  static const cPrimary = Color(0xFF0037B0);
  static const cPrimaryFixed = Color(0xFFDCE1FF);
  static const cOnPrimary = Color(0xFFFFFFFF);
  static const cOnPrimaryContainer = Color(0xFFCAD3FF);
  static const cTertiaryContainer = Color(0xFF006A48);
  static const cTertiaryFixed = Color(0xFF6FFBBE);
  static const cTertiaryFixedDim = Color(0xFF4EDEA3);
  static const cOnTertiary = Color(0xFFFFFFFF);
  static const cError = Color(0xFFBA1A1A);
  static const cErrorContainer = Color(0xFFFFDAD6);
  static const cOnErrorContainer = Color(0xFF93000A);
  static const cSecondary = Color(0xFF505F76);
  static const cOutlineVariant = Color(0xFFC4C5D7);

  // ===== State =====
  String _kategori = 'praktik';
  final _acaraCtrl = TextEditingController(
    text: 'Praktik Uji Coba Aplikasi Web Siswa',
  );
  String _selectedSlot = '13:30 - 15:30';
  int _jumlah = 1;
  bool _agree = true;
  final _borrowingService = BorrowingService();
  final List<BorrowingFacility> _facilities = [];
  DateTime _selectedDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  String? _selectedFacilityId;
  String? _facilityError;
  bool _isLoadingFacilities = true;
  bool _isSubmitting = false;

  // Data sesi
  final List<_Slot> _slots = const [
    _Slot(time: '08:00 - 10:00', label: 'Sesi pagi', full: false),
    _Slot(time: '10:30 - 12:30', label: 'Sesi siang 1', full: false),
    _Slot(time: '13:30 - 15:30', label: 'Sesi siang 2', full: false),
    _Slot(time: '15:30 - 17:00', label: 'Sesi sore', full: false),
  ];

  BorrowingFacility? get _selectedFacility {
    for (final facility in _facilities) {
      if (facility.id == _selectedFacilityId) return facility;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  @override
  void dispose() {
    _acaraCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFacilities() async {
    try {
      final facilities = await _borrowingService.fetchFacilities();
      if (!mounted) return;
      setState(() {
        _facilities
          ..clear()
          ..addAll(facilities);
        _selectedFacilityId ??= facilities.isEmpty ? null : facilities.first.id;
        _isLoadingFacilities = false;
        _facilityError = null;
      });
    } on Lapak8ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingFacilities = false;
        _facilityError = error.message;
      });
    }
  }

  Future<void> _selectDate() async {
    final firstDate = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstDate)
          ? firstDate
          : _selectedDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 90)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  DateTime _dateAt(String time) {
    final parts = time.split(':');
    final hour = int.parse(parts[0]);
    final minute = int.parse(parts[1]);
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      hour,
      minute,
    );
  }

  List<DateTime> get _dateChoices {
    final firstDate = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    return List.generate(5, (index) => firstDate.add(Duration(days: index)));
  }

  String _formatDate(DateTime date, {bool weekday = true}) {
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
    final dateText = '${date.day} ${months[date.month - 1]} ${date.year}';
    return weekday ? '${weekdays[date.weekday - 1]}, $dateText' : dateText;
  }

  void _submit() {
    if (!_agree) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setujui SOP terlebih dahulu.')),
      );
      return;
    }
    final facility = _selectedFacility;
    if (facility == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih fasilitas yang akan dipinjam.')),
      );
      return;
    }
    if (_jumlah > facility.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Stok fasilitas ini hanya ${facility.stock} unit.'),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi Pengajuan'),
        content: Text(
          'Ajukan peminjaman ${facility.name} sebanyak $_jumlah unit pada '
          '${_formatDate(_selectedDate, weekday: false)}, sesi $_selectedSlot?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: _isSubmitting
                ? null
                : () async {
                    Navigator.pop(context);
                    await _submitToApi(facility);
                  },
            child: const Text('Ya, Ajukan'),
          ),
        ],
      ),
    );
  }

  Future<void> _submitToApi(BorrowingFacility facility) async {
    setState(() => _isSubmitting = true);
    try {
      final parts = _selectedSlot.split(' - ');
      final booking = await _borrowingService.create(
        facilityId: facility.id,
        category: _kategori,
        eventName: _acaraCtrl.text.trim(),
        quantity: _jumlah,
        startAt: _dateAt(parts.first),
        endAt: _dateAt(parts.last),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pengajuan ${booking.code} berhasil dikirim.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/borrowings');
    } on Lapak8ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _saveDraft() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Fitur draf belum terhubung ke backend.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cSurface,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                _facilitySection(),
                const SizedBox(height: 12),
                _previewCard(),
                const SizedBox(height: 12),
                _stepperCard(),
                const SizedBox(height: 12),
                _kategoriSection(),
                const SizedBox(height: 12),
                _namaAcaraSection(),
                const SizedBox(height: 12),
                _tanggalSection(),
                const SizedBox(height: 12),
                _sesiSection(),
                const SizedBox(height: 12),
                _jumlahSection(),
                const SizedBox(height: 12),
                _sopSection(),
              ],
            ),
          ),
          _bottomActionBar(),
        ],
      ),
    );
  }

  Widget _facilitySection() => _cardWrapper(
    children: [
      _sectionLabel(Icons.meeting_room_outlined, 'Pilih Fasilitas'),
      const SizedBox(height: 10),
      if (_isLoadingFacilities)
        const Center(child: CircularProgressIndicator())
      else if (_facilityError != null)
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_facilityError!, style: const TextStyle(color: cError)),
            TextButton(
              onPressed: () {
                setState(() {
                  _isLoadingFacilities = true;
                  _facilityError = null;
                });
                _loadFacilities();
              },
              child: const Text('Coba lagi'),
            ),
          ],
        )
      else if (_facilities.isEmpty)
        const Text('Belum ada fasilitas aktif di database.')
      else
        DropdownButtonFormField<String>(
          initialValue: _selectedFacilityId,
          isExpanded: true,
          decoration: const InputDecoration(
            filled: true,
            border: OutlineInputBorder(),
          ),
          items: _facilities
              .map(
                (facility) => DropdownMenuItem(
                  value: facility.id,
                  child: Text(
                    '${facility.name} (${facility.stock} unit)',
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            BorrowingFacility? facility;
            for (final item in _facilities) {
              if (item.id == id) facility = item;
            }
            setState(() {
              _selectedFacilityId = id;
              if (facility != null && _jumlah > facility.stock) {
                _jumlah = facility.stock;
              }
            });
          },
        ),
    ],
  );

  // ============ HEADER ============
  Widget _header() => Container(
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 8,
      bottom: 8,
      left: 8,
      right: 16,
    ),
    decoration: BoxDecoration(color: cSurface.withValues(alpha: 0.85)),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.maybePop(context),
          icon: const Icon(Icons.arrow_back, size: 24, color: cOnSurface),
        ),
        const Expanded(
          child: Text(
            'Formulir Booking',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Outfit',
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: cOnSurface,
              letterSpacing: -0.3,
            ),
          ),
        ),
      ],
    ),
  );

  // ============ PREVIEW CARD ============
  Widget _previewCard() {
    final facility = _selectedFacility;
    return Container(
      padding: const EdgeInsets.all(12),
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    'https://images.unsplash.com/photo-1562774053-701939374585?auto=format&fit=crop&w=300&q=80',
                    fit: BoxFit.cover,
                    loadingBuilder: (_, child, p) =>
                        p == null ? child : Container(color: cSurfaceContainer),
                    errorBuilder: (_, __, ___) => Container(
                      color: cSurfaceContainer,
                      child: const Icon(
                        Icons.image_outlined,
                        color: cOutlineVariant,
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cTertiaryContainer.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.circle, size: 6, color: cTertiaryFixedDim),
                          SizedBox(width: 4),
                          Text(
                            'Siap Pakai',
                            style: TextStyle(
                              fontSize: 9,
                              color: cOnTertiary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ITEM YANG DIPINJAM',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: cPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  facility?.name ?? 'Pilih fasilitas',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: cOnSurface,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 14, color: cPrimary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        facility?.location ?? 'Lokasi fasilitas',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: cOnSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: const [
                    Icon(Icons.support_agent, size: 14, color: cSecondary),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'Pengajuan dikirim ke petugas Sarpras',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: cSecondary,
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
    );
  }

  // ============ STEPPER CARD ============
  Widget _stepperCard() => Container(
    padding: const EdgeInsets.all(16),
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
        Row(
          children: [
            const Expanded(
              child: Text(
                'Langkah 1 dari 2',
                style: TextStyle(
                  fontFamily: 'Outfit',
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: cOnSurface,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cPrimaryFixed.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Detail Peminjaman',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: cPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: 0.5,
            minHeight: 8,
            backgroundColor: cSurfaceContainer,
            valueColor: const AlwaysStoppedAnimation(cPrimary),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Lengkapi data kebutuhan kegiatan sebelum proses tinjauan kaprodi.',
          style: TextStyle(fontSize: 12, color: cOnSurfaceVariant),
        ),
      ],
    ),
  );

  // ============ KATEGORI ============
  Widget _kategoriSection() => _cardWrapper(
    children: [
      _sectionLabel(Icons.category, 'Kategori Keperluan'),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(child: _kategoriBtn('praktik', 'Praktik Belajar')),
          const SizedBox(width: 8),
          Expanded(child: _kategoriBtn('ekskul', 'Ekskul / IT')),
          const SizedBox(width: 8),
          Expanded(child: _kategoriBtn('lainnya', 'Lainnya')),
        ],
      ),
    ],
  );

  Widget _kategoriBtn(String value, String label) {
    final selected = _kategori == value;
    return GestureDetector(
      onTap: () => setState(() => _kategori = value),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? cPrimary : cSurfaceLow,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? cOnPrimary : cOnSurface,
                ),
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.check_circle_outline,
              size: 16,
              color: selected ? cOnPrimary : Colors.transparent,
            ),
          ],
        ),
      ),
    );
  }

  // ============ NAMA ACARA ============
  Widget _namaAcaraSection() => _cardWrapper(
    children: [
      _sectionLabel(Icons.edit_note, 'Nama Acara / Kegiatan'),
      const SizedBox(height: 10),
      Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: cSurfaceLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: TextField(
          controller: _acaraCtrl,
          style: const TextStyle(fontSize: 13, color: cOnSurface),
          decoration: const InputDecoration(
            isDense: true,
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
            hintText: 'Nama acara',
            hintStyle: TextStyle(color: cOnSurfaceVariant, fontSize: 13),
          ),
        ),
      ),
    ],
  );

  // ============ TANGGAL ============
  Widget _tanggalSection() => _cardWrapper(
    children: [
      Row(
        children: [
          Expanded(
            child: _sectionLabel(Icons.calendar_month, 'Tanggal Peminjaman'),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: cTertiaryFixed.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              '1 Hari Dipilih',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: cTertiaryContainer,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: cSurfaceLow,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          children: [
            const Icon(Icons.today, size: 20, color: cPrimary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _formatDate(_selectedDate),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: cOnSurface,
                ),
              ),
            ),
            IconButton(
              onPressed: _selectDate,
              tooltip: 'Pilih tanggal',
              icon: const Icon(Icons.calendar_today, color: cPrimary),
            ),
          ],
        ),
      ),
      const SizedBox(height: 10),
      Row(
        children: _dateChoices
            .map(
              (date) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: _calDay(date),
                ),
              ),
            )
            .toList(),
      ),
    ],
  );

  Widget _calDay(DateTime date) {
    final selected = DateUtils.isSameDay(date, _selectedDate);
    const weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return InkWell(
      onTap: () => setState(() => _selectedDate = date),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? cPrimary : cSurfaceLow,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              weekdays[date.weekday - 1],
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: selected ? cOnPrimaryContainer : cOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.day}',
              style: TextStyle(
                fontFamily: 'Outfit',
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: selected ? cOnPrimary : cOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ SESI ============
  Widget _sesiSection() => _cardWrapper(
    children: [
      _sectionLabel(Icons.schedule, 'Sesi Waktu Peminjaman'),
      const SizedBox(height: 10),
      ..._slots.map(
        (s) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _slotTile(s),
        ),
      ),
    ],
  );

  Widget _slotTile(_Slot s) {
    final selected = !s.full && _selectedSlot == s.time;
    if (s.full) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cErrorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel, color: cError, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.time,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: cOnSurface,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  Text(
                    s.label,
                    style: const TextStyle(fontSize: 11, color: cError),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: cErrorContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Penuh',
                style: TextStyle(
                  fontSize: 10,
                  color: cOnErrorContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedSlot = s.time),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? cPrimary : cSurfaceLow,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x1A000000),
                    blurRadius: 4,
                    offset: Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              color: selected ? cOnPrimary : cTertiaryContainer,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.time,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: selected ? cOnPrimary : cOnSurface,
                    ),
                  ),
                  Text(
                    selected ? 'Sesi Siang 2 - Terpilih' : s.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: selected
                          ? cOnPrimaryContainer
                          : cTertiaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: selected
                    ? cSurfaceLowest
                    : cTertiaryFixed.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                selected ? 'Aktif' : 'Tersedia',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: selected ? cPrimary : cTertiaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============ JUMLAH ============
  Widget _jumlahSection() => _cardWrapper(
    children: [
      Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionLabel(Icons.inventory_2, 'Jumlah Item'),
                const SizedBox(height: 2),
                Text(
                  'Stok tersedia: ${_selectedFacility?.stock ?? 0} unit',
                  style: TextStyle(fontSize: 12, color: cOnSurfaceVariant),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: cSurfaceLow,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  onPressed: _jumlah > 1
                      ? () => setState(() => _jumlah--)
                      : null,
                  icon: const Icon(Icons.remove, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: cSurfaceLowest,
                    foregroundColor: cOnSurface,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
                SizedBox(
                  width: 72,
                  child: Text(
                    '$_jumlah Unit',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: cOnSurface,
                    ),
                  ),
                ),
                IconButton(
                  onPressed:
                      _jumlah < (_selectedFacility?.stock ?? 0) && _jumlah < 5
                      ? () => setState(() => _jumlah++)
                      : null,
                  icon: const Icon(Icons.add, size: 18),
                  style: IconButton.styleFrom(
                    backgroundColor: cPrimary,
                    foregroundColor: cOnPrimary,
                    minimumSize: const Size(36, 36),
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ],
  );

  // ============ SOP ============
  Widget _sopSection() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: cSurfaceLow,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0D000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: _agree,
          onChanged: (v) => setState(() => _agree = v ?? false),
          activeColor: cPrimary,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _agree = !_agree),
            child: RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 12,
                  color: cOnSurface,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'Saya berjanji mematuhi '),
                  const TextSpan(
                    text: 'SOP Laboratorium Komputer',
                    style: TextStyle(
                      color: cPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const TextSpan(
                    text:
                        ' & bertanggung jawab penuh atas kebersihan, ketertiban, serta integritas perangkat selama durasi penggunaan.',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ============ BOTTOM ACTION BAR ============
  Widget _bottomActionBar() => Container(
    padding: EdgeInsets.only(
      left: 16,
      right: 16,
      top: 12,
      bottom: MediaQuery.of(context).padding.bottom + 12,
    ),
    decoration: BoxDecoration(
      color: cSurfaceLowest.withValues(alpha: 0.9),
      boxShadow: const [
        BoxShadow(
          color: Color(0x28000000),
          blurRadius: 20,
          offset: Offset(0, -4),
        ),
      ],
    ),
    child: Row(
      children: [
        SizedBox(
          height: 44,
          child: OutlinedButton.icon(
            onPressed: _saveDraft,
            icon: const Icon(Icons.bookmark_border, size: 18),
            label: const Text('Draf', style: TextStyle(fontSize: 13)),
            style: OutlinedButton.styleFrom(
              foregroundColor: cPrimary,
              backgroundColor: cSurfaceHigh,
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: SizedBox(
            height: 44,
            child: ElevatedButton(
              onPressed: _isSubmitting || _isLoadingFacilities ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: cPrimary,
                foregroundColor: cOnPrimary,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSubmitting ? 'Mengirim...' : 'Ajukan Booking Sekarang',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  // ============ HELPERS ============
  Widget _cardWrapper({required List<Widget> children}) => Container(
    padding: const EdgeInsets.all(16),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );

  Widget _sectionLabel(IconData icon, String text) => Row(
    children: [
      Icon(icon, size: 18, color: cPrimary),
      const SizedBox(width: 6),
      Text(
        text,
        style: const TextStyle(
          fontFamily: 'Outfit',
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: cOnSurface,
        ),
      ),
    ],
  );
}

// ===== MODEL CLASSES =====
class _Slot {
  final String time, label;
  final bool full;
  const _Slot({required this.time, required this.label, required this.full});
}
