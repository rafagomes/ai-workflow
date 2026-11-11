---
name: spec
description: "Write the implementation spec for one feature or roadmap task at docs/specs/NNN_<feature>.md — problem, design, affected files, flag, and verification criteria with concrete inputs and outputs — and slice it into independently mergeable pieces when it is more than one concern. Use when the user says 'spec out X', 'write the plan for Y', 'turn this idea into a spec', 'this roadmap task needs a spec', or wants a document /wf:feature can build from. Not for bug fixes (/wf:fix)."
argument-hint: "<feature | roadmap task | existing spec>"
---
Create a feature implementation spec for: $ARGUMENTS

In hosts that do not substitute `$ARGUMENTS` (e.g. Codex), it is the text the user wrote after the skill name.

## Spec Numbering & Path

Every spec path starts with a zero-padded 3-digit prefix mirroring its **roadmap phase number**, so spec order matches roadmap order at a glance.

- **Single spec:** `docs/specs/NNN_<slug>.md`
- **Sliced spec:** `docs/specs/NNN_<slug>/` containing `README.md` (index) and `MMM_<slice>.md` files. The directory-vs-file distinction is how sliced specs are identified; the `NNN` prefix stays on the directory, never moves to the children.
- **Separator** between prefix and slug is `_`; within the slug, words are joined by `-` (e.g., `003_atlassian-integration.md`).

**Picking `NNN`:**
- If this spec implements a task in `docs/roadmap/NNN_<phase>.md`, use that same `NNN`.
- Multiple specs in one phase: letter suffixes `NNN.A_<name>.md`, `NNN.B_<name>.md`, in task order. A lone spec has no suffix.
- No roadmap yet: scan `docs/specs/` and use `max(existing) + 1`. Don't renumber later when a roadmap is added.
- **Never renumber an existing spec**: commits, PRs and issues reference specs by path.

Before writing any file, tell the user the path and which roadmap phase it mirrors.

## Context Gathering

Read what already exists before asking anything:

1. **Docs:** `docs/PRD.md` or `docs/prd/`, `docs/ARCHITECTURE.md` (and `docs/TECHNICAL_DESIGN_DOCUMENT.md` in older projects), `docs/THREAT_MODEL.md`, `README.md`, the project's agent instructions (`CLAUDE.md` or `AGENTS.md`).
2. **Roadmap and specs:** list `docs/roadmap/` and `docs/specs/` to pick `NNN`. If the input is a roadmap task, take its Files, Flag, Depends on, Complexity, Verification and `Design reference` from the task.
3. **An existing spec for this feature:** if the user is revising, don't start from scratch.
4. **Inherited project with no docs:** read the README, the directory structure, key entry points, `git log --oneline -20` and the manifest (`package.json`, `Cargo.toml`, `pyproject.toml`, ...). Summarize what you understood before the interview.

## Interview

Read the affected code and draft the spec first. Ask only what is still open, at most 4 questions per AskUserQuestion call. Where AskUserQuestion is unavailable but the user can answer in chat (e.g. Codex), ask the same question in chat as a short numbered list and wait for the answer; a headless run or a dispatched agent has no such user, and the headless rule applies instead. If the user cannot be asked (a headless run), proceed from what exists and list each assumption under an `Open questions` heading in the spec. The spec must be precise enough to implement without further clarification, so cover: what changes, edge cases, security (auth, input validation, data exposure), concrete verification cases with inputs and expected outputs, and dependencies. Skip what does not apply: an API contract and data model mean nothing for a CLI, UI-only or docs change.

Reference existing architecture, TDD and security docs; don't repeat them.

## Slice (trunk-based)

Estimate size in **added source lines only**; tests never count toward the budget. A PR is one concern, and roughly 1,000 added source lines or ~40 changed source files is the point to check that it still is (the size guide in your global agent instructions (`~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md`)).

- **Up to ~1,000 lines, or larger but one concern that is meaningless in parts:** one spec, one PR, a single file. For the larger case, say in the spec why it stays together.
- **Over ~1,000 lines and more than one concern:** slice into independently mergeable vertical slices, each one concern, under `docs/specs/NNN_<slug>/`. Never cut one concern into slices that only make sense together.

**Slicing rules:**
- Every slice leaves the trunk branch deployable. If a slice adds user-visible behavior that isn't ready, name a **feature flag** (default off).
- Slice **vertically** (DB, API, UI for *one* capability), not horizontally; horizontal slices pile up un-shippable intermediate state.
- No slice depends on an unmerged slice. If B truly needs A merged first, mark the dependency and don't start B until A is merged.
- Each slice is its own branch and PR. `/wf:feature` names the branch.

**Trunk metadata fields** (in the Slices table and in single-file specs):
- **Type:** conventional-commit prefix (`feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `perf`, `build`, `ci`, `security`). Drives the branch prefix and the `type:*` label.
- **Flag:** exact flag name (default off), or `none` if it ships user-ready. This is the single source for the flag.
- **Depends on:** other slice numbers or specs that must merge first; `—` if independent.
- **Complexity:** `low` is under ~300 added source lines, `med` under ~1,000, `high` is more than that or more than one concern. A `high` slice is a smell to re-slice; if you keep it, add a `## Slicing` section saying why one PR is still defensible.
- **Risk:** `T0`, `T1` or `T2` with a one-line why, e.g. `T2 — changes the session token format`. Pick it from **Risk tiers** in your global agent instructions (`~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md`), the one definition (highest match wins; when unsure take the higher). Size does not set it. `/wf:feature` re-checks it against the diff.
- **Issue:** `—` until `/wf:issues` fills it with `#<number>`.

**Sliced index** (`docs/specs/NNN_<slug>/README.md`). The Slices table is the source of truth for `/wf:issues`:

```markdown
# Feature: [Name]

## Problem
[One paragraph, shared context for all slices.]

## Slices

| # | Slice | Type | Flag | Depends on | Complexity | Risk | Issue |
|---|-------|------|------|------------|------------|------|-------|
| 001 | [slice-name](001_slice-name.md) | feat | `none` or `flag_name` | — | low/med/high | T1 — <why> | — |
| 002 | [slice-name](002_slice-name.md) | feat | `flag_name` | 001 | low/med/high | T2 — <why> | — |

## Rollout
[When each flag flips on, who owns the decision, what verifies the rollout.]
```

Write each sub-spec with the single-file template below, but omit Trunk Metadata: its Slices row is its metadata.

**Single-file specs** carry a short block near the top:

```markdown
## Trunk Metadata
- **Type:** feat
- **Flag:** `none` or `flag_name`
- **Depends on:** — | NNN | #N
- **Complexity:** low/med/high
- **Risk:** T1 — <one-line why>
- **Issue:** — (filled by `/wf:issues`)
```

## Write

Omit template sections that do not apply. Single spec or sub-spec:

```markdown
# Feature: [Name]

## Problem
[What problem does this solve? Who is affected?]

## Solution
[High-level approach. What changes and why.]

## Technical Design

### Affected Files
[Files to create or modify.]

### API Changes
[Endpoints, request/response shapes, error codes]

### Data Model
[Schema changes, migrations needed]

### Architecture
[Which components change and how they interact. Reference ARCHITECTURE.md if it exists. Copy the roadmap task's `Design reference` here for UI work.]

## Security Considerations
[Auth requirements, input validation, data exposure risks. Reference THREAT_MODEL.md if it exists.]

## Feature Flag
[Only when a flag exists: name, default off, when it flips.]

## Verification Criteria
Verification command: [command that runs these checks]

### Unit Tests
- [ ] [function/module]: [input] → [expected output]
- [ ] [validation]: [invalid input] → [expected error]
- [ ] [edge case]: [boundary condition] → [expected behavior]

### Integration Tests
- [ ] [API endpoint]: [request] → [response + status code]
- [ ] [database operation]: [action] → [expected state]
- [ ] [service interaction]: [call] → [expected result]

### E2E Tests (if applicable)
- [ ] [user flow]: [steps] → [expected outcome]

*Adapt the layers to what the feature touches: pure logic needs unit tests, an API feature unit + integration, a critical user flow all three. Reference the Testing Strategy in `docs/ARCHITECTURE.md` (in older projects, `docs/TECHNICAL_DESIGN_DOCUMENT.md`) if it exists.*

## Out of Scope
[What this does NOT include]
```

## After Writing

1. Present the spec to the user for review. Iterate until they're satisfied.
2. Commit the spec; `/wf:autopilot` needs specs on the trunk branch. If issues were already filed for it, re-run `/wf:issues <spec>` so they get the drift update.
3. Next step: `/wf:issues docs/specs/NNN_<name>.md` (or `.../NNN_<name>/README.md` for a sliced spec) fills the `Issue` field(s) so `/wf:feature` can name the branch from the issue number. Then `/wf:feature docs/specs/NNN_<name>.md` (single) or `/wf:feature docs/specs/NNN_<name>/MMM_<slice>.md` (one slice at a time).
