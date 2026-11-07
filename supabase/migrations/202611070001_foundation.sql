-- Followkind foundation. Run once in the project's Supabase SQL Editor.
-- Creates a private schema foundation, not a publicly writable volunteer form.
-- Fictional records only until the complete access flow has been verified.
begin;

create table public.workspaces (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);

create table public.staff_members (
  workspace_id uuid not null references public.workspaces(id),
  user_id uuid not null references auth.users(id),
  role text not null check (role in ('coordinator', 'supplies')),
  display_name text not null,
  primary key (workspace_id, user_id)
);

create table public.volunteers (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  display_name text not null,
  active boolean not null default true,
  unique (workspace_id, id)
);

-- A visit can contain several volunteers' reports without combining their hours.
create table public.visits (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  visit_date date not null,
  family_reference text not null,
  created_at timestamptz not null default now(),
  unique (workspace_id, id)
);

create table public.updates (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  volunteer_id uuid not null,
  visit_id uuid,
  client_submission_id uuid not null unique,
  source_message text not null,
  visit_date date not null,
  hours numeric(5,2) check (hours > 0 and hours <= 24),
  status text not null default 'draft' check (status in ('draft', 'review', 'confirmed')),
  created_at timestamptz not null default now(),
  foreign key (workspace_id, volunteer_id) references public.volunteers(workspace_id, id),
  foreign key (workspace_id, visit_id) references public.visits(workspace_id, id),
  check (status <> 'confirmed' or (hours is not null and visit_id is not null)),
  unique (workspace_id, id)
);

-- Deliberately excludes source messages and counseling information.
create table public.needs (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  title text not null,
  family_reference text not null,
  assigned_role text not null default 'supplies' check (assigned_role in ('supplies', 'coordinator')),
  status text not null default 'received' check (status in ('received', 'acknowledged', 'resolved')),
  acknowledged_by uuid references auth.users(id),
  resolved_by uuid references auth.users(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now(),
  check (status <> 'acknowledged' or acknowledged_by is not null),
  check (status <> 'resolved' or (acknowledged_by is not null and resolved_by is not null and resolved_at is not null))
);

-- Function owner reads membership without a recursive RLS policy.
create function public.has_staff_role(target_workspace uuid, allowed_roles text[])
returns boolean language sql stable security definer set search_path = '' as $$
  select exists (
    select 1 from public.staff_members m
    where m.workspace_id = target_workspace
      and m.user_id = (select auth.uid())
      and m.role = any(allowed_roles)
  );
$$;
revoke all on function public.has_staff_role(uuid, text[]) from public;
grant execute on function public.has_staff_role(uuid, text[]) to authenticated;

alter table public.workspaces enable row level security;
alter table public.staff_members enable row level security;
alter table public.volunteers enable row level security;
alter table public.visits enable row level security;
alter table public.updates enable row level security;
alter table public.needs enable row level security;

-- No anonymous reads or writes. Staff receive SELECT only; later validated RPCs
-- will own writes, transitions, deduplication and audit records.
revoke all on public.workspaces, public.staff_members, public.volunteers,
  public.visits, public.updates, public.needs from anon, authenticated;
grant select on public.workspaces, public.staff_members, public.volunteers,
  public.visits, public.updates, public.needs to authenticated;

create policy workspace_members_read on public.workspaces for select to authenticated
using (public.has_staff_role(id, array['coordinator','supplies']));
create policy own_membership_read on public.staff_members for select to authenticated
using (user_id = (select auth.uid()));
create policy coordinator_volunteers_read on public.volunteers for select to authenticated
using (public.has_staff_role(workspace_id, array['coordinator']));
create policy coordinator_visits_read on public.visits for select to authenticated
using (public.has_staff_role(workspace_id, array['coordinator']));
create policy coordinator_updates_read on public.updates for select to authenticated
using (public.has_staff_role(workspace_id, array['coordinator']));
create policy assigned_staff_needs_read on public.needs for select to authenticated
using (public.has_staff_role(workspace_id, array['coordinator'])
  or public.has_staff_role(workspace_id, array[assigned_role]));

create index updates_workspace_date_idx on public.updates(workspace_id, visit_date);
create index needs_workspace_status_idx on public.needs(workspace_id, status);

commit;
