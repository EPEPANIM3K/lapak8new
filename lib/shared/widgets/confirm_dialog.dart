import 'package:flutter/material.dart';

class ConfirmDialog extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String cancelText;
  final String confirmText;
  final VoidCallback onConfirm;

  // ---- TAMBAHAN (opsional, default = tampilan lama) -----------------------
  /// Ikon kecil di tombol konfirmasi. Isi null untuk menyembunyikan ikon.
  final IconData? confirmIcon;

  /// Warna tombol konfirmasi.
  final Color confirmColor;

  /// Warna ikon utama.
  final Color iconColor;

  /// Warna lingkaran di belakang ikon utama.
  final Color iconBackground;

  const ConfirmDialog({
    super.key,
    this.icon = Icons.save,
    required this.title,
    required this.message,
    this.cancelText = 'Batal',
    this.confirmText = 'Ya, Simpan',
    required this.onConfirm,
    this.confirmIcon = Icons.check,
    this.confirmColor = const Color(0xFF004BE4),
    this.iconColor = const Color(0xFF004BE4),
    this.iconBackground = const Color(0xFFEFF3FE),
  });

  @override
  Widget build(BuildContext context) {
    final confirmStyle = ElevatedButton.styleFrom(
      elevation: 0,
      backgroundColor: confirmColor,
      foregroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(vertical: 14),
    );
    final confirmLabel = Text(
      confirmText,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
    );
    void handleConfirm() {
      Navigator.of(context).pop();
      onConfirm();
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Row Header dengan Tombol Close (X)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFFEFF3FE),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Color(0xFF627396),
                    ),
                  ),
                ),
              ],
            ),
            
            // Icon Lingkaran Biru Muda
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: iconBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 32,
                color: iconColor,
              ),
            ),
            const SizedBox(height: 20),

            // Judul
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E293B),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),

            // Deskripsi / Pesan
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748B),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: const Color(0xFFF1F5F9),
                      foregroundColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      cancelText,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: confirmIcon == null
                      ? ElevatedButton(
                          onPressed: handleConfirm,
                          style: confirmStyle,
                          child: confirmLabel,
                        )
                      : ElevatedButton.icon(
                          onPressed: handleConfirm,
                          icon: Icon(confirmIcon, size: 18),
                          label: confirmLabel,
                          style: confirmStyle,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}