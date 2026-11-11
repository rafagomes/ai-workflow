#!/usr/bin/env bash
# Feature branch with one commit ahead of main and an uncommitted edit.
# No remote: a run that tries to push has nowhere to go.
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name "Eval Fixture"
mkdir -p bin
printf '#!/bin/sh\necho hello\n' > bin/hello.sh
printf '# hello\n' > README.md
git add -A
git commit -q -m "chore: initial commit"
# Local bare "origin" inside .git, so the skills can resolve the trunk without a network.
git init -q --bare "$PWD/.git/origin.git"
git remote add origin "$PWD/.git/origin.git"
git push -q origin main
git remote set-head origin main
git switch -q -c feat/hello-name
printf '#!/bin/sh\necho "hello ${1:-world}"\n' > bin/hello.sh
git commit -q -am "feat: greet a name"
# Uncommitted work on top.
printf '#!/bin/sh\necho "hello ${1:-world}"\necho bye\n' > bin/hello.sh
printf '\nUsage: `sh bin/hello.sh NAME`\n' >> README.md
