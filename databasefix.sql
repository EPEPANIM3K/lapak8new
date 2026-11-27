-- =============================================================================
-- databasefix.sql — Unified PostgreSQL/Supabase DDL, RLS, Triggers & Functions
-- Reconciles: database/schema_baru.sql (Indonesian), database/schema.sql (English),
--             tooling/lapak8_api_server/schema.sql (MySQL REST),
--             database/existing_users_auth_rls.sql (bigint migration)
-- =============================================================================
-- DESIGN OBJECTIVES
-- 1. Canonical naming follows database/schema_baru.sql (Indonesian: pengguna, fasilitas, etc.)
-- 2. Role naming: peran='siswa'|'guru'|'staf'|'admin'  (Indonesian)  |
--    English aliases: student|teacher|staff|admin  (via profiles view)
-- 3. Status flow unified:
--    DB status: menunggu_persetujuan | disetujui | ditolak | dibatalkan | dipinjam | dikembalikan | terlambat
--    English: pending_approval | approved | rejected | cancelled | borrowed | returned | overdue
--    REST: pending | approved | rejected | returned | cancelled
-- 4. Includes supporting tables not in baseline (categories, time_slots, rules, facility_pics,
--    notifications, activity_logs, return_documentation, return_inspections) for complete app coverage.
-- 5. Idempotent: uses CREATE TABLE IF NOT EXISTS / DROP ... CREATE ... pattern safe for SupSQL Editor.
-- =============================================================================

-- -------------------------------------------------------------
-- EXTENSIONS
-- -------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- -------------------------------------------------------------
-- CORE TABLES (canonical Indonesian naming, per schema_baru.sql)
-- -------------------------------------------------------------

-- Table: public.lokasi (locations)
CREATE TABLE IF NOT EXISTS public.lokasi (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama TEXT NOT NULL,
  deskripsi TEXT,
  aktif BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.fasilitas (facilities)
CREATE TABLE IF NOT EXISTS public.fasilitas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama TEXT NOT NULL,
  kategori TEXT NOT NULL DEFAULT 'SARPRAS UMUM',
  lokasi_id UUID REFERENCES public.lokasi(id) ON DELETE SET NULL,
  total_unit INTEGER DEFAULT 0,
  status TEXT DEFAULT 'tersedia' CHECK (status IN ('tersedia','pemeliharaan','tidak_aktif')),
  foto_url TEXT,
  aktif BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.fasilitas
  ADD COLUMN IF NOT EXISTS kategori TEXT NOT NULL DEFAULT 'SARPRAS UMUM';

-- Table: public.aset_fasilitas (facility_assets / inventory items under a facility)
CREATE TABLE IF NOT EXISTS public.aset_fasilitas (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fasilitas_id UUID REFERENCES public.fasilitas(id) ON DELETE CASCADE,
  nama TEXT NOT NULL,
  deskripsi TEXT,
  kondisi TEXT DEFAULT 'baik' CHECK (kondisi IN ('baik','rusak','perawatan')),
  kuantitas INTEGER DEFAULT 1,
  lokasi_simpanan TEXT,
  foto_url TEXT,
  aktif BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.pengguna (users) — canonical Indonesian fields
-- Maps to: siswa/guru/staf/admin  /  nomor_induk/nama_lengkap/kelas_atau_unit
-- id references auth.users for Supabase Auth integration.
-- auth_id is retained only as an unused legacy compatibility column.
CREATE TABLE IF NOT EXISTS public.pengguna (
  id UUID PRIMARY KEY REFERENCES auth.users (id) ON DELETE CASCADE,
  nama_lengkap TEXT NOT NULL,
  email TEXT UNIQUE,
  nomor_induk TEXT UNIQUE,          -- NISN / NIP
  peran TEXT NOT NULL DEFAULT 'siswa'
    CHECK (peran IN ('siswa','guru','staf','admin')),
  kelas_atau_unit TEXT,             -- kelas | unit_staf | unit_admin
  telepon TEXT,
  foto_url TEXT,
  notifikasi_aktif BOOLEAN NOT NULL DEFAULT TRUE,
  aktif BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.pengguna
  ADD COLUMN IF NOT EXISTS notifikasi_aktif BOOLEAN NOT NULL DEFAULT TRUE;

-- Table: public.peminjaman (borrowings)
CREATE TABLE IF NOT EXISTS public.peminjaman (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  kode_booking TEXT UNIQUE NOT NULL,          -- format: LPK-YYYYMMDD-XXXXX
  peminjam_id UUID REFERENCES public.pengguna(id) ON DELETE RESTRICT,
  kategori TEXT NOT NULL CHECK (kategori IN ('praktik','ekskul','lainnya')),
  nama_kegiatan TEXT NOT NULL,
  catatan_tujuan TEXT,
  mulai_pada TIMESTAMPTZ NOT NULL,
  estimasi_kembali_pada TIMESTAMPTZ NOT NULL,
  status TEXT NOT NULL DEFAULT 'menunggu_persetujuan'
    CHECK (status IN ('menunggu_persetujuan','disetujui','ditolak','dibatalkan','dipinjam','dikembalikan','terlambat')),
  diajukan_pada TIMESTAMPTZ DEFAULT now(),
  disetujui_pada TIMESTAMPTZ,
  diambil_pada TIMESTAMPTZ,
  dikembalikan_pada TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.peminjaman
  ADD COLUMN IF NOT EXISTS alasan_penolakan TEXT;

-- Table: public.item_peminjaman (borrowing items — many-to-many between borrowing & facility asset)
CREATE TABLE IF NOT EXISTS public.item_peminjaman (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  peminjaman_id UUID REFERENCES public.peminjaman(id) ON DELETE CASCADE,
  aset_fasilitas_id UUID REFERENCES public.aset_fasilitas(id) ON DELETE RESTRICT,
  jumlah INTEGER NOT NULL DEFAULT 1 CHECK (jumlah > 0),
  nama_fasilitas_snapshot TEXT NOT NULL,  -- denormalized name for quick display
  created_at TIMESTAMPTZ DEFAULT now()
);

ALTER TABLE public.item_peminjaman
  ADD COLUMN IF NOT EXISTS fasilitas_id UUID REFERENCES public.fasilitas(id) ON DELETE RESTRICT;

UPDATE public.item_peminjaman AS item
SET fasilitas_id = aset.fasilitas_id
FROM public.aset_fasilitas AS aset
WHERE item.aset_fasilitas_id = aset.id
  AND item.fasilitas_id IS NULL
  AND aset.fasilitas_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_item_peminjaman_fasilitas_id
  ON public.item_peminjaman (fasilitas_id);

-- Table: public.persetujuan_peminjaman (borrowing approvals — workflow step)
CREATE TABLE IF NOT EXISTS public.persetujuan_peminjaman (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  peminjaman_id UUID REFERENCES public.peminjaman(id) ON DELETE CASCADE,
  evaluator_id UUID REFERENCES public.pengguna(id) ON DELETE SET NULL,
  status TEXT NOT NULL DEFAULT 'menunggu' CHECK (status IN ('menunggu','disetujui','ditolak')),
  alasan_penolakan TEXT,
  dibuat_pada TIMESTAMPTZ DEFAULT now(),
  disetujui_pada TIMESTAMPTZ
);

-- Table: public.penugasan_aset (borrowing asset assignments — links borrowing items to borrowers)
CREATE TABLE IF NOT EXISTS public.penugasan_aset (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  item_peminjaman_id UUID REFERENCES public.item_peminjaman(id) ON DELETE CASCADE,
  peminjam_id UUID REFERENCES public.pengguna(id) ON DELETE RESTRICT,
  assigned_at TIMESTAMPTZ DEFAULT now(),
  dikembalikan BOOLEAN DEFAULT FALSE
);

-- Table: public.tiket_qr (borrowing QR tickets)
CREATE TABLE IF NOT EXISTS public.tiket_qr (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  peminjaman_id UUID REFERENCES public.peminjaman(id) ON DELETE CASCADE,
  kode_qr TEXT UNIQUE NOT NULL,
  dibuat_pada TIMESTAMPTZ DEFAULT now(),
  expired_at TIMESTAMPTZ
);

-- Table: public.riwayat_kejadian (activity logs / incident history)
CREATE TABLE IF NOT EXISTS public.riwayat_kejadian (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  peminjaman_id UUID REFERENCES public.peminjaman(id) ON DELETE SET NULL,
  aktor_id UUID REFERENCES public.pengguna(id) ON DELETE SET NULL,
  jenis TEXT NOT NULL DEFAULT 'status_change' CHECK (jenis IN ('status_change','penugasan','keterlambatan','lainnya')),
  deskripsi TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.percakapan (chat threads)
CREATE TABLE IF NOT EXISTS public.percakapan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  peminjaman_id UUID REFERENCES public.peminjaman(id) ON DELETE CASCADE,
  judul TEXT NOT NULL DEFAULT 'Diskusi peminjaman',
  dibuat_oleh UUID REFERENCES public.pengguna(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.peserta_percakapan (chat participants)
CREATE TABLE IF NOT EXISTS public.peserta_percakapan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  percakapan_id UUID REFERENCES public.percakapan(id) ON DELETE CASCADE,
  pengguna_id UUID REFERENCES public.pengguna(id) ON DELETE CASCADE,
  role_dalam_percakapan TEXT DEFAULT 'siswa' CHECK (role_dalam_percakapan IN ('siswa','guru','staf','admin')),
  added_at TIMESTAMPTZ DEFAULT now(),
  UNIQUE (percakapan_id, pengguna_id)
);

-- Table: public.pesan (chat messages)
CREATE TABLE IF NOT EXISTS public.pesan (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  percakapan_id UUID REFERENCES public.percakapan(id) ON DELETE CASCADE,
  pengirim_id UUID REFERENCES public.pengguna(id) ON DELETE SET NULL,
  penerima_id UUID REFERENCES public.pengguna(id) ON DELETE SET NULL,
  isi_teks TEXT NOT NULL,
  isi_attachment JSONB,  -- optional: {file_url, type, ...}
  created_at TIMESTAMPTZ DEFAULT now()
);

-- -------------------------------------------------------------
-- SUPPORTING TABLES (present in at least 2 of the 3 schemas / migration)
-- -------------------------------------------------------------

-- Table: public.categories (item categories / loan types)
CREATE TABLE IF NOT EXISTS public.categories (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama TEXT NOT NULL UNIQUE,
  deskripsi TEXT,
  aktif BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.time_slots (time slot slots for borrowing periods)
CREATE TABLE IF NOT EXISTS public.time_slots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  peminjaman_id UUID REFERENCES public.peminjaman(id) ON DELETE CASCADE,
  mulai_pada TIMESTAMPTZ NOT NULL,
  selesai_pada TIMESTAMPTZ NOT NULL,
  is_aktif BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.rules (borrowing rules / policies)
CREATE TABLE IF NOT EXISTS public.rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  nama TEXT NOT NULL,
  deskripsi TEXT,
  syarat_teks TEXT NOT NULL,
  jenis TEXT NOT NULL DEFAULT 'umum' CHECK (jenis IN ('umum','fasilitas','aset')),
  aktif BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.facility_pics (facility photos)
CREATE TABLE IF NOT EXISTS public.facility_pics (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fasilitas_id UUID REFERENCES public.fasilitas(id) ON DELETE CASCADE,
  url TEXT NOT NULL,
  caption TEXT,
  uploaded_by UUID REFERENCES public.pengguna(id) ON DELETE SET NULL,
  uploaded_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.notifications (system notifications)
CREATE TABLE IF NOT EXISTS public.notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.pengguna(id) ON DELETE CASCADE,
  judul TEXT NOT NULL,
  isi TEXT NOT NULL,
  jenis TEXT NOT NULL DEFAULT 'info' CHECK (jenis IN ('info','warning','success','error')),
  related_entity TEXT,     -- e.g. 'peminjaman_id:uuid'
  related_id UUID,
  sudah_dibaca BOOLEAN DEFAULT FALSE,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Table: public.return_inspections (internal inspection records)
CREATE TABLE IF NOT EXISTS public.return_inspections (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  borrowing_id UUID REFERENCES public.peminjaman(id) ON DELETE CASCADE,
  inspektor_id UUID REFERENCES public.pengguna(id) ON DELETE SET NULL,
  inspection_code TEXT,                 -- external/API inspection id, e.g. KM-2024-031
  status TEXT NOT NULL DEFAULT 'menunggu' CHECK (status IN ('menunggu','selesai','disetujui','ditolak')),
  catatan_akhir TEXT,
  dibuat_pada TIMESTAMPTZ NOT NULL DEFAULT now(),
  selesai_pada TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Table: public.return_documentation (external inspection file metadata)
-- Files are stored by the external storage server; DB stores metadata/compatibility only.
-- External API contract: /api/v1/inspections/:returnId/docs|upload|files/:fileId|file/:fileId
CREATE TABLE IF NOT EXISTS public.return_documentation (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  borrowing_id UUID REFERENCES public.peminjaman(id) ON DELETE CASCADE,
  return_inspection_id UUID REFERENCES public.return_inspections(id) ON DELETE SET NULL,
  inspection_id TEXT NOT NULL,          -- external returnId/inspection code used by storage API
  item_id UUID REFERENCES public.item_peminjaman(id) ON DELETE SET NULL,
  file_id TEXT,                         -- external file id from storage API
  jenis TEXT NOT NULL DEFAULT 'photo' CHECK (jenis IN ('photo','video')),
  file_name TEXT,
  file_path TEXT NOT NULL,              -- relative API path: /api/v1/inspections/<inspectionId>/file/<fileId>
  mime_type TEXT,
  ukuran_byte BIGINT NOT NULL DEFAULT 0,
  diunggah_oleh UUID REFERENCES public.pengguna(id) ON DELETE SET NULL,
  diunggah_pada TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT return_documentation_inspection_id_not_blank CHECK (nullif(trim(inspection_id), '') IS NOT NULL)
);

-- -------------------------------------------------------------
-- FUNCTIONS (security helpers, triggers, migration compat)
-- -------------------------------------------------------------

-- Helper: current user role (Indonesian: 'siswa'|'guru'|'staf'|'admin')
CREATE OR REPLACE FUNCTION public.peran_pengguna_saat_ini()
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT peran FROM public.pengguna WHERE id = auth.uid() AND aktif = true;
$$;

-- Helper: is current user admin?
CREATE OR REPLACE FUNCTION public.adalah_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    (SELECT peran = 'admin' FROM public.pengguna WHERE id = auth.uid() AND aktif = true),
    false
  );
$$;

-- Helper: is current user admin or staf? (used in RLS policies)
CREATE OR REPLACE FUNCTION public.adalah_admin_atau_staf()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    (SELECT peran IN ('admin','staf') FROM public.pengguna WHERE id = auth.uid() AND aktif = true),
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.ajukan_peminjaman(
  p_kategori TEXT,
  p_nama_kegiatan TEXT,
  p_mulai_pada TIMESTAMPTZ,
  p_estimasi_kembali_pada TIMESTAMPTZ,
  p_items JSONB,
  p_catatan_tujuan TEXT DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_peminjam_id UUID := auth.uid();
  v_peminjaman_id UUID;
  v_kode_booking TEXT;
  v_percobaan INTEGER := 0;
  v_item JSONB;
  v_fasilitas_id UUID;
  v_jumlah INTEGER;
  v_nama_fasilitas TEXT;
  v_total_unit INTEGER;
  v_status_fasilitas TEXT;
  v_aktif BOOLEAN;
  v_aktif_pengguna BOOLEAN;
  v_fasilitas_terpilih UUID[] := ARRAY[]::UUID[];
BEGIN
  IF v_peminjam_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Silakan masuk terlebih dahulu.';
  END IF;

  SELECT pengguna.aktif
  INTO v_aktif_pengguna
  FROM public.pengguna AS pengguna
  WHERE pengguna.id = v_peminjam_id;

  IF NOT FOUND OR v_aktif_pengguna IS DISTINCT FROM TRUE THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Akun tidak aktif atau tidak ditemukan.';
  END IF;

  IF p_kategori IS NULL
     OR p_kategori NOT IN ('praktik', 'ekskul', 'lainnya')
     OR nullif(trim(p_nama_kegiatan), '') IS NULL
     OR p_mulai_pada IS NULL
     OR p_estimasi_kembali_pada IS NULL
     OR p_mulai_pada <= now()
     OR p_estimasi_kembali_pada <= p_mulai_pada THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Data peminjaman atau rentang waktunya tidak valid.';
  END IF;

  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Daftar fasilitas tidak valid.';
  END IF;

  IF jsonb_array_length(p_items) = 0 OR jsonb_array_length(p_items) > 50 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Daftar fasilitas tidak valid.';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    IF jsonb_typeof(v_item) <> 'object' THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Format fasilitas tidak valid.';
    END IF;

    BEGIN
      v_fasilitas_id := nullif(v_item ->> 'fasilitas_id', '')::UUID;
      v_jumlah := nullif(v_item ->> 'jumlah', '')::INTEGER;
    EXCEPTION
      WHEN invalid_text_representation OR numeric_value_out_of_range THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'ID fasilitas atau jumlah tidak valid.';
    END;

    IF v_fasilitas_id IS NULL OR v_jumlah IS NULL OR v_jumlah < 1 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Jumlah fasilitas minimal satu unit.';
    END IF;

    IF v_fasilitas_id = ANY(v_fasilitas_terpilih) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Fasilitas yang sama tidak boleh dicantumkan lebih dari sekali.';
    END IF;
    v_fasilitas_terpilih := array_append(v_fasilitas_terpilih, v_fasilitas_id);

    SELECT fasilitas.nama, coalesce(fasilitas.total_unit, 0), fasilitas.status, fasilitas.aktif
    INTO v_nama_fasilitas, v_total_unit, v_status_fasilitas, v_aktif
    FROM public.fasilitas AS fasilitas
    WHERE fasilitas.id = v_fasilitas_id;

    IF NOT FOUND OR v_aktif IS DISTINCT FROM TRUE OR v_status_fasilitas <> 'tersedia' THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Fasilitas tidak tersedia.';
    END IF;

    IF v_jumlah > v_total_unit THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Jumlah yang diajukan melebihi stok fasilitas.';
    END IF;
  END LOOP;

  LOOP
    v_percobaan := v_percobaan + 1;
    v_kode_booking := 'LPK-' || to_char(now(), 'YYYYMMDD') || '-' ||
      upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 5));

    BEGIN
      INSERT INTO public.peminjaman (
        kode_booking, peminjam_id, kategori, nama_kegiatan, catatan_tujuan,
        mulai_pada, estimasi_kembali_pada, status
      )
      VALUES (
        v_kode_booking, v_peminjam_id, p_kategori, trim(p_nama_kegiatan),
        nullif(trim(p_catatan_tujuan), ''), p_mulai_pada,
        p_estimasi_kembali_pada, 'menunggu_persetujuan'
      )
      RETURNING id INTO v_peminjaman_id;
      EXIT;
    EXCEPTION
      WHEN unique_violation THEN
        IF v_percobaan >= 5 THEN
          RAISE;
        END IF;
    END;
  END LOOP;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_items)
  LOOP
    v_fasilitas_id := (v_item ->> 'fasilitas_id')::UUID;
    v_jumlah := (v_item ->> 'jumlah')::INTEGER;

    INSERT INTO public.item_peminjaman (
      peminjaman_id, fasilitas_id, jumlah, nama_fasilitas_snapshot
    )
    SELECT v_peminjaman_id, fasilitas.id, v_jumlah, fasilitas.nama
    FROM public.fasilitas AS fasilitas
    WHERE fasilitas.id = v_fasilitas_id;
  END LOOP;

  INSERT INTO public.persetujuan_peminjaman (peminjaman_id, status)
  VALUES (v_peminjaman_id, 'menunggu');

  INSERT INTO public.riwayat_kejadian (peminjaman_id, aktor_id, jenis, deskripsi)
  VALUES (v_peminjaman_id, v_peminjam_id, 'status_change', 'Pengajuan dikirim untuk menunggu persetujuan admin.');

  RETURN v_peminjaman_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.batalkan_peminjaman(p_peminjaman_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_peminjam_id UUID := auth.uid();
  v_peminjaman_peminjam_id UUID;
  v_status TEXT;
BEGIN
  IF v_peminjam_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Silakan masuk terlebih dahulu.';
  END IF;

  SELECT peminjaman.peminjam_id, peminjaman.status
  INTO v_peminjaman_peminjam_id, v_status
  FROM public.peminjaman AS peminjaman
  WHERE peminjaman.id = p_peminjaman_id
  FOR UPDATE;

  IF NOT FOUND
     OR v_peminjaman_peminjam_id <> v_peminjam_id
     OR v_status <> 'menunggu_persetujuan' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Peminjaman tidak dapat dibatalkan.';
  END IF;

  UPDATE public.peminjaman
  SET status = 'dibatalkan', updated_at = now()
  WHERE id = p_peminjaman_id;

  DELETE FROM public.persetujuan_peminjaman
  WHERE peminjaman_id = p_peminjaman_id AND status = 'menunggu';

  INSERT INTO public.riwayat_kejadian (peminjaman_id, aktor_id, jenis, deskripsi)
  VALUES (p_peminjaman_id, v_peminjam_id, 'status_change', 'Pengajuan dibatalkan oleh peminjam.');
END;
$$;

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
DECLARE
  v_aktor_id UUID := auth.uid();
  v_status_lama TEXT;
  v_mulai_pada TIMESTAMPTZ;
  v_estimasi_kembali_pada TIMESTAMPTZ;
  v_item RECORD;
  v_total_unit INTEGER;
  v_status_fasilitas TEXT;
  v_aktif BOOLEAN;
  v_dipesan INTEGER;
  v_alasan TEXT := nullif(trim(p_alasan_penolakan), '');
BEGIN
  IF v_aktor_id IS NULL OR NOT public.adalah_admin_atau_staf() THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Hanya admin atau staf aktif yang dapat memproses peminjaman.';
  END IF;

  IF p_status IS NULL
     OR p_status NOT IN ('disetujui', 'ditolak', 'dipinjam', 'dikembalikan', 'terlambat') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Status peminjaman tidak valid.';
  END IF;

  SELECT peminjaman.status, peminjaman.mulai_pada,
         peminjaman.estimasi_kembali_pada
  INTO v_status_lama, v_mulai_pada, v_estimasi_kembali_pada
  FROM public.peminjaman AS peminjaman
  WHERE peminjaman.id = p_peminjaman_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Peminjaman tidak ditemukan.';
  END IF;

  IF NOT (
    (v_status_lama = 'menunggu_persetujuan' AND p_status IN ('disetujui', 'ditolak'))
    OR (v_status_lama = 'disetujui' AND p_status = 'dipinjam')
    OR (v_status_lama = 'dipinjam' AND p_status IN ('dikembalikan', 'terlambat'))
    OR (v_status_lama = 'terlambat' AND p_status = 'dikembalikan')
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Perubahan status tidak sesuai alur peminjaman.';
  END IF;

  IF p_status = 'ditolak' AND v_alasan IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Alasan penolakan wajib diisi.';
  END IF;

  IF p_status = 'disetujui' THEN
    IF EXISTS (
      SELECT 1
      FROM public.item_peminjaman AS item
      WHERE item.peminjaman_id = p_peminjaman_id AND item.fasilitas_id IS NULL
    ) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Data fasilitas peminjaman belum lengkap.';
    END IF;

    PERFORM fasilitas.id
    FROM public.fasilitas AS fasilitas
    JOIN (
      SELECT DISTINCT item.fasilitas_id
      FROM public.item_peminjaman AS item
      WHERE item.peminjaman_id = p_peminjaman_id
    ) AS diminta ON diminta.fasilitas_id = fasilitas.id
    ORDER BY fasilitas.id
    FOR UPDATE OF fasilitas;

    FOR v_item IN
      SELECT item.fasilitas_id, sum(item.jumlah)::INTEGER AS jumlah
      FROM public.item_peminjaman AS item
      WHERE item.peminjaman_id = p_peminjaman_id
      GROUP BY item.fasilitas_id
      ORDER BY item.fasilitas_id
    LOOP
      SELECT coalesce(fasilitas.total_unit, 0), fasilitas.status, fasilitas.aktif
      INTO v_total_unit, v_status_fasilitas, v_aktif
      FROM public.fasilitas AS fasilitas
      WHERE fasilitas.id = v_item.fasilitas_id;

      IF NOT FOUND OR v_aktif IS DISTINCT FROM TRUE OR v_status_fasilitas <> 'tersedia' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Salah satu fasilitas sedang tidak tersedia.';
      END IF;

      WITH overlapping AS (
        SELECT peminjaman.mulai_pada, peminjaman.estimasi_kembali_pada,
               peminjaman.status, item.jumlah
        FROM public.item_peminjaman AS item
        JOIN public.peminjaman AS peminjaman ON peminjaman.id = item.peminjaman_id
        WHERE item.fasilitas_id = v_item.fasilitas_id
          AND peminjaman.id <> p_peminjaman_id
          AND peminjaman.status IN ('disetujui', 'dipinjam', 'terlambat')
          AND peminjaman.mulai_pada < v_estimasi_kembali_pada
          AND CASE
                WHEN peminjaman.status IN ('dipinjam', 'terlambat')
                  THEN 'infinity'::TIMESTAMPTZ
                ELSE peminjaman.estimasi_kembali_pada
              END > v_mulai_pada
      ),
      events AS (
        SELECT greatest(overlapping.mulai_pada, v_mulai_pada) AS waktu,
               overlapping.jumlah::BIGINT AS perubahan
        FROM overlapping
        UNION ALL
        SELECT least(
                 CASE
                   WHEN overlapping.status IN ('dipinjam', 'terlambat')
                     THEN 'infinity'::TIMESTAMPTZ
                   ELSE overlapping.estimasi_kembali_pada
                 END,
                 v_estimasi_kembali_pada
               ),
               -overlapping.jumlah::BIGINT
        FROM overlapping
      ),
      grouped_events AS (
        SELECT events.waktu, sum(events.perubahan) AS perubahan
        FROM events
        GROUP BY events.waktu
      ),
      pemakaian AS (
        SELECT sum(grouped_events.perubahan) OVER (
          ORDER BY grouped_events.waktu
          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS jumlah
        FROM grouped_events
      )
      SELECT kapasitas.jumlah
      INTO v_dipesan
      FROM (SELECT coalesce(max(pemakaian.jumlah), 0)::INTEGER AS jumlah FROM pemakaian) AS kapasitas;

      IF v_dipesan + v_item.jumlah > v_total_unit THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Stok fasilitas tidak cukup pada waktu yang dipilih.';
      END IF;
    END LOOP;
  END IF;

  UPDATE public.peminjaman
  SET status = p_status,
      alasan_penolakan = CASE WHEN p_status = 'ditolak' THEN v_alasan ELSE NULL END,
      disetujui_pada = CASE WHEN p_status = 'disetujui' THEN now() ELSE disetujui_pada END,
      diambil_pada = CASE WHEN p_status = 'dipinjam' THEN now() ELSE diambil_pada END,
      dikembalikan_pada = CASE WHEN p_status = 'dikembalikan' THEN now() ELSE dikembalikan_pada END,
      updated_at = now()
  WHERE id = p_peminjaman_id;

  IF v_status_lama = 'menunggu_persetujuan' THEN
    UPDATE public.persetujuan_peminjaman
    SET evaluator_id = v_aktor_id,
        status = CASE WHEN p_status = 'disetujui' THEN 'disetujui' ELSE 'ditolak' END,
        alasan_penolakan = CASE WHEN p_status = 'ditolak' THEN v_alasan ELSE NULL END,
        disetujui_pada = now()
    WHERE peminjaman_id = p_peminjaman_id AND status = 'menunggu';

    IF NOT FOUND THEN
      INSERT INTO public.persetujuan_peminjaman (
        peminjaman_id, evaluator_id, status, alasan_penolakan, disetujui_pada
      )
      VALUES (
        p_peminjaman_id, v_aktor_id,
        CASE WHEN p_status = 'disetujui' THEN 'disetujui' ELSE 'ditolak' END,
        CASE WHEN p_status = 'ditolak' THEN v_alasan ELSE NULL END,
        now()
      );
    END IF;
  END IF;

  INSERT INTO public.riwayat_kejadian (peminjaman_id, aktor_id, jenis, deskripsi)
  VALUES (
    p_peminjaman_id, v_aktor_id, 'status_change',
    'Status peminjaman diubah dari ' || v_status_lama || ' menjadi ' || p_status ||
      CASE WHEN p_status = 'ditolak' THEN '. Alasan: ' || v_alasan ELSE '.' END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.ajukan_peminjaman(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, TEXT) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.batalkan_peminjaman(UUID) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.proses_peminjaman_admin(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ajukan_peminjaman(TEXT, TEXT, TIMESTAMPTZ, TIMESTAMPTZ, JSONB, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.batalkan_peminjaman(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION public.proses_peminjaman_admin(UUID, TEXT, TEXT) TO authenticated;

-- -------------------------------------------------------------
-- Legacy policy helper — use the canonical Supabase user table.
-- -------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_lapak8_admin()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    (SELECT peran = 'admin' FROM public.pengguna WHERE id = auth.uid() AND aktif = true),
    false
  );
$$;

REVOKE ALL ON FUNCTION public.is_lapak8_admin() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_lapak8_admin() TO authenticated;

-- Compatibility view: profiles
-- Maps canonical Indonesian pengguna rows to the English profile shape expected by
-- older Supabase/admin tooling. This is a read-compatibility view; canonical writes go to pengguna.
CREATE OR REPLACE VIEW public.profiles
WITH (security_invoker = true)
AS
SELECT
  u.id,
  u.nama_lengkap AS full_name,
  u.email,
  u.nomor_induk AS identity_number,
  u.kelas_atau_unit AS class_or_unit,
  u.telepon AS phone,
  CASE u.peran
    WHEN 'siswa' THEN 'student'
    WHEN 'guru' THEN 'teacher'
    WHEN 'staf' THEN 'staff'
    WHEN 'admin' THEN 'admin'
    ELSE u.peran
  END AS role,
  u.aktif AS is_active,
  u.created_at,
  u.updated_at
FROM public.pengguna AS u;

-- -------------------------------------------------------------
-- TRIGGERS — updated_at timestamp maintenance
-- -------------------------------------------------------------

-- Helper function: set_updated_at
CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;

-- Auth sync: create a pengguna row when a new Supabase auth user is created.
CREATE OR REPLACE FUNCTION public.tangani_pengguna_auth_baru()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_nama text;
  v_peran text;
BEGIN
  v_nama := coalesce(
    nullif(trim(new.raw_user_meta_data ->> 'nama_lengkap'), ''),
    nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''),
    nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
    'Pengguna'
  );

  v_peran := lower(coalesce(new.raw_user_meta_data ->> 'peran', new.raw_user_meta_data ->> 'role', 'siswa'));
  IF v_peran NOT IN ('siswa', 'guru', 'staf', 'admin') THEN
    v_peran := 'siswa';
  END IF;

  INSERT INTO public.pengguna (
    id,
    nama_lengkap,
    email,
    nomor_induk,
    peran,
    kelas_atau_unit,
    telepon,
    aktif
  )
  VALUES (
    new.id,
    v_nama,
    new.email,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'nomor_induk', new.raw_user_meta_data ->> 'identity_number', '')), ''),
    v_peran,
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'kelas_atau_unit', new.raw_user_meta_data ->> 'class_or_unit', '')), ''),
    nullif(trim(coalesce(new.raw_user_meta_data ->> 'telepon', new.raw_user_meta_data ->> 'phone', '')), ''),
    true
  )
  ON CONFLICT (id) DO UPDATE
  SET email = EXCLUDED.email,
      nama_lengkap = CASE
        WHEN public.pengguna.nama_lengkap IS NULL OR btrim(public.pengguna.nama_lengkap) = '' THEN EXCLUDED.nama_lengkap
        ELSE public.pengguna.nama_lengkap
      END,
      updated_at = now();

  RETURN new;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.tangani_pengguna_auth_baru();

-- Canonical admin profile update used by the Flutter admin repository.
CREATE OR REPLACE FUNCTION public.admin_perbarui_pengguna(
  p_pengguna_id uuid,
  p_nama_lengkap text,
  p_telepon text,
  p_nomor_induk text,
  p_kelas_atau_unit text,
  p_peran text,
  p_aktif boolean
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT public.adalah_admin() THEN
    RAISE EXCEPTION 'Hanya admin yang boleh mengubah data pengguna';
  END IF;

  IF p_peran IS NOT NULL AND p_peran NOT IN ('siswa', 'guru', 'staf') THEN
    RAISE EXCEPTION 'Peran tidak valid. Pilih: siswa, guru, atau staf';
  END IF;

  IF p_nama_lengkap IS NOT NULL AND nullif(trim(p_nama_lengkap), '') IS NULL THEN
    RAISE EXCEPTION 'Nama lengkap tidak boleh kosong';
  END IF;

  UPDATE public.pengguna
  SET
    nama_lengkap = coalesce(nullif(trim(p_nama_lengkap), ''), nama_lengkap),
    telepon = p_telepon,
    nomor_induk = p_nomor_induk,
    kelas_atau_unit = p_kelas_atau_unit,
    peran = coalesce(p_peran, peran),
    aktif = coalesce(p_aktif, aktif),
    updated_at = now()
  WHERE id = p_pengguna_id
    AND peran <> 'admin';

  IF NOT FOUND THEN
    RAISE EXCEPTION 'Pengguna tidak ditemukan atau akun admin tidak dapat diubah';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.admin_perbarui_pengguna(uuid, text, text, text, text, text, boolean) FROM public;
GRANT EXECUTE ON FUNCTION public.admin_perbarui_pengguna(uuid, text, text, text, text, text, boolean) TO authenticated;

-- updated_at triggers on canonical tables
DROP TRIGGER IF EXISTS pengguna_set_updated_at ON public.pengguna;
CREATE TRIGGER pengguna_set_updated_at
  BEFORE UPDATE ON public.pengguna
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS lokasi_set_updated_at ON public.lokasi;
CREATE TRIGGER lokasi_set_updated_at
  BEFORE UPDATE ON public.lokasi
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS fasilitas_set_updated_at ON public.fasilitas;
CREATE TRIGGER fasilitas_set_updated_at
  BEFORE UPDATE ON public.fasilitas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS aset_fasilitas_set_updated_at ON public.aset_fasilitas;
CREATE TRIGGER aset_fasilitas_set_updated_at
  BEFORE UPDATE ON public.aset_fasilitas
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS peminjaman_set_updated_at ON public.peminjaman;
CREATE TRIGGER peminjaman_set_updated_at
  BEFORE UPDATE ON public.peminjaman
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS percakapan_set_updated_at ON public.percakapan;
CREATE TRIGGER percakapan_set_updated_at
  BEFORE UPDATE ON public.percakapan
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

DROP TRIGGER IF EXISTS return_documentation_set_updated_at ON public.return_documentation;
CREATE TRIGGER return_documentation_set_updated_at
  BEFORE UPDATE ON public.return_documentation
  FOR EACH ROW EXECUTE FUNCTION public.set_updated_at();

-- -------------------------------------------------------------
-- INDEXES
-- -------------------------------------------------------------

-- Core lookup indexes
CREATE INDEX IF NOT EXISTS idx_pengguna_peran_aktif ON public.pengguna (peran, aktif);
CREATE INDEX IF NOT EXISTS idx_pengguna_nomor_induk ON public.pengguna (nomor_induk) WHERE nomor_induk IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_peminjaman_peminjam_id ON public.peminjaman (peminjam_id);
CREATE INDEX IF NOT EXISTS idx_peminjaman_status ON public.peminjaman (status);
CREATE INDEX IF NOT EXISTS idx_peminjaman_kategori ON public.peminjaman (kategori);
CREATE INDEX IF NOT EXISTS idx_peminjaman_kode_booking ON public.peminjaman (kode_booking);
CREATE INDEX IF NOT EXISTS idx_item_peminjaman_aset_id ON public.item_peminjaman (aset_fasilitas_id);
CREATE INDEX IF NOT EXISTS idx_persetujuan_peminjaman_status ON public.persetujuan_peminjaman (status);
CREATE INDEX IF NOT EXISTS idx_penugasan_aset_item_id ON public.penugasan_aset (item_peminjaman_id);
CREATE INDEX IF NOT EXISTS idx_tiket_qr_peminjaman_id ON public.tiket_qr (peminjaman_id);
CREATE INDEX IF NOT EXISTS idx_riwayat_kejadian_peminjaman_id ON public.riwayat_kejadian (peminjaman_id);
CREATE INDEX IF NOT EXISTS idx_percakapan_peminjaman_id ON public.percakapan (peminjaman_id);
CREATE INDEX IF NOT EXISTS idx_peserta_percakapan_pengguna_id ON public.peserta_percakapan (pengguna_id);
CREATE INDEX IF NOT EXISTS idx_pesan_percakapan_id ON public.pesan (percakapan_id);
CREATE INDEX IF NOT EXISTS idx_fasilitas_lokasi_aktif ON public.fasilitas (lokasi_id, aktif) WHERE aktif;
CREATE INDEX IF NOT EXISTS idx_aset_fasilitas_fasilitas_id ON public.aset_fasilitas (fasilitas_id);
CREATE INDEX IF NOT EXISTS idx_categories_aktif ON public.categories (aktif);
CREATE INDEX IF NOT EXISTS idx_rules_jenis_aktif ON public.rules (jenis, aktif);
CREATE INDEX IF NOT EXISTS idx_facility_pics_fasilitas_id ON public.facility_pics (fasilitas_id);
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON public.notifications (user_id) WHERE NOT sudah_dibaca;
CREATE INDEX IF NOT EXISTS idx_return_documentation_borrowing_id ON public.return_documentation (borrowing_id);
CREATE INDEX IF NOT EXISTS idx_return_documentation_inspection_id ON public.return_documentation (inspection_id);
CREATE INDEX IF NOT EXISTS idx_return_inspections_borrowing_id ON public.return_inspections (borrowing_id);
CREATE INDEX IF NOT EXISTS idx_return_inspections_status ON public.return_inspections (status);

-- -------------------------------------------------------------
-- RLS POLICYS (unified across schemas)
-- -------------------------------------------------------------
ALTER TABLE public.pengguna ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lokasi ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fasilitas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.aset_fasilitas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.peminjaman ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.item_peminjaman ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.persetujuan_peminjaman ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.penugasan_aset ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tiket_qr ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.riwayat_kejadian ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.percakapan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.peserta_percakapan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pesan ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.time_slots ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.facility_pics ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_documentation ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.return_inspections ENABLE ROW LEVEL SECURITY;

-- ==== pengguna ====
DROP POLICY IF EXISTS pengguna_select_own ON public.pengguna;
CREATE POLICY pengguna_select_own ON public.pengguna
  FOR SELECT TO authenticated
  USING (id = auth.uid());

DROP POLICY IF EXISTS pengguna_manage_admin ON public.pengguna;
CREATE POLICY pengguna_manage_admin ON public.pengguna
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== lokasi ====
DROP POLICY IF EXISTS lokasi_baca_semua ON public.lokasi;
CREATE POLICY lokasi_baca_semua ON public.lokasi
  FOR SELECT TO authenticated USING (aktif OR public.adalah_admin_atau_staf());

DROP POLICY IF EXISTS lokasi_kelola_admin ON public.lokasi;
CREATE POLICY lokasi_kelola_admin ON public.lokasi
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== fasilitas ====
DROP POLICY IF EXISTS fasilitas_baca_semua ON public.fasilitas;
CREATE POLICY fasilitas_baca_semua ON public.fasilitas
  FOR SELECT TO authenticated USING (aktif OR public.adalah_admin_atau_staf());

DROP POLICY IF EXISTS fasilitas_kelola_admin ON public.fasilitas;
CREATE POLICY fasilitas_kelola_admin ON public.fasilitas
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== aset_fasilitas ====
DROP POLICY IF EXISTS aset_baca_aktif_atau_admin ON public.aset_fasilitas;
CREATE POLICY aset_baca_aktif_atau_admin ON public.aset_fasilitas
  FOR SELECT TO authenticated
  USING (aktif OR public.adalah_admin_atau_staf());

DROP POLICY IF EXISTS aset_kelola_admin ON public.aset_fasilitas;
CREATE POLICY aset_kelola_admin ON public.aset_fasilitas
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== peminjaman ====
DROP POLICY IF EXISTS peminjaman_baca_milik_atau_admin ON public.peminjaman;
CREATE POLICY peminjaman_baca_milik_atau_admin ON public.peminjaman
  FOR SELECT TO authenticated
  USING (peminjam_id = auth.uid() OR public.adalah_admin_atau_staf());

DROP POLICY IF EXISTS peminjaman_buat_sendiri ON public.peminjaman;

DROP POLICY IF EXISTS peminjaman_kelola_admin ON public.peminjaman;
CREATE POLICY peminjaman_kelola_admin ON public.peminjaman
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== item_peminjaman ====
DROP POLICY IF EXISTS item_baca_milik_atau_admin ON public.item_peminjaman;
CREATE POLICY item_baca_milik_atau_admin ON public.item_peminjaman
  FOR SELECT TO authenticated
  USING (public.adalah_admin_atau_staf()
     OR EXISTS (
       SELECT 1 FROM public.peminjaman p WHERE p.id = item_peminjaman.peminjaman_id AND p.peminjam_id = auth.uid()
     ));

DROP POLICY IF EXISTS item_buat_untuk_peminjaman_sendiri ON public.item_peminjaman;

DROP POLICY IF EXISTS item_kelola_admin ON public.item_peminjaman;
CREATE POLICY item_kelola_admin ON public.item_peminjaman
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== persetujuan_peminjaman ====
DROP POLICY IF EXISTS persetujuan_baca_milik_atau_admin ON public.persetujuan_peminjaman;
CREATE POLICY persetujuan_baca_milik_atau_admin ON public.persetujuan_peminjaman
  FOR SELECT TO authenticated
  USING (public.adalah_admin_atau_staf()
     OR EXISTS (
       SELECT 1 FROM public.peminjaman p WHERE p.id = persetujuan_peminjaman.peminjaman_id AND p.peminjam_id = auth.uid()
     ));

DROP POLICY IF EXISTS persetujuan_kelola_admin ON public.persetujuan_peminjaman;
CREATE POLICY persetujuan_kelola_admin ON public.persetujuan_peminjaman
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== riwayat_kejadian ====
DROP POLICY IF EXISTS riwayat_baca_milik_atau_admin ON public.riwayat_kejadian;
CREATE POLICY riwayat_baca_milik_atau_admin ON public.riwayat_kejadian
  FOR SELECT TO authenticated
  USING (public.adalah_admin_atau_staf()
     OR EXISTS (
       SELECT 1 FROM public.peminjaman p WHERE p.id = riwayat_kejadian.peminjaman_id AND p.peminjam_id = auth.uid()
     ));

DROP POLICY IF EXISTS riwayat_insert_admin ON public.riwayat_kejadian;
CREATE POLICY riwayat_insert_admin ON public.riwayat_kejadian
  FOR INSERT TO authenticated
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== penugasan_aset ====
DROP POLICY IF EXISTS penugasan_baca_milik_atau_admin ON public.penugasan_aset;
CREATE POLICY penugasan_baca_milik_atau_admin ON public.penugasan_aset
  FOR SELECT TO authenticated
  USING (
    public.adalah_admin_atau_staf()
    OR peminjam_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM public.item_peminjaman ip
      JOIN public.peminjaman p ON p.id = ip.peminjaman_id
      WHERE ip.id = penugasan_aset.item_peminjaman_id
        AND p.peminjam_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS penugasan_kelola_admin ON public.penugasan_aset;
CREATE POLICY penugasan_kelola_admin ON public.penugasan_aset
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== tiket_qr ====
DROP POLICY IF EXISTS tiket_qr_baca_milik_atau_admin ON public.tiket_qr;
CREATE POLICY tiket_qr_baca_milik_atau_admin ON public.tiket_qr
  FOR SELECT TO authenticated
  USING (
    public.adalah_admin_atau_staf()
    OR EXISTS (
      SELECT 1 FROM public.peminjaman p
      WHERE p.id = tiket_qr.peminjaman_id
        AND p.peminjam_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS tiket_qr_kelola_admin ON public.tiket_qr;
CREATE POLICY tiket_qr_kelola_admin ON public.tiket_qr
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== peserta_percakapan ====
DROP POLICY IF EXISTS peserta_baca_milik_atau_admin ON public.peserta_percakapan;
CREATE POLICY peserta_baca_milik_atau_admin ON public.peserta_percakapan
  FOR SELECT TO authenticated
  USING (public.adalah_admin_atau_staf() OR pengguna_id = auth.uid());

DROP POLICY IF EXISTS peserta_kelola_admin ON public.peserta_percakapan;
CREATE POLICY peserta_kelola_admin ON public.peserta_percakapan
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());

-- ==== percakapan ====
DROP POLICY IF EXISTS percakapan_baca_peserta_atau_admin ON public.percakapan;
CREATE POLICY percakapan_baca_peserta_atau_admin ON public.percakapan
  FOR SELECT TO authenticated
  USING (public.adalah_admin_atau_staf()
     OR dibuat_oleh = auth.uid()
     OR EXISTS (
       SELECT 1 FROM public.peserta_percakapan pp WHERE pp.percakapan_id = id AND pp.pengguna_id = auth.uid()
     ));

DROP POLICY IF EXISTS percakapan_buat_sendiri ON public.percakapan;
CREATE POLICY percakapan_buat_sendiri ON public.percakapan
  FOR INSERT TO authenticated
  WITH CHECK (dibuat_oleh = auth.uid());

-- ==== pesan ====
DROP POLICY IF EXISTS pesan_baca_peserta_atau_admin ON public.pesan;
CREATE POLICY pesan_baca_peserta_atau_admin ON public.pesan
  FOR SELECT TO authenticated
  USING (public.adalah_admin_atau_staf()
     OR EXISTS (
       SELECT 1 FROM public.peserta_percakapan pp WHERE pp.percakapan_id = pesan.percakapan_id AND pp.pengguna_id = auth.uid()
     ));

DROP POLICY IF EXISTS pesan_kirim_peserta ON public.pesan;
CREATE POLICY pesan_kirim_peserta ON public.pesan
  FOR INSERT TO authenticated
  WITH CHECK (
    pengirim_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM public.peserta_percakapan pp WHERE pp.percakapan_id = pesan.percakapan_id AND pp.pengguna_id = auth.uid()
    )
  );

-- ==== categories ====
DROP POLICY IF EXISTS categories_read_authenticated ON public.categories;
CREATE POLICY categories_read_authenticated ON public.categories
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS categories_manage_admin ON public.categories;
CREATE POLICY categories_manage_admin ON public.categories
  FOR ALL TO authenticated
  USING (public.is_lapak8_admin())
  WITH CHECK (public.is_lapak8_admin());

-- ==== time_slots ====
DROP POLICY IF EXISTS time_slots_read_active_or_admin ON public.time_slots;
CREATE POLICY time_slots_read_active_or_admin ON public.time_slots
  FOR SELECT TO authenticated USING (is_aktif OR public.is_lapak8_admin());

DROP POLICY IF EXISTS time_slots_manage_admin ON public.time_slots;
CREATE POLICY time_slots_manage_admin ON public.time_slots
  FOR ALL TO authenticated
  USING (public.is_lapak8_admin())
  WITH CHECK (public.is_lapak8_admin());

-- ==== rules ====
DROP POLICY IF EXISTS rules_read_active_or_admin ON public.rules;
CREATE POLICY rules_read_active_or_admin ON public.rules
  FOR SELECT TO authenticated USING (aktif OR public.is_lapak8_admin());

DROP POLICY IF EXISTS rules_manage_admin ON public.rules;
CREATE POLICY rules_manage_admin ON public.rules
  FOR ALL TO authenticated
  USING (public.is_lapak8_admin())
  WITH CHECK (public.is_lapak8_admin());

-- ==== facility_pics ====
DROP POLICY IF EXISTS facility_pics_read_authenticated ON public.facility_pics;
CREATE POLICY facility_pics_read_authenticated ON public.facility_pics
  FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS facility_pics_manage_admin ON public.facility_pics;
CREATE POLICY facility_pics_manage_admin ON public.facility_pics
  FOR ALL TO authenticated
  USING (public.is_lapak8_admin())
  WITH CHECK (public.is_lapak8_admin());

-- ==== notifications ====
DROP POLICY IF EXISTS notifications_read_owner_or_admin ON public.notifications;
CREATE POLICY notifications_read_owner_or_admin ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid() OR public.is_lapak8_admin());

DROP POLICY IF EXISTS notifications_manage_admin ON public.notifications;
CREATE POLICY notifications_manage_admin ON public.notifications
  FOR ALL TO authenticated
  USING (public.is_lapak8_admin())
  WITH CHECK (public.is_lapak8_admin());

-- ==== return_documentation ====
DROP POLICY IF EXISTS return_documentation_read_owner_or_admin ON public.return_documentation;
CREATE POLICY return_documentation_read_owner_or_admin ON public.return_documentation
  FOR SELECT TO authenticated
  USING (
    public.is_lapak8_admin()
    OR EXISTS (
      SELECT 1
      FROM public.peminjaman p
      WHERE p.id = return_documentation.borrowing_id
        AND p.peminjam_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS return_documentation_manage_admin ON public.return_documentation;
CREATE POLICY return_documentation_manage_admin ON public.return_documentation
  FOR ALL TO authenticated
  USING (public.is_lapak8_admin())
  WITH CHECK (public.is_lapak8_admin());

-- ==== return_inspections ====
DROP POLICY IF EXISTS return_inspections_read_owner_or_admin ON public.return_inspections;
CREATE POLICY return_inspections_read_owner_or_admin ON public.return_inspections
  FOR SELECT TO authenticated
  USING (
    public.is_lapak8_admin()
    OR EXISTS (
      SELECT 1
      FROM public.peminjaman p
      WHERE p.id = return_inspections.borrowing_id
        AND p.peminjam_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS return_inspections_manage_admin ON public.return_inspections;
CREATE POLICY return_inspections_manage_admin ON public.return_inspections
  FOR ALL TO authenticated
  USING (public.is_lapak8_admin())
  WITH CHECK (public.is_lapak8_admin());

-- -------------------------------------------------------------
-- GRANTS — make tables readable/writable where policies allow
-- -------------------------------------------------------------
-- service_role is used by Edge Functions (admin client). It bypasses RLS,
-- but still needs explicit table privileges; new projects only get Dxtm.
GRANT USAGE ON SCHEMA public TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE, DELETE ON TABLE
  public.pengguna,
  public.lokasi,
  public.fasilitas,
  public.aset_fasilitas,
  public.peminjaman,
  public.item_peminjaman,
  public.persetujuan_peminjaman,
  public.penugasan_aset,
  public.tiket_qr,
  public.riwayat_kejadian,
  public.percakapan,
  public.peserta_percakapan,
  public.pesan,
  public.categories,
  public.time_slots,
  public.rules,
  public.facility_pics,
  public.notifications,
  public.return_documentation,
  public.return_inspections
TO authenticated, service_role;

GRANT SELECT ON TABLE public.profiles TO authenticated, service_role;

REVOKE INSERT, UPDATE, DELETE ON TABLE
  public.peminjaman,
  public.item_peminjaman,
  public.persetujuan_peminjaman
FROM authenticated;

-- -------------------------------------------------------------
-- FILE END
-- =============================================================================
-- SUMMARY OF RECONCILIATION
-- -------------------------------------------------------------
-- Role mapping (Indonesian → English):
--   siswa → student   |   guru → teacher   |   staf → staff   |   admin → admin
-- Status flow mapping:
--   DB:       menunggu_persetujuan | disetujui | ditolak | dibatalkan | dipinjam | dikembalikan | terlambat
--   Eng:      pending_approval      | approved     | rejected   | cancelled     | borrowed | returned        | overdue
--   REST:     pending               | approved     | rejected   | cancelled     | —        | returned        | cancelled
-- Canonical table naming follows database/schema_baru.sql (Indonesian).
-- Supporting tables (categories, time_slots, rules, facility_pics, notifications,
-- return_documentation, return_inspections) added to cover all app data needs.
-- Functions tangani_pengguna_auth_baru,adalah_admin_atau_staf,admin_perbarui_pengguna,
-- set_updated_at,is_lapak8_admin are included for RLS.
-- -------------------------------------------------------------