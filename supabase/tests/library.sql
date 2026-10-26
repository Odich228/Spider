begin;
insert into auth.users values ('11111111-1111-4111-8111-111111111111'), ('22222222-2222-4222-8222-222222222222');
set local role authenticated;
select set_config('request.jwt.claim.sub', '11111111-1111-4111-8111-111111111111', true);
do $$
declare response jsonb;
begin
  response := public.apply_library_mutation('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'series', '{"title":"My series"}', false, 0, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  if (response->'entity'->>'revision')::int <> 1 or (response->>'conflict')::boolean then raise exception 'initial mutation failed'; end if;
  response := public.apply_library_mutation('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'series', '{"title":"My series"}', false, 0, 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  if (response->'entity'->>'revision')::int <> 1 then raise exception 'replay was not idempotent'; end if;
  response := public.apply_library_mutation('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'series', '{"title":"stale"}', false, 0, 'cccccccc-cccc-4ccc-8ccc-cccccccccccc');
  if not (response->>'conflict')::boolean then raise exception 'stale update was accepted'; end if;
  response := public.apply_library_mutation('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'series', '{"title":"updated"}', false, 1, 'dddddddd-dddd-4ddd-8ddd-dddddddddddd');
  if (response->'entity'->>'revision')::int <> 2 then raise exception 'version did not advance'; end if;
  response := public.apply_library_mutation('12345678-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'readingList', '{"title":"Route","readingOrder":[],"completed":[]}', false, 0, '12345678-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  if response->'entity'->>'kind' <> 'readingList' then raise exception 'reading lists rejected'; end if;
  perform public.apply_library_mutation('12345679-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'settings', '{"theme":"symbiote"}', false, 0, '12345679-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
  perform public.apply_library_mutation('12345670-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'bookmarks', '{"pages":[1,3]}', false, 0, '12345670-bbbb-4bbb-8bbb-bbbbbbbbbbbb');
end $$;
select set_config('request.jwt.claim.sub', '22222222-2222-4222-8222-222222222222', true);
do $$ begin
  if exists(select 1 from public.library_entities) then raise exception 'cross-user read'; end if;
  perform public.apply_library_mutation('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'series', '{"title":"other owner"}', false, 0, 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee');
  if (select count(*) from public.library_entities) <> 1 then raise exception 'owner isolation failed'; end if;
  begin
    update public.library_entities set revision = 999;
    raise exception 'direct write bypassed CAS';
  exception when insufficient_privilege then null;
  end;
  begin
    insert into storage.objects values ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', 'library-covers', '11111111-1111-4111-8111-111111111111/cover.png');
    raise exception 'cross-user storage write';
  exception when insufficient_privilege then null;
  end;
end $$;
reset role;
rollback;
