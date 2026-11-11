#!/usr/bin/env bash
# Python project with a Makefile test target and a filed spec (issue #42).
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name "Eval Fixture"
mkdir -p src tests docs/specs
touch src/__init__.py tests/__init__.py
cat > src/textutil.py <<'PY'
import re


def slugify(text):
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
PY
cat > tests/test_textutil.py <<'PY'
import unittest
from src.textutil import slugify


class SlugifyTest(unittest.TestCase):
    def test_slugify(self):
        self.assertEqual(slugify("Hello, World!"), "hello-world")


if __name__ == "__main__":
    unittest.main()
PY
printf '__pycache__/\n' > .gitignore
printf 'test:\n\tpython3 -m unittest discover -s tests -t .\n' > Makefile
printf '# textutil\n\nSmall text helpers. Run `make test`.\n' > README.md
cat > docs/specs/003_slug-truncate.md <<'MD'
# Slug truncation

## Trunk Metadata
- **Type:** feat
- **Flag:** `none`
- **Depends on:** —
- **Complexity:** low
- **Issue:** #42

## Problem
URLs built from titles get too long. We need a slug helper with a length cap.

## Design
Add `truncate_slug(text, max_len)` to `src/textutil.py`. It slugifies `text`
with the existing `slugify`, then cuts the result to at most `max_len`
characters on a word boundary (a hyphen), never leaving a trailing hyphen.
A single word longer than `max_len` is cut mid-word.

## Affected files
- `src/textutil.py`
- `tests/test_textutil.py`

## Verification Criteria
1. `truncate_slug("Hello, World!", 20)` returns `"hello-world"`.
2. `truncate_slug("The quick brown fox", 9)` returns `"the-quick"`.
3. `truncate_slug("Supercalifragilistic", 5)` returns `"super"`.
4. `truncate_slug("", 5)` and `truncate_slug("---", 5)` return `""`.
5. `truncate_slug("abc", 0)` raises `ValueError`.
MD
git add -A
git commit -q -m "chore: initial commit"
# Local bare "origin" inside .git, so the skills can resolve the trunk without a network.
git init -q --bare "$PWD/.git/origin.git"
git remote add origin "$PWD/.git/origin.git"
git push -q origin main
git remote set-head origin main
