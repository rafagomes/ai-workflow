#!/usr/bin/env bash
# Shell project with a Makefile test/lint and a spec whose issue is unfiled.
# shellcheck disable=SC2016  # fixture text is literal on purpose
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name "Eval Fixture"
mkdir -p bin tests docs/specs
cat > bin/report.sh <<'SH'
#!/bin/sh
# usage: report.sh FILE   (prints a header, then one "name: count" line per row)
echo "REPORT"
awk '{ print $1 ": " $2 }' "$1"
SH
printf 'alpha 3\nbeta 5\n' > tests/sample.txt
cat > tests/run.sh <<'SH'
#!/bin/sh
# Minimal test harness: each check prints FAIL and the script exits 1 on any failure.
fail=0
out=$(sh bin/report.sh tests/sample.txt)
[ "$out" = "REPORT
alpha: 3
beta: 5" ] || { echo "FAIL default output"; fail=1; }
exit $fail
SH
printf 'test:\n\tsh tests/run.sh\n\nlint:\n\tsh -n bin/report.sh\n' > Makefile
printf '# report\n\nRun `make test` and `make lint`.\n' > README.md
cat > docs/specs/002_quiet-flag.md <<'MD'
# Quiet flag

## Trunk Metadata
- **Type:** feat
- **Flag:** `none`
- **Depends on:** —
- **Complexity:** low
- **Issue:** — (filled by `/wf:issues`)

## Problem
Scripts that pipe `report.sh` do not want the `REPORT` header.

## Design
`bin/report.sh` accepts `--quiet` before the file name; with it the header is
not printed. Any other flag starting with `-` prints a usage line to stderr
and exits 2.

## Affected files
- `bin/report.sh`
- `tests/run.sh`

## Verification Criteria
1. `sh bin/report.sh tests/sample.txt` still prints the `REPORT` header and both rows.
2. `sh bin/report.sh --quiet tests/sample.txt` prints only `alpha: 3` and `beta: 5`.
3. `sh bin/report.sh --bogus tests/sample.txt` exits 2 and writes `usage` to stderr.
MD
git add -A
git commit -q -m "chore: initial commit"
# Local bare "origin" inside .git, so the skills can resolve the trunk without a network.
git init -q --bare "$PWD/.git/origin.git"
git remote add origin "$PWD/.git/origin.git"
git push -q origin main
git remote set-head origin main
