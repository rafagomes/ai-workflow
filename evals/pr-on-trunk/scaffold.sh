#!/usr/bin/env bash
# Clean tree on the trunk branch. No remote.
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name "Eval Fixture"
printf 'build:\n\t@echo build\n' > Makefile
printf '# demo\n' > README.md
git add -A
git commit -q -m "chore: initial commit"
printf '# demo\n\nA second commit, straight on main.\n' > README.md
git commit -q -am "docs: describe the demo"
