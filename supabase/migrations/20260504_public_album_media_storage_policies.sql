-- Public read access to album media bucket (cover/banner + gallery media).
-- This ensures guests can see cover & banner images and uploaded media.
--
-- NOTE:
-- `storage.objects` is owned by `supabase_storage_admin` on hosted Supabase.
-- Many projects cannot `SET ROLE supabase_storage_admin` from the SQL editor,
-- so running `CREATE POLICY` here may fail.
--
-- Recommended: set the `album-media` bucket to Public in the Dashboard:
-- Storage -> Buckets -> album-media -> Settings -> Public.
--
-- If you *can* run policies (e.g. via an owner/privileged runner), then apply:
--
  drop policy if exists public_read_album_media_bucket on storage.objects;
  create policy public_read_album_media_bucket
  on storage.objects
  for select
  to anon, authenticated
  using (bucket_id = 'album-media');
