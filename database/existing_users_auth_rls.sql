-- LAPAK8 compatibility migration for the existing bigint-based public.users schema.
-- Run only against the existing 12-table database after taking a backup.
-- This does not create Auth accounts, change auth_id mappings, or read password_hash.
-- Non-admin users can read the catalog and their own records; only admins can write.

begin;

do $preflight$
declare
  required_table text;
begin
  foreach required_table in array array[
    'users',
    'activity_logs',
    'borrowings',
    'categories',
    'facilities',
    'facility_pics',
    'locations',
    'notifications',
    'return_documentation',
    'return_inspections',
    'rules',
    'time_slots'
  ]
  loop
    if to_regclass(format('public.%I', required_table)) is null then
      raise exception 'Tabel public.% tidak ditemukan; migrasi dibatalkan',
        required_table;
    end if;
  end loop;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'auth_id'
      and data_type = 'uuid'
  ) then
    raise exception 'public.users.auth_id UUID tidak ditemukan; migrasi dibatalkan';
  end if;

  if not exists (
    select 1
    from information_schema.columns
    where table_schema = 'public'
      and table_name = 'users'
      and column_name = 'password_hash'
  ) then
    raise exception 'Kolom password_hash tidak ditemukan; tinjau grant kolom sebelum migrasi';
  end if;

  if to_regclass('public.profiles') is not null then
    raise exception 'public.profiles sudah ada; migrasi kompatibilitas tidak akan menimpanya';
  end if;

  if exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = any (array[
        'users',
        'activity_logs',
        'borrowings',
        'categories',
        'facilities',
        'facility_pics',
        'locations',
        'notifications',
        'return_documentation',
        'return_inspections',
        'rules',
        'time_slots'
      ])
      and not (
        tablename = 'users'
        and policyname = 'users_read_own'
        and roles = array['authenticated']::name[]
        and cmd = 'SELECT'
        and qual = '(auth_id = auth.uid())'
        and with_check is null
      )
  ) then
    raise exception 'Policy selain users_read_own ditemukan; migrasi dibatalkan agar akses lama tidak berubah';
  end if;

  if exists (
    select 1
    from public.users
    where role not in ('admin', 'guru', 'petugas', 'siswa')
  ) then
    raise exception 'Ada role users di luar admin/guru/petugas/siswa; tinjau pemetaan role';
  end if;
end;
$preflight$;

create or replace function public.current_lapak8_user_id()
returns bigint
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select u.id
  from public.users as u
  where u.auth_id = auth.uid()
    and u.is_active
  limit 1
$function$;

create or replace function public.current_lapak8_role()
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select u.role
  from public.users as u
  where u.auth_id = auth.uid()
    and u.is_active
  limit 1
$function$;

create or replace function public.is_lapak8_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $function$
  select coalesce(public.current_lapak8_role() = 'admin', false)
$function$;

revoke all on function public.current_lapak8_user_id() from public, anon;
revoke all on function public.current_lapak8_role() from public, anon;
revoke all on function public.is_lapak8_admin() from public, anon;
grant execute on function public.current_lapak8_user_id() to authenticated;
grant execute on function public.current_lapak8_role() to authenticated;
grant execute on function public.is_lapak8_admin() to authenticated;

create view public.profiles
with (security_invoker = true)
as
select
  u.auth_id as id,
  u.name as full_name,
  u.email,
  u.id_number as identity_number,
  u.role_class as class_or_unit,
  u.phone,
  case u.role
    when 'siswa' then 'student'
    when 'guru' then 'teacher'
    when 'petugas' then 'staff'
    when 'admin' then 'admin'
    else u.role
  end as role,
  u.is_active
from public.users as u
where u.auth_id is not null;

create or replace function public.admin_update_managed_profile(
  p_profile_id uuid,
  p_full_name text,
  p_phone text,
  p_identity_number text,
  p_class_or_unit text,
  p_role text,
  p_is_active boolean
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $function$
declare
  mapped_role text;
begin
  if not public.is_lapak8_admin() then
    raise exception 'Akses hanya untuk admin';
  end if;

  if p_role is not null and p_role not in ('student', 'teacher', 'staff') then
    raise exception 'Peran akun tidak valid';
  end if;

  if p_full_name is not null and nullif(trim(p_full_name), '') is null then
    raise exception 'Nama pengguna wajib diisi';
  end if;

  mapped_role := case p_role
    when 'student' then 'siswa'
    when 'teacher' then 'guru'
    when 'staff' then 'petugas'
    else null
  end;

  if p_full_name is null then
    update public.users as u
    set is_active = coalesce(p_is_active, u.is_active)
    where u.auth_id = p_profile_id
      and u.role <> 'admin';
  else
    update public.users as u
    set name = trim(p_full_name),
        phone = p_phone,
        id_number = p_identity_number,
        role_class = p_class_or_unit,
        role = coalesce(mapped_role, u.role),
        is_active = coalesce(p_is_active, u.is_active)
    where u.auth_id = p_profile_id
      and u.role <> 'admin';
  end if;

  if not found then
    raise exception 'Pengguna tidak ditemukan/terhubung atau akun admin tidak dapat diubah dari halaman ini';
  end if;
end;
$function$;

revoke all on function public.admin_update_managed_profile(
  uuid, text, text, text, text, text, boolean
) from public, anon;
grant execute on function public.admin_update_managed_profile(
  uuid, text, text, text, text, text, boolean
) to authenticated;

alter table public.users enable row level security;
alter table public.activity_logs enable row level security;
alter table public.borrowings enable row level security;
alter table public.categories enable row level security;
alter table public.facilities enable row level security;
alter table public.facility_pics enable row level security;
alter table public.locations enable row level security;
alter table public.notifications enable row level security;
alter table public.return_documentation enable row level security;
alter table public.return_inspections enable row level security;
alter table public.rules enable row level security;
alter table public.time_slots enable row level security;

drop policy if exists users_read_own on public.users;
drop policy if exists users_read_self_or_admin on public.users;
create policy users_read_self_or_admin on public.users
  for select to authenticated
  using (id = public.current_lapak8_user_id() or public.is_lapak8_admin());

drop policy if exists activity_logs_read_admin on public.activity_logs;
create policy activity_logs_read_admin on public.activity_logs
  for select to authenticated
  using (public.is_lapak8_admin());

drop policy if exists borrowings_read_owner_or_admin on public.borrowings;
create policy borrowings_read_owner_or_admin on public.borrowings
  for select to authenticated
  using (
    borrower_id = public.current_lapak8_user_id()
    or public.is_lapak8_admin()
  );
drop policy if exists borrowings_manage_admin on public.borrowings;
create policy borrowings_manage_admin on public.borrowings
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

drop policy if exists categories_read_authenticated on public.categories;
create policy categories_read_authenticated on public.categories
  for select to authenticated
  using (true);
drop policy if exists categories_manage_admin on public.categories;
create policy categories_manage_admin on public.categories
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

drop policy if exists facilities_read_active_or_admin on public.facilities;
create policy facilities_read_active_or_admin on public.facilities
  for select to authenticated
  using (is_active or public.is_lapak8_admin());
drop policy if exists facilities_manage_admin on public.facilities;
create policy facilities_manage_admin on public.facilities
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

drop policy if exists facility_pics_read_authenticated on public.facility_pics;
create policy facility_pics_read_authenticated on public.facility_pics
  for select to authenticated
  using (true);
drop policy if exists facility_pics_manage_admin on public.facility_pics;
create policy facility_pics_manage_admin on public.facility_pics
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

drop policy if exists locations_read_authenticated on public.locations;
create policy locations_read_authenticated on public.locations
  for select to authenticated
  using (true);
drop policy if exists locations_manage_admin on public.locations;
create policy locations_manage_admin on public.locations
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

drop policy if exists notifications_read_owner_or_admin on public.notifications;
create policy notifications_read_owner_or_admin on public.notifications
  for select to authenticated
  using (
    user_id = public.current_lapak8_user_id()
    or public.is_lapak8_admin()
  );
drop policy if exists notifications_manage_admin on public.notifications;
create policy notifications_manage_admin on public.notifications
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

drop policy if exists return_documentation_read_owner_or_admin on public.return_documentation;
create policy return_documentation_read_owner_or_admin on public.return_documentation
  for select to authenticated
  using (
    public.is_lapak8_admin()
    or exists (
      select 1
      from public.return_inspections as ri
      join public.borrowings as b on b.id = ri.borrowing_id
      where ri.id = return_documentation.inspection_id
        and b.borrower_id = public.current_lapak8_user_id()
    )
  );
drop policy if exists return_documentation_manage_admin on public.return_documentation;
create policy return_documentation_manage_admin on public.return_documentation
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

drop policy if exists return_inspections_read_owner_or_admin on public.return_inspections;
create policy return_inspections_read_owner_or_admin on public.return_inspections
  for select to authenticated
  using (
    public.is_lapak8_admin()
    or exists (
      select 1
      from public.borrowings as b
      where b.id = return_inspections.borrowing_id
        and b.borrower_id = public.current_lapak8_user_id()
    )
  );
drop policy if exists return_inspections_manage_admin on public.return_inspections;
create policy return_inspections_manage_admin on public.return_inspections
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

drop policy if exists rules_read_active_or_admin on public.rules;
create policy rules_read_active_or_admin on public.rules
  for select to authenticated
  using (is_active or public.is_lapak8_admin());
drop policy if exists rules_manage_admin on public.rules;
create policy rules_manage_admin on public.rules
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

drop policy if exists time_slots_read_active_or_admin on public.time_slots;
create policy time_slots_read_active_or_admin on public.time_slots
  for select to authenticated
  using (is_active or public.is_lapak8_admin());
drop policy if exists time_slots_manage_admin on public.time_slots;
create policy time_slots_manage_admin on public.time_slots
  for all to authenticated
  using (public.is_lapak8_admin())
  with check (public.is_lapak8_admin());

grant usage on schema public to authenticated;
revoke all on table
  public.users,
  public.activity_logs,
  public.borrowings,
  public.categories,
  public.facilities,
  public.facility_pics,
  public.locations,
  public.notifications,
  public.return_documentation,
  public.return_inspections,
  public.rules,
  public.time_slots
from anon, authenticated;
revoke select (password_hash), insert (password_hash), update (password_hash),
  references (password_hash)
on table public.users from anon, authenticated;

-- Never expose password_hash through the Data API, including to admins.
grant select (
  id, name, email, id_number, id_type, role, role_class, phone, avatar_url,
  is_active, loan_count, late_count, created_at, updated_at, auth_id
) on public.users to authenticated;

grant select on public.profiles to authenticated;
revoke all on public.profiles from anon;
grant select on public.activity_logs to authenticated;
grant select, insert, update, delete on table
  public.borrowings,
  public.categories,
  public.facilities,
  public.facility_pics,
  public.locations,
  public.notifications,
  public.return_documentation,
  public.return_inspections,
  public.rules,
  public.time_slots
to authenticated;

commit;
