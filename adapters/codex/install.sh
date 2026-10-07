#!/usr/bin/env bash
set -euo pipefail

# AI Workflow — Codex Adapter Installer
#
# Installs aiwf for OpenAI Codex CLI in two parts:
#
#   1. Skills — each skills/<name>/ is symlinked as a native Codex skill at
#      ~/.agents/skills/aiwf-<name>/. The directory uses an aiwf- prefix to
#      avoid colliding with other skill sources, but Codex invokes by the
#      `name:` field inside SKILL.md, so users type `$<name>` at the prompt
#      (e.g. `$spec`, `$roadmap`). Codex also matches implicitly on the
#      description. Reference: https://developers.openai.com/codex/skills
#
#   2. Global context — ~/.codex/AGENTS.md is compiled with the small bits
#      that aren't skills (global workflow conventions + agent definitions +
#      language review guides). This file is kept well under Codex's
#      32 KiB default `project_doc_max_bytes` cap so nothing gets truncated.
#
# Older versions of this adapter compiled every skill into a ~174 KiB
# AGENTS.md, most of which Codex silently dropped. The symlink-as-skill
# layout matches how spec-kit and other toolkits integrate with Codex.
#
# Usage:
#   ./adapters/codex/install.sh
#   CODEX_DIR=<path>  ./adapters/codex/install.sh   # override ~/.codex
#   AGENTS_DIR=<path> ./adapters/codex/install.sh   # override ~/.agents

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CODEX_DIR="${CODEX_DIR:-$HOME/.codex}"
AGENTS_DIR="${AGENTS_DIR:-$HOME/.agents}"
SKILLS_DIR="$AGENTS_DIR/skills"
OUT_FILE="$CODEX_DIR/AGENTS.md"
LEGACY_FILE="$CODEX_DIR/instructions.md"
SKILL_PREFIX="aiwf-"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $1"; }
warn()  { echo -e "${YELLOW}[!]${NC} $1"; }
error() { echo -e "${RED}[x]${NC} $1" >&2; }

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

echo ""
echo "=== AI Workflow — Codex Installer ==="
echo ""

mkdir -p "$CODEX_DIR" "$SKILLS_DIR"

# --- 1. Install skills as native Codex skills --------------------------------

info "Installing skills into $SKILLS_DIR"

# Remove stale aiwf-* skill links from previous installs.
if compgen -G "$SKILLS_DIR/${SKILL_PREFIX}*" > /dev/null; then
    for old in "$SKILLS_DIR/${SKILL_PREFIX}"*; do
        [ -L "$old" ] && rm "$old"
    done
fi

skill_count=0
for skill_src in "$REPO_DIR"/skills/*/; do
    [ -d "$skill_src" ] || continue
    [ -f "$skill_src/SKILL.md" ] || continue
    name="$(basename "$skill_src")"
    # Rewrite the skill name in the symlinked SKILL.md via a wrapper dir? No —
    # Codex reads `name:` from the file itself. We symlink the dir so edits in
    # the repo propagate. The skill's declared name stays as-is (e.g. "spec"),
    # but the directory is prefixed aiwf- so `$aiwf-spec` works at the prompt.
    link="$SKILLS_DIR/${SKILL_PREFIX}${name}"
    ln -sfn "$skill_src" "$link"
    skill_count=$((skill_count + 1))
done
info "Linked $skill_count skills under ${SKILL_PREFIX}* — invoke via \$<name> (e.g. \$spec, \$roadmap)"

# --- 2. Drop legacy compiled file if it was ours -----------------------------

if [ -f "$LEGACY_FILE" ] && grep -q "aiwf — AI Workflow" "$LEGACY_FILE" 2>/dev/null; then
    warn "Removing legacy $LEGACY_FILE (migrated to AGENTS.md + native skills)"
    rm "$LEGACY_FILE"
fi

# --- 3. Build a lean AGENTS.md with global context only ----------------------

if [ -f "$OUT_FILE" ] && ! grep -q "aiwf — AI Workflow" "$OUT_FILE" 2>/dev/null; then
    backup="${OUT_FILE}.bak.$(date +%s)"
    warn "Backing up existing $OUT_FILE -> $backup"
    cp "$OUT_FILE" "$backup"
fi

{
    printf '<!-- aiwf — AI Workflow compiled instructions — do not edit by hand -->\n'
    printf '<!-- Regenerate with: aiwf install-codex  or  ./adapters/codex/install.sh -->\n\n'

    # Global workflow conventions (strip the Claude-specific Toolkit section).
    # Source is the global file under dotfiles/, not the project-specific
    # CLAUDE.md at the repo root (which is for working in the ai-workflow repo).
    printf '# Global Workflow Conventions\n\n'
    if [ -f "$REPO_DIR/dotfiles/CLAUDE.md" ]; then
        awk '
            /^## Toolkit \(ai-workflow repo\)/ { skip=1; next }
            skip && /^## / { skip=0 }
            !skip { print }
        ' "$REPO_DIR/dotfiles/CLAUDE.md"
    fi
    printf '\n'

    # Skills index — tell Codex the workflows exist and how to invoke them.
    # The skill bodies themselves live in ~/.agents/skills/, not here.
    printf '%s\n\n# Available Workflow Skills\n\n' "---"
    printf 'These workflows are installed as native Codex skills under\n'
    printf '`~/.agents/skills/%s<name>/` (the directory uses an %s prefix\n' "$SKILL_PREFIX" "$SKILL_PREFIX"
    printf 'to avoid collisions; Codex invokes by the skill `name` field).\n'
    printf 'Invoke with `$<name>` or by describing the task.\n\n'

    for skill_file in "$REPO_DIR"/skills/*/SKILL.md; do
        [ -f "$skill_file" ] || continue
        name="$(frontmatter_field "$skill_file" name)"
        description="$(frontmatter_field "$skill_file" description)"
        [ -z "$name" ] && continue
        echo "- **\$${name}** — ${description}"
    done
    printf '\n'

    # Agent definitions — small enough to keep inline.
    printf '%s\n\n# Agent Definitions\n\n' "---"
    for agent_file in "$REPO_DIR"/agents/*.md; do
        [ -f "$agent_file" ] || continue
        base="$(basename "$agent_file" .md)"
        printf '## %s\n\n' "${base//-/ }"
        cat "$agent_file"
        printf '\n%s\n\n' "---"
    done

    # Language review guides — appendix to hand to a reviewer as stack criteria
    # (e.g. Anthropic's official code-review skill).
    printf '# Language Review Guides\n\n'
    for guide_file in "$REPO_DIR"/reviews/*.md; do
        [ -f "$guide_file" ] || continue
        base="$(basename "$guide_file" .md)"
        printf '## %s\n\n' "$base"
        cat "$guide_file"
        printf '\n%s\n\n' "---"
    done
} > "$OUT_FILE"

bytes=$(wc -c < "$OUT_FILE")
info "Written $OUT_FILE ($(wc -l < "$OUT_FILE") lines, $bytes bytes)"

# --- 4. Ensure project_doc_max_bytes can fit AGENTS.md -----------------------

# Codex caps AGENTS.md reads at 32 KiB by default. Our lean AGENTS.md is
# typically ~35 KiB (global conventions + agents + review guides), so nudge
# the cap to 64 KiB when needed. Only touches config.toml if the current
# value is too low.
CONFIG_FILE="$CODEX_DIR/config.toml"
needed=$(( ((bytes + 65535) / 65536) * 65536 + 65536 ))
[ "$needed" -lt 65536 ] && needed=65536

touch "$CONFIG_FILE"
if grep -qE '^[[:space:]]*project_doc_max_bytes[[:space:]]*=' "$CONFIG_FILE"; then
    current=$(grep -E '^[[:space:]]*project_doc_max_bytes[[:space:]]*=' "$CONFIG_FILE" \
              | head -1 | sed -E 's/.*=[[:space:]]*([0-9]+).*/\1/')
    if [ "${current:-0}" -lt "$needed" ]; then
        sed -i -E "s|^[[:space:]]*project_doc_max_bytes[[:space:]]*=.*|project_doc_max_bytes = $needed|" "$CONFIG_FILE"
        info "Raised project_doc_max_bytes: $current -> $needed in $CONFIG_FILE"
    else
        info "project_doc_max_bytes already $current (>= $needed) in $CONFIG_FILE"
    fi
else
    tmp="$(mktemp)"
    {
        echo "project_doc_max_bytes = $needed"
        cat "$CONFIG_FILE"
    } > "$tmp"
    mv "$tmp" "$CONFIG_FILE"
    info "Set project_doc_max_bytes = $needed in $CONFIG_FILE"
fi

echo ""
info "Codex install complete."
info "Skills: $SKILLS_DIR/${SKILL_PREFIX}* (invoke as \$<name>, e.g. \$spec)"
info "Global context: $OUT_FILE"
echo ""
