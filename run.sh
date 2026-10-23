#!/usr/bin/env bash
# Replays the app on a throwaway PostgreSQL cluster: attacks on the flawed schema, then the fixes and
# the same attacks again. Exits non-zero at the first unexpected result.
set -euo pipefail
cd "$(dirname "$0")"
BIN=$(ls -d /usr/lib/postgresql/*/bin | tail -1)
DATA=$(mktemp -d)
SOCK=$(mktemp -d)
trap '"$BIN/pg_ctl" -D "$DATA" -m immediate stop >/dev/null 2>&1 || true; rm -rf "$DATA" "$SOCK"' EXIT
"$BIN/initdb" -D "$DATA" -A trust -U postgres >/dev/null
"$BIN/pg_ctl" -D "$DATA" -o "-k $SOCK -c listen_addresses=''" -l "$DATA/log" -w start >/dev/null
PSQL=(psql -X -q -v ON_ERROR_STOP=1 -h "$SOCK" -U postgres postgres)
"${PSQL[@]}" -f sql/00_supabase_shim.sql -f sql/01_app.sql -f tests/seed.sql
"${PSQL[@]}" -f tests/attacks_flawed.sql
"${PSQL[@]}" -c "update profiles set likes_left = 0 where id = '00000000-0000-0000-0000-00000000000a'; delete from likes;"
"${PSQL[@]}" -f sql/02_fixes.sql
"${PSQL[@]}" -f tests/attacks_fixed.sql
echo "all checks passed"
