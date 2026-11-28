-- Jalankan setelah migrasi_pengembalian_workflow.sql.
-- Konfirmasi user hanya menandai pembayaran dummy menunggu verifikasi admin.
-- Peminjaman baru selesai setelah admin menjalankan RPC konfirmasi.

ALTER TABLE public.return_inspections
  ADD COLUMN IF NOT EXISTS pembayaran_dikonfirmasi_oleh UUID
    REFERENCES public.pengguna(id) ON DELETE SET NULL;

ALTER TABLE public.return_inspections
  DROP CONSTRAINT IF EXISTS return_inspections_status_pembayaran_check;

ALTER TABLE public.return_inspections
  ADD CONSTRAINT return_inspections_status_pembayaran_check CHECK (
    status_pembayaran IN (
      'tidak_ada',
      'menunggu_pembayaran',
      'menunggu_konfirmasi_admin',
      'dikonfirmasi'
    )
  );

CREATE INDEX IF NOT EXISTS idx_return_inspections_payment_confirmation
  ON public.return_inspections (status_pembayaran)
  WHERE status_pembayaran = 'menunggu_konfirmasi_admin';

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
    AND ri.denda > 0
  ORDER BY ri.dibuat_pada DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Tagihan tidak sedang menunggu pembayaran atau sudah dikonfirmasi.';
  END IF;

  UPDATE public.return_inspections
  SET status_pembayaran = 'menunggu_konfirmasi_admin',
      updated_at = now()
  WHERE id = v_inspection.id;

  INSERT INTO public.riwayat_kejadian (peminjaman_id, aktor_id, jenis, deskripsi)
  VALUES (
    p_peminjaman_id,
    v_user_id,
    'status_change',
    'Pengguna mengirim konfirmasi pembayaran denda simulasi; menunggu konfirmasi admin.'
  );

  RETURN jsonb_build_object(
    'peminjaman_id', p_peminjaman_id,
    'status', 'pelanggaran',
    'status_pembayaran', 'menunggu_konfirmasi_admin',
    'return_inspection_id', v_inspection.id
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.konfirmasi_pembayaran_denda_admin(
  p_peminjaman_id UUID
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_admin_id UUID := auth.uid();
  v_inspection public.return_inspections%ROWTYPE;
BEGIN
  IF v_admin_id IS NULL OR NOT public.adalah_admin_atau_staf() THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Hanya admin atau staf aktif yang dapat mengonfirmasi pembayaran.';
  END IF;

  PERFORM 1
  FROM public.peminjaman AS p
  WHERE p.id = p_peminjaman_id
    AND p.status = 'pelanggaran'
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Peminjaman tidak lagi menunggu konfirmasi pembayaran.';
  END IF;

  SELECT ri.*
  INTO v_inspection
  FROM public.return_inspections AS ri
  WHERE ri.borrowing_id = p_peminjaman_id
    AND ri.status = 'menunggu_pembayaran'
    AND ri.status_pembayaran = 'menunggu_konfirmasi_admin'
    AND ri.denda > 0
  ORDER BY ri.dibuat_pada DESC
  LIMIT 1
  FOR UPDATE;

  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Konfirmasi pembayaran dari pengguna tidak ditemukan atau sudah diproses.';
  END IF;

  UPDATE public.return_inspections
  SET status = 'selesai',
      status_pembayaran = 'dikonfirmasi',
      dibayar_pada = now(),
      pembayaran_dikonfirmasi_oleh = v_admin_id,
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
    v_admin_id,
    'status_change',
    'Admin mengonfirmasi penyelesaian pembayaran denda simulasi sebesar Rp' ||
      replace(to_char(v_inspection.denda, 'FM999G999G999G990'), ',', '.') ||
      '. Transaksi selesai.'
  );

  RETURN jsonb_build_object(
    'peminjaman_id', p_peminjaman_id,
    'status', 'dikembalikan',
    'status_pembayaran', 'dikonfirmasi',
    'dibayar_pada', now(),
    'pembayaran_dikonfirmasi_oleh', v_admin_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.konfirmasi_pembayaran_denda(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.konfirmasi_pembayaran_denda(UUID)
  TO authenticated;

REVOKE ALL ON FUNCTION public.konfirmasi_pembayaran_denda_admin(UUID)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.konfirmasi_pembayaran_denda_admin(UUID)
  TO authenticated;
