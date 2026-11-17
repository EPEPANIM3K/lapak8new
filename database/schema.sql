-- LAPAK8 database schema for Supabase (PostgreSQL).
-- Supabase Auth owns credentials; public.profiles stores application profile data.

begin;

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null,
  phone text,
  identity_number text unique,
  class_or_unit text,
  role text not null default 'student'
    check (role in ('student', 'teacher', 'staff', 'admin')),
  photo_url text,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.locations (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  pic_user_id uuid references public.profiles (id) on delete set null,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.facilities (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  category text,
  description text,
  location_id uuid references public.locations (id) on delete set null,
  total_units integer not null default 0 check (total_units >= 0),
  image_url text,
  status text not null default 'available'
    check (status in ('available', 'maintenance', 'inactive')),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Optional per-unit inventory for equipment that has an asset tag or serial number.
create table if not exists public.facility_assets (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities (id) on delete restrict,
  asset_tag text not null unique,
  serial_number text,
  condition text not null default 'good'
    check (condition in ('good', 'fair', 'damaged')),
  status text not null default 'available'
    check (status in ('available', 'maintenance', 'retired')),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (facility_id, serial_number)
);

create table if not exists public.borrowings (
  id uuid primary key default gen_random_uuid(),
  booking_code text not null unique,
  borrower_id uuid not null references public.profiles (id) on delete restrict,
  category text not null
    check (category in ('praktik', 'ekskul', 'lainnya')),
  event_name text not null,
  purpose_notes text,
  starts_at timestamptz not null,
  expected_return_at timestamptz not null,
  status text not null default 'pending_approval'
    check (status in (
      'pending_approval', 'approved', 'rejected', 'canceled',
      'borrowed', 'returned', 'overdue'
    )),
  rejection_reason text,
  applied_at timestamptz not null default now(),
  approved_at timestamptz,
  checked_out_at timestamptz,
  returned_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (expected_return_at > starts_at)
);

create table if not exists public.borrowing_items (
  id uuid primary key default gen_random_uuid(),
  borrowing_id uuid not null references public.borrowings (id) on delete cascade,
  facility_id uuid not null references public.facilities (id) on delete restrict,
  facility_name_snapshot text not null,
  quantity integer not null check (quantity > 0),
  created_at timestamptz not null default now(),
  unique (borrowing_id, facility_id)
);

create table if not exists public.borrowing_approvals (
  id uuid primary key default gen_random_uuid(),
  borrowing_id uuid not null references public.borrowings (id) on delete cascade,
  approval_step text not null
    check (approval_step in ('department_head', 'sarpras')),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  approver_id uuid references public.profiles (id) on delete set null,
  note text,
  decided_at timestamptz,
  created_at timestamptz not null default now(),
  unique (borrowing_id, approval_step)
);

-- Assign individual serialized units to a booking when the inventory requires it.
create table if not exists public.borrowing_asset_assignments (
  borrowing_item_id uuid not null references public.borrowing_items (id) on delete cascade,
  asset_id uuid not null references public.facility_assets (id) on delete restrict,
  assigned_at timestamptz not null default now(),
  primary key (borrowing_item_id, asset_id)
);

-- Store only a hash of the QR token. Issue/validate tokens through a trusted server function.
create table if not exists public.borrowing_qr_tickets (
  id uuid primary key default gen_random_uuid(),
  borrowing_id uuid not null unique references public.borrowings (id) on delete cascade,
  token_hash text not null unique,
  issued_by uuid references public.profiles (id) on delete set null,
  issued_at timestamptz not null default now(),
  expires_at timestamptz not null,
  revoked_at timestamptz,
  check (expires_at > issued_at)
);

create table if not exists public.borrowing_events (
  id uuid primary key default gen_random_uuid(),
  borrowing_id uuid not null references public.borrowings (id) on delete cascade,
  ticket_id uuid references public.borrowing_qr_tickets (id) on delete set null,
  event_type text not null
    check (event_type in ('checked_out', 'returned', 'qr_scanned', 'status_changed')),
  actor_id uuid references public.profiles (id) on delete set null,
  notes text,
  metadata jsonb not null default '{}'::jsonb,
  occurred_at timestamptz not null default now()
);

-- Chat tables are included for the planned chat feature; its current Dart files are empty.
create table if not exists public.chat_threads (
  id uuid primary key default gen_random_uuid(),
  created_by uuid not null references public.profiles (id) on delete restrict,
  subject text,
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.chat_participants (
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  profile_id uuid not null references public.profiles (id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (thread_id, profile_id)
);

create table if not exists public.chat_messages (
  id uuid primary key default gen_random_uuid(),
  thread_id uuid not null references public.chat_threads (id) on delete cascade,
  sender_id uuid references public.profiles (id) on delete set null,
  body text,
  attachment_url text,
  sent_at timestamptz not null default now(),
  read_at timestamptz,
  check (nullif(trim(body), '') is not null or attachment_url is not null)
);

create index if not exists facilities_location_status_idx
  on public.facilities (location_id, status) where is_active;
create index if not exists facility_assets_facility_status_idx
  on public.facility_assets (facility_id, status);
create index if not exists borrowings_borrower_created_idx
  on public.borrowings (borrower_id, created_at desc);
create index if not exists borrowings_status_schedule_idx
  on public.borrowings (status, starts_at, expected_return_at);
create index if not exists borrowing_items_facility_idx
  on public.borrowing_items (facility_id, borrowing_id);
create index if not exists borrowing_approvals_pending_idx
  on public.borrowing_approvals (approval_step, created_at)
  where status = 'pending';
create index if not exists borrowing_events_borrowing_time_idx
  on public.borrowing_events (borrowing_id, occurred_at desc);
create index if not exists chat_participants_profile_idx
  on public.chat_participants (profile_id, thread_id);
create index if not exists chat_messages_thread_time_idx
  on public.chat_messages (thread_id, sent_at);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
drop trigger if exists locations_set_updated_at on public.locations;
create trigger locations_set_updated_at before update on public.locations
  for each row execute function public.set_updated_at();
drop trigger if exists facilities_set_updated_at on public.facilities;
create trigger facilities_set_updated_at before update on public.facilities
  for each row execute function public.set_updated_at();
drop trigger if exists facility_assets_set_updated_at on public.facility_assets;
create trigger facility_assets_set_updated_at before update on public.facility_assets
  for each row execute function public.set_updated_at();
drop trigger if exists borrowings_set_updated_at on public.borrowings;
create trigger borrowings_set_updated_at before update on public.borrowings
  for each row execute function public.set_updated_at();
drop trigger if exists chat_threads_set_updated_at on public.chat_threads;
create trigger chat_threads_set_updated_at before update on public.chat_threads
  for each row execute function public.set_updated_at();

create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.is_staff_or_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_profile_role() in ('staff', 'admin'), false)
$$;

revoke all on function public.current_profile_role() from public;
revoke all on function public.is_staff_or_admin() from public;
grant execute on function public.current_profile_role() to authenticated;
grant execute on function public.is_staff_or_admin() to authenticated;

create or replace function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name)
  values (
    new.id,
    coalesce(
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      nullif(split_part(coalesce(new.email, ''), '@', 1), ''),
      'Pengguna'
    )
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

alter table public.profiles enable row level security;
alter table public.locations enable row level security;
alter table public.facilities enable row level security;
alter table public.facility_assets enable row level security;
alter table public.borrowings enable row level security;
alter table public.borrowing_items enable row level security;
alter table public.borrowing_approvals enable row level security;
alter table public.borrowing_asset_assignments enable row level security;
alter table public.borrowing_qr_tickets enable row level security;
alter table public.borrowing_events enable row level security;
alter table public.chat_threads enable row level security;
alter table public.chat_participants enable row level security;
alter table public.chat_messages enable row level security;

drop policy if exists profiles_read_self_or_staff on public.profiles;
create policy profiles_read_self_or_staff on public.profiles
  for select to authenticated
  using (id = auth.uid() or public.is_staff_or_admin());

drop policy if exists locations_read_authenticated on public.locations;
create policy locations_read_authenticated on public.locations
  for select to authenticated using (is_active or public.is_staff_or_admin());
drop policy if exists locations_manage_staff on public.locations;
create policy locations_manage_staff on public.locations
  for all to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

drop policy if exists facilities_read_authenticated on public.facilities;
create policy facilities_read_authenticated on public.facilities
  for select to authenticated using (is_active or public.is_staff_or_admin());
drop policy if exists facilities_manage_staff on public.facilities;
create policy facilities_manage_staff on public.facilities
  for all to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

drop policy if exists facility_assets_manage_staff on public.facility_assets;
create policy facility_assets_manage_staff on public.facility_assets
  for all to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

drop policy if exists borrowings_read_owner_or_staff on public.borrowings;
create policy borrowings_read_owner_or_staff on public.borrowings
  for select to authenticated
  using (borrower_id = auth.uid() or public.is_staff_or_admin());
drop policy if exists borrowings_create_owner on public.borrowings;
create policy borrowings_create_owner on public.borrowings
  for insert to authenticated
  with check (borrower_id = auth.uid() and status = 'pending_approval');
drop policy if exists borrowings_manage_staff on public.borrowings;
create policy borrowings_manage_staff on public.borrowings
  for all to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

drop policy if exists borrowing_items_read_owner_or_staff on public.borrowing_items;
create policy borrowing_items_read_owner_or_staff on public.borrowing_items
  for select to authenticated
  using (
    public.is_staff_or_admin()
    or exists (
      select 1 from public.borrowings b
      where b.id = borrowing_id and b.borrower_id = auth.uid()
    )
  );
drop policy if exists borrowing_items_create_for_own_pending on public.borrowing_items;
create policy borrowing_items_create_for_own_pending on public.borrowing_items
  for insert to authenticated
  with check (
    exists (
      select 1 from public.borrowings b
      where b.id = borrowing_id
        and b.borrower_id = auth.uid()
        and b.status = 'pending_approval'
    )
  );
drop policy if exists borrowing_items_manage_staff on public.borrowing_items;
create policy borrowing_items_manage_staff on public.borrowing_items
  for all to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

drop policy if exists borrowing_approvals_read_owner_or_staff on public.borrowing_approvals;
create policy borrowing_approvals_read_owner_or_staff on public.borrowing_approvals
  for select to authenticated
  using (
    public.is_staff_or_admin()
    or exists (
      select 1 from public.borrowings b
      where b.id = borrowing_id and b.borrower_id = auth.uid()
    )
  );
drop policy if exists borrowing_approvals_manage_staff on public.borrowing_approvals;
create policy borrowing_approvals_manage_staff on public.borrowing_approvals
  for all to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

drop policy if exists borrowing_asset_assignments_manage_staff on public.borrowing_asset_assignments;
create policy borrowing_asset_assignments_manage_staff on public.borrowing_asset_assignments
  for all to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

-- QR token hashes are intentionally server-only; no direct authenticated-client policy.
drop policy if exists borrowing_events_read_owner_or_staff on public.borrowing_events;
create policy borrowing_events_read_owner_or_staff on public.borrowing_events
  for select to authenticated
  using (
    public.is_staff_or_admin()
    or exists (
      select 1 from public.borrowings b
      where b.id = borrowing_id and b.borrower_id = auth.uid()
    )
  );
drop policy if exists borrowing_events_insert_staff on public.borrowing_events;
create policy borrowing_events_insert_staff on public.borrowing_events
  for insert to authenticated
  with check (public.is_staff_or_admin());

drop policy if exists chat_threads_read_participant_or_staff on public.chat_threads;
create policy chat_threads_read_participant_or_staff on public.chat_threads
  for select to authenticated
  using (
    public.is_staff_or_admin()
    or created_by = auth.uid()
    or exists (
      select 1 from public.chat_participants cp
      where cp.thread_id = id and cp.profile_id = auth.uid()
    )
  );
drop policy if exists chat_threads_create_owner on public.chat_threads;
create policy chat_threads_create_owner on public.chat_threads
  for insert to authenticated
  with check (created_by = auth.uid());
drop policy if exists chat_threads_manage_staff on public.chat_threads;
create policy chat_threads_manage_staff on public.chat_threads
  for all to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

drop policy if exists chat_participants_read_self_or_staff on public.chat_participants;
create policy chat_participants_read_self_or_staff on public.chat_participants
  for select to authenticated
  using (profile_id = auth.uid() or public.is_staff_or_admin());
drop policy if exists chat_participants_join_own_thread on public.chat_participants;
create policy chat_participants_join_own_thread on public.chat_participants
  for insert to authenticated
  with check (
    profile_id = auth.uid()
    and exists (
      select 1 from public.chat_threads t
      where t.id = thread_id and t.created_by = auth.uid()
    )
  );
drop policy if exists chat_participants_manage_staff on public.chat_participants;
create policy chat_participants_manage_staff on public.chat_participants
  for all to authenticated
  using (public.is_staff_or_admin())
  with check (public.is_staff_or_admin());

drop policy if exists chat_messages_read_participant_or_staff on public.chat_messages;
create policy chat_messages_read_participant_or_staff on public.chat_messages
  for select to authenticated
  using (
    public.is_staff_or_admin()
    or exists (
      select 1 from public.chat_participants cp
      where cp.thread_id = chat_messages.thread_id and cp.profile_id = auth.uid()
    )
  );
drop policy if exists chat_messages_send_as_participant on public.chat_messages;
create policy chat_messages_send_as_participant on public.chat_messages
  for insert to authenticated
  with check (
    sender_id = auth.uid()
    and exists (
      select 1 from public.chat_participants cp
      where cp.thread_id = chat_messages.thread_id and cp.profile_id = auth.uid()
    )
  );

grant usage on schema public to authenticated;
grant select, insert, update, delete on table
  public.profiles,
  public.locations,
  public.facilities,
  public.facility_assets,
  public.borrowings,
  public.borrowing_items,
  public.borrowing_approvals,
  public.borrowing_asset_assignments,
  public.borrowing_qr_tickets,
  public.borrowing_events,
  public.chat_threads,
  public.chat_participants,
  public.chat_messages
to authenticated;

commit;
