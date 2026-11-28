-- ============================================================================
-- Notifikasi badge + highlight otomatis LAPAK8
-- Aman dijalankan ulang.
-- ============================================================================

-- Pengecekan sebelum eksekusi (jalankan manual di SQL Editor):
--
-- SELECT tgname, pg_get_triggerdef(oid)
-- FROM pg_trigger
-- WHERE tgrelid = 'public.peminjaman'::regclass
--   AND NOT tgisinternal;
--
-- SELECT proname
-- FROM pg_proc
-- WHERE pronamespace = 'public'::regnamespace
--   AND proname ILIKE '%notif%';
--
-- Jika ada trigger/RPC notifikasi lama, hentikan dan hapus/ganti trigger lama
-- sebelum menjalankan migrasi ini agar satu kejadian tidak menghasilkan dua notifikasi.

-- Hapus trigger notifikasi warisan yang masih aktif. Keduanya memanggil
-- public.notifikasi_peminjaman_trigger() dan menulis related_entity='peminjaman'
-- tanpa event_key, sehingga badge tidak pernah bisa di-auto-read.
DROP TRIGGER IF EXISTS peminjaman_notifikasi_insert ON public.peminjaman;
DROP TRIGGER IF EXISTS peminjaman_notifikasi_status ON public.peminjaman;

-- ----------------------------------------------------------------------------
-- Kolom deduplikasi
-- ----------------------------------------------------------------------------
ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS event_key TEXT;

CREATE UNIQUE INDEX IF NOT EXISTS uq_notifications_user_event_key
  ON public.notifications (user_id, event_key);

-- ----------------------------------------------------------------------------
-- Helper role admin/staf (helper lama is_lapak8_admin() hanya mengenali admin)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_lapak8_admin_atau_staf()
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(
    (
      SELECT peran IN ('admin', 'staf')
      FROM public.pengguna
      WHERE id = auth.uid()
        AND aktif = true
    ),
    false
  );
$$;

REVOKE ALL ON FUNCTION public.is_lapak8_admin_atau_staf() FROM public, anon;
GRANT EXECUTE ON FUNCTION public.is_lapak8_admin_atau_staf() TO authenticated;

-- ----------------------------------------------------------------------------
-- RPC tandai dibaca (owner-only, aman dipanggil dari client)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.tandai_notifikasi_dibaca(
  p_id UUID DEFAULT NULL,
  p_ids UUID[] DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_uid UUID := auth.uid();
  v_count INTEGER;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501',
      MESSAGE = 'Silakan masuk terlebih dahulu.';
  END IF;

  UPDATE public.notifications AS n
  SET sudah_dibaca = TRUE
  WHERE n.user_id = v_uid
    AND (p_id IS NULL OR n.id = p_id)
    AND (p_ids IS NULL OR n.id = ANY(p_ids));

  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.tandai_notifikasi_dibaca(UUID, UUID[]) FROM public, anon;
GRANT EXECUTE ON FUNCTION public.tandai_notifikasi_dibaca(UUID, UUID[]) TO authenticated;

-- ----------------------------------------------------------------------------
-- RLS notifications: owner-only. Admin/staf tetap melihat notifikasi yang
-- memang disimpan dengan user_id mereka masing-masing.
--
-- Pengecekan policies lama (jalankan manual di SQL Editor):
-- SELECT cmd, policyname, permissive, roles, qual
-- FROM pg_policies
-- WHERE schemaname = 'public' AND tablename = 'notifications';
-- ----------------------------------------------------------------------------
DO $$
DECLARE
  v_policy RECORD;
BEGIN
  FOR v_policy IN
    SELECT policyname
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'notifications'
      AND cmd IN ('SELECT', 'ALL')
  LOOP
    EXECUTE format('DROP POLICY %I ON public.notifications', v_policy.policyname);
  END LOOP;
END;
$$;

DROP POLICY IF EXISTS notifications_read_owner ON public.notifications;
CREATE POLICY notifications_read_owner ON public.notifications
  FOR SELECT TO authenticated
  USING (user_id = auth.uid());

-- ----------------------------------------------------------------------------
-- Trigger: pengajuan peminjaman baru
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notif_peminjaman_baru()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_nama_user TEXT;
  v_nama_barang TEXT;
  v_admin RECORD;
BEGIN
  IF NEW.status IS DISTINCT FROM 'menunggu_persetujuan' THEN
    RETURN NEW;
  END IF;

  SELECT u.nama_lengkap
  INTO v_nama_user
  FROM public.pengguna AS u
  WHERE u.id = NEW.peminjam_id;

  SELECT ip.nama_fasilitas_snapshot
  INTO v_nama_barang
  FROM public.item_peminjaman AS ip
  WHERE ip.peminjaman_id = NEW.id
  ORDER BY ip.created_at, ip.id
  LIMIT 1;

  v_nama_barang := coalesce(nullif(trim(v_nama_barang), ''), NEW.nama_kegiatan, 'barang');

  FOR v_admin IN
    SELECT u.id
    FROM public.pengguna AS u
    WHERE u.peran IN ('admin', 'staf')
      AND u.aktif = true
      AND u.notifikasi_aktif = true
  LOOP
    INSERT INTO public.notifications (
      user_id, judul, isi, jenis, related_entity, related_id, event_key, sudah_dibaca
    )
    VALUES (
      v_admin.id,
      'Pengajuan Peminjaman Baru',
      coalesce(v_nama_user, 'Pengguna LAPAK8') ||
        ' mengajukan peminjaman ' || v_nama_barang || '.',
      'warning',
      'pengajuan_peminjaman',
      NEW.id,
      'pengajuan_peminjaman:' || NEW.id::text || ':' || v_admin.id::text,
      false
    )
    ON CONFLICT (user_id, event_key) DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notif_peminjaman_baru ON public.peminjaman;
CREATE TRIGGER trg_notif_peminjaman_baru
  AFTER INSERT ON public.peminjaman
  FOR EACH ROW
  EXECUTE FUNCTION public.notif_peminjaman_baru();

-- ----------------------------------------------------------------------------
-- Trigger: persetujuan peminjaman
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notif_persetujuan_peminjaman()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_aktif BOOLEAN;
  v_notifikasi_aktif BOOLEAN;
  v_nama_barang TEXT;
BEGIN
  IF TG_OP <> 'UPDATE'
     OR OLD.status IS NOT DISTINCT FROM NEW.status
     OR OLD.status <> 'menunggu_persetujuan'
     OR NEW.status <> 'disetujui'
     OR NEW.peminjam_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT u.aktif, u.notifikasi_aktif
  INTO v_aktif, v_notifikasi_aktif
  FROM public.pengguna AS u
  WHERE u.id = NEW.peminjam_id;

  IF NOT FOUND OR coalesce(v_aktif, false) = false OR coalesce(v_notifikasi_aktif, false) = false THEN
    RETURN NEW;
  END IF;

  SELECT ip.nama_fasilitas_snapshot
  INTO v_nama_barang
  FROM public.item_peminjaman AS ip
  WHERE ip.peminjaman_id = NEW.id
  ORDER BY ip.created_at, ip.id
  LIMIT 1;

  v_nama_barang := coalesce(nullif(trim(v_nama_barang), ''), NEW.nama_kegiatan, 'barang');

  INSERT INTO public.notifications (
    user_id, judul, isi, jenis, related_entity, related_id, event_key, sudah_dibaca
  )
  VALUES (
    NEW.peminjam_id,
    'Peminjaman Disetujui',
    'Peminjaman ' || v_nama_barang || ' kamu telah disetujui admin.',
    'success',
    'persetujuan_peminjaman',
    NEW.id,
    'persetujuan_peminjaman:' || NEW.id::text || ':' || NEW.peminjam_id::text,
    false
  )
  ON CONFLICT (user_id, event_key) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notif_persetujuan_peminjaman ON public.peminjaman;
CREATE TRIGGER trg_notif_persetujuan_peminjaman
  AFTER UPDATE OF status ON public.peminjaman
  FOR EACH ROW
  EXECUTE FUNCTION public.notif_persetujuan_peminjaman();

-- ----------------------------------------------------------------------------
-- Trigger: pengajuan pengembalian baru
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.notif_pengembalian_baru()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_nama_user TEXT;
  v_nama_barang TEXT;
  v_admin RECORD;
BEGIN
  IF TG_OP <> 'UPDATE'
     OR OLD.status IS NOT DISTINCT FROM NEW.status
     OR OLD.status NOT IN ('dipinjam', 'terlambat')
     OR NEW.status <> 'menunggu_pengembalian' THEN
    RETURN NEW;
  END IF;

  SELECT u.nama_lengkap
  INTO v_nama_user
  FROM public.pengguna AS u
  WHERE u.id = NEW.peminjam_id;

  SELECT ip.nama_fasilitas_snapshot
  INTO v_nama_barang
  FROM public.item_peminjaman AS ip
  WHERE ip.peminjaman_id = NEW.id
  ORDER BY ip.created_at, ip.id
  LIMIT 1;

  v_nama_barang := coalesce(nullif(trim(v_nama_barang), ''), NEW.nama_kegiatan, 'barang');

  FOR v_admin IN
    SELECT u.id
    FROM public.pengguna AS u
    WHERE u.peran IN ('admin', 'staf')
      AND u.aktif = true
      AND u.notifikasi_aktif = true
  LOOP
    INSERT INTO public.notifications (
      user_id, judul, isi, jenis, related_entity, related_id, event_key, sudah_dibaca
    )
    VALUES (
      v_admin.id,
      'Pengajuan Pengembalian Baru',
      coalesce(v_nama_user, 'Pengguna LAPAK8') ||
        ' mengajukan pengembalian ' || v_nama_barang || '.',
      'warning',
      'pengajuan_pengembalian',
      NEW.id,
      'pengajuan_pengembalian:' || NEW.id::text || ':' || v_admin.id::text,
      false
    )
    ON CONFLICT (user_id, event_key) DO NOTHING;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notif_pengembalian_baru ON public.peminjaman;
CREATE TRIGGER trg_notif_pengembalian_baru
  AFTER UPDATE OF status ON public.peminjaman
  FOR EACH ROW
  EXECUTE FUNCTION public.notif_pengembalian_baru();

-- ----------------------------------------------------------------------------
-- Realtime publication
-- ----------------------------------------------------------------------------
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END;
$$;

-- ----------------------------------------------------------------------------
-- Bersihkan badge warisan (sekali jalan, aman diulang).
-- Notifikasi lama tidak punya event_key dan tidak bisa dicocokkan dengan
-- transaksi pada halaman Aktifitas/Pinjaman, jadi ditandai dibaca agar badge
-- hanya menghitung notifikasi baru yang memang relevan.
-- ----------------------------------------------------------------------------
UPDATE public.notifications
SET sudah_dibaca = true
WHERE event_key IS NULL;
