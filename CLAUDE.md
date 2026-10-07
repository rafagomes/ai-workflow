# ai-workflow — Project-Specific Instructions

These rules apply **only when working inside the `ai-workflow` repo**. The global Claude defaults live at `dotfiles/CLAUDE.md` (symlinked to `~/.claude/CLAUDE.md` by `install.sh`) and apply to every project.

## Repo layout

This repo is the source of truth for everything installed under `~/.claude/`:

- `dotfiles/CLAUDE.md` — global defaults, symlinked to `~/.claude/CLAUDE.md`
- `CLAUDE.md` (this file) — project-specific rules, loaded only when `cwd` is this repo
- `skills/<name>/SKILL.md` — slash-command skills, symlinked into `~/.claude/skills/`
- `agents/`, `commands/`, `reviews/`, `settings.json` — symlinked similarly via `install.sh`
- `adapters/codex/`, `adapters/cursor/` — compile the skills + global CLAUDE.md into formats those tools understand
- `extras/` — opt-in personal skills, only installed via `./install.sh --extra`

## Editing rules

- **Edit the source in this repo, never the symlink in `~/.claude/`.** Edits to `~/.claude/<thing>` will either be lost on the next `install.sh` run or break the symlink. If you find yourself reading from `~/.claude/...` to make a change, stop and re-open the matching file in this repo.
- **Re-run `install.sh` after adding, removing, or renaming any skill, agent, or command.** Editing existing files in place is fine — symlinks already point at them. Only the directory shape changes need a re-link.

## Docs are part of the change — never ship a behavior change without doc updates

Any change to a skill, workflow, convention, or installer **must** update the relevant docs in the same change. Docs are not a follow-up. They are part of the change.

When you change something in this list (left), update the docs on the right in the same commit/PR:

| Change | Update |
|--------|--------|
| Skill behavior, args, or removal/rename | `skills/<name>/SKILL.md` (the source), `docs/REFERENCE.md` skill section, `README.md` Skills table + tree, `CHANGELOG.md` |
| Workflow convention (trunk rules, commit style, etc.) | `dotfiles/CLAUDE.md`, `docs/WORKFLOW.md`, `docs/TRUNK_BASED_WORKFLOW.md`, `CHANGELOG.md` |
| Adding/removing a skill | `install.sh`, `uninstall.sh`, `README.md` "Available skills" list, `dotfiles/CLAUDE.md` "Toolkit" section, adapters (codex/cursor), `CHANGELOG.md` |
| Installer or symlink layout | `install.sh`, `uninstall.sh`, adapters, `README.md` install section, `docs/REFERENCE.md` layout section, `CHANGELOG.md` |
| New or repurposed top-level convention file | `README.md` repo-tree section, `docs/REFERENCE.md` layout section |

If you're not sure whether a change is doc-relevant, it is. Default to updating docs. The cost of a stale doc is much higher than the cost of a one-line CHANGELOG entry.

## Versioning + releases

- Version lives in `CHANGELOG.md` only — no `package.json`, `VERSION` file, or other source of truth.
- Bump via SemVer:
  - **patch** (`0.x.y` → `0.x.y+1`) — doc-only, typo, or internal cleanup with no behavior change
  - **minor** (`0.x.y` → `0.x+1.0`) — new skill, new flag, repositioned skill, new convention, anything users can observe
  - **major** (`0.x.y` → `1.0.0`) — breaking removal/rename of a skill, flag, or convention users may depend on
- On bump: rename `[Unreleased]` → `[<version>] - <YYYY-MM-DD>`, leave a fresh empty `[Unreleased]` above it, commit, tag `v<version>`, push tag.

## Commit + PR style for this repo

- Conventional commits per global rule (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`, `security:`).
- Skill changes: `feat(skill-name): ...` or `fix(skill-name): ...`. Doc-only: `docs: ...`.
- Splitting commits by concern is especially important here because skill, doc, installer, and adapter edits often land together — keep each commit independently revertible.

## Testing changes locally

- After editing a skill: in any project, invoke the slash command (e.g., `/spec`) — Claude reads from `~/.claude/skills/<name>/SKILL.md`, which is the symlink to your edit.
- After editing `install.sh` or `uninstall.sh`: run them in a throwaway shell and verify the symlinks land where expected.
- After editing adapters: re-run the matching `aiwf install-codex` / `aiwf install-cursor` and check the generated output.

## When in doubt, ask

If a change touches multiple skills or shifts a convention, surface the plan before editing — don't make wide changes in one shot without confirmation.
