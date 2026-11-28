-- Wajib dijalankan setelah migrasi_qr_peminjaman.sql.
-- Validasi QR tidak mengubah status atau menggunakan tiket; pemrosesan yang
-- sudah tersedia tetap dijalankan hanya setelah admin mengonfirmasi.

CREATE OR REPLACE FUNCTION public.validasi_qr_peminjaman_admin(
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
      MESSAGE = 'Hanya admin atau staf aktif yang dapat memvalidasi QR peminjaman.';
  END IF;

  IF p_peminjaman_id IS NULL OR p_kode_qr IS NULL OR p_kode_qr = '' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Data QR atau transaksi peminjaman tidak valid.';
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

  SELECT tq.*
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

  IF v_tiket.sudah_dipakai THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Tiket QR ini sudah pernah digunakan.';
  END IF;

  IF v_tiket.expired_at IS NULL OR v_tiket.expired_at <= now() THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Tiket QR ini sudah kedaluwarsa atau masa berlakunya tidak valid. Minta peminjam membuat QR baru.';
  END IF;

  RETURN jsonb_build_object(
    'peminjaman_id', p_peminjaman_id,
    'tipe_tiket', v_tiket.tipe,
    'status', v_status
  );
END;
$$;

REVOKE ALL ON FUNCTION public.validasi_qr_peminjaman_admin(TEXT, UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.validasi_qr_peminjaman_admin(TEXT, UUID)
  TO authenticated;

NOTIFY pgrst, 'reload schema';
