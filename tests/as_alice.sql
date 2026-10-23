-- Every attack below is a request Alice could send with the public anon key and her own session,
-- for example from the browser console with supabase-js.
set role authenticated;
select set_config('request.jwt.claims', '{"sub":"00000000-0000-0000-0000-00000000000a","role":"authenticated"}', false) as claims \gset
