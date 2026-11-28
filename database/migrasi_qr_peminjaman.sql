-- Wajib dijalankan setelah migrasi_pengembalian.sql.
-- Penyerahan barang hanya boleh dikonfirmasi melalui QR pengambilan.

DO $$
BEGIN
  IF to_regprocedure('public.proses_qr_admin(text)') IS NULL THEN
    RAISE EXCEPTION
      'Jalankan migrasi_pengembalian.sql sebelum migrasi_qr_peminjaman.sql.';
  END IF;

  IF to_regprocedure(
    'public.proses_peminjaman_admin_qr_legacy(uuid,text,text)'
  ) IS NULL THEN
    IF to_regprocedure('public.proses_peminjaman_admin(uuid,text,text)') IS NULL THEN
      RAISE EXCEPTION 'Fungsi proses_peminjaman_admin tidak ditemukan.';
    END IF;

    EXECUTE 'ALTER FUNCTION public.proses_peminjaman_admin(uuid,text,text) RENAME TO proses_peminjaman_admin_qr_legacy';
  END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.proses_peminjaman_admin_qr_legacy(UUID, TEXT, TEXT)
  FROM PUBLIC, anon, authenticated;

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
  IF p_status = 'dipinjam' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Status dipinjam hanya dapat dikonfirmasi melalui scan QR peminjaman.';
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

CREATE OR REPLACE FUNCTION public.proses_qr_peminjaman_admin(
  p_kode_qr TEXT,
  p_peminjaman_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_status TEXT;
  v_tiket RECORD;
BEGIN
  IF auth.uid() IS NULL OR NOT public.adalah_admin_atau_staf() THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Hanya admin atau staf aktif yang dapat memproses QR peminjaman.';
  END IF;

  IF p_peminjaman_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'ID transaksi peminjaman tidak valid.';
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

  IF v_status <> 'disetujui' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'QR peminjaman hanya dapat diproses untuk transaksi yang disetujui.';
  END IF;

  SELECT tq.peminjaman_id, tq.tipe
  INTO v_tiket
  FROM public.tiket_qr AS tq
  WHERE tq.kode_qr = p_kode_qr
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Kode QR tidak valid atau bukan tiket LAPAK8.';
  END IF;

  IF v_tiket.peminjaman_id IS DISTINCT FROM p_peminjaman_id THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'QR tidak cocok dengan transaksi peminjaman yang dipilih.';
  END IF;

  IF v_tiket.tipe IS DISTINCT FROM 'pengambilan' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'QR ini bukan QR peminjaman.';
  END IF;

  RETURN public.proses_qr_admin(p_kode_qr);
END;
$$;

REVOKE ALL ON FUNCTION public.proses_qr_peminjaman_admin(TEXT, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.proses_qr_peminjaman_admin(TEXT, UUID)
  TO authenticated;

DROP POLICY IF EXISTS peminjaman_kelola_admin ON public.peminjaman;
REVOKE INSERT, UPDATE, DELETE ON TABLE public.peminjaman
  FROM PUBLIC, anon, authenticated;

NOTIFY pgrst, 'reload schema';
