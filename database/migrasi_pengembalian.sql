-- Migrasi fitur QR pengambilan dan pengembalian LAPAK8.
-- Tinjau dahulu, lalu jalankan di Supabase SQL Editor setelah databasefix.sql.
-- Tidak menghapus tabel atau data. Status selesai mengikuti skema aktif:
-- public.peminjaman.status = 'dikembalikan' (ditampilkan sebagai "Selesai").

ALTER TABLE public.tiket_qr
  ADD COLUMN IF NOT EXISTS tipe TEXT NOT NULL DEFAULT 'pengambilan'
    CHECK (tipe IN ('pengambilan', 'pengembalian'));

ALTER TABLE public.tiket_qr
  ADD COLUMN IF NOT EXISTS sudah_dipakai BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.tiket_qr
  ADD COLUMN IF NOT EXISTS dipakai_pada TIMESTAMPTZ;

ALTER TABLE public.tiket_qr
  ADD COLUMN IF NOT EXISTS dipakai_oleh UUID REFERENCES public.pengguna(id) ON DELETE SET NULL;

ALTER TABLE public.peminjaman
  ADD COLUMN IF NOT EXISTS kondisi_barang TEXT
    CHECK (kondisi_barang IS NULL OR kondisi_barang IN ('baik', 'rusak', 'hilang'));

ALTER TABLE public.peminjaman
  ADD COLUMN IF NOT EXISTS catatan_pengembalian TEXT;

CREATE INDEX IF NOT EXISTS idx_tiket_qr_tipe ON public.tiket_qr (tipe);

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
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Silakan masuk terlebih dahulu.';
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
  ELSIF p_tipe = 'pengembalian' AND v_status NOT IN ('dipinjam', 'terlambat') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'QR pengembalian hanya tersedia untuk barang yang sedang dipinjam.';
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
    || upper(substr(replace(gen_random_uuid()::TEXT, '-', ''), 1, 8));
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

CREATE OR REPLACE FUNCTION public.proses_qr_admin(
  p_kode_qr TEXT
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
  v_terlambat BOOLEAN;
BEGIN
  IF v_admin_id IS NULL OR NOT public.adalah_admin_atau_staf() THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Hanya admin atau staf aktif yang dapat memproses QR.';
  END IF;

  SELECT tq.peminjaman_id
  INTO v_peminjaman_id
  FROM public.tiket_qr AS tq
  WHERE tq.kode_qr = p_kode_qr;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Kode QR tidak valid atau bukan tiket LAPAK8.';
  END IF;

  -- Selalu kunci peminjaman sebelum tiket agar pemrosesan tiket satu peminjaman
  -- terserialisasi dan tiket tidak dapat dipakai dua kali secara bersamaan.
  SELECT p.*
  INTO v_peminjaman
  FROM public.peminjaman AS p
  WHERE p.id = v_peminjaman_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Peminjaman terkait tidak ditemukan.';
  END IF;

  SELECT tq.*
  INTO v_tiket
  FROM public.tiket_qr AS tq
  WHERE tq.kode_qr = p_kode_qr
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Kode QR tidak valid atau bukan tiket LAPAK8.';
  END IF;

  IF v_tiket.sudah_dipakai THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Tiket QR ini sudah pernah digunakan.';
  END IF;

  IF v_tiket.expired_at IS NULL OR v_tiket.expired_at <= now() THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Tiket QR ini sudah kedaluwarsa atau masa berlakunya tidak valid. Minta peminjam membuat QR baru.';
  END IF;

  IF v_tiket.tipe = 'pengambilan' AND v_peminjaman.status <> 'disetujui' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Peminjaman sudah tidak berstatus disetujui.';
  ELSIF v_tiket.tipe = 'pengembalian'
      AND v_peminjaman.status NOT IN ('dipinjam', 'terlambat') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Barang belum diambil atau sudah dikembalikan.';
  ELSIF v_tiket.tipe NOT IN ('pengambilan', 'pengembalian') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Jenis tiket QR tidak valid.';
  END IF;

  UPDATE public.tiket_qr
  SET sudah_dipakai = TRUE,
      dipakai_pada = now(),
      dipakai_oleh = v_admin_id
  WHERE id = v_tiket.id;

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
  WHERE item.peminjaman_id = v_peminjaman.id;

  v_terlambat := now() > v_peminjaman.estimasi_kembali_pada;

  IF v_tiket.tipe = 'pengambilan' THEN
    UPDATE public.peminjaman
    SET status = 'dipinjam',
        diambil_pada = now(),
        updated_at = now()
    WHERE id = v_peminjaman.id;

    INSERT INTO public.riwayat_kejadian (peminjaman_id, aktor_id, jenis, deskripsi)
    VALUES (v_peminjaman.id, v_admin_id, 'status_change',
      'Barang diambil melalui QR dan diproses oleh admin.');
  END IF;

  RETURN jsonb_build_object(
    'peminjaman_id', v_peminjaman.id,
    'kode_booking', v_peminjaman.kode_booking,
    'tipe_tiket', v_tiket.tipe,
    'status', CASE
      WHEN v_tiket.tipe = 'pengambilan' THEN 'dipinjam'
      ELSE v_peminjaman.status
    END,
    'nama_kegiatan', v_peminjaman.nama_kegiatan,
    'kategori', v_peminjaman.kategori,
    'mulai_pada', v_peminjaman.mulai_pada,
    'estimasi_kembali_pada', v_peminjaman.estimasi_kembali_pada,
    'diambil_pada', CASE
      WHEN v_tiket.tipe = 'pengambilan' THEN now()
      ELSE v_peminjaman.diambil_pada
    END,
    'terlambat', v_terlambat,
    'peminjam', jsonb_build_object(
      'nama_lengkap', v_peminjam.nama_lengkap,
      'nomor_induk', v_peminjam.nomor_induk,
      'kelas_atau_unit', v_peminjam.kelas_atau_unit,
      'peran', v_peminjam.peran
    ),
    'items', v_items
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
DECLARE
  v_admin_id UUID := auth.uid();
  v_status TEXT;
  v_item RECORD;
  v_catatan TEXT := nullif(trim(p_catatan), '');
BEGIN
  IF v_admin_id IS NULL OR NOT public.adalah_admin_atau_staf() THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Hanya admin atau staf aktif yang dapat memproses pengembalian.';
  END IF;

  IF p_kondisi_barang IS NULL
      OR p_kondisi_barang NOT IN ('baik', 'rusak', 'hilang') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Pilih kondisi barang: baik, rusak, atau hilang.';
  END IF;

  SELECT p.status
  INTO v_status
  FROM public.peminjaman AS p
  WHERE p.id = p_peminjaman_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Peminjaman tidak ditemukan.';
  END IF;

  IF v_status NOT IN ('dipinjam', 'terlambat') THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Barang belum diambil atau sudah pernah dikembalikan.';
  END IF;

  UPDATE public.peminjaman
  SET status = 'dikembalikan',
      dikembalikan_pada = now(),
      kondisi_barang = p_kondisi_barang,
      catatan_pengembalian = v_catatan,
      updated_at = now()
  WHERE id = p_peminjaman_id;

  -- total_unit adalah jumlah fisik, bukan penghitung pinjaman aktif.
  -- Status dikembalikan melepaskan unit dari perhitungan pemakaian aktif.
  -- Barang rusak/hilang tidak dilepas kembali ke kapasitas yang dapat dipinjam.
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

  INSERT INTO public.riwayat_kejadian (peminjaman_id, aktor_id, jenis, deskripsi)
  VALUES (
    p_peminjaman_id, v_admin_id, 'status_change',
    'Barang selesai dikembalikan. Kondisi: ' || p_kondisi_barang ||
      CASE WHEN v_catatan IS NOT NULL THEN '. Catatan: ' || v_catatan ELSE '.' END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.buat_tiket_qr(UUID, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.buat_tiket_qr(UUID, TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.proses_qr_admin(TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.proses_qr_admin(TEXT) TO authenticated;

REVOKE ALL ON FUNCTION public.selesaikan_pengembalian(UUID, TEXT, TEXT) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.selesaikan_pengembalian(UUID, TEXT, TEXT) TO authenticated;

ALTER TABLE public.tiket_qr ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS tiket_qr_baca_pemilik ON public.tiket_qr;
CREATE POLICY tiket_qr_baca_pemilik ON public.tiket_qr
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1
      FROM public.peminjaman AS p
      WHERE p.id = tiket_qr.peminjaman_id
        AND p.peminjam_id = auth.uid()
    )
    OR public.adalah_admin_atau_staf()
  );

DROP POLICY IF EXISTS tiket_qr_kelola_admin ON public.tiket_qr;
CREATE POLICY tiket_qr_kelola_admin ON public.tiket_qr
  FOR ALL TO authenticated
  USING (public.adalah_admin_atau_staf())
  WITH CHECK (public.adalah_admin_atau_staf());
