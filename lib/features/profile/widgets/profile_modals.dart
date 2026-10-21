import 'package:flutter/material.dart';

// ==========================================
// 1. POPUP UBAH KATA SANDI
// ==========================================
class ChangePasswordModal extends StatefulWidget {
  const ChangePasswordModal({super.key});

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

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
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
                width: 40, height: 4,
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
                const Text('Ubah Kata Sandi',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF131B2E))),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFFF2F3FF), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF434655)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Pastikan kata sandi baru Anda kuat dan mudah diingat.',
              style: TextStyle(fontSize: 12, color: Color(0xFF505F76))),
            const SizedBox(height: 20),

            // Input: Kata Sandi Saat Ini
            _buildTextField(
              label: 'Kata Sandi Saat Ini',
              controller: _oldCtrl,
              obscure: _obscureOld,
              onToggleVisibility: () => setState(() => _obscureOld = !_obscureOld),
            ),
            const SizedBox(height: 16),

            // Input: Kata Sandi Baru
            _buildTextField(
              label: 'Kata Sandi Baru',
              controller: _newCtrl,
              obscure: _obscureNew,
              onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 16),

            // Input: Konfirmasi Kata Sandi
            _buildTextField(
              label: 'Konfirmasi Kata Sandi Baru',
              controller: _confirmCtrl,
              obscure: _obscureConfirm,
              onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 24),

            // Tombol Aksi
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kata sandi berhasil diperbarui!'), behavior: SnackBarBehavior.floating),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0037B0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Simpan Perubahan', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Batal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF131B2E))),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(fontSize: 14, color: Color(0xFF131B2E)),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFFF2F3FF),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            prefixIcon: const Icon(Icons.lock_outline, size: 20, color: Color(0xFF747686)),
            suffixIcon: IconButton(
              icon: Icon(obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20, color: const Color(0xFF747686)),
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
  const ChangePhoneModal({super.key});

  @override
  State<ChangePhoneModal> createState() => _ChangePhoneModalState();
}

class _ChangePhoneModalState extends State<ChangePhoneModal> {
  final _phoneCtrl = TextEditingController(text: '+62 812-3456-7890');

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
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
                width: 40, height: 4,
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
                const Text('Ubah Nomor Telepon',
                  style: TextStyle(fontFamily: 'Outfit', fontSize: 20, fontWeight: FontWeight.w700, color: Color(0xFF131B2E))),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(color: Color(0xFFF2F3FF), shape: BoxShape.circle),
                    child: const Icon(Icons.close, size: 18, color: Color(0xFF434655)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text('Nomor ini akan digunakan untuk dihubungi oleh PIC Sarpras terkait peminjaman.',
              style: TextStyle(fontSize: 12, color: Color(0xFF505F76), height: 1.4)),
            const SizedBox(height: 20),

            // Input: Nomor Telepon
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Nomor WhatsApp Aktif',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF131B2E))),
                const SizedBox(height: 6),
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(fontSize: 14, color: Color(0xFF131B2E), fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: const Color(0xFFF2F3FF),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    prefixIcon: const Icon(Icons.phone_android, size: 20, color: Color(0xFF0037B0)),
                    hintText: '+62 8xx-xxxx-xxxx',
                    hintStyle: const TextStyle(color: Color(0xFFC4C5D7), fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

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
                    child: Text('Pastikan nomor yang dimasukkan adalah nomor WhatsApp yang aktif.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF434655), height: 1.4)),
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
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Nomor telepon berhasil diperbarui!'), behavior: SnackBarBehavior.floating),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0037B0),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Simpan Nomor', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
                ),
                child: const Text('Batal', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}