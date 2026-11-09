import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';
import 'package:lapak8new/features/admin/screens/user_form_screen.dart';

// Simpan di: lib/features/admin/screens/manage_users_screen.dart

enum _Role { student, teacher }

enum _UserFilter { all, student, teacher, suspended }

class _User {
  const _User({
    required this.name,
    required this.role,
    required this.idLabel,
    required this.loanCount,
    this.className,
    this.email,
    this.subtitle,
    this.suspended = false,
    this.onTimeText,
    this.lateCount,
    this.warning,
    this.previousLoans = false,
    this.phone,
    this.avatarUrl,
  });

  final String name;
  final _Role role;
  final String idLabel; // "NISN: ..." / "NIP: ..."
  final int loanCount;
  final String? className; // chip kelas (siswa)
  final String? email;
  final String? subtitle; // mis. "Guru Kejuruan RPL"
  final bool suspended;
  final String? onTimeText; // "100% Tepat Waktu"
  final int? lateCount; // "1× Terlambat"
  final String? warning; // baris peringatan merah
  final bool previousLoans; // "3× Pinjam Sebelumnya"
  final String? phone;
  final String? avatarUrl;

  bool get isTeacher => role == _Role.teacher;

  /// Data awal untuk form "Kelola Akun Pengguna".
  UserFormData toFormData() => UserFormData(
        name: name,
        password: '', // kosong = tidak diubah
        email: email ?? '',
        idNumber: idLabel.replaceFirst(RegExp(r'^(NISN|NIP):\s*'), ''),
        roleClass: className ?? subtitle,
        active: !suspended,
        phone: phone ?? '',
      );

  String get initials {
    final parts =
        name.replaceAll(RegExp(r'^(Ibu|Bapak|Drs\.)\s'), '').trim().split(' ');
    final a = parts.first.isNotEmpty ? parts.first[0] : '';
    final b = parts.length > 1 && parts[1].isNotEmpty ? parts[1][0] : '';
    return (a + b).toUpperCase();
  }
}

// Warna yang belum ada di AppColors.
const _greenBg = Color(0xFFD1FAE5);
const _greenFg = Color(0xFF065F46);
const _onlineDot = Color(0xFF34D399);

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  _UserFilter _filter = _UserFilter.all;
  String _query = '';
  int _page = 1;

  // TODO: ganti dengan data dari backend.
  static const List<_User> _users = [
    _User(
      name: 'Nabila Az-Zahra',
      role: _Role.student,
      className: 'XI MM 2',
      email: 'nabila.azzahra@smkn8malang.sch',
      idLabel: 'NISN: 0068194021',
      phone: '082345671827391',
      loanCount: 14,
      onTimeText: '100% Tepat Waktu',
    ),
    _User(
      name: 'Dimas Arya Pratama',
      role: _Role.student,
      className: 'XII RPL 1',
      email: 'dimas.arya@smkn8malang.sch.id',
      idLabel: 'NISN: 0074128954',
      phone: '081234567890',
      loanCount: 22,
      lateCount: 1,
    ),
    _User(
      name: 'Ibu Ratna Dewi, S.Pd',
      role: _Role.teacher,
      subtitle: 'Guru Kejuruan RPL',
      idLabel: 'NIP: 198204152008012011',
      phone: '081298765432',
      loanCount: 22,
    ),
    _User(
      name: 'Fajar Kurniawan',
      role: _Role.student,
      className: 'X TKJ 3',
      idLabel: 'NISN: 0071983321',
      phone: '085712345678',
      loanCount: 3,
      suspended: true,
      warning: '2× Terlambat > 3 Hari',
      previousLoans: true,
    ),
  ];

  // TODO: ambil dari backend.
  static const _stats = (
    students: 840,
    teachers: 48,
    review: 12,
    compliance: '98.4%',
  );

  int get _total => _stats.students + _stats.teachers;

  List<_User> get _visible {
    final q = _query.trim().toLowerCase();
    return _users.where((u) {
      switch (_filter) {
        case _UserFilter.all:
          break;
        case _UserFilter.student:
          if (u.role != _Role.student) return false;
        case _UserFilter.teacher:
          if (u.role != _Role.teacher) return false;
        case _UserFilter.suspended:
          if (!u.suspended) return false;
      }
      if (q.isEmpty) return true;
      return u.name.toLowerCase().contains(q) ||
          u.idLabel.toLowerCase().contains(q) ||
          (u.className ?? '').toLowerCase().contains(q) ||
          (u.email ?? '').toLowerCase().contains(q);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final users = _visible;
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.mobileGutter,
          AppSpacing.md,
          AppSpacing.mobileGutter,
          AppSpacing.md,
        ),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Data Peminjaman',
                    style: AppTextStyles.headlineMd(
                        color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(
                  'Kelola Akun Pengguna',
                  style: AppTextStyles.bodyMd(color: AppColors.slate600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _AddAccountButton(
            onPressed: () async {
              final data = await UserFormScreen.show(context);
              if (data != null) {
                // TODO: kirim data akun baru ke backend
              }
            },
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                    label: 'Siswa Terdaftar',
                    value: '${_stats.students}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                    label: 'Guru & Staf', value: '${_stats.teachers}'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                    label: 'Perlu Tinjauan', value: '${_stats.review}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                    label: 'Rerata Kepatuhan',
                    value: _stats.compliance),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SearchField(onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 16),
          _buildFilterChips(),
          const SizedBox(height: 16),
          if (users.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Tidak ada data pengguna',
                  style: AppTextStyles.bodyMd(color: AppColors.slate500),
                ),
              ),
            ),
          for (final u in users) ...[
            _UserCard(
              user: u,
              onManage: () async {
                final data = await UserFormScreen.show(
                  context,
                  initial: u.toFormData(),
                );
                if (data != null) {
                  // TODO: kirim perubahan akun ke backend
                }
              },
              onUnsuspend: () {
                showDialog(
                  context: context,
                  barrierColor: Colors.black54,
                  builder: (_) => ConfirmDialog(
                    icon: Symbols.lock_open,
                    title: 'Buka Suspend Akun?',
                    message: 'Akses peminjaman sarpras untuk akun '
                        'siswa ini akan diaktifkan kembali secara '
                        'normal dan status sanksi keterlambatan akan '
                        'direset.',
                    confirmText: 'Buka Akses',
                    confirmIcon: Symbols.key,
                    onConfirm: () {
                      // TODO: panggil backend untuk buka suspend + reset sanksi
                    },
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            ],
          const SizedBox(height: 4),
          _Pagination(
            page: _page,
            totalPages: 3,
            onChanged: (p) => setState(() => _page = p),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = <(String, _UserFilter)>[
      ('Semua ($_total)', _UserFilter.all),
      ('Siswa (${_stats.students})', _UserFilter.student),
      ('Guru & Staf (${_stats.teachers})', _UserFilter.teacher),
      ('Ditangguhkan', _UserFilter.suspended),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (label, value) = filters[i];
          final selected = _filter == value;
          return GestureDetector(
            onTap: () => setState(() => _filter = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(AppRadius.full),
                boxShadow: selected ? null : AppShadows.sm,
              ),
              child: Text(
                label,
                style: AppTextStyles.labelMd(
                  weight: FontWeight.w700,
                  color: selected ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tombol "Tambah Akun Baru"
// ---------------------------------------------------------------------------
class _AddAccountButton extends StatelessWidget {
  const _AddAccountButton({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Symbols.add_circle, size: 22),
        label: Text(
          'Tambah Akun Baru',
          style: AppTextStyles.labelLg(
              weight: FontWeight.w700, color: AppColors.onPrimary),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu statistik
// ---------------------------------------------------------------------------
class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.bodySm(
              weight: FontWeight.w500,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: AppTextStyles.headlineMd(color: AppColors.onSurface)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kolom pencarian
// ---------------------------------------------------------------------------
class _SearchField extends StatelessWidget {
  const _SearchField({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(AppRadius.full),
        boxShadow: AppShadows.sm,
      ),
      child: TextField(
        onChanged: onChanged,
        style: AppTextStyles.bodyMd(color: AppColors.onSurface),
        decoration: InputDecoration(
          hintText: 'Cari nama siswa, NISN, atau kelas...',
          hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
          prefixIcon: const Icon(Symbols.search, color: AppColors.slate600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chip kecil (kelas / status)
// ---------------------------------------------------------------------------
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.background,
    required this.foreground,
    this.dot = false,
  });

  final String label;
  final Color background;
  final Color foreground;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration:
                  BoxDecoration(color: foreground, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: AppTextStyles.labelSm(
                weight: FontWeight.w700, color: foreground),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Kartu pengguna
// ---------------------------------------------------------------------------
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onManage,
    required this.onUnsuspend,
  });

  final _User user;
  final VoidCallback onManage;
  final VoidCallback onUnsuspend;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppShadows.sm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          const SizedBox(height: 12),
          _buildStatsBar(),
          const SizedBox(height: 12),
          if (user.suspended)
            _ActionButton(
              label: 'Buka Suspend',
              icon: Symbols.lock_open,
              background: AppColors.errorContainer,
              foreground: AppColors.error,
              onPressed: onUnsuspend,
            )
          else
            _ActionButton(
              label: 'Kelola Akun',
              icon: Symbols.manage_accounts,
              background: AppColors.primaryFixed,
              foreground: AppColors.primary,
              onPressed: onManage,
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final showOnline = user.role == _Role.student && !user.suspended;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primaryFixed,
              shape: BoxShape.circle,
              image: user.avatarUrl == null
                  ? null
                  : DecorationImage(
                      image: NetworkImage(user.avatarUrl!),
                      fit: BoxFit.cover,
                    ),
            ),
            child: user.avatarUrl == null
                ? Text(
                    user.initials,
                    style: AppTextStyles.headlineSm(color: AppColors.primary)
                        .copyWith(fontSize: 16, fontWeight: FontWeight.w700),
                  )
                : null,
          ),
          if (showOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: _onlineDot,
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AppColors.surfaceContainerLowest, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAvatar(),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 6,
                runSpacing: 4,
                children: [
                  Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.headlineSm(color: AppColors.onSurface)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (user.className != null)
                    _Pill(
                      label: user.className!,
                      background: AppColors.primaryFixed,
                      foreground: AppColors.primary,
                    ),
                ],
              ),
              if (user.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  user.subtitle!,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: AppColors.slate600,
                  ),
                ),
              ],
              if (user.email != null) ...[
                const SizedBox(height: 2),
                Text(
                  user.email!,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodySm(
                    weight: FontWeight.w500,
                    color: AppColors.slate600,
                  ),
                ),
              ],
              const SizedBox(height: 2),
              Text(
                user.idLabel,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySm(
                  weight: FontWeight.w700,
                  color: AppColors.slate600,
                ),
              ),
              if (user.warning != null) ...[
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Symbols.warning,
                        size: 14, color: AppColors.error),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        user.warning!,
                        overflow: TextOverflow.ellipsis,
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
          ),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (user.isTeacher) ...[
              const _Pill(
                label: 'Pengajar',
                background: _greenBg,
                foreground: _greenFg,
              ),
              const SizedBox(height: 4),
            ],
            if (user.suspended)
              const _Pill(
                label: 'Ditangguhkan',
                background: AppColors.errorContainer,
                foreground: AppColors.error,
              )
            else
              _Pill(
                label: 'Aktif',
                background: AppColors.surfaceContainerLow,
                foreground: AppColors.onSurface,
                dot: true,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsBar() {
    final loanLabel =
        user.previousLoans ? '${user.loanCount}× Pinjam Sebelumnya' : '${user.loanCount}× Pinjam';

    Widget? right;
    if (user.suspended) {
      right = Text(
        'Akses Dibekukan',
        style: AppTextStyles.labelSm(
          weight: FontWeight.w700,
          color: AppColors.error,
        ),
      );
    } else if (user.onTimeText != null) {
      right = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.verified_user, size: 16, color: _greenFg),
          const SizedBox(width: 4),
          Text(
            user.onTimeText!,
            style: AppTextStyles.labelSm(
              weight: FontWeight.w700,
              color: _greenFg,
            ),
          ),
        ],
      );
    } else if (user.lateCount != null) {
      right = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Symbols.schedule, size: 16, color: AppColors.slate600),
          const SizedBox(width: 4),
          Text(
            '${user.lateCount}× Terlambat',
            style: AppTextStyles.labelSm(
              weight: FontWeight.w700,
              color: AppColors.slate600,
            ),
          ),
        ],
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.base),
      ),
      child: Row(
        children: [
          Icon(
            user.previousLoans ? Symbols.history : Symbols.sync_alt,
            size: 16,
            color: user.previousLoans ? AppColors.slate600 : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              loanLabel,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelSm(
                weight: FontWeight.w700,
                color: AppColors.onSurface,
              ),
            ),
          ),
          if (right != null) right,
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 40,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          style: AppTextStyles.labelMd(
              weight: FontWeight.w700, color: foreground),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pagination
// ---------------------------------------------------------------------------
class _Pagination extends StatelessWidget {
  const _Pagination({
    required this.page,
    required this.totalPages,
    required this.onChanged,
  });

  final int page;
  final int totalPages;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final canPrev = page > 1;
    final canNext = page < totalPages;

    Widget circle(Widget child, {required bool selected, VoidCallback? onTap}) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary
                : AppColors.surfaceContainerLowest,
            shape: BoxShape.circle,
            boxShadow: selected ? null : AppShadows.sm,
          ),
          child: child,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        circle(
          Icon(Symbols.chevron_left,
              color: canPrev ? AppColors.onSurface : AppColors.slate500),
          selected: false,
          onTap: canPrev ? () => onChanged(page - 1) : null,
        ),
        const SizedBox(width: 8),
        for (var p = 1; p <= totalPages; p++) ...[
          circle(
            Text(
              '$p',
              style: AppTextStyles.labelLg(
                weight: FontWeight.w700,
                color: p == page ? AppColors.onPrimary : AppColors.onSurface,
              ),
            ),
            selected: p == page,
            onTap: () => onChanged(p),
          ),
          const SizedBox(width: 8),
        ],
        GestureDetector(
          onTap: canNext ? () => onChanged(page + 1) : null,
          child: Container(
            height: 44,
            padding: const EdgeInsets.only(left: 16, right: 10),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(AppRadius.full),
              boxShadow: AppShadows.sm,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Next',
                  style: AppTextStyles.labelMd(
                    weight: FontWeight.w700,
                    color: canNext ? AppColors.primary : AppColors.slate500,
                  ),
                ),
                Icon(Symbols.chevron_right,
                    size: 20,
                    color: canNext ? AppColors.primary : AppColors.slate500),
              ],
            ),
          ),
        ),
      ],
    );
  }
}