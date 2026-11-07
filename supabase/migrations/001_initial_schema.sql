-- TULAI initial Supabase schema. Execute once in a new Supabase project.
begin;
create extension if not exists pgcrypto;
create type public.resource_origin as enum ('official_source','platform','community','ai_generated');
create type public.review_status as enum ('unreviewed','pending','verified','rejected','unlisted');
create type public.proficiency_level as enum ('Beginner','Developing','Intermediate','Proficient');
create type public.sync_operation_status as enum ('pending','synced','failed');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  preferred_interface_language text not null default 'en' check (preferred_interface_language in ('en','fil','ilo')),
  preferred_content_language text not null default 'en' check (preferred_content_language in ('en','fil','ilo')),
  created_at timestamptz not null default now(), updated_at timestamptz not null default now()
);
create function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,display_name) values(new.id, coalesce(new.raw_user_meta_data->>'display_name','')) on conflict(id) do nothing; return new; end; $$;
create trigger on_auth_user_created after insert on auth.users for each row execute procedure public.handle_new_user();
create function public.set_updated_at() returns trigger language plpgsql as $$ begin new.updated_at=now(); return new; end; $$;
create trigger profiles_updated_at before update on public.profiles for each row execute procedure public.set_updated_at();

create table public.resources (
 id uuid primary key default gen_random_uuid(), slug text unique not null, title text not null, description text not null default '', author_organization text not null,
 subject text not null, topic text not null, language text not null check(language in ('en','fil','ilo')), difficulty public.proficiency_level not null,
 resource_type text not null default 'lesson', origin public.resource_origin not null, original_source_url text, license_name text not null,
 redistribution_allowed boolean not null default false, publication_date date, review_status public.review_status not null default 'unreviewed',
 external_url text, is_published boolean not null default false, created_by uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check (redistribution_allowed = false or license_name <> '')
);
create index resources_catalogue_idx on public.resources(is_published,subject,language,difficulty);
create index resources_search_idx on public.resources using gin(to_tsvector('simple',coalesce(title,'')||' '||coalesce(description,'')||' '||coalesce(topic,'')));
create trigger resources_updated_at before update on public.resources for each row execute procedure public.set_updated_at();
create table public.resource_files (
 id uuid primary key default gen_random_uuid(), resource_id uuid not null references public.resources(id) on delete cascade,
 storage_path text, external_url text, file_format text not null default 'markdown', file_size_bytes bigint,
 is_primary boolean not null default false, created_at timestamptz not null default now(), check(storage_path is not null or external_url is not null)
);
create index resource_files_resource_idx on public.resource_files(resource_id);
create table public.resource_translations (
 id uuid primary key default gen_random_uuid(), resource_id uuid not null references public.resources(id) on delete cascade,
 source_language text not null check(source_language in ('en','fil','ilo')), target_language text not null check(target_language in ('en','fil','ilo')),
 title text not null, content_markdown text not null, translation_method text not null check(translation_method in ('human','machine')),
 review_status public.review_status not null default 'unreviewed', reviewer_id uuid references auth.users(id) on delete set null,
 created_at timestamptz not null default now(), unique(resource_id,target_language), check(source_language<>target_language),
 check (translation_method <> 'machine' or review_status <> 'verified' or reviewer_id is not null)
);

create table public.assessments (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 subject text not null check(subject in ('Mathematics','English')), score smallint not null check(score between 0 and 100),
 level public.proficiency_level not null, answers jsonb not null default '[]'::jsonb, completed_at timestamptz not null default now(), client_operation_id uuid not null,
 unique(user_id,client_operation_id)
);
create index assessments_user_date_idx on public.assessments(user_id,completed_at desc);
create table public.assessment_answers (
 id uuid primary key default gen_random_uuid(), assessment_id uuid not null references public.assessments(id) on delete cascade,
 question_key text not null, selected_option integer, is_correct boolean not null, unique(assessment_id,question_key)
);
create table public.user_library (
 user_id uuid not null references auth.users(id) on delete cascade, resource_id uuid not null references public.resources(id) on delete cascade,
 added_at timestamptz not null default now(), primary key(user_id,resource_id)
);
create table public.learning_progress (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 resource_id uuid references public.resources(id) on delete cascade, local_resource_id text,
 last_position integer not null default 0 check(last_position>=0), percent_complete numeric(5,2) not null default 0 check(percent_complete between 0 and 100),
 updated_at timestamptz not null default now(), client_operation_id uuid not null,
 unique(user_id,resource_id), unique(user_id,local_resource_id), unique(user_id,client_operation_id),
 check ((resource_id is not null) <> (local_resource_id is not null))
);
create table public.learning_activities (
 id uuid primary key default gen_random_uuid(), user_id uuid not null references auth.users(id) on delete cascade,
 resource_id uuid references public.resources(id) on delete set null, activity_type text not null, payload jsonb not null default '{}'::jsonb,
 occurred_at timestamptz not null default now(), client_operation_id uuid not null, unique(user_id,client_operation_id)
);
create index learning_activities_user_date_idx on public.learning_activities(user_id,occurred_at desc);
create table public.quizzes (
 id uuid primary key default gen_random_uuid(), resource_id uuid references public.resources(id) on delete cascade,
 title text not null, subject text not null, language text not null check(language in ('en','fil','ilo')), is_published boolean not null default false
);
create table public.quiz_questions (
 id uuid primary key default gen_random_uuid(), quiz_id uuid not null references public.quizzes(id) on delete cascade,
 question_text text not null, options jsonb not null, correct_option integer not null, explanation text, sort_order integer not null default 0,
 check(jsonb_typeof(options)='array')
);
create table public.quiz_attempts (
 id uuid primary key default gen_random_uuid(), quiz_id uuid not null references public.quizzes(id) on delete cascade,
 user_id uuid not null references auth.users(id) on delete cascade, score numeric(5,2) not null check(score between 0 and 100),
 answers jsonb not null default '[]'::jsonb, completed_at timestamptz not null default now(), client_operation_id uuid not null, unique(user_id,client_operation_id)
);
create table public.achievements (
 id uuid primary key default gen_random_uuid(), code text unique not null, title text not null, description text not null, threshold jsonb not null default '{}'::jsonb
);
create table public.user_achievements (
 user_id uuid not null references auth.users(id) on delete cascade, achievement_id uuid not null references public.achievements(id) on delete cascade,
 awarded_at timestamptz not null default now(), primary key(user_id,achievement_id)
);
-- Future contribution workflow tables; no public submission or moderation UI is enabled in the MVP.
create table public.contributions (
 id uuid primary key default gen_random_uuid(), contributor_id uuid not null references auth.users(id) on delete cascade,
 title text not null, description text not null default '', source_url text not null, license_name text not null,
 storage_path text, status text not null default 'Pending' check(status in ('Pending','Approved','Rejected','Unlisted')),
 reviewer_id uuid references auth.users(id) on delete set null, review_note text, created_at timestamptz not null default now(), reviewed_at timestamptz,
 check(reviewer_id is null or reviewer_id<>contributor_id)
);
create table public.moderation_logs (
 id uuid primary key default gen_random_uuid(), contribution_id uuid not null references public.contributions(id) on delete cascade,
 moderator_id uuid not null references auth.users(id) on delete restrict, action text not null check(action in ('Approved','Rejected','Unlisted','Pending')),
 note text, created_at timestamptz not null default now()
);
create table public.sync_operations (
 operation_id uuid primary key, user_id uuid not null references auth.users(id) on delete cascade,
 resource_id uuid references public.resources(id) on delete set null, operation_type text not null,
 occurred_at timestamptz not null, payload jsonb not null default '{}'::jsonb,
 status public.sync_operation_status not null default 'pending', last_error text, received_at timestamptz not null default now()
);
create index sync_operations_user_status_idx on public.sync_operations(user_id,status);

-- Idempotent sync endpoint: only the authenticated owner can write; duplicate operation IDs are ignored.
create or replace function public.record_sync_operation(p_operation_id uuid,p_resource_id uuid,p_operation_type text,p_occurred_at timestamptz,p_payload jsonb)
returns void language plpgsql security invoker set search_path=public as $$
begin
 if auth.uid() is null then raise exception 'Authentication required'; end if;
 insert into public.sync_operations(operation_id,user_id,resource_id,operation_type,occurred_at,payload,status)
 values(p_operation_id,auth.uid(),p_resource_id,p_operation_type,p_occurred_at,p_payload,'synced') on conflict(operation_id) do nothing;
end; $$;

-- RLS
alter table public.profiles enable row level security;
alter table public.resources enable row level security;
alter table public.resource_files enable row level security;
alter table public.resource_translations enable row level security;
alter table public.assessments enable row level security;
alter table public.assessment_answers enable row level security;
alter table public.user_library enable row level security;
alter table public.learning_progress enable row level security;
alter table public.learning_activities enable row level security;
alter table public.quizzes enable row level security;
alter table public.quiz_questions enable row level security;
alter table public.quiz_attempts enable row level security;
alter table public.achievements enable row level security;
alter table public.user_achievements enable row level security;
alter table public.contributions enable row level security;
alter table public.moderation_logs enable row level security;
alter table public.sync_operations enable row level security;
create policy "profile owner read" on public.profiles for select to authenticated using(id=auth.uid());
create policy "profile owner update" on public.profiles for update to authenticated using(id=auth.uid()) with check(id=auth.uid());
create policy "published resources readable" on public.resources for select to anon,authenticated using(is_published=true);
create policy "published resource files readable" on public.resource_files for select to anon,authenticated using(exists(select 1 from public.resources r where r.id=resource_id and r.is_published=true));
create policy "reviewed translations readable" on public.resource_translations for select to anon,authenticated using(review_status='verified' and exists(select 1 from public.resources r where r.id=resource_id and r.is_published=true));
create policy "owner assessments" on public.assessments for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "owner assessment answers" on public.assessment_answers for all to authenticated using(exists(select 1 from public.assessments a where a.id=assessment_id and a.user_id=auth.uid())) with check(exists(select 1 from public.assessments a where a.id=assessment_id and a.user_id=auth.uid()));
create policy "owner library" on public.user_library for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "owner progress" on public.learning_progress for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "owner activities" on public.learning_activities for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "published quizzes readable" on public.quizzes for select to anon,authenticated using(is_published=true);
create policy "published questions readable" on public.quiz_questions for select to anon,authenticated using(exists(select 1 from public.quizzes q where q.id=quiz_id and q.is_published=true));
create policy "owner quiz attempts" on public.quiz_attempts for all to authenticated using(user_id=auth.uid()) with check(user_id=auth.uid());
create policy "achievements readable" on public.achievements for select to anon,authenticated using(true);
create policy "owner achievements readable" on public.user_achievements for select to authenticated using(user_id=auth.uid());
create policy "contributor sees own submissions" on public.contributions for select to authenticated using(contributor_id=auth.uid());
create policy "contributor submits own" on public.contributions for insert to authenticated with check(contributor_id=auth.uid() and status='Pending' and reviewer_id is null);
create policy "contributor cannot self moderate" on public.contributions for update to authenticated using(false) with check(false);
create policy "moderation logs private" on public.moderation_logs for select to authenticated using(false);
create policy "owner sync operations" on public.sync_operations for select to authenticated using(user_id=auth.uid());
create policy "owner inserts sync operations" on public.sync_operations for insert to authenticated with check(user_id=auth.uid());
create view public.quiz_question_public as
 select qq.id,qq.quiz_id,qq.question_text,qq.options,qq.explanation,qq.sort_order
 from public.quiz_questions qq join public.quizzes q on q.id=qq.quiz_id where q.is_published=true;
revoke all on public.quiz_questions from anon,authenticated;
grant select on public.resources,public.resource_files,public.resource_translations,public.quizzes,public.quiz_question_public,public.achievements to anon,authenticated;
grant select,update on public.profiles to authenticated;
grant select,insert,update,delete on public.assessments,public.assessment_answers,public.user_library,public.learning_progress,public.learning_activities,public.quiz_attempts to authenticated;
grant select,insert on public.contributions to authenticated;
grant select on public.user_achievements,public.sync_operations to authenticated;
grant execute on function public.record_sync_operation(uuid,uuid,text,timestamptz,jsonb) to authenticated;

-- Private bucket for downloadable content. Public catalogue rows should expose official URLs where redistribution is not allowed.
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('learning-materials','learning-materials',false,52428800,array['text/markdown','application/pdf','text/plain'])
on conflict(id) do nothing;
-- Only explicitly redistributable materials may be downloaded from the private bucket.
create policy "public redistributable learning files" on storage.objects for select to anon,authenticated
using(bucket_id='learning-materials' and exists(
  select 1 from public.resource_files f join public.resources r on r.id=f.resource_id
  where f.storage_path=name and r.is_published=true and r.redistribution_allowed=true
));

commit;
