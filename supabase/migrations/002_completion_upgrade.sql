-- Upgrade path for projects that already ran the earlier TULAI initial schema.
-- Do NOT run this after the revised 001_initial_schema.sql; it is an alternative path.
begin;

alter table public.learning_progress drop constraint if exists learning_progress_pkey;
alter table public.learning_progress add column if not exists id uuid default gen_random_uuid();
update public.learning_progress set id = gen_random_uuid() where id is null;
alter table public.learning_progress alter column id set not null;
alter table public.learning_progress alter column resource_id drop not null;
alter table public.learning_progress add column if not exists local_resource_id text;
alter table public.learning_progress add constraint learning_progress_pkey primary key (id);
alter table public.learning_progress add constraint learning_progress_user_resource_key unique (user_id, resource_id);
alter table public.learning_progress add constraint learning_progress_user_local_resource_key unique (user_id, local_resource_id);
alter table public.learning_progress add constraint learning_progress_resource_key_check
  check ((resource_id is not null) <> (local_resource_id is not null));

-- Replace the previous policy, which allowed authenticated downloads regardless of license.
drop policy if exists "authenticated users read published resource files" on storage.objects;
drop policy if exists "public redistributable learning files" on storage.objects;
create policy "public redistributable learning files" on storage.objects for select to anon, authenticated
using (
  bucket_id = 'learning-materials'
  and exists (
    select 1
    from public.resource_files f
    join public.resources r on r.id = f.resource_id
    where f.storage_path = name
      and r.is_published = true
      and r.redistribution_allowed = true
  )
);

commit;
