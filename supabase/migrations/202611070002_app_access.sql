-- Followkind application access. Run after 202611070001_foundation.sql.
-- Rerunnable. Keeps existing records. Personal links expire after seven days.
begin;
create schema if not exists followkind_private;
revoke all on schema followkind_private from public, anon, authenticated;
create table if not exists followkind_private.allowed_staff (
  email text primary key,
  workspace_id uuid not null references public.workspaces(id),
  role text not null check (role in ('coordinator','supplies')),
  display_name text not null
);
create table if not exists followkind_private.volunteer_links (
  token_hash bytea primary key,
  volunteer_id uuid not null references public.volunteers(id),
  expires_at timestamptz not null default now() + interval '7 days',
  revoked boolean not null default false
);
create table if not exists public.activity_log (
  id uuid primary key default gen_random_uuid(),
  workspace_id uuid not null references public.workspaces(id),
  actor_id uuid,
  action text not null,
  record_id uuid not null,
  created_at timestamptz not null default now()
);
alter table public.activity_log enable row level security;
revoke all on public.activity_log from anon, authenticated;
grant select on public.activity_log to authenticated;
do $$ begin
  if not exists(select 1 from pg_policies where schemaname='public' and tablename='activity_log' and policyname='coordinator_activity_read') then
    create policy coordinator_activity_read on public.activity_log for select to authenticated
    using(public.has_staff_role(workspace_id,array['coordinator']));
  end if;
end $$;

create or replace function public.followkind_claim_staff()
returns jsonb language plpgsql security definer set search_path='' as $$
declare invite followkind_private.allowed_staff%rowtype;
begin
  if auth.uid() is null or not exists(select 1 from auth.users where id=auth.uid() and email_confirmed_at is not null) then
    raise exception 'Verify your staff email before continuing';
  end if;
  select * into invite from followkind_private.allowed_staff where email=lower(auth.jwt()->>'email');
  if not found then raise exception 'This email has not been added to the team'; end if;
  insert into public.staff_members(workspace_id,user_id,role,display_name)
  values(invite.workspace_id,auth.uid(),invite.role,invite.display_name)
  on conflict(workspace_id,user_id) do nothing;
  return jsonb_build_object('workspace_id',invite.workspace_id,'role',invite.role,'display_name',invite.display_name);
end $$;

create or replace function public.followkind_create_volunteer(p_workspace uuid,p_name text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare vid uuid; token text;
begin
  if not public.has_staff_role(p_workspace,array['coordinator']) then raise exception 'Coordinator access required'; end if;
  if length(trim(p_name)) not between 1 and 100 then raise exception 'Enter a volunteer name'; end if;
  token := encode(sha256(convert_to(gen_random_uuid()::text || gen_random_uuid()::text,'UTF8')),'hex');
  insert into public.volunteers(workspace_id,display_name) values(p_workspace,trim(p_name)) returning id into vid;
  insert into followkind_private.volunteer_links(token_hash,volunteer_id) values(sha256(convert_to(token,'UTF8')),vid);
  insert into public.activity_log(workspace_id,actor_id,action,record_id) values(p_workspace,auth.uid(),'volunteer_created',vid);
  return jsonb_build_object('volunteer_id',vid,'token',token,'expires_in_days',7);
end $$;

create or replace function public.followkind_volunteer_context(p_token text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
  if p_token is null or length(p_token)<>64 then raise exception 'Invalid or expired link'; end if;
  select jsonb_build_object('volunteer_name',v.display_name,'workspace_name',w.name) into result
  from followkind_private.volunteer_links l join public.volunteers v on v.id=l.volunteer_id
  join public.workspaces w on w.id=v.workspace_id
  where l.token_hash=sha256(convert_to(p_token,'UTF8')) and not l.revoked and l.expires_at>now() and v.active;
  if result is null then raise exception 'Invalid or expired link'; end if;
  return result;
end $$;

create or replace function public.followkind_submit_update(
 p_token text,p_submission uuid,p_date date,p_hours numeric,p_family text,p_message text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare v public.volunteers%rowtype; prior public.updates%rowtype; vid uuid; uid uuid;
begin
  if p_token is null or length(p_token)<>64 then raise exception 'Invalid or expired link'; end if;
  select v1.* into v from followkind_private.volunteer_links l join public.volunteers v1 on v1.id=l.volunteer_id
  where l.token_hash=sha256(convert_to(p_token,'UTF8')) and not l.revoked and l.expires_at>now() and v1.active;
  if not found then raise exception 'Invalid or expired link'; end if;
  if p_submission is null or p_date is null or p_date>current_date or p_hours is null or p_hours<=0 or p_hours>24
    or length(trim(coalesce(p_family,''))) not between 1 and 120
    or length(trim(coalesce(p_message,''))) not between 1 and 4000 then
    raise exception 'Enter the visit date, hours, family reference and update';
  end if;
  perform pg_advisory_xact_lock(hashtext(p_submission::text));
  select * into prior from public.updates where client_submission_id=p_submission;
  if found then
    if prior.volunteer_id<>v.id or prior.source_message<>trim(p_message) or prior.hours<>p_hours
      or prior.visit_date<>p_date or not exists(select 1 from public.visits where id=prior.visit_id and family_reference=trim(p_family)) then raise exception 'Submission reference already used'; end if;
    return jsonb_build_object('id',prior.id,'status',prior.status,'hours',prior.hours,'retried',true);
  end if;
  insert into public.visits(workspace_id,visit_date,family_reference) values(v.workspace_id,p_date,trim(p_family)) returning id into vid;
  insert into public.updates(workspace_id,volunteer_id,visit_id,client_submission_id,source_message,visit_date,hours,status)
  values(v.workspace_id,v.id,vid,p_submission,trim(p_message),p_date,p_hours,'review') returning id into uid;
  insert into public.activity_log(workspace_id,action,record_id) values(v.workspace_id,'volunteer_update_submitted',uid);
  return jsonb_build_object('id',uid,'status','review','hours',p_hours,'retried',false);
end $$;

create or replace function public.followkind_review_update(p_update uuid,p_need_title text default null)
returns void language plpgsql security definer set search_path='' as $$
declare u public.updates%rowtype; family text;
begin
  select * into u from public.updates where id=p_update for update;
  if not found or not public.has_staff_role(u.workspace_id,array['coordinator']) then raise exception 'Coordinator access required'; end if;
  if u.status='confirmed' then return; end if;
  if u.hours is null or u.visit_id is null then raise exception 'Hours and visit details are required'; end if;
  if length(coalesce(p_need_title,''))>200 then raise exception 'Keep the need title under 200 characters'; end if;
  select family_reference into family from public.visits where id=u.visit_id;
  if length(trim(coalesce(p_need_title,'')))>0 then
    insert into public.needs(workspace_id,title,family_reference) values(u.workspace_id,trim(p_need_title),family);
  end if;
  update public.updates set status='confirmed' where id=u.id;
  insert into public.activity_log(workspace_id,actor_id,action,record_id) values(u.workspace_id,auth.uid(),'update_confirmed',u.id);
end $$;

create or replace function public.followkind_transition_need(p_need uuid,p_status text)
returns void language plpgsql security definer set search_path='' as $$
declare n public.needs%rowtype;
begin
  select * into n from public.needs where id=p_need for update;
  if not found or not(public.has_staff_role(n.workspace_id,array['coordinator']) or public.has_staff_role(n.workspace_id,array[n.assigned_role])) then
    raise exception 'Assigned staff access required';
  end if;
  if p_status='acknowledged' and n.status='received' then
    update public.needs set status='acknowledged',acknowledged_by=auth.uid() where id=n.id;
  elsif p_status='resolved' and n.status='acknowledged' then
    update public.needs set status='resolved',resolved_by=auth.uid(),resolved_at=now() where id=n.id;
  else raise exception 'This status change is not allowed'; end if;
  insert into public.activity_log(workspace_id,actor_id,action,record_id) values(n.workspace_id,auth.uid(),'need_'||p_status,n.id);
end $$;

revoke all on function public.followkind_claim_staff() from public;
revoke all on function public.followkind_create_volunteer(uuid,text) from public;
revoke all on function public.followkind_volunteer_context(text) from public;
revoke all on function public.followkind_submit_update(text,uuid,date,numeric,text,text) from public;
revoke all on function public.followkind_review_update(uuid,text) from public;
revoke all on function public.followkind_transition_need(uuid,text) from public;
grant execute on function public.followkind_claim_staff() to authenticated;
grant execute on function public.followkind_create_volunteer(uuid,text) to authenticated;
grant execute on function public.followkind_volunteer_context(text) to anon,authenticated;
grant execute on function public.followkind_submit_update(text,uuid,date,numeric,text,text) to anon,authenticated;
grant execute on function public.followkind_review_update(uuid,text) to authenticated;
grant execute on function public.followkind_transition_need(uuid,text) to authenticated;
commit;
