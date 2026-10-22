-- Checks the sync functions the way the app calls them: as the anon role.
-- Run after stubs.sql and schema.sql. Any failed check raises and stops.
\set ON_ERROR_STOP 1
set role anon;

-- Tables are closed to the public API.
do $$ begin
  begin
    perform 1 from public.records;
    raise exception 'anon could read records';
  exception when insufficient_privilege then null;
  end;
end $$;

-- Two devices, each in a space of its own.
create temp table t_ids (k text primary key, v jsonb);
insert into t_ids values
  ('laptop', public.register_device('laptop-secret-0123456789abcdef0123456789', 'Laptop', 'laptop')),
  ('phone', public.register_device('phone-secret-0123456789abcdef01234567890', 'Pixel', 'phone'));

do $$ begin
  if (select v->>'space_id' from t_ids where k = 'laptop') = (select v->>'space_id' from t_ids where k = 'phone') then
    raise exception 'new devices share a space';
  end if;
  -- Registering again keeps the same device and space.
  if public.register_device('laptop-secret-0123456789abcdef0123456789', 'Laptop 2', 'laptop')->>'space_id'
     <> (select v->>'space_id' from t_ids where k = 'laptop') then
    raise exception 're-register moved the device';
  end if;
  begin
    perform public.register_device('short', 'x', 'phone');
    raise exception 'short secret accepted';
  exception when sqlstate 'SR400' then null;
  end;
  begin
    perform public.push_records('nobody-0123456789abcdef0123456789abcdef', '[]');
    raise exception 'unknown device accepted';
  exception when sqlstate 'SR401' then null;
  end;
end $$;

-- The phone has a record before pairing, in its own space.
do $$ begin
  if public.push_records('phone-secret-0123456789abcdef01234567890', '[
    {"kind":"subject","id":"s1","fields":{"name":"Maths","color":1},
     "clock":{"name":"000000000000100-0000-p","color":"000000000000100-0000-p"}}
  ]') <> 1 then raise exception 'first push did not insert'; end if;
end $$;

-- Pairing: a wrong code counts as a try, the right code joins once.
create temp table t_code as
  select public.create_pairing_code('laptop-secret-0123456789abcdef0123456789') as v;
do $$
declare
  code text := (select v->>'code' from t_code);
  res jsonb;
begin
  if code !~ '^[A-HJKMNP-Z2-9]{8}$' then raise exception 'odd code %', code; end if;
  res := public.join_space('phone-secret-0123456789abcdef01234567890', 'WRONG000');
  if res->>'error' <> 'SR404' then raise exception 'wrong code joined: %', res; end if;
  -- Dashes, spaces and lower case are fine.
  res := public.join_space('phone-secret-0123456789abcdef01234567890',
    lower(substr(code, 1, 4)) || '-' || substr(code, 5));
  if res->>'space_id' <> (select v->>'space_id' from t_ids where k = 'laptop') then
    raise exception 'join went to %', res;
  end if;
  res := public.join_space('phone-secret-0123456789abcdef01234567890', code);
  if res->>'error' <> 'SR404' then raise exception 'code worked twice'; end if;
  if (select count(*) from public.list_devices('laptop-secret-0123456789abcdef0123456789')) <> 2 then
    raise exception 'laptop does not see the phone';
  end if;
end $$;

-- Too many wrong tries are refused.
do $$ begin
  for i in 1..12 loop
    begin
      perform public.join_space('phone-secret-0123456789abcdef01234567890', 'ZZZZZZZZ');
    exception when sqlstate 'SR429' then
      if i < 10 then raise exception 'locked out after % tries', i; end if;
      return;
    end;
  end loop;
  raise exception 'never locked out';
end $$;

-- Per-field merge: each device edits a different field offline.
do $$
declare
  rows jsonb;
begin
  perform public.push_records('laptop-secret-0123456789abcdef0123456789', '[
    {"kind":"reminder","id":"r1","fields":{"title":"Physics","minute":600},
     "clock":{"title":"000000000000200-0000-l","minute":"000000000000200-0000-l"}}]');
  perform public.push_records('laptop-secret-0123456789abcdef0123456789', '[
    {"kind":"reminder","id":"r1","fields":{"title":"Physics revision","minute":600},
     "clock":{"title":"000000000000300-0000-l","minute":"000000000000200-0000-l"}}]');
  -- The phone changed the time later, and still has the old title.
  perform public.push_records('phone-secret-0123456789abcdef01234567890', '[
    {"kind":"reminder","id":"r1","fields":{"title":"Physics","minute":540},
     "clock":{"title":"000000000000200-0000-l","minute":"000000000000250-0000-p"}}]');
  -- A stale echo changes nothing.
  if public.push_records('phone-secret-0123456789abcdef01234567890', '[
    {"kind":"reminder","id":"r1","fields":{"title":"Physics","minute":540},
     "clock":{"title":"000000000000200-0000-l","minute":"000000000000250-0000-p"}}]') <> 0 then
    raise exception 'echo counted as a change';
  end if;

  select jsonb_agg(to_jsonb(p) order by p.seq) into rows
  from public.pull_records('phone-secret-0123456789abcdef01234567890', 0) p
  where p.kind = 'reminder';
  if jsonb_array_length(rows) <> 1 then raise exception 'pulled %', rows; end if;
  if rows->0->'fields' <> '{"title":"Physics revision","minute":540}'::jsonb then
    raise exception 'merge lost an edit: %', rows->0->'fields';
  end if;
end $$;

-- Pull pages by sequence number. The phone's subject from before pairing
-- went with its old space; the app pushes it again after joining.
do $$
declare
  first_page bigint;
  n int;
begin
  perform public.push_records('phone-secret-0123456789abcdef01234567890', '[
    {"kind":"subject","id":"s1","fields":{"name":"Maths","color":1},
     "clock":{"name":"000000000000100-0000-p","color":"000000000000100-0000-p"}}]');
  select max(seq) into first_page
  from public.pull_records('laptop-secret-0123456789abcdef0123456789', 0, 1);
  select count(*) into n
  from public.pull_records('laptop-secret-0123456789abcdef0123456789', first_page);
  if n <> 1 then raise exception 'second page has % rows', n; end if;
  if (select count(*) from public.pull_records('laptop-secret-0123456789abcdef0123456789', 0)) <> 2 then
    raise exception 'space should hold r1 and s1';
  end if;
end $$;

-- Leaving takes the phone to a fresh, empty space.
do $$
declare
  res jsonb := public.leave_space('phone-secret-0123456789abcdef01234567890');
begin
  if exists (select 1 from public.pull_records('phone-secret-0123456789abcdef01234567890', 0)) then
    raise exception 'new space is not empty';
  end if;
  if (select count(*) from public.list_devices('laptop-secret-0123456789abcdef0123456789')) <> 1 then
    raise exception 'laptop still lists the phone';
  end if;
end $$;

reset role;
do $$ begin
  if (select count(*) from public.spaces) <> 2 then
    raise exception 'empty spaces were not removed: %', (select count(*) from public.spaces);
  end if;
  if not exists (select 1 from realtime.sent where event = 'changed' and not private) then
    raise exception 'no change ping sent';
  end if;
end $$;
select 'schema tests passed' as result;
