#!/usr/bin/env bash
# Tests for install.sh and uninstall.sh. Runs them against a throwaway HOME and
# CLAUDE_DIR, from a temporary copy of the scripts, so the real clone is never
# touched (install.sh seeds an untracked settings.json next to itself).
#
# Usage: bash tests/install_test.sh
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS + 1)); }
fail() { FAIL=$((FAIL + 1)); echo "FAIL: $1" >&2; }
# check <description> <command...>
check() {
    local desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok; else fail "$desc"; fi
}
# check_eq <description> <expected> <actual>
check_eq() { if [ "$2" = "$3" ]; then ok; else fail "$1 (expected '$2', got '$3')"; fi; }
count_bak() { find "$1" -maxdepth 1 -name "$2.bak.*" 2>/dev/null | wc -l | tr -d ' '; }

copy_clone() {
    mkdir -p "$1"
    cp -R "$REPO/install.sh" "$REPO/uninstall.sh" "$REPO/dotfiles" \
          "$REPO/settings.example.json" "$REPO/extras" "$1/"
}

# Fresh scenario: its own HOME and its own clone copy. Sets CLONE, HOME_DIR, PRIMARY.
scenario() {
    local d
    d="$(mktemp -d "$TMP/s.XXXXXX")"
    mkdir -p "$d/home"
    copy_clone "$d/clone"
    CLONE="$(cd -P "$d/clone" && pwd)"
    HOME_DIR="$(cd -P "$d/home" && pwd)"
    PRIMARY="$HOME_DIR/.claude"
}
install()   { local dir="$1"; shift; HOME="$HOME_DIR" CLAUDE_DIR="$dir" bash "$CLONE/install.sh" "$@" >/dev/null 2>&1; }
uninstall() { HOME="$HOME_DIR" CLAUDE_DIR="$1" bash "$CLONE/uninstall.sh" >/dev/null 2>&1; }
target()    { readlink "$1" 2>/dev/null || echo "<none>"; }

HAD_SETTINGS=0
[ -e "$REPO/settings.json" ] && HAD_SETTINGS=1

# 1. Primary dir: CLAUDE.md and settings.json linked into the clone, settings seeded.
scenario
install "$PRIMARY"
check_eq "primary: CLAUDE.md link" "$CLONE/dotfiles/CLAUDE.md" "$(target "$PRIMARY/CLAUDE.md")"
check_eq "primary: settings.json link" "$CLONE/settings.json" "$(target "$PRIMARY/settings.json")"
check "primary: settings.json seeded from example" cmp -s "$CLONE/settings.json" "$CLONE/settings.example.json"
check "primary: no extras link by default" test ! -e "$PRIMARY/skills/rlabs-design"

# 2. Re-running install is idempotent: links intact, no backups created.
install "$PRIMARY"
check_eq "idempotent: CLAUDE.md link" "$CLONE/dotfiles/CLAUDE.md" "$(target "$PRIMARY/CLAUDE.md")"
check_eq "idempotent: no CLAUDE.md backup" 0 "$(count_bak "$PRIMARY" CLAUDE.md)"
check_eq "idempotent: no settings.json backup" 0 "$(count_bak "$PRIMARY" settings.json)"
# An existing (edited) settings.json in the clone is kept, not re-seeded.
echo '{"mine":true}' > "$CLONE/settings.json"
install "$PRIMARY"
check_eq "existing clone settings.json kept" '{"mine":true}' "$(cat "$CLONE/settings.json")"

# 3. --no-settings on the primary dir: no settings link, nothing seeded.
scenario
install "$PRIMARY" --no-settings
check_eq "--no-settings: no settings link" "<none>" "$(target "$PRIMARY/settings.json")"
check "--no-settings: nothing seeded" test ! -e "$CLONE/settings.json"
check_eq "--no-settings: CLAUDE.md still linked" "$CLONE/dotfiles/CLAUDE.md" "$(target "$PRIMARY/CLAUDE.md")"

# 4. Secondary profile skips settings unless --with-settings.
scenario
SECOND="$HOME_DIR/.claude-work"
install "$SECOND"
check_eq "secondary: CLAUDE.md linked" "$CLONE/dotfiles/CLAUDE.md" "$(target "$SECOND/CLAUDE.md")"
check "secondary: settings.json not linked" test ! -e "$SECOND/settings.json"
check "secondary: settings.json not seeded" test ! -e "$CLONE/settings.json"
install "$SECOND" --with-settings
check_eq "secondary --with-settings: linked" "$CLONE/settings.json" "$(target "$SECOND/settings.json")"

# 5. A trailing slash on CLAUDE_DIR still resolves to the primary dir.
scenario
install "$PRIMARY/"
check_eq "primary with trailing slash: settings linked" "$CLONE/settings.json" "$(target "$PRIMARY/settings.json")"

# 6. Pre-existing files are backed up and uninstall restores them. A second
#    dir with nothing pre-existing gets no backup.
scenario
SECOND="$HOME_DIR/.claude-work"
mkdir -p "$PRIMARY" "$SECOND"
echo "my own rules" > "$PRIMARY/CLAUDE.md"
echo '{"theme":"mine"}' > "$PRIMARY/settings.json"
install "$PRIMARY"
install "$SECOND"
check_eq "backup: CLAUDE.md linked" "$CLONE/dotfiles/CLAUDE.md" "$(target "$PRIMARY/CLAUDE.md")"
check_eq "backup: CLAUDE.md backup made" 1 "$(count_bak "$PRIMARY" CLAUDE.md)"
check_eq "backup: settings.json backup made" 1 "$(count_bak "$PRIMARY" settings.json)"
check_eq "backup: none for a clean dir" 0 "$(count_bak "$SECOND" CLAUDE.md)"
uninstall "$PRIMARY"
check_eq "restore: CLAUDE.md content" "my own rules" "$(cat "$PRIMARY/CLAUDE.md")"
check "restore: CLAUDE.md is a regular file" test ! -L "$PRIMARY/CLAUDE.md"
check_eq "restore: settings.json content" '{"theme":"mine"}' "$(cat "$PRIMARY/settings.json")"
check_eq "restore: backup consumed" 0 "$(count_bak "$PRIMARY" CLAUDE.md)"
uninstall "$SECOND"
check "uninstall: clean dir has no CLAUDE.md left" test ! -e "$SECOND/CLAUDE.md"

# 7. --extra links the extras skill, and uninstall removes it.
scenario
install "$PRIMARY" --extra
check_eq "--extra: skill linked" "$CLONE/extras/skills/rlabs-design" "$(target "$PRIMARY/skills/rlabs-design")"
check "--extra: skill resolves" test -f "$PRIMARY/skills/rlabs-design/SKILL.md"
uninstall "$PRIMARY"
check "uninstall: extras link removed" test ! -e "$PRIMARY/skills/rlabs-design"
check "uninstall: CLAUDE.md link removed" test ! -e "$PRIMARY/CLAUDE.md"
check "uninstall: settings.json link removed" test ! -e "$PRIMARY/settings.json"

# 8. Uninstall removes only links into this clone.
scenario
SECOND="$HOME_DIR/.claude-work"
mkdir -p "$SECOND"
echo '{}' > "$HOME_DIR/own-settings.json"
echo "unrelated" > "$HOME_DIR/other.md"
ln -s "$HOME_DIR/own-settings.json" "$SECOND/settings.json"
install "$SECOND"   # secondary: links CLAUDE.md, leaves settings.json alone
check_eq "foreign settings link kept by install" "$HOME_DIR/own-settings.json" "$(target "$SECOND/settings.json")"
ln -s "$HOME_DIR/other.md" "$SECOND/commands-note.md"
uninstall "$SECOND"
check "uninstall: own CLAUDE.md link removed" test ! -e "$SECOND/CLAUDE.md"
check_eq "uninstall: foreign settings link kept" "$HOME_DIR/own-settings.json" "$(target "$SECOND/settings.json")"
check_eq "uninstall: foreign file kept" "$HOME_DIR/other.md" "$(target "$SECOND/commands-note.md")"
# A link into a different clone is not ours either.
scenario
install "$PRIMARY"
copy_clone "$HOME_DIR/other-clone"
HOME="$HOME_DIR" CLAUDE_DIR="$PRIMARY" bash "$HOME_DIR/other-clone/uninstall.sh" >/dev/null 2>&1
check_eq "uninstall from another clone keeps links" "$CLONE/dotfiles/CLAUDE.md" "$(target "$PRIMARY/CLAUDE.md")"

# 9. Unknown argument exits non-zero and links nothing.
scenario
rc=0
HOME="$HOME_DIR" CLAUDE_DIR="$PRIMARY" bash "$CLONE/install.sh" --bogus >/dev/null 2>&1 || rc=$?
check "unknown argument exits non-zero" test "$rc" -ne 0
check "unknown argument links nothing" test ! -e "$PRIMARY/CLAUDE.md"

# The real clone must not have been touched.
if [ "$HAD_SETTINGS" -eq 0 ]; then
    check "real clone left without a settings.json" test ! -e "$REPO/settings.json"
fi

echo "install_test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
