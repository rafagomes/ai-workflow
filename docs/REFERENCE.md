# Workflow Toolkit Reference

> Quick reference for all agents, skills, settings, and conventions — and how to install them on Claude Code, Cursor, and Codex CLI.

---

## Table of Contents

1. [Overview](#overview)
2. [Installation](#installation)
3. [Global Agents](#global-agents)
4. [Language-Specific Review Guides](#language-specific-review-guides)
5. [Global Skills](#global-skills)
6. [Global Settings](#global-settings)
7. [Global CLAUDE.md](#global-claudemd)
8. [File Map](#file-map)
9. [Daily Usage](#daily-usage)

---

## Overview

This toolkit implements the workflow described in [WORKFLOW.md](./WORKFLOW.md), built around the branching model in [TRUNK_BASED_WORKFLOW.md](./TRUNK_BASED_WORKFLOW.md). It provides:

- **Agents** — specialized reviewers that can be spawned as subagents
- **Skills** — reusable workflows (`/prd`, `/architecture`, `/tdd`, `/security`, `/adr`, `/rfc`, `/spec`, `/roadmap`, `/feature`, `/fix`, `/commit`, `/pr`, `/review`, `/sec-review`, `/autopilot`, `/factory`, `/new-project`, `/design`, `/verify-design`). For stack-aware code review, use Anthropic's official `code-review` skill from `claude-code-plugins`.
- **Settings** — notification hooks for parallel work (Claude Code)
- **CLAUDE.md** — global defaults applied to every project

The toolkit supports three platforms. Each installs everything from the same source:

| Platform | Installed to | Invocation |
|----------|-------------|------------|
| Claude Code | `~/.claude/` (symlinks) | `/skill-name` slash commands |
| Cursor | `~/.cursor/rules/aiwf-*.mdc` (generated) | `"follow the /spec workflow for X"` |
| Codex CLI | `~/.agents/skills/aiwf-*/` (symlinked native skills) + `~/.codex/AGENTS.md` (compiled global context) | `$skill-name` at the prompt (e.g. `$spec`, `$roadmap`) or describe the task |

---

## Installation

### One-liner (auto-detects all installed platforms)

```bash
curl -fsSL https://raw.githubusercontent.com/0xrafasec/ai-workflow/main/bootstrap.sh | bash
```

### Per-platform

```bash
aiwf install           # Claude Code — symlinks into ~/.claude/
aiwf install-cursor    # Cursor — generates ~/.cursor/rules/aiwf-*.mdc
aiwf install-codex     # Codex CLI — symlinks skills into ~/.agents/skills/ + writes ~/.codex/AGENTS.md
aiwf install-all       # all three at once
```

### Manage

```bash
aiwf status            # health check across all platforms
aiwf update            # git pull + re-link Claude Code
aiwf install-all       # re-run after update to refresh Cursor and Codex
aiwf uninstall-all     # remove from all platforms
aiwf help              # full command reference
```

### After modifying skills or config

Skill edits take effect immediately for Claude Code and Codex — both use symlinks (`~/.claude/skills/`, `~/.agents/skills/aiwf-*/`). Re-run the adapter only when:

- **Adding/removing skills** → run `aiwf install-codex` (new symlinks) or `aiwf install` (Claude)
- **Editing global conventions, agents, or review guides** → run `aiwf install-codex` (these are compiled into `~/.codex/AGENTS.md`, not symlinked)
- **Any Cursor change** → always run `aiwf install-cursor` (generated MDC files)

```bash
aiwf install-cursor    # regenerate Cursor rules
aiwf install-codex     # re-link skills + recompile AGENTS.md
```

---

## Global Agents

Agents are spawned as subagents during implementation or review. They run in isolation and return a report.

### security-reviewer

**File:** `~/.claude/agents/security-reviewer.md`

**Purpose:** Reviews code for security vulnerabilities.

**What it checks:**
| Category | Examples |
|----------|----------|
| Injection | SQL, NoSQL, command injection, XXE, template injection, prototype pollution |
| Auth | Authentication bypass, privilege escalation, session management, JWT issues |
| Secrets | Hardcoded API keys, passwords, tokens in source code |
| Crypto | Weak algorithms, missing timing-safe comparisons |
| Data exposure | Sensitive data in logs, API leakage, debug info in production |
| Web | XSS via unsafe methods, SSRF (host/protocol control), open redirects |
| Config | CI/CD injection, insecure defaults, CORS misconfiguration |

**Filtering:**
- Only reports findings with confidence >= 8/10
- Only HIGH or MEDIUM severity
- Excludes noise: DoS, .env in .gitignore, test-only issues, regex DoS, client-side auth, outdated libs

**Output:** Numbered findings with file:line, severity, description, and before/after fix code. Ends with positive practices.

---

### architecture-reviewer

**File:** `~/.claude/agents/architecture-reviewer.md`

**Purpose:** Reviews code for architectural consistency and quality.

**What it checks:**
| Criteria | Description |
|----------|-------------|
| Pattern consistency | Does new code follow existing codebase patterns? |
| Separation of concerns | No god objects, no business logic in controllers |
| Unnecessary abstractions | Flags premature generalization and over-engineering |
| API contract stability | Do changes break existing contracts? |
| Dependency hygiene | Are new dependencies justified and maintained? |
| Error handling | Errors handled at the right layer? |
| Testability | Is code structured for easy testing? |

**Output:** Numbered concerns with file:line, severity (HIGH/MEDIUM/LOW), issue, suggestion. Ends with summary of what's good.

---

## Language-Specific Review Guides

Review guides provide language and framework-specific criteria. They are loaded on demand by `/review`, `/feature`, and `/fix`, and can be passed as stack criteria to Anthropic's official `code-review` skill (from `claude-code-plugins`).

### Go (`reviews/go.md`)

**Security focus:** unchecked errors, goroutine leaks, race conditions, `os/exec` injection, `math/rand` misuse, missing HTTP timeouts, `unsafe` package, CGo, template injection.

**Architecture focus:** project structure (`cmd/`, `internal/`), interface design (accept interfaces/return structs, small interfaces), error patterns (sentinel errors, no panic in libraries), concurrency (channel ownership, context propagation, errgroup), testing (table-driven, `t.Helper()`).

### Rust (`reviews/rust.md`)

**Security focus:** `unsafe` blocks (justification required), FFI boundaries (null pointers, panic across FFI), `unwrap()` in library code, integer overflow, `serde` deserialization with untrusted input, `zeroize` for secrets, `cargo audit`.

**Architecture focus:** ownership patterns (excessive `.clone()`, `Rc`/`Arc` proliferation), type system (newtypes, typestate), error design (`thiserror` for libs, `anyhow` for apps), async patterns (blocking in async, cancellation safety, `Send` bounds), module structure (`pub` visibility, re-exports).

### TypeScript (`reviews/typescript.md`)

Covers **Node.js**, **Next.js**, and **Nest.js** with framework-specific sections for each.

**Security focus:** prototype pollution, `eval()`/`child_process.exec()`, JWT in localStorage, missing `sameSite` cookies. **Next.js:** server actions as public endpoints, RSC data leaks, env var exposure. **Nest.js:** missing guards, unvalidated DTOs, exposed internal errors.

**Architecture focus:** type safety (`any` usage, type assertions, Zod at boundaries), async patterns (missing `await`, sequential vs parallel), module design. **Next.js:** client/server boundary, data fetching strategy, route segment config. **Nest.js:** module boundaries, provider scope, dependency injection, repository pattern.

### Python (`reviews/python.md`)

Covers **FastAPI**, **Django**, **Flask**, and general Python.

**Security focus:** `eval()`/`exec()`, `pickle.loads()`, `yaml.load()`, f-string SQL, path traversal, `random` vs `secrets`. **Django:** `DEBUG=True`, `ALLOWED_HOSTS`, raw SQL, CSRF exemption. **FastAPI:** missing response models, WebSocket auth. **Flask:** debug mode, hardcoded secret key.

**Architecture focus:** type hints (`Any` usage, `# type: ignore`), error handling (bare `except`, silenced exceptions), async patterns (blocking in async). **Django:** fat models, manager methods, signals overuse. **FastAPI:** dependency injection, router organization, async all the way. **Testing:** pytest fixtures, factory pattern, mocking boundaries.

---

## Global Skills

Skills are invoked as slash commands. They orchestrate multi-step workflows.

### /prd

**File:** `~/.claude/skills/prd/SKILL.md`

**Purpose:** Interview the user and create a Product Requirements Document. This is the starting point for new projects or major features.

**Usage:**
```
/prd credential-delegation-protocol
/prd user-dashboard-redesign
```

**What it does:**
1. Checks for existing docs (won't duplicate what's already written)
2. Deep interviews you — problem, solution, scope, users, success criteria, constraints, risks
3. Writes to `docs/PRD.md` (or `docs/prd/<name>.md` for sub-feature PRDs)
4. Presents for review and iterates
5. Suggests next steps: which specs to create

**Document structure produced:**
- Problem statement
- Solution overview
- Design principles (non-negotiable properties)
- Scope (in/out with reasons)
- User types
- Key flows
- Success criteria
- Constraints (technical, business, regulatory)
- Risks and open questions
- Future work

---

### /architecture

**File:** `~/.claude/skills/architecture/SKILL.md`

**Purpose:** Create or update the system architecture document.

```
/architecture
```

**Interview focus:** Components, data flow, technology choices, deployment model, scaling, integration points, key decisions and tradeoffs.

**Writes to:** `docs/ARCHITECTURE.md`

**Document structure:**
- System overview (with Mermaid diagram)
- Components (responsibility, technology, interfaces, design decisions)
- Data flow (with diagrams for critical paths)
- Technology stack table with rationale
- Deployment model
- Key decisions table (decision, choice, alternatives, rationale)
- Constraints and limitations

**Context awareness:** Reads existing PRD, docs, and codebase before interviewing. For inherited projects, explores the codebase first and summarizes what it found.

---

### /tdd

**File:** `~/.claude/skills/tdd/SKILL.md`

**Purpose:** Create or update the Technical Design Document — testing strategy, dev environment, CI/CD, coding standards, tooling.

```
/tdd
```

**Interview focus:** Test frameworks and layers (unit/integration/e2e), dev environment setup, CI/CD pipeline, coding standards, tooling decisions, observability, dependency management.

**Writes to:** `docs/TECHNICAL_DESIGN_DOCUMENT.md`

**Document structure:**
- Testing Strategy (source of truth for `/feature`, `/fix`, `/roadmap`, `/autopilot`)
  - Test layers table (scope, framework, run command, when to write)
  - Test conventions (location, naming, fixtures, CI behavior)
  - Coverage expectations per layer
- Dev environment (setup, external dependencies)
- CI/CD pipeline (PR checks, deployment)
- Coding standards (linter, formatter, type checker)
- Tooling table with rationale
- Error handling & observability
- Dependency management

**Context awareness:** Explores existing test directories, CI config, linter config, and package files before interviewing.

---

### /security

**File:** `~/.claude/skills/security/SKILL.md`

**Purpose:** Create or update the threat model and security spec.

```
/security
```

**Interview focus:** Trust boundaries, auth/authz, sensitive data inventory, attack surface, threat actors, compliance requirements, existing security measures.

**Writes to:** `docs/THREAT_MODEL.md`

**Document structure:**
- Trust assumptions (with Mermaid trust hierarchy)
- Security properties (non-negotiable invariants)
- Attack surface table
- Threats by category (attack, impact, likelihood, defense)
- Sensitive data inventory (classification, protection at rest/transit, access control)
- Security controls (implemented vs required)
- Compliance requirements

**Context awareness:** Explores auth middleware, input validation, database queries, secrets management, and exposed endpoints before interviewing.

---

### /adr

**File:** `~/.claude/skills/adr/SKILL.md`

**Purpose:** Create an Architecture Decision Record. Lightweight, numbered, captures one decision.

```
/adr use-postgresql-over-mongodb
/adr switch-to-grpc
```

**Interview focus:** What's the decision, context/constraints, options considered with tradeoffs, the choice and why, consequences.

**Writes to:** `docs/adr/NNNN-<slug>.md` (auto-numbered)

**Document structure:**
- Status (Proposed/Accepted/Deprecated/Superseded)
- Context
- Decision
- Options considered (pros/cons for each)
- Consequences (positive, negative, neutral)
- Related links

---

### /rfc

**File:** `~/.claude/skills/rfc/SKILL.md`

**Purpose:** Create a Request for Comments for significant changes needing team discussion.

```
/rfc migrate-to-event-sourcing
/rfc new-auth-system
```

**Interview focus:** Proposal, motivation, scope, high-level design, alternatives, migration plan, risks, open questions.

**Writes to:** `docs/rfc/NNNN-<slug>.md` (auto-numbered)

**Document structure:**
- Summary (elevator pitch)
- Motivation
- Proposal with key design decisions
- Alternatives considered
- Migration plan
- Risks and open questions
- Feedback requested
- References

---

### /spec

**File:** `~/.claude/skills/spec/SKILL.md`

**Purpose:** Create a feature implementation spec. Focused on a single feature — the actionable document that `/feature` reads and implements.

```
/spec user-authentication
/spec payment-processing
/spec webhook-system
```

**Interview focus:** Exact API changes, data model changes, edge cases, security considerations, verification criteria (concrete test cases with inputs and outputs).

**Writes to:** `docs/specs/<feature_name>.md`

**Document structure:**
- Problem
- Solution
- Technical design (API changes, data model, architecture)
- Security considerations
- Verification criteria by test layer:
  - Unit tests (function/module level)
  - Integration tests (API, database, service boundaries)
  - E2E tests (critical user flows, if applicable)
- Out of scope

**Context awareness:** Reads existing architecture, TDD, and security docs to build on them rather than repeat them. For inherited projects, explores the codebase first.

---

### /feature

**File:** `~/.claude/skills/feature/SKILL.md`

**Purpose:** Implement a feature end-to-end from a spec file.

**Usage:**
```
/feature docs/specs/auth.md                    # implement + verify
/feature docs/specs/auth/001_models.md         # implement one slice of a sliced spec
```

**Stops with a working tree the user can review.** You ship via `/commit` + `/pr` after reviewing the diff.

**What it does:**
1. Reads the spec thoroughly
2. Checks for a matching roadmap task in `docs/roadmap/`
3. Discovers test strategy — reads `docs/TECHNICAL_DESIGN_DOCUMENT.md` or infers from codebase (test directories, frameworks, patterns)
4. Plans the implementation (enters Plan Mode if complex)
5. Implements with tests at the right layers (unit, integration, e2e) based on the test strategy
6. Runs lint, typecheck, and all test layers
7. Spawns a **fresh-context reviewer subagent** (sonnet, cold context — never the in-context `code-review` skill, which would violate writer/reviewer separation). Reviewer reads only the diff + spec + ≤3 files it doubts, returns a structured `VERDICT: PASS | FIX_REQUIRED` block with HIGH/MED/LOW findings
8. If `FIX_REQUIRED`: fixes the listed action items in the warm writer context (no respawn — the writer already has the spec/files loaded), re-runs the quality gate, re-dispatches the reviewer on the new diff. Bounded to **2 fix cycles**; after that, reports `NEEDS_HUMAN` with unresolved items and a "Spec ambiguity suspected" note when the same finding survived a cycle
9. Reports files changed, verification output, review verdict (`PASS` / `PASS_WITH_NITS` / `NEEDS_HUMAN`), and slice metadata for the PR body — then stops

---

### /fix

**File:** `~/.claude/skills/fix/SKILL.md`

**Purpose:** Diagnose and fix a bug with proper regression tests.

**Usage:**
```
/fix users can't login with special chars         # diagnose + patch + verify
/fix https://github.com/org/repo/issues/42        # fix from issue
```

**Stops with a working tree the user can review.** You ship via `/commit` + `/pr` after reviewing the diff.

**What it does:**
1. Understands the bug (from description or GitHub issue)
2. Searches the codebase to locate the relevant code paths
3. Diagnoses root cause — traces data flow, checks git history
4. Discovers test strategy from `docs/TECHNICAL_DESIGN_DOCUMENT.md` or codebase
5. Fixes with minimal change + regression tests at the right layer(s)
6. Runs quality checks and a stack-aware code review (Anthropic's `code-review` skill, or `/sec-review` + architecture-reviewer)
7. Reports root cause, files changed, regression tests, verification output, and a suggested `fix:` commit subject — then stops

---

### /commit

**File:** `~/.claude/skills/commit/SKILL.md`

**Purpose:** Stage and commit the working tree as one or more logical conventional commits — never a single bundled "update everything" commit.

**Usage:**
```
/commit
```

**Default and only behavior:** local-only. Never pushes, force-pushes, amends, or touches the remote.

**What it does:**
1. Surveys the tree (`git status`, `git diff --stat`, `git log --oneline -10`) to match existing commit style
2. Reads the actual diffs for any files whose change isn't obvious from the path
3. Groups changes by logical concern — a bug fix and an unrelated refactor become separate commits
4. Drafts conventional-commit messages (feat/fix/refactor/docs/test/chore/perf/security/build/ci), imperative mood, under 72 chars, body only when the *why* is non-obvious
5. **Presents the full commit plan** (files + messages) and waits for approval. Accepts targeted edits ("merge 2 and 3", "reword commit 1 as...")
6. Stages explicit paths (`git add <file>`, never `git add .` or `-A`) and commits each group sequentially with a HEREDOC message
7. Never uses `--no-verify`. On pre-commit hook failure: stops, shows the error, asks how to proceed — never `--amend` to hide a failure
8. Reports final `git status` + `git log --oneline -N`

Pushing and PR creation are `/pr`'s job.

---

### /pr

**File:** `~/.claude/skills/pr/SKILL.md`

**Purpose:** Open a pull request for the current branch. Assumes commits already exist.

**Usage:**
```
/pr                    # normal, review-ready PR
/pr --draft            # draft PR (WIP, early CI feedback, review conversation)
```

**What it does:**
1. Checks preconditions: working tree clean (otherwise tells you to run `/commit` first), not on `main`/`master`, there are commits ahead of the base branch
2. Pushes the current branch if it has no upstream or is ahead — never force-pushes without explicit confirmation, never force-pushes to `main`/`master`
3. Analyzes **all** commits in `<base>..HEAD` (not just the tip) to draft the PR
4. Drafts a title under 70 chars, **no type prefix** (`feat:` / `fix:` belong in commits, not PR titles)
5. Drafts a body with Summary → Spec (if one exists in `docs/specs/`) → Security checklist (only if the diff touches auth / crypto / input validation / secrets / external APIs) → Test plan
6. Presents the draft for approval, accepts edits, then creates the PR via `gh pr create --title ... --body ...` with HEREDOC, adding `--draft` only if requested
7. Returns the PR URL

Does not merge, request reviewers, add labels, or close issues — those are explicit follow-ups.

---

### /roadmap

**File:** `~/.claude/skills/roadmap/SKILL.md`

**Purpose:** Create a phased task breakdown from specs.

**Usage:**
```
/roadmap                              # scan all specs, create full roadmap
/roadmap auth-system                  # single phase
/roadmap docs/specs/feature_x.md      # roadmap for one spec
```

**What it does:**
1. Reads project context (PRD, architecture, TDD, existing specs)
2. Interviews about priorities, dependencies, parallelization, team context
3. Creates `docs/roadmap/` with phased tasks — each with spec path, files, dependencies, test layers, verification command
4. Identifies parallel vs sequential tasks, critical path

**Each task specifies:** which test layers are needed (unit/integration/e2e) based on the TDD.

---

### /review

**File:** `~/.claude/skills/review/SKILL.md`

**Purpose:** Review a branch or PR using the writer/reviewer pattern.

**Usage:**
```
/review                    # review current branch vs main
/review feature-auth       # review a specific branch
/review 42                 # review PR #42
```

**What it does:**
1. Gathers the diff and commit history
2. Finds the relevant spec in `docs/specs/`
3. Spawns **security-reviewer** and **architecture-reviewer** subagents in parallel
4. Reviews business logic, design decisions, missing cases, test coverage, and spec compliance
5. Produces a consolidated report with verdict: APPROVE, REQUEST_CHANGES, or COMMENT

**Important:** This is a read-only review. It flags issues with line references — it does not rewrite the implementation. Best used in a **fresh session** (not the one that wrote the code).

---

### /new-project

**File:** `~/.claude/skills/new-project/SKILL.md`

**Purpose:** Scaffold a new project with the full workflow structure.

**Usage:**
```
/new-project my-api python/fastapi
/new-project my-cli go
/new-project my-app typescript/nextjs
/new-project my-service            # will ask what stack to use
```

**Arguments:**
- `<project-name>` (required) — the directory name to create
- `[language/framework]` (optional) — the tech stack, used to tailor Makefile, linter, .gitignore, pre-commit hooks to that ecosystem. Examples: `python`, `python/fastapi`, `go`, `rust`, `typescript/nextjs`. If omitted, you'll be asked.

**Where it creates the project:** In your **current working directory** (`$PWD/<project-name>/`). Navigate to the desired parent directory first if needed.

**What it creates:**

```
<project-name>/
  CLAUDE.md                          # Project-specific Claude instructions
  Makefile                           # test, lint, typecheck, build, security-scan targets
  .gitignore                         # Language-appropriate + .claude/ + .env
  .pre-commit-config.yaml            # Linter + type checker + tests + gitleaks
  .claude/
    settings.json                    # Hooks (lint on edit)
    agents/
      security-reviewer.md           # Tailored to project language
      architecture-reviewer.md       # Tailored to project language
  docs/
    specs/                           # Feature specifications go here
    roadmap/                         # Phase/task breakdowns go here
    adr/                             # Architecture decision records
    rfc/                             # Requests for comments
```

Skills are installed globally — no project-level copies needed.

**After scaffolding, the suggested next steps are:**
1. `cd <project-name>`
2. `pre-commit install`
3. `/prd <project-name>` — write the product requirements
4. `/architecture` — define the system structure
5. `/tdd` — Technical Design Document (testing, dev environment, CI/CD, coding standards)
6. `/security` — define the threat model (if applicable)
7. `/spec <first-feature>` — write your first feature spec
8. `/feature docs/specs/<first-feature>.md` — implement it

---

### /autopilot

**File:** `~/.claude/skills/autopilot/SKILL.md`

**Purpose:** Execute an entire roadmap **autonomously, end to end**. For every task in every phase it runs the full pipeline — **develop → review → fix → merge to `main`** — and loops until the roadmap is delivered or a genuine blocker stops it. **No human gate by default; it self-merges.** This is the deliberate contrast with `/factory`, which builds one milestone's PRs and stops with them open for a human to merge — `/autopilot` *merges*. Pass `--supervised` to restore per-phase human checkpoints.

**Usage:**
```
/autopilot docs/roadmap.md              # autonomous: build, review, fix, merge — all phases
/autopilot docs/roadmap.md --supervised # stop at each phase boundary with PRs open for human merge
```

**How it works (per task):**

```
Orchestrator (stays thin: parse, dispatch, triage, MERGE, track, loop)
  |
  Phase N → waves of tasks (no shared files, deps merged first):
  |  for each task:
  |    1. Writer agent (worktree, sonnet) ── implements + tests + verifies ──→ PR
  |    2. Reviewer agent (FRESH context, sonnet, own worktree) ── re-runs the
  |         build itself, checks spec compliance ──→ VERDICT: PASS | FIX_REQUIRED
  |    3. Security gate (/sec-review, opus) ── only for risky diffs ──→ HIGH blocks merge
  |    4. Fix loop ── resume the writer via SendMessage with action items, max 2 cycles,
  |         else park as NEEDS_HUMAN
  |    5. MERGE ── orchestrator runs `gh pr merge --rebase --delete-branch`, removes worktrees
  |    6. Tick roadmap status, commit (docs:), continue
  |  → autonomous: roll straight into Phase N+1 (its deps are now on main)
  |  → --supervised: stop at the phase boundary for human review + merge
```

**Writer ≠ reviewer.** Review always runs as a separate agent with cold context — never the writing session, never the orchestrator. The reviewer **runs the verification itself**; a green claim from the writer is not evidence.

**Merge authority.** Invoking autopilot in the default mode grants it authority to merge to `main`. It will not squash (preserves the writer's logical commit split), waits for a dependency's **merge** before branching dependent work, and never puts two file-overlapping tasks in the same parallel wave. If `main` is protected against direct/auto merge, it switches to `--supervised` and says so.

**Checkpoint commands (`--supervised` only):**
- `continue` — proceed to next phase
- `retry <task>` — re-run a failed task
- `skip <task>` — skip a task and continue
- `stop` — halt and summarize progress

**Stops (even autonomous) on:** a build/finding that survives 2 fix cycles, an unresolvable merge conflict, a missing/contradictory spec, a HIGH+ security finding it can't safely fix, an unmergeable protected `main`, or any destructive/irreversible action outside the roadmap's scope.

**Why context isn't lost:** The orchestrator never reads implementation files. Each writer/reviewer gets its own context window with only its task's spec + diff. The orchestrator tracks task name, status, PR URL, verdict, blockers — and keeps roadmap status committed so an interrupted run is resumable.

**Requirements for the roadmap:**
- Specs committed and on `main` (worktree agents can't see untracked files)
- Phases in dependency order; each task names spec path, files, dependencies, verification command
- Parallel tasks must touch different files

---

### /code-review (deprecated)

This skill was removed after a benchmark (see `code-review-workspace/iteration-1/benchmark.md`) showed no detection lift over a no-skill baseline on planted-bug fixtures at ~1.5× the cost, and its parallel-subagent architecture didn't execute as designed when nested.

**Replacement:** install Anthropic's official `code-review` skill from `claude-code-plugins`. Language-specific criteria remain in this repo under `reviews/` (`go.md`, `rust.md`, `typescript.md`, `python.md`) and can be passed as stack criteria, or loaded directly by `/review`, `/feature`, and `/fix`.

---

### /sec-review

**File:** `~/.claude/commands/sec-review.md` *(delivered as a command rather than a `skills/<name>/SKILL.md` entry — it behaves as a slash-command skill in every other respect.)*

**Purpose:** Detailed security audit with parallel analysis agents. More thorough than the security-reviewer agent — this is a full audit tool.

**Usage:**
```
/sec-review                # diff mode vs main
/sec-review full           # full codebase scan
/sec-review diff develop   # diff vs specific branch
/sec-review full src/      # full scan scoped to a directory
```

**What it does:**
1. Spawns 4 parallel agents: injection, auth/crypto, data exposure/web, config/supply chain
2. Each agent reads every file, traces data flow, assigns confidence scores
3. Consolidates findings, deduplicates, filters by confidence >= 8
4. Produces a structured report with verdict (PASS/REVIEW/FAIL) and positive practices

---

### /design

**File:** `~/.claude/skills/design/SKILL.md`

**Purpose:** Produce distinctive, production-grade UI designs in Paper.design MCP — a full design system + brand guide + every screen from the PRD, or a single flow/screen. Commits to a bold aesthetic direction (editorial, brutalist, luxury, retro-futuristic, technical, etc.) rather than defaulting to generic AI-SaaS looks.

**Usage:**
```
/design                    # full: design system + brand guide + every screen in the PRD
/design auth               # only the named flow group (reuses existing design system)
/design auth/login         # a single screen and all its states
/design --system-only      # refresh the design system + component library only
/design --layouts-only     # skip system phase, go straight to layouts
```

**What it does:**
1. Reads `docs/PRD.md`, `ARCHITECTURE.md`, `THREAT_MODEL.md`, and existing specs to extract screens and flows
2. Runs a short `AskUserQuestion` interview (aesthetic, palette, typography, density, references) and commits to a direction
3. Writes `docs/design/DESIGN_SYSTEM.md` (tokens, typography, spacing, components, accessibility)
4. Builds a "Design System" and "Component Library" artboard in Paper (light + dark), then all flow-group artboards at desktop (1440×900) + mobile (390×844), with dark variants per group
5. Stops at review checkpoints using `AskUserQuestion` — never monologues through an entire canvas

**Requires:** a PRD or at least one feature spec. Runs on Opus/Sonnet — Haiku produces flatter layouts.

---

### /verify-design

**File:** `~/.claude/skills/verify-design/SKILL.md`

**Purpose:** Diff the running UI against Paper design refs with Playwright runtime checks, then fix mismatches in place. Not a report tool — it edits code and re-verifies.

**Usage:**
```
/verify-design                       # every page that has a design ref
/verify-design owner                 # one route/page
/verify-design web/components/Hero.tsx   # one component
```

**What it does:**
1. Resolves design references (`docs/design/`, spec artboard IDs, `DESIGN_SYSTEM.md`)
2. Loads Paper artboards (desktop + mobile) via MCP — reads computed styles, never guesses from screenshots
3. Drives the running dev server with Playwright at `1440x900` and `390x844`, captures screenshots + console errors, exercises interactive flows
4. **Fixes** mismatches in place (prefers token fixes over ad-hoc values), re-runs Playwright + lint + typecheck + tests
5. Severity model: HIGH = wrong font/color, broken responsive, runtime errors, inoperable controls, clipping; MEDIUM = off by >2 steps, hardcoded-instead-of-token; LOW = ≤2px drift

**Rules:** never skip Playwright, never skip responsive checks, token violations are at minimum MEDIUM, missing loading/empty/error states are HIGH. If Playwright is unavailable it stops rather than silently degrading to static-only.

---

### /factory

**File:** `~/.claude/skills/factory/SKILL.md`

**Purpose:** Single-milestone/phase delivery pipeline. Implements every open issue in **one** GitHub milestone (== one roadmap phase) as parallel, conflict-free PRs, each pre-reviewed by a fresh-context reviewer agent. Stops with all PRs open for human merge — **no auto-merge**. For multi-phase end-to-end execution, use `/autopilot`.

**Convention:** roadmap phase file `docs/roadmap/<NNN>_<name>.md` corresponds to a GitHub milestone whose **title is exactly `<NNN>_<name>`**. `/issues` files them this way.

**Usage:**
```
/factory 003_auth            # phase name → resolves matching milestone by title
/factory --milestone 5       # milestone number → resolves matching phase file
/factory 003_auth --dry-run  # scan + plan batches, spawn nothing
/factory 003_auth --no-issues
/factory 003_auth --limit 3  # override the 5-agent parallel cap
```

A phase/milestone is **required** — bare `/factory` is rejected with a pointer to `/autopilot` for multi-phase runs.

**What it does:**
1. **Preflight** — repo root, clean tree, `gh auth`, lint/typecheck/test commands resolved
2. **Milestone scan** — pulls open issues from the milestone (closed = done, excluded), greps spec path from each issue body, falls back to the phase roadmap file for unmapped issues
3. **File-overlap batching** — greedy bin-packer groups features into batches of ≤5 such that no two features in a batch touch the same file (ported from `/autopilot`)
4. **Spec generation** — for issues without a spec, runs `/speckit-spec` + `/speckit-plan` + `/speckit-tasks` sequentially
5. **Quality-gate hook** — registers a `Stop` hook running `lint && typecheck && tests`; restored at end
6. **Parallel writers** — per batch, ≤5 worktree agents (`sonnet`, `run_in_background: true`) implement, pass the gate, commit, push, open PR. Writers do **not** review themselves
7. **Per-PR review loop** — fresh-context reviewer subagent (sonnet, no worktree) per PR, parallel across PRs in the batch. Reads only the diff + spec + ≤3 files. Returns structured `VERDICT: PASS | FIX_REQUIRED`. On `FIX_REQUIRED`, the **writer agent is resumed via `SendMessage`** (warm context — the cheap path) with the action items, fixes, re-pushes, and the reviewer re-runs on the new diff only. Bounded to 2 fix cycles, then escalates to PR comment as `NEEDS_HUMAN`. Spec-ambiguity is auto-detected when the same finding survives a cycle
8. **Summary + cleanup** — posts a per-feature results table with review verdicts (PASS / PASS_WITH_NITS / NEEDS_HUMAN / BLOCKED), restores the `Stop` hook

**Token discipline:** orchestrator (opus) never reads diffs or review prose — only compact `{verdict, cycles, pr_url}` returns. Reviewers are sonnet with bounded scope. Fixers are warm writers, never respawned. Estimated overhead vs. unreviewed: +20-30% common case, +60-80% worst case (2 cycles), with reviewers running parallel so wall-clock is barely affected.

**Hard rules:** orchestrator never writes code, never reads diffs; no auto-merge; writers never review their own code; fixer = writer resumed (never a fresh agent); review loop capped at 2 cycles; one milestone per invocation.

---

## Global Settings

**File:** `~/.claude/settings.json`

### Notification Hooks

Desktop notifications fire whenever Claude needs your attention. Essential for parallel worktree sessions where you're not watching every terminal.

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "notify-send 'Claude Code' '$CLAUDE_NOTIFICATION'"
          }
        ]
      }
    ]
  }
}
```

Uses `notify-send` (Linux/Freedesktop). Fires on any notification event from Claude.

### Other Settings

| Setting | Value | Purpose |
|---------|-------|---------|
| `defaultMode` | `bypassPermissions` | No permission prompts |
| `model` | `claude-opus-4-8[1m]` | Default model. Per-profile — set it in each profile's own `settings.json`. Use a full model id (`claude-opus-4-8[1m]`, `claude-opus-5`, `claude-sonnet-5`) rather than an alias when you want a specific variant such as the 1M-context window. |
| `statusLine` | custom command | Custom status line script |
| `statusLine.refreshInterval` | `30` | Re-runs the status line every 30s so the rate-limit reset countdown stays live while idle |

---

## Global CLAUDE.md

**Source:** `dotfiles/CLAUDE.md` in this repo. **Installed at:** `~/.claude/CLAUDE.md` (symlink created by `install.sh`).

These defaults apply to **every project** unless overridden by a project-level CLAUDE.md. The ai-workflow repo itself has a separate project-level `CLAUDE.md` at the repo root (rules for editing skills, updating docs, version bumps); it loads only when working inside the repo and is not installed globally.

**Key rules:**
- Spec first, code second
- Conventional commits: `feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`, `security:`
- Split commits by logical concern
- `/sec-review` before PR on security-sensitive changes
- Writer/reviewer pattern: never review in the same session that wrote the code
- No unnecessary abstractions
- Validate at system boundaries only
- Tests must cover spec verification criteria
- PRs: one concern, under 200 lines **excluding tests**, with summary + spec link + security checklist + test plan
- `/clear` between tasks, `/compact` mid-task, `/rewind` after 2 failed corrections

---

## File Map

### Source repo

```
ai-workflow/
  CLAUDE.md                              # Global conventions (source of truth)
  settings.json                          # Hooks, permissions, model (Claude Code)
  statusline-command.sh                  # Custom status line (Claude Code)
  aiwf                                   # Toolkit manager CLI
  install.sh / uninstall.sh              # Claude Code symlink installer
  bootstrap.sh                           # Multi-platform one-liner installer
  .claude-plugin/marketplace.json        # Plugin marketplace listing mods/ (installed via `claude plugin install`, not install.sh)
  mods/
    english-coach/                       # Grammar + fluency feedback on every prompt (see README "Mods")
    toolbar/                             # Model/effort card, VS Code button and clean view (see README "Mods")
  adapters/
    cursor/
      install.sh                         # Generates ~/.cursor/rules/aiwf-*.mdc
      uninstall.sh
    codex/
      install.sh                         # Symlinks skills into ~/.agents/skills/aiwf-* + compiles ~/.codex/AGENTS.md
      uninstall.sh
  agents/
    security-reviewer.md
    architecture-reviewer.md
  commands/
    sec-review.md
  reviews/
    go.md / rust.md / typescript.md / python.md
  skills/
    prd / architecture / tdd / security / adr / rfc /
    spec / roadmap / feature / fix / commit / pr /
    review / autopilot / new-project /
    design / verify-design / factory
    # (feature-workspace/ exists alongside but is benchmarking data, not a skill —
    #  it has no top-level SKILL.md so install adapters skip it.)
```

### Claude Code install (`~/.claude/`)

The install directory is `~/.claude` unless `CLAUDE_DIR` says otherwise. Claude Code supports isolated profiles through its own `CLAUDE_CONFIG_DIR`, and each profile carries its own `skills/`, `agents/`, `commands/` and `CLAUDE.md` — so each one needs a separate `install.sh` run with `CLAUDE_DIR` pointed at it. Everything in the table below is shared toolkit and installs into every profile **except `settings.json`**, which is profile-local (account, theme, model, status line, enabled plugins): only the primary `~/.claude` gets the repo's copy. That is derived from `CLAUDE_DIR` rather than a flag so it survives `aiwf update` / `aiwf reinstall`; `--with-settings` and `--no-settings` force it either way. `uninstall.sh` reads the same `CLAUDE_DIR`, removes only symlinks (a profile-local `settings.json` is never touched), and leaves the shared `~/.local/bin/aiwf` launcher alone unless it is cleaning the primary dir.

```
~/.claude/
  CLAUDE.md                              # Global defaults for all projects
  settings.json                          # Notification hooks, permissions, model
  statusline-command.sh                  # Custom status line script
  agents/
    security-reviewer.md
    architecture-reviewer.md
  commands/
    sec-review.md                        # /sec-review — detailed security audit
  reviews/
    go.md / rust.md / typescript.md / python.md
  skills/
    prd/SKILL.md                         # /prd
    architecture/SKILL.md                # /architecture
    tdd/SKILL.md                         # /tdd
    security/SKILL.md                    # /security
    adr/SKILL.md                         # /adr
    rfc/SKILL.md                         # /rfc
    spec/SKILL.md                        # /spec
    roadmap/SKILL.md                     # /roadmap
    feature/SKILL.md                     # /feature
    fix/SKILL.md                         # /fix
    commit/SKILL.md                      # /commit
    pr/SKILL.md                          # /pr
    review/SKILL.md                      # /review
    autopilot/SKILL.md                   # /autopilot
    new-project/SKILL.md                 # /new-project
    design/SKILL.md                      # /design
    verify-design/SKILL.md               # /verify-design
    factory/SKILL.md                     # /factory
```

### Cursor install (`~/.cursor/rules/`)

```
~/.cursor/rules/
  aiwf-global.mdc                        # Global conventions (alwaysApply: true)
  aiwf-skill-prd.mdc
  aiwf-skill-architecture.mdc
  aiwf-skill-tdd.mdc
  aiwf-skill-security.mdc
  aiwf-skill-adr.mdc
  aiwf-skill-rfc.mdc
  aiwf-skill-spec.mdc
  aiwf-skill-roadmap.mdc
  aiwf-skill-feature.mdc
  aiwf-skill-fix.mdc
  aiwf-skill-commit.mdc
  aiwf-skill-pr.mdc
  aiwf-skill-review.mdc
  aiwf-skill-autopilot.mdc
  aiwf-skill-new-project.mdc
  aiwf-skill-design.mdc
  aiwf-skill-verify-design.mdc
  aiwf-skill-factory.mdc
  aiwf-agent-security-reviewer.mdc
  aiwf-agent-architecture-reviewer.mdc
  aiwf-review-go.mdc
  aiwf-review-rust.mdc
  aiwf-review-typescript.mdc
  aiwf-review-python.mdc
```

### Codex CLI install

Codex uses two locations: native skill discovery at `~/.agents/skills/`,
and a compiled global-context file at `~/.codex/AGENTS.md`.

```
~/.agents/skills/
  aiwf-spec     -> <repo>/skills/spec/       # symlinks — each dir has a SKILL.md
  aiwf-roadmap  -> <repo>/skills/roadmap/    # invoke at the prompt as $spec,
  aiwf-feature  -> <repo>/skills/feature/    # $roadmap, $feature, etc.
  ... (one per skill, aiwf- prefix avoids collisions)

~/.codex/
  AGENTS.md                        # Compiled: global workflow conventions,
                                   # agent definitions, review guides. Skills
                                   # are NOT duplicated here — Codex loads
                                   # them natively from ~/.agents/skills/.
  config.toml                      # Installer ensures project_doc_max_bytes
                                   # is large enough to read AGENTS.md in
                                   # full (Codex default is 32 KiB).
```

**Invocation:** type `$<name>` at the Codex prompt — e.g. `$spec`,
`$roadmap`, `$commit`. Codex also matches skills implicitly by their
`description:` frontmatter, so you can just describe the task.

---

## Daily Usage

### New project from scratch
```
cd ~/Projects
/new-project my-app python/fastapi     # Scaffold structure
cd my-app
/prd my-app                            # Define what we're building
/architecture                          # Define how it's structured
/tdd                                   # Define testing, dev env, CI/CD
/security                              # Define the threat model
/spec user-authentication              # First feature spec
/feature docs/specs/user-authentication.md  # Implement it
```

### Joining an inherited project
```
cd ~/Projects/existing-app
/architecture                          # It reads the codebase first, then interviews you
/tdd                                   # Discovers existing test setup, fills gaps
/security                              # Same — explores before asking
/spec new-feature                      # Feature spec, building on what exists
```

### Automated full roadmap execution
```
/autopilot ROADMAP.md                  # Executes phase by phase
# → Phase 1: dispatches agents, waits, shows PRs
# → "continue" to proceed to Phase 2
# → "retry task-name" if something failed
# → "stop" to halt
```

### Parallel work with worktrees (manual)
```bash
claude --worktree task-a --tmux        # Terminal 1
claude --worktree task-b --tmux        # Terminal 2
# Desktop notifications tell you when each needs attention
```

### Reviewing work
```
# In a FRESH session (not the one that wrote the code):
/review                                 # Review current branch
/review feature-auth                    # Review specific branch
```

### Security audit
```
/sec-review                             # Diff mode vs main
/sec-review full                        # Full codebase scan
/sec-review diff develop                # Diff vs specific branch
```

### Context management
```
/clear                                  # Between unrelated tasks
/compact                                # When context gets heavy
/rewind                                 # When an approach keeps failing
```

---

## Document Pipeline

The typical flow from idea to code:

```
/prd                    "What are we building and why?"
  |
  v
/architecture           "How is the system structured?"
/tdd                    "How do we build, test, and ship?"
/security               "What are the threats and defenses?"
  |
  v
/roadmap                "Phase breakdown with tasks, deps, parallelism"
  |                     (generated from PRD + architecture + TDD + threat model)
  v
/spec <feature>         "Exact implementation details for this feature"
  |                     (references architecture, TDD, security docs)
  |
  +--→ /design [flow]   "UI designs in Paper — design system + screens"
  |      |              (run after PRD, before or alongside specs for UI work)
  |      v
  |    /verify-design   "Diff running UI against Paper refs, fix in place"
  |
  +--→ /autopilot       "Execute the whole roadmap with parallel worktree agents"
  |
  +--→ /factory <phase> "One milestone/phase: parallel PRs + per-PR review loop"
  |
  +--→ /feature <spec>  "Or implement one feature at a time manually"
       |
       v
     /review             "Independent review in a fresh session"

/fix <issue|stack>      "Diagnose and fix a bug (anytime, no spec needed)"
/adr <title>            "Capture a decision (anytime)"
/rfc <title>            "Propose a significant change (anytime)"
```

Not every project needs every step. A small feature on an existing project might just need `/spec <feature>` and `/feature`. A greenfield project with a full roadmap can use `/autopilot` to execute it all.
