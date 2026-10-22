-- Study Reminder sync schema for Supabase (Postgres 15+).
--
-- Paste the whole file into the Supabase SQL Editor and run it. Running it
-- again is safe: it only adds what is missing and replaces the functions.
--
-- How it works
-- - Each device keeps a random secret. The server stores only its SHA-256.
--   Every call passes the secret, so there are no sign-ins or tokens to
--   refresh, and the app's background tasks can sync on their own.
-- - Devices that are paired share a space. Pairing uses a short code that
--   lasts 10 minutes and works once.
-- - Records are stored as JSON fields with a per-field clock (packed hybrid
--   logical clock strings that sort as text). A push keeps, field by field,
--   whichever value has the newer stamp, so edits made offline on two devices
--   both survive.
-- - Every change gets a sequence number. Writes to one space are serialized,
--   so a device can pull "everything after N" without missing anything.
-- - Tables are closed to the public API. The app only calls the functions
--   below, which check the device secret.

create table if not exists public.spaces (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now()
);

create table if not exists public.devices (
  id uuid primary key default gen_random_uuid(),
  secret_hash bytea not null unique,
  space_id uuid not null references public.spaces (id) on delete cascade,
  name text not null,
  kind text not null check (kind in ('phone', 'laptop')),
  joined_at timestamptz not null default now(),
  last_seen timestamptz not null default now(),
  pair_attempts int not null default 0,
  pair_window_start timestamptz not null default now()
);
create index if not exists devices_space on public.devices (space_id);
-- Added for focus mode: the phone's Firebase push token, and a limit on how
-- often a device can wake the others.
alter table public.devices add column if not exists push_token text;
alter table public.devices add column if not exists push_count int not null default 0;
alter table public.devices
  add column if not exists push_window_start timestamptz not null default now();

create table if not exists public.pairing_codes (
  code text primary key,
  space_id uuid not null references public.spaces (id) on delete cascade,
  created_by uuid not null references public.devices (id) on delete cascade,
  expires_at timestamptz not null
);

create sequence if not exists public.record_seq;

create table if not exists public.records (
  space_id uuid not null references public.spaces (id) on delete cascade,
  kind text not null check (kind in ('subject', 'reminder', 'occurrence', 'focus', 'study')),
  id text not null,
  fields jsonb not null,
  clock jsonb not null,
  hlc text collate "C" not null,
  seq bigint not null,
  updated_by uuid,
  updated_at timestamptz not null default now(),
  primary key (space_id, kind, id)
);
create index if not exists records_space_seq on public.records (space_id, seq);

-- The kinds of record, again for a table made by an older version of this
-- file. 'study': the focus sessions kept for the stats.
alter table public.records drop constraint if exists records_kind_check;
alter table public.records add constraint records_kind_check
  check (kind in ('subject', 'reminder', 'occurrence', 'focus', 'study'));

alter table public.spaces enable row level security;
alter table public.devices enable row level security;
alter table public.pairing_codes enable row level security;
alter table public.records enable row level security;
revoke all on public.spaces, public.devices, public.pairing_codes, public.records
  from anon, authenticated;
revoke all on sequence public.record_seq from anon, authenticated;

-- The device behind a secret. Raises SR401 when there is none, which tells
-- the app to register again.
create or replace function public.sr_device(p_secret text)
returns public.devices
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.devices;
begin
  select * into d
  from public.devices
  where secret_hash = sha256(convert_to(coalesce(p_secret, ''), 'UTF8'));
  if not found then
    raise exception 'unknown device' using errcode = 'SR401';
  end if;
  return d;
end;
$$;

-- Tells the other devices in a space that something changed. Only a ping:
-- they pull the changes themselves. Never fails the caller.
create or replace function public.sr_ping(p_space uuid, p_event text, p_by uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform realtime.send(
    jsonb_build_object('by', p_by),
    p_event,
    'space:' || p_space::text,
    false
  );
exception when others then
  null;
end;
$$;

-- Removes a space nobody is in any more, with its records.
create or replace function public.sr_drop_if_empty(p_space uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.spaces s
  where s.id = p_space
    and not exists (select 1 from public.devices d where d.space_id = p_space);
$$;

-- Registers this device, or updates its name. A new device starts in a
-- space of its own.
create or replace function public.register_device(
  p_secret text,
  p_name text,
  p_kind text
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  hash bytea;
  d public.devices;
  new_space uuid;
begin
  if p_secret is null or length(p_secret) < 32 then
    raise exception 'secret too short' using errcode = 'SR400';
  end if;
  hash := sha256(convert_to(p_secret, 'UTF8'));
  update public.devices
  set name = left(coalesce(nullif(trim(p_name), ''), 'Device'), 60),
      kind = p_kind,
      last_seen = now()
  where secret_hash = hash
  returning * into d;
  if not found then
    begin
      insert into public.spaces default values returning id into new_space;
      insert into public.devices (secret_hash, space_id, name, kind)
      values (hash, new_space, left(coalesce(nullif(trim(p_name), ''), 'Device'), 60), p_kind)
      returning * into d;
    exception when unique_violation then
      -- The app's background task registered the same device a moment ago.
      select * into d from public.devices where secret_hash = hash;
    end;
  end if;
  return jsonb_build_object('device_id', d.id, 'space_id', d.space_id);
end;
$$;

-- A one-time code another device can use to join this device's space.
-- Codes last 10 minutes; making a new one replaces the old one.
create or replace function public.create_pairing_code(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.devices := public.sr_device(p_secret);
  alphabet constant text := 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  bytes bytea;
  new_code text;
  expires timestamptz := now() + interval '10 minutes';
begin
  delete from public.pairing_codes
  where expires_at < now() or space_id = d.space_id;
  loop
    bytes := uuid_send(gen_random_uuid()) || uuid_send(gen_random_uuid());
    new_code := '';
    for i in 0..7 loop
      -- Bytes 0 to 5 of each uuid are fully random (6 and 8 hold fixed bits).
      new_code := new_code || substr(
        alphabet,
        get_byte(bytes, case when i < 6 then i else 10 + i end) % 31 + 1,
        1
      );
    end loop;
    begin
      insert into public.pairing_codes (code, space_id, created_by, expires_at)
      values (new_code, d.space_id, d.id, expires);
      exit;
    exception when unique_violation then
      -- Try another code.
    end;
  end loop;
  return jsonb_build_object('code', new_code, 'expires_at', expires);
end;
$$;

-- Joins the space a pairing code belongs to. The device's own records stay
-- on the device and are pushed into the new space by the app. Raises SR404
-- for a wrong or expired code and SR429 after too many wrong tries.
create or replace function public.join_space(p_secret text, p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.devices := public.sr_device(p_secret);
  wanted text := upper(regexp_replace(coalesce(p_code, ''), '[^A-Za-z0-9]', '', 'g'));
  c public.pairing_codes;
  old_space uuid := d.space_id;
begin
  if d.pair_window_start < now() - interval '10 minutes' then
    update public.devices set pair_attempts = 0, pair_window_start = now()
    where id = d.id;
    d.pair_attempts := 0;
  end if;
  if d.pair_attempts >= 10 then
    raise exception 'too many tries' using errcode = 'SR429';
  end if;

  select * into c from public.pairing_codes
  where code = wanted and expires_at > now()
  for update;
  if not found then
    update public.devices set pair_attempts = pair_attempts + 1 where id = d.id;
    -- The counter must survive the error, so report it as a result.
    return jsonb_build_object('error', 'SR404');
  end if;

  delete from public.pairing_codes where code = c.code;
  if c.space_id = old_space then
    return jsonb_build_object('space_id', old_space);
  end if;
  update public.devices
  set space_id = c.space_id, pair_attempts = 0, joined_at = now(), last_seen = now()
  where id = d.id;
  perform public.sr_drop_if_empty(old_space);
  perform public.sr_ping(c.space_id, 'devices', d.id);
  return jsonb_build_object('space_id', c.space_id);
end;
$$;

-- Unpairs this device: it moves to a new space of its own. Its records stay
-- on the device and are pushed into the new space by the app.
create or replace function public.leave_space(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.devices := public.sr_device(p_secret);
  new_space uuid;
begin
  insert into public.spaces default values returning id into new_space;
  update public.devices set space_id = new_space, joined_at = now() where id = d.id;
  perform public.sr_drop_if_empty(d.space_id);
  perform public.sr_ping(d.space_id, 'devices', d.id);
  return jsonb_build_object('space_id', new_space);
end;
$$;

-- The devices in this device's space.
create or replace function public.list_devices(p_secret text)
returns table (id uuid, name text, kind text, last_seen timestamptz, is_me boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.devices := public.sr_device(p_secret);
begin
  update public.devices set last_seen = now() where devices.id = d.id;
  return query
    select x.id, x.name, x.kind, x.last_seen, x.id = d.id
    from public.devices x
    where x.space_id = d.space_id
    order by x.joined_at;
end;
$$;

-- Merges records into the space, field by field, newest stamp wins.
-- p_records is a JSON array of {kind, id, fields, clock}. Returns how many
-- records changed on the server.
create or replace function public.push_records(p_secret text, p_records jsonb)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.devices := public.sr_device(p_secret);
  r record;
  cur public.records;
  merged_fields jsonb;
  merged_clock jsonb;
  f record;
  changed_rows int := 0;
  changed boolean;
  space_full boolean;
begin
  if jsonb_typeof(p_records) <> 'array' or jsonb_array_length(p_records) > 500 then
    raise exception 'send at most 500 records at a time' using errcode = 'SR400';
  end if;
  -- One writer per space at a time, so sequence numbers follow commit order.
  perform pg_advisory_xact_lock(hashtextextended(d.space_id::text, 0));
  space_full := (select count(*) from public.records where space_id = d.space_id) >= 50000;

  for r in
    select x.kind, x.id, x.fields, x.clock
    from jsonb_to_recordset(p_records)
      as x(kind text, id text, fields jsonb, clock jsonb)
  loop
    if jsonb_typeof(r.fields) <> 'object' or jsonb_typeof(r.clock) <> 'object' then
      raise exception 'bad record %', r.id using errcode = 'SR400';
    end if;
    -- Real records are a few hundred bytes. Oversized ones are skipped
    -- rather than refused, so one bad record cannot stop a device syncing.
    if length(r.kind) > 30 or length(r.id) not between 1 and 100
       or pg_column_size(r.fields) > 65536 or pg_column_size(r.clock) > 16384 then
      continue;
    end if;
    select * into cur from public.records
    where space_id = d.space_id and kind = r.kind and id = r.id
    for update;

    if not found then
      if space_full then
        continue;
      end if;
      insert into public.records
        (space_id, kind, id, fields, clock, hlc, seq, updated_by)
      values (
        d.space_id, r.kind, r.id, r.fields, r.clock,
        coalesce((select max(v collate "C") from jsonb_each_text(r.clock) as t(k, v)), ''),
        nextval('public.record_seq'),
        d.id
      );
      changed_rows := changed_rows + 1;
      continue;
    end if;

    merged_fields := cur.fields;
    merged_clock := cur.clock;
    changed := false;
    for f in select k, v from jsonb_each_text(r.clock) as t(k, v) loop
      if f.v collate "C" > coalesce(cur.clock ->> f.k, '') collate "C" then
        merged_fields := merged_fields
          || jsonb_build_object(f.k, coalesce(r.fields -> f.k, 'null'::jsonb));
        merged_clock := merged_clock || jsonb_build_object(f.k, f.v);
        changed := true;
      end if;
    end loop;

    if changed then
      update public.records
      set fields = merged_fields,
          clock = merged_clock,
          hlc = (select max(v collate "C") from jsonb_each_text(merged_clock) as t(k, v)),
          seq = nextval('public.record_seq'),
          updated_by = d.id,
          updated_at = now()
      where space_id = d.space_id and kind = r.kind and id = r.id;
      changed_rows := changed_rows + 1;
    end if;
  end loop;

  update public.devices set last_seen = now() where id = d.id;
  if changed_rows > 0 then
    perform public.sr_ping(d.space_id, 'changed', d.id);
  end if;
  return changed_rows;
end;
$$;

-- Records in this device's space changed after sequence number p_after,
-- oldest first.
create or replace function public.pull_records(
  p_secret text,
  p_after bigint,
  p_limit int default 500
)
returns table (kind text, id text, fields jsonb, clock jsonb, seq bigint)
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.devices := public.sr_device(p_secret);
begin
  return query
    select x.kind, x.id, x.fields, x.clock, x.seq
    from public.records x
    where x.space_id = d.space_id and x.seq > coalesce(p_after, 0)
    order by x.seq
    limit least(greatest(coalesce(p_limit, 500), 1), 1000);
end;
$$;

-- Saves the push token Firebase gave this phone, so the other devices can
-- wake it when a focus session starts or stops. An empty token clears it.
create or replace function public.set_push_token(p_secret text, p_token text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.devices := public.sr_device(p_secret);
  t text := nullif(btrim(coalesce(p_token, '')), '');
begin
  if length(t) > 4096 then
    raise exception 'push token too long' using errcode = 'SR400';
  end if;
  -- A token belongs to one install, so a device this phone used to be loses it.
  if t is not null then
    update public.devices set push_token = null
    where devices.push_token = t and devices.id <> d.id;
  end if;
  update public.devices set push_token = t, last_seen = now() where devices.id = d.id;
end;
$$;

-- For the focus-push function only (it runs with the project's secret key):
-- the push tokens of the other devices in the caller's space, and the phone's
-- focus session as the server has it, with its version (the newest field
-- stamp). Only phones have push tokens, so only the phone's session goes out.
-- Tokens never reach the apps. At most 30 calls in 10 minutes per device.
create or replace function public.focus_push_targets(p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  d public.devices := public.sr_device(p_secret);
  v_count int;
  v_tokens jsonb;
  v_focus public.records;
begin
  -- One statement on the locked row, so parallel calls cannot all pass.
  update public.devices x set
    push_count = case
      when x.push_window_start < now() - interval '10 minutes' then 1
      else x.push_count + 1
    end,
    push_window_start = case
      when x.push_window_start < now() - interval '10 minutes' then now()
      else x.push_window_start
    end
  where x.id = d.id
  returning x.push_count into v_count;
  if v_count > 30 then
    raise exception 'too many pushes' using errcode = 'SR429';
  end if;
  select coalesce(jsonb_agg(distinct x.push_token), '[]'::jsonb) into v_tokens
  from public.devices x
  where x.space_id = d.space_id and x.id <> d.id and x.push_token is not null;
  select * into v_focus
  from public.records r
  where r.space_id = d.space_id and r.kind = 'focus' and r.id = 'phone';
  return jsonb_build_object(
    'tokens', v_tokens,
    'focus', v_focus.fields,
    'version', v_focus.hlc
  );
end;
$$;

-- Only the app's entry points are callable from the public API.
revoke all on function
  public.sr_device(text),
  public.sr_ping(uuid, text, uuid),
  public.sr_drop_if_empty(uuid)
from public, anon, authenticated;

revoke all on function
  public.register_device(text, text, text),
  public.create_pairing_code(text),
  public.join_space(text, text),
  public.leave_space(text),
  public.list_devices(text),
  public.push_records(text, jsonb),
  public.pull_records(text, bigint, int),
  public.set_push_token(text, text)
from public;

grant execute on function
  public.register_device(text, text, text),
  public.create_pairing_code(text),
  public.join_space(text, text),
  public.leave_space(text),
  public.list_devices(text),
  public.push_records(text, jsonb),
  public.pull_records(text, bigint, int),
  public.set_push_token(text, text)
to anon, authenticated;

-- Only the focus-push function may read push tokens.
revoke all on function public.focus_push_targets(text)
from public, anon, authenticated;
grant execute on function public.focus_push_targets(text) to service_role;

-- Lets the API see the new functions right away.
notify pgrst, 'reload schema';
