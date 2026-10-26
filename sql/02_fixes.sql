-- Fix 1: users may change their display name only; the quota is no longer writable from the API.
revoke update on profiles from anon, authenticated;
grant update (display_name) on profiles to authenticated;

-- Fix 2: RLS filters rows, not columns. Other members see id and display name only;
-- a user reads their own private fields through my_profile().
revoke select on profiles from anon, authenticated;
grant select (id, display_name) on profiles to authenticated;
create function my_profile() returns setof profiles language sql stable security definer set search_path = public as $$
  select * from profiles where id = auth.uid()
$$;
revoke execute on function my_profile() from public, anon;
grant execute on function my_profile() to authenticated;

-- Fix 3: a like and its quota change happen together, server side; direct inserts are closed.
revoke insert on likes from anon, authenticated;
create function send_like(target uuid) returns void language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then raise exception 'not signed in'; end if;
  if target = auth.uid() then raise exception 'cannot like yourself'; end if;
  update profiles set likes_left = likes_left - 1 where id = auth.uid() and likes_left > 0;
  if not found then raise exception 'no likes left today'; end if;
  insert into likes (from_user, to_user) values (auth.uid(), target);
end $$;
revoke execute on function send_like(uuid) from public, anon;
grant execute on function send_like(uuid) to authenticated;

-- Fix 4: the quota reset is for the scheduler only (it runs as the service role, here the table owner).
revoke execute on function reset_likes(uuid) from public, anon, authenticated;
-- A security definer function with a mutable search_path can be steered to other objects (Supabase's advisor flags it).
alter function reset_likes(uuid) set search_path = public;

-- Also closed: anon had every table privilege by default, guarded by the absence of anon policies only.
revoke all on profiles, likes from anon;
-- authenticated kept the other default privileges too; RLS never applies to TRUNCATE.
revoke insert, delete, truncate, trigger, references on profiles from authenticated;
revoke delete, truncate, trigger, references on likes from authenticated;
