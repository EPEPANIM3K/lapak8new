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

## Fitur QR pengambilan dan pengembalian

Migrasi fitur berada di `migrasi_pengembalian.sql`. Tinjau isi migrasi terlebih
dahulu, lalu jalankan di Supabase SQL Editor setelah `databasefix.sql`. Migrasi
menambah kolom dan RPC pada tabel yang sudah ada; migrasi ini tidak menghapus
tabel atau data.

Untuk database yang sudah menerapkan migrasi tersebut, tinjau dan jalankan
`migrasi_pengembalian_keamanan_qr.sql` sebagai patch lanjutan. Patch ini
memastikan hanya akun aktif yang dapat membuat tiket dan memperkuat token QR;
tidak mengubah tabel atau data.

### Alur pemakaian

1. Setelah peminjaman disetujui, peminjam membuka **Pinjaman Saya** dan memilih
   **Tampilkan QR Pengambilan**. Petugas/admin memindainya untuk menandai barang
   sebagai sedang dipinjam.
2. Saat barang sedang dipinjam atau terlambat, peminjam memilih
   **Tampilkan QR Pengembalian**. Admin memindainya, memeriksa ringkasan
   peminjaman dan keterlambatan, memilih kondisi barang (baik/rusak/hilang),
   menulis catatan bila perlu, lalu mengonfirmasi.
3. Pengembalian tanpa QR dapat dicatat dari **Aktivitas Admin → Peminjaman →
   Catat Pengembalian** dengan mengisi kondisi dan catatan yang sama.
4. Status kanonik database setelah selesai adalah `dikembalikan`, sesuai skema
   yang sudah ada; aplikasi menampilkannya sebagai **Selesai**. Jangan mengubah
   constraint status menjadi nilai `selesai`.

Tiket QR berlaku 24 jam dan hanya dapat dipakai sekali. RPC memeriksa akun
admin/staf aktif, masa berlaku, status peminjaman, serta penggunaan ulang.
Peminjaman yang belum diambil tidak dapat dikembalikan.

`fasilitas.total_unit` menyimpan kapasitas fisik. Barang baik yang selesai
dikembalikan kembali tersedia karena status peminjaman keluar dari perhitungan
peminjaman aktif—jumlah fisik tidak ditambah lagi agar stok tidak berlipat.
Barang rusak atau hilang mengurangi kapasitas fisik; perubahan atau penambahan
stok selanjutnya dilakukan melalui pengelolaan fasilitas.
