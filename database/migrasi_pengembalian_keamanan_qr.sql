-- Patch keamanan QR untuk database yang sudah memakai migrasi_pengembalian.sql.
-- Tinjau lalu jalankan manual di Supabase SQL Editor; tidak mengubah data/tabel.

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

  IF NOT EXISTS (
    SELECT 1
    FROM public.pengguna AS pg
    WHERE pg.id = v_uid
      AND pg.aktif = TRUE
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
      AND v_status NOT IN ('dipinjam', 'terlambat') THEN
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
