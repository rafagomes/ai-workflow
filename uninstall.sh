#!/usr/bin/env bash
set -euo pipefail

# AI Workflow Uninstaller
# Removes symlinks created by install.sh and restores backups if they exist.
#
# CLAUDE_DIR selects which Claude config dir to clean (default ~/.claude), and
# must match the one install.sh was run against. Only symlinks are removed, so
# a profile that kept its own settings.json (install.sh --no-settings) is left
# untouched.

# Resolve a directory to its canonical form so that ~/.claude, ~/.claude/,
# ~/./.claude and a symlinked ~/.claude all compare equal. The primary-dir
# comparison below decides whether settings.json is shared, so a spelling
# difference must never flip it.
canonical_dir() {
    local d="${1%/}"
    [ -z "$d" ] && d="/"
    if [ -d "$d" ]; then (cd -P "$d" && pwd); else printf '%s\n' "$d"; fi
}

PRIMARY_CLAUDE_DIR="$(canonical_dir "$HOME/.claude")"
CLAUDE_DIR="$(canonical_dir "${CLAUDE_DIR:-$HOME/.claude}")"
BIN_DIR="${AIWF_BIN_DIR:-$HOME/.local/bin}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }

unlink_if_symlink() {
    local target="$1"
    if [ -L "$target" ]; then
        rm "$target"
        info "Removed symlink: $target"

        # Restore most recent backup if one exists
        local latest_backup
        latest_backup=$(ls -t "${target}.bak."* 2>/dev/null | head -1 || true)
        if [ -n "$latest_backup" ]; then
            mv "$latest_backup" "$target"
            warn "Restored backup: $latest_backup -> $target"
        fi
    fi
}

echo ""
echo "=== AI Workflow Uninstaller ==="
echo ""

FILES=(
    "CLAUDE.md"
    "settings.json"
    "statusline-command.sh"
    "agents/security-reviewer.md"
    "agents/architecture-reviewer.md"
    "commands/sec-review.md"
    "skills/spec/SKILL.md"
    "skills/new-project/SKILL.md"
    "skills/prd/SKILL.md"
    "skills/roadmap/SKILL.md"
    "skills/architecture/SKILL.md"
    "skills/tdd/SKILL.md"
    "skills/security/SKILL.md"
    "skills/adr/SKILL.md"
    "skills/rfc/SKILL.md"
    "skills/commit/SKILL.md"
    "skills/design/SKILL.md"
    "skills/verify-design/SKILL.md"
    "skills/issues/SKILL.md"
    "reviews/go.md"
    "reviews/rust.md"
    "reviews/typescript.md"
    "reviews/python.md"
)

for f in "${FILES[@]}"; do
    unlink_if_symlink "$CLAUDE_DIR/$f"
done

# Retired skills — no longer in the repo or installed by install.sh (replaced
# by marketplace plugins). Kept here so an install made before the removal
# still gets its now-dangling symlinks cleaned up by uninstall / `aiwf reinstall`.
# Only dangling links are removed: a live link under one of these names is a
# skill from somewhere else. A dangling one is removed wherever it pointed.
RETIRED_SKILLS=(
    "skills/feature/SKILL.md"
    "skills/fix/SKILL.md"
    "skills/review/SKILL.md"
    "skills/autopilot/SKILL.md"
    "skills/factory/SKILL.md"
    "skills/pr/SKILL.md"
)
for f in "${RETIRED_SKILLS[@]}"; do
    if [ -L "$CLAUDE_DIR/$f" ] && [ ! -e "$CLAUDE_DIR/$f" ]; then
        unlink_if_symlink "$CLAUDE_DIR/$f"
        rmdir "$(dirname "$CLAUDE_DIR/$f")" 2>/dev/null || true
    fi
done

# Extras (opt-in in install.sh via --extra). Always cleaned up on uninstall
# regardless of whether they were installed, so this is safe to run.
EXTRA_SKILLS=(
    "skills/rlabs-design"
)
for f in "${EXTRA_SKILLS[@]}"; do
    unlink_if_symlink "$CLAUDE_DIR/$f"
done

# The aiwf launcher is shared by every profile, so only the primary uninstall
# takes it away. Otherwise cleaning up one profile would strip the command the
# others still rely on.
if [ "$CLAUDE_DIR" = "$PRIMARY_CLAUDE_DIR" ]; then
    unlink_if_symlink "$BIN_DIR/aiwf"
else
    warn "Left $BIN_DIR/aiwf in place (shared by all profiles)"
fi

echo ""
info "Done! Symlinks removed. Original backups restored where available."
echo ""
