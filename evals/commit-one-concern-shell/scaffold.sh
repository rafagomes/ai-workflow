#!/usr/bin/env bash
# Shell project on a feature branch: one bug fix spread over two scripts,
# plus untracked build and scratch files that must not be committed.
# shellcheck disable=SC2016  # fixture text is literal on purpose
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name "Eval Fixture"
mkdir -p bin
cat > bin/backup.sh <<'SH'
#!/bin/sh
# usage: backup.sh SRC DEST
cp -r $1 $2
SH
cat > bin/restore.sh <<'SH'
#!/bin/sh
# usage: restore.sh SRC DEST
cp -r $1 $2
SH
printf 'lint:\n\tsh -n bin/backup.sh && sh -n bin/restore.sh\n' > Makefile
printf '# snapshot\n\nTiny backup helpers.\n' > README.md
git add -A
git commit -q -m "chore: initial commit"
# Local bare "origin" inside .git, so the skills can resolve the trunk without a network.
git init -q --bare "$PWD/.git/origin.git"
git remote add origin "$PWD/.git/origin.git"
git push -q origin main
git remote set-head origin main
git switch -q -c fix/paths-with-spaces

# One concern: quote the paths in both scripts.
sed -i 's|cp -r \$1 \$2|cp -r "$1" "$2"|' bin/backup.sh bin/restore.sh
mkdir -p dist
printf 'binary-ish' > dist/backup.tar
printf 'remember to test with spaces\n' > notes.scratch
