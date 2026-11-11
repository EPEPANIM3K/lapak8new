import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_dimens.dart';
import '../../../core/constants/app_text_styles.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _rememberMe = false;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _onLogin() {
    final identifier = _identifierController.text.trim();
    final password = _passwordController.text.trim();

    if (identifier.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Silakan isi semua field')),
      );
      return;
    }

    // TODO: Implement actual login logic with backend
    // For now, navigate to admin dashboard as demo
    context.go('/admin');
  }

  @override
  Widget build(BuildContext context) {
    // Set system UI style untuk Android
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ));

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.mobileGutter,
                      vertical: AppSpacing.x2l,
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.md),
                          _buildHeader(),
                          const SizedBox(height: AppSpacing.xl),
                          _buildLoginCard(),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Header logo & teks sambutan
  Widget _buildHeader() {
    return Column(
          children: [
            // Logo icon box
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.base),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x0A000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.school_outlined,
                size: 32,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            // Welcome text
            Text(
              'LAPAK8 - Selamat Datang Kembali!',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineLg(color: AppColors.onSurface)
                  .copyWith(letterSpacing: -0.02 * 28),
            ),
          ],
    );
  }

  /// Login card dengan form fields
  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Identifier field
          _buildLabel('Nomor Induk / Email Sekolah'),
          const SizedBox(height: AppSpacing.xxs),
          _buildTextField(
            controller: _identifierController,
            icon: Icons.badge_outlined,
            placeholder: 'Contoh: 20241088 atau nama@sekolah.sch.id',
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: AppSpacing.md),

          // Password field
          _buildLabel('Kata Sandi'),
          const SizedBox(height: AppSpacing.xxs),
          _buildPasswordField(),
          const SizedBox(height: AppSpacing.lg),

          // Remember me & Forgot password
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _rememberMe = !_rememberMe),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: Checkbox(
                          value: _rememberMe,
                          onChanged: (v) =>
                              setState(() => _rememberMe = v ?? false),
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                          activeColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.outline,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Ingat Saya',
                        style: AppTextStyles.bodySm(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: Implement forgot password flow
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fitur lupa password akan segera hadir'),
                    ),
                  );
                },
                child: Text(
                  'Lupa Kata Sandi?',
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Login button
          SizedBox(
            height: AppSpacing.touchTargetMin,
            child: ElevatedButton(
              onPressed: _onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 3,
                shadowColor: AppColors.primary.fade(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                padding: EdgeInsets.zero,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Masuk Sekarang',
                    style: AppTextStyles.labelLg(
                      weight: FontWeight.w600,
                      color: AppColors.onPrimary,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  const Icon(Icons.arrow_forward, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Helper: Label widget
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: AppTextStyles.labelMd(
        weight: FontWeight.w600,
        color: AppColors.onSurface,
      ),
    );
  }

  /// Helper: Text input field
  Widget _buildTextField({
    required TextEditingController controller,
    required IconData icon,
    required String placeholder,
    TextInputType? keyboardType,
  }) {
    return Container(
      height: AppSpacing.touchTargetMin,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          Icon(icon, size: 20, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType ?? TextInputType.text,
              style: AppTextStyles.bodyMd(color: AppColors.onSurface),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: placeholder,
                hintStyle: AppTextStyles.bodyMd(
                  color: AppColors.outline.fade(0.7),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
    );
  }

  /// Helper: Password input field dengan visibility toggle
  Widget _buildPasswordField() {
    return Container(
      height: AppSpacing.touchTargetMin,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        children: [
          const SizedBox(width: AppSpacing.md),
          const Icon(Icons.lock_outline, size: 20, color: AppColors.secondary),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: AppTextStyles.bodyMd(color: AppColors.onSurface),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                hintText: 'Masukkan kata sandi akun',
                hintStyle: AppTextStyles.bodyMd(
                  color: AppColors.outline.fade(0.7),
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              setState(() => _obscurePassword = !_obscurePassword);
            },
            icon: Icon(
              _obscurePassword
                  ? Icons.visibility_outlined
                  : Icons.visibility_off_outlined,
              size: 20,
              color: AppColors.secondary,
            ),
            splashRadius: 20,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
          ),
          const SizedBox(width: AppSpacing.xxs),
        ],
      ),
    );
  }
}
