-- Enforce passcode access for code-protected albums at the database layer.
-- This replaces the "public_*" guest policies to ensure:
--   - code_protected albums require `public.has_album_access(album_id)`
--   - album_settings.allow_guest_view_gallery is respected for public gallery reads
--   - album_settings allow_* flags are respected for guest inserts (media + notes)
--   - album owners can fully moderate/approve/reject (select/update/delete)
--
-- Safe to re-run.

do $$
begin
  -- guests
  if exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'guests'
  ) then
    execute 'alter table public.guests enable row level security';

    execute 'drop policy if exists public_insert_guests on public.guests';
    execute $policy$
      create policy public_insert_guests
      on public.guests
      for insert
      to anon, authenticated
      with check (
        exists (
          select 1
          from public.albums a
          where a.id = album_id
            and (a.status is null or a.status = 'active')
            and (a.upload_enabled is null or a.upload_enabled = true)
            and (a.visibility is null or a.visibility in ('public', 'code_protected'))
            and public.has_album_access(a.id)
        )
      )
    $policy$;
  end if;

  -- media_uploads
  if exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'media_uploads'
  ) then
    execute 'alter table public.media_uploads enable row level security';

    -- Guest inserts
    execute 'drop policy if exists public_insert_media_uploads on public.media_uploads';
    execute $policy$
      create policy public_insert_media_uploads
      on public.media_uploads
      for insert
      to anon, authenticated
      with check (
        exists (
          select 1
          from public.albums a
          left join public.album_settings s on s.album_id = a.id
          where a.id = album_id
            and (a.status is null or a.status = 'active')
            and (a.upload_enabled is null or a.upload_enabled = true)
            and (a.visibility is null or a.visibility in ('public', 'code_protected'))
            and public.has_album_access(a.id)
            and (
              (type = 'photo' and coalesce(s.allow_photos, true)) or
              (type = 'video' and coalesce(s.allow_videos, true)) or
              (type = 'audio' and coalesce(s.allow_audio, true))
            )
        )
        and exists (
          select 1
          from public.guests g
          where g.id = guest_id and g.album_id = album_id
        )
      )
    $policy$;

    -- Public selects (gallery)
    execute 'drop policy if exists public_select_media_uploads on public.media_uploads';
    execute $policy$
      create policy public_select_media_uploads
      on public.media_uploads
      for select
      to anon, authenticated
      using (
        (status is null or status = 'approved')
        and (is_hidden is null or is_hidden = false)
        and (deleted_at is null)
        and exists (
          select 1
          from public.albums a
          left join public.album_settings s on s.album_id = a.id
          where a.id = album_id
            and (a.status is null or a.status = 'active')
            and (a.gallery_enabled is null or a.gallery_enabled = true)
            and (a.visibility is null or a.visibility in ('public', 'code_protected'))
            and coalesce(s.allow_guest_view_gallery, true)
            and public.has_album_access(a.id)
        )
      )
    $policy$;

    -- Owner moderation
    execute 'drop policy if exists owner_select_media_uploads on public.media_uploads';
    execute $policy$
      create policy owner_select_media_uploads
      on public.media_uploads
      for select
      to authenticated
      using (public.is_album_owner(album_id))
    $policy$;

    execute 'drop policy if exists owner_update_media_uploads on public.media_uploads';
    execute $policy$
      create policy owner_update_media_uploads
      on public.media_uploads
      for update
      to authenticated
      using (public.is_album_owner(album_id))
      with check (public.is_album_owner(album_id))
    $policy$;

    execute 'drop policy if exists owner_delete_media_uploads on public.media_uploads';
    execute $policy$
      create policy owner_delete_media_uploads
      on public.media_uploads
      for delete
      to authenticated
      using (public.is_album_owner(album_id))
    $policy$;
  end if;

  -- notes
  if exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'notes'
  ) then
    execute 'alter table public.notes enable row level security';

    -- Guest inserts
    execute 'drop policy if exists public_insert_notes on public.notes';
    execute $policy$
      create policy public_insert_notes
      on public.notes
      for insert
      to anon, authenticated
      with check (
        exists (
          select 1
          from public.albums a
          left join public.album_settings s on s.album_id = a.id
          where a.id = album_id
            and (a.status is null or a.status = 'active')
            and (a.upload_enabled is null or a.upload_enabled = true)
            and (a.visibility is null or a.visibility in ('public', 'code_protected'))
            and public.has_album_access(a.id)
            and coalesce(s.allow_notes, true)
        )
        and exists (
          select 1
          from public.guests g
          where g.id = guest_id and g.album_id = album_id
        )
      )
    $policy$;

    -- Public selects (gallery)
    execute 'drop policy if exists public_select_notes on public.notes';
    execute $policy$
      create policy public_select_notes
      on public.notes
      for select
      to anon, authenticated
      using (
        (status is null or status = 'approved')
        and (is_hidden is null or is_hidden = false)
        and (deleted_at is null)
        and exists (
          select 1
          from public.albums a
          left join public.album_settings s on s.album_id = a.id
          where a.id = album_id
            and (a.status is null or a.status = 'active')
            and (a.gallery_enabled is null or a.gallery_enabled = true)
            and (a.visibility is null or a.visibility in ('public', 'code_protected'))
            and coalesce(s.allow_guest_view_gallery, true)
            and public.has_album_access(a.id)
        )
      )
    $policy$;

    -- Owner moderation
    execute 'drop policy if exists owner_select_notes on public.notes';
    execute $policy$
      create policy owner_select_notes
      on public.notes
      for select
      to authenticated
      using (public.is_album_owner(album_id))
    $policy$;

    execute 'drop policy if exists owner_update_notes on public.notes';
    execute $policy$
      create policy owner_update_notes
      on public.notes
      for update
      to authenticated
      using (public.is_album_owner(album_id))
      with check (public.is_album_owner(album_id))
    $policy$;

    execute 'drop policy if exists owner_delete_notes on public.notes';
    execute $policy$
      create policy owner_delete_notes
      on public.notes
      for delete
      to authenticated
      using (public.is_album_owner(album_id))
    $policy$;
  end if;
end $$;

