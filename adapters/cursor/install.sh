#!/usr/bin/env bash
set -euo pipefail

# AI Workflow — Cursor Adapter Installer
#
# Generates ~/.cursor/rules/aiwf-*.mdc files from skills and global config.
# Cursor loads these rules automatically; the AI picks them up when relevant.
#
# Usage:
#   ./adapters/cursor/install.sh
#   CURSOR_RULES_DIR=<path> ./adapters/cursor/install.sh   # override target dir

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CURSOR_RULES_DIR="${CURSOR_RULES_DIR:-$HOME/.cursor/rules}"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1" >&2; }

# --- helpers -----------------------------------------------------------------

# Extract a frontmatter field value from a SKILL.md file.
# Usage: frontmatter_field <file> <field>
frontmatter_field() {
    local file="$1" field="$2"
    awk -v field="$field" '
        /^---/ { count++; next }
        count == 1 && $0 ~ "^"field": " {
            sub("^"field": *", "")
            print
        }
        count >= 2 { exit }
    ' "$file"
}

# Extract everything after the closing --- of YAML frontmatter.
skill_body() {
    awk '/^---/{count++; if(count==2){found=1; next}} found{print}' "$1"
}

# Write one .mdc rule file.
# Usage: write_rule <dest_path> <description> <always_apply> <body>
write_rule() {
    local dest="$1" description="$2" always_apply="$3" body="$4"
    {
        printf '%s\n' "---"
        printf 'description: %s\n' "$description"
        printf 'alwaysApply: %s\n' "$always_apply"
        printf '%s\n' "---"
        printf '%s\n' "$body"
    } > "$dest"
}

# --- main --------------------------------------------------------------------

echo ""
echo "=== AI Workflow — Cursor Installer ==="
echo ""
info "Rules dir: $CURSOR_RULES_DIR"
echo ""

mkdir -p "$CURSOR_RULES_DIR"

# 1. Global rule from dotfiles/CLAUDE.md ---------------------------------------
# Source is the global defaults file under dotfiles/, not the project-specific
# CLAUDE.md at the repo root (which only applies inside the ai-workflow repo).
global_src="$REPO_DIR/dotfiles/CLAUDE.md"
global_dst="$CURSOR_RULES_DIR/aiwf-global.mdc"

if [ -f "$global_src" ]; then
    write_rule "$global_dst" \
        "AI Workflow — global coding workflow and conventions" \
        "true" \
        "$(cat "$global_src")"
    info "Written $global_dst"
else
    warn "dotfiles/CLAUDE.md not found at $global_src — skipping global rule"
fi

# 2. One rule per skill ---------------------------------------------------------
# Remove stale skill rules first, so a skill that was removed from the repo
# does not linger as a rule from a previous install.
for old in "$CURSOR_RULES_DIR"/aiwf-skill-*.mdc; do
    [ -f "$old" ] && rm "$old"
done

for skill_file in "$REPO_DIR"/skills/*/SKILL.md; do
    [ -f "$skill_file" ] || continue

    name="$(frontmatter_field "$skill_file" name)"
    description="$(frontmatter_field "$skill_file" description)"

    if [ -z "$name" ]; then
        warn "Skipping $skill_file — could not parse 'name' from frontmatter"
        continue
    fi

    dest="$CURSOR_RULES_DIR/aiwf-skill-${name}.mdc"
    body="$(skill_body "$skill_file")"

    write_rule "$dest" \
        "AI Workflow /${name} — ${description}" \
        "false" \
        "# /${name}

${body}"

    info "Written $dest"
done

# 3. Agent rules ----------------------------------------------------------------
for agent_file in "$REPO_DIR"/agents/*.md; do
    [ -f "$agent_file" ] || continue
    base="$(basename "$agent_file" .md)"
    dest="$CURSOR_RULES_DIR/aiwf-agent-${base}.mdc"

    write_rule "$dest" \
        "AI Workflow agent — ${base//-/ }" \
        "false" \
        "$(cat "$agent_file")"
    info "Written $dest"
done

# 4. Review guides --------------------------------------------------------------
for guide_file in "$REPO_DIR"/reviews/*.md; do
    [ -f "$guide_file" ] || continue
    base="$(basename "$guide_file" .md)"
    dest="$CURSOR_RULES_DIR/aiwf-review-${base}.mdc"

    write_rule "$dest" \
        "AI Workflow language review guide — ${base}" \
        "false" \
        "$(cat "$guide_file")"
    info "Written $dest"
done

echo ""
info "Cursor install complete."
info "Rules are in $CURSOR_RULES_DIR"
info "To use a skill, reference its name in your prompt, e.g.: 'follow the /spec workflow for feature X'"
echo ""
