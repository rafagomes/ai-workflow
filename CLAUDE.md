# ai-workflow — Project-Specific Instructions

These rules apply **only when working inside the `ai-workflow` repo**. The global Claude defaults live at `dotfiles/CLAUDE.md` (symlinked to `~/.claude/CLAUDE.md` by `install.sh`) and apply to every project.

## Repo layout

This repo is two things: the `wf` Claude Code plugin, and the personal config files a plugin cannot carry.

- `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` — the plugin manifest and the marketplace that serves it
- `skills/<name>/SKILL.md` — the plugin's skills, invoked as `/wf:<name>`
- `agents/reviewer.md` — the plugin's reviewer agent (`wf:reviewer`)
- `hooks/hooks.json`, `hooks/guard.sh` — the plugin's guardrail hook (PreToolUse on Bash); tested by `tests/hooks_test.sh`
- `dotfiles/CLAUDE.md` — global defaults, symlinked to `~/.claude/CLAUDE.md` by `install.sh`
- `settings.json` — your untracked settings, symlinked into `~/.claude/` by `install.sh`
- `CLAUDE.md` (this file) — project-specific rules, loaded only when `cwd` is this repo
- `extras/` — opt-in personal skills, only installed via `./install.sh --extra`
- `tests/` — CI checks that run offline: `install_test.sh` (installer and uninstaller) and `check_links.py` (Markdown links and anchors)
- `.github/` — `workflows/ci.yml` (free-only CI), issue templates and the PR template
- `docs/` — the trunk-based workflow guide and the skill-quality notes

## Editing rules

- **Edit the source in this repo, never an installed copy.** The plugin is installed into Claude Code's plugin cache and the dotfiles are symlinks; an edit made under `~/.claude/` is either lost on the next update or silently changes this repo.
- **Skills cross-reference each other by their namespaced name** (`/wf:pr`, `wf:reviewer`). Keep that form when adding a reference.
- **Run `claude plugin validate .` after adding, removing, or renaming a skill or agent**, or touching either manifest.

## Docs are part of the change — never ship a behavior change without doc updates

Any change to a skill, workflow, convention, or installer **must** update the relevant docs in the same change. Docs are not a follow-up. They are part of the change.

When you change something in this list (left), update the docs on the right in the same commit/PR:

| Change | Update |
|--------|--------|
| Skill behavior, args, or removal/rename | `skills/<name>/SKILL.md` (the source), `README.md` Skills table + tree, `CHANGELOG.md` |
| Workflow convention (trunk rules, commit style, etc.) | `dotfiles/CLAUDE.md`, `docs/TRUNK_BASED_WORKFLOW.md`, `CHANGELOG.md` |
| Adding/removing a skill | `README.md` Skills tables, `dotfiles/CLAUDE.md` "Toolkit" section, `.claude-plugin/marketplace.json` description if the count changes, `CHANGELOG.md` |
| Plugin manifests, installer or symlink layout | `install.sh`, `uninstall.sh`, `README.md` install section + tree, `CHANGELOG.md` |
| CI or test change (`tests/`, `.github/workflows/`) | `CONTRIBUTING.md` CI section, `CHANGELOG.md` |
| New or repurposed top-level convention file | `README.md` repo-tree section |

If you're not sure whether a change is doc-relevant, it is. Default to updating docs. The cost of a stale doc is much higher than the cost of a one-line CHANGELOG entry.

## Versioning + releases

- Version lives in `CHANGELOG.md` only — no `package.json`, `VERSION` file, or other source of truth. `plugin.json` deliberately has no `version`, so installed copies track the repository's commits.
- Bump via SemVer:
  - **patch** (`0.x.y` → `0.x.y+1`) — doc-only, typo, or internal cleanup with no behavior change
  - **minor** (`0.x.y` → `0.x+1.0`) — new skill, new flag, repositioned skill, new convention, anything users can observe
  - **major** (`0.x.y` → `1.0.0`) — breaking removal/rename of a skill, flag, or convention users may depend on
- `main` is branch-protected (PR required, CI required, linear history), so a release is a PR: open `chore: release <version>` renaming `[Unreleased]` → `[<version>] - <YYYY-MM-DD>` with a fresh empty `[Unreleased]` above it (CHANGELOG only: T0, review skipped), merge it, then tag the merge commit `v<version>` on `main` and push the tag.

## Commit + PR style for this repo

- Conventional commits per global rule (`feat:`, `fix:`, `refactor:`, `chore:`, `docs:`, `test:`, `perf:`, `build:`, `ci:`, `security:`).
- Skill changes: `feat(skill-name): ...` or `fix(skill-name): ...`. Doc-only: `docs: ...`.
- Splitting commits by concern is especially important here because skill, doc, and installer edits often land together — keep each commit independently revertible.
- The PR body follows the template in `.github/PULL_REQUEST_TEMPLATE.md`, including `## Risk` (tier per the global Risk tiers). Text that instructs an agent (a skill, the agent, a `CLAUDE.md`) is never T0.

## Testing changes locally

- After editing a skill or the agent: start a session with the working tree loaded as the plugin — `claude --plugin-dir .` — and invoke it (e.g., `/wf:autopilot --dry-run`).
- After changing `/wf:commit`, `/wf:feature`, `/wf:fix` or `/wf:pr` (or the structure of any skill with a case in `evals/`): run that skill's evals from a plain terminal (inside an agent session the eval child may have no usable `git`, so git-based cases fail; see `docs/SKILL_QUALITY.md`), e.g. `claude plugin eval . --tag fix --scaffold --no-publish --allow-tools Bash Write Edit --max-cost-usd 5`. Evals call a model on your own account, so they are local and opt-in and never run in CI; see `docs/SKILL_QUALITY.md` for when to run them, how to read the result and how to add a case.
- After editing `hooks/`: `bash tests/hooks_test.sh`, and break the rule you changed to see a test fail.
- After editing a manifest, or adding or renaming a skill: `claude plugin validate .`.
- After editing `install.sh` or `uninstall.sh`: run them against a throwaway `CLAUDE_DIR` and verify the symlinks land where expected.
- Before every push, run the CI checks locally (no secrets or network needed except for `validate`'s CLI):
  - `claude plugin validate .`
  - `git ls-files -z '*.sh' | xargs -0 shellcheck`
  - `bash tests/install_test.sh`
  - `python3 -I tests/check_links.py`

## When in doubt, ask

If a change touches multiple skills or shifts a convention, surface the plan before editing — don't make wide changes in one shot without confirmation.
