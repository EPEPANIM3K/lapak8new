-- Jalankan setelah databasefix.sql dan migrasi_pengembalian_workflow.sql.
-- Mengembalikan agregat popularitas fasilitas tanpa membuka data peminjam.

CREATE OR REPLACE FUNCTION public.fasilitas_populer_dashboard(
  p_limit INTEGER DEFAULT 4
)
RETURNS TABLE (
  id UUID,
  nama TEXT,
  kategori TEXT,
  lokasi JSONB,
  total_unit INTEGER,
  status TEXT,
  aktif BOOLEAN,
  foto_url TEXT,
  jumlah_dipinjam BIGINT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, auth, pg_temp
AS $$
BEGIN
  IF auth.uid() IS NULL OR NOT EXISTS (
    SELECT 1
    FROM public.pengguna AS pengguna
    WHERE pengguna.id = auth.uid()
      AND pengguna.aktif = TRUE
  ) THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Hanya pengguna aktif yang dapat melihat item populer.';
  END IF;

  IF p_limit IS NULL OR p_limit < 1 OR p_limit > 12 THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Jumlah item populer harus antara 1 dan 12.';
  END IF;

  RETURN QUERY
  SELECT
    fasilitas.id,
    fasilitas.nama,
    fasilitas.kategori,
    CASE
      WHEN lokasi.id IS NULL THEN jsonb_build_object('nama', '-')
      ELSE jsonb_build_object('id', lokasi.id, 'nama', lokasi.nama)
    END,
    fasilitas.total_unit,
    fasilitas.status,
    fasilitas.aktif,
    fasilitas.foto_url,
    COALESCE(popularitas.jumlah_dipinjam, 0)::BIGINT
  FROM public.fasilitas AS fasilitas
  LEFT JOIN public.lokasi AS lokasi
    ON lokasi.id = fasilitas.lokasi_id
  LEFT JOIN (
    SELECT
      item.fasilitas_id,
      SUM(item.jumlah)::BIGINT AS jumlah_dipinjam
    FROM public.item_peminjaman AS item
    JOIN public.peminjaman AS peminjaman
      ON peminjaman.id = item.peminjaman_id
    WHERE peminjaman.status IN (
      'disetujui',
      'dipinjam',
      'terlambat',
      'menunggu_pengembalian',
      'pelanggaran',
      'dikembalikan'
    )
    GROUP BY item.fasilitas_id
  ) AS popularitas
    ON popularitas.fasilitas_id = fasilitas.id
  WHERE fasilitas.aktif = TRUE
    AND fasilitas.status = 'tersedia'
    AND fasilitas.total_unit > 0
  ORDER BY COALESCE(popularitas.jumlah_dipinjam, 0) DESC, fasilitas.nama
  LIMIT p_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.fasilitas_populer_dashboard(INTEGER)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.fasilitas_populer_dashboard(INTEGER)
  TO authenticated;
