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
          "$REPO/settings.example.json" "$REPO/extras" "$REPO/agents" "$1/"
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
# Codex runs: CODEX is the throwaway CODEX_HOME, CLAUDE_DIR is the primary dir.
install_codex()   { HOME="$HOME_DIR" CLAUDE_DIR="$PRIMARY" CODEX_HOME="$CODEX" bash "$CLONE/install.sh" --no-settings --codex >/dev/null 2>&1; }
uninstall_codex() { HOME="$HOME_DIR" CLAUDE_DIR="$PRIMARY" CODEX_HOME="$CODEX" bash "$CLONE/uninstall.sh" --codex >/dev/null 2>&1; }
# toml_get <file> <key>: print one top-level string key (tomllib needs Python 3.11+).
toml_get() { python3 -I -c 'import sys,tomllib; print(tomllib.load(open(sys.argv[1],"rb"))[sys.argv[2]], end="")' "$1" "$2"; }
# The reviewer body: everything after the closing --- of the frontmatter.
body_of() { python3 -I -c 'import sys; print(open(sys.argv[1]).read().split("---\n",2)[2], end="")' "$1"; }
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

# 10. Codex: a default run creates nothing under CODEX_HOME.
scenario
CODEX="$HOME_DIR/.codex"
HOME="$HOME_DIR" CLAUDE_DIR="$PRIMARY" CODEX_HOME="$CODEX" bash "$CLONE/install.sh" --no-settings >/dev/null 2>&1
check "default run: CODEX_HOME not created" test ! -e "$CODEX"

if python3 -c 'import tomllib' 2>/dev/null; then
# 11. --codex: AGENTS.md linked, reviewer agent generated and parseable.
scenario
CODEX="$HOME_DIR/.codex"
install_codex
TOML="$CODEX/agents/wf-reviewer.toml"
check_eq "--codex: AGENTS.md link" "$CLONE/dotfiles/CLAUDE.md" "$(target "$CODEX/AGENTS.md")"
check "--codex: reviewer agent is a regular file" test -f "$TOML" -a ! -L "$TOML"
check_eq "--codex: agent name" "wf-reviewer" "$(toml_get "$TOML" name)"
check "--codex: agent description non-empty" test -n "$(toml_get "$TOML" description)"
check_eq "--codex: instructions are the reviewer body" "$(body_of "$CLONE/agents/reviewer.md")" "$(toml_get "$TOML" developer_instructions)"
check "--codex: Claude dir still gets CLAUDE.md" test -L "$PRIMARY/CLAUDE.md"
# 12. Idempotent: same file, no backups.
cp "$TOML" "$TMP/first.toml"
install_codex
check "idempotent: agent unchanged" cmp -s "$TMP/first.toml" "$TOML"
check_eq "idempotent: no AGENTS.md backup" 0 "$(count_bak "$CODEX" AGENTS.md)"
check_eq "idempotent: no agent backup" 0 "$(count_bak "$CODEX/agents" wf-reviewer.toml)"
# 13. The agent follows its source, and quotes and backslashes survive.
{
    printf '%s\n' '---' 'name: reviewer' 'description: Says "hi" \ and a path C:\x' '---'
    printf '%s\n' 'Line one "quoted" \n not an escape' '' "It's fine."
} > "$CLONE/agents/reviewer.md"
install_codex
check_eq "escaping: description" 'Says "hi" \ and a path C:\x' "$(toml_get "$TOML" description)"
check_eq "escaping: body verbatim" "$(body_of "$CLONE/agents/reviewer.md")" "$(toml_get "$TOML" developer_instructions)"
# A body that cannot be a literal string fails loudly and leaves the old agent alone.
cp "$TOML" "$TMP/before.toml"
printf '%s\n' '---' 'name: reviewer' 'description: d' '---' "has ''' inside" > "$CLONE/agents/reviewer.md"
rc=0
HOME="$HOME_DIR" CLAUDE_DIR="$PRIMARY" CODEX_HOME="$CODEX" bash "$CLONE/install.sh" --no-settings --codex >/dev/null 2>&1 || rc=$?
check "triple quote: install fails" test "$rc" -ne 0
check "triple quote: old agent kept" cmp -s "$TMP/before.toml" "$TOML"
check_eq "triple quote: no stray temp files" 1 "$(find "$CODEX/agents" -type f | wc -l | tr -d ' ')"

# 14. Backup and restore of pre-existing Codex files; uninstall without --codex
#     leaves Codex alone; uninstall --codex removes only what install created.
scenario
CODEX="$HOME_DIR/.codex"
TOML="$CODEX/agents/wf-reviewer.toml"
mkdir -p "$CODEX/agents"
echo "my agents rules" > "$CODEX/AGENTS.md"
echo 'name = "wf-reviewer"' > "$TOML"
install_codex
check_eq "backup: AGENTS.md linked" "$CLONE/dotfiles/CLAUDE.md" "$(target "$CODEX/AGENTS.md")"
check_eq "backup: AGENTS.md backup made" 1 "$(count_bak "$CODEX" AGENTS.md)"
check_eq "backup: hand-written agent backed up" 1 "$(count_bak "$CODEX/agents" wf-reviewer.toml)"
check_eq "backup: generated agent in place" "wf-reviewer" "$(toml_get "$TOML" name)"
uninstall "$PRIMARY"
check_eq "plain uninstall: Codex AGENTS.md link kept" "$CLONE/dotfiles/CLAUDE.md" "$(target "$CODEX/AGENTS.md")"
check "plain uninstall: Codex agent kept" test -f "$TOML"
uninstall_codex
check_eq "restore: AGENTS.md content" "my agents rules" "$(cat "$CODEX/AGENTS.md")"
check_eq "restore: agent content" 'name = "wf-reviewer"' "$(cat "$TOML")"
check_eq "restore: no AGENTS.md backup left" 0 "$(count_bak "$CODEX" AGENTS.md)"
# Without backups, uninstall removes the link and the generated file.
scenario
CODEX="$HOME_DIR/.codex"
install_codex
uninstall_codex
check "uninstall --codex: AGENTS.md removed" test ! -e "$CODEX/AGENTS.md"
check "uninstall --codex: agent removed" test ! -e "$CODEX/agents/wf-reviewer.toml"
# Foreign files are never removed.
scenario
CODEX="$HOME_DIR/.codex"
mkdir -p "$CODEX/agents"
echo "mine" > "$HOME_DIR/own.md"
ln -s "$HOME_DIR/own.md" "$CODEX/AGENTS.md"
echo 'name = "wf-reviewer"' > "$CODEX/agents/wf-reviewer.toml"
uninstall_codex
check_eq "foreign AGENTS.md link kept" "$HOME_DIR/own.md" "$(target "$CODEX/AGENTS.md")"
check_eq "hand-written agent kept" 'name = "wf-reviewer"' "$(cat "$CODEX/agents/wf-reviewer.toml")"
else
    echo "install_test: python3 tomllib unavailable, skipped the --codex checks" >&2
fi

# The real clone must not have been touched.
if [ "$HAD_SETTINGS" -eq 0 ]; then
    check "real clone left without a settings.json" test ! -e "$REPO/settings.json"
fi

echo "install_test: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
