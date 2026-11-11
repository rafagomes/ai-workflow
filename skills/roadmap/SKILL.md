---
name: roadmap
description: "Turn the PRD and architecture into a phased delivery plan: docs/roadmap/README.md plus one numbered phase file per phase (docs/roadmap/NNN_<phase>.md), each with sized, ordered tasks that name their spec, flag, files and verification command. Use when the user wants to plan phases, sequence a build, decide what ships first or where the MVP ends, or says 'lay out the roadmap', 'what order should we ship in', 'split this into phases', 'add a phase for X'. Not for filing issues for a roadmap that already exists (/wf:issues) or a single feature's spec (/wf:spec)."
argument-hint: "[phase name | spec path]"
---
Create a phased roadmap for: $ARGUMENTS

## Parse Arguments

- **Phase name:** `/wf:roadmap auth-system` writes `docs/roadmap/NNN_auth-system.md`.
- **No argument:** build a full roadmap (index plus phase files) from the PRD, architecture and any existing specs.
- **Spec path:** `/wf:roadmap docs/specs/003_feature-x.md` plans a single spec or feature area; name the phase after the spec's slug.

## Phase Numbering

Phase files are `NNN_<slug>.md` (zero-padded, underscore, kebab-case slug) so they sort in phase order. `docs/roadmap/README.md` is the unnumbered index. Before creating a phase, list `docs/roadmap/` and use `max(existing) + 1`. Never renumber existing files: commits, PRs and specs reference them by name. A full roadmap starts at `001_` in dependency order.

## Context Gathering

Read what exists before asking anything: `docs/PRD.md` or `docs/prd/`, `docs/ARCHITECTURE.md`, `docs/THREAT_MODEL.md`, the project's `CLAUDE.md` (build commands), `README.md`, `docs/specs/` (specs may not exist yet; the roadmap then says which need writing), `docs/roadmap/` (build on it, avoid duplicates), the directory structure and `git log --oneline -20` (what is already implemented).

If neither a PRD nor an architecture doc exists, say so and offer two choices: create one (`/wf:prd`, `/wf:architecture`), or build the roadmap from the user's stated goal plus the code and README. Do not stop silently.

**UI work:** look for a design source: a connected Paper or Figma MCP (Paper's `get_basic_info` tool lists artboards), or `docs/design/`. Put the artboard id or image path in the task's `Design reference`. If there is none, write `Design reference: MISSING` and carry on; `/wf:autopilot` warns and does not block, so the roadmap should not either.

## Interview

Draft the phase split, the MVP boundary and the parallelism from the docs first. Ask only what the docs leave open, at most 4 questions in one AskUserQuestion call; if the user cannot be asked, proceed from the docs and list each assumption as an open question. Typical gaps: priorities and deadlines, how many parallel worktrees/agents are practical (solo or team), where a human review is needed before continuing, build/test/lint commands if the project's `CLAUDE.md` lacks them. Push back where two tasks touch the same files: they must be sequential.

A full roadmap needs an MVP boundary: the last phase required to ship the MVP. Take it from the PRD's "in scope (v1)" section; if that does not settle it, ask.

**GitHub hand-off.** In the same AskUserQuestion call, also ask: "File GitHub milestones and issues when the roadmap is settled?" with options *Yes, once it is on the trunk branch* / *No, only the roadmap*. This question is always asked and does not count toward the 4 (the tool takes at most 4 per call, so when 4 gaps are already open, ask it in a second call). Skip it only when the repository has no GitHub remote (`gh repo view --json nameWithOwner` fails). The answer is intent only: nothing is filed during the interview or while the roadmap is being written, because the draft still changes and issue titles are numbered by task position. Act on it in After Writing. If the user cannot be asked, the answer is No.

## Generate the Roadmap

Create `docs/roadmap/` if it does not exist.

### Single Phase

Write `docs/roadmap/NNN_<phase-name>.md`. If `docs/roadmap/README.md` exists, append the phase's row to its table (MVP column `—` unless the user says otherwise).

A task is one vertical slice, one PR, one concern (see the size guide in your global `CLAUDE.md`). Complexity and the `Risk` tier are defined in `/wf:spec` (tiers in **Risk tiers** in your global `CLAUDE.md`); set `Risk` from what the task touches, not how big it is; a `high` task normally points at a sliced spec (a directory with a `## Slices` table). The roadmap task then tracks the spec and the PRs come from its slices.

```markdown
# Phase NNN: [Name]

## Context
[What this phase accomplishes. Dependencies on prior phases if any.]

## Trunk Alignment
[Which tasks ship user-ready vs. behind a feature flag. Name the flags. If one flag gates the whole phase, say so.]

## Tasks

### Task 1: [Name]
- **Spec:** docs/specs/NNN_[name].md (exists | needs creation)
- **Design reference:** [Paper artboard id | Figma node | image path | MISSING | N/A for non-UI]
- **Type:** feat / fix / refactor / chore / test / docs / perf / build / ci / security
- **Files:** [files to create or modify]
- **Depends on:** None
- **Tests:** Unit + Integration (sets up data models and API layer)
- **Verification:** [command that proves this task works]
- **Flag:** `none` or `flag_name` (default off)
- **Complexity:** low / med / high
- **Risk:** T1 — [one-line why]
- **Milestone:** Phase NNN — [phase-name]
- **Issues:** — (filled by `/wf:issues`)

### Task 2: [Name] (high complexity, sliced spec)
- **Spec:** docs/specs/NNN_[name]/README.md (sliced; its Slices table lists the PR-sized slices)
- **Type:** feat
- **Files:** [cross-slice file list]
- **Depends on:** Task 1 (needs [specific thing])
- **Tests:** Unit + Integration
- **Verification:** [command]
- **Flag:** `flag_name` (covers every slice)
- **Complexity:** high
- **Risk:** T2 — [one-line why]
- **Milestone:** Phase NNN — [phase-name]
- **Issues:** — (one per slice, filled by `/wf:issues`)

## Execution Order

1. **Sequential:** Task 1 (foundation)
2. **Parallel:** Task 2 + Task 3 (no file overlap, both depend only on Task 1)

Tasks grouped as parallel must follow the same rule `/wf:autopilot` uses for waves (step 4): no dependency between them and no file in common.

## Phase Checklist
- [ ] All tasks have detailed specs
- [ ] All `high` tasks have sliced specs
- [ ] `/wf:issues` has filed the phase milestone and one issue per task/slice
- [ ] All tasks completed and verification commands pass
- [ ] PRs reviewed and merged
- [ ] Integration tests pass (if applicable)
- [ ] Feature flags flipped on where the phase calls for it (or deferred in `## Trunk Alignment`)
```

### Full Roadmap

Write the index at `docs/roadmap/README.md`, then each phase file in the format above.

```markdown
# Roadmap

## Overview
[What the full roadmap accomplishes.]

## MVP Boundary
**The MVP ends at Phase NNN ([phase-name]).** [What the user has at that point and why it ships on its own.] Later phases are post-MVP: [what they add].

## Phases

| # | Phase | Tasks | Dependencies | MVP | Status |
|---|-------|-------|--------------|-----|--------|
| 001 | [phase-name](001_phase-name.md) | [count] | None | ✓ | Not started |
| 002 | [phase-name](002_phase-name.md) | [count] | 001 | ✓ **(MVP ends here)** | Not started |
| 003 | [phase-name](003_phase-name.md) | [count] | 002 | — | Not started |

## Execution Notes
- [Parallelization opportunities, critical path, known risks]
```

Status is one of `Not started`, `In progress`, `Completed`. `/wf:autopilot` sets `Completed` and skips such phases.

## Key Rules for Task Breakdown

1. **One task = one vertical slice = one PR = one concern.** Every task names its commit type (it drives the branch prefix and the `type:*` label) and its flag (`none` if user-ready on merge), because the trunk branch must stay deployable after every merge.
2. **Parallelize only when files do not overlap.** Mark every dependency and say what specifically the later task needs.
3. **Give every task a concrete verification command.**
4. **Mark test layers per task** from the Testing Strategy in `docs/ARCHITECTURE.md` (in older projects, `docs/TECHNICAL_DESIGN_DOCUMENT.md`) or the codebase: a task touching APIs needs integration tests, a critical user flow needs e2e, pure logic only unit.
5. **Foundation first:** shared types, interfaces, data models and config go in Phase 1.
6. **Spec status per task.** A task without a spec needs `/wf:spec` before execution; one without a GitHub issue needs `/wf:issues`.
7. **Spec prefix mirrors the phase number.** Specs for Phase `NNN` live at `docs/specs/NNN_<name>.md` (or `NNN_<name>/` if sliced); several specs in one phase take letter suffixes `NNN.A_`, `NNN.B_` in task order. Issue titles number the same tasks `[NNN.N]` by position (Task 2 is `[003.2]`). See `/wf:spec`.

## After Writing

1. Present the roadmap: critical path, parallelization, which tasks have specs. Iterate until the user is satisfied.
2. Commit the roadmap and any specs; `/wf:autopilot` needs them on the trunk branch.
3. **Hand off to `/wf:issues`, if the user answered Yes** in the interview. File only from what is on the trunk branch, never from a draft.
   - **Target file:** `docs/roadmap/README.md` for a full roadmap; the phase file (`docs/roadmap/NNN_<phase>.md`) for a single phase or a spec path, even though the index was edited too. Passing the index there would file the whole roadmap.
   - **Gate:** resolve the trunk branch `<base>` as `/wf:autopilot` does (`gh repo view --json defaultBranchRef -q .defaultBranchRef.name`, fallback `git symbolic-ref --short refs/remotes/origin/HEAD` with `origin/` stripped), run `git fetch origin <base>`, then check both: `git status --porcelain -- docs/roadmap docs/specs` prints nothing (no uncommitted or untracked files, which `git diff` alone would miss), and `git diff --quiet origin/<base> -- docs/roadmap docs/specs` exits 0. Together they mean every roadmap and spec file in the working tree is identical to the trunk branch.
   - **Gate passes:** invoke `/wf:issues <target file>`. It runs its own preflight, dry-run and confirmation. Its questions (Reconcile, Horizon, Proceed?) are the user's to answer: the Yes given in the interview is not an answer to any of them, and in particular does not choose the full-roadmap horizon. Do not file anything yourself. Tasks without a spec are fine: their issues carry `needs-spec`; do not hold the hand-off back or ask again because of them.
   - **Gate fails** (untracked, uncommitted, committed but not pushed, on a branch, or in an open PR; any output from the first command or a non-zero exit from the second): do not file. Say why and give the command to run once it is merged: `/wf:issues <target file>`.
   - The user answered No or could not be asked: do not file, and do not ask again.
4. Suggest the next step:
   - Specs missing: `/wf:spec <task>` for each (a `high` task gets a sliced spec). Issues filed before a spec exists carry `needs-spec`; re-run `/wf:issues` after writing it.
   - Specs exist and issues are not filed: `/wf:issues docs/roadmap/README.md` (or one phase file), then `/wf:autopilot` on the same file.
   - One task: `/wf:feature docs/specs/NNN_<name>.md` (or a slice file `docs/specs/NNN_<name>/MMM_<slice>.md`).
