-- A small dating web app as AI coding tools tend to write it: RLS is enabled everywhere and each policy
-- looks reasonable on its own.
create table profiles (
  id uuid primary key,
  display_name text not null,
  email text not null,
  birth_date date not null,
  latitude numeric,
  longitude numeric,
  likes_left int not null default 10
);
create table likes (
  id bigint generated always as identity primary key,
  from_user uuid not null references profiles(id),
  to_user uuid not null references profiles(id),
  created_at timestamptz not null default now()
);
alter table profiles enable row level security;
alter table likes enable row level security;

-- "Members can browse other members"
create policy "profiles are visible to members" on profiles for select to authenticated using (true);
-- "Users can edit their own profile"
create policy "users update own profile" on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
-- "Users can like someone": the client decrements likes_left after inserting
create policy "users insert own likes" on likes for insert to authenticated with check (from_user = auth.uid());
create policy "users see likes they sent or received" on likes for select to authenticated
  using (from_user = auth.uid() or to_user = auth.uid());

-- Daily quota reset, meant for a scheduled job
create function reset_likes(target uuid) returns void language sql security definer as $$
  update profiles set likes_left = 10 where id = target
$$;
