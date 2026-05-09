-- Album deletion support (owner-only) + cascade FK cleanup.
-- Safe to re-run.

do $$
begin
  -- Ensure album-related foreign keys cascade when an album is deleted.
  -- (Some environments may already have these, hence IF EXISTS / re-create.)

  -- album_access_tokens.album_id -> albums.id
  execute 'alter table public.album_access_tokens drop constraint if exists album_access_tokens_album_id_fkey';
  execute 'alter table public.album_access_tokens add constraint album_access_tokens_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- album_settings.album_id -> albums.id
  execute 'alter table public.album_settings drop constraint if exists album_settings_album_id_fkey';
  execute 'alter table public.album_settings add constraint album_settings_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- download_exports.album_id -> albums.id
  execute 'alter table public.download_exports drop constraint if exists download_exports_album_id_fkey';
  execute 'alter table public.download_exports add constraint download_exports_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- guests.album_id -> albums.id
  execute 'alter table public.guests drop constraint if exists guests_album_id_fkey';
  execute 'alter table public.guests add constraint guests_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- media_uploads.album_id -> albums.id
  execute 'alter table public.media_uploads drop constraint if exists media_uploads_album_id_fkey';
  execute 'alter table public.media_uploads add constraint media_uploads_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- notes.album_id -> albums.id
  execute 'alter table public.notes drop constraint if exists notes_album_id_fkey';
  execute 'alter table public.notes add constraint notes_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- payments.album_id -> albums.id
  execute 'alter table public.payments drop constraint if exists payments_album_id_fkey';
  execute 'alter table public.payments add constraint payments_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- qr_codes.album_id -> albums.id
  execute 'alter table public.qr_codes drop constraint if exists qr_codes_album_id_fkey';
  execute 'alter table public.qr_codes add constraint qr_codes_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- qr_scans.album_id -> albums.id
  execute 'alter table public.qr_scans drop constraint if exists qr_scans_album_id_fkey';
  execute 'alter table public.qr_scans add constraint qr_scans_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- slideshow_settings.album_id -> albums.id
  execute 'alter table public.slideshow_settings drop constraint if exists slideshow_settings_album_id_fkey';
  execute 'alter table public.slideshow_settings add constraint slideshow_settings_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- activity_logs.album_id -> albums.id
  execute 'alter table public.activity_logs drop constraint if exists activity_logs_album_id_fkey';
  execute 'alter table public.activity_logs add constraint activity_logs_album_id_fkey foreign key (album_id) references public.albums(id) on delete cascade';

  -- Cascades for guest-linked tables when guests are deleted (because album is deleted).
  execute 'alter table public.media_uploads drop constraint if exists media_uploads_guest_id_fkey';
  execute 'alter table public.media_uploads add constraint media_uploads_guest_id_fkey foreign key (guest_id) references public.guests(id) on delete cascade';

  execute 'alter table public.notes drop constraint if exists notes_guest_id_fkey';
  execute 'alter table public.notes add constraint notes_guest_id_fkey foreign key (guest_id) references public.guests(id) on delete cascade';

  execute 'alter table public.activity_logs drop constraint if exists activity_logs_guest_id_fkey';
  execute 'alter table public.activity_logs add constraint activity_logs_guest_id_fkey foreign key (guest_id) references public.guests(id) on delete cascade';
end $$;

create or replace function public.delete_album(album_uuid uuid)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public, pg_temp
as $$
begin
  if album_uuid is null then
    raise exception 'album_id is required';
  end if;

  if public.is_album_owner(album_uuid) is not true then
    raise exception 'Not authorized';
  end if;

  delete from public.albums a where a.id = album_uuid;
end;
$$;

revoke all on function public.delete_album(uuid) from public;
grant execute on function public.delete_album(uuid) to authenticated, service_role;

