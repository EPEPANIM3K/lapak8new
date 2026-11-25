// lib/features/borrowings/screens/borrowing_form_screen.dart
// Form pengajuan peminjaman — menggunakan PeminjamanService (skema baru).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../models/peminjaman.dart';
import '../services/peminjaman_service.dart';

class BorrowingFormScreen extends StatefulWidget {
  const BorrowingFormScreen({super.key});
  @override
  State<BorrowingFormScreen> createState() => _BorrowingFormScreenState();
}

class _BorrowingFormScreenState extends State<BorrowingFormScreen> {
  // ===== Palette =====
  static const cSurface              = Color(0xFFFAF8FF);
  static const cSurfaceLowest        = Color(0xFFFFFFFF);
  static const cSurfaceLow           = Color(0xFFF2F3FF);
  static const cSurfaceContainer     = Color(0xFFEAEDFF);
  static const cSurfaceHigh          = Color(0xFFE2E7FF);
  static const cOnSurface            = Color(0xFF131B2E);
  static const cOnSurfaceVariant     = Color(0xFF434655);
  static const cPrimary              = Color(0xFF0037B0);
  static const cPrimaryFixed         = Color(0xFFDCE1FF);
  static const cOnPrimary            = Color(0xFFFFFFFF);
  static const cOnPrimaryContainer   = Color(0xFFCAD3FF);
  static const cTertiaryContainer    = Color(0xFF006A48);
  static const cTertiaryFixed        = Color(0xFF6FFBBE);
  static const cTertiaryFixedDim     = Color(0xFF4EDEA3);
  static const cOnTertiary           = Color(0xFFFFFFFF);
  static const cError                = Color(0xFFBA1A1A);
  static const cErrorContainer       = Color(0xFFFFDAD6);
  static const cOnErrorContainer     = Color(0xFF93000A);
  static const cSecondary            = Color(0xFF505F76);
  static const cOutlineVariant       = Color(0xFFC4C5D7);

  // ===== State =====
  String _kategori = 'praktik';
  final _acaraCtrl = TextEditingController(
    text: 'Praktik Uji Coba Aplikasi Web Siswa',
  );
  String _selectedSlot = '13:30 - 15:30';
  int _jumlah = 1;
  bool _agree = true;
  final _peminjamanService = peminjamanService;
  final List<FasilitasRingkas> _fasilitas = [];
  DateTime _selectedDate = DateUtils.dateOnly(
    DateTime.now().add(const Duration(days: 1)),
  );
  String? _selectedFasilitasId;
  String? _fasilitasError;
  bool _isLoadingFasilitas = true;
  bool _isSubmitting = false;

  final List<_Slot> _slots = const [
    _Slot(time: '08:00 - 10:00', label: 'Sesi pagi',    full: false),
    _Slot(time: '10:30 - 12:30', label: 'Sesi siang 1', full: false),
    _Slot(time: '13:30 - 15:30', label: 'Sesi siang 2', full: false),
    _Slot(time: '15:30 - 17:00', label: 'Sesi sore',    full: false),
  ];

  FasilitasRingkas? get _selectedFasilitas {
    for (final f in _fasilitas) {
      if (f.id == _selectedFasilitasId) return f;
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    _loadFasilitas();
  }

  @override
  void dispose() {
    _acaraCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFasilitas() async {
    try {
      final list = await _peminjamanService.ambilFasilitas();
      if (!mounted) return;
      setState(() {
        _fasilitas
          ..clear()
          ..addAll(list);
        _selectedFasilitasId ??= list.isEmpty ? null : list.first.id;
        _isLoadingFasilitas = false;
        _fasilitasError = null;
      });
    } on PeminjamanException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingFasilitas = false;
        _fasilitasError = e.pesan;
      });
    }
  }

  Future<void> _selectDate() async {
    final firstDate = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(firstDate) ? firstDate : _selectedDate,
      firstDate: firstDate,
      lastDate: firstDate.add(const Duration(days: 90)),
    );
    if (date != null) setState(() => _selectedDate = date);
  }

  DateTime _dateAt(String time) {
    final parts = time.split(':');
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      int.parse(parts[0]),
      int.parse(parts[1]),
    );
  }

  List<DateTime> get _dateChoices {
    final firstDate = DateUtils.dateOnly(
      DateTime.now().add(const Duration(days: 1)),
    );
    return List.generate(5, (i) => firstDate.add(Duration(days: i)));
  }

  String _formatDate(DateTime date, {bool weekday = true}) {
    const days = ['Senin','Selasa','Rabu','Kamis','Jumat','Sabtu','Minggu'];
    const months = [
      'Jan','Feb','Mar','Apr','Mei','Jun',
      'Jul','Agu','Sep','Okt','Nov','Des',
    ];
    final d = date.weekday - 1;
    final buf = StringBuffer();
    if (weekday) buf.write('${days[d]}, ');
    buf.write('${date.day} ${months[date.month - 1]}');
    return buf.toString();
  }

  Future<void> _submit() async {
    if (_selectedFasilitasId == null) {
      _snack('Pilih fasilitas terlebih dahulu.', error: true);
      return;
    }
    if (!_agree) {
      _snack('Setujui peraturan peminjaman terlebih dahulu.', error: true);
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final startParts  = _selectedSlot.split(' - ')[0].split(':');
      final endParts    = _selectedSlot.split(' - ')[1].split(':');
      final mulaiPada   = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        int.parse(startParts[0]), int.parse(startParts[1]),
      );
      final estimasi    = DateTime(
        _selectedDate.year, _selectedDate.month, _selectedDate.day,
        int.parse(endParts[0]), int.parse(endParts[1]),
      );

      final f = _selectedFasilitas!;
      await _peminjamanService.buat(
        fasilitasId:            f.id,
        namaFasilitas:          f.nama,
        kategori:               _kategori,
        namaKegiatan:           _acaraCtrl.text.trim(),
        jumlah:                 _jumlah,
        mulaiPada:              mulaiPada,
        estimasiKembaliPada:    estimasi,
      );
      if (!mounted) return;
      _snack('Pengajuan peminjaman berhasil dikirim!');
      context.go('/borrowings');
    } on PeminjamanException catch (e) {
      if (!mounted) return;
      _snack(e.pesan, error: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: error ? cError : cTertiaryContainer,
      ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cSurface,
      appBar: AppBar(
        backgroundColor: cSurface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: cOnSurface),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Ajukan Peminjaman',
          style: TextStyle(
            color: cOnSurface,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Kategori ---
            _sectionTitle('Kategori Peminjaman'),
            const SizedBox(height: 10),
            _buildKategoriChips(),
            const SizedBox(height: 20),

            // --- Fasilitas ---
            _sectionTitle('Pilih Fasilitas'),
            const SizedBox(height: 10),
            _buildFasilitasDropdown(),
            const SizedBox(height: 20),

            // --- Tanggal ---
            _sectionTitle('Pilih Tanggal'),
            const SizedBox(height: 10),
            _buildDateRow(),
            const SizedBox(height: 20),

            // --- Slot waktu ---
            _sectionTitle('Pilih Sesi Waktu'),
            const SizedBox(height: 10),
            _buildSlotGrid(),
            const SizedBox(height: 20),

            // --- Jumlah ---
            _sectionTitle('Jumlah Unit'),
            const SizedBox(height: 10),
            _buildJumlahRow(),
            const SizedBox(height: 20),

            // --- Nama kegiatan ---
            _sectionTitle('Nama Kegiatan'),
            const SizedBox(height: 10),
            _buildAcaraField(),
            const SizedBox(height: 20),

            // --- Peraturan ---
            _buildAgreementTile(),
            const SizedBox(height: 28),

            // --- Submit ---
            _buildSubmitButton(),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // Builders
  // =========================================================================

  Widget _sectionTitle(String text) => Text(
    text,
    style: const TextStyle(
      color: cOnSurface,
      fontWeight: FontWeight.w700,
      fontSize: 15,
    ),
  );

  Widget _buildKategoriChips() {
    const opts = [
      ('praktik', 'Praktik'),
      ('ekskul',  'Ekskul / IT'),
      ('lainnya', 'Lainnya'),
    ];
    return Wrap(
      spacing: 8,
      children: [
        for (final (val, label) in opts)
          ChoiceChip(
            label: Text(label),
            selected: _kategori == val,
            onSelected: (_) => setState(() => _kategori = val),
            selectedColor: cPrimaryFixed,
            labelStyle: TextStyle(
              color: _kategori == val ? cPrimary : cOnSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
            side: BorderSide(
              color: _kategori == val ? cPrimary : cOutlineVariant,
            ),
          ),
      ],
    );
  }

  Widget _buildFasilitasDropdown() {
    if (_isLoadingFasilitas) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_fasilitasError != null) {
      return Text(_fasilitasError!, style: const TextStyle(color: cError));
    }
    if (_fasilitas.isEmpty) {
      return const Text(
        'Tidak ada fasilitas tersedia.',
        style: TextStyle(color: cOnSurfaceVariant),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: cSurfaceLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cOutlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          isExpanded: true,
          value: _selectedFasilitasId,
          items: _fasilitas
              .map((f) => DropdownMenuItem(
                    value: f.id,
                    child: Text(
                      '${f.nama} (${f.lokasiNama ?? '-'})',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ))
              .toList(),
          onChanged: (v) => setState(() => _selectedFasilitasId = v),
        ),
      ),
    );
  }

  Widget _buildDateRow() {
    return SizedBox(
      height: 72,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final date in _dateChoices) ...[
            _DateCard(
              date: date,
              selected: DateUtils.isSameDay(date, _selectedDate),
              onTap: () => setState(() => _selectedDate = date),
            ),
            const SizedBox(width: 8),
          ],
          // Tombol pilih tanggal lain
          GestureDetector(
            onTap: _selectDate,
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: cSurfaceLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cOutlineVariant),
              ),
              child: const Icon(Icons.calendar_today, color: cPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotGrid() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final slot in _slots)
          GestureDetector(
            onTap: slot.full ? null : () => setState(() => _selectedSlot = slot.time),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: slot.full
                    ? cSurfaceHigh
                    : _selectedSlot == slot.time
                        ? cPrimary
                        : cSurfaceLowest,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _selectedSlot == slot.time ? cPrimary : cOutlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.time,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: slot.full
                          ? cOnSurfaceVariant
                          : _selectedSlot == slot.time
                              ? cOnPrimary
                              : cOnSurface,
                    ),
                  ),
                  Text(
                    slot.full ? 'Penuh' : slot.label,
                    style: TextStyle(
                      fontSize: 11,
                      color: slot.full
                          ? cError
                          : _selectedSlot == slot.time
                              ? cOnPrimaryContainer
                              : cOnSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildJumlahRow() {
    return Row(
      children: [
        _CounterButton(
          icon: Icons.remove,
          onPressed: _jumlah > 1 ? () => setState(() => _jumlah--) : null,
        ),
        const SizedBox(width: 16),
        Text(
          '$_jumlah unit',
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: cOnSurface,
          ),
        ),
        const SizedBox(width: 16),
        _CounterButton(
          icon: Icons.add,
          onPressed: () => setState(() => _jumlah++),
        ),
        if (_selectedFasilitas != null) ...[
          const SizedBox(width: 12),
          Text(
            '(maks. ${_selectedFasilitas!.totalUnit})',
            style: const TextStyle(color: cOnSurfaceVariant, fontSize: 12),
          ),
        ],
      ],
    );
  }

  Widget _buildAcaraField() {
    return TextField(
      controller: _acaraCtrl,
      style: const TextStyle(color: cOnSurface),
      decoration: InputDecoration(
        hintText: 'Nama kegiatan / acara...',
        hintStyle: const TextStyle(color: cOnSurfaceVariant),
        filled: true,
        fillColor: cSurfaceLowest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cOutlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: cOutlineVariant),
        ),
      ),
    );
  }

  Widget _buildAgreementTile() {
    return GestureDetector(
      onTap: () => setState(() => _agree = !_agree),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: _agree,
            onChanged: (v) => setState(() => _agree = v ?? false),
            activeColor: cPrimary,
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Saya menyetujui peraturan peminjaman fasilitas sekolah dan '
              'bersedia bertanggung jawab atas kondisi barang yang dipinjam.',
              style: TextStyle(color: cOnSurfaceVariant, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _isSubmitting ? null : _submit,
        style: ElevatedButton.styleFrom(
          backgroundColor: cPrimary,
          foregroundColor: cOnPrimary,
          shape: const StadiumBorder(),
          elevation: 0,
        ),
        child: _isSubmitting
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: cOnPrimary,
                ),
              )
            : const Text(
                'Kirim Pengajuan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers kecil
// ---------------------------------------------------------------------------

class _Slot {
  const _Slot({required this.time, required this.label, required this.full});
  final String time;
  final String label;
  final bool full;
}

class _DateCard extends StatelessWidget {
  const _DateCard({
    required this.date,
    required this.selected,
    required this.onTap,
  });

  final DateTime date;
  final bool selected;
  final VoidCallback onTap;

  static const _days = ['Sen','Sel','Rab','Kam','Jum','Sab','Min'];

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 56,
        decoration: BoxDecoration(
          color: selected ? _BorrowingFormScreenState.cPrimary : _BorrowingFormScreenState.cSurfaceLowest,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? _BorrowingFormScreenState.cPrimary
                : _BorrowingFormScreenState.cOutlineVariant,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _days[date.weekday - 1],
              style: TextStyle(
                fontSize: 11,
                color: selected
                    ? _BorrowingFormScreenState.cOnPrimaryContainer
                    : _BorrowingFormScreenState.cOnSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${date.day}',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: selected
                    ? _BorrowingFormScreenState.cOnPrimary
                    : _BorrowingFormScreenState.cOnSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CounterButton extends StatelessWidget {
  const _CounterButton({required this.icon, required this.onPressed});
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _BorrowingFormScreenState.cSurfaceLow,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: 20,
            color: onPressed == null
                ? _BorrowingFormScreenState.cOnSurfaceVariant
                : _BorrowingFormScreenState.cPrimary,
          ),
        ),
      ),
    );
  }
}
