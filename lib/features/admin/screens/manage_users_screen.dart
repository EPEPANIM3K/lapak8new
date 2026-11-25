import 'dart:async';

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';

import 'package:lapak8new/core/constants/app_colors.dart';
import 'package:lapak8new/core/constants/app_dimens.dart';
import 'package:lapak8new/core/constants/app_text_styles.dart';
import 'package:lapak8new/features/admin/screens/user_form_screen.dart';
import 'package:lapak8new/features/admin/services/user_repository.dart';
import 'package:lapak8new/shared/widgets/app_bottom_nav.dart';
import 'package:lapak8new/shared/widgets/confirm_dialog.dart';

enum _UserFilter { all, student, teacher, suspended }

<<<<<<< HEAD
class _User {
  const _User({
    required this.name,
    required this.role,
    required this.idLabel,
    required this.loanCount,
  }) : className = null, email = null, subtitle = null, suspended = false, onTimeText = null, lateCount = null, warning = null, previousLoans = false, phone = null, avatarUrl = null;

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

=======
>>>>>>> c4d3b6adf1f29467316add0189fb5d57a0cafedd
class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  static const _pageSize = 10;

  _UserFilter _filter = _UserFilter.all;
  String _query = '';
  int _page = 1;
  int _requestId = 0;
  List<AppUser> _users = const [];
  UserStats _stats = const UserStats(students: 0, staff: 0, suspended: 0);
  int _total = 0;
  bool _loading = true;
  String? _error;
  Timer? _searchTimer;

  int get _totalPages => _total == 0 ? 1 : (_total / _pageSize).ceil();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final requestId = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        userRepository.fetchUsers(
          query: _query,
          page: _page - 1,
          pageSize: _pageSize,
          role: _filter == _UserFilter.student ? 'student' : null,
          roles: _filter == _UserFilter.teacher ? ['teacher', 'staff'] : null,
          suspended: _filter == _UserFilter.suspended ? true : null,
        ),
        userRepository.fetchStats(),
      ]);
      if (!mounted || requestId != _requestId) return;
      final page = results[0] as UserPage;
      setState(() {
        _users = page.items;
        _total = page.total;
        _stats = results[1] as UserStats;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  void _search(String value) {
    _searchTimer?.cancel();
    _query = value;
    _page = 1;
    _searchTimer = Timer(const Duration(milliseconds: 350), _load);
  }

  void _selectFilter(_UserFilter filter) {
    setState(() {
      _filter = filter;
      _page = 1;
    });
    _load();
  }

  Future<void> _createAccount() async {
    final data = await UserFormScreen.show(context, isAdmin: true);
    if (data == null || !mounted) return;
    try {
      await userRepository.createAccount(
        nama: data.name,
        email: data.email,
        password: data.password,
        role: data.role,
        kelas: data.roleClass,
        nisn: data.idNumber,
        nomorTelepon: data.phone,
        active: data.active,
      );
      if (!mounted) return;
      _showMessage('Akun berhasil dibuat.');
      await _load();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  Future<void> _editAccount(AppUser user) async {
    final data = await UserFormScreen.show(
      context,
      isAdmin: true,
      initial: UserFormData(
        name: user.nama,
        password: '',
        email: user.email,
        idNumber: user.nisn ?? '',
        roleClass: user.kelas,
        role: user.role,
        active: user.isActive,
        phone: user.nomorTelepon ?? '',
      ),
    );
    if (data == null || !mounted) return;

    try {
      await userRepository.updateUser(
        user.id,
        nama: data.name,
        phone: data.phone,
        kelas: data.roleClass,
        nisn: data.idNumber,
        role: data.role,
        active: data.active,
      );
      if (data.email != user.email) {
        await userRepository.updateEmail(user.id, data.email);
      }
      if (data.password.isNotEmpty) {
        await userRepository.resetPassword(user.id, data.password);
      }
      if (!mounted) return;
      _showMessage('Perubahan akun berhasil disimpan.');
      await _load();
    } catch (error) {
      if (!mounted) return;
      _showMessage('Tidak semua perubahan tersimpan: $error', isError: true);
      await _load();
    }
  }

  Future<void> _reactivate(AppUser user) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.lock_open,
        title: 'Buka Suspend Akun?',
        message: 'Akun ${user.nama} akan dapat digunakan kembali.',
        confirmText: 'Buka Akses',
        confirmIcon: Symbols.key,
        onConfirm: () => _setActive(user, true),
      ),
    );
  }

  Future<void> _confirmSuspend(AppUser user) async {
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => ConfirmDialog(
        icon: Symbols.lock,
        title: 'Tangguhkan Akun?',
        message: 'Akun ${user.nama} tidak dapat digunakan sampai diaktifkan '
            'kembali oleh admin.',
        confirmText: 'Tangguhkan',
        confirmIcon: Symbols.lock,
        confirmColor: AppColors.error,
        iconColor: AppColors.error,
        iconBackground: AppColors.errorContainer,
        onConfirm: () => _setActive(user, false),
      ),
    );
  }

  Future<void> _setActive(AppUser user, bool active) async {
    try {
      await userRepository.setActive(user.id, active);
      if (!mounted) return;
      _showMessage(active ? 'Akun diaktifkan kembali.' : 'Akun ditangguhkan.');
      await _load();
    } catch (error) {
      if (mounted) _showMessage(error.toString(), isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: isError ? AppColors.error : null,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceContainerLow,
      bottomNavigationBar: const AdminBottomNav(currentIndex: 4),
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
                Text(
                  'Kelola Pengguna',
                  style: AppTextStyles.headlineMd(color: AppColors.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  'Kelola akun siswa, guru, dan staf',
                  style: AppTextStyles.bodyMd(color: AppColors.slate600),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _createAccount,
              icon: const Icon(Symbols.add_circle, size: 22),
              label: Text(
                'Tambah Akun Baru',
                style: AppTextStyles.labelLg(
                  weight: FontWeight.w700,
                  color: AppColors.onPrimary,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                elevation: 0,
                shape: const StadiumBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Siswa Terdaftar',
                  value: '${_stats.students}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Guru & Staf',
                  value: '${_stats.staff}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Akun Ditangguhkan',
                  value: '${_stats.suspended}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _StatCard(
                  label: 'Total Pengguna',
                  value: '${_stats.students + _stats.staff}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SearchField(onChanged: _search),
          const SizedBox(height: 16),
          _buildFilterChips(),
          const SizedBox(height: 16),
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Text(
                    'Gagal memuat data: $_error',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMd(color: AppColors.error),
                  ),
                  const SizedBox(height: 12),
                  TextButton.icon(
                    onPressed: _load,
                    icon: const Icon(Symbols.refresh),
                    label: const Text('Coba lagi'),
                  ),
                ],
              ),
            )
          else if (_users.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'Tidak ada data pengguna',
                  style: AppTextStyles.bodyMd(color: AppColors.slate500),
                ),
              ),
            )
          else
            for (final user in _users) ...[
              _UserCard(
                user: user,
                onManage: () => _editAccount(user),
                onReactivate: () => _reactivate(user),
                onSuspend: () => _confirmSuspend(user),
              ),
              const SizedBox(height: 16),
            ],
          const SizedBox(height: 4),
          _Pagination(
            page: _page,
            totalPages: _totalPages,
            onChanged: (page) {
              setState(() => _page = page);
              _load();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    final filters = <(String, _UserFilter)>[
      ('Semua ($_total)', _UserFilter.all),
      ('Siswa (${_stats.students})', _UserFilter.student),
      ('Guru & Staf (${_stats.staff})', _UserFilter.teacher),
      ('Ditangguhkan (${_stats.suspended})', _UserFilter.suspended),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, value) = filters[index];
          final selected = _filter == value;
          return GestureDetector(
            onTap: () => _selectFilter(value),
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
                  color:
                      selected ? AppColors.onPrimary : AppColors.onSurface,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

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
          hintText: 'Cari nama, email, NISN / NIP, atau kelas...',
          hintStyle: AppTextStyles.bodyMd(color: AppColors.slate500),
          prefixIcon: const Icon(Symbols.search, color: AppColors.slate600),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.onManage,
    required this.onReactivate,
    required this.onSuspend,
  });

  final AppUser user;
  final VoidCallback onManage;
  final VoidCallback onReactivate;
  final VoidCallback onSuspend;

  String get _initials {
    final words = user.nama.trim().split(RegExp(r'\s+'));
    return words.take(2).map((word) => word[0]).join().toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final roleLabel = switch (user.role) {
      'student' => 'Siswa',
      'teacher' => 'Guru',
      'staff' => 'Staf',
      _ => user.role,
    };
    final idLabel = user.role == 'student' ? 'NISN' : 'NIP';

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
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryFixed,
                child: Text(
                  _initials,
                  style: AppTextStyles.labelLg(
                    weight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nama,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.headlineSm(
                        color: AppColors.onSurface,
                      ).copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySm(color: AppColors.slate600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Pill(label: roleLabel),
              if (user.kelas != null && user.kelas!.isNotEmpty)
                _Pill(label: user.kelas!),
              _Pill(label: '$idLabel: ${user.nisn ?? '-'}'),
              _Pill(label: user.isActive ? 'Aktif' : 'Ditangguhkan'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Kelola Akun',
                  icon: Symbols.manage_accounts,
                  onPressed: onManage,
                ),
              ),
              const SizedBox(width: 8),
              if (!user.isActive)
                Expanded(
                  child: _ActionButton(
                    label: 'Buka Suspend',
                    icon: Symbols.lock_open,
                    onPressed: onReactivate,
                  ),
                )
              else
                IconButton(
                  tooltip: 'Tangguhkan akun',
                  onPressed: onSuspend,
                  icon: const Icon(
                    Symbols.lock,
                    color: AppColors.error,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryFixed,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: AppTextStyles.labelSm(
          weight: FontWeight.w700,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
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
            weight: FontWeight.w700,
            color: AppColors.primary,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryFixed,
          foregroundColor: AppColors.primary,
          elevation: 0,
          shape: const StadiumBorder(),
        ),
      ),
    );
  }
}

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
    final firstPage = totalPages <= 5
        ? 1
        : (page - 2).clamp(1, totalPages - 4).toInt();
    final visiblePages = List<int>.generate(
      totalPages < 5 ? totalPages : 5,
      (index) {
        return firstPage + index;
      },
    );

    Widget pageButton(int value) => GestureDetector(
          onTap: value == page ? null : () => onChanged(value),
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: value == page
                  ? AppColors.primary
                  : AppColors.surfaceContainerLowest,
              shape: BoxShape.circle,
              boxShadow: value == page ? null : AppShadows.sm,
            ),
            child: Text(
              '$value',
              style: AppTextStyles.labelMd(
                weight: FontWeight.w700,
                color: value == page
                    ? AppColors.onPrimary
                    : AppColors.onSurface,
              ),
            ),
          ),
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: page > 1 ? () => onChanged(page - 1) : null,
          icon: const Icon(Symbols.chevron_left),
        ),
        for (final value in visiblePages) ...[
          pageButton(value),
          const SizedBox(width: 8),
        ],
        IconButton(
          onPressed: page < totalPages ? () => onChanged(page + 1) : null,
          icon: const Icon(Symbols.chevron_right),
        ),
      ],
    );
  }
}
