-- Add missing enum values used by moderation triggers.
-- Safe to re-run.

do $$
begin
  if exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace where n.nspname = 'public' and t.typname = 'media_status') then
    begin
      execute 'alter type public.media_status add value if not exists ''pending''';
    exception
      when duplicate_object then
        null;
    end;
  end if;

  if exists (select 1 from pg_type t join pg_namespace n on n.oid = t.typnamespace where n.nspname = 'public' and t.typname = 'note_status') then
    begin
      execute 'alter type public.note_status add value if not exists ''pending''';
    exception
      when duplicate_object then
        null;
    end;
  end if;
end
$$;

