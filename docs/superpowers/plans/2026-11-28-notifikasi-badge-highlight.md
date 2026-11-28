# Notifikasi Badge + Highlight Otomatis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Menambahkan badge angka real-time dan highlight sementara untuk transaksi baru yang belum dilihat pada Admin Aktivitas dan User Pinjaman, tanpa halaman/popup baru.

**Architecture:** Trigger PostgreSQL membuat baris `notifications` saat status transaksi benar-benar berubah; Flutter membaca baris tersebut lewat Supabase Realtime, menghitung badge per user, lalu menandai dibaca hanya setelah transaksi terkait tampil pada tab aktif. Navbar existing diberi badge angka; card yang baru ditandai diberi warna lembut selama 4 detik.

**Tech Stack:** Flutter/Dart, Supabase Flutter (`supabase_flutter`), go_router, PostgreSQL/Supabase Realtime, flutter_test.

**Spec:** `docs/superpowers/specs/2026-11-28-notifikasi-badge-highlight-design.md`

## Global Constraints

- FCM/push notification **di luar iterasi ini**; jangan menambah dependency Firebase.
- Jangan menambah halaman notifikasi, popup, toast khusus, dialog, atau tombol "Tandai Semua Dibaca".
- Jangan mengubah layout navbar, ikon, spacing, warna dasar, atau navigasi utama.
- Badge: merah `AppColors.error`, tampil `99+` jika `count > 99`, disembunyikan jika `count <= 0`.
- Highlight: `AppColors.primaryFixed`, transisi 250ms, hilang setelah ~4 detik.
- Auto-read hanya untuk notifikasi yang transaksinya tampil pada tab aktif yang lolos filter/pencarian.
- Jika load gagal, jangan tandai dibaca dan jangan highlight.
- Penerima notifikasi harus memiliki `notifikasi_aktif = true`.
- RLS `public.notifications` bersifat owner-only; user tidak boleh melihat/mengubah notifikasi user lain.
- Satu kejadian transaksi menghasilkan paling banyak satu notifikasi per penerima.
- Jangan menghapus data notifikasi atau transaksi.
- Jangan mengubah alur peminjaman/pengembalian yang sudah berjalan.

## Review Focus

- **Trigger lama atau retry transaksi bisa membuat notifikasi dobel.** Task 1 memuat query pengecekan trigger/RPC lama dan verifikasi unique `(user_id, event_key)` + `ON CONFLICT DO NOTHING`.
- **Notifikasi bisa salah penerima (admin/staf vs peminjam, atau user lain).** Task 1 memuat query verifikasi recipient dan `notifikasi_aktif`; Task 2 memastikan controller hanya query `user_id = auth.uid()`.
- **Auto-read bisa terjadi sebelum card tampil atau saat load gagal.** Task 5 dan Task 6 memanggil auto-read hanya dari callback sukses + `addPostFrameCallback`; Task 2 menguji `selectUnreadTransactionIds` dengan daftar visible kosong/terbatas.
- **Badge bisa stale setelah mark read atau realtime event.** Task 2 menguji pemetaan ID notifikasi; Task 4 menghubungkan `AnimatedBuilder` ke controller; Task 7 verifikasi manual skenario realtime.
- **Filter/tab baru bisa menyingkap notifikasi lama yang belum dibaca.** Task 5 memanggil auto-read saat tab/filter/query berubah; Task 6 memanggilnya saat tab berubah; Task 2 menguji pemetaan dengan subset visible.

---

### Task 1: Migrasi database notifikasi

**Files:**
- Create: `database/migrasi_notifikasi_badge_highlight.sql`
- Include already-approved docs in commit: `docs/superpowers/specs/2026-11-28-notifikasi-badge-highlight-design.md`, `docs/superpowers/plans/2026-11-28-notifikasi-badge-highlight.md`

**Interfaces:**
- Produces: `public.notifications.event_key`, `uq_notifications_user_event_key`, `public.is_lapak8_admin_atau_staf()`, `public.tandai_notifikasi_dibaca(p_id UUID DEFAULT NULL, p_ids UUID[] DEFAULT NULL) RETURNS INTEGER`, trigger `trg_notif_peminjaman_baru`, `trg_notif_persetujuan_peminjaman`, `trg_notif_pengembalian_baru` pada `public.peminjaman`.

- [ ] **Step 1: Tulis migrasi SQL**

Buat file dengan objek berikut, semua idempoten:
  - `ALTER TABLE public.notifications ADD COLUMN IF NOT EXISTS event_key TEXT;`
  - `CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_user_event_key ON public.notifications (user_id, event_key);`
  - Function `public.is_lapak8_admin_atau_staf()` returning true hanya untuk `peran IN ('admin','staf')` dan `aktif = true`.
  - Function trigger `public.notif_peminjaman_baru()`, `public.notif_persetujuan_peminjaman()`, `public.notif_pengembalian_baru()` dengan payload persis sesuai spec: judul `Pengajuan Peminjaman Baru`, `Pengajuan Pengembalian Baru`, `Peminjaman Disetujui`; isi memakai `nama_lengkap` dan `nama_fasilitas_snapshot` pertama (fallback `nama_kegiatan`).
  - `event_key` persis: `pengajuan_peminjaman:<id>:<recipient_id>`, `pengajuan_pengembalian:<id>:<recipient_id>`, `persetujuan_peminjaman:<id>:<recipient_id>`.
  - Recipient: admin/staf aktif dan `notifikasi_aktif = true` untuk pengajuan; `peminjam_id` aktif dan `notifikasi_aktif = true` untuk persetujuan.
  - Update trigger hanya jika `OLD.status IS DISTINCT FROM NEW.status`.
  - Semua insert memakai `ON CONFLICT (user_id, event_key) DO NOTHING`.
  - RPC `tandai_notifikasi_dibaca` dengan `SECURITY DEFINER`, filter `user_id = auth.uid()`, return jumlah baris, revoke anon, grant authenticated.
  - RLS notifications owner-only; hapus policy admin `FOR ALL` lama.
  - Tambah `public.notifications` ke publication `supabase_realtime` bila belum ada.
  - Sertakan komentar query pengecekan trigger/RPC lama dari spec.

- [ ] **Step 2: Jalankan query pengecekan prasyarat**

Jalankan dua query dari spec di Supabase SQL Editor.

Expected: tidak ada trigger/RPC notifikasi lama. Jika ada, hentikan eksekusi dan hapus/ganti trigger lama sebelum lanjut.

- [ ] **Step 3: Jalankan migrasi dua kali**

Jalankan file migrasi dua kali berturut-turut di Supabase SQL Editor.

Expected: kedua eksekusi sukses tanpa error.

- [ ] **Step 4: Verifikasi data dasar**

Jalankan query yang membuktikan:
  - satu pengajuan pinjam menghasilkan satu baris per admin/staf aktif dengan `notifikasi_aktif = true`;
  - pengajuan yang sama tidak menambah baris saat dijalankan ulang;
  - persetujuan menghasilkan satu baris untuk peminjam dan nol untuk user lain;
  - penerima `notifikasi_aktif = false` tidak mendapat baris.

Expected: semua sesuai.

- [ ] **Step 5: Commit**

```bash
git add docs/superpowers/specs/2026-11-28-notifikasi-badge-highlight-design.md docs/superpowers/plans/2026-11-28-notifikasi-badge-highlight.md database/migrasi_notifikasi_badge_highlight.sql
git commit -m "feat: add notification trigger and read migration"
```

### Task 2: Model, helper, dan controller badge

**Files:**
- Create: `lib/features/notifications/models/notification_record.dart`
- Create: `lib/features/notifications/utils/badge_count.dart`
- Create: `lib/features/notifications/utils/notification_selection.dart`
- Create: `lib/features/notifications/controllers/notification_badge_controller.dart`
- Modify: `lib/main.dart:1-18`
- Test: `test/features/notifications/utils/notification_badge_test.dart`

**Interfaces:**
- Consumes: baris `public.notifications` dengan kolom `id`, `user_id`, `judul`, `isi`, `related_entity`, `related_id`, `sudah_dibaca`, `created_at`; `authProvider` singleton.
- Produces:
  - `class NotificationRecord { String id; String? relatedEntity; String? relatedId; String judul; String isi; DateTime? createdAt; bool sudahDibaca; factory NotificationRecord.fromMap(Map<String, dynamic> map); }`
  - `String formatBadgeCount(int count)`
  - `List<String> selectUnreadTransactionIds({required Iterable<NotificationRecord> records, required String entity, required Iterable<String> visibleTransactionIds})`
  - `List<String> selectNotificationIds({required Iterable<NotificationRecord> records, required String entity, required Iterable<String> transactionIds})`
  - `class NotificationBadgeController extends ChangeNotifier` dengan `int get unreadCount`, `List<NotificationRecord> get unreadRecords`, `void bind(String? userId)`, `Future<void> refresh()`, `Future<void> markRead(Iterable<String> notificationIds)`, `List<String> unreadRelatedIds(String entity)`, `List<String> notificationIdsFor(String entity, Iterable<String> transactionIds)`.
  - `final notificationBadgeController = NotificationBadgeController();`

- [ ] **Step 1: Tulis test yang gagal**

Buat `test/features/notifications/utils/notification_badge_test.dart` dengan test:
  - `formatBadgeCount(0) == '0'`, `formatBadgeCount(3) == '3'`, `formatBadgeCount(99) == '99'`, `formatBadgeCount(100) == '99+'`.
  - `selectUnreadTransactionIds` hanya mengembalikan `relatedId` unik untuk entity yang sama dan ada di `visibleTransactionIds`; `relatedId == null`, `sudahDibaca == true`, entity lain, dan id di luar visible tidak ikut.
  - `selectNotificationIds` mengembalikan semua ID notifikasi untuk transaksi yang diberikan, termasuk dua notifikasi dengan `relatedId` sama, dan tidak mengembalikan notifikasi entity lain.

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Run: `flutter test test/features/notifications/utils/notification_badge_test.dart`

Expected: FAIL karena file belum ada.

- [ ] **Step 3: Implementasi model dan helper**

Buat `NotificationRecord.fromMap` dengan konversi aman untuk `sudah_dibaca` (bool atau int) dan `created_at` nullable. Buat helper di atas tanpa efek samping.

- [ ] **Step 4: Implementasi controller**

`bind(userId)` membatalkan subscription lama, reset state, lalu `refresh()` dan subscribe ke stream `notifications` filtered by `user_id`. `refresh()` mengisi `unreadRecords` hanya untuk `sudah_dibaca != true`. `markRead` memanggil RPC `tandai_notifikasi_dibaca` dengan `p_ids`, lalu menghapus state lokal hanya setelah sukses. `unreadRelatedIds` dan `notificationIdsFor` mendelegasikan ke helper.

- [ ] **Step 5: Bind controller di startup**

Di `lib/main.dart`, setelah `await authProvider.init()`, tambahkan listener `authProvider` yang memanggil `notificationBadgeController.bind(authProvider.user?.id)` dan panggil sekali untuk user saat ini. Import controller.

- [ ] **Step 6: Jalankan test dan analyze**

Run: `flutter test test/features/notifications/utils/notification_badge_test.dart && flutter analyze`

Expected: PASS dan `No issues found!`.

- [ ] **Step 7: Commit**

```bash
git add lib/features/notifications lib/main.dart test/features/notifications
git commit -m "feat: add notification badge controller"
```

### Task 3: Badge angka pada navbar

**Files:**
- Modify: `lib/shared/widgets/app_bottom_nav.dart:13-25,154-165,211-230`
- Test: `test/shared/widgets/app_bottom_nav_badge_test.dart`

**Interfaces:**
- Consumes: `formatBadgeCount`.
- Produces: `AppBottomNavItem.badgeCount` (menggantikan `showBadge`), `AdminBottomNav.aktivitasBadgeCount`.

- [ ] **Step 1: Tulis widget test yang gagal**

Test:
  - `AppBottomNav` dengan item `badgeCount: 3`, `useRouter: false` menampilkan teks `3`.
  - item dengan `badgeCount: 100` menampilkan `99+`.
  - item dengan `badgeCount: 0` tidak menampilkan teks `0` dan tidak ada badge.

- [ ] **Step 2: Jalankan test untuk memastikan gagal**

Run: `flutter test test/shared/widgets/app_bottom_nav_badge_test.dart`

Expected: FAIL karena `badgeCount` belum ada.

- [ ] **Step 3: Implementasi badge**

Ganti `showBadge` dengan `int badgeCount = 0`. Pada `_NavItem`, ganti dot 8×8 dengan pill `Positioned(top: 4, right: 10)`, background `AppColors.error`, radius 999, teks putih bold 10px, minimum 18×18, shadow ring `AppColors.surfaceContainerLowest`. Tambah `aktivitasBadgeCount` pada `AdminBottomNav` dan terapkan ke item index 1.

- [ ] **Step 4: Jalankan test**

Run: `flutter test test/shared/widgets/app_bottom_nav_badge_test.dart`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/shared/widgets/app_bottom_nav.dart test/shared/widgets/app_bottom_nav_badge_test.dart
git commit -m "feat: render numeric nav badge"
```

### Task 4: Hubungkan badge ke shell

**Files:**
- Modify: `lib/shared/widgets/user_app_shell.dart:1-70`
- Modify: `lib/features/admin/admin_shell.dart:1-87`

**Interfaces:**
- Consumes: `notificationBadgeController`, `AppBottomNavItem.badgeCount`, `AdminBottomNav.aktivitasBadgeCount`.
- Produces: badge pada route `'/borrowings'` dan `'/admin/borrowings'` mengikuti `notificationBadgeController.unreadCount`.

- [ ] **Step 1: Update UserAppShell**

Import `notification_badge_controller.dart`. Bungkus `AppBottomNav` dengan `AnimatedBuilder(animation: notificationBadgeController, ...)`. Buat salinan `AppBottomNav.userItems` dan set `badgeCount` pada item route `'/borrowings'` dari `notificationBadgeController.unreadCount`. Jangan mengubah item lain.

- [ ] **Step 2: Update AdminShell**

Import `notification_badge_controller.dart`. Bungkus `AdminBottomNav` dengan `AnimatedBuilder(animation: notificationBadgeController, ...)`, meneruskan `aktivitasBadgeCount: notificationBadgeController.unreadCount`.

- [ ] **Step 3: Verifikasi**

Run: `flutter analyze`

Expected: `No issues found!`. Pastikan tidak ada perubahan pada header, padding, atau currentIndex.

- [ ] **Step 4: Commit**

```bash
git add lib/shared/widgets/user_app_shell.dart lib/features/admin/admin_shell.dart
git commit -m "feat: wire unread badge into shells"
```

### Task 5: Highlight dan auto-read Admin Aktivitas

**Files:**
- Modify: `lib/features/admin/screens/admin_borrowings_screen.dart:187-299,425-453,831,955-956,1002,1022,1379-1405,1681-1703`

**Interfaces:**
- Consumes: `notificationBadgeController.unreadRelatedIds`, `notificationBadgeController.notificationIdsFor`, `notificationBadgeController.markRead`, `AppColors.primaryFixed`, `AppColors.surfaceContainerLowest`.
- Produces: `_highlightedBorrowingIds`, `Future<void> _consumeVisibleUnreadNotifications()`, `highlight` pada `_LoanCard` dan `_ReturnCard`.

- [ ] **Step 1: Tambah state highlight**

Tambah `final Set<String> _highlightedBorrowingIds = {};`, `Timer? _highlightTimer;`, import `dart:async`, dan `dispose()` yang membatalkan timer bila ada.

- [ ] **Step 2: Tambah method auto-read**

Buat `Future<void> _consumeVisibleUnreadNotifications() async`:
  - pilih entity `pengajuan_peminjaman` bila `_isLoanTab`, else `pengajuan_pengembalian`;
  - visible ids dari `_visibleLoans` atau `_visibleReturns` (`borrowingId`);
  - `transactionIds = controller.unreadRelatedIds(entity).where((id) => visibleIds.contains(id))`;
  - jika kosong, return;
  - `notificationIds = controller.notificationIdsFor(entity, transactionIds)`;
  - `setState` menambah `transactionIds` ke `_highlightedBorrowingIds`;
  - panggil `await controller.markRead(notificationIds)`;
  - restart timer 4 detik yang menghapus `transactionIds` dari set dan `setState`.

- [ ] **Step 3: Panggil setelah data/filter tampil**

Panggil `unawaited(_consumeVisibleUnreadNotifications())` dalam `addPostFrameCallback` setelah:
  - `_performLoadLoans` sukses;
  - perubahan `_query` (`onChanged`);
  - perubahan tab di `_tabBtn`;
  - perubahan `_loanFilter` dan `_returnFilter`.

Jangan panggil dari cabang error.

- [ ] **Step 4: Terapkan highlight ke card**

Tambah `required this.highlight` ke `_LoanCard` dan `_ReturnCard`. Ganti outer `Container` dengan `AnimatedContainer(duration: 250ms, color: highlight ? AppColors.primaryFixed : AppColors.surfaceContainerLowest)`; padding, radius, shadow, dan child tetap sama. Teruskan `highlight: _highlightedBorrowingIds.contains(l.borrowingId)` / `(r.borrowingId)` saat memanggil card.

- [ ] **Step 5: Verifikasi**

Run: `flutter analyze` dan `flutter test`.

Expected: `No issues found!` dan semua test lulus. Verifikasi manual: setelah load sukses badge turun hanya untuk transaksi pada tab aktif yang lolos filter; highlight hilang setelah ~4 detik; load gagal tidak mengubah badge.

- [ ] **Step 6: Commit**

```bash
git add lib/features/admin/screens/admin_borrowings_screen.dart
git commit -m "feat: auto-read and highlight admin activity"
```

### Task 6: Highlight dan auto-read User Pinjaman

**Files:**
- Modify: `lib/features/borrowings/screens/my_borrowings_screen.dart:38-96,467-520,582-592,649,1250-1267`

**Interfaces:**
- Consumes: `notificationBadgeController.unreadRelatedIds`, `notificationBadgeController.notificationIdsFor`, `notificationBadgeController.markRead`.
- Produces: `_highlightedBorrowingIds`, `Future<void> _consumeVisibleUnreadNotifications()`, `highlight` pada `_cardAktif` dan `_cardWrapper`.

- [ ] **Step 1: Tambah state highlight**

Tambah `final Set<String> _highlightedBorrowingIds = {};`, `Timer? _highlightTimer;`, import `dart:async`, dan `dispose()` yang membatalkan timer.

- [ ] **Step 2: Tambah method auto-read**

Buat `Future<void> _consumeVisibleUnreadNotifications() async`:
  - return bila `_tab != 'aktif'` atau `_loading` atau `_errorMessage != null`;
  - `visibleIds` dari `activeItems` (`p.id`);
  - `transactionIds = controller.unreadRelatedIds('persetujuan_peminjaman').where((id) => visibleIds.contains(id))`;
  - jika kosong, return;
  - `notificationIds = controller.notificationIdsFor('persetujuan_peminjaman', transactionIds)`;
  - highlight + `markRead` + timer 4 detik seperti Task 5.

- [ ] **Step 3: Panggil setelah data/tab tampil**

Panggil `unawaited(_consumeVisibleUnreadNotifications())` dalam `addPostFrameCallback` setelah `_load()` sukses dan setelah `_switchTab('aktif')`. Jangan panggil dari cabang error.

- [ ] **Step 4: Terapkan highlight tanpa mengubah layout**

Tambah `bool highlighted = false` pada `_cardAktif` dan `_cardWrapper`. Gunakan `AnimatedContainer` dengan warna `highlighted ? AppColors.primaryFixed : cSurfaceLowest` dan mempertahankan padding/radius/shadow yang sama. Teruskan `highlighted: _highlightedBorrowingIds.contains(p.id)` hanya dari `_buildCard` untuk status aktif.

- [ ] **Step 5: Verifikasi**

Run: `flutter analyze` dan `flutter test`.

Expected: `No issues found!` dan semua test lulus. Verifikasi manual: badge sesuai jumlah persetujuan; membuka tab Aktif menampilkan highlight ~4 detik dan badge hilang; tab Menunggu/Riwayat tidak menandai dibaca; restart tidak mengulang highlight.

- [ ] **Step 6: Commit**

```bash
git add lib/features/borrowings/screens/my_borrowings_screen.dart
git commit -m "feat: auto-read and highlight approved loans"
```

### Task 7: Verifikasi akhir

**Files:**
- Tidak ada file baru.

**Interfaces:**
- Consumes: semua task sebelumnya.

- [ ] **Step 1: Jalankan verifikasi otomatis**

Run: `flutter analyze && flutter test`

Expected: `No issues found!` dan seluruh test lulus (minimal 15 test lama + test baru).

- [ ] **Step 2: Verifikasi skenario realtime manual**

Lakukan di dua perangkat/akun:
  - User mengajukan pinjam → badge Admin bertambah tanpa refresh.
  - Admin membuka Aktivitas tab Peminjaman → card highlight, badge turun.
  - User mengajukan kembali → badge Admin bertambah; tab Pengembalian → highlight, badge turun.
  - Admin menyetujui 2 transaksi → badge User menunjukkan 2; User membuka tab Aktif → kedua card highlight, badge hilang.
  - User lain tidak menerima notifikasi persetujuan tersebut.
  - Matikan `notifikasi_aktif` → tidak ada notifikasi baru.
  - Restart aplikasi → highlight tidak muncul ulang.

Expected: semua sesuai spec.

- [ ] **Step 3: Commit bila ada perbaikan kecil**

```bash
git add -A
git commit -m "fix: notification verification adjustments"
```

Expected: hanya dijalankan bila verifikasi menemukan perbaikan.
