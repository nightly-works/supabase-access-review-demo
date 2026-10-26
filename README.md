# Access review of an AI-built Supabase app (demo)

A proof piece for security reviews of apps written with AI coding tools: a small, fictional dating web app's database as such tools tend to write it, four flaws a signed-in user can exploit from the browser console, each reproduced by a query, then fixed with the same queries proving the fix and that normal use still works.

| # | Flaw | Why row-level security did not stop it | Fix |
|---|---|---|---|
| 1 | A user resets their own like quota | the "users update own profile" policy covers every column of their row | update privilege on `display_name` only |
| 2 | Any member reads every member's email, birth date and exact location | RLS filters rows, never columns | column privileges for others; `my_profile()` for one's own private fields |
| 3 | Unlimited likes | the client inserts the like and decrements the quota itself | `send_like()`: quota check and insert together, direct inserts closed |
| 4 | Anyone calls the scheduler's `reset_likes()` | functions are executable by everyone by default, and `security definer` bypasses RLS | execute revoked from the API roles |

Also closed: `anon` kept every table privilege by default, guarded only by the absence of anon policies.

Supabase itself is not needed: `sql/00_supabase_shim.sql` recreates its API roles, its default privileges and `auth.uid()` on plain PostgreSQL. A client's `supabase db dump --schema-only` can be replayed the same way once the other Supabase objects it references (`auth.users`, extensions, `service_role`) are stubbed.

After fix 2, client code must list the columns it reads (`select('id, display_name')`): `select('*')` on `profiles` is refused.

Also tightened: `reset_likes()` gets a fixed `search_path`, and `authenticated` loses the table privileges it never needed (insert, delete, truncate, trigger, references; RLS never applies to TRUNCATE).

Checked on PostgreSQL 15 (all attacks reproduced, all fixes hold, normal use works). Run: `./run.sh` (PostgreSQL server binaries under `/usr/lib/postgresql/*/bin`, `psql`). It starts a throwaway cluster, runs `tests/attacks_flawed.sql` (every attack must succeed), applies `sql/02_fixes.sql`, runs `tests/attacks_fixed.sql` (every attack must be refused, normal use must work) and stops at the first unexpected result.

[![checks](https://github.com/nightly-works/supabase-access-review-demo/actions/workflows/checks.yml/badge.svg)](https://github.com/nightly-works/supabase-access-review-demo/actions/workflows/checks.yml)

Built by an AI agent (Claude) at [Nightly Works](https://github.com/nightly-works); the app is fictional, written for this demo. MIT licence.
