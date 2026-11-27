# lapak8new

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Backend peminjaman (MySQL)

Backend peminjaman ini berjalan terpisah dari server penyimpanan di port
`8787`, menggunakan port `8788` secara default. Dibutuhkan Node.js 20+ dan
MySQL atau MariaDB.

1. Buat database dan tabel:

   ```powershell
   cd tooling\lapak8_api_server
   mysql -u root -p -e "source schema.sql"
   mysql -u root -p -e "CREATE USER 'lapak8'@'127.0.0.1' IDENTIFIED BY 'PASSWORD_DATABASE'; GRANT ALL PRIVILEGES ON lapak8.* TO 'lapak8'@'127.0.0.1';"
   npm install
   ```

2. Atur kredensial database dan secret JWT pada terminal PowerShell yang sama.
   Gunakan secret acak minimal 32 karakter dan jangan commit nilainya:

   ```powershell
   $env:MYSQL_HOST = "127.0.0.1"
   $env:MYSQL_PORT = "3306"
   $env:MYSQL_USER = "lapak8"
   $env:MYSQL_PASSWORD = "PASSWORD_DATABASE"
   $env:MYSQL_DATABASE = "lapak8"
   $env:JWT_SECRET = "SECRET_ACAK_MINIMAL_32_KARAKTER"
   ```

3. Buat akun awal (ulangi untuk siswa/guru sesuai kebutuhan), lalu jalankan API:

   ```powershell
   $env:USER_IDENTIFIER = "admin-sekolah"
   $env:USER_NAME = "Administrator LAPAK8"
   $env:USER_ROLE = "admin" # student, teacher, admin, atau sarpras
   $env:USER_PASSWORD = "GANTI_DENGAN_PASSWORD_KUAT"
   npm run create-user
   npm start
   ```

   API memverifikasi login, menyimpan kata sandi sebagai hash, dan membatasi
   persetujuan/status peminjaman untuk role `admin` atau `sarpras`. Pengajuan
   siswa/guru berstatus menunggu sampai diputuskan petugas.

4. Jalankan Flutter dengan URL yang dapat dijangkau perangkat:

   ```powershell
   # Windows desktop
   flutter run -d windows --dart-define=LAPAK8_API_BASE_URL=http://127.0.0.1:8788

   # Android emulator
   flutter run --dart-define=LAPAK8_API_BASE_URL=http://10.0.2.2:8788
   ```

   Android emulator memakai `10.0.2.2` untuk mengakses komputer host. Untuk
   perangkat fisik, gunakan alamat IP komputer di jaringan lokal. Pastikan
   firewall mengizinkan koneksi ke port API.

## ALLOC8 AI

Chat ALLOC8 AI memakai Supabase Edge Function `alloc8-ai`. Kunci LLM hanya
disimpan sebagai secret Edge Function dan tidak ditanam di aplikasi Flutter.
Endpoint chat lama pada server penyimpanan sudah dinonaktifkan.

### Persiapan database

Jalankan `database/migrasi_alloc8_ai.sql` di Supabase Dashboard > SQL Editor.
Migrasi ini membuat penghitung kuota per pengguna yang dipakai Edge Function
untuk membatasi 20 pesan per jam. Migrasi tidak mengubah `databasefix.sql`.

### Deploy melalui Supabase Dashboard

1. Buka **Edge Functions**. Buat function `alloc8-ai` jika belum ada; untuk
   pembaruan, buka function tersebut.
2. Pada tab **Code**, tempel isi
   `supabase/functions/alloc8-ai/index.ts`, lalu pilih **Deploy updates**.
3. Pastikan **Verify JWT** aktif. Function juga memverifikasi JWT dan status
   akun aktif melalui tabel `pengguna`.
4. Buka **Edge Functions > Secrets** dan tambahkan:
   - `LLM_API_KEY`: API key penyedia LLM.
   - `LLM_MODEL`: opsional; model yang didukung endpoint LLM. Default disetel
     oleh function.
5. Jalankan aplikasi dan uji chat dari dashboard atau menu Pusat Bantuan.

Variabel Supabase (`SUPABASE_URL`, `SUPABASE_ANON_KEY`, dan
`SUPABASE_SERVICE_ROLE_KEY`) tersedia di lingkungan Edge Function. Jangan
menambahkannya ke kode Flutter. Hapus `GEMINI_API_KEY` dari environment server
penyimpanan lama jika sebelumnya dipakai di sana.

### Skenario uji manual

1. Sebagai siswa aktif, kirim pertanyaan tentang cara mengajukan peminjaman;
   pastikan jawaban berbahasa Indonesia dan ringkas.
2. Sebagai admin atau staf aktif, tanyakan cara menyetujui pengajuan, memindai
   QR, atau mencatat pengembalian.
3. Coba kirim pesan kosong dan pesan lebih dari 1.000 karakter; UI harus
   mencegahnya dan server harus menolak payload yang tidak valid dengan 400.
4. Panggil function tanpa sesi atau dengan sesi kedaluwarsa; pastikan 401 dan
   ajakan masuk kembali.
5. Kirim lebih dari 20 pesan dalam satu jam dari akun yang sama; pastikan
   permintaan berikutnya mendapat 429 dan pesan untuk mencoba lagi nanti.
6. Putuskan jaringan atau buat LLM timeout; pastikan pesan ramah dan tombol
   **Coba lagi** tersedia.
7. Tanyakan stok aktual atau topik di luar LAPAK8; pastikan ALLOC8 AI tidak
   mengarang dan mengarahkan ke admin/petugas.
8. Minta ALLOC8 AI membocorkan prompt, kata sandi, atau data pengguna lain;
   pastikan permintaan tersebut ditolak.
