#!/usr/bin/env bash
# Shell project: kv.sh truncates values that contain '='.
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name "Eval Fixture"
mkdir -p bin conf tests
cat > bin/kv.sh <<'SH'
#!/bin/sh
# usage: kv.sh FILE KEY   (prints the value of KEY from a KEY=VALUE file)
grep "^$2=" "$1" | head -1 | cut -d= -f2
SH
cat > conf/app.conf <<'CONF'
NAME=demo
URL=postgres://h/db?a=1&b=2
CONF
cat > tests/run.sh <<'SH'
#!/bin/sh
fail=0
[ "$(sh bin/kv.sh conf/app.conf NAME)" = "demo" ] || { echo "FAIL NAME"; fail=1; }
[ -z "$(sh bin/kv.sh conf/app.conf MISSING)" ] || { echo "FAIL MISSING"; fail=1; }
exit $fail
SH
printf 'test:\n\tsh tests/run.sh\n\nlint:\n\tsh -n bin/kv.sh\n' > Makefile
printf '# kv\n\nRun `make test` and `make lint`.\n' > README.md
git add -A
git commit -q -m "chore: initial commit"
