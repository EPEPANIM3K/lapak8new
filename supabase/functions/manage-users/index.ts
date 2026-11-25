// Deno Edge Function: manage-users
// Supabase Project: oqyhowjjndkjerdouhfl
// Skema: tabel "pengguna" (skema baru, nama kolom Indonesia)

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

type JsonRecord = Record<string, unknown>;

function respond(body: JsonRecord, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function requiredString(body: JsonRecord, key: string): string | null {
  const value = body[key];
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function optionalString(body: JsonRecord, key: string): string | null {
  const value = body[key];
  return typeof value === 'string' && value.trim() ? value.trim() : null;
}

function validEmail(value: string): boolean {
  return /^[^\@\s]+@[^\@\s]+\.[^\@\s]+$/.test(value);
}

function validUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-8][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

Deno.serve(async (request) => {
  if (request.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (request.method !== 'POST') {
    return respond({ error: 'Metode permintaan tidak didukung.' }, 405);
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!supabaseUrl || !anonKey || !serviceRoleKey) {
    return respond({ error: 'Konfigurasi server Supabase belum lengkap.' }, 500);
  }

  const authorization = request.headers.get('Authorization');
  if (!authorization) {
    return respond({ error: 'Sesi login tidak ditemukan.' }, 401);
  }

  // Verifikasi user yang memanggil function
  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return respond({ error: 'Sesi login tidak valid atau sudah berakhir.' }, 401);
  }

  // Verifikasi bahwa pemanggil adalah admin aktif di tabel pengguna
  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: operator, error: operatorError } = await adminClient
    .from('pengguna')
    .select('id, peran, aktif')
    .eq('id', authData.user.id)
    .maybeSingle();

  if (operatorError) {
    return respond({ error: 'Gagal memverifikasi akun admin.' }, 500);
  }
  if (!operator || operator.peran !== 'admin' || operator.aktif !== true) {
    return respond({ error: 'Hanya admin aktif yang boleh mengelola akun.' }, 403);
  }

  let body: JsonRecord;
  try {
    const parsed: unknown = await request.json();
    if (typeof parsed !== 'object' || parsed === null || Array.isArray(parsed)) {
      return respond({ error: 'Isi permintaan tidak valid.' }, 400);
    }
    body = parsed as JsonRecord;
  } catch {
    return respond({ error: 'Format permintaan tidak valid.' }, 400);
  }

  const action = body.action;

  // ---------------------------------------------------------------------------
  // ACTION: create — buat akun auth + insert ke tabel pengguna
  // ---------------------------------------------------------------------------
  if (action === 'create') {
    const nama     = requiredString(body, 'nama');
    const rawEmail = requiredString(body, 'email');
    const password = body.password;
    const nomorInduk = optionalString(body, 'nomor_induk');
    const peran    = body.peran;
    const aktif    = body.aktif === undefined ? true : body.aktif;

    if (!nama || !rawEmail || typeof password !== 'string') {
      return respond({ error: 'Nama, email, dan password wajib diisi.' }, 400);
    }
    if (typeof aktif !== 'boolean') {
      return respond({ error: 'Status akun tidak valid.' }, 400);
    }
    const email = rawEmail.toLowerCase();
    if (!validEmail(email)) {
      return respond({ error: 'Format email tidak valid.' }, 400);
    }
    if (password.length < 6) {
      return respond({ error: 'Password minimal 6 karakter.' }, 400);
    }

    // Validasi peran (skema baru: siswa, guru, staf)
    const validRoles = ['siswa', 'guru', 'staf'];
    if (typeof peran !== 'string' || !validRoles.includes(peran)) {
      return respond({ error: 'Jenis akun tidak valid. Gunakan: siswa, guru, atau staf.' }, 400);
    }

    // 1. Buat akun auth Supabase
    const { data: created, error: createError } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { nama_lengkap: nama },
      });
    if (createError || !created.user) {
      return respond({
        error: createError?.message ?? 'Akun Auth tidak berhasil dibuat.',
      }, 409);
    }

    // 2. Insert ke tabel pengguna (trigger tangani_pengguna_auth_baru mungkin
    //    sudah membuat baris — kita pakai upsert agar aman)
    const { error: insertError } = await adminClient.from('pengguna').upsert({
      id:              created.user.id,
      nama_lengkap:    nama,
      email:           email,
      nomor_induk:     nomorInduk ?? '',
      peran:           peran,
      kelas_atau_unit: optionalString(body, 'kelas'),
      telepon:         optionalString(body, 'nomor_telepon'),
      aktif:           aktif,
    }, { onConflict: 'id' });

    if (insertError) {
      // Rollback: hapus akun auth yang sudah terbuat
      await adminClient.auth.admin.deleteUser(created.user.id);
      return respond({ error: insertError.message }, 409);
    }

    return respond({ id: created.user.id }, 201);
  }

  // ---------------------------------------------------------------------------
  // ACTION: set_email / set_password
  // ---------------------------------------------------------------------------
  if (action === 'set_email' || action === 'set_password') {
    const id = requiredString(body, 'id');
    if (!id || !validUuid(id)) {
      return respond({ error: 'ID akun tidak valid.' }, 400);
    }

    // Ambil data target dari tabel pengguna
    const { data: target, error: targetError } = await adminClient
      .from('pengguna')
      .select('id, email, peran')
      .eq('id', id)
      .maybeSingle();

    if (targetError) {
      return respond({ error: 'Gagal memeriksa akun tujuan.' }, 500);
    }
    if (!target || (target.peran === 'admin' && target.id !== authData.user.id)) {
      return respond({ error: 'Akun tujuan tidak dapat dikelola.' }, 404);
    }

    if (action === 'set_email') {
      const rawEmail = requiredString(body, 'email');
      if (!rawEmail) return respond({ error: 'Email wajib diisi.' }, 400);
      const email = rawEmail.toLowerCase();
      if (!validEmail(email)) return respond({ error: 'Format email tidak valid.' }, 400);

      // Update email di tabel pengguna
      const { error: profileError } = await adminClient
        .from('pengguna')
        .update({ email })
        .eq('id', id);
      if (profileError) {
        return respond({ error: profileError.message }, 409);
      }

      // Update email di auth
      const { error: authUpdateError } =
        await adminClient.auth.admin.updateUserById(id, {
          email,
          email_confirm: true,
        });
      if (authUpdateError) {
        // Rollback
        await adminClient.from('pengguna').update({ email: target.email }).eq('id', id);
        return respond({ error: authUpdateError.message }, 409);
      }

      return respond({ ok: true });
    }

    // set_password
    const password = body.password;
    if (typeof password !== 'string' || password.length < 6) {
      return respond({ error: 'Password minimal 6 karakter.' }, 400);
    }
    const { error: passwordError } =
      await adminClient.auth.admin.updateUserById(id, { password });
    if (passwordError) {
      return respond({ error: passwordError.message }, 400);
    }
    return respond({ ok: true });
  }

  return respond({ error: 'Aksi pengelolaan akun tidak dikenal.' }, 400);
});
