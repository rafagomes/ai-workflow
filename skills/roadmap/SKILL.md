---
name: roadmap
description: "Create a phased roadmap from design docs — one numbered phase per file under docs/roadmap/NNN_*.md. Use when the user asks to plan phases, break work into milestones, sequence a build, says 'what order should we ship in', 'lay out the roadmap', 'split this into phases', or wants a delivery plan derived from the PRD and architecture."
---
Create a phased roadmap for: $ARGUMENTS

## Parse Arguments

The argument can be:
- **Phase name:** `/roadmap auth-system` — creates `docs/roadmap/NNN_auth-system.md` where `NNN` is the next available 3-digit prefix
- **No argument:** `/roadmap` — reads PRD, architecture, and any existing specs to create a full roadmap with numbered phase files
- **Doc path:** `/roadmap docs/specs/feature_x.md` — creates a roadmap for a single spec or feature area

## Phase Numbering

All phase files get a zero-padded 3-digit prefix so phase order is obvious at a glance and files sort correctly: `001_foundations.md`, `002_api-layer.md`, `003_frontend.md`, etc. The index file `docs/roadmap/README.md` stays **unnumbered** — it's the table of contents, not a phase.

**Rules:**
- **Scan, don't renumber.** Before creating a phase, list `docs/roadmap/` and extract existing `NNN_*.md` prefixes. Use `max(existing) + 1`, zero-padded to 3 digits. Never renumber existing files — commits, PRs, and specs may reference them by name.
- **Full roadmap from scratch:** first phase is `001_`, numbered in dependency order.
- **Adding to an existing roadmap:** continue from the next available number.
- **Separator is underscore** (`001_auth-system.md`), not dash, to keep the numeric prefix visually distinct from the kebab-case phase slug.

## Context Gathering

Before anything, read what exists:

1. **Design docs (primary input for the roadmap):**
   - Read `docs/PRD.md` or `docs/prd/` — the source of *what* needs to be built
   - Read `docs/ARCHITECTURE.md` — the source of *how* the system is structured
   - Read `docs/TECHNICAL_DESIGN_DOCUMENT.md` — testing strategy, dev environment, CI/CD
   - Read `docs/THREAT_MODEL.md` — security constraints, trust boundaries
   - Read `CLAUDE.md` for build commands and conventions
   - Read `README.md` for project overview

2. **Existing specs (optional — specs may not exist yet):**
   - List all files in `docs/specs/`
   - If feature specs exist, read them — they add detail to the roadmap
   - If no feature specs exist, that's fine — the roadmap will define *what* needs to be specified

3. **Existing roadmap:**
   - Check `docs/roadmap/` — if roadmaps already exist, read them to avoid duplication
   - If the user is adding to an existing roadmap, build on what's there

4. **Codebase state:**
   - Explore the directory structure to understand what already exists
   - Check `git log --oneline -20` for recent work direction
   - Identify what (if anything) is already implemented

5. **Visual design references (for UI work):**
   - Check for a connected **Figma MCP** — if available, list frames/pages so tasks can reference them by node ID
   - Check for a connected **Paper MCP** (`mcp__paper__get_basic_info`) — if available, list artboards so tasks can reference them by node ID
   - If neither MCP is connected, look for local image references: `design/assets/`, `docs/design/`, `design/`, or any PNG/JPG mockups in the repo
   - When writing UI tasks, include a **Design reference** field pointing to the specific frame/artboard/image the task implements. If nothing is found, flag it and ask the user to provide a reference before the task is executable.

**Minimum required context:** A PRD or architecture doc. The roadmap breaks down *what the design docs describe* into phased, executable work. If neither exists, stop and tell the user:
"No PRD or architecture doc found. Create one first with `/prd` or `/architecture`, then come back to build the roadmap."

## Interview

Use AskUserQuestion to refine the roadmap. Adapt questions based on what you learned from the design docs and codebase.

1. **Priorities** — Which features are most important? What must ship first? Are there external deadlines?
2. **Dependencies** — Are there features that must be done before others? Shared interfaces or data models that need to exist first?
3. **Parallelization** — How many worktrees/agents can run simultaneously? Any file overlap concerns between features?
4. **Team context** — Is this a solo developer or a team? How many streams of parallel work are practical?
5. **Verification** — What are the build/test/lint commands? Are there integration tests that span features?
6. **Phase boundaries** — Where are the natural checkpoints? What needs human review before continuing?
7. **MVP boundary** — Which phase is the last one required to ship the MVP? Everything after that phase is post-MVP polish/expansion. If the answer isn't obvious from the PRD's "in scope (v1)" section and the first-slice priority, ask explicitly. Every full roadmap MUST identify this boundary.

**Interview rules:**
- If design docs are clear and dependencies are obvious, keep the interview short (2-3 questions)
- If the PRD is broad or there are many features, dig deeper
- Push back on unrealistic parallelization — if two tasks touch the same files, they must be sequential
- Don't ask what's already answered in the design docs

## Generate the Roadmap

Create `docs/roadmap/` directory if it doesn't exist.

### Single Phase

If the user gave a phase name or single feature area, compute the next prefix (see Phase Numbering above) and write to `docs/roadmap/NNN_<phase-name>.md`.

**Trunk rule for tasks.** One task = one vertical slice = one PR ≤200 lines (per root `CLAUDE.md`'s Trunk-Based Workflow). If a task is `complexity:high`, the spec it points to **must** be sliced (directory-based spec with a `## Slices` table, per `/spec`). The roadmap task then tracks the *spec*, not a PR — the actual PRs come from the spec's slices.

```markdown
# Phase: [Name]

## Context
[What this phase accomplishes. Dependencies on prior phases if any.]

## Trunk Alignment
[Which tasks ship user-ready vs. behind a feature flag. Name the flags. If the whole phase is gated by one flag (e.g., `jira_ingest_enabled`), say so here.]

## Tasks

### Task 1: [Name]
- **Spec:** docs/specs/NNN_[name].md (exists | needs creation)
- **Design reference:** [Figma node | Paper artboard id | path to image | N/A for non-UI]
- **Type:** feat / fix / refactor / chore / test / docs / perf / security
- **Files:** [list of files to create or modify]
- **Dependencies:** None
- **Tests:** Unit + Integration (sets up data models and API layer)
- **Verification:** [command to verify this task works]
- **Feature flag:** `none` or `flag_name` (default off)
- **Estimated complexity:** Low / Medium / High
- **Milestone:** Phase NNN — [phase-name]
- **Issues:** — (filled by `/issues`)

### Task 2: [Name] — HIGH complexity → sliced spec
- **Spec:** docs/specs/NNN_[name]/README.md (sliced — see its Slices table for PR-sized slices)
- **Type:** feat
- **Files:** [cross-slice file list]
- **Dependencies:** Task 1 (needs [specific thing])
- **Tests:** Unit + Integration (service interactions)
- **Verification:** [command]
- **Feature flag:** `flag_name` (covers every slice)
- **Estimated complexity:** High
- **Milestone:** Phase NNN — [phase-name]
- **Issues:** — (one GitHub issue per slice, filled by `/issues`)

### Task 3: [Name] (can parallelize with Task 2)
- **Spec:** docs/specs/NNN_[name].md (exists | needs creation)
- **Type:** feat
- **Files:** [list — no overlap with Task 2]
- **Dependencies:** Task 1
- **Tests:** Unit only (pure UI logic, no service boundary)
- **Verification:** [command]
- **Feature flag:** `none`
- **Estimated complexity:** Low
- **Milestone:** Phase NNN — [phase-name]
- **Issues:** —

## Execution Order

1. **Sequential:** Task 1 (foundation — others depend on it)
2. **Parallel:** Task 2 + Task 3 (no file overlap, both depend only on Task 1)

## Phase Checklist
- [ ] All tasks have detailed specs
- [ ] All `complexity:high` tasks have sliced specs (≤200 lines per slice)
- [ ] `/issues` has filed the phase milestone + one issue per task/slice
- [ ] All tasks completed
- [ ] All verification commands pass
- [ ] PRs reviewed and merged
- [ ] Integration tests pass (if applicable)
- [ ] Feature flags flipped on where the phase calls for it (or flagged as deferred in `## Trunk Alignment`)
```

### Full Roadmap

If the user gave no argument (build from design docs), write an index at `docs/roadmap/README.md` plus one file per phase:

**`docs/roadmap/README.md`:**

```markdown
# Roadmap

## Overview
[What the full roadmap accomplishes. High-level project goal.]

## MVP Boundary
**The MVP ends at Phase NNN ([phase-name]).** [One sentence describing what the user has at that point and why that slice is shippable on its own.] Phases after NNN are post-MVP — [one sentence describing what they add].

## Phases

| # | Phase | Tasks | Dependencies | MVP | Status |
|---|-------|-------|--------------|-----|--------|
| 001 | [phase-name](001_phase-name.md) | [count] | None | ✓ | Not started |
| 002 | [phase-name](002_phase-name.md) | [count] | 001 | ✓ | Not started |
| 003 | [phase-name](003_phase-name.md) | [count] | 002 | ✓ **(MVP ends here)** | Not started |
| 004 | [phase-name](004_phase-name.md) | [count] | 003 | — | Not started |

## Execution Notes
- [Key parallelization opportunities]
- [Critical path — the longest sequential chain]
- [Known risks or blockers]
```

**MVP boundary is required.** Mark the last MVP phase with `✓ **(MVP ends here)**` in the table and call it out in a dedicated `## MVP Boundary` section above the table. Post-MVP phases get `—` in the MVP column. If the user hasn't indicated a boundary and it isn't obvious from the PRD, ask before writing the README.

Then create each `docs/roadmap/NNN_<phase-name>.md` using the single-phase format above, numbering phases in dependency order starting at `001_`.

## Key Rules for Task Breakdown

1. **One task = one vertical slice ≤200 lines = one PR** (trunk-based). If a task is `complexity:high`, point it at a **sliced spec** (directory form, see `/spec`). The roadmap task is the tracker; the PRs come from the slices.
2. **Every task names its commit type** — `feat` / `fix` / `refactor` / `chore` / `test` / `docs` / `perf` / `security`. This drives the branch prefix and the `type:*` GitHub label.
3. **Every task names its feature flag** — or `none` if the task ships user-ready on merge. `main` must stay deployable after every merge.
4. **Identify parallelizable tasks** — tasks that touch different files can run simultaneously in worktrees.
5. **Mark dependencies explicitly** — if Task B needs Task A's output, say so and explain what specifically it needs.
6. **Include verification commands** — every task needs a concrete way to prove it works.
7. **Specify test layers per task** — based on the Testing Strategy in `docs/TECHNICAL_DESIGN_DOCUMENT.md` (or inferred from the codebase), mark which test layers each task needs: Unit, Integration, E2E. A task that touches APIs needs integration tests. A task that implements a critical user flow needs e2e. Pure logic only needs unit.
8. **Foundation first** — shared types, interfaces, data models, and config go in Phase 1. Implementation builds on top.
9. **File overlap = sequential** — if two tasks modify the same file, they cannot run in parallel. Call this out explicitly.
10. **Mark spec status per task** — indicate whether a detailed spec exists or needs to be created. Tasks without specs need `/spec` or `/speckit.specify` before execution. Tasks without GitHub issues need `/issues` before execution.
11. **Spec prefix mirrors the phase number.** Specs for tasks in Phase `NNN` are written to `docs/specs/NNN_<name>.md` (or `docs/specs/NNN_<name>/` if sliced). When a phase has multiple tasks, disambiguate with a letter suffix: `NNN.A_<name>.md`, `NNN.B_<name>.md`. See `/spec` for full numbering rules.

## After Writing

1. Present the roadmap to the user for review. Highlight:
   - The critical path (longest sequential chain)
   - Parallelization opportunities
   - Which tasks already have specs and which need them

2. Iterate until the user is satisfied.

3. Suggest next steps based on spec coverage:
   - **Tasks need specs?** → "Create detailed specs before executing: `/spec <feature-name>` for each task (or `/speckit.specify` with GitHub Spec Kit). `complexity:high` tasks must produce a sliced directory-form spec."
   - **All tasks have specs, no GitHub issues yet?** → "Run `/issues docs/roadmap/README.md` to file milestones (one per phase) and issues (one per task/slice)."
   - **All tasks have specs + issues?** → "Planning is complete: every task is an issue with a spec, ready to be implemented. This toolkit has no one-command 'run the whole roadmap' pipeline — implement issue by issue, or use the `superpowers` plugin's `subagent-driven-development` / `executing-plans` skills to work through several tasks."
   - **Start one phase?** → "Run `/issues docs/roadmap/NNN_<phase-name>.md`, then implement that phase's issues one at a time."
   - **Single task?** → "In Claude Code, hand the issue and its spec to the `feature-dev` plugin: `/feature-dev:feature-dev implement issue #<N> per docs/specs/NNN_<name>.md`" (or a specific slice file `docs/specs/NNN_<name>/MMM_<slice>.md` for sliced specs)
