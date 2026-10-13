# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- The global `CLAUDE.md` has a `Language` section: everything a session creates (docs, code, comments, identifiers, commit messages, PR titles and bodies, issues, config) is in English whatever language the user is speaking, until they explicitly say otherwise for that piece of work, while chat replies follow the language of the user's message. A session spoken to in another language had written a PRD in that language.
- The global `CLAUDE.md` makes the `wf` workflow the default path for implementing a spec: `/feature` for one task, and for a phase or roadmap `/autopilot`, which only the user can start, so a session asks for it to be typed. When asked to deliver several tasks without it, a session orchestrates by hand under dispatch rules now stated there: writers on Sonnet in isolated worktrees, `wf:reviewer` on Opus once per PR, the security gate on Opus with `HIGH` and `MED` blocking, the same writer resumed for at most two fix rounds per PR in total, and no merge authority unless the user gave it. A session that rebuilt the loop by hand had no rules in context and ran every writer on the orchestrator's model.
- `/roadmap` asks, in its interview, whether to file GitHub milestones and issues when the roadmap is settled. On Yes it hands off to `/issues` at the end, and only when the roadmap and spec files in the working tree are identical to the trunk branch on the remote; otherwise (uncommitted, unpushed, on a branch or in an open PR) it prints the command to run after the merge. `/issues` keeps its own dry-run and confirmation, and stays the way to file issues for an existing roadmap, phase or spec. The question is skipped when there is no GitHub remote, and a run that cannot ask the user files nothing.

### Changed
- **Fewer review rounds per PR.** A project delivered with hand-run orchestration took three to seven review passes per PR: fix rounds bundled `LOW` fixes that introduced new defects, every re-review was a second full review that found something else, and writers' tests could not fail (uniform fixtures, tests that passed with the behaviour removed). Now, in the global `CLAUDE.md`, `/pr`, `/autopilot` and the `reviewer` agent: a fix round changes only what the `HIGH` and `MED` findings require, with a test that fails without each fix where the suite can test it, and a full suite run; `LOW` findings are listed and never fixed in a fix round (they were "fixed or listed"); the first review is the full one and a re-review is narrow — the reviewer now returns `REVIEWED_AT`, the dispatcher passes it back as `Reviewed at: <sha>`, and the re-review confirms the previous findings and reads the fix commits (one by one after a merge of the base or a rebase). What the fix commits broke blocks as before, wherever it shows; a defect that was already there blocks only when `HIGH` and is otherwise listed as `[LOW] outside the fix (MED): …`. The security gate's fixes go through the same narrow re-review, the `LOW` findings of every round reach the final PR comment, and a PR allowed past two rounds gets only narrow checks. `/feature`, the `/autopilot` writer template and the global `CLAUDE.md` require varied test data and seeing each new test fail with its behaviour removed, before the first review.
- **The `reviewer` agent runs on Opus** (`model: opus`; it was `sonnet`). The standard is now written down in `/autopilot`: orchestrator, reviewer and security gate on Opus, dispatched writers on Sonnet. `/autopilot` dispatches the reviewer without a `model` override and the security gate with `model: "opus"`. A Sonnet reviewer had passed PRs in which a separate security audit then found issues that mattered.
- **The security gate takes back `HIGH` and `MED` findings**, not only `HIGH`. In `/autopilot` both block the merge and go to the writer; in `/pr` both keep the PR a draft and are fixed, after which the reviewer and `/security-review` run again; the global `CLAUDE.md` says the same. `LOW` findings are listed. The findings the gate had been dropping were `MED` ones worth blocking on (a resource-exhaustion flood, a test script able to delete the repository).
- **Reviewer and security fixes share one budget of two fix cycles per PR**, not two each, in `/autopilot`, `/pr` and the global `CLAUDE.md`. A `HIGH` or `MED` security finding left after it is `NEEDS_HUMAN`: `/pr` leaves the PR a draft, `/autopilot` parks the task and halts only if later tasks depend on it.
- **One list of what triggers the security review**, in `/autopilot`, `/pr`, `/fix` and the global `CLAUDE.md`: a trust boundary, auth, crypto, input parsing, secrets, permissions, dependencies, or anything that runs automatically. Each had a different subset.

### Fixed
- `build` and `ci` are valid task types everywhere a type is listed (`/roadmap`, `/spec`, `/feature`, `/issues`, `/pr`, and the branch names in the global `CLAUDE.md` and the trunk guide), matching the commit types that already allowed them. `/issues` creates `type:build` and `type:ci` labels; before, a roadmap task of either type had no label colour to create.
- `/issues` says how to write a dependency on a whole phase (`Needs all of <milestone title>.`) and one that is not a task (`Also needs: <text>.`), in the issue body template and in the drift check of a re-run, instead of leaving it to the run.

## [1.1.1] - 2026-10-11

Fixes for defects the review of 1.1.0 found after it shipped, and the 1.1.0 notes it was missing.

### Fixed
- The size gate in `/feature` and `/fix` compared `origin/<base>...HEAD`, which ignores uncommitted work — and both skills stop at the working tree, so it measured nothing. It now diffs the working tree against the merge base and counts untracked source files.
- `/pr`, re-run on a branch that already has an open PR, was told to continue at the step after the reviewer dispatch, which skipped the review.
- The `reviewer` agent diffed against the local base branch when `/pr` dispatched it, so a stale local trunk pulled merged commits into the review. It now fetches and diffs against `origin/<base>` in every case.
- The branch slug was undefined in `/feature` and defined differently in `/autopilot`, so autopilot could miss a PR opened with `/feature` and dispatch a second writer. `/feature` now defines it (the spec's file name without its prefix; for a slice, the parent's slug joined to the slice's, so same-named slices of two features cannot collide) and `/autopilot` points there.
- `/issues` let a caller's claim that "the plan is approved" stand in for the user's confirmation in a headless run. A headless run now always prints the plan and stops.
- `/issues` matches an existing milestone by its `Phase NNN` prefix and reads roadmaps written before 1.1 (`# Phase:`, `Feature flag`, `Dependencies`); the title for a standalone single-file spec is restored.
- `/commit` handles a repository with no commits when clearing the index, and no longer assumes the trunk is `main`. `/autopilot` retries once before treating a PR as having no remote checks.

### Changed
Behaviour that changed in 1.1.0 and was missing from its notes:
- `/issues` no longer applies the `spec-ready` and `blocked` labels, no longer writes a `## Branch` section into issue bodies, files issues in dependency order instead of patching `{{issue:…}}` placeholders in a second pass, and asks about the next phase only for a full roadmap.
- `/new-project` no longer generates a `security-scan` Makefile target or runs the test suite from pre-commit.
- `/commit` proposes a branch when run on the trunk branch or a detached HEAD.
- `/pr` reuses an open PR for the branch instead of trying to create another.
- `/roadmap` writes `Design reference: MISSING` for a UI task with no design source instead of stopping to ask.
- The `reviewer` agent reports a check that fails for environmental reasons (a tool missing in its sandbox) as `LOW` rather than as a failing check.

## [1.1.0] - 2026-10-11

A quality pass over every skill: sharper descriptions, about 40% less text, one vocabulary across the planning skills, and a reworked `/new-project`.

### Changed
- **Every skill reviewed against the `skill-creator` writing guide.** Descriptions now say what the skill writes and when to use it, and name the sibling or built-in to use instead where they used to collide (`/threat-model` vs the built-in `/security-review`, `/roadmap` vs `/issues` vs `/spec`). Bodies lost text that did not change behaviour — the fifteen `SKILL.md` files go from about 2,400 lines to about 1,500 — and long templates moved into `references/` files read only at the step that needs them (`/architecture`, `/design`, `/new-project`).
- **One planning vocabulary.** `/roadmap`, `/spec` and `/issues` used different names for the same fields. They now share `Flag`, `Depends on`, `Complexity: low / med / high` (defined in `/spec`) and `Issue`; phase files are headed `# Phase NNN: <Name>`, which is what `/issues` derives the milestone title from; the roadmap index Status is `Not started`, `In progress` or `Completed`. `/issues` writes the issue number into the spec's `## Trunk Metadata` (or the Slices row), which is where `/feature` and `/autopilot` read it. Branch naming is defined only in `/feature` and `/fix`.
- **Skills work from the trunk branch, not from `main`.** `/feature`, `/fix`, `/pr` and `/autopilot` resolve the default branch with `gh repo view` and measure against `origin/<base>` after a fetch. The size gate also excludes `__tests__/`, `*.spec.*` and `*_spec.*`.
- **Skills ask less.** Interviews read the code and docs first and ask only the gaps, at most 3–4 questions per round. `/prd` revises an existing PRD instead of asking whether to start over. When nobody can be asked (headless run, or dispatched by `/autopilot`), a skill proceeds and lists its assumptions.
- **`/new-project` reworked.** It refuses to scaffold into a non-empty directory unless confirmed, no longer copies the global workflow rules into the generated `CLAUDE.md`, takes per-stack commands from `references/stacks.md` instead of inventing them, and is user-invoked only.
- **`/pr`** records the review verdict as a PR comment, runs the built-in `/security-review` before marking a security-sensitive PR ready, and prints a cleanup command that works after a rebase or squash merge. **`/autopilot`** checks merge permission and the allowed merge method up front and waits for the PR's remote checks before merging.
- **`/threat-model`** tables carry a STRIDE column and a status per control; **`/adr`** finds the repo's ADR directory, defaults to `Proposed`, and marks a superseded ADR. Generated documents carry `Last updated` instead of a `Version` nobody could fill.
- `/design` and `/verify-design` name MCP tools by their short name (the `mcp__…` prefix depends on how the server is installed), load Paper's own guide first, and say what to do when a server is not connected. Model advice is gone from both.
- Conventional-commit types in the global conventions gain `build:` and `ci:`.

### Fixed
- `/roadmap` wrote `# Phase: <Name>` while `/issues` derived the milestone title from a `# Phase NNN:` heading, so the title could not be derived.
- `/commit` told the agent not to `reset` and, two steps later, to `git reset` staged changes.
- `/pr` measured the commit range against a possibly stale local base branch.
- `/fix` required the regression test to fail without the fix but never said to write it first.

## [1.0.0] - 2026-10-11

The toolkit becomes the `wf` Claude Code plugin. Skills are invoked as `/wf:<name>`; the symlink installer, the `aiwf` CLI, the Cursor/Codex adapters, the status line and six skills are gone or merged. See "Removed" for the old → new command map and the README for the upgrade steps.

### Added
- `argument-hint` on every skill that takes arguments, so the slash menu shows them.
- **The toolkit is now a Claude Code plugin, `wf`.** `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` make this repo both the plugin and the marketplace that serves it: `claude plugin marketplace add rafagomes/ai-workflow` then `claude plugin install wf@ai-workflow` (or the same two as `/plugin` commands in a session). Skills are invoked as `/wf:<name>` and the agent is `wf:reviewer`; every cross-reference between skills uses the namespaced form.
- **`reviewer` agent.** One read-only, fresh-context reviewer (`agents/reviewer.md`) with a fixed checklist, a `HIGH` / `MED` / `LOW` severity scale and a `VERDICT` / `CHECKS` / `FINDINGS` / `SUMMARY` output format. It runs the project's check commands itself rather than trusting the writer's output. `/pr` dispatches it; the prompt only supplies base branch, spec path and check commands.
- **Per-profile installs.** Claude Code isolates accounts through its own `CLAUDE_CONFIG_DIR`, so a second profile starts with none of the toolkit. `install.sh` and `uninstall.sh` read a `CLAUDE_DIR` override — `CLAUDE_DIR="$HOME/.claude-work" ./install.sh` links the global `CLAUDE.md` into that profile. `settings.json` is linked only into the primary `~/.claude` unless `--with-settings` is passed, because account, theme, model and enabled plugins are the reason to keep profiles apart. The plugin is installed per profile with `CLAUDE_CONFIG_DIR` set.

### Changed
- **The PR size guide is now ~500 added source lines, and it is a signal rather than a quota.** The 200-line cap dated from when a human read every line. With a fresh-context reviewer on every PR it produced strings of tiny PRs that only made sense together, each paying its own review rounds and merge. The rule is now "one branch = one PR = one concern": past ~500 lines, ask whether it is really one concern and split if it is two; never split one concern to get under the number. Tests, generated files, lockfiles, pure moves and deletions do not count. `/spec` slices only what is more than one concern, and the gates in `/feature`, `/fix` and `/pr` measure added source lines (`git diff --numstat`, tests and lockfiles excluded) and ask only when a change is both over ~500 and more than one concern. The excludes use `:(exclude,glob)` pathspecs, so a top-level `tests/` directory is excluded too. A bug fix or a behaviour-neutral chore no longer needs a spec written for it.
- **Review rules made proportionate** (`dotfiles/CLAUDE.md`, new "Review" section). Still one fresh-context review for every PR that changes behaviour, unprompted. New: one reviewer per PR rather than per commit; at most two fix rounds; `LOW` findings never trigger another round; and a diff that is only typo or formatting fixes in prose, or a changelog or project-version bump, may skip the reviewer if the PR body says so — text that instructs an agent never qualifies. `/pr --no-review` accepts that case and writes `Review: skipped — <reason>`.
- **Global conventions rewritten** for the rest: verification reports one line per check and pastes output only on failure, and says so when a project has no checks; the Paper rule applies when a project has a design source instead of blocking all UI work; a spec link and security note are required in a PR description only when they apply; the skill list and the "Context Management" section are gone (the plugin advertises its own skills; the other restated built-in commands); duplicated PR-size and file-convention rules are merged.
- **`settings.example.json` no longer seeds `bypassPermissions`, `skipDangerousModePermissionPrompt`, or a pinned model.** A fresh install starts in Claude Code's default permission mode with the default model. It enables `wf@ai-workflow` and registers this repo as a marketplace; the `telegram` plugin, which fails to start without `bun`, is no longer in the seed. An existing `settings.json` is not touched.
- `/design` keeps its 230-line design-system template in `design-system-template.md` beside the skill instead of inline, so it is read only when the document is being written.
- **`install.sh` and `uninstall.sh` only handle what a plugin cannot carry**: the global `CLAUDE.md` and `settings.json` (with the same per-profile `CLAUDE_DIR` and `--with-settings` / `--no-settings` behaviour), plus `--extra`. Per-file filters are gone. `uninstall.sh` also sweeps every skill, agent, command and review-guide symlink an older install left pointing into the clone, and the `aiwf` launcher link.
- README rewritten around the plugin and restructured to be read top-down: a four-command quick start, a diagram of the pipeline, the review loop, skills grouped as Plan / Design / Build / Ship, a "pick your path" table, and the reference material (installer flags, profiles, upgrade map, layout) in collapsible sections. Repository URLs point at `rafagomes/ai-workflow`.
- **`/architecture` now covers the technical design too, in one document.** `/tdd` is merged into it: one interview, one `docs/ARCHITECTURE.md` with a System part (components, data flow, stack, deployment, decisions) and an Engineering part (testing strategy, dev environment, CI/CD, coding standards, observability, dependencies). The two documents repeated the stack and deployment decisions, and "TDD" read as test-driven development. Skills that read the testing strategy (`/spec`, `/roadmap`, `/feature`, `/fix`, `/autopilot`) look in `docs/ARCHITECTURE.md` and fall back to `docs/TECHNICAL_DESIGN_DOCUMENT.md` in older projects; `/architecture` offers to fold a legacy file in.
- **`/autopilot` absorbs `/factory`.** They were the same pipeline (waves, worktree writers, cold reviewer, writer resumed for fixes, 2-cycle cap) differing only in scope and whether they merge. `/autopilot` now takes a roadmap, a phase (`--phase NNN` or a phase file) or a GitHub milestone (`--milestone <N>`), caps a wave at 5 writers, reviews with the shared `reviewer` agent, and supports `--supervised` (never merges or approves; verdicts go on the PR as comments) and `--dry-run`. It no longer generates missing specs or edits the project's `.claude/settings.json` — a missing spec is a stop. It is **user-invoked only** (`disable-model-invocation`), since invoking it is what grants merge authority.
- **`/security` is renamed `/threat-model`**, which is what it writes; the old name collided with the built-in `/security-review`.
- **`/pr` now opens a draft, runs a fresh-context review, and marks the PR ready on PASS.** HIGH/MED findings are fixed in a bounded loop (max 2 cycles); an unresolved loop leaves the PR as a draft. `--draft` keeps it a draft after a passing review; the new `--no-review` skips the loop.
- **Review happens in one place.** `/feature` and `/fix` no longer review their own uncommitted work (`/feature` carried its own copy of the reviewer prompt; `/fix` ran a self-check in the writer's session); they stop at the working tree and `/pr` reviews the committed branch. Previously `/feature` followed by `/pr` reviewed the same change twice.
- `/feature` lost its file-placement table and parallel-wave dispatch — machinery for 6+-file changes inside a slice capped at 200 source lines. `--commit` and `--pr` now refer to `/commit` and `/pr` by name instead of by step number.
- **Writer/reviewer separation restated as an obligation, not a prohibition.** The global rule read "never review code in the same session that wrote it" — true, but it only says what *not* to do, and a small or test-only diff could plausibly be read as needing no review at all. It now reads **always trigger a fresh reviewer**: once an implementation is on a branch, actively spawn a reviewer with clean context (a subagent that did not write the code, or a fresh session), every time, unprompted, regardless of diff size. Paired with a second rule making **merge authority explicitly human-gated**: the default is to report findings and stop, and autonomous merging happens only when the user has said so for that specific piece of work ("autonomous", "merge if it passes", `/autopilot`), with the authorization never carrying to the next task.
- `/autopilot` repositioned from "dispatch worktree agents, pause between phases for human merge" to **fully autonomous end-to-end delivery**. It now runs the complete pipeline for every task itself — **develop (writer worktree agent) → review (fresh-context reviewer agent that re-runs the build) → bounded 2-cycle fix loop (writer resumed via `SendMessage`) → merge to `main`** — and loops through every phase with **no human gate by default**. The orchestrator performs the merge directly (`gh pr merge --rebase --delete-branch`, never `--squash`, to preserve the writer's logical commit split). This is the deliberate counterpart to `/factory` (which stops with PRs open for human merge): autopilot *merges*. A new `--supervised` flag restores the previous behaviour (stop at each phase boundary with PRs open). Adds: a pre-flight gate (specs committed to `main`, toolchain on PATH, `gh` auth, merge authority, clean tree), file-overlap-aware parallel waves, a security gate (`/security-review`) for risky diffs, feature-flag-off-until-phase-end discipline, committed roadmap-status updates for resumability, and explicit stop conditions (unresolvable conflict, surviving finding, missing/contradictory spec, protected `main`, destructive out-of-scope actions). Writer/reviewer separation is enforced — review always runs as a separate cold-context agent, never the writer and never the orchestrator.

### Removed
- **The status line.** `statusline-command.sh`, its `statusLine` block in `settings.example.json` and its installer link are gone from this repo; the script now lives in [rafagomes/claude-code-mods](https://github.com/rafagomes/claude-code-mods/tree/main/statusline), with the rework that was pending here (quiet rate-limit row, unambiguous reset stamps, single `jq` pass, Linux fixes). **Breaking** for an existing install: after `git pull` the `~/.claude/statusline-command.sh` link dangles — re-link it to the new location, or run `./uninstall.sh` to remove it. A `settings.json` you already have keeps its `statusLine` entry.
- **The `aiwf` CLI and `bootstrap.sh`.** Install, update and removal of the skills go through `claude plugin`; there is no clone to manage for them. **Breaking**: the skills lose their bare names (`/feature` → `/wf:feature`). To upgrade, run `./uninstall.sh` once from the existing clone, `git pull`, `./install.sh`, then install the plugin.
- **`/factory`, `/tdd` and `/rfc`.** `/factory` and `/tdd` are merged as described above; `/factory` also depended on Spec Kit commands this repo never installed. `/rfc` (a proposal for team feedback) is dropped — `/adr` covers recorded decisions. **Breaking**: `/factory <phase>` becomes `/autopilot --phase <NNN> --supervised` and `/factory --milestone <N>` becomes `/autopilot --milestone <N> --supervised` (the `--limit` and `--no-issues` flags are gone), `/tdd` becomes `/architecture`, `/security` becomes `/threat-model`. The old symlinks are swept by `./uninstall.sh` (see the upgrade note above).
- **`/review`, `/sec-review`, the `architecture-reviewer` and `security-reviewer` agents, and `reviews/*.md`.** The two agents had no frontmatter and were never registered by Claude Code, so the skills that named them as a fallback were calling nothing. `/review` is replaced by Claude Code's built-in `/code-review`, `/sec-review` by the built-in `/security-review`. The language guides were generic lint-level advice with no remaining consumer. **Breaking** for anyone invoking `/review` or `/sec-review`; when upgrading an existing install, run `./uninstall.sh` once — it sweeps the old symlinks, which would otherwise dangle.
- `docs/REFERENCE.md`, `docs/WORKFLOW.md` and `docs/spec-driven-development.md`. REFERENCE paraphrased every `SKILL.md` and had drifted from them (no `/issues`, old `/pr` and `/autopilot` behaviour); WORKFLOW predated the skills and contradicted the trunk rules (it recommended stacked PRs); the SDD guide duplicated the README's pipeline and model tables. The `SKILL.md` files are the reference; `README.md` is the overview; `docs/TRUNK_BASED_WORKFLOW.md` and `docs/SKILL_QUALITY.md` stay.
- **Cursor and Codex CLI adapters.** `adapters/cursor/` and `adapters/codex/` are gone, along with `aiwf install-cursor`, `uninstall-cursor`, `install-codex`, `uninstall-codex`, `install-all` and `uninstall-all`, the `CURSOR_RULES_DIR` / `CODEX_DIR` overrides, and the Cursor/Codex auto-detection in `bootstrap.sh`. The toolkit targets Claude Code only. **Breaking** for anyone using those commands; an existing Cursor/Codex install is not cleaned up — remove `~/.cursor/rules/aiwf-*.mdc`, `~/.agents/skills/aiwf-*` and the generated `~/.codex/AGENTS.md` by hand, and revert `project_doc_max_bytes` in `~/.codex/config.toml` if the adapter raised it.
- `code-review-workspace/` — benchmark output for the already-removed `/code-review` skill. The conclusion (no detection lift over baseline at ~1.5× the cost) stays recorded in the docs.
- `docs/speckit-integration.md` — the Spec Kit integration guide had drifted from the skills.

### Fixed
- `/new-project` generated an invalid `PostToolUse` hook (old flat shape, no `hooks` array or `type`), told the scaffold to gitignore all of `.claude/` while also creating a committed `.claude/settings.json`, and copied two reviewer agents that had no frontmatter and so never registered. The hook now uses the current schema, only `.claude/settings.local.json` is ignored, and the agent-copy step is gone.
- `/verify-design` carried paths and commands from one specific project (`web/app/globals.css`, `pnpm --filter web dev`, `localhost:3000`, literal artboard IDs). It now discovers the token sources, dev-server command and check commands from the project, and its description lists trigger phrases.
- `/issues` preferred a GitHub MCP server using guessed tool names; it now goes through the `gh` CLI only.
- `aiwf uninstall` and `aiwf reinstall` no longer abort with `passthru: unbound variable` on bash 3.2 (stock macOS `/bin/bash`), where an empty array expansion trips `set -u`. Reported, with a fix, by @thalissonbarbosas in #1, before the launcher was retired in this release.
- `install.sh`'s closing message hardcoded `~/.claude/` even when installing elsewhere.
- The primary-directory comparison canonicalizes both paths, so `~/.claude/`, `~/./.claude` or a symlinked `~/.claude` no longer flip a profile between shared and isolated settings.
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

[Unreleased]: https://github.com/rafagomes/ai-workflow/compare/v1.1.1...HEAD
[1.1.1]: https://github.com/rafagomes/ai-workflow/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/rafagomes/ai-workflow/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/rafagomes/ai-workflow/compare/v0.6.3...v1.0.0
[0.3.0]: https://github.com/rafagomes/ai-workflow/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/rafagomes/ai-workflow/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/rafagomes/ai-workflow/releases/tag/v0.1.0
