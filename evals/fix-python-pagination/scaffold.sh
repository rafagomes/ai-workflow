#!/usr/bin/env bash
# Python project with an off-by-one in page_count; existing tests only use
# totals that divide evenly, so they pass.
# shellcheck disable=SC2016  # fixture text is literal on purpose
set -euo pipefail
git init -q -b main
git config user.email eval@example.com
git config user.name "Eval Fixture"
mkdir -p src tests
touch src/__init__.py tests/__init__.py
cat > src/paging.py <<'PY'
def page_count(total, size):
    """Number of pages needed to show `total` items, `size` per page."""
    return total // size


def page_slice(items, page, size):
    start = page * size
    return items[start:start + size]
PY
cat > tests/test_paging.py <<'PY'
import unittest
from src.paging import page_count, page_slice


class PagingTest(unittest.TestCase):
    def test_even_split(self):
        self.assertEqual(page_count(9, 3), 3)
        self.assertEqual(page_count(6, 2), 3)

    def test_empty(self):
        self.assertEqual(page_count(0, 5), 0)

    def test_slice(self):
        self.assertEqual(page_slice(list(range(10)), 1, 4), [4, 5, 6, 7])


if __name__ == "__main__":
    unittest.main()
PY
printf '__pycache__/\n' > .gitignore
printf 'test:\n\tpython3 -m unittest discover -s tests -t .\n' > Makefile
printf '# paging\n\nRun `make test`.\n' > README.md
git add -A
git commit -q -m "chore: initial commit"
# Local bare "origin" inside .git, so the skills can resolve the trunk without a network.
git init -q --bare "$PWD/.git/origin.git"
git remote add origin "$PWD/.git/origin.git"
git push -q origin main
git remote set-head origin main
