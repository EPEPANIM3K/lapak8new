-- Store return-inspection evidence in a private Supabase Storage bucket.
-- Run after migrasi_pengembalian_workflow.sql.

BEGIN;

INSERT INTO storage.buckets (
  id,
  name,
  public,
  file_size_limit,
  allowed_mime_types
)
VALUES (
  'return-documentation',
  'return-documentation',
  false,
  104857600,
  ARRAY[
    'image/jpeg',
    'image/png',
    'image/webp',
    'image/gif',
    'image/bmp',
    'image/tiff',
    'image/heic',
    'image/heif',
    'image/avif',
    'image/vnd.microsoft.icon',
    'image/jxl',
    'video/mp4',
    'video/quicktime',
    'video/webm'
  ]
)
ON CONFLICT (id) DO UPDATE
SET name = EXCLUDED.name,
    public = false,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

CREATE OR REPLACE FUNCTION public.set_return_documentation_storage_path()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = pg_catalog, public, pg_temp
AS $$
BEGIN
  IF NEW.return_inspection_id IS NULL
      OR NEW.file_id IS NULL
      OR NEW.file_id !~ '^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$' THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'Identitas bukti pemeriksaan tidak valid.';
  END IF;

  NEW.file_path := NEW.return_inspection_id::TEXT || '/' || NEW.file_id;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS return_documentation_set_storage_path
  ON public.return_documentation;
CREATE TRIGGER return_documentation_set_storage_path
  BEFORE INSERT ON public.return_documentation
  FOR EACH ROW
  EXECUTE FUNCTION public.set_return_documentation_storage_path();

DROP POLICY IF EXISTS return_documentation_storage_read
  ON storage.objects;
CREATE POLICY return_documentation_storage_read
  ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'return-documentation'
    AND (
      public.adalah_admin_atau_staf()
      OR EXISTS (
        SELECT 1
        FROM public.return_documentation AS documentation
        JOIN public.peminjaman AS borrowing
          ON borrowing.id = documentation.borrowing_id
        WHERE documentation.file_path = storage.objects.name
          AND borrowing.peminjam_id = auth.uid()
      )
    )
  );

DROP POLICY IF EXISTS return_documentation_storage_upload
  ON storage.objects;
CREATE POLICY return_documentation_storage_upload
  ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'return-documentation'
    AND public.adalah_admin_atau_staf()
  );

DROP POLICY IF EXISTS return_documentation_storage_delete
  ON storage.objects;
CREATE POLICY return_documentation_storage_delete
  ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'return-documentation'
    AND public.adalah_admin_atau_staf()
  );

COMMIT;
