-- Jalankan setelah migrasi_pengembalian.sql, migrasi_qr_peminjaman.sql,
-- dan migrasi_konfirmasi_qr_peminjaman.sql.
-- Semua perubahan bersifat aditif; data peminjaman dan riwayat tidak dihapus.

DO $$
BEGIN
  IF to_regprocedure('public.proses_qr_admin(text)') IS NULL
      OR to_regprocedure(
        'public.proses_peminjaman_admin_qr_legacy(uuid,text,text)'
      ) IS NULL THEN
    RAISE EXCEPTION
      'Jalankan migrasi QR peminjaman sebelum migrasi workflow pengembalian.';
  END IF;
END;
$$;

ALTER TABLE public.peminjaman
  DROP CONSTRAINT IF EXISTS peminjaman_status_check;

ALTER TABLE public.peminjaman
  ADD CONSTRAINT peminjaman_status_check CHECK (
    status IN (
      'menunggu_persetujuan', 'disetujui', 'ditolak', 'dibatalkan',
      'dipinjam', 'menunggu_pengembalian', 'pelanggaran',
      'dikembalikan', 'terlambat'
    )
  );

ALTER TABLE public.peminjaman
  ADD COLUMN IF NOT EXISTS return_requested_at TIMESTAMPTZ;

ALTER TABLE public.peminjaman
  DROP CONSTRAINT IF EXISTS peminjaman_kondisi_barang_check;

ALTER TABLE public.peminjaman
  ADD CONSTRAINT peminjaman_kondisi_barang_check CHECK (
    kondisi_barang IS NULL
    OR kondisi_barang IN ('baik', 'rusak', 'hilang', 'terlambat')
  );

ALTER TABLE public.return_inspections
  DROP CONSTRAINT IF EXISTS return_inspections_status_check;

ALTER TABLE public.return_inspections
  ADD CONSTRAINT return_inspections_status_check CHECK (
    status IN ('menunggu', 'menunggu_pembayaran', 'selesai', 'disetujui', 'ditolak')
  );

ALTER TABLE public.return_inspections
  ADD COLUMN IF NOT EXISTS kondisi_barang TEXT,
  ADD COLUMN IF NOT EXISTS jenis_pelanggaran TEXT,
  ADD COLUMN IF NOT EXISTS denda NUMERIC(12, 2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS keterangan_pelanggaran TEXT,
  ADD COLUMN IF NOT EXISTS status_pembayaran TEXT NOT NULL DEFAULT 'tidak_ada',
  ADD COLUMN IF NOT EXISTS diperiksa_pada TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS dibayar_pada TIMESTAMPTZ;

ALTER TABLE public.return_inspections
  DROP CONSTRAINT IF EXISTS return_inspections_kondisi_barang_check,
  DROP CONSTRAINT IF EXISTS return_inspections_jenis_pelanggaran_check,
  DROP CONSTRAINT IF EXISTS return_inspections_denda_check,
  DROP CONSTRAINT IF EXISTS return_inspections_status_pembayaran_check;

ALTER TABLE public.return_inspections
  ADD CONSTRAINT return_inspections_kondisi_barang_check CHECK (
    kondisi_barang IS NULL
    OR kondisi_barang IN ('baik', 'rusak', 'hilang', 'terlambat')
  ),
  ADD CONSTRAINT return_inspections_jenis_pelanggaran_check CHECK (
    jenis_pelanggaran IS NULL
    OR jenis_pelanggaran IN ('rusak', 'hilang', 'terlambat')
  ),
  ADD CONSTRAINT return_inspections_denda_check CHECK (denda >= 0),
  ADD CONSTRAINT return_inspections_status_pembayaran_check CHECK (
    status_pembayaran IN ('tidak_ada', 'menunggu_pembayaran', 'dikonfirmasi')
  );

CREATE OR REPLACE FUNCTION public.ajukan_pengembalian(
  p_peminjaman_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_status TEXT;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Silakan masuk terlebih dahulu.';
  END IF;

  SELECT p.status
  INTO v_status
  FROM public.peminjaman AS p
  WHERE p.id = p_peminjaman_id
    AND p.peminjam_id = v_user_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Peminjaman tidak ditemukan atau bukan milik Anda.';
  END IF;

  IF v_status NOT IN ('dipinjam', 'terlambat') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Peminjaman tidak dapat diajukan untuk pengembalian saat ini.';
  END IF;

  UPDATE public.peminjaman
  SET status = 'menunggu_pengembalian',
      return_requested_at = now(),
      updated_at = now()
  WHERE id = p_peminjaman_id;

  INSERT INTO public.riwayat_kejadian (peminjaman_id, aktor_id, jenis, deskripsi)
  VALUES (
    p_peminjaman_id,
    v_user_id,
    'status_change',
    'Peminjam mengajukan pengembalian; menunggu pemeriksaan admin.'
  );
END;
$$;

-- Return QR hanya dapat dibuat setelah user mengajukan pengembalian.
CREATE OR REPLACE FUNCTION public.buat_tiket_qr(
  p_peminjaman_id UUID,
  p_tipe TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_status TEXT;
  v_peminjam_id UUID;
  v_kode TEXT;
  v_tiket_id UUID;
  v_expired TIMESTAMPTZ;
  v_existing RECORD;
BEGIN
  IF v_uid IS NULL OR NOT EXISTS (
    SELECT 1 FROM public.pengguna AS pg
    WHERE pg.id = v_uid AND pg.aktif = TRUE
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Akun tidak aktif atau tidak terdaftar.';
  END IF;

  SELECT p.status, p.peminjam_id
  INTO v_status, v_peminjam_id
  FROM public.peminjaman AS p
  WHERE p.id = p_peminjaman_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Peminjaman tidak ditemukan.';
  END IF;

  IF v_peminjam_id <> v_uid THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Anda bukan peminjam dari peminjaman ini.';
  END IF;

  IF p_tipe = 'pengambilan' AND v_status <> 'disetujui' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'QR pengambilan hanya tersedia untuk peminjaman yang disetujui.';
  ELSIF p_tipe = 'pengembalian'
      AND v_status <> 'menunggu_pengembalian' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Ajukan pengembalian sebelum membuat QR pengembalian.';
  ELSIF p_tipe NOT IN ('pengambilan', 'pengembalian') OR p_tipe IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Jenis QR tidak valid.';
  END IF;

  SELECT tq.id, tq.kode_qr, tq.expired_at
  INTO v_existing
  FROM public.tiket_qr AS tq
  WHERE tq.peminjaman_id = p_peminjaman_id
    AND tq.tipe = p_tipe
    AND tq.sudah_dipakai = FALSE
    AND tq.expired_at > now()
  ORDER BY tq.dibuat_pada DESC
  LIMIT 1
  FOR UPDATE;

  IF v_existing.id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'tiket_id', v_existing.id,
      'kode_qr', v_existing.kode_qr,
      'expired_at', v_existing.expired_at,
      'baru', FALSE
    );
  END IF;

  v_kode := 'LAPAK8:' || p_peminjaman_id::TEXT || ':' || p_tipe || ':'
    || upper(replace(gen_random_uuid()::TEXT, '-', ''));
  v_expired := now() + interval '24 hours';

  INSERT INTO public.tiket_qr (peminjaman_id, kode_qr, tipe, expired_at)
  VALUES (p_peminjaman_id, v_kode, p_tipe, v_expired)
  RETURNING id INTO v_tiket_id;

  RETURN jsonb_build_object(
    'tiket_id', v_tiket_id,
    'kode_qr', v_kode,
    'expired_at', v_expired,
    'baru', TRUE
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.proses_qr_pengembalian_admin(
  p_kode_qr TEXT,
  p_peminjaman_id UUID DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_peminjaman_id UUID;
  v_tiket RECORD;
  v_peminjaman RECORD;
  v_peminjam RECORD;
  v_items JSONB;
  v_inspection_id UUID;
  v_item_id UUID;
BEGIN
  IF v_admin_id IS NULL OR NOT public.adalah_admin_atau_staf() THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Hanya admin atau staf aktif yang dapat memproses QR pengembalian.';
  END IF;

  SELECT tq.peminjaman_id
  INTO v_peminjaman_id
  FROM public.tiket_qr AS tq
  WHERE tq.kode_qr = p_kode_qr;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Kode QR tidak valid atau bukan tiket LAPAK8.';
  END IF;

  IF p_peminjaman_id IS NOT NULL
      AND p_peminjaman_id IS DISTINCT FROM v_peminjaman_id THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'QR tidak cocok dengan transaksi pengembalian yang dipilih.';
  END IF;

  SELECT p.*
  INTO v_peminjaman
  FROM public.peminjaman AS p
  WHERE p.id = v_peminjaman_id
  FOR UPDATE;

  IF NOT FOUND OR v_peminjaman.status <> 'menunggu_pengembalian' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'QR pengembalian hanya dapat diproses untuk transaksi yang menunggu pengembalian.';
  END IF;

  SELECT tq.*
  INTO v_tiket
  FROM public.tiket_qr AS tq
  WHERE tq.kode_qr = p_kode_qr
  FOR UPDATE;

  IF NOT FOUND
      OR v_tiket.peminjaman_id IS DISTINCT FROM v_peminjaman_id
      OR v_tiket.tipe IS DISTINCT FROM 'pengembalian' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'QR tidak cocok dengan transaksi pengembalian yang dipilih.';
  END IF;

  IF v_tiket.sudah_dipakai THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Tiket QR ini sudah pernah digunakan.';
  END IF;

  IF v_tiket.expired_at IS NULL OR v_tiket.expired_at <= now() THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Tiket QR ini sudah kedaluwarsa. Minta peminjam membuat QR baru.';
  END IF;

  UPDATE public.tiket_qr
  SET sudah_dipakai = TRUE,
      dipakai_pada = now(),
      dipakai_oleh = v_admin_id
  WHERE id = v_tiket.id;

  SELECT ri.id
  INTO v_inspection_id
  FROM public.return_inspections AS ri
  WHERE ri.borrowing_id = v_peminjaman_id
    AND ri.status = 'menunggu'
  ORDER BY ri.dibuat_pada DESC
  LIMIT 1
  FOR UPDATE;

  IF FOUND THEN
    UPDATE public.return_inspections
    SET inspektor_id = v_admin_id,
        updated_at = now()
    WHERE id = v_inspection_id;
  ELSE
    INSERT INTO public.return_inspections (
      borrowing_id, inspektor_id, inspection_code, status
    )
    VALUES (
      v_peminjaman_id,
      v_admin_id,
      'RET-' || v_peminjaman.kode_booking,
      'menunggu'
    )
    RETURNING id INTO v_inspection_id;
  END IF;

  SELECT pg.nama_lengkap, pg.nomor_induk, pg.kelas_atau_unit, pg.peran
  INTO v_peminjam
  FROM public.pengguna AS pg
  WHERE pg.id = v_peminjaman.peminjam_id;

  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'id', item.id,
    'fasilitas_id', item.fasilitas_id,
    'nama_fasilitas', item.nama_fasilitas_snapshot,
    'jumlah', item.jumlah
  )), '[]'::jsonb)
  INTO v_items
  FROM public.item_peminjaman AS item
  WHERE item.peminjaman_id = v_peminjaman_id;

  SELECT item.id
  INTO v_item_id
  FROM public.item_peminjaman AS item
  WHERE item.peminjaman_id = v_peminjaman_id
  ORDER BY item.created_at
  LIMIT 1;

  RETURN jsonb_build_object(
    'peminjaman_id', v_peminjaman_id,
    'return_inspection_id', v_inspection_id,
    'item_id', v_item_id,
    'kode_booking', v_peminjaman.kode_booking,
    'tipe_tiket', 'pengembalian',
    'status', v_peminjaman.status,
    'terlambat', now() > v_peminjaman.estimasi_kembali_pada,
    'di-scan-pada', now(),
    'peminjam', jsonb_build_object(
      'nama_lengkap', v_peminjam.nama_lengkap,
      'nomor_induk', v_peminjam.nomor_induk,
      'kelas_atau_unit', v_peminjam.kelas_atau_unit,
      'peran', v_peminjam.peran
    ),
    'items', v_items,
    'estimasi_kembali_pada', v_peminjaman.estimasi_kembali_pada
  );
END;
$$;

DO $$
BEGIN
  IF to_regprocedure('public.proses_qr_admin_legacy(TEXT)') IS NULL
      AND to_regprocedure('public.proses_qr_admin(TEXT)') IS NOT NULL THEN
    ALTER FUNCTION public.proses_qr_admin(TEXT)
      RENAME TO proses_qr_admin_legacy;
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.proses_qr_admin_legacy(TEXT)
  FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.proses_qr_admin(
  p_kode_qr TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_peminjaman_id UUID;
  v_tipe TEXT;
BEGIN
  SELECT tq.peminjaman_id, tq.tipe
  INTO v_peminjaman_id, v_tipe
  FROM public.tiket_qr AS tq
  WHERE tq.kode_qr = p_kode_qr;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Kode QR tidak valid atau bukan tiket LAPAK8.';
  END IF;

  IF v_tipe = 'pengembalian' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Pindai QR pengembalian dari tombol Cek Kondisi pada transaksi yang dipilih.';
  END IF;

  RETURN public.proses_qr_admin_legacy(p_kode_qr);
END;
$$;

CREATE OR REPLACE FUNCTION public.selesaikan_pemeriksaan_pengembalian(
  p_peminjaman_id UUID,
  p_return_inspection_id UUID,
  p_kondisi_barang TEXT,
  p_denda NUMERIC,
  p_keterangan TEXT DEFAULT NULL,
  p_bukti JSONB DEFAULT '[]'::JSONB
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_peminjaman public.peminjaman%ROWTYPE;
  v_inspection public.return_inspections%ROWTYPE;
  v_item RECORD;
  v_item_id UUID;
  v_description TEXT := nullif(trim(p_keterangan), '');
  v_violation TEXT;
  v_payment_status TEXT;
  v_return_status TEXT;
  v_log TEXT;
  v_file JSONB;
  v_file_id TEXT;
  v_kind TEXT;
  v_photo_count INTEGER;
  v_video_count INTEGER;
BEGIN
  IF v_admin_id IS NULL OR NOT public.adalah_admin_atau_staf() THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Hanya admin atau staf aktif yang dapat menyimpan pemeriksaan.';
  END IF;

  IF p_kondisi_barang NOT IN ('baik', 'rusak', 'hilang', 'terlambat')
      OR p_kondisi_barang IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Pilih kondisi: baik, rusak, hilang, atau terlambat.';
  END IF;

  IF p_denda IS NULL OR p_denda < 0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Nominal denda tidak valid.';
  END IF;

  IF p_kondisi_barang = 'baik' AND p_denda <> 0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Pengembalian dengan kondisi baik tidak dikenakan denda.';
  ELSIF p_kondisi_barang <> 'baik' AND p_denda <= 0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Nominal denda wajib lebih dari nol untuk pelanggaran.';
  END IF;

  IF p_kondisi_barang IN ('rusak', 'hilang')
      AND v_description IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Keterangan kerusakan atau kehilangan wajib diisi.';
  END IF;

  IF p_bukti IS NULL OR jsonb_typeof(p_bukti) <> 'array' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Daftar bukti pemeriksaan tidak valid.';
  END IF;

  SELECT count(*) FILTER (WHERE value->>'jenis' = 'photo')::INTEGER,
         count(*) FILTER (WHERE value->>'jenis' = 'video')::INTEGER
  INTO v_photo_count, v_video_count
  FROM jsonb_array_elements(p_bukti);

  IF v_photo_count > 6 OR v_video_count > 1
      OR v_photo_count + v_video_count <> jsonb_array_length(p_bukti) THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Bukti harus berupa maksimal 6 foto dan 1 video.';
  END IF;

  IF EXISTS (
    SELECT 1
    FROM jsonb_array_elements(p_bukti) AS evidence(value)
    GROUP BY evidence.value->>'file_id'
    HAVING count(*) > 1
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'ID berkas bukti tidak boleh berulang.';
  END IF;

  SELECT p.*
  INTO v_peminjaman
  FROM public.peminjaman AS p
  WHERE p.id = p_peminjaman_id
  FOR UPDATE;

  IF NOT FOUND OR v_peminjaman.status <> 'menunggu_pengembalian' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Peminjaman tidak lagi menunggu pemeriksaan pengembalian.';
  END IF;

  SELECT ri.*
  INTO v_inspection
  FROM public.return_inspections AS ri
  WHERE ri.id = p_return_inspection_id
    AND ri.borrowing_id = p_peminjaman_id
  FOR UPDATE;

  IF NOT FOUND OR v_inspection.status <> 'menunggu' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Pemeriksaan pengembalian tidak valid atau sudah diselesaikan.';
  END IF;

  SELECT item.id
  INTO v_item_id
  FROM public.item_peminjaman AS item
  WHERE item.peminjaman_id = p_peminjaman_id
  ORDER BY item.created_at
  LIMIT 1;

  FOR v_file IN SELECT value FROM jsonb_array_elements(p_bukti)
  LOOP
    v_file_id := v_file->>'file_id';
    v_kind := v_file->>'jenis';
    IF v_file_id IS NULL
        OR v_file_id !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$'
        OR v_kind NOT IN ('photo', 'video') THEN
      RAISE EXCEPTION USING ERRCODE = '22023',
        MESSAGE = 'Metadata bukti pemeriksaan tidak valid.';
    END IF;

    IF v_kind = 'video' THEN
      DELETE FROM public.return_documentation
      WHERE return_inspection_id = p_return_inspection_id
        AND jenis = 'video';
    END IF;

    INSERT INTO public.return_documentation (
      borrowing_id, return_inspection_id, inspection_id, item_id,
      file_id, jenis, file_name, file_path, mime_type, ukuran_byte,
      diunggah_oleh
    )
    SELECT
      p_peminjaman_id,
      p_return_inspection_id,
      p_return_inspection_id::TEXT,
      v_item_id,
      v_file_id,
      v_kind,
      coalesce(nullif(v_file->>'file_name', ''), 'Bukti pemeriksaan'),
      '/api/v1/inspections/' || p_return_inspection_id::TEXT ||
        '/file/' || v_file_id,
      coalesce(nullif(v_file->>'mime_type', ''), 'application/octet-stream'),
      greatest(coalesce((v_file->>'ukuran_byte')::BIGINT, 0), 0),
      v_admin_id
    WHERE NOT EXISTS (
      SELECT 1
      FROM public.return_documentation AS existing_file
      WHERE existing_file.return_inspection_id = p_return_inspection_id
        AND existing_file.file_id = v_file_id
    );
  END LOOP;

  v_violation := CASE
    WHEN p_kondisi_barang = 'baik' THEN NULL
    ELSE p_kondisi_barang
  END;
  v_payment_status := CASE
    WHEN v_violation IS NULL THEN 'tidak_ada'
    ELSE 'menunggu_pembayaran'
  END;
  v_return_status := CASE
    WHEN v_violation IS NULL THEN 'dikembalikan'
    ELSE 'pelanggaran'
  END;

  UPDATE public.return_inspections
  SET status = CASE
        WHEN v_violation IS NULL THEN 'selesai'
        ELSE 'menunggu_pembayaran'
      END,
      kondisi_barang = p_kondisi_barang,
      jenis_pelanggaran = v_violation,
      denda = p_denda,
      keterangan_pelanggaran = v_description,
      status_pembayaran = v_payment_status,
      diperiksa_pada = now(),
      selesai_pada = CASE WHEN v_violation IS NULL THEN now() ELSE NULL END,
      updated_at = now()
  WHERE id = p_return_inspection_id;

  UPDATE public.peminjaman
  SET status = v_return_status,
      kondisi_barang = p_kondisi_barang,
      catatan_pengembalian = v_description,
      dikembalikan_pada = CASE
        WHEN v_violation IS NULL THEN now()
        ELSE NULL
      END,
      updated_at = now()
  WHERE id = p_peminjaman_id;

  IF p_kondisi_barang IN ('rusak', 'hilang') THEN
    FOR v_item IN
      SELECT item.fasilitas_id, sum(item.jumlah)::INTEGER AS jumlah
      FROM public.item_peminjaman AS item
      WHERE item.peminjaman_id = p_peminjaman_id
        AND item.fasilitas_id IS NOT NULL
      GROUP BY item.fasilitas_id
    LOOP
      UPDATE public.fasilitas
      SET total_unit = greatest(coalesce(total_unit, 0) - v_item.jumlah, 0),
          updated_at = now()
      WHERE id = v_item.fasilitas_id;
    END LOOP;
  END IF;

  IF p_kondisi_barang = 'baik' THEN
    v_log := 'Pengembalian terverifikasi, barang kembali dengan kondisi baik.';
  ELSIF p_kondisi_barang = 'rusak' THEN
    v_log := 'Barang kembali dengan pelanggaran kerusakan sebesar Rp' ||
      replace(to_char(p_denda, 'FM999G999G999G990'), ',', '.') || '.';
  ELSIF p_kondisi_barang = 'hilang' THEN
    v_log := 'Barang dinyatakan hilang dengan denda sebesar Rp' ||
      replace(to_char(p_denda, 'FM999G999G999G990'), ',', '.') || '.';
  ELSE
    v_log := 'Barang kembali dengan pelanggaran keterlambatan sebesar Rp' ||
      replace(to_char(p_denda, 'FM999G999G999G990'), ',', '.') || '.';
  END IF;
  IF v_description IS NOT NULL THEN
    v_log := v_log || ' Keterangan: ' || v_description;
  END IF;

  INSERT INTO public.riwayat_kejadian (peminjaman_id, aktor_id, jenis, deskripsi)
  VALUES (p_peminjaman_id, v_admin_id, 'status_change', v_log);

  RETURN jsonb_build_object(
    'peminjaman_id', p_peminjaman_id,
    'return_inspection_id', p_return_inspection_id,
    'status', v_return_status,
    'status_pembayaran', v_payment_status,
    'denda', p_denda,
    'diperiksa_pada', now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.konfirmasi_pembayaran_denda(
  p_peminjaman_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_user_id UUID := auth.uid();
  v_inspection public.return_inspections%ROWTYPE;
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Silakan masuk terlebih dahulu.';
  END IF;

  PERFORM 1
  FROM public.peminjaman AS p
  WHERE p.id = p_peminjaman_id
    AND p.peminjam_id = v_user_id
    AND p.status = 'pelanggaran'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Pelanggaran tidak ditemukan atau bukan milik Anda.';
  END IF;

  SELECT ri.*
  INTO v_inspection
  FROM public.return_inspections AS ri
  WHERE ri.borrowing_id = p_peminjaman_id
    AND ri.status = 'menunggu_pembayaran'
    AND ri.status_pembayaran = 'menunggu_pembayaran'
  ORDER BY ri.dibuat_pada DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND
      OR v_inspection.status <> 'menunggu_pembayaran'
      OR v_inspection.status_pembayaran <> 'menunggu_pembayaran'
      OR v_inspection.denda <= 0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Tagihan tidak sedang menunggu pembayaran atau sudah dikonfirmasi.';
  END IF;

  UPDATE public.return_inspections
  SET status = 'selesai',
      status_pembayaran = 'dikonfirmasi',
      dibayar_pada = now(),
      selesai_pada = now(),
      updated_at = now()
  WHERE id = v_inspection.id;

  UPDATE public.peminjaman
  SET status = 'dikembalikan',
      dikembalikan_pada = now(),
      updated_at = now()
  WHERE id = p_peminjaman_id;

  INSERT INTO public.riwayat_kejadian (peminjaman_id, aktor_id, jenis, deskripsi)
  VALUES (
    p_peminjaman_id,
    v_user_id,
    'status_change',
    'Pengguna mengonfirmasi pembayaran denda secara simulasi. Transaksi selesai.'
  );

  RETURN jsonb_build_object(
    'peminjaman_id', p_peminjaman_id,
    'status', 'dikembalikan',
    'status_pembayaran', 'dikonfirmasi',
    'dibayar_pada', now()
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.selesaikan_pengembalian(
  p_peminjaman_id UUID,
  p_kondisi_barang TEXT,
  p_catatan TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  RAISE EXCEPTION USING ERRCODE = '22023',
    MESSAGE = 'Gunakan alur scan QR dan pemeriksaan pengembalian terbaru.';
END;
$$;

REVOKE ALL ON FUNCTION public.ajukan_pengembalian(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajukan_pengembalian(UUID) TO authenticated;

REVOKE ALL ON FUNCTION public.buat_tiket_qr(UUID, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.buat_tiket_qr(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.proses_qr_pengembalian_admin(TEXT, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.proses_qr_pengembalian_admin(TEXT, UUID)
  TO authenticated;

REVOKE ALL ON FUNCTION public.proses_qr_admin(TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.proses_qr_admin(TEXT) TO authenticated;

CREATE OR REPLACE FUNCTION public.proses_peminjaman_admin(
  p_peminjaman_id UUID,
  p_status TEXT,
  p_alasan_penolakan TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF p_status IS NULL OR p_status NOT IN ('disetujui', 'ditolak') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Status peminjaman hanya dapat disetujui atau ditolak melalui aksi admin.';
  END IF;

  PERFORM public.proses_peminjaman_admin_qr_legacy(
    p_peminjaman_id,
    p_status,
    p_alasan_penolakan
  );
END;
$$;

REVOKE ALL ON FUNCTION public.proses_peminjaman_admin(UUID, TEXT, TEXT)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.proses_peminjaman_admin(UUID, TEXT, TEXT)
  TO authenticated;

REVOKE ALL ON FUNCTION public.selesaikan_pemeriksaan_pengembalian(
  UUID, UUID, TEXT, NUMERIC, TEXT, JSONB
) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.selesaikan_pemeriksaan_pengembalian(
  UUID, UUID, TEXT, NUMERIC, TEXT, JSONB
) TO authenticated;

REVOKE ALL ON FUNCTION public.konfirmasi_pembayaran_denda(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.konfirmasi_pembayaran_denda(UUID)
  TO authenticated;

REVOKE ALL ON FUNCTION public.selesaikan_pengembalian(UUID, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
