import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/shared/widgets/ms_icon.dart';

/// Halaman Notifikasi (dipakai bersama oleh User dan Admin).
///
/// Frontend only: menampilkan daftar notifikasi contoh dengan status
/// belum/baca. Menyediakan aksi "Tandai semua dibaca" dan menandai satu
/// notifikasi sebagai dibaca saat ditekan.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationData {
  _NotificationData({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.message,
    required this.time,
    required this.group,
    this.isUnread = true,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String message;
  final String time;
  final String group;
  bool isUnread;
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final List<_NotificationData> _items = [
    _NotificationData(
      icon: Symbols.check_circle,
      iconColor: const Color(0xFF006A48),
      iconBackground: const Color(0xFFD1FAE5),
      title: 'Peminjaman Disetujui',
      message:
          'Pengajuan Lab Komputer & RPL 1 disetujui oleh Pak Ahmad Fauzi. '
          'Silakan ambil QR-Pass peminjaman.',
      time: '10 menit lalu',
      group: 'Hari Ini',
    ),
    _NotificationData(
      icon: Symbols.schedule,
      iconColor: const Color(0xFFB45309),
      iconBackground: const Color(0xFFFFF1D6),
      title: 'Pengingat Pengembalian',
      message:
          'Sony Alpha A6400 + Kit jatuh tempo dikembalikan hari ini pukul '
          '15.30 WIB.',
      time: '1 jam lalu',
      group: 'Hari Ini',
    ),
    _NotificationData(
      icon: Symbols.cancel,
      iconColor: AppColors.error,
      iconBackground: AppColors.errorContainer,
      title: 'Peminjaman Ditolak',
      message:
          'Drawing Tablet Huion Kamvas 16 ditolak karena stok sedang tidak '
          'tersedia.',
      time: 'Kemarin, 16.20 WIB',
      group: 'Sebelumnya',
      isUnread: false,
    ),
    _NotificationData(
      icon: Symbols.send,
      iconColor: AppColors.primary,
      iconBackground: AppColors.primaryFixed,
      title: 'Reservasi Terkirim',
      message:
          'Formulir booking Anda berhasil dikirim dan sedang menunggu '
          'persetujuan petugas.',
      time: '2 hari lalu',
      group: 'Sebelumnya',
      isUnread: false,
    ),
    _NotificationData(
      icon: Symbols.inventory_2,
      iconColor: const Color(0xFF006A48),
      iconBackground: const Color(0xFFD1FAE5),
      title: 'Peminjaman Selesai',
      message:
          'Proyektor Epson EB-X500 telah dikembalikan. Terima kasih sudah '
          'tepat waktu.',
      time: '3 hari lalu',
      group: 'Sebelumnya',
      isUnread: false,
    ),
  ];

  int get _unreadCount => _items.where((n) => n.isUnread).length;

  void _markAllRead() {
    setState(() {
      for (final n in _items) {
        n.isUnread = false;
      }
    });
  }

  void _openNotification(_NotificationData n) {
    setState(() => n.isUnread = false);
  }

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<_NotificationData>>{};
    for (final n in _items) {
      groups.putIfAbsent(n.group, () => []).add(n);
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _items.isEmpty
                ? _buildEmpty()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.mobileGutter,
                      AppSpacing.md,
                      AppSpacing.mobileGutter,
                      AppSpacing.xl,
                    ),
                    children: [
                      for (final entry in groups.entries) ...[
                        _buildGroupLabel(entry.key),
                        const SizedBox(height: 10),
                        for (final n in entry.value) ...[
                          _buildCard(n),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 6),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
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
                icon: const MsIcon(Symbols.arrow_back,
                    size: 24, color: AppColors.onSurface),
              ),
              Expanded(
                child: Text(
                  'Notifikasi',
                  style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                      .copyWith(fontWeight: FontWeight.w700, fontSize: 18),
                ),
              ),
              TextButton(
                onPressed: _unreadCount == 0 ? null : _markAllRead,
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: Text(
                  'Tandai dibaca',
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w700,
                    color: _unreadCount == 0
                        ? AppColors.slate400
                        : AppColors.primary,
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

  Widget _buildGroupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        label,
        style: AppTextStyles.labelMd(
          weight: FontWeight.w700,
          color: AppColors.slate500,
        ),
      ),
    );
  }

  Widget _buildCard(_NotificationData n) {
    return Material(
      color: n.isUnread
          ? AppColors.primaryFixed.fade(0.35)
          : AppColors.surfaceContainerLowest,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _openNotification(n),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: n.isUnread
                  ? AppColors.primary.fade(0.25)
                  : AppColors.outlineVariant.fade(0.5),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildIconCircle(n),
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
                            n.title,
                            style: AppTextStyles.labelLg(
                              weight: FontWeight.w700,
                              color: AppColors.onSurface,
                            ),
                          ),
                        ),
                        if (n.isUnread)
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
                      n.message,
                      style: AppTextStyles.bodySm(
                        weight: FontWeight.w500,
                        color: AppColors.slate600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      n.time,
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

  Widget _buildIconCircle(_NotificationData n) {
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: n.iconBackground,
        shape: BoxShape.circle,
      ),
      child: MsIcon(n.icon, size: 22, color: n.iconColor),
    );
  }

  Widget _buildEmpty() {
    return Center(
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
            child: const MsIcon(Symbols.notifications,
                size: 34, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Tidak ada notifikasi',
            style: AppTextStyles.headlineSm(color: AppColors.onSurface),
          ),
          const SizedBox(height: 4),
          Text(
            'Semua pemberitahuan peminjaman akan muncul di sini.',
            style: AppTextStyles.bodySm(color: AppColors.slate600),
          ),
        ],
      ),
    );
  }

}
