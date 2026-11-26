import 'package:flutter/material.dart';

// ==========================================
// 1. POPUP UBAH KATA SANDI
// ==========================================
class ChangePasswordModal extends StatefulWidget {
  const ChangePasswordModal({required this.onSave, super.key});

  final Future<void> Function(String currentPassword, String newPassword)
  onSave;

  @override
  State<ChangePasswordModal> createState() => _ChangePasswordModalState();
}

class _ChangePasswordModalState extends State<ChangePasswordModal> {
  // State untuk toggle mata (show/hide password)
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Controllers
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;
  String? _error;

  bool get _canSave =>
      _oldCtrl.text.isNotEmpty &&
      _newCtrl.text.length >= 6 &&
      _confirmCtrl.text == _newCtrl.text;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_canSave || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_oldCtrl.text, _newCtrl.text);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Kata sandi berhasil diperbarui.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC4C5D7).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ubah Kata Sandi',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF131B2E),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF434655),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Pastikan kata sandi baru Anda kuat dan mudah diingat.',
              style: TextStyle(fontSize: 12, color: Color(0xFF505F76)),
            ),
            const SizedBox(height: 20),

            // Input: Kata Sandi Saat Ini
            _buildTextField(
              label: 'Kata Sandi Saat Ini',
              controller: _oldCtrl,
              obscure: _obscureOld,
              onToggleVisibility: () =>
                  setState(() => _obscureOld = !_obscureOld),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Input: Kata Sandi Baru
            _buildTextField(
              label: 'Kata Sandi Baru',
              controller: _newCtrl,
              obscure: _obscureNew,
              onToggleVisibility: () =>
                  setState(() => _obscureNew = !_obscureNew),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Input: Konfirmasi Kata Sandi
            _buildTextField(
              label: 'Konfirmasi Kata Sandi Baru',
              controller: _confirmCtrl,
              obscure: _obscureConfirm,
              onToggleVisibility: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              onChanged: (_) => setState(() {}),
            ),
            if (_newCtrl.text.isNotEmpty && _newCtrl.text.length < 6)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Kata sandi baru minimal 6 karakter.'),
              ),
            if (_confirmCtrl.text.isNotEmpty &&
                _confirmCtrl.text != _newCtrl.text)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text('Konfirmasi kata sandi tidak cocok.'),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFBA1A1A)),
                ),
              ),
            const SizedBox(height: 24),

            // Tombol Aksi
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canSave && !_saving ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0037B0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  _saving ? 'Menyimpan...' : 'Simpan Perubahan',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF434655),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget Helper untuk TextField
  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required bool obscure,
    required VoidCallback onToggleVisibility,
    required ValueChanged<String> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF131B2E),
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: Color(0xFF131B2E)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF2F3FF),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            prefixIcon: const Icon(
              Icons.lock_outline,
              size: 20,
              color: Color(0xFF747686),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                obscure
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
                color: const Color(0xFF747686),
              ),
              onPressed: onToggleVisibility,
            ),
            hintText: '••••••••',
            hintStyle: const TextStyle(color: Color(0xFFC4C5D7), fontSize: 14),
          ),
        ),
      ],
    );
  }
}

// ==========================================
// 2. POPUP UBAH NOMOR TELEPON
// ==========================================
class ChangePhoneModal extends StatefulWidget {
  const ChangePhoneModal({
    required this.initialPhone,
    required this.onSave,
    super.key,
  });

  final String initialPhone;
  final Future<void> Function(String phone) onSave;

  @override
  State<ChangePhoneModal> createState() => _ChangePhoneModalState();
}

class _ChangePhoneModalState extends State<ChangePhoneModal> {
  late final _phoneCtrl = TextEditingController(text: widget.initialPhone);
  bool _saving = false;
  String? _error;

  String get _normalizedPhone =>
      _phoneCtrl.text.trim().replaceAll(RegExp(r'[\s()-]'), '');

  bool get _phoneValid =>
      RegExp(r'^\+?[0-9]{8,15}$').hasMatch(_normalizedPhone);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_phoneValid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_normalizedPhone);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Nomor telepon berhasil diperbarui.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFC4C5D7).withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ubah Nomor Telepon',
                  style: TextStyle(
                    fontFamily: 'Outfit',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF131B2E),
                  ),
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFF2F3FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF434655),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Nomor ini akan digunakan untuk dihubungi oleh PIC Sarpras terkait peminjaman.',
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF505F76),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),

            // Input: Nomor Telepon
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nomor WhatsApp Aktif',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF131B2E),
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF131B2E),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF2F3FF),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: const Icon(
                      Icons.phone_android,
                      size: 20,
                      color: Color(0xFF0037B0),
                    ),
                    hintText: '+62 8xx-xxxx-xxxx',
                    hintStyle: const TextStyle(
                      color: Color(0xFFC4C5D7),
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_phoneCtrl.text.isNotEmpty && !_phoneValid)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'Masukkan nomor telepon yang valid (8–15 digit).',
                  style: TextStyle(color: Color(0xFFBA1A1A)),
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Color(0xFFBA1A1A)),
                ),
              ),

            // Info Banner Kecil
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEAEDFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Icon(Icons.info_outline, size: 16, color: Color(0xFF0037B0)),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pastikan nomor yang dimasukkan adalah nomor WhatsApp yang aktif.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF434655),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Tombol Aksi
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _phoneValid && !_saving ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0037B0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: Text(
                  _saving ? 'Menyimpan...' : 'Simpan Nomor',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF434655),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                child: const Text(
                  'Batal',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
