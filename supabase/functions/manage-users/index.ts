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

function validEmail(value: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);
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

  const userClient = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: authorization } },
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: authData, error: authError } = await userClient.auth.getUser();
  if (authError || !authData.user) {
    return respond({ error: 'Sesi login tidak valid atau sudah berakhir.' }, 401);
  }

  const adminClient = createClient(supabaseUrl, serviceRoleKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  });
  const { data: operator, error: operatorError } = await adminClient
    .from('profiles')
    .select('id, role, is_active')
    .eq('id', authData.user.id)
    .maybeSingle();

  if (operatorError) {
    return respond({ error: 'Gagal memverifikasi akun admin.' }, 500);
  }
  if (!operator || operator.role !== 'admin' || operator.is_active !== true) {
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
  if (action === 'create') {
    const name = requiredString(body, 'nama');
    const rawEmail = requiredString(body, 'email');
    const password = body.password;
    const idNumber = requiredString(body, 'nisn');
    const role = body.role;
    const active = body.active === undefined ? true : body.active;

    if (!name || !rawEmail || !idNumber || typeof password !== 'string') {
      return respond({
        error: 'Nama, email, password, dan nomor induk wajib diisi.',
      }, 400);
    }
    if (typeof active !== 'boolean') {
      return respond({ error: 'Status akun tidak valid.' }, 400);
    }
    const email = rawEmail.toLowerCase();
    if (!validEmail(email)) {
      return respond({ error: 'Format email tidak valid.' }, 400);
    }
    if (password.length < 6) {
      return respond({ error: 'Password minimal 6 karakter.' }, 400);
    }

    const roleMap: Record<string, { dbRole: string; idType: string }> = {
      student: { dbRole: 'siswa',    idType: 'nisn' },
      teacher: { dbRole: 'guru',     idType: 'nip'  },
      staff:   { dbRole: 'petugas',  idType: 'nip'  },
    };
    const validRoles = ['student', 'teacher', 'staff'];
    if (typeof role !== 'string' || !validRoles.includes(role)) {
      return respond({ error: 'Jenis akun tidak valid.' }, 400);
    }
    const mapped = roleMap[role];

    const { data: created, error: createError } =
      await adminClient.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: name },
      });
    if (createError || !created.user) {
      return respond({
        error: createError?.message ?? 'Akun Auth tidak berhasil dibuat.',
      }, 409);
    }

    const { error: insertError } = await adminClient.from('users').insert({
      auth_id: created.user.id,
      name,
      email,
      id_number: idNumber,
      id_type: mapped.idType,
      role: mapped.dbRole,
      role_class: requiredString(body, 'kelas'),
      phone: requiredString(body, 'nomor_telepon'),
      is_active: active,
      password_hash: '',
      loan_count: 0,
      late_count: 0,
    });

    if (insertError) {
      const { error: cleanupError } =
        await adminClient.auth.admin.deleteUser(created.user.id);
      if (cleanupError) {
        return respond({
          error: `Profil gagal disimpan dan akun Auth tidak dapat dibersihkan: ${insertError.message}`,
        }, 500);
      }
      return respond({ error: insertError.message }, 409);
    }

    return respond({ id: created.user.id }, 201);
  }

  if (action === 'set_email' || action === 'set_password') {
    const id = requiredString(body, 'id');
    if (!id || !validUuid(id)) {
      return respond({ error: 'ID akun tidak valid.' }, 400);
    }

    const { data: target, error: targetError } = await adminClient
      .from('profiles')
      .select('id, email, role')
      .eq('id', id)
      .maybeSingle();

    if (targetError) {
      return respond({ error: 'Gagal memeriksa akun tujuan.' }, 500);
    }
    if (
      !target ||
      (target.role === 'admin' && target.id !== authData.user.id)
    ) {
      return respond({ error: 'Akun tujuan tidak dapat dikelola.' }, 404);
    }

    if (action === 'set_email') {
      const rawEmail = requiredString(body, 'email');
      if (!rawEmail) {
        return respond({ error: 'Email wajib diisi.' }, 400);
      }
      const email = rawEmail.toLowerCase();
      if (!validEmail(email)) {
        return respond({ error: 'Format email tidak valid.' }, 400);
      }

      const { error: profileError } = await adminClient
        .from('profiles')
        .update({ email })
        .eq('id', id);
      if (profileError) {
        return respond({ error: profileError.message }, 409);
      }

      const { error: authUpdateError } =
        await adminClient.auth.admin.updateUserById(id, {
          email,
          email_confirm: true,
        });
      if (authUpdateError) {
        const { error: rollbackError } = await adminClient
          .from('profiles')
          .update({ email: target.email })
          .eq('id', id);
        if (rollbackError) {
          return respond({
            error: `Email Auth gagal diperbarui dan sinkronisasi profil gagal: ${rollbackError.message}`,
          }, 500);
        }
        return respond({ error: authUpdateError.message }, 409);
      }

      return respond({ ok: true });
    }

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
