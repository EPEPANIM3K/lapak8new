# Skema database LAPAK8

Skema ini ditujukan untuk **Supabase PostgreSQL** dan berada di `schema.sql`.
Jalankan isinya pada SQL Editor proyek Supabase. Tabel kredensial tidak dibuat
sendiri: Supabase Auth menyimpan akun di `auth.users`; trigger membuat baris
profil aplikasi pada `public.profiles` saat akun baru dibuat.

## Temuan struktur project

- `lib/core` berisi konstanta tampilan, tema, router, dan direktori network.
- `lib/features` mengelompokkan layar berdasarkan auth, dashboard, fasilitas,
  peminjaman, QR, riwayat, chat, profil, aturan, dan admin.
- `lib/shared/widgets` berisi komponen UI yang dipakai lintas fitur.
- Data inventaris, peminjaman, pengguna, status, dan riwayat yang terlihat saat
  ini berasal dari data contoh/UI. Model dan service auth, fasilitas,
  peminjaman, serta chat masih kosong; belum ada integrasi database.
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
