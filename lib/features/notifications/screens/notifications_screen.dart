import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/shared/widgets/ms_icon.dart';

/// Halaman Notifikasi (dipakai bersama oleh User dan Admin).
///
/// Membaca tabel `notifications` milik pengguna yang sedang login secara
/// realtime. Notifikasi dibuat oleh trigger di database (migrasi_notifikasi.sql).
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final SupabaseClient _client = Supabase.instance.client;
  late Stream<List<Map<String, dynamic>>> _stream = _buatStream();

  String? get _uid => _client.auth.currentUser?.id;

  Stream<List<Map<String, dynamic>>> _buatStream() {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', uid)
        .order('created_at', ascending: false)
        .limit(50);
  }

  void _muatUlang() => setState(() => _stream = _buatStream());

  Future<void> _tandai(String? id) async {
    try {
      await _client.rpc('tandai_notifikasi_dibaca', params: {'p_id': id});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gagal memperbarui notifikasi. Coba lagi.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  DateTime _waktuDari(Map<String, dynamic> n) {
    final raw = n['created_at'];
    return (raw is String ? DateTime.tryParse(raw) : null)?.toLocal() ??
        DateTime.now();
  }

  String _labelWaktu(DateTime t) {
    final selisih = DateTime.now().difference(t);
    if (selisih.inMinutes < 1) return 'Baru saja';
    if (selisih.inMinutes < 60) return '${selisih.inMinutes} menit lalu';
    if (selisih.inHours < 24) return '${selisih.inHours} jam lalu';
    if (selisih.inDays == 1) return 'Kemarin';
    if (selisih.inDays < 7) return '${selisih.inDays} hari lalu';
    return '${t.day.toString().padLeft(2, '0')}/'
        '${t.month.toString().padLeft(2, '0')}/${t.year}';
  }

  ({IconData icon, Color color, Color bg}) _gaya(String jenis) {
    switch (jenis) {
      case 'success':
        return (
          icon: Symbols.check_circle,
          color: const Color(0xFF006A48),
          bg: const Color(0xFFD1FAE5),
        );
      case 'warning':
        return (
          icon: Symbols.schedule,
          color: const Color(0xFFB45309),
          bg: const Color(0xFFFFF1D6),
        );
      case 'error':
        return (
          icon: Symbols.cancel,
          color: AppColors.error,
          bg: AppColors.errorContainer,
        );
      default:
        return (
          icon: Symbols.notifications,
          color: AppColors.primary,
          bg: AppColors.primaryFixed,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          final items = snapshot.data ?? const <Map<String, dynamic>>[];
          final unread = items.where((n) => n['sudah_dibaca'] != true).length;

          final Widget content;
          if (_uid == null) {
            content = _buildInfo(
              icon: Symbols.lock,
              title: 'Belum masuk',
              message: 'Silakan masuk untuk melihat notifikasi.',
            );
          } else if (snapshot.hasError) {
            content = _buildInfo(
              icon: Symbols.cloud_off,
              title: 'Gagal memuat notifikasi',
              message: 'Periksa koneksi internet lalu coba lagi.',
              actionLabel: 'Coba lagi',
              onAction: _muatUlang,
            );
          } else if (!snapshot.hasData) {
            content = const Center(child: CircularProgressIndicator());
          } else if (items.isEmpty) {
            content = _buildInfo(
              icon: Symbols.notifications,
              title: 'Tidak ada notifikasi',
              message: 'Semua pemberitahuan peminjaman akan muncul di sini.',
            );
          } else {
            content = _buildList(items);
          }

          return Column(
            children: [
              _buildHeader(unread),
              Expanded(child: content),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(int unread) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        boxShadow: AppShadows.sm,
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              IconButton(
                onPressed: () => Navigator.maybePop(context),
                icon: const MsIcon(
                  Symbols.arrow_back,
                  size: 24,
                  color: AppColors.onSurface,
                ),
              ),
              Expanded(
                child: Text(
                  'Notifikasi',
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              TextButton(
                onPressed: unread == 0 ? null : () => _tandai(null),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'Tandai dibaca',
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w700,
                    color: unread == 0 ? AppColors.slate400 : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildList(List<Map<String, dynamic>> items) {
    final sekarang = DateTime.now();
    final hariIni = <Map<String, dynamic>>[];
    final sebelumnya = <Map<String, dynamic>>[];
    for (final n in items) {
      final t = _waktuDari(n);
      final sama = t.year == sekarang.year &&
          t.month == sekarang.month &&
          t.day == sekarang.day;
      (sama ? hariIni : sebelumnya).add(n);
    }

    Widget bagian(String label, List<Map<String, dynamic>> daftar) {
      if (daftar.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              label,
              style: AppTextStyles.labelMd(
                weight: FontWeight.w700,
                color: AppColors.slate500,
              ),
            ),
          ),
          const SizedBox(height: 10),
          for (final n in daftar) ...[
            _buildCard(n),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 6),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.mobileGutter,
        AppSpacing.md,
        AppSpacing.mobileGutter,
        AppSpacing.xl,
      ),
      children: [
        bagian('Hari Ini', hariIni),
        bagian('Sebelumnya', sebelumnya),
      ],
    );
  }

  Widget _buildCard(Map<String, dynamic> n) {
    final unread = n['sudah_dibaca'] != true;
    final gaya = _gaya((n['jenis'] as String?) ?? 'info');
    final judul = (n['judul'] as String?) ?? '';
    final isi = (n['isi'] as String?) ?? '';
    final id = n['id'] as String?;

    return Material(
      color: unread
          ? AppColors.primaryFixed.fade(0.35)
          : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: unread && id != null ? () => _tandai(id) : null,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: unread
                  ? AppColors.primary.fade(0.25)
                  : AppColors.outlineVariant.fade(0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: gaya.bg,
                  shape: BoxShape.circle,
                ),
                child: MsIcon(gaya.icon, size: 22, color: gaya.color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            judul,
                            style: AppTextStyles.labelLg(
                              weight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (unread)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 4, left: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isi,
                      style: AppTextStyles.bodySm(
                        weight: FontWeight.w500,
                        color: AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _labelWaktu(_waktuDari(n)),
                      style: AppTextStyles.bodySm(
                        weight: FontWeight.w500,
                        color: AppColors.slate400,
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

  Widget _buildInfo({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.primaryFixed,
                shape: BoxShape.circle,
              ),
              child: MsIcon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSm(color: AppColors.onSurface),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySm(color: AppColors.slate600),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              TextButton(onPressed: onAction, child: Text(actionLabel)),
            ],
          ],
        ),
      ),
    );
  }
}