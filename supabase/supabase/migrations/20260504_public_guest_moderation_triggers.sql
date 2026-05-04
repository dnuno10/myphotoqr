-- Enforce moderation settings for guest (anon) submissions.
-- This makes `enable moderation` / `auto-approve` behave consistently even if a
-- client sends an unexpected status.
--
-- This file intentionally avoids nested DO/EXECUTE blocks (some runners split
-- dollar-quoted SQL and fail). It is safe to re-run.

create or replace function public.enforce_guest_media_status()
returns trigger
language plpgsql
as $$
declare
  m_enabled boolean;
  m_auto boolean;
begin
  -- Only enforce for unauthenticated (anon) inserts.
  if auth.uid() is null then
    select
      coalesce(s.moderation_enabled, false),
      coalesce(s.auto_approve_uploads, true)
    into m_enabled, m_auto
    from public.album_settings s
    where s.album_id = new.album_id
    limit 1;

    if m_enabled and not m_auto then
      new.status := 'pending';
    else
      new.status := 'approved';
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
as $$
declare
  m_enabled boolean;
  m_auto boolean;
begin
  if auth.uid() is null then
    select
      coalesce(s.moderation_enabled, false),
      coalesce(s.auto_approve_notes, true)
    into m_enabled, m_auto
    from public.album_settings s
    where s.album_id = new.album_id
    limit 1;

    if m_enabled and not m_auto then
      new.status := 'pending';
    else
      new.status := 'approved';
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
