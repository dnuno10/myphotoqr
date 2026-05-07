-- Passcode support for code-protected albums (hashing + verification)
-- plus persistent guest access grants so RLS + Realtime can enforce access
-- without relying on client-side state.
--
-- Expected album fields:
--   - albums.guest_access_code_enabled boolean
--   - albums.guest_access_code_hash text
--   - albums.visibility text ('public' | 'code_protected' | ...)
--
-- This migration is safe to re-run.

create extension if not exists pgcrypto;

create schema if not exists private;

create table if not exists private.album_access_grants (
  album_id uuid not null references public.albums(id) on delete cascade,
  auth_user_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamp with time zone not null default now(),
  last_validated_at timestamp with time zone not null default now(),
  primary key (album_id, auth_user_id)
);

alter table private.album_access_grants enable row level security;

-- No direct access from client roles.
revoke all on table private.album_access_grants from anon, authenticated;

create or replace function public.hash_guest_access_code(code text)
returns text
language sql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
  select crypt(code, gen_salt('bf', 10));
$$;

revoke all on function public.hash_guest_access_code(text) from public;
grant execute on function public.hash_guest_access_code(text) to anon, authenticated, service_role;

create or replace function public.is_album_owner(album_uuid uuid)
returns boolean
language sql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
  select exists (
    select 1
    from public.albums a
    join public.users u on u.id = a.user_id
    where a.id = album_uuid
      and u.auth_user_id = auth.uid()
  );
$$;

revoke all on function public.is_album_owner(uuid) from public;
grant execute on function public.is_album_owner(uuid) to anon, authenticated, service_role;

create or replace function public.album_requires_access_code(album_uuid uuid)
returns boolean
language sql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
  select coalesce(a.guest_access_code_enabled, false)
      or coalesce(a.visibility, 'public') = 'code_protected'
  from public.albums a
  where a.id = album_uuid
  limit 1;
$$;

revoke all on function public.album_requires_access_code(uuid) from public;
grant execute on function public.album_requires_access_code(uuid) to anon, authenticated, service_role;

create or replace function public.has_album_access(album_uuid uuid)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth, pg_temp
as $$
declare
  requires_code boolean;
begin
  select public.album_requires_access_code(album_uuid)
  into requires_code;

  if requires_code is not true then
    return true;
  end if;

  if public.is_album_owner(album_uuid) then
    return true;
  end if;

  if auth.uid() is null then
    return false;
  end if;

  return exists (
    select 1
    from private.album_access_grants g
    where g.album_id = album_uuid
      and g.auth_user_id = auth.uid()
  );
end;
$$;

revoke all on function public.has_album_access(uuid) from public;
grant execute on function public.has_album_access(uuid) to anon, authenticated, service_role;

create or replace function public.verify_guest_access_code(
  album_uuid uuid,
  code text
)
returns boolean
language plpgsql
security definer
set search_path = pg_catalog, public, private, auth, pg_temp
as $$
declare
  requires_code boolean;
  code_hash text;
  ok boolean;
begin
  select public.album_requires_access_code(album_uuid)
  into requires_code;

  if requires_code is not true then
    return true;
  end if;

  select a.guest_access_code_hash
  into code_hash
  from public.albums a
  where a.id = album_uuid
  limit 1;

  if code_hash is null or length(code_hash) < 10 then
    return false;
  end if;

  ok := crypt(code, code_hash) = code_hash;

  -- Persist access for authenticated (including anonymous) sessions.
  if ok and auth.uid() is not null then
    insert into private.album_access_grants (album_id, auth_user_id, last_validated_at)
    values (album_uuid, auth.uid(), now())
    on conflict (album_id, auth_user_id)
    do update set last_validated_at = excluded.last_validated_at;
  end if;

  return ok;
end;
$$;

revoke all on function public.verify_guest_access_code(uuid, text) from public;
grant execute on function public.verify_guest_access_code(uuid, text) to anon, authenticated, service_role;

