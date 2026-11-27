-- Batas laju ALLOC8 AI: maksimal 20 permintaan per pengguna per jam.
-- Jalankan di Supabase SQL Editor sebelum mengaktifkan Edge Function alloc8-ai.

CREATE TABLE IF NOT EXISTS public.alloc8_ai_rate_limits (
  user_id UUID PRIMARY KEY
    REFERENCES public.pengguna(id) ON DELETE CASCADE,
  window_started_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  request_count INTEGER NOT NULL DEFAULT 0 CHECK (request_count >= 0)
);

ALTER TABLE public.alloc8_ai_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE public.alloc8_ai_rate_limits FROM PUBLIC, anon, authenticated;

CREATE OR REPLACE FUNCTION public.consume_alloc8_ai_quota(p_user_id UUID)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp
AS $$
DECLARE
  v_count INTEGER;
BEGIN
  IF p_user_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023',
      MESSAGE = 'ID pengguna tidak valid.';
  END IF;

  INSERT INTO public.alloc8_ai_rate_limits AS quota (
    user_id, window_started_at, request_count
  )
  VALUES (p_user_id, now(), 1)
  ON CONFLICT (user_id) DO UPDATE
  SET window_started_at = CASE
        WHEN quota.window_started_at <= now() - interval '1 hour' THEN now()
        ELSE quota.window_started_at
      END,
      request_count = CASE
        WHEN quota.window_started_at <= now() - interval '1 hour' THEN 1
        ELSE quota.request_count + 1
      END
  RETURNING request_count INTO v_count;

  RETURN v_count <= 20;
END;
$$;

REVOKE ALL ON FUNCTION public.consume_alloc8_ai_quota(UUID)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.consume_alloc8_ai_quota(UUID)
  TO service_role;
