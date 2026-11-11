import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/shared/widgets/ms_icon.dart';

/// Modal "Ubah Kata Sandi" untuk admin.
///
/// Frontend only: memvalidasi input (wajib diisi, konfirmasi cocok) dan
/// menampilkan notifikasi. Tidak mengubah autentikasi/password backend.
class AdminChangePasswordSheet extends StatefulWidget {
  const AdminChangePasswordSheet({super.key});

  @override
  State<AdminChangePasswordSheet> createState() =>
      _AdminChangePasswordSheetState();
}

class _AdminChangePasswordSheetState extends State<AdminChangePasswordSheet> {
  final _oldCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _submitted = false;

  @override
  void dispose() {
    _oldCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  String? get _oldError {
    if (!_submitted && _oldCtrl.text.isEmpty) return null;
    if (_oldCtrl.text.isEmpty) return 'Kata sandi lama wajib diisi.';
    return null;
  }

  String? get _newError {
    if (!_submitted && _newCtrl.text.isEmpty) return null;
    if (_newCtrl.text.isEmpty) return 'Kata sandi baru wajib diisi.';
    if (_newCtrl.text.length < 6) return 'Minimal 6 karakter.';
    return null;
  }

  String? get _confirmError {
    if (!_submitted && _confirmCtrl.text.isEmpty) return null;
    if (_confirmCtrl.text.isEmpty) return 'Konfirmasi kata sandi wajib diisi.';
    if (_newCtrl.text.isNotEmpty && _confirmCtrl.text != _newCtrl.text) {
      return 'Kata sandi tidak cocok.';
    }
    return null;
  }

  bool get _canSave =>
      _oldCtrl.text.isNotEmpty &&
      _newCtrl.text.length >= 6 &&
      _confirmCtrl.text == _newCtrl.text;

  void _save() {
    setState(() => _submitted = true);
    if (!_canSave) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.primary,
        content: Text(
          'Kata sandi berhasil diperbarui.',
          style: AppTextStyles.bodySm(
            weight: FontWeight.w600,
            color: AppColors.onPrimary,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      backgroundColor: AppColors.surfaceContainerLowest,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 40),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ubah Kata Sandi',
                        style: AppTextStyles.headlineSm(
                          color: AppColors.onSurface,
                        ).copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pastikan kata sandi baru kuat dan mudah diingat.',
                        style: AppTextStyles.bodySm(
                          color: AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
                _CloseButton(onTap: () => Navigator.of(context).pop()),
              ],
            ),
            const SizedBox(height: 20),
            _PasswordField(
              label: 'Kata Sandi Lama',
              controller: _oldCtrl,
              obscure: _obscureOld,
              errorText: _oldError,
              onChanged: (_) => setState(() {}),
              onToggle: () => setState(() => _obscureOld = !_obscureOld),
            ),
            const SizedBox(height: 16),
            _PasswordField(
              label: 'Kata Sandi Baru',
              controller: _newCtrl,
              obscure: _obscureNew,
              errorText: _newError,
              onChanged: (_) => setState(() {}),
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 16),
            _PasswordField(
              label: 'Konfirmasi Kata Sandi Baru',
              controller: _confirmCtrl,
              obscure: _obscureConfirm,
              errorText: _confirmError,
              onChanged: (_) => setState(() {}),
              onToggle: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _canSave ? _save : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  disabledBackgroundColor: AppColors.primaryFixed.fade(0.5),
                  foregroundColor: AppColors.onPrimary,
                  disabledForegroundColor: AppColors.slate500,
                  elevation: 0,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Simpan Perubahan',
                  style: AppTextStyles.labelLg(
                    weight: FontWeight.w700,
                    color: _canSave ? AppColors.onPrimary : AppColors.slate500,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.slate600,
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  'Batal',
                  style: AppTextStyles.labelLg(
                    weight: FontWeight.w600,
                    color: AppColors.slate600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLow,
          shape: BoxShape.circle,
        ),
        child: const MsIcon(Symbols.close, size: 18, color: AppColors.slate600),
      ),
    );
  }
}

class _PasswordField extends StatelessWidget {
  const _PasswordField({
    required this.label,
    required this.controller,
    required this.obscure,
    required this.onToggle,
    required this.onChanged,
    this.errorText,
  });

  final String label;
  final TextEditingController controller;
  final bool obscure;
  final VoidCallback onToggle;
  final ValueChanged<String> onChanged;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final hasError = errorText != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTextStyles.labelMd(
            weight: FontWeight.w700,
            color: AppColors.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscure,
          onChanged: onChanged,
          style: AppTextStyles.bodyMd(
            weight: FontWeight.w500,
            color: AppColors.onSurface,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: AppColors.surfaceContainerLow,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : Colors.transparent,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppRadius.base),
              borderSide: BorderSide(
                color: hasError ? AppColors.error : Colors.transparent,
              ),
            ),
            prefixIcon: const MsIcon(
              Symbols.lock,
              size: 20,
              color: AppColors.slate500,
            ),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: MsIcon(
                obscure ? Symbols.visibility_off : Symbols.visibility,
                size: 20,
                color: AppColors.slate500,
              ),
            ),
            hintText: '••••••••',
            hintStyle: AppTextStyles.bodyMd(color: AppColors.outlineVariant),
          ),
        ),
        if (hasError) ...[
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MsIcon(Symbols.error, size: 14, color: AppColors.error),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  errorText!,
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w600,
                    color: AppColors.error,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

