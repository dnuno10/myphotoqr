-- Keep album counters accurate (photos/videos/audios/notes/uploads) via triggers.
-- This fixes stale totals in dashboards/overview without requiring manual refresh.
--
-- Semantics:
--   - `total_uploads` counts approved, visible (not hidden), not deleted media items
--     across photo/video/audio.
--   - `total_photos|total_videos|total_audios` are the corresponding breakdown.
--   - `total_notes` counts approved, visible, not deleted notes.
--
-- Safe to re-run.

create or replace function public.recalculate_album_counters(album_uuid uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  p integer;
  v integer;
  a integer;
  u integer;
  n integer;
begin
  select
    count(*) filter (where m.type = 'photo'),
    count(*) filter (where m.type = 'video'),
    count(*) filter (where m.type = 'audio'),
    count(*)
  into p, v, a, u
  from public.media_uploads m
  where m.album_id = album_uuid
    and (m.status is null or m.status = 'approved')
    and (m.is_hidden is null or m.is_hidden = false)
    and (m.deleted_at is null)
    and m.type in ('photo', 'video', 'audio');

  select count(*)
  into n
  from public.notes t
  where t.album_id = album_uuid
    and (t.status is null or t.status = 'approved')
    and (t.is_hidden is null or t.is_hidden = false)
    and (t.deleted_at is null);

  update public.albums
  set
    total_photos = coalesce(p, 0),
    total_videos = coalesce(v, 0),
    total_audios = coalesce(a, 0),
    total_uploads = coalesce(u, 0),
    total_notes = coalesce(n, 0),
    updated_at = now()
  where id = album_uuid;
end;
$$;

create or replace function public.trg_album_counters_from_media()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  old_album uuid;
  new_album uuid;
begin
  old_album := case when tg_op in ('UPDATE', 'DELETE') then old.album_id else null end;
  new_album := case when tg_op in ('UPDATE', 'INSERT') then new.album_id else null end;

  if old_album is not null then
    perform public.recalculate_album_counters(old_album);
  end if;

  if new_album is not null and new_album is distinct from old_album then
    perform public.recalculate_album_counters(new_album);
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists trg_album_counters_media on public.media_uploads;
create trigger trg_album_counters_media
after insert or update or delete on public.media_uploads
for each row
execute function public.trg_album_counters_from_media();

create or replace function public.trg_album_counters_from_notes()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
declare
  old_album uuid;
  new_album uuid;
begin
  old_album := case when tg_op in ('UPDATE', 'DELETE') then old.album_id else null end;
  new_album := case when tg_op in ('UPDATE', 'INSERT') then new.album_id else null end;

  if old_album is not null then
    perform public.recalculate_album_counters(old_album);
  end if;

  if new_album is not null and new_album is distinct from old_album then
    perform public.recalculate_album_counters(new_album);
  end if;

  return case when tg_op = 'DELETE' then old else new end;
end;
$$;

drop trigger if exists trg_album_counters_notes on public.notes;
create trigger trg_album_counters_notes
after insert or update or delete on public.notes
for each row
execute function public.trg_album_counters_from_notes();

-- Backfill existing rows.
do $$
declare
  r record;
begin
  for r in (select id from public.albums) loop
    perform public.recalculate_album_counters(r.id);
  end loop;
end $$;

