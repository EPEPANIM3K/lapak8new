-- Run this once in the Supabase SQL Editor after schema.sql is installed.
begin;

alter table public.profiles add column if not exists email text;

update public.profiles p
set email = u.email
from auth.users u
where u.id = p.id
  and p.email is distinct from u.email;

create or replace function public.is_staff_or_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select role in ('staff', 'admin') and is_active
      from public.profiles
      where id = auth.uid()
    ),
    false
  )
$$;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Pengguna'
    ),
    new.email
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create or replace function public.sync_auth_user_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles set email = new.email where id = new.id;
  return new;
end;
$$;

drop trigger if exists on_auth_user_email_updated on auth.users;
create trigger on_auth_user_email_updated
  after update of email on auth.users
  for each row when (old.email is distinct from new.email)
  execute function public.sync_auth_user_email();

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
set search_path = public
as $$
begin
  if not public.is_staff_or_admin() then
    raise exception 'Akses hanya untuk admin atau staf';
  end if;
  if p_role is not null and p_role not in ('student', 'teacher', 'staff') then
    raise exception 'Peran akun tidak valid';
  end if;
  if p_full_name is not null and nullif(trim(p_full_name), '') is null then
    raise exception 'Nama pengguna wajib diisi';
  end if;

  if p_full_name is null then
    update public.profiles
    set is_active = coalesce(p_is_active, is_active)
    where id = p_profile_id and role <> 'admin';
  else
    update public.profiles
    set full_name = p_full_name,
        phone = p_phone,
        identity_number = p_identity_number,
        class_or_unit = p_class_or_unit,
        role = coalesce(p_role, role),
        is_active = coalesce(p_is_active, is_active)
    where id = p_profile_id and role <> 'admin';
  end if;

  if not found then
    raise exception 'Pengguna tidak ditemukan atau akun admin tidak dapat diubah dari halaman ini';
  end if;
end;
$$;

revoke all on function public.admin_update_managed_profile(
  uuid, text, text, text, text, text, boolean
) from public;
grant execute on function public.admin_update_managed_profile(
  uuid, text, text, text, text, text, boolean
) to authenticated;

commit;
