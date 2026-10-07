#!/usr/bin/env bash
set -euo pipefail

# AI Workflow Installer
# Symlinks this repo's config files into ~/.claude/ so changes stay in sync.
#
# Usage:
#   ./install.sh                    Install the core workflow (no extras)
#   ./install.sh --extra            Install core + everything under extras/
#   ./install.sh settings.json      Install only matching target(s)
#   ./install.sh --extra rlabs-design
#   ./install.sh --no-settings      Never link settings.json
#   ./install.sh --with-settings    Always link settings.json
#
# CLAUDE_DIR selects which Claude config dir to install into (default
# ~/.claude). Claude Code supports several isolated profiles via its own
# CLAUDE_CONFIG_DIR, and each one needs its own copy of the symlinks:
#
#   CLAUDE_DIR="$HOME/.claude-work" ./install.sh
#
# Skills, agents, commands, review guides and the global CLAUDE.md are shared
# toolkit — every profile gets them. settings.json is not: it carries the
# profile's account, theme, model, status line and enabled plugins, which is
# the whole reason to run separate profiles. So it is linked only into the
# primary dir; a secondary CLAUDE_DIR keeps its own file. The two flags force
# the decision either way.
#
# Extras are personal/optional add-ons (e.g. private brand systems) that live
# under extras/ and are not part of the default workflow. They are only linked
# when --extra is passed.
#
# A filter matches a target if it equals the source path, the destination
# path, or the basename of either. This lets you refresh one file without
# re-linking every skill and agent.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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

INSTALL_EXTRAS=0
INSTALL_SETTINGS=""
FILTERS=()
for arg in "$@"; do
    if [ "$arg" = "--extra" ] || [ "$arg" = "--extras" ]; then
        INSTALL_EXTRAS=1
    elif [ "$arg" = "--no-settings" ]; then
        INSTALL_SETTINGS=0
    elif [ "$arg" = "--with-settings" ]; then
        INSTALL_SETTINGS=1
    else
        FILTERS+=("$arg")
    fi
done

# Unflagged: the primary dir gets settings.json, a secondary profile keeps its
# own. Deriving this from CLAUDE_DIR rather than a flag is what makes it hold
# across `aiwf update` and `aiwf reinstall`, which re-run the install for you.
if [ -z "$INSTALL_SETTINGS" ]; then
    if [ "$CLAUDE_DIR" = "$PRIMARY_CLAUDE_DIR" ]; then
        INSTALL_SETTINGS=1
    else
        INSTALL_SETTINGS=0
    fi
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1"; }
skip()  { echo -e "${YELLOW}[-]${NC} skip $1"; }

# Returns 0 (install) if no filters given, or if any filter matches the entry.
# Matches on: exact src path, exact dst path, basename of src, basename of dst.
should_install() {
    local src="$1"
    local dst="$2"

    if [ ${#FILTERS[@]} -eq 0 ]; then
        return 0
    fi

    local src_base="${src##*/}"
    local dst_base="${dst##*/}"
    local f
    for f in "${FILTERS[@]}"; do
        if [ "$f" = "$src" ] || [ "$f" = "$dst" ] \
           || [ "$f" = "$src_base" ] || [ "$f" = "$dst_base" ]; then
            return 0
        fi
    done
    return 1
}

backup_if_exists() {
    local target="$1"
    if [ -e "$target" ] && [ ! -L "$target" ]; then
        local backup="${target}.bak.$(date +%s)"
        warn "Backing up existing $target -> $backup"
        mv "$target" "$backup"
    elif [ -L "$target" ]; then
        rm "$target"
    fi
}

link() {
    local src_rel="$1"
    local dst_rel="$2"
    local src="$SCRIPT_DIR/$src_rel"
    local dst="$CLAUDE_DIR/$dst_rel"

    if ! should_install "$src_rel" "$dst_rel"; then
        return 0
    fi

    MATCHED=$((MATCHED + 1))

    if [ ! -e "$src" ]; then
        error "Source not found: $src"
        return 1
    fi

    mkdir -p "$(dirname "$dst")"
    backup_if_exists "$dst"
    ln -sf "$src" "$dst"
    info "Linked $dst -> $src"
}

link_bin() {
    local src_rel="$1"
    local dst_name="$2"
    local src="$SCRIPT_DIR/$src_rel"
    local dst="$BIN_DIR/$dst_name"

    if ! should_install "$src_rel" "$dst_name"; then
        return 0
    fi

    MATCHED=$((MATCHED + 1))

    if [ ! -e "$src" ]; then
        error "Source not found: $src"
        return 1
    fi

    mkdir -p "$BIN_DIR"
    backup_if_exists "$dst"
    ln -sf "$src" "$dst"
    info "Linked $dst -> $src"
}

echo ""
echo "=== AI Workflow Installer ==="
echo ""
if [ ${#FILTERS[@]} -eq 0 ]; then
    echo "This will symlink ALL core config files from:"
else
    echo "This will symlink filtered targets (${FILTERS[*]}) from:"
fi
if [ "$INSTALL_EXTRAS" -eq 1 ]; then
    echo "  (--extra: extras/ add-ons included)"
fi
if [ "$INSTALL_SETTINGS" -eq 0 ]; then
    echo "  (settings.json left alone — profile-local)"
fi
echo "  $SCRIPT_DIR"
echo "into:"
echo "  $CLAUDE_DIR"
echo ""

MATCHED=0

# Ensure ~/.claude exists
mkdir -p "$CLAUDE_DIR"/{agents,commands,skills}

# Install the aiwf launcher so follow-up platform commands work from a clone.
link_bin "aiwf" "aiwf"

# Global config (the global Claude defaults — applies to every project).
# Project-specific CLAUDE.md for working IN the ai-workflow repo lives at the
# repo root and is NOT installed (it loads only when you cd into the repo).
link "dotfiles/CLAUDE.md"       "CLAUDE.md"

# settings.json is per-user (gitignored). Seed from the tracked example on
# fresh clones so the symlink target exists before we link it into ~/.claude.
if [ "$INSTALL_SETTINGS" -eq 1 ]; then
    if [ ! -e "$SCRIPT_DIR/settings.json" ] && [ -e "$SCRIPT_DIR/settings.example.json" ]; then
        cp "$SCRIPT_DIR/settings.example.json" "$SCRIPT_DIR/settings.json"
        info "Seeded settings.json from settings.example.json (edit freely; not tracked)"
    fi
    link "settings.json"        "settings.json"
else
    skip "settings.json (profile-local)"
fi

link "statusline-command.sh"    "statusline-command.sh"

# Agents
link "agents/security-reviewer.md"      "agents/security-reviewer.md"
link "agents/architecture-reviewer.md"   "agents/architecture-reviewer.md"

# Commands
link "commands/sec-review.md"   "commands/sec-review.md"

# Skills
for skill in spec new-project prd roadmap architecture tdd security adr rfc commit design verify-design issues; do
    mkdir -p "$CLAUDE_DIR/skills/$skill"
    link "skills/$skill/SKILL.md" "skills/$skill/SKILL.md"
done

# Retired skills — removed from the toolkit in favour of marketplace plugins
# (see README "Required plugins"). An existing install still has symlinks for
# them, now pointing at files that no longer exist, and `aiwf update` only
# re-runs this script — so drop them here. Only dangling links to a path of that
# shape are touched; a live skill of the same name from anywhere else is left
# alone. Dangling, not "points into $SCRIPT_DIR": the clone may be reached by a
# different spelling of its path than the one the link was made with.
if [ ${#FILTERS[@]} -eq 0 ]; then
    for skill in feature fix review autopilot factory pr; do
        stale="$CLAUDE_DIR/skills/$skill/SKILL.md"
        if [ -L "$stale" ] && [ ! -e "$stale" ]; then
            case "$(readlink "$stale")" in
                */skills/"$skill"/SKILL.md) ;;
                *) continue ;;
            esac
            rm "$stale"
            rmdir "$CLAUDE_DIR/skills/$skill" 2>/dev/null || true
            info "Removed retired skill link: $stale"
        fi
    done
fi

# Extras (opt-in via --extra): personal add-ons that sit outside the core
# workflow. Multi-file skills are symlinked as whole directories so supporting
# files (CSS tokens, fonts, assets, UI kits, previews) resolve from within.
if [ "$INSTALL_EXTRAS" -eq 1 ]; then
    for skill in rlabs-design; do
        link "extras/skills/$skill" "skills/$skill"
    done
fi

# Language-specific review guides
mkdir -p "$CLAUDE_DIR/reviews"
for guide in go rust typescript python; do
    link "reviews/$guide.md" "reviews/$guide.md"
done

# Ensure adapter scripts are executable (important after a fresh clone)
chmod +x \
    "$SCRIPT_DIR/adapters/cursor/install.sh" \
    "$SCRIPT_DIR/adapters/cursor/uninstall.sh" \
    "$SCRIPT_DIR/adapters/codex/install.sh" \
    "$SCRIPT_DIR/adapters/codex/uninstall.sh" \
    2>/dev/null || true

echo ""
if [ ${#FILTERS[@]} -gt 0 ] && [ "$MATCHED" -eq 0 ]; then
    if [ "$INSTALL_SETTINGS" -eq 0 ] && should_install "settings.json" "settings.json"; then
        info "Nothing to do: settings.json stays profile-local for $CLAUDE_DIR."
        info "Pass --with-settings to link it anyway."
        exit 0
    fi
    error "No targets matched filter(s): ${FILTERS[*]}"
    exit 1
fi
info "Done! $MATCHED target(s) linked."
info "Edit files in $SCRIPT_DIR and changes apply to $CLAUDE_DIR/ automatically."
info "For Cursor: aiwf install-cursor | For Codex: aiwf install-codex | For all: aiwf install-all"
echo ""
