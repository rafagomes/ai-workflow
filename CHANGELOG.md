# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- **Per-profile installs.** Claude Code isolates accounts through its own `CLAUDE_CONFIG_DIR`, and each profile directory carries its own `skills/`, `agents/`, `commands/` and `CLAUDE.md` — so a second profile starts with none of the toolkit. `install.sh` and `uninstall.sh` now read the `CLAUDE_DIR` override, so `CLAUDE_DIR="$HOME/.claude-work" ./install.sh` installs the skills, agents, review guides and global conventions into that profile. What it deliberately does **not** carry over is `settings.json`: account, theme, model, status line and enabled plugins are the whole reason to run separate profiles, so the primary dir gets the shared settings file and a secondary `CLAUDE_DIR` keeps its own. That decision is derived from `CLAUDE_DIR` rather than a flag, so it survives `aiwf update` and `aiwf reinstall` re-running the install; `--with-settings` and `--no-settings` force it either way. A profile-scoped `uninstall.sh` leaves `~/.local/bin/aiwf` alone, since the launcher is shared.

### Changed
- **The ≤200-line PR budget now excludes tests.** It previously read "≤200 lines of diff (tests included)", which penalised well-tested slices and created a standing incentive to thin out tests to stay under budget — the opposite of what the rule is for. The budget now counts **source lines only**; tests are written in full and never count. The budget is measured with an exclusion pathspec (`':(exclude)**/tests/**'`, `**/*_test.*`, `**/*.test.*`, `**/test_*`) rather than a raw `git diff --stat`, and `/spec` estimates in source lines when deciding whether to slice.
- **Writer/reviewer separation restated as an obligation, not a prohibition.** The global rule read "never review code in the same session that wrote it" — true, but it only says what *not* to do, and a small or test-only diff could plausibly be read as needing no review at all. It now reads **always trigger a fresh reviewer**: once an implementation is on a branch, actively spawn a reviewer with clean context (a subagent that did not write the code, or a fresh session), every time, unprompted, regardless of diff size. Paired with a second rule making **merge authority explicitly human-gated**: the default is to report findings and stop, and autonomous merging happens only when the user has said so for that specific piece of work ("autonomous", "merge if it passes"), with the authorization never carrying to the next task.
- **Status line rearchitected** into a colour-coded display that stays quiet until something needs a decision. Row 1 is identity: directory, git branch + dirty count, model, reasoning effort, `⚡` fast mode, non-default output style, the context in absolute tokens (with the window size from 80 columns), and the cost on API-key billing. Row 2 is new and is an alert rather than a dashboard: **a rate-limit window (5-hour, 7-day) is drawn only once it reaches 70% used, with a usage bar plus the local clock time the allowance resets** (from `rate_limits.*.resets_at`, which the payload provides as Unix epoch seconds) and a countdown. `CLAUDE_STATUSLINE_LIMIT_SHOW` moves that threshold; `0` always shows both windows. Bars colour green / amber / red at 70% and 90%. Adds `refreshInterval: 30` to `settings.example.json` so the countdown stays live while the session is idle — status lines are otherwise event-driven and the clock would freeze.
- Status-line **rate-limit reset stamps are no longer a bare weekday**. `Mon 05:00` reads as *this* Monday, but the 7-day window can reset up to a week out, so it was routinely wrong by days. Resets now render as `today 22:00` / `tomorrow 05:00` when that close, and the full `Mon 10 Aug 05:00` otherwise.
- **Hand-offs from the planning skills now end at "an issue with a spec, ready to be implemented".** `/spec`, `/roadmap`, `/issues`, `/new-project`, `/tdd`, `/design` and `/commit` no longer point at the retired execution skills (see **Removed**). `/issues` is the last step of the chain and suggests `/feature-dev:feature-dev implement issue #<N> per docs/specs/NNN_<name>.md` — the `feature-dev` plugin is not spec-file driven by itself, so the issue and its spec path are passed as the argument. `/commit` hands off to `gh pr create` instead of `/pr`.
- **`dotfiles/CLAUDE.md` tool names updated; the rules are unchanged.** The canonical feature flow reads `/spec` → `/issues` → implement the issue from its spec (in Claude Code: `/feature-dev:feature-dev <issue + spec path>`) → review the diff → `/commit` → push + `gh pr create` → fresh reviewer → report → merge. The merge-authorization examples drop `/autopilot` and `/factory`. The Toolkit list reflects the 13 remaining skills + `/sec-review` and names the three execution plugins. Language guides in `~/.claude/reviews/` stay installed and are described as guides to hand to a reviewer rather than "loaded on demand by `/review`, `/feature`, `/fix`".
- **The ≤200-line non-test budget is no longer measured by a skill gate.** The rule stands; `docs/TRUNK_BASED_WORKFLOW.md` now gives the exclusion pathspec (`git diff --stat main...HEAD -- . ':(exclude)**/tests/**' ':(exclude)**/*_test.*' ':(exclude)**/*.test.*' ':(exclude)**/test_*'`) as the way to measure it. The same goes for typed branch names and feature-flag wiring: they apply through the global `CLAUDE.md`, not through gates in `/feature`, `/fix` and `/pr`. The replacement plugins do not enforce them.
- `README.md` gains a **Required plugins** section; `settings.example.json` enables `feature-dev`, `pr-review-toolkit` and `superpowers` in `enabledPlugins`. `docs/REFERENCE.md` gains an `/issues` section and an **Execution (plugins)** section mapping each retired skill to its replacement.
- `install.sh` removes the retired skills' symlinks (only those pointing back into this repo) and `uninstall.sh` keeps their paths in a separate `RETIRED_SKILLS` list (removing them only when dangling), so installs made before the removal are cleaned up without touching a same-named skill from elsewhere. `adapters/cursor/install.sh` now deletes stale `aiwf-skill-*.mdc` rules before regenerating, so a removed skill no longer lingers as a Cursor rule (the Codex adapter already did this for its symlinks).

### Removed
- **BREAKING — the six execution skills are retired: `/feature`, `/fix`, `/review`, `/pr`, `/autopilot`, `/factory`.** Maintained plugins from the `claude-plugins-official` marketplace now cover them, and the toolkit keeps only the planning half (PRD → architecture → roadmap → spec → GitHub issue) plus `/design`, `/verify-design`, `/new-project`, `/commit`, the agents, `/sec-review` and the review guides. By this repo's versioning rule a breaking removal is a **major** bump at release time. Replacements:
  - `/feature` → `feature-dev` plugin, `/feature-dev:feature-dev` (guided 7-phase workflow; interactive; does not commit or open a PR).
  - `/fix` → `superpowers` plugin, `systematic-debugging` skill.
  - `/review` → `pr-review-toolkit` plugin, `/pr-review-toolkit:review-pr`.
  - `/pr` → no dedicated replacement: `gh pr create` (or ask Claude), then the reviewer above; `superpowers` also has `finishing-a-development-branch`.
  - `/autopilot`, `/factory` → `superpowers` skills `subagent-driven-development`, `executing-plans`, `dispatching-parallel-agents`. **There is no longer a one-command "run the whole roadmap/milestone and merge" pipeline in this toolkit.**
- `feature-dev` and `pr-review-toolkit` are Claude Code only (`superpowers` also ships Codex and Cursor installs), so **the Cursor and Codex adapters now install the planning skills and no execution skills**.
- **Enabling `superpowers` changes every session**: its session-start hook tells Claude to look for an applicable superpowers skill before any task, and its `brainstorming` skill overlaps `/prd` and `/spec`. `settings.example.json` enables it; remove that line if it competes with your conventions.
- `/pr-review-toolkit:review-pr` reads **uncommitted** changes, so the documented order is review → `/commit` → `git push` + `gh pr create`. A filtered install run (`./install.sh <name>`) does not prune the retired links; run it unfiltered or use `aiwf reinstall`.
- **After pulling, run:**
  1. `aiwf update` (or `git pull && ./install.sh` in a clone) — re-links Claude Code and removes the six now-dangling `~/.claude/skills/<name>/SKILL.md` symlinks. `aiwf reinstall` does the same. Repeat with `CLAUDE_DIR=<profile>` for each secondary profile.
  2. `aiwf install-cursor` and/or `aiwf install-codex` if you use them — drops the retired skills' rules/symlinks and recompiles `~/.codex/AGENTS.md`.
  3. In Claude Code: `/plugin install feature-dev@claude-plugins-official`, `/plugin install pr-review-toolkit@claude-plugins-official`, `/plugin install superpowers@claude-plugins-official`.

### Fixed
- `aiwf help` documented `CLAUDE_DIR` as "Override Claude config dir (default: ~/.claude)" and `aiwf status` honoured it, but `install.sh` and `uninstall.sh` both hardcoded `$HOME/.claude` — so `CLAUDE_DIR=... aiwf install` reported one directory and symlinked into another. Both scripts read the override now, and `aiwf` exports it so the value reaches them.
- `aiwf reinstall` silently dropped its arguments (`cmd_reinstall` ignored `"$@"`), so any filter or flag passed to it was accepted and discarded. It forwards them to the install step now.
- `aiwf uninstall` and `aiwf reinstall` no longer abort with `passthru: unbound variable` on bash 3.2 (stock macOS `/bin/bash`), where an empty array expansion trips `set -u`.
- The status line command in `settings.example.json` hardcoded `~/.claude/statusline-command.sh`, which resolves to the primary profile from every other profile. It now resolves through `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`.
- `install.sh`'s closing message hardcoded `~/.claude/` even when installing elsewhere.
- `aiwf uninstall --purge` is now refused from a secondary profile. It deleted the clone that every profile's symlinks point at, leaving the others with 29 dangling links and no launcher to repair them.
- The primary-directory comparison canonicalizes both paths, so `~/.claude/`, `~/./.claude` or a symlinked `~/.claude` no longer flip a profile between shared and isolated settings.
- `settings.example.json` pins a full model id (`claude-opus-4-8[1m]`) instead of the `opus` alias, which cannot select a context-window variant. The setup snippet in `statusline-command.sh`'s header carried the same hardcoded `~/.claude` status line path as the example did.
- Status line no longer **drops the git segment and leaks a filesystem dump to stderr on Linux**. The 3s `git status` cache probed `stat -f %m` (BSD) before `stat -c %Y` (GNU), but on GNU coreutils `-f` means `--file-system` and **exits 0** with a multi-line filesystem report, so the BSD-first probe never fell through. The garbage landed in `$(( ))`, producing an arithmetic syntax error and a bogus cache age. Probes GNU first now, with a numeric guard on the result.
- Status line no longer **silently shifts every field after an empty one**. The single jq pass emitted `@tsv` and read it with `IFS=$'\t'`; tab is IFS whitespace, so `read` collapses runs of it and any empty field (no `effort.level`, no `output_style.name`, no `model.id`) shifted all later fields left by one — rendering `false` as the effort, `total_duration_ms` as the cost, and `resets_at` as the rate-limit percentage. Fields are now joined with `U+001F` (unit separator), which is not IFS whitespace, so empty fields survive.
- Status line no longer reports a **wrong session cost**. It hand-computed cost as `(input × $3 + output × $15) / 1e6` — hardcoded Sonnet pricing applied regardless of the active model, so every Opus session was understated. Now reads `cost.total_cost_usd` straight from the payload.
- Status line no longer mislabels the working directory. It preferred `workspace.project_dir` over `cwd`; when Claude Code is launched from a parent directory `project_dir` is that parent (e.g. `$HOME`), so every project rendered under the same name. Now prefers `workspace.current_dir`.
- Status line no longer forks `jq` once per field (12+ processes per render) plus `bc`. It runs a single `jq` pass emitting one delimited record and drops the `bc` dependency, using shell arithmetic instead. Status lines re-run on every event and are cancelled if still running when the next update lands, so the process count was the difference between a live bar and a stale one.
- Status line dropped the `tasks:N` segment, which read `~/.claude/todos/<session_id>.json` — a path Claude Code no longer writes, so the segment never rendered.
- Status line is now portable across macOS and Linux for timestamp formatting (BSD `date -r` vs GNU `date -d @`), degrades by terminal width via `$COLUMNS`, honours `NO_COLOR`, caches `git status` for 3s, and always exits 0 with a fallback line rather than emitting a partial or empty status.
- Desktop notification hook in `settings.example.json` is no longer Linux-only. It hardcoded `notify-send`, which does not exist on macOS, so the hook silently did nothing there. It now prefers `notify-send` and falls back to `osascript`.

## [0.6.3] - 2026-04-23

### Fixed
- `/design` now enforces an **Implementation Fidelity Protocol** in every generated `docs/design/DESIGN_SYSTEM.md`. Problem: downstream skills (`/feature`, `/factory`, `/fix`) were reading the design system doc and implementing from the markdown + memory, producing pixel drift vs. Paper. Fix: the generated doc must now open with (a) a non-negotiable "read before writing any UI code" checklist that forces `mcp__paper__get_jsx` / `get_computed_styles` on the target node before implementation, (b) a **Paper Canvas Map** table listing every artboard + its node ID + what it covers, and (c) a `📐 Paper reference` line at the end of every component block pointing to its exact canvas location. Screenshots are explicitly demoted to lowest-trust input. The new Rule 1 in `/design` codifies this; all component templates in the doc now carry the reference line. Net effect: implementers stop eyeballing from PNGs and always resolve exact values from Paper.

## [0.6.2] - 2026-04-21

### Fixed
- `/verify-design` now documents itself as a **single-pass fidelity-fix skill**, not a review-only gate. Empirically, dispatching it as "review" then spawning a separate fix agent doubles Paper MCP and Playwright load for the same outcome — the skill is authored to mutate code and already does review + fix + re-verify in one pass. Writer/reviewer separation applies to *code-review* skills; this one is a reviewer-and-fixer, and calling it twice is a misuse. Adds a model-fit matrix for parent agents that dispatch to sub-agents (Sonnet for first-pass delta work, Haiku for re-verify against a known delta list, Opus only for from-scratch design + implementation). Direct user invocations run at the user's chosen model — no auto-downgrade for cost.

## [0.6.1] - 2026-04-20

### Fixed
- `/factory` no longer attempts `gh pr review --approve` on the PRs it opens. On a PR authored by the current user that call fails with `Can not approve your own pull request`, leaving the verdict unrecorded. It also conflicts with the skill's own "no auto-merge, ever" rule — approval is a state-changing review action that belongs to the human, not the orchestrator. Phase 5.5b now posts the factory verdict as a PR **comment** (`gh pr comment`), which is visible in the timeline, doesn't interfere with branch protection, and leaves approve/merge entirely to the human. Rule 11 is extended to "no auto-approve, ever"; the cycle-2 escalation path likewise switched from `gh pr review --request-changes` to a comment.

## [0.6.0] - 2026-04-19

### Changed
- `/factory` repositioned from "end-to-end roadmap pipeline" to **single-milestone/phase** pipeline. New required argument: `/factory <phase-name>` or `/factory --milestone <N>`. Convention: roadmap phase file `docs/roadmap/<NNN>_<name>.md` ↔ GitHub milestone titled `<NNN>_<name>` (filed by `/issues`). Source of work is now open issues in the milestone (closed = done, excluded). Bare `/factory` is rejected with a pointer to `/autopilot` for multi-phase runs. End-to-end roadmap orchestration remains `/autopilot`'s job.
- `/factory` now batches features with **file-overlap awareness** (greedy bin-packer ported from `/autopilot`): no two features in the same writer batch may touch the same file, so 10 PRs from a milestone open as 2-3 conflict-free batches instead of one risky batch.
- `/factory` writers no longer self-review. The previous in-context `code-review` skill call (Step 4 of the writer prompt) violated writer/reviewer separation and has been removed.

### Added
- `/factory` Phase 5.5 — **per-PR review loop** with token discipline: fresh-context sonnet reviewer per PR (parallel across PRs in the batch, no worktree, bounded scope = diff + spec + ≤3 files), structured `VERDICT: PASS | FIX_REQUIRED` output. On `FIX_REQUIRED`, the **writer agent is resumed via `SendMessage`** (warm context — re-spawning a fresh fixer would re-pay the spec/files read cost) with the action items only, fixes, re-pushes; reviewer re-runs on the new diff only. Hard cap of 2 fix cycles, then escalates to PR comment as `NEEDS_HUMAN`. Spec-ambiguity is auto-detected when the same finding survives a cycle. Final verdict posted to the PR via `gh pr review`. **No auto-merge** — factory stops with PRs open and reviewed for human merge.
- `/feature` Step 6 rewritten with the same fresh-context reviewer + warm-fixer + 2-cycle pattern. The previous "self-review (parallel)" branch that ran the in-context `code-review` skill is gone — skills run in the writer's session, which defeats writer/reviewer separation. Reviewer always runs as a separate `Agent` call with cold context.
- Project `CLAUDE.md` rule: any change to a skill, workflow, or convention must update the relevant docs (README, REFERENCE.md, CHANGELOG, WORKFLOW.md) in the same change.

## [0.5.8] - 2026-04-19

### Changed
- `/feature #<N>` now resolves directly from a GitHub issue number: fetches the issue via `gh issue view` or GitHub MCP, scans `docs/specs/` for a matching `Issue: #<N>` field, and proceeds with that spec. If no spec is linked, treats the issue title/body as the feature description and asks whether to spec first or build inline.

## [0.5.7] - 2026-04-19

### Changed
- `/feature` gains `--commit` and `--pr` flags for hands-free finishing. `--commit` auto-commits using `/commit`'s grouping logic but skips plan presentation — outputs only `git log --oneline -N`. `--pr` implies `--commit` and also pushes + opens a PR without draft presentation — outputs only the log lines and PR URL. All other output is suppressed when either flag is active. Intended for use in orchestrated flows or when the user trusts the implementation enough to skip the intermediate review step.

## [0.5.6] - 2026-04-18

### Fixed
- `/rlabs-design` — surface-specific kit loading is now mandatory (slides → `slides/index.html`; website → all `ui_kits/website/` components; app → all `ui_kits/app/` components), and `assets/` + `preview/` specimen files are enumerated as first-class references rather than buried under "explore the other available files". Reading only `colors_and_type.css`/`tokens.css` was producing off-brand output because tokens alone don't convey component composition or spacing rhythm.
- `/rlabs-design` — Playwright fidelity check is now required after applying the design: screenshot the matching reference `index.html` and the output at 1440×900 (and 390×844 if mobile in scope), compare against an explicit brand-rule checklist (typography, palette, radii, spacing, borders, motion, copy), fix drift in place, then report. Falls back to a stated manual check if Playwright is unavailable rather than silently skipping verification.

## [0.5.5] - 2026-04-18

### Fixed
- `/spec` — collapsed the three restatements of the `NNN`-prefix rule (Hard Requirements, Spec Numbering, Slice section) into one **Spec Numbering & Path** section, and the two copies of the trunk-metadata field definitions (Slices table columns + single-file `## Trunk Metadata` block) into one shared subsection. Same rules, stated once each.
- `/issues` — dependency references in issue bodies now use `{{issue:<slice-id>}}` placeholders during creation and get rewritten to real `#N` values in a second pass once the `slice-id → #N` mapping is known. Writing raw `#001`, `#002` during creation auto-linked those tokens to whatever issues already existed in the repo (issue #1, #2, …), silently producing wrong cross-references. The per-milestone loop now runs pass 2 before writing back to source spec files so downstream references use final issue numbers.

## [0.5.4] - 2026-04-18

### Fixed
- `/spec` now prefixes every spec with a zero-padded `NNN` that mirrors the roadmap phase number (`docs/specs/002_jira-sync.md`), with `.A`/`.B` letter suffixes when a phase has multiple specs. Sliced specs use the directory form `docs/specs/NNN_<feature>/` with `README.md` + `MMM_<slice>.md` inside — the directory itself is how "sliced" is identified, no extra marker. Previously spec filenames carried no ordering signal, so reading `docs/specs/` gave no hint which came first or how specs mapped back to roadmap phases. `/roadmap`, `/feature`, and `/issues` updated to reference the new prefixed paths.

## [0.5.3] - 2026-04-18

### Fixed
- `/feature` and `/fix` no longer commit, push, or open PRs — both stop after implementation, verification, and self-review with a structured report (files changed, lint/typecheck/test tail, security verdict, slice metadata, suggested commit subjects). The previous `--pr` flag and auto-commit step quietly turned every run into a shipped PR before the user had a chance to read the diff; the user reviews the working tree, then ships via `/commit` + `/pr`. Orchestrators (`/autopilot`, `/factory`) keep their auto-commit/PR behavior — that is where it earns its keep.
- `/feature` `Asking the user questions` rule now requires the `AskUserQuestion` tool for every mid-flight decision (missing spec, slice-size override, split shape, ambiguous metadata) — free-text prompts were ambiguous to parse and easy to skip.

### Changed
- Canonical feature flow in `CLAUDE.md` now reads: `/spec → (slice if >200 lines) → /issues → /feature <spec> → review the diff → /commit → /pr → /review → merge → cleanup`.
- `docs/TRUNK_BASED_WORKFLOW.md` and `docs/REFERENCE.md` recipes updated to drop `--pr` from `/feature` and `/fix`.

## [0.5.2] - 2026-04-18

### Fixed
- `/issues` now uses the `AskUserQuestion` tool for every interactive decision — drift/gone reconciliation, dry-run confirmation, roadmap-index horizon, and the per-milestone "proceed to next phase?" loop. Free-text confirmations were easy to miss and ambiguous to parse ("ok", "sure", "go"); structured options make each decision one click with an explicit recommended default, and batch the horizon + dry-run prompts into a single call on roadmap-index runs.

## [0.5.1] - 2026-04-18

### Added
- `/issues` — **two-milestone horizon** as the default pacing recommendation for roadmap-index inputs. The skill now proposes filing only the current phase + the next phase (not the entire roadmap), names the phases it's skipping, and asks before filing more. Rolling forward is idempotent: re-running advances the window once phases complete. This is the team practice that translates cleanly to solo work — it gives team discipline (issue-per-PR, milestone-scoped) without team overhead (stale labels, quarter-long backlogs, triage meetings).

### Changed
- `/issues` "After writing" guidance now reinforces the horizon: when the current phase is roughly halfway done, re-run to file the next-next phase.

## [0.5.0] - 2026-04-18

### Added
- `/issues` skill — files GitHub milestones (one per phase) and issues (one per task/slice) from `docs/roadmap/*.md` and `docs/specs/*.md`. Polymorphic input: a roadmap index, a single phase, a sliced spec's `README.md`, or a single-file spec. Uses the GitHub MCP as the primary transport with `gh` CLI as a fallback. Per-milestone confirmation loop keeps broken runs recoverable. Writes issue numbers back into the source Markdown so `/feature` can derive branch names.
- Label taxonomy bootstrapped on first `/issues` run: `type:feat|fix|refactor|chore|test|docs|perf|security`, `complexity:low|med|high`, `mvp|post-mvp`, `needs-spec|spec-ready|blocked`, each with a default color.

### Changed
- `/spec` now emits a trunk-aware Slices table with `Type`, `Flag`, `Depends on`, `Complexity`, and `Issue` columns — the table is the source of truth for `/issues`. Single-file specs get a `## Trunk Metadata` block with the same fields so `/issues` can file them too.
- `/roadmap` tasks now carry `Type`, `Feature flag`, `Milestone`, and `Issues` fields. `complexity:high` tasks must point at a sliced directory-form spec (one PR per slice). Phase template gains a `## Trunk Alignment` section naming flags and shipping state.
- `/feature` derives branch names from the spec's `Issue` field — canonical form is `<type>/<issue-number>-<slug>` (e.g., `feat/42-jira-sync`). Falls back to `<type>/<slug>` when no issue is filed yet. PR body now requires `Closes #<N>` and a `Feature flag` line matching the spec.
- Canonical feature flow in `CLAUDE.md` now reads: `/spec → (slice if >200 lines) → /issues → /feature <spec> --pr → /review → merge → cleanup`.

## [0.4.0] - 2026-04-18

### Added
- `docs/TRUNK_BASED_WORKFLOW.md` — full guide explaining the shift from Git Flow to trunk-based development, why it fits AI-assisted work, the seven rules, skill-enforcement table, recipes, and FAQ.
- `Trunk-Based Workflow` section in global `CLAUDE.md` codifying branch naming (`feat/*`, `fix/*`, `refactor/*`, `docs/*`, `chore/*`, `test/*`, `perf/*`, `security/*`), short-lived branches, ≤200-line slices, feature-flag expectations, worktree placement, and delete-after-merge.
- Slicing step in `/spec`: when a feature is estimated >200 lines, produces sub-specs under `docs/specs/<feature>/NNN_<slice>.md` with an index `README.md` and per-slice feature-flag section.
- `## Feature Flag` section in the single-file spec template.
- Branch precondition + slice-size gate in `/feature` and `/fix` (blocks commits when `git diff --stat` exceeds ~200 lines; requires explicit user override).
- Branch-name validation, diff-size warning, and post-merge cleanup reminder in `/pr`.

### Changed
- `PR Structure` in `CLAUDE.md` now cross-references the new Trunk-Based Workflow section for slicing and feature-flag rules.
- `docs/REFERENCE.md` overview now points at `TRUNK_BASED_WORKFLOW.md` alongside `WORKFLOW.md`.

## [0.3.0] - 2026-04-18

### Added
- `extras/` opt-in tree with `--extra` flag on `install.sh` for personal add-ons that stay outside the core workflow.
- `/rlabs-design` as the first extra — personal brand design system (tokens, typography, assets, UI kits, preview cards). Installed only when `./install.sh --extra` is passed.

### Changed
- Project-wide docs moved from `docs/specs/` to `docs/` root: `ARCHITECTURE.md`, `TECHNICAL_DESIGN_DOCUMENT.md`, and `THREAT_MODEL.md`. `docs/specs/` is now reserved for individual feature specs only.
- All skill references updated accordingly across `architecture`, `tdd`, `security`, `adr`, `rfc`, `spec`, `roadmap`, `design`, `autopilot`, `feature`, `fix`, `review` skills, plus `README.md` and `docs/REFERENCE.md`.

## [0.2.0] - 2026-04-15

### Added
- Multi-platform support: Cursor and OpenAI Codex CLI adapters alongside Claude Code (`aiwf install-cursor`, `aiwf install-codex`, `aiwf install-all`).
- `/design` skill for producing distinctive, production-grade UI designs via the Paper.design MCP, including multi-hue palette and accessibility guidance.
- `/verify-design` skill — diffs the running UI against Paper refs with Playwright and fixes mismatches in place.
- `/factory` skill — end-to-end delivery pipeline that reads the roadmap, generates specs, and runs parallel `/feature` agents.
- `/commit` and `/pr` skills for splitting the working tree into logical conventional commits and opening pull requests.
- Roadmap skill now requires an MVP boundary in every full roadmap and numbers phase files with a `001_` prefix.
- Verification, UI work, file convention, and git workflow sections added to the global `CLAUDE.md`.

### Changed
- `/feature` skill rewritten (v2) with benchmark-driven trims.
- `/design` skill pushed toward distinctive aesthetic commitments.
- Skill descriptions polished, guardrails reframed, and model guidance added across the suite.
- Enabled 8 additional `claude-plugins-official` plugins in `settings.json`.
- `WORKFLOW.md` and `REFERENCE.md` moved under `docs/`.

### Deprecated
- In-repo `/code-review` skill deprecated in favor of Anthropic's official `code-review` skill from `claude-code-plugins` (benchmark showed no detection lift at ~1.5× the cost). Language-specific review guides in `reviews/` remain in use by `/review`, `/feature`, and `/fix`.

### Fixed
- Codex adapter: install skills as native Codex skills under `~/.agents/skills/aiwf-*/`, write `AGENTS.md` (not `instructions.md`), and raise `project_doc_max_bytes` so `AGENTS.md` is not truncated.

### Documentation
- README and `REFERENCE.md` updated for multi-platform support.
- References refreshed for `/design`, `/verify-design`, and `/factory`; review-layer diagram fixed.
- Bare `code-review` references disambiguated as Anthropic's skill.
- Codex invocation clarified as `$<name>` with symlink layout documented.

## [0.1.0] - 2026-04-11

Initial tagged release: full SDLC toolkit for AI-assisted coding — skills, agents, review guides, hooks, and the `aiwf` launcher for Claude Code.

[Unreleased]: https://github.com/0xrafasec/ai-workflow/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/0xrafasec/ai-workflow/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/0xrafasec/ai-workflow/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/0xrafasec/ai-workflow/releases/tag/v0.1.0
