-- =============================================================================
-- LAPAK8 — Skema Database Baru (Versi Indonesia)
-- Supabase (PostgreSQL)
-- =============================================================================
-- Cara pakai:
--   1. Buat project Supabase baru (atau hapus semua tabel di project lama)
--   2. Jalankan seluruh file ini di SQL Editor Supabase
--   3. Buat auth user admin pertama via Supabase Dashboard > Auth > Users
--   4. Jalankan: UPDATE public.pengguna SET peran = 'admin' WHERE id = '<uuid_admin>';
-- =============================================================================

begin;

-- ---------------------------------------------------------------------------
-- TABEL PENGGUNA
-- Terhubung ke auth.users Supabase via uuid primary key.
-- ---------------------------------------------------------------------------
create table if not exists public.pengguna (
  id            uuid primary key references auth.users (id) on delete cascade,
  nama_lengkap  text not null,
  email         text,
  telepon       text,
  nomor_induk   text unique,          -- NISN untuk siswa, NIP untuk guru/staf
  kelas_atau_unit text,               -- kelas siswa atau unit kerja guru/staf
  peran         text not null default 'siswa'
                  check (peran in ('siswa', 'guru', 'staf', 'admin')),
  foto_url      text,
  aktif         boolean not null default true,
  dibuat_pada   timestamptz not null default now(),
  diperbarui_pada timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- TABEL LOKASI
-- Ruangan / area tempat fasilitas berada.
-- ---------------------------------------------------------------------------
create table if not exists public.lokasi (
  id              uuid primary key default gen_random_uuid(),
  nama            text not null unique,
  deskripsi       text,
  pj_id           uuid references public.pengguna (id) on delete set null, -- penanggung jawab
  aktif           boolean not null default true,
  dibuat_pada     timestamptz not null default now(),
  diperbarui_pada timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- TABEL FASILITAS
-- Barang / alat / ruang yang dapat dipinjam.
-- ---------------------------------------------------------------------------
create table if not exists public.fasilitas (
  id              uuid primary key default gen_random_uuid(),
  nama            text not null,
  kategori        text,
  deskripsi       text,
  lokasi_id       uuid references public.lokasi (id) on delete set null,
  total_unit      integer not null default 0 check (total_unit >= 0),
  foto_url        text,
  status          text not null default 'tersedia'
                    check (status in ('tersedia', 'pemeliharaan', 'tidak_aktif')),
  aktif           boolean not null default true,
  dibuat_pada     timestamptz not null default now(),
  diperbarui_pada timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- TABEL ASET_FASILITAS
-- Unit individual (bernomor seri / kode aset) dari suatu fasilitas.
-- ---------------------------------------------------------------------------
create table if not exists public.aset_fasilitas (
  id              uuid primary key default gen_random_uuid(),
  fasilitas_id    uuid not null references public.fasilitas (id) on delete restrict,
  kode_aset       text not null unique,
  nomor_seri      text,
  kondisi         text not null default 'baik'
                    check (kondisi in ('baik', 'cukup', 'rusak')),
  status          text not null default 'tersedia'
                    check (status in ('tersedia', 'pemeliharaan', 'pensiun')),
  catatan         text,
  dibuat_pada     timestamptz not null default now(),
  diperbarui_pada timestamptz not null default now(),
  unique (fasilitas_id, nomor_seri)
);

-- ---------------------------------------------------------------------------
-- TABEL PEMINJAMAN
-- Header transaksi peminjaman.
-- ---------------------------------------------------------------------------
create table if not exists public.peminjaman (
  id                    uuid primary key default gen_random_uuid(),
  kode_booking          text not null unique,
  peminjam_id           uuid not null references public.pengguna (id) on delete restrict,
  kategori              text not null
                          check (kategori in ('praktik', 'ekskul', 'lainnya')),
  nama_kegiatan         text not null,
  catatan_tujuan        text,
  mulai_pada            timestamptz not null,
  estimasi_kembali_pada timestamptz not null,
  status                text not null default 'menunggu_persetujuan'
                          check (status in (
                            'menunggu_persetujuan', 'disetujui', 'ditolak',
                            'dibatalkan', 'dipinjam', 'dikembalikan', 'terlambat'
                          )),
  alasan_penolakan      text,
  diajukan_pada         timestamptz not null default now(),
  disetujui_pada        timestamptz,
  diambil_pada          timestamptz,
  dikembalikan_pada     timestamptz,
  dibuat_pada           timestamptz not null default now(),
  diperbarui_pada       timestamptz not null default now(),
  check (estimasi_kembali_pada > mulai_pada)
);

-- ---------------------------------------------------------------------------
-- TABEL ITEM_PEMINJAMAN
-- Detail fasilitas yang dipinjam dalam satu transaksi.
-- ---------------------------------------------------------------------------
create table if not exists public.item_peminjaman (
  id                      uuid primary key default gen_random_uuid(),
  peminjaman_id           uuid not null references public.peminjaman (id) on delete cascade,
  fasilitas_id            uuid not null references public.fasilitas (id) on delete restrict,
  nama_fasilitas_snapshot text not null,   -- nama disimpan saat transaksi (tidak berubah walau fasilitas direname)
  jumlah                  integer not null check (jumlah > 0),
  dibuat_pada             timestamptz not null default now(),
  unique (peminjaman_id, fasilitas_id)
);

-- ---------------------------------------------------------------------------
-- TABEL PERSETUJUAN_PEMINJAMAN
-- Alur multi-step approval (kepala jurusan → sarpras).
-- ---------------------------------------------------------------------------
create table if not exists public.persetujuan_peminjaman (
  id              uuid primary key default gen_random_uuid(),
  peminjaman_id   uuid not null references public.peminjaman (id) on delete cascade,
  tahap           text not null
                    check (tahap in ('kepala_jurusan', 'sarpras')),
  status          text not null default 'menunggu'
                    check (status in ('menunggu', 'disetujui', 'ditolak')),
  penyetuju_id    uuid references public.pengguna (id) on delete set null,
  catatan         text,
  diputuskan_pada timestamptz,
  dibuat_pada     timestamptz not null default now(),
  unique (peminjaman_id, tahap)
);

-- ---------------------------------------------------------------------------
-- TABEL PENUGASAN_ASET
-- Aset bernomor seri yang ditugaskan ke item peminjaman tertentu.
-- ---------------------------------------------------------------------------
create table if not exists public.penugasan_aset (
  item_peminjaman_id uuid not null references public.item_peminjaman (id) on delete cascade,
  aset_id            uuid not null references public.aset_fasilitas (id) on delete restrict,
  ditugaskan_pada    timestamptz not null default now(),
  primary key (item_peminjaman_id, aset_id)
);

-- ---------------------------------------------------------------------------
-- TABEL TIKET_QR
-- Token QR untuk checkout/return. Hash saja yang disimpan.
-- ---------------------------------------------------------------------------
create table if not exists public.tiket_qr (
  id                uuid primary key default gen_random_uuid(),
  peminjaman_id     uuid not null unique references public.peminjaman (id) on delete cascade,
  hash_token        text not null unique,
  diterbitkan_oleh  uuid references public.pengguna (id) on delete set null,
  diterbitkan_pada  timestamptz not null default now(),
  kadaluarsa_pada   timestamptz not null,
  dicabut_pada      timestamptz,
  check (kadaluarsa_pada > diterbitkan_pada)
);

-- ---------------------------------------------------------------------------
-- TABEL RIWAYAT_KEJADIAN
-- Log audit setiap kejadian penting pada suatu peminjaman.
-- ---------------------------------------------------------------------------
create table if not exists public.riwayat_kejadian (
  id              uuid primary key default gen_random_uuid(),
  peminjaman_id   uuid not null references public.peminjaman (id) on delete cascade,
  tiket_id        uuid references public.tiket_qr (id) on delete set null,
  jenis           text not null
                    check (jenis in ('diambil', 'dikembalikan', 'qr_dipindai', 'status_berubah')),
  pelaku_id       uuid references public.pengguna (id) on delete set null,
  catatan         text,
  metadata        jsonb not null default '{}'::jsonb,
  terjadi_pada    timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- TABEL PERCAKAPAN, PESERTA_PERCAKAPAN, PESAN (Chat)
-- ---------------------------------------------------------------------------
create table if not exists public.percakapan (
  id              uuid primary key default gen_random_uuid(),
  dibuat_oleh     uuid not null references public.pengguna (id) on delete restrict,
  subjek          text,
  status          text not null default 'terbuka' check (status in ('terbuka', 'ditutup')),
  dibuat_pada     timestamptz not null default now(),
  diperbarui_pada timestamptz not null default now()
);

create table if not exists public.peserta_percakapan (
  percakapan_id uuid not null references public.percakapan (id) on delete cascade,
  pengguna_id   uuid not null references public.pengguna (id) on delete cascade,
  bergabung_pada timestamptz not null default now(),
  primary key (percakapan_id, pengguna_id)
);

create table if not exists public.pesan (
  id              uuid primary key default gen_random_uuid(),
  percakapan_id   uuid not null references public.percakapan (id) on delete cascade,
  pengirim_id     uuid references public.pengguna (id) on delete set null,
  isi             text,
  lampiran_url    text,
  dikirim_pada    timestamptz not null default now(),
  dibaca_pada     timestamptz,
  check (nullif(trim(isi), '') is not null or lampiran_url is not null)
);

-- =============================================================================
-- INDEX
-- =============================================================================
create index if not exists fasilitas_lokasi_status_idx
  on public.fasilitas (lokasi_id, status) where aktif;
create index if not exists aset_fasilitas_status_idx
  on public.aset_fasilitas (fasilitas_id, status);
create index if not exists peminjaman_peminjam_dibuat_idx
  on public.peminjaman (peminjam_id, dibuat_pada desc);
create index if not exists peminjaman_status_jadwal_idx
  on public.peminjaman (status, mulai_pada, estimasi_kembali_pada);
create index if not exists item_peminjaman_fasilitas_idx
  on public.item_peminjaman (fasilitas_id, peminjaman_id);
create index if not exists persetujuan_menunggu_idx
  on public.persetujuan_peminjaman (tahap, dibuat_pada)
  where status = 'menunggu';
create index if not exists riwayat_kejadian_peminjaman_idx
  on public.riwayat_kejadian (peminjaman_id, terjadi_pada desc);
create index if not exists peserta_percakapan_pengguna_idx
  on public.peserta_percakapan (pengguna_id, percakapan_id);
create index if not exists pesan_percakapan_waktu_idx
  on public.pesan (percakapan_id, dikirim_pada);

-- =============================================================================
-- FUNGSI HELPER
-- =============================================================================

-- Auto-update kolom diperbarui_pada
create or replace function public.set_diperbarui_pada()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.diperbarui_pada = now();
  return new;
end;
$$;

-- Trigger updated_at pada semua tabel yang relevan
drop trigger if exists pengguna_set_diperbarui_pada on public.pengguna;
create trigger pengguna_set_diperbarui_pada before update on public.pengguna
  for each row execute function public.set_diperbarui_pada();

drop trigger if exists lokasi_set_diperbarui_pada on public.lokasi;
create trigger lokasi_set_diperbarui_pada before update on public.lokasi
  for each row execute function public.set_diperbarui_pada();

drop trigger if exists fasilitas_set_diperbarui_pada on public.fasilitas;
create trigger fasilitas_set_diperbarui_pada before update on public.fasilitas
  for each row execute function public.set_diperbarui_pada();

drop trigger if exists aset_fasilitas_set_diperbarui_pada on public.aset_fasilitas;
create trigger aset_fasilitas_set_diperbarui_pada before update on public.aset_fasilitas
  for each row execute function public.set_diperbarui_pada();

drop trigger if exists peminjaman_set_diperbarui_pada on public.peminjaman;
create trigger peminjaman_set_diperbarui_pada before update on public.peminjaman
  for each row execute function public.set_diperbarui_pada();

drop trigger if exists percakapan_set_diperbarui_pada on public.percakapan;
create trigger percakapan_set_diperbarui_pada before update on public.percakapan
  for each row execute function public.set_diperbarui_pada();

-- ---------------------------------------------------------------------------
-- Auto-insert ke pengguna saat auth user baru dibuat
-- (handle case di mana user dibuat via Supabase Dashboard / invite)
-- ---------------------------------------------------------------------------
create or replace function public.tangani_pengguna_auth_baru()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.pengguna (id, nama_lengkap, email)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data->>'full_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Pengguna'
    ),
    new.email
  )
  on conflict (id) do nothing;  -- edge function sudah insert duluan → skip
  return new;
end;
$$;

drop trigger if exists on_auth_pengguna_dibuat on auth.users;
create trigger on_auth_pengguna_dibuat
  after insert on auth.users
  for each row execute function public.tangani_pengguna_auth_baru();

-- Auto-sync email jika diubah via Supabase Auth
create or replace function public.sinkron_email_auth()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.pengguna set email = new.email where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_email_pengguna_diperbarui on auth.users;
create trigger on_email_pengguna_diperbarui
  after update of email on auth.users
  for each row when (old.email is distinct from new.email)
  execute function public.sinkron_email_auth();

-- ---------------------------------------------------------------------------
-- Fungsi keamanan untuk RLS
-- ---------------------------------------------------------------------------
create or replace function public.peran_pengguna_saat_ini()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select peran from public.pengguna where id = auth.uid() and aktif = true
$$;

create or replace function public.adalah_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select peran = 'admin' from public.pengguna where id = auth.uid() and aktif = true),
    false
  )
$$;

create or replace function public.adalah_admin_atau_staf()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select peran in ('admin', 'staf') from public.pengguna where id = auth.uid() and aktif = true),
    false
  )
$$;

revoke all on function public.peran_pengguna_saat_ini() from public;
revoke all on function public.adalah_admin() from public;
revoke all on function public.adalah_admin_atau_staf() from public;
grant execute on function public.peran_pengguna_saat_ini() to authenticated;
grant execute on function public.adalah_admin() to authenticated;
grant execute on function public.adalah_admin_atau_staf() to authenticated;

-- ---------------------------------------------------------------------------
-- Fungsi untuk admin update profil pengguna lain (dipanggil dari Flutter)
-- ---------------------------------------------------------------------------
create or replace function public.admin_perbarui_pengguna(
  p_pengguna_id    uuid,
  p_nama_lengkap   text,
  p_telepon        text,
  p_nomor_induk    text,
  p_kelas_atau_unit text,
  p_peran          text,
  p_aktif          boolean
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.adalah_admin() then
    raise exception 'Hanya admin yang boleh mengubah data pengguna';
  end if;
  if p_peran is not null and p_peran not in ('siswa', 'guru', 'staf') then
    raise exception 'Peran tidak valid. Pilih: siswa, guru, atau staf';
  end if;
  if p_nama_lengkap is not null and nullif(trim(p_nama_lengkap), '') is null then
    raise exception 'Nama lengkap tidak boleh kosong';
  end if;

  update public.pengguna
  set
    nama_lengkap    = coalesce(p_nama_lengkap, nama_lengkap),
    telepon         = p_telepon,
    nomor_induk     = p_nomor_induk,
    kelas_atau_unit = p_kelas_atau_unit,
    peran           = coalesce(p_peran, peran),
    aktif           = coalesce(p_aktif, aktif)
  where id = p_pengguna_id
    and peran <> 'admin';  -- admin tidak bisa diubah dari sini

  if not found then
    raise exception 'Pengguna tidak ditemukan atau akun admin tidak dapat diubah';
  end if;
end;
$$;

revoke all on function public.admin_perbarui_pengguna(uuid, text, text, text, text, text, boolean) from public;
grant execute on function public.admin_perbarui_pengguna(uuid, text, text, text, text, text, boolean) to authenticated;

-- =============================================================================
-- ROW LEVEL SECURITY
-- =============================================================================
alter table public.pengguna              enable row level security;
alter table public.lokasi                enable row level security;
alter table public.fasilitas             enable row level security;
alter table public.aset_fasilitas        enable row level security;
alter table public.peminjaman            enable row level security;
alter table public.item_peminjaman       enable row level security;
alter table public.persetujuan_peminjaman enable row level security;
alter table public.penugasan_aset        enable row level security;
alter table public.tiket_qr              enable row level security;
alter table public.riwayat_kejadian      enable row level security;
alter table public.percakapan            enable row level security;
alter table public.peserta_percakapan    enable row level security;
alter table public.pesan                 enable row level security;

-- pengguna: lihat diri sendiri atau admin/staf
drop policy if exists pengguna_baca_sendiri_atau_admin on public.pengguna;
create policy pengguna_baca_sendiri_atau_admin on public.pengguna
  for select to authenticated
  using (id = auth.uid() or public.adalah_admin_atau_staf());

drop policy if exists pengguna_perbarui_sendiri on public.pengguna;
create policy pengguna_perbarui_sendiri on public.pengguna
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid() and peran = (select peran from public.pengguna where id = auth.uid()));

-- lokasi
drop policy if exists lokasi_baca_semua on public.lokasi;
create policy lokasi_baca_semua on public.lokasi
  for select to authenticated using (aktif or public.adalah_admin_atau_staf());
drop policy if exists lokasi_kelola_admin on public.lokasi;
create policy lokasi_kelola_admin on public.lokasi
  for all to authenticated
  using (public.adalah_admin_atau_staf())
  with check (public.adalah_admin_atau_staf());

-- fasilitas
drop policy if exists fasilitas_baca_semua on public.fasilitas;
create policy fasilitas_baca_semua on public.fasilitas
  for select to authenticated using (aktif or public.adalah_admin_atau_staf());
drop policy if exists fasilitas_kelola_admin on public.fasilitas;
create policy fasilitas_kelola_admin on public.fasilitas
  for all to authenticated
  using (public.adalah_admin_atau_staf())
  with check (public.adalah_admin_atau_staf());

-- aset_fasilitas
drop policy if exists aset_kelola_admin on public.aset_fasilitas;
create policy aset_kelola_admin on public.aset_fasilitas
  for all to authenticated
  using (public.adalah_admin_atau_staf())
  with check (public.adalah_admin_atau_staf());

-- peminjaman
drop policy if exists peminjaman_baca_milik_atau_admin on public.peminjaman;
create policy peminjaman_baca_milik_atau_admin on public.peminjaman
  for select to authenticated
  using (peminjam_id = auth.uid() or public.adalah_admin_atau_staf());
drop policy if exists peminjaman_buat_sendiri on public.peminjaman;
create policy peminjaman_buat_sendiri on public.peminjaman
  for insert to authenticated
  with check (peminjam_id = auth.uid() and status = 'menunggu_persetujuan');
drop policy if exists peminjaman_kelola_admin on public.peminjaman;
create policy peminjaman_kelola_admin on public.peminjaman
  for all to authenticated
  using (public.adalah_admin_atau_staf())
  with check (public.adalah_admin_atau_staf());

-- item_peminjaman
drop policy if exists item_baca_milik_atau_admin on public.item_peminjaman;
create policy item_baca_milik_atau_admin on public.item_peminjaman
  for select to authenticated
  using (
    public.adalah_admin_atau_staf()
    or exists (
      select 1 from public.peminjaman p
      where p.id = peminjaman_id and p.peminjam_id = auth.uid()
    )
  );
drop policy if exists item_buat_untuk_peminjaman_sendiri on public.item_peminjaman;
create policy item_buat_untuk_peminjaman_sendiri on public.item_peminjaman
  for insert to authenticated
  with check (
    exists (
      select 1 from public.peminjaman p
      where p.id = peminjaman_id
        and p.peminjam_id = auth.uid()
        and p.status = 'menunggu_persetujuan'
    )
  );
drop policy if exists item_kelola_admin on public.item_peminjaman;
create policy item_kelola_admin on public.item_peminjaman
  for all to authenticated
  using (public.adalah_admin_atau_staf())
  with check (public.adalah_admin_atau_staf());

-- persetujuan_peminjaman
drop policy if exists persetujuan_baca_milik_atau_admin on public.persetujuan_peminjaman;
create policy persetujuan_baca_milik_atau_admin on public.persetujuan_peminjaman
  for select to authenticated
  using (
    public.adalah_admin_atau_staf()
    or exists (
      select 1 from public.peminjaman p
      where p.id = peminjaman_id and p.peminjam_id = auth.uid()
    )
  );
drop policy if exists persetujuan_kelola_admin on public.persetujuan_peminjaman;
create policy persetujuan_kelola_admin on public.persetujuan_peminjaman
  for all to authenticated
  using (public.adalah_admin_atau_staf())
  with check (public.adalah_admin_atau_staf());

-- riwayat_kejadian
drop policy if exists riwayat_baca_milik_atau_admin on public.riwayat_kejadian;
create policy riwayat_baca_milik_atau_admin on public.riwayat_kejadian
  for select to authenticated
  using (
    public.adalah_admin_atau_staf()
    or exists (
      select 1 from public.peminjaman p
      where p.id = peminjaman_id and p.peminjam_id = auth.uid()
    )
  );
drop policy if exists riwayat_insert_admin on public.riwayat_kejadian;
create policy riwayat_insert_admin on public.riwayat_kejadian
  for insert to authenticated
  with check (public.adalah_admin_atau_staf());

-- percakapan
drop policy if exists percakapan_baca_peserta_atau_admin on public.percakapan;
create policy percakapan_baca_peserta_atau_admin on public.percakapan
  for select to authenticated
  using (
    public.adalah_admin_atau_staf()
    or dibuat_oleh = auth.uid()
    or exists (
      select 1 from public.peserta_percakapan pp
      where pp.percakapan_id = id and pp.pengguna_id = auth.uid()
    )
  );
drop policy if exists percakapan_buat_sendiri on public.percakapan;
create policy percakapan_buat_sendiri on public.percakapan
  for insert to authenticated
  with check (dibuat_oleh = auth.uid());

-- pesan
drop policy if exists pesan_baca_peserta_atau_admin on public.pesan;
create policy pesan_baca_peserta_atau_admin on public.pesan
  for select to authenticated
  using (
    public.adalah_admin_atau_staf()
    or exists (
      select 1 from public.peserta_percakapan pp
      where pp.percakapan_id = pesan.percakapan_id and pp.pengguna_id = auth.uid()
    )
  );
drop policy if exists pesan_kirim_peserta on public.pesan;
create policy pesan_kirim_peserta on public.pesan
  for insert to authenticated
  with check (
    pengirim_id = auth.uid()
    and exists (
      select 1 from public.peserta_percakapan pp
      where pp.percakapan_id = pesan.percakapan_id and pp.pengguna_id = auth.uid()
    )
  );

-- =============================================================================
-- GRANT
-- =============================================================================
grant usage on schema public to authenticated;
grant select, insert, update, delete on table
  public.pengguna,
  public.lokasi,
  public.fasilitas,
  public.aset_fasilitas,
  public.peminjaman,
  public.item_peminjaman,
  public.persetujuan_peminjaman,
  public.penugasan_aset,
  public.tiket_qr,
  public.riwayat_kejadian,
  public.percakapan,
  public.peserta_percakapan,
  public.pesan
to authenticated;

commit;
