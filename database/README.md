# Database LAPAK8

Sumber skema database yang aktif untuk project ini adalah:

- `databasefix.sql` — skema PostgreSQL/Supabase terpadu (DDL, constraint, index, RLS, trigger/function, dan data dummy). Jalankan file ini di Supabase SQL Editor pada project baru.

## Catatan

- `databasefix.sql` merekonsiliasi skema lama (Indonesia/Inggris/MySQL REST) ke skema kanonik Supabase.
- Tabel kanonik utama memakai penamaan Indonesia (`pengguna`, `fasilitas`, `peminjaman`, dll.) dengan view/kompatibilitas yang dibutuhkan aplikasi.
- `public.pengguna.id` terhubung ke `auth.users(id)`. Jangan memasukkan UUID auth sembarang pada seed/data manual.
- Dokumentasi inspeksi/pengembalian tetap disimpan di storage server eksternal; database hanya menyimpan metadata/kompatibilitas.

## Langkah awal project baru

1. Buat project Supabase baru.
2. Jalankan `databasefix.sql` di SQL Editor.
3. Isi kredensial Supabase baru di aplikasi (`SUPABASE_URL`, `SUPABASE_ANON_KEY`) atau `lib/core/config/supabase_config.dart` untuk lokal.
4. Verifikasi RLS, trigger, dan alur peminjaman di staging sebelum produksi.
