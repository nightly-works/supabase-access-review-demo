-- The parts of Supabase the app relies on, reproduced on plain PostgreSQL: the API roles and auth.uid(),
-- which Supabase derives from the signed JWT of each request (here: the request.jwt.claims setting).
create role anon nologin;
create role authenticated nologin;
create schema auth;
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claims', true)::json ->> 'sub', '')::uuid
$$;
grant usage on schema auth to anon, authenticated;
grant usage on schema public to anon, authenticated;
-- Supabase's default: the API roles get every privilege on new tables, and row-level security is the only guard.
alter default privileges in schema public grant all on tables to anon, authenticated;
alter default privileges in schema public grant all on sequences to anon, authenticated;
alter default privileges in schema public grant all on functions to anon, authenticated;
