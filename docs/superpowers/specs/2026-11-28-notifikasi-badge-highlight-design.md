# Notifikasi Badge + Highlight Otomatis LAPAK8 — Design

> Status: menunggu persetujuan human partner  
> Tanggal: 2026-11-28

## Intent

LAPAK8 perlu menandai transaksi baru yang belum dilihat tanpa menambah halaman, popup, daftar notifikasi, atau tombol "Tandai Semua Dibaca". Notifikasi hanya berupa badge angka pada navbar yang sudah ada, lalu highlight sementara pada card transaksi setelah halaman tujuan berhasil menampilkan transaksi tersebut. Badge harus real-time via Supabase Realtime, tersimpan di database, dan otomatis berkurang saat notifikasi ditandai dibaca.

FCM/push notification **di luar iterasi ini**. Iterasi ini hanya mencakup badge, auto-read, dan highlight. Tidak ada dependency Firebase yang ditambahkan.

## Goals

- Admin melihat badge angka pada menu **Aktivitas** untuk pengajuan peminjaman dan pengembalian baru.
- User melihat badge angka pada menu **Pinjaman** untuk peminjaman yang baru disetujui.
- Badge menghitung notifikasi `sudah_dibaca = false` milik user yang sedang login, maksimal tampil `99+`.
- Saat halaman tujuan berhasil memuat dan card transaksi terkait benar-benar tampil:
  - card tersebut mendapat highlight lembut sekitar 4 detik;
  - notifikasi terkait otomatis ditandai dibaca;
  - badge berkurang/hilang.
- Jika halaman gagal memuat, tidak ada notifikasi yang ditandai dibaca.
- Notifikasi dibuat oleh database saat perubahan status transaksi berhasil disimpan, bukan oleh Flutter.
- Tidak ada notifikasi duplikat untuk satu kejadian transaksi per penerima.
- Tidak ada perubahan pada layout navbar, warna dasar, ikon, spacing, atau alur peminjaman/pengembalian yang sudah berjalan.

## Non-goals

- Tidak menambah halaman notifikasi, popup, toast khusus, dialog, atau tombol baru.
- Tidak mengubah desain card secara permanen.
- Tidak menambahkan FCM, firebase_core, firebase_messaging, atau flutter_local_notifications.
- Tidak menghapus data notifikasi atau transaksi.
- Tidak mengizinkan user membuat/mengubah notifikasi secara bebas dari client.
- Tidak mengubah `SystemChrome`, safe-area, atau perilaku navigasi utama.

## Anti-goals

- Notifikasi statis/dummy.
- Badge yang hanya berasal dari jumlah transaksi pending tanpa status baca tersimpan.
- Menandai semua notifikasi dibaca hanya karena badge ditekan.
- Menandai notifikasi dibaca sebelum card transaksinya tampil.
- Memberi highlight pada transaksi lama yang bukan notifikasi belum dibaca.

## Constraints

- Supabase adalah source of truth. Tabel `public.notifications` sudah ada di `databasefix.sql:255-265`.
- Kolom yang dipakai: `id`, `user_id`, `judul`, `isi`, `jenis`, `related_entity`, `related_id`, `sudah_dibaca`, `created_at`.
- Status admin di aplikasi adalah `admin` dan `staf` (`AppUser.isAdminAtauStaf`, `auth_provider.dart:30`). Helper DB lama `is_lapak8_admin()` hanya mengenali `admin`, jadi migrasi baru tidak boleh bergantung padanya untuk penerima staf.
- Rute admin `'/admin/borrowings'` menampilkan tab Peminjaman dan Pengembalian dalam satu halaman.
- Rute user `'/borrowings'` menampilkan tab Aktif, Menunggu, dan Riwayat; hasil persetujuan admin berada pada tab Aktif (`StatusPeminjaman.disetujui`).
- Navbar memakai `AppBottomNavItem` (`app_bottom_nav.dart:13-25`) dan saat ini hanya punya `showBadge` boolean yang tidak pernah dipakai.
- Shell sudah membungkus halaman utama; badge harus dihubungkan ke shell, bukan ke setiap card.
- Tidak ada package state management tambahan; gunakan `ChangeNotifier`/`AnimatedBuilder` seperti pola `authProvider`.

## Approaches

### 1. Trigger database + Realtime + auto-read saat render — dipilih

Notifikasi dibuat oleh trigger PostgreSQL pada transisi status yang berhasil. Flutter hanya membaca, menampilkan badge, dan menandai dibaca setelah card tampil.

Kelebihan: validasi backend, tidak bisa dipalsukan client, transaksi dan notifikasi konsisten, mudah dicegah duplikat dengan unique key.

Kekurangan: perlu migrasi SQL dan hati-hati pada transisi status.

### 2. Insert notifikasi dari Flutter setelah RPC sukses — ditolak

Lebih sedikit SQL, tetapi client bisa dimanipulasi dan retry jaringan bisa membuat duplikat. Bertentangan dengan syarat validasi backend.

### 3. Polling count — ditolak

Lebih sederhana, tetapi tidak real-time dan meminta Supabase Realtime secara eksplisit.

### 4. Memakai `riwayat_kejadian` sebagai sumber notifikasi — ditolak

Tidak punya recipient, status baca, atau scope per user; perlu tabel baru lagi.

## Design

### A. Database migration

File baru: `database/migrasi_notifikasi_badge_highlight.sql`.

1. Tambah kolom `event_key TEXT` pada `public.notifications` jika belum ada.
2. Buat unique index:
   - `UNIQUE (user_id, event_key)` dengan nama `uq_notifications_user_event_key`.
   - Index partial unread yang sudah ada dipertahankan.
3. Buat/`CREATE OR REPLACE` function helper:
   - `public.is_lapak8_admin_atau_staf()` mengembalikan true hanya bila `auth.uid()` memiliki `peran IN ('admin','staf')` dan `aktif = true`.
4. Helper internal `public._notifikasi_transaksi(...)` atau minimal tiga function trigger kecil:
   - `public.notif_peminjaman_baru()` AFTER INSERT ON `public.peminjaman`.
   - `public.notif_persetujuan_peminjaman()` AFTER UPDATE OF `status` ON `public.peminjaman`.
   - `public.notif_pengembalian_baru()` AFTER UPDATE OF `status` ON `public.peminjaman`.
5. Recipient dan payload:

| Event | Pemicu | Recipient | `related_entity` | Judul | Isi |
|---|---|---|---|---|---|
| Pengajuan peminjaman baru | INSERT `peminjaman.status = 'menunggu_persetujuan'` | semua `pengguna.aktif` dengan `peran IN ('admin','staf')` **dan `notifikasi_aktif = true`** | `pengajuan_peminjaman` | `Pengajuan Peminjaman Baru` | `[Nama User] mengajukan peminjaman [Nama Barang].` |
| Pengajuan pengembalian baru | UPDATE `status` dari `dipinjam`/`terlambat` ke `menunggu_pengembalian` | semua `pengguna.aktif` dengan `peran IN ('admin','staf')` **dan `notifikasi_aktif = true`** | `pengajuan_pengembalian` | `Pengajuan Pengembalian Baru` | `[Nama User] mengajukan pengembalian [Nama Barang].` |
| Persetujuan peminjaman | UPDATE `status` dari `menunggu_persetujuan` ke `disetujui` | `peminjam_id` dengan `aktif = true` **dan `notifikasi_aktif = true`** | `persetujuan_peminjaman` | `Peminjaman Disetujui` | `Peminjaman [Nama Barang] kamu telah disetujui admin.` |

6. Sumber nama:
   - `[Nama User]` dari `public.pengguna.nama_lengkap` pada `peminjam_id`.
   - `[Nama Barang]` dari `item_peminjaman.nama_fasilitas_snapshot` pertama; jika tidak ada, `peminjaman.nama_kegiatan`.
7. `jenis` memakai nilai existing:
   - `warning` untuk pengajuan baru;
   - `success` untuk persetujuan.
   - Jenis transaksi dibedakan melalui `related_entity`, bukan dengan mengubah CHECK constraint `jenis`.
8. `event_key`:
   - `pengajuan_peminjaman:<peminjaman_id>:<recipient_id>`
   - `pengajuan_pengembalian:<peminjaman_id>:<recipient_id>`
   - `persetujuan_peminjaman:<peminjaman_id>:<recipient_id>`
9. Semua insert memakai `ON CONFLICT (user_id, event_key) DO NOTHING`.
10. Trigger hanya memproses transisi nyata: `TG_OP = 'UPDATE'` harus memenuhi `OLD.status IS DISTINCT FROM NEW.status`.
11. RPC `public.tandai_notifikasi_dibaca(p_id UUID DEFAULT NULL, p_ids UUID[] DEFAULT NULL) RETURNS INTEGER`:
   - `SECURITY DEFINER`, `SET search_path = pg_catalog, public, pg_temp`.
   - Hanya mengubah baris dengan `user_id = auth.uid()`.
   - Jika `p_ids` diisi, batasi `id = ANY(p_ids)`.
   - Jika `p_id` diisi, batasi `id = p_id`.
   - Jika keduanya null, tandai semua notifikasi milik caller (kompatibel dengan `notifications_screen.dart` yang sudah ada, walaupun halaman itu tidak dipakai dalam iterasi ini).
   - Return jumlah baris yang berubah.
   - `REVOKE ALL ... FROM public, anon`, `GRANT EXECUTE ... TO authenticated`.
12. Perbaiki RLS `notifications` menjadi **owner-only**: `user_id = auth.uid()` untuk SELECT. Tidak ada policy yang memberi admin/staf hak melihat notifikasi user lain. Notifikasi admin/staf juga disimpan dengan `user_id` masing-masing, sehingga mereka tetap melihat notifikasi yang ditujukan kepada mereka. Policy admin `FOR ALL` lama dihapus supaya tidak membuka akses lintas user.
13. Tambahkan `public.notifications` ke `supabase_realtime` publication bila belum terdaftar, dengan blok `DO` idempoten.

Migration harus idempoten dan aman dijalankan ulang. Karena kondisi produksi belum dipastikan, dokumen/migrasi harus menyertakan query pengecekan berikut sebelum eksekusi:

```sql
SELECT tgname, pg_get_triggerdef(oid)
FROM pg_trigger
WHERE tgrelid = 'public.peminjaman'::regclass
  AND NOT tgisinternal;

SELECT proname
FROM pg_proc
WHERE pronamespace = 'public'::regnamespace
  AND proname ILIKE '%notif%';
```

Jika ternyata ada trigger/RPC notifikasi lama, hentikan dan hapus/ganti trigger lama tersebut sebelum menjalankan trigger baru. Trigger baru memakai nama unik dan `DROP TRIGGER IF EXISTS` hanya untuk nama yang dibuat oleh migrasi ini.

### B. Flutter badge controller

File baru: `lib/features/notifications/controllers/notification_badge_controller.dart`.

`NotificationBadgeController extends ChangeNotifier` dengan state:

- `int _unreadCount`, getter `unreadCount`.
- `List<_NotificationRecord> _unread`, getter `unreadRecords`.
- `String? _userId`.
- `StreamSubscription<List<Map<String, dynamic>>>? _subscription`.

Interface publik:

```dart
void bind(String? userId);
Future<void> refresh();
Future<void> markRead(Iterable<String> notificationIds);
List<String> unreadRelatedIds(String entity);
List<String> notificationIdsFor(String entity, Iterable<String> transactionIds);
```

Perilaku:

- `bind(userId)`:
  - jika sama dengan user sebelumnya, return;
  - cancel subscription lama;
  - reset count dan daftar ke kosong;
  - jika userId null, notify dan selesai;
  - jika tidak null, jalankan `refresh()` lalu subscribe ke:
    `Supabase.instance.client.from('notifications').stream(primaryKey: ['id']).eq('user_id', userId)`.
- `refresh()` mengambil baris `id, related_entity, related_id, sudah_dibaca` untuk `user_id`, diurutkan `created_at` descending; count dan daftar hanya untuk `sudah_dibaca != true`.
- Event Realtime memanggil `refresh()` (bukan inkreman manual) agar count selalu cocok dengan database.
- `unreadRelatedIds(entity)` mengembalikan **ID transaksi** (`related_id`) unik dari notifikasi belum dibaca untuk entity tersebut.
- `notificationIdsFor(entity, transactionIds)` mengembalikan **ID notifikasi** yang `related_entity = entity` dan `related_id` ada dalam daftar transaksi yang benar-benar tampil. Jika beberapa notifikasi menunjuk transaksi sama, semua ID notifikasinya ikut ditandai dibaca.
- `markRead(notificationIds)`:
  - return jika kosong;
  - panggil RPC `tandai_notifikasi_dibaca` dengan `p_ids: notificationIds.toList()`;
  - hapus id tersebut dari state lokal dan `notifyListeners()` hanya setelah RPC sukses;
  - jika RPC gagal, biarkan state dan badge apa adanya.
- Global singleton `final notificationBadgeController = NotificationBadgeController();`.

File baru `lib/features/notifications/models/notification_record.dart` berisi model immutable dengan field `id`, `relatedEntity`, `relatedId`, `judul`, `isi`, `sudahDibaca`, `createdAt`.

File baru `lib/features/notifications/utils/badge_count.dart`:

```dart
String formatBadgeCount(int count) => count > 99 ? '99+' : '$count';
```

Tidak ada dependency baru.

### C. Navbar badge

Ubah `lib/shared/widgets/app_bottom_nav.dart`:

- `AppBottomNavItem` mendapat `int badgeCount = 0`.
- `_NavItem` mengganti dot boolean dengan pill angka:
  - hidden jika `badgeCount <= 0`;
  - teks `formatBadgeCount(badgeCount)`;
  - warna merah `AppColors.error` (atau konstanta merah existing terdekat);
  - `Positioned(top: 4, right: 10)`, tidak mengubah posisi ikon/label;
  - ukuran minimal 18×18, borderRadius 999, teks putih 10px bold.
- `showBadge` boolean lama dihapus karena tidak dipakai di manapun.
- `AppBottomNav.userItems` dan `dashboardItems` tetap `static`, tetapi shell membuat salinan dengan `badgeCount` dinamis.
- `AdminBottomNav` menerima `int aktivitasBadgeCount = 0` dan diteruskan ke item Aktivitas.

### D. Shell wiring

- `lib/shared/widgets/user_app_shell.dart`:
  - bungkus `AppBottomNav` dengan `AnimatedBuilder(animation: notificationBadgeController, ...)`.
  - salin `AppBottomNav.userItems`, set `badgeCount` hanya pada route `'/borrowings'` dari `notificationBadgeController.unreadCount`.
  - panggil `notificationBadgeController.bind(authProvider.user?.id)` pada `initState` dan saat user berubah (bisa via listener `authProvider` atau `didChangeDependencies`; implementer memilih yang paling sederhana dan konsisten).
- `lib/features/admin/admin_shell.dart`:
  - hal yang sama untuk `'/admin/borrowings'` via `AdminBottomNav(aktivitasBadgeCount: ...)`.
  - bind user id yang sama.
- Tidak ada perubahan pada `LapakHeader`, `AppBottomNav.totalHeight`, atau route definitions.

### E. Highlight + auto-read

Definisi "ditampilkan" yang disetujui: **semua transaksi pada tab aktif yang lolos filter/pencarian saat ini**, tanpa perlu di-scroll ke card tersebut. Tidak perlu tracking viewport. Jika filter diubah sehingga transaksi unread tidak lagi lolos, transaksi itu belum dianggap ditampilkan dan notifikasinya tetap belum dibaca.

#### Admin — `lib/features/admin/screens/admin_borrowings_screen.dart`

- Tambah state `Set<String> _highlightedBorrowingIds` berisi id transaksi yang baru saja ditampilkan dan masih dalam masa highlight.
- Setelah `_performLoadLoans` berhasil dan `setState` data selesai, jadwalkan `addPostFrameCallback`:
  - tentukan entity sesuai tab aktif:
    - `_isLoanTab` → `pengajuan_peminjaman`;
    - sebaliknya → `pengajuan_pengembalian`;
  - ambil `unreadRelatedIds(entity)` dari controller;
  - filter hanya id transaksi yang benar-benar ada di daftar yang sedang dirender (`_visibleLoans` atau `_visibleReturns`);
  - ubah ke ID notifikasi dengan `notificationIdsFor(entity, renderedTransactionIds)`;
  - jika ada:
    - simpan id transaksi ke `_highlightedBorrowingIds`;
    - panggil `notificationBadgeController.markRead(notificationIds)`;
    - jadwalkan timer ~4 detik untuk menghapus id highlight dan `setState`.
- Jika load gagal, jangan panggil markRead dan jangan highlight.
- `_LoanCard` dan `_ReturnCard` menerima flag `highlight`. Gunakan `AnimatedContainer` dengan `color`:
  - normal: `AppColors.surfaceContainerLowest`;
  - highlight: `AppColors.primaryFixed`;
  - durasi transisi ~250ms; tidak mengubah padding, radius, shadow, atau child.
- Kartu untuk transaksi lama tidak masuk set highlight karena tidak punya notifikasi unread terkait.

#### User — `lib/features/borrowings/screens/my_borrowings_screen.dart`

- Tambah state `Set<String> _highlightedBorrowingIds`.
- Setelah `_loadData()` berhasil dan tab aktif adalah `'aktif'`, jadwalkan `addPostFrameCallback`:
  - ambil `unreadRelatedIds('persetujuan_peminjaman')`;
  - filter hanya id transaksi yang ada di `activeItems` dan benar-benar dirender;
  - ubah ke ID notifikasi dengan `notificationIdsFor(...)`;
  - highlight + `markRead` + timer ~4 detik seperti admin.
- Jika tab aktif bukan `'aktif'`, jangan tandai dibaca; tunggu sampai tab Aktif ditampilkan.
- Jika load gagal, jangan tandai dibaca.
- `_buildCard(Peminjaman p)`/`_cardAktif` membungkus card dengan `AnimatedContainer` atau mewarisi warna highlight tanpa mengubah layout.

### F. Keamanan dan akurasi

- User hanya bisa membaca notifikasi `user_id = auth.uid()` melalui RLS dan query controller.
- Hanya RPC `SECURITY DEFINER` yang dapat mengubah `sudah_dibaca`; client tidak diberi policy UPDATE langsung.
- Trigger berjalan di database setelah status transaksi berhasil diubah. Jika transaksi gagal/gagal commit, trigger tidak menghasilkan notifikasi.
- Unique `(user_id, event_key)` mencegah duplikat.
- Admin menerima pengajuan pinjam/pengembalian; user hanya menerima persetujuan miliknya.
- Tidak ada notifikasi yang dihapus.

## Decisions already made by human partner

- FCM/push tidak dikerjakan pada iterasi ini.
- Tidak ada halaman notifikasi, popup, atau tombol "Tandai Semua Dibaca".
- Badge angka pada navbar existing saja.
- Highlight 3–5 detik; implementasi memilih ~4 detik.
- Auto-read terjadi setelah halaman berhasil memuat dan transaksi terkait ditampilkan.
- Perubahan seminimal mungkin; fitur pinjam/kembali/auth tidak diubah.
- Auto-read mencakup semua transaksi di tab aktif yang lolos filter/pencarian saat ini, tanpa tracking viewport.
- Toggle `notifikasi_aktif` ikut mengontrol badge in-app.
- Kondisi trigger lama di produksi belum dipastikan; migrasi wajib menyertakan query pengecekan dan bersifat idempoten.

## Builder calls

- `jenis` tetap memakai CHECK lama; pembeda transaksi memakai `related_entity`.
- Highlight memakai `AppColors.primaryFixed` agar tidak menambah warna baru.
- Durasi highlight 4 detik dengan transisi 250ms.
- Badge merah memakai konstanta existing `AppColors.error` (`#BA1A1A`); tidak ada warna baru.
- Untuk admin, auto-read dilakukan per tab yang sedang dirender, bukan sekaligus untuk kedua tab. Jika dua jenis notifikasi ada, badge baru hilang semua setelah kedua tab dibuka. Ini menjaga syarat "hanya yang benar-benar ditampilkan".
- Untuk user, auto-read hanya terjadi pada tab Aktif.
- Baris notifikasi lama yang sudah ada sebelum migrasi tidak dimodifikasi/dihapus. Jika baris lama memiliki `related_entity`/`related_id` yang valid, perilakunya sama seperti notifikasi baru; jika tidak, baris itu tidak akan cocok dengan card mana pun dan sengaja dibiarkan daripada diubah sembarangan.

## Verification

- Migration SQL dijalankan ulang dua kali tanpa error.
- Query manual:
  - ajukan pinjam → 1 notifikasi per admin/staf;
  - ajukan pinjam ulang dengan id yang sama tidak menambah baris;
  - setujui → 1 notifikasi untuk peminjam, 0 untuk user lain;
  - ajukan kembali → 1 notifikasi per admin/staf;
  - `tandai_notifikasi_dibaca` oleh user A tidak mengubah baris user B;
  - penerima dengan `notifikasi_aktif = false` tidak mendapat baris notifikasi;
  - query trigger/RPC lama dijalankan sebelum migrasi dan hasilnya dicek.
- Flutter:
  - `flutter analyze` bersih;
  - `flutter test` lulus, termasuk test baru untuk `formatBadgeCount`, filter related ids, dan auto-read hanya pada data yang tampil;
  - manual: badge bertambah real-time tanpa refresh; setelah halaman tujuan dibuka, badge hilang dan highlight muncul ~4 detik; setelah restart tidak muncul lagi.

## Open questions

Tidak ada yang mengubah bentuk fitur. Human partner perlu menyetujui dokumen ini sebelum rencana implementasi dibuat.
