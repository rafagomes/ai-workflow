---
name: spec
description: "Create a feature implementation spec at docs/specs/NNN_<feature>.md (prefix mirrors the roadmap phase) — scope, approach, affected files, verification. Use when the user says 'spec out feature X', 'write the implementation plan for Y', 'turn this idea into a spec', 'document how we'll build this', or needs a doc an implementer (human or agent) can execute from later."
---
Create a feature implementation spec for: $ARGUMENTS

## Spec Numbering & Path

Every spec path starts with a zero-padded 3-digit prefix mirroring its **roadmap phase number**, so spec order matches roadmap order at a glance.

- **Single spec:** `docs/specs/NNN_<slug>.md`
- **Sliced spec:** `docs/specs/NNN_<slug>/` containing `README.md` (index) and `MMM_<slice>.md` files. The directory-vs-file distinction is how sliced specs are identified — the `NNN` prefix stays on the directory, never moves to the children.
- **Separator** between prefix and slug is `_`; within the slug, words are joined by `-` (e.g., `003_atlassian-integration.md`, never `atlassian_integration.md` and never without the prefix).

**Picking `NNN`:**
- If this spec implements a task in `docs/roadmap/NNN_<phase>.md`, use that same `NNN`. Check the roadmap file before picking.
- Multiple specs in one phase → disambiguate with letter suffixes `NNN.A_<name>.md`, `NNN.B_<name>.md`, in task order. A lone spec in a phase has no suffix.
- No roadmap yet → scan `docs/specs/` and use `max(existing) + 1`. Don't renumber later when a roadmap is added.
- **Never renumber an existing spec** — commits, PRs, and issues reference specs by path.

Before writing any file, state the target path and confirm it satisfies the rules above.

## Context Gathering

Read what already exists before interviewing:

1. **Existing docs:** `docs/PRD.md` or `docs/prd/`, `docs/ARCHITECTURE.md`, `docs/TECHNICAL_DESIGN_DOCUMENT.md`, `docs/THREAT_MODEL.md`, `README.md`, `CLAUDE.md`.
2. **Roadmap and specs directory:** list `docs/roadmap/` and `docs/specs/` to pick the correct `NNN` per the rules above.
3. **Existing spec for this feature** — if the user is revising, don't start from scratch.
4. **Inherited project with no docs:** read `README.md`, explore directory structure, read key entry points, check `git log --oneline -20`, read `package.json` / `Cargo.toml` / `pyproject.toml` / equivalent. Summarize what you learned to the user before the interview — "Here's what I understand about this project so far: ..."

## Interview

Use AskUserQuestion to nail down implementation details — precise enough that the feature can be implemented without further clarification.

1. **What exactly changes?** — Which components, APIs, data models are affected?
2. **API contract** — Exact endpoints, request/response shapes, error codes, status codes
3. **Data model** — Schema changes, migrations, new fields, new tables/collections
4. **Edge cases** — Invalid input? Dependencies down? Missing data? Concurrent requests?
5. **Security** — Auth requirements on new endpoints? Input validation rules? Data exposure risks?
6. **Verification** — How do we prove this works? Concrete test cases with inputs and expected outputs.
7. **Dependencies** — Does this depend on other work? Does other work depend on this?

Build on existing architecture, TDD, and security docs if they exist — reference them, don't repeat them.

## Slice (trunk-based)

Estimate implementation size in **source lines only** — tests are written in full regardless and never count toward the budget. Per the global **Trunk-Based Workflow** (root `CLAUDE.md`), each PR targets ≤200 non-test lines.

- **≤200 lines:** one spec, one PR. Single file at `docs/specs/NNN_<slug>.md`.
- **>200 lines:** slice into N independently mergeable vertical slices, each ≤200 lines, under `docs/specs/NNN_<slug>/`.

**Slicing rules:**
- Every slice must leave `main` deployable. If a slice adds user-visible behavior that isn't ready to ship, name a **feature flag** (default off) in its spec.
- Slice **vertically** (DB → API → UI for *one* capability), not horizontally. Vertical slices ship value; horizontal slices pile up un-shippable intermediate state.
- No slice depends on an unmerged slice. If B truly needs A merged first, mark the dependency and don't start B until A is merged.
- Each slice = its own branch, its own PR, deleted after merge. Branch naming: `<type>/<slice-slug>` before `/issues` runs, `<type>/<issue-number>-<slice-slug>` after (e.g., `feat/42-jira-sync`).

**Trunk metadata fields** (used in both the Slices table and single-file specs):
- **Type** — conventional-commit prefix (`feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `perf`, `security`). Drives the branch prefix and the `type:*` label on GitHub.
- **Flag** — exact flag name (default off), or `none` if the slice ships user-ready.
- **Depends on** *(sliced only)* — other slice numbers that must merge first; `—` if independent.
- **Complexity** — `low` / `med` / `high`. `high` is a smell that the slice should be re-sliced; if you keep it, include a `## Slicing` section explaining why one PR is still defensible.
- **Issue** — `—` until `/issues` fills it with `#<number>`, which then unlocks the issue-numbered branch name.

**Sliced index** (`docs/specs/NNN_<slug>/README.md`) — the Slices table is the **source of truth for `/issues`**:

```markdown
# Feature: [Name]

## Problem
[One paragraph — shared context for all slices.]

## Slices

| # | Slice | Type | Flag | Depends on | Complexity | Issue | Status |
|---|-------|------|------|------------|------------|-------|--------|
| 001 | [slice-name](001_slice-name.md) | feat | `none` or `flag_name` | — | low/med/high | — | Not started |
| 002 | [slice-name](002_slice-name.md) | feat | `flag_name` | 001 | low/med/high | — | Not started |

## Rollout
[When each flag flips on, who owns the decision, what verifies the rollout.]
```

Write each sub-spec using the single-file template below.

**Single-file specs** add the same metadata as a short block near the top:

```markdown
## Trunk Metadata
- **Type:** feat
- **Flag:** `none` or `flag_name`
- **Complexity:** low/med/high
- **Issue:** — (filled by `/issues`)
- **Branch (post-/issues):** `<type>/<issue-number>-<slug>`
```

## Write

Single (≤200 line) spec or sub-spec:

```markdown
# Feature: [Name]

## Problem
[What problem does this solve? Who is affected?]

## Solution
[High-level approach. What changes and why.]

## Technical Design

### API Changes
[Endpoints, request/response shapes, error codes]

### Data Model
[Schema changes, migrations needed]

### Architecture
[Which components change. How they interact. Reference ARCHITECTURE.md if it exists.]

## Security Considerations
[Auth requirements, input validation, data exposure risks. Reference THREAT_MODEL.md if it exists.]

## Feature Flag
[Flag name and default state, or `None — slice is user-ready on merge`.]

## Verification Criteria

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

*Adapt the layers to what the feature touches. A pure logic change may only need unit tests. An API feature needs unit + integration. A critical user-facing flow needs all three. Reference the Testing Strategy in `docs/TECHNICAL_DESIGN_DOCUMENT.md` if it exists.*

## Out of Scope
[What this does NOT include]
```

## After Writing

1. Present the spec to the user for review. Iterate until they're satisfied.
2. Suggest next steps based on what exists:
   - No architecture doc? → "Define system structure with `/architecture`"
   - No TDD? → "Define testing and dev workflow with `/tdd`"
   - No threat model and there are security concerns? → "Consider `/security`"
   - Spec approved? → "File GitHub issues with `/issues docs/specs/NNN_<name>.md` (or `/issues docs/specs/NNN_<name>/README.md` for a sliced spec). This populates the `Issue` column and unlocks `<type>/<issue-number>-<slug>` branch naming."
   - Issues filed? → "The issue and its spec are ready to be implemented. In Claude Code, hand both to the `feature-dev` plugin: `/feature-dev:feature-dev implement issue #<N> per docs/specs/NNN_<name>.md` (single) or `... per docs/specs/NNN_<name>/MMM_<slice>.md` (one slice at a time)."
