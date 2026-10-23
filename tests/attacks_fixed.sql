\i tests/as_alice.sql
\echo '--- fixed app: each attack must be refused, normal use must work'
do $$ begin
  update profiles set likes_left = 999 where id = auth.uid();
  raise exception 'FAIL: quota still writable';
exception when insufficient_privilege then raise notice 'fix 1 holds: quota update refused';
end $$;
do $$ begin
  update profiles set display_name = 'Alice B.' where id = auth.uid();
  raise notice 'fix 1 keeps normal use: Alice renamed herself';
end $$;
do $$ declare e text; begin
  select email into e from profiles where id = '00000000-0000-0000-0000-00000000000b';
  raise exception 'FAIL: Bob''s email still readable';
exception when insufficient_privilege then raise notice 'fix 2 holds: other members'' private columns refused';
end $$;
do $$ declare n text; e text; begin
  select display_name into n from profiles where id = '00000000-0000-0000-0000-00000000000b';
  select email into e from my_profile();
  if n <> 'Bob' or e <> 'alice@example.com' then raise exception 'FAIL: browsing or own profile broken'; end if;
  raise notice 'fix 2 keeps normal use: Alice sees Bob''s name and her own email';
end $$;
do $$ begin
  insert into likes (from_user, to_user) values (auth.uid(), '00000000-0000-0000-0000-00000000000b');
  raise exception 'FAIL: direct like insert still allowed';
exception when insufficient_privilege then raise notice 'fix 3 holds: direct like insert refused';
end $$;
do $$ begin
  perform send_like('00000000-0000-0000-0000-00000000000b');
  raise exception 'FAIL: like sent with an empty quota';
exception when raise_exception then
  if sqlerrm like 'FAIL%' then raise; end if;
  raise notice 'fix 3 holds: send_like refused with no likes left (%)', sqlerrm;
end $$;
do $$ begin
  perform reset_likes(auth.uid());
  raise exception 'FAIL: reset_likes still callable';
exception when insufficient_privilege then raise notice 'fix 4 holds: reset_likes refused';
end $$;
reset role;
-- The scheduler (table owner, like Supabase's service role) still resets quotas; then a like goes through.
do $$ begin perform reset_likes('00000000-0000-0000-0000-00000000000a'); end $$;
\i tests/as_alice.sql
do $$ begin
  perform send_like('00000000-0000-0000-0000-00000000000b');
  if (select likes_left from my_profile()) <> 9 then raise exception 'FAIL: quota not spent'; end if;
  raise notice 'fix 3 keeps normal use: one like sent, 9 left';
end $$;
reset role;
set role anon;
do $$ begin
  perform 1 from likes;
  raise exception 'FAIL: anon still has table privileges';
exception when insufficient_privilege then raise notice 'anon has no table access';
end $$;
reset role;
