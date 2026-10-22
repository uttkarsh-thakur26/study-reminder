-- Stand-ins for what Supabase provides, so the schema runs on plain Postgres.
do $$ begin
  if not exists (select 1 from pg_roles where rolname = 'anon') then create role anon nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'authenticated') then create role authenticated nologin; end if;
  if not exists (select 1 from pg_roles where rolname = 'service_role') then create role service_role nologin; end if;
end $$;
create schema if not exists realtime;
create table if not exists realtime.sent (topic text, event text, payload jsonb, private boolean);
create or replace function realtime.send(payload jsonb, event text, topic text, private boolean default true)
returns void language sql as $$ insert into realtime.sent values (topic, event, payload, private) $$;
grant usage on schema realtime to public;
