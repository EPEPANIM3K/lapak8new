-- Jalankan setelah databasefix.sql.
-- Mengembalikan agregat stok tanpa membuka data peminjam.

CREATE OR REPLACE FUNCTION public.stok_fasilitas()
RETURNS TABLE (
  fasilitas_id UUID,
  total_unit INTEGER,
  dipakai INTEGER,
  tersedia INTEGER
)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
  WITH pemakaian AS (
    SELECT
      item.fasilitas_id,
      COALESCE(SUM(item.jumlah), 0)::INTEGER AS dipakai
    FROM public.item_peminjaman AS item
    JOIN public.peminjaman AS peminjaman
      ON peminjaman.id = item.peminjaman_id
    WHERE peminjaman.status IN ('disetujui', 'dipinjam', 'terlambat')
    GROUP BY item.fasilitas_id
  )
  SELECT
    fasilitas.id,
    fasilitas.total_unit,
    COALESCE(pemakaian.dipakai, 0)::INTEGER,
    GREATEST(fasilitas.total_unit - COALESCE(pemakaian.dipakai, 0), 0)::INTEGER
  FROM public.fasilitas AS fasilitas
  LEFT JOIN pemakaian
    ON pemakaian.fasilitas_id = fasilitas.id
  WHERE fasilitas.aktif = TRUE
     OR public.adalah_admin_atau_staf();
$$;

REVOKE ALL ON FUNCTION public.stok_fasilitas() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.stok_fasilitas() TO authenticated;
