#!/usr/bin/env bash
set -euo pipefail

# AI Workflow — personal config installer.
#
# The skills and the reviewer agent ship as the `wf` Claude Code plugin and
# are installed with `claude plugin install` (see README). A plugin cannot
# carry the things below, so this script symlinks them from this clone:
#
#   dotfiles/CLAUDE.md      -> $CLAUDE_DIR/CLAUDE.md
#   settings.json           -> $CLAUDE_DIR/settings.json   (primary dir only)
#
# Usage:
#   ./install.sh                  Link the files above
#   ./install.sh --extra          Also link the personal skills under extras/
#   ./install.sh --no-settings    Never link settings.json
#   ./install.sh --with-settings  Always link settings.json
#
# CLAUDE_DIR selects the Claude config dir (default ~/.claude). settings.json
# carries a profile's account, theme, model and enabled plugins, so by default
# it is linked only into the primary dir; a secondary profile keeps its own.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Resolve a directory to its canonical form so that ~/.claude, ~/.claude/ and a
# symlinked ~/.claude all compare equal — the primary-dir comparison below
# decides whether settings.json is shared.
canonical_dir() {
    local d="${1%/}"
    [ -z "$d" ] && d="/"
    if [ -d "$d" ]; then (cd -P "$d" && pwd); else printf '%s\n' "$d"; fi
}

PRIMARY_CLAUDE_DIR="$(canonical_dir "$HOME/.claude")"
CLAUDE_DIR="$(canonical_dir "${CLAUDE_DIR:-$HOME/.claude}")"

INSTALL_EXTRAS=0
INSTALL_SETTINGS=""
for arg in "$@"; do
    case "$arg" in
        --extra|--extras) INSTALL_EXTRAS=1 ;;
        --no-settings)    INSTALL_SETTINGS=0 ;;
        --with-settings)  INSTALL_SETTINGS=1 ;;
        *) echo "Unknown argument: $arg" >&2; exit 1 ;;
    esac
done
if [ -z "$INSTALL_SETTINGS" ]; then
    if [ "$CLAUDE_DIR" = "$PRIMARY_CLAUDE_DIR" ]; then INSTALL_SETTINGS=1; else INSTALL_SETTINGS=0; fi
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'
info() { echo -e "${GREEN}[+]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

link() {
    local src="$SCRIPT_DIR/$1"
    local dst="$CLAUDE_DIR/$2"
    mkdir -p "$(dirname "$dst")"
    if [ -L "$dst" ] && [[ "$(readlink "$dst")" == "$SCRIPT_DIR"/* ]]; then
        rm "$dst"
    elif [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup
        backup="${dst}.bak.$(date +%s)"
        warn "Backing up existing $dst -> $backup"
        mv "$dst" "$backup"
    fi
    ln -s "$src" "$dst"
    info "Linked $dst -> $src"
}

mkdir -p "$CLAUDE_DIR"

link "dotfiles/CLAUDE.md" "CLAUDE.md"

# settings.json is per-user (gitignored). Seed it from the tracked example on a
# fresh clone so the symlink target exists.
if [ "$INSTALL_SETTINGS" -eq 1 ]; then
    if [ ! -e "$SCRIPT_DIR/settings.json" ]; then
        cp "$SCRIPT_DIR/settings.example.json" "$SCRIPT_DIR/settings.json"
        info "Seeded settings.json from settings.example.json (edit freely; not tracked)"
    fi
    link "settings.json" "settings.json"
else
    warn "Left settings.json alone (profile-local)"
fi

# Extras: personal add-ons outside the plugin. Multi-file skills are linked as
# whole directories so their supporting files resolve.
if [ "$INSTALL_EXTRAS" -eq 1 ]; then
    # shellcheck disable=SC2043 # a list that currently has one entry
    for skill in rlabs-design; do
        link "extras/skills/$skill" "skills/$skill"
    done
fi

echo ""
info "Done. Now install the plugin (skills + reviewer agent):"
echo "    claude plugin marketplace add rafagomes/ai-workflow"
echo "    claude plugin install wf@ai-workflow"
echo ""
