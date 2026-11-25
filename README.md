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

Backend ini berjalan terpisah dari layanan chatbot/storage di port `8787`,
menggunakan port `8788` secara default. Dibutuhkan Node.js 20+ dan MySQL atau
MariaDB.

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

## Chatbot Gemini

Chatbot LAPAK8 memakai endpoint server agar Gemini API key tidak ditanam di
aplikasi Flutter.

1. Buat API key di Google AI Studio.
2. Jalankan server dengan key sebagai environment variable (jangan commit key):

   ```powershell
   cd tooling\lapak8_storage_server
   $env:GEMINI_API_KEY = "API_KEY_ANDA"
   node server.js
   ```

   Server memakai model `gemini-3.5-flash-lite` secara default; model dapat diganti
   lewat environment variable `GEMINI_MODEL`.
3. Jalankan Flutter dengan alamat server yang dapat dijangkau perangkat:

   ```powershell
   # Android emulator
   flutter run --dart-define=LAPAK8_STORAGE_BASE_URL=http://10.0.2.2:8787

   # Windows desktop
   flutter run -d windows --dart-define=LAPAK8_STORAGE_BASE_URL=http://127.0.0.1:8787
   ```

   Untuk perangkat fisik, gunakan alamat IP komputer di jaringan lokal dan
   pastikan port server dapat dijangkau.

Jangan gunakan token pengembangan bawaan (`lapak8-dev-token`) di produksi.
Chatbot saat ini menjawab panduan umum dan belum membaca inventaris atau status
peminjaman dari database LAPAK8.

Lihat [daftar model Gemini resmi](https://ai.google.dev/gemini-api/docs/models)
untuk mengecek model yang tersedia.
