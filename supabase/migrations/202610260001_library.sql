-- Portable, owner-scoped metadata. Filesystem paths never belong in this table.
create table public.library_entities (
  user_id uuid not null references auth.users(id) on delete cascade,
  id uuid not null,
  kind text not null check (kind in ('issue', 'series', 'collection', 'progress')),
  payload jsonb not null check (jsonb_typeof(payload) = 'object' and octet_length(payload::text) <= 1048576),
  deleted boolean not null default false,
  revision bigint not null default 1 check (revision > 0),
  last_mutation_id uuid not null,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
alter table public.library_entities enable row level security;
create policy "Read own library" on public.library_entities for select to authenticated using ((select auth.uid()) = user_id);
revoke all on public.library_entities from anon, authenticated;
grant select on public.library_entities to authenticated;

-- CAS and idempotency are enforced server-side, not by client timestamps.
create function public.apply_library_mutation(
  p_id uuid, p_kind text, p_payload jsonb, p_deleted boolean,
  p_base_revision bigint, p_mutation_id uuid
) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  owner_id uuid := auth.uid();
  current_entity public.library_entities;
begin
  if owner_id is null then raise exception 'Authentication required' using errcode = '42501'; end if;
  if p_base_revision < 0 or p_kind not in ('issue', 'series', 'collection', 'progress') or jsonb_typeof(p_payload) <> 'object' then
    raise exception 'Invalid mutation' using errcode = '22023';
  end if;
  perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(owner_id::text || p_id::text, 0));
  select * into current_entity from public.library_entities where user_id = owner_id and id = p_id for update;
  if found then
    if current_entity.last_mutation_id = p_mutation_id then
      return jsonb_build_object('conflict', false, 'entity', to_jsonb(current_entity));
    end if;
    if current_entity.revision <> p_base_revision or current_entity.kind <> p_kind then
      return jsonb_build_object('conflict', true, 'entity', to_jsonb(current_entity));
    end if;
    update public.library_entities set payload = p_payload, deleted = p_deleted,
      revision = revision + 1, last_mutation_id = p_mutation_id, updated_at = now()
      where user_id = owner_id and id = p_id returning * into current_entity;
  else
    if p_base_revision <> 0 then raise exception 'Unknown entity revision' using errcode = '22023'; end if;
    insert into public.library_entities(user_id, id, kind, payload, deleted, last_mutation_id)
      values(owner_id, p_id, p_kind, p_payload, p_deleted, p_mutation_id) returning * into current_entity;
  end if;
  return jsonb_build_object('conflict', false, 'entity', to_jsonb(current_entity));
end;
$$;
revoke all on function public.apply_library_mutation(uuid, text, jsonb, boolean, bigint, uuid) from public, anon;
grant execute on function public.apply_library_mutation(uuid, text, jsonb, boolean, bigint, uuid) to authenticated;

insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('library-covers', 'library-covers', false, 20971520, array['image/jpeg','image/png','image/webp'])
on conflict (id) do nothing;
create policy "Read own covers" on storage.objects for select to authenticated using (bucket_id = 'library-covers' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Upload own covers" on storage.objects for insert to authenticated with check (bucket_id = 'library-covers' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Update own covers" on storage.objects for update to authenticated using (bucket_id = 'library-covers' and (storage.foldername(name))[1] = (select auth.uid())::text) with check (bucket_id = 'library-covers' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Delete own covers" on storage.objects for delete to authenticated using (bucket_id = 'library-covers' and (storage.foldername(name))[1] = (select auth.uid())::text);
