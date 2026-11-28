# Database LAPAK8

Sumber skema database yang aktif untuk project ini adalah:

- `databasefix.sql` — skema PostgreSQL/Supabase terpadu (DDL, constraint, index, RLS, trigger/function, dan data dummy). Jalankan file ini di Supabase SQL Editor pada project baru.

## Catatan

- `databasefix.sql` merekonsiliasi skema lama (Indonesia/Inggris/MySQL REST) ke skema kanonik Supabase.
- Tabel kanonik utama memakai penamaan Indonesia (`pengguna`, `fasilitas`, `peminjaman`, dll.) dengan view/kompatibilitas yang dibutuhkan aplikasi.
- `public.pengguna.id` terhubung ke `auth.users(id)`. Jangan memasukkan UUID auth sembarang pada seed/data manual.
- Bukti pemeriksaan pengembalian disimpan di bucket privat Supabase Storage; database menyimpan metadata dan path objek.

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

Setelah itu, jalankan `migrasi_qr_peminjaman.sql`. Migrasi ini mewajibkan
konfirmasi penyerahan lewat QR, membatasi pemindaian ke transaksi terpilih,
dan menutup hak tulis langsung pada tabel `peminjaman`.

Untuk mendukung popup konfirmasi setelah QR peminjaman tervalidasi, jalankan
`migrasi_konfirmasi_qr_peminjaman.sql` setelahnya. Migrasi ini menambahkan RPC
validasi yang tidak mengubah status atau menggunakan tiket; status hanya
diperbarui oleh RPC pemrosesan QR yang sudah ada setelah admin menekan
**Ya, Konfirmasi**.

Setelah itu, jalankan `migrasi_pengembalian_workflow.sql`. Migrasi ini
menambahkan status pengajuan pengembalian, pemeriksaan, pelanggaran,
dokumentasi, dan konfirmasi pembayaran dummy. Jalankan pada basis data staging
terlebih dahulu; migrasi tidak menghapus riwayat transaksi.

Setelah workflow pengembalian diterapkan, jalankan
`migrasi_supabase_storage_bukti.sql`. Migrasi ini membuat bucket bukti privat,
membatasi unggah ke admin/staf, dan memberi akses baca hanya kepada admin/staf
serta pemilik transaksi. Setelah migrasi berhasil, unggah dan baca bukti baru
tidak lagi memerlukan `tooling/lapak8_storage_server`.

Pada database yang sudah menerapkan `migrasi_pengembalian_workflow.sql`,
jalankan `migrasi_konfirmasi_pembayaran_admin.sql` setelahnya. Konfirmasi dari
user hanya mengubah status pembayaran menjadi menunggu konfirmasi admin.
Transaksi baru dipindahkan ke riwayat setelah admin/staf aktif mengonfirmasi.

Untuk mengisi bagian **Item Populer** dashboard user dari riwayat pinjaman,
jalankan `migrasi_dashboard_item_populer.sql` setelah `databasefix.sql` dan
`migrasi_pengembalian_workflow.sql`. RPC hanya mengembalikan data agregat
fasilitas dan jumlah unit yang pernah dipinjam, bukan identitas peminjam.

### Stok tersedia

Jalankan `migrasi_stok_tersedia.sql` setelah `databasefix.sql` melalui
**Supabase Dashboard → SQL Editor → New query**. Migrasi menambahkan RPC
`public.stok_fasilitas()` yang mengembalikan kapasitas fisik, unit yang sedang
dipakai, dan unit tersedia tanpa membuka identitas peminjam.

Stok dihitung konservatif: semua peminjaman berstatus `disetujui`, `dipinjam`,
atau `terlambat` dihitung tanpa membandingkan tanggal. Status `menunggu`
tidak mengurangi stok; status `dikembalikan` melepaskan unit. Untuk
memverifikasi hasil agregat:

```sql
SELECT *
FROM public.stok_fasilitas()
ORDER BY fasilitas_id;
```

### Alur pemakaian

1. Setelah peminjaman disetujui, peminjam membuka **Pinjaman Saya** dan memilih
   **Tampilkan QR Peminjaman**. Admin membuka transaksi yang sama di Aktivitas
   lalu memilih **Scan QR Peminjaman**. Setelah QR valid untuk transaksi
   tersebut, admin mengonfirmasi penyerahan barang; status berubah menjadi
   `dipinjam` dan `diambil_pada` dicatat setelah konfirmasi.
2. Saat barang sedang dipinjam atau terlambat, peminjam memilih
   **Kembalikan Sekarang** dan mengonfirmasi. Status berubah menjadi
   `menunggu_pengembalian`; peminjam lalu menampilkan QR pengembalian.
3. Admin membuka tab **Aktivitas Pengembalian**, memilih **Cek Kondisi**,
   memindai QR untuk transaksi tersebut, lalu memilih kondisi Baik, Rusak,
   Hilang, atau Terlambat. Temuan, nominal denda, keterangan, serta metadata
   bukti disimpan bersama pemeriksaan.
4. Kondisi Baik langsung menyelesaikan transaksi. Temuan lain mengubah status
   menjadi `pelanggaran` dan menunggu konfirmasi pembayaran dummy dari pemilik
   transaksi. Setelah user mengirim konfirmasi, status pembayaran menjadi
   `menunggu_konfirmasi_admin`; admin/staf harus mengonfirmasi sebelum status
   peminjaman berubah menjadi `dikembalikan`. QRIS hanya ditampilkan sebagai
   petunjuk pembayaran manual; tidak ada verifikasi QRIS.
5. Status kanonik database setelah selesai adalah `dikembalikan`, sesuai skema
   yang sudah ada; aplikasi menampilkannya sebagai **Selesai**. Jangan mengubah
   constraint status menjadi nilai `selesai`.

Tiket QR berlaku 24 jam dan hanya dapat dipakai sekali. RPC memeriksa akun
admin/staf aktif, masa berlaku, status peminjaman, kecocokan transaksi, serta
penggunaan ulang. QR pengembalian hanya dapat diproses dari transaksi yang
sedang menunggu pengembalian. Peminjaman yang belum diambil tidak dapat
dikembalikan.
Status `dipinjam` tidak dapat diatur melalui RPC persetujuan atau pembaruan
langsung tabel; hanya pemrosesan QR peminjaman yang dapat mengubahnya.

`fasilitas.total_unit` menyimpan kapasitas fisik. Barang baik yang selesai
dikembalikan kembali tersedia karena status peminjaman keluar dari perhitungan
peminjaman aktif—jumlah fisik tidak ditambah lagi agar stok tidak berlipat.
Barang rusak atau hilang mengurangi kapasitas fisik; perubahan atau penambahan
stok selanjutnya dilakukan melalui pengelolaan fasilitas.

Bukti yang diunggah sebelum migrasi ini masih berada di server penyimpanan
lama dan tidak otomatis dipindahkan. Jika perlu mempertahankan akses ke berkas
lama, salin berkas tersebut ke bucket `return-documentation` dan perbarui
`return_documentation.file_path` sesuai path objek Supabase.
