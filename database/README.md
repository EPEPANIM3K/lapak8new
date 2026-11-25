# Skema database LAPAK8

Skema ini ditujukan untuk **Supabase PostgreSQL**. Pilih satu jalur berdasarkan
tabel yang sudah ada:

- **Instalasi baru:** jalankan `schema.sql`. Jika skema tersebut sudah
  terpasang, `admin_users_migration.sql` menambahkan dukungan pengelolaan akun.
- **Database lama yang memakai `public.users` dengan ID `bigint`:** jangan
  jalankan `schema.sql` atau `admin_users_migration.sql`. Setelah membuat backup,
  gunakan `existing_users_auth_rls.sql` sebagai migrasi kompatibilitas untuk
  skema tersebut. File itu mempertahankan `users.auth_id`, membuat view
  `profiles` agar sesuai dengan query Flutter, memetakan role lama ke role
  Flutter (`siswa` → `student`, `guru` → `teacher`, `petugas` → `staff`), dan
  menerapkan akses admin-only.

Kedua jalur tidak boleh dicampur. File migrasi tidak membuat akun Auth baru;
untuk database lama, hanya akun yang sudah dihubungkan lewat `users.auth_id`
yang tampil pada view `profiles`. Jangan mengekspos `password_hash` ke aplikasi.
Migrasi kompatibilitas memberi pengguna non-admin akses baca ke katalog dan
data miliknya sendiri; hanya role `admin` yang dapat mengubah data lewat API.
Pembuatan akun Auth baru dan penautan akun yang belum memiliki `auth_id` tetap
harus dilakukan oleh proses tepercaya. Source Edge Function `manage-users`
belum tersedia di workspace ini, sehingga pembuatan akun dan perubahan
email/password admin belum aktif hanya dengan menjalankan SQL tersebut.

## Temuan struktur project

- `lib/core` berisi konstanta tampilan, tema, router, dan direktori network.
- `lib/features` mengelompokkan layar berdasarkan auth, dashboard, fasilitas,
  peminjaman, QR, riwayat, chat, profil, aturan, dan admin.
- `lib/shared/widgets` berisi komponen UI yang dipakai lintas fitur.
- Data inventaris, peminjaman, dan riwayat belum seluruhnya terhubung ke
  backend. Login dan pengelolaan akun memakai Supabase Auth dan
  `public.profiles`.
- Rute aktif diarahkan ke dashboard admin untuk pengembangan. File ini hanya
  menyiapkan struktur database dan belum menghubungkan Flutter ke Supabase.

## Tabel dan relasi utama

- `profiles`: profil dan peran aplikasi yang terhubung ke `auth.users`.
- `locations`, `facilities`, `facility_assets`: lokasi penyimpanan, katalog
  sarana, jumlah unit, dan opsi pencatatan aset berserial/tag.
- `borrowings`: pemohon, kategori keperluan, acara, rentang waktu, status,
  alasan penolakan, dan waktu proses.
- `borrowing_items`: daftar fasilitas dan kuantitas dalam satu pengajuan.
- `borrowing_approvals`: keputusan bertahap Kaprodi dan Sarpras.
- `borrowing_asset_assignments`: pengaitan unit bernomor seri ke item pinjaman.
- `borrowing_qr_tickets`, `borrowing_events`: tiket QR (hash token saja) serta
  log scan, pengambilan, dan pengembalian.
- `chat_threads`, `chat_participants`, `chat_messages`: struktur dasar fitur
  chat yang belum diimplementasikan di UI/service.

Relasi ringkas:

```text
auth.users 1--1 profiles
locations 1--* facilities 1--* facility_assets
profiles 1--* borrowings 1--* borrowing_items *--1 facilities
borrowings 1--* borrowing_approvals
borrowing_items 1--* borrowing_asset_assignments *--1 facility_assets
borrowings 1--0..1 borrowing_qr_tickets
borrowings 1--* borrowing_events
chat_threads 1--* chat_participants
chat_threads 1--* chat_messages
```

## Catatan implementasi

- Role baru otomatis `student`. Pemberian role `staff`/`admin` harus dilakukan
  dari proses tepercaya (misalnya Supabase Edge Function), bukan dari aplikasi
  klien.
- Pengelolaan akun memanggil Edge Function `manage-users` untuk membuat akun
  Auth serta mengubah email/password. Deploy dari direktori
  `supabase/functions/manage-users`; function memakai environment standar
  Supabase. Jika perlu mengatur secret secara manual, lakukan lewat CLI dan
  jangan pernah memasukkan `SUPABASE_SERVICE_ROLE_KEY` ke aplikasi Flutter.
- Perubahan profil/status dilakukan lewat RPC
  `admin_update_managed_profile`. RPC membatasi pemanggil ke staf/admin dan
  tidak mengizinkan halaman pengguna mengubah akun ber-role `admin`.
- Untuk memberi akses admin pertama, buat/login akun melalui Supabase Auth,
  lalu jalankan di SQL Editor dengan email yang benar:

  ```sql
  update public.profiles
  set role = 'admin'
  where email = 'admin@sekolah.sch.id';
  ```
  Langkah ini hanya untuk instalasi baru yang memakai `public.profiles` sebagai
  tabel. Database lama menggunakan `public.users.role` dan tidak boleh memakai
  query tersebut.

- Setelah Supabase CLI terhubung ke proyek, deploy function dengan
  `supabase functions deploy manage-users`. Environment standar Supabase Edge
  Functions (`SUPABASE_URL`, `SUPABASE_ANON_KEY`,
  `SUPABASE_SERVICE_ROLE_KEY`) harus tersedia; jangan salin service-role key
  ke Flutter atau Git.
- RLS aktif. Profil hanya dapat dibaca pemiliknya atau staf/admin; perubahan
  data profil dan transisi status peminjaman sebaiknya dilakukan lewat operasi
  server yang tervalidasi. Kebijakan RLS bukan pengganti validasi bisnis.
- Status ketersediaan aktual bergantung pada benturan jadwal, jumlah unit, dan
  pemeliharaan; jangan menganggap `total_units` sebagai jumlah yang sedang
  bebas. Perhitungan dan pencegahan double-booking perlu dibuat transaksional
  di RPC/server.
- Token QR mentah tidak disimpan di database. Buat, kirim, dan validasi token
  melalui endpoint tepercaya; simpan hanya hash pada `borrowing_qr_tickets`.
- Foto dan lampiran sebaiknya disimpan di Supabase Storage; kolom URL hanya
  menyimpan lokasi objek.
- `chat_messages` mensyaratkan pesan teks atau lampiran. Pastikan peserta
  ditambahkan ke `chat_participants` ketika thread dibuat.
- Data kelas/unit masih berupa teks agar sesuai dengan form saat ini. Jika
  kelak perlu daftar terkelola, normalisasikan menjadi tabel referensi.
