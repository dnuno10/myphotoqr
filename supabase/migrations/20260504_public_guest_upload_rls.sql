-- Allow unauthenticated guests (anon) to upload to public albums.
-- This fixes mobile/web uploads failing with RLS violations on `guests`.

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

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'guests'
        and policyname = 'public_insert_guests'
    ) then
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
          )
        )
      $policy$;
    end if;
  end if;

  -- media_uploads
  if exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'media_uploads'
  ) then
    execute 'alter table public.media_uploads enable row level security';

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'media_uploads'
        and policyname = 'public_insert_media_uploads'
    ) then
      execute $policy$
        create policy public_insert_media_uploads
        on public.media_uploads
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
          )
          and exists (
            select 1
            from public.guests g
            where g.id = guest_id and g.album_id = album_id
          )
        )
      $policy$;
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'media_uploads'
        and policyname = 'public_select_media_uploads'
    ) then
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
            where a.id = album_id
              and (a.status is null or a.status = 'active')
              and (a.visibility is null or a.visibility in ('public', 'code_protected'))
          )
        )
      $policy$;
    end if;
  end if;

  -- notes
  if exists (
    select 1
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public' and c.relname = 'notes'
  ) then
    execute 'alter table public.notes enable row level security';

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'notes'
        and policyname = 'public_insert_notes'
    ) then
      execute $policy$
        create policy public_insert_notes
        on public.notes
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
          )
          and exists (
            select 1
            from public.guests g
            where g.id = guest_id and g.album_id = album_id
          )
        )
      $policy$;
    end if;

    if not exists (
      select 1 from pg_policies
      where schemaname = 'public'
        and tablename = 'notes'
        and policyname = 'public_select_notes'
    ) then
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
            where a.id = album_id
              and (a.status is null or a.status = 'active')
              and (a.visibility is null or a.visibility in ('public', 'code_protected'))
          )
        )
      $policy$;
    end if;
  end if;
end $$;

