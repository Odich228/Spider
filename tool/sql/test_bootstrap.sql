-- Minimal Supabase API schemas for running the real migration on plain Postgres.
-- Test infrastructure only; never apply this file to Supabase.
create role anon nologin;
create role authenticated nologin;
create schema auth;
create table auth.users(id uuid primary key);
create function auth.uid() returns uuid language sql stable as
  $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
grant usage on schema auth, public to authenticated, anon;
grant execute on function auth.uid() to authenticated, anon;
create schema storage;
create table storage.buckets(id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]);
create table storage.objects(id uuid primary key, bucket_id text, name text);
alter table storage.objects enable row level security;
create function storage.foldername(name text) returns text[] language sql immutable as $$ select string_to_array(name, '/') $$;
grant usage on schema storage to authenticated;
grant select, insert, update, delete on storage.objects to authenticated;
grant execute on function storage.foldername(text) to authenticated;
