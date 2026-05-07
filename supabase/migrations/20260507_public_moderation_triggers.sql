-- Enforce album moderation settings for guest submissions (both anon and authenticated).
-- Guests should never be able to self-approve by setting `status='approved'` client-side.
--
-- Owner inserts are not modified.
--
-- Safe to re-run.

create or replace function public.enforce_guest_media_status()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  m_enabled boolean;
  m_auto boolean;
begin
  -- Do not override status for album owners (admin actions).
  if public.is_album_owner(new.album_id) then
    return new;
  end if;

  select
    coalesce(s.moderation_enabled, false),
    coalesce(s.auto_approve_uploads, true)
  into m_enabled, m_auto
  from public.album_settings s
  where s.album_id = new.album_id
  limit 1;

  if m_enabled and not m_auto then
    new.status := 'pending';
    new.approved_at := null;
  else
    new.status := 'approved';
    if new.approved_at is null then
      new.approved_at := now();
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_guest_media_status on public.media_uploads;
create trigger trg_enforce_guest_media_status
before insert on public.media_uploads
for each row
execute function public.enforce_guest_media_status();

create or replace function public.enforce_guest_note_status()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  m_enabled boolean;
  m_auto boolean;
begin
  if public.is_album_owner(new.album_id) then
    return new;
  end if;

  select
    coalesce(s.moderation_enabled, false),
    coalesce(s.auto_approve_notes, true)
  into m_enabled, m_auto
  from public.album_settings s
  where s.album_id = new.album_id
  limit 1;

  if m_enabled and not m_auto then
    new.status := 'pending';
    new.approved_at := null;
  else
    new.status := 'approved';
    if new.approved_at is null then
      new.approved_at := now();
    end if;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_enforce_guest_note_status on public.notes;
create trigger trg_enforce_guest_note_status
before insert on public.notes
for each row
execute function public.enforce_guest_note_status();

