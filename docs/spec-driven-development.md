# Spec-Driven Development

> A methodology where specifications are the source of truth for all implementation, testing, and review. AI agents execute specs — not vague instructions.

---

## What is Spec-Driven Development?

Spec-Driven Development (SDD) is a workflow where every feature, fix, and architectural decision is defined in a specification **before** any code is written. The spec is the contract between the human (who decides *what* to build) and the AI agent (who decides *how* to build it).

The core insight: AI is a powerful executor but a poor decision-maker. When you give it a vague instruction like "add authentication", you get code that "looks right" but misses edge cases, security requirements, and integration constraints. When you give it a precise spec with verification criteria, you get code that's correct on the first pass.

**SDD is not waterfall.** Specs are living documents — they get refined through interviews, updated as constraints emerge, and versioned alongside the code. The key difference from ad-hoc prompting is that the spec exists as an artifact that can be reviewed, shared, and referenced by multiple agents.

---

## The Document Hierarchy

Specs don't exist in isolation. They form a layered system where each document builds on the ones above it:

```mermaid
graph TD
    PRD["/prd<br/>Product Requirements"]
    ARCH["/architecture<br/>System Architecture"]
    TDD["/tdd<br/>Technical Design"]
    SEC["/security<br/>Threat Model"]
    SPEC["/spec<br/>Feature Specs"]
    ROAD["/roadmap<br/>Task Breakdown"]
    DESIGN["/design + /verify-design<br/>UI design in Paper"]
    ISSUES["/issues<br/>GitHub milestones + issues"]
    IMPL["feature-dev · superpowers (plugins)<br/>Implementation"]
    REV["pr-review-toolkit (plugin)<br/>or code-review (Anthropic)<br/>Review"]

    PRD --> ARCH
    PRD --> TDD
    PRD --> SEC
    PRD --> DESIGN
    ARCH --> ROAD
    TDD --> ROAD
    SEC --> ROAD
    ROAD --> SPEC
    SPEC --> ISSUES
    ISSUES --> IMPL
    DESIGN --> IMPL
    IMPL --> REV

    style PRD fill:#4a90d9,stroke:#2c5f8a,color:#fff
    style ARCH fill:#7b68ee,stroke:#5a4fcf,color:#fff
    style TDD fill:#7b68ee,stroke:#5a4fcf,color:#fff
    style SEC fill:#7b68ee,stroke:#5a4fcf,color:#fff
    style SPEC fill:#2ecc71,stroke:#27ae60,color:#fff
    style ROAD fill:#f39c12,stroke:#d68910,color:#fff
    style ISSUES fill:#2ecc71,stroke:#27ae60,color:#fff
    style DESIGN fill:#9b59b6,stroke:#7d3c98,color:#fff
    style IMPL fill:#e74c3c,stroke:#c0392b,color:#fff
    style REV fill:#95a5a6,stroke:#7f8c8d,color:#fff
```

| Layer | Document | Purpose | Created by |
|-------|----------|---------|------------|
| **Why** | PRD | What we're building and why | `/prd` |
| **How (system)** | Architecture | System structure, components, data flow | `/architecture` |
| **How (process)** | TDD | Technical Design — testing, dev env, CI/CD, coding standards | `/tdd` |
| **How (security)** | Threat Model | Trust boundaries, attack surface, defenses | `/security` |
| **When** | Roadmap | Phased tasks from design docs, with dependencies and parallelism | `/roadmap` |
| **What (feature)** | Feature Spec | Detailed implementation spec per task in the roadmap | `/spec` |
| **Hand-off** | GitHub issue | One issue per task/slice, carrying its spec path — ready to be implemented | `/issues` |

The roadmap is generated from the design docs (PRD, architecture, TDD, threat model) — it breaks the project into phased tasks before detailed specs exist. Then each task gets a detailed feature spec (`/spec`) that references the architecture, technical design, and threat model. This means implementation agents have full context without needing everything repeated. Finally `/issues` files each task as a GitHub issue that links its spec — the planning chain ends there, with an issue ready to be implemented. Implementation and review are handled by marketplace plugins, not by this toolkit's skills.

---

## The Interview Pattern

Every spec is created through a structured interview, not a one-shot prompt. The interview pattern ensures completeness:

```mermaid
sequenceDiagram
    participant U as Human
    participant C as Claude (/spec)
    participant D as Existing Docs

    C->>D: Read PRD, Architecture,<br/>TDD, Threat Model
    C->>D: Explore codebase<br/>(inherited projects)
    C->>U: Interview: Problem & scope
    U->>C: Answers
    C->>U: Interview: Technical design,<br/>edge cases, security
    U->>C: Answers
    C->>U: Interview: Verification criteria<br/>(concrete test cases)
    U->>C: Answers
    C->>C: Write spec to<br/>docs/specs/<feature>.md
    C->>U: Present for review
    U->>C: Feedback / approval
    C->>C: Update spec
```

The interview goes deep on the hard parts: edge cases, failure modes, security boundaries, and concrete verification criteria with inputs and expected outputs. The human decides *what*; Claude asks the questions that ensure nothing is missed.

---

## From Spec to Code: The Implementation Pipeline

Once an issue and its spec exist, implementation is handed to Claude Code plugins from the `claude-plugins-official` marketplace (`feature-dev`, `superpowers`, `pr-review-toolkit` — see the README's "Required plugins"). This is where the cost of spec-writing pays off — every downstream step has clear inputs.

### Single Feature Flow

```mermaid
flowchart LR
    SPEC["Read Spec"] --> TEST_STRATEGY["Discover<br/>Test Strategy"]
    TEST_STRATEGY --> PLAN["Plan<br/>(if complex)"]
    PLAN --> IMPL["Implement<br/>+ Tests"]
    IMPL --> QUALITY["Lint<br/>Typecheck<br/>Tests"]
    QUALITY --> REVIEW["code-review skill<br/>(Anthropic)"]
    REVIEW --> FIX["Fix HIGH<br/>findings"]
    FIX --> COMMIT["Commit<br/>+ PR"]

    style SPEC fill:#2ecc71,stroke:#27ae60,color:#fff
    style REVIEW fill:#e74c3c,stroke:#c0392b,color:#fff
    style COMMIT fill:#4a90d9,stroke:#2c5f8a,color:#fff
```

For one issue, the `feature-dev` plugin drives the read → plan → implement → review part of this as a guided, interactive workflow. It is not spec-file driven by itself, so give it the issue and its spec path:

```
/feature-dev:feature-dev implement issue #42 per docs/specs/003_auth.md
```

It explores the codebase, asks clarifying questions, proposes approaches, implements after your approval, and runs its own quality review. Run a fresh reviewer on the diff (`/pr-review-toolkit:review-pr`, which reads uncommitted changes), then commit (`/commit`), push and open the PR (`gh pr create`). For a bug, the `superpowers` plugin's `systematic-debugging` skill replaces the spec step with a root-cause investigation.

### Executing Several Tasks

This toolkit no longer has a one-command pipeline that runs a whole roadmap or milestone and merges it. For several tasks, the `superpowers` plugin provides the building blocks:

- **`subagent-driven-development`** — a fresh implementer subagent per task, a review (spec compliance + code quality) after each, and a whole-branch review at the end.
- **`executing-plans`** — the same plan executed inline in one session, with one fresh-context review at the end.
- **`dispatching-parallel-agents`** — one agent per independent problem, run concurrently.

Each task still maps to one issue, one short-lived branch and one PR, and merging stays a human decision unless you say otherwise for that piece of work.

---

## The Review Layer

Every implementation goes through a review by a fresh reviewer before merge — never the session that wrote the code. In Claude Code, `/pr-review-toolkit:review-pr` runs specialized review agents over the diff (general code review, test coverage, silent failures, comments, type design, simplification) and aggregates the findings as critical / important / suggestions. For stack-aware review, use Anthropic's official `code-review` skill and hand it the matching language guide from `reviews/` (`go.md`, `rust.md`, `typescript.md`, `python.md`) as stack criteria. Security-sensitive changes also get `/sec-review`; the `architecture-reviewer` agent is available for structural changes.

```mermaid
flowchart TB
    TRIGGER["Branch with an implementation"]
    PRT["/pr-review-toolkit:review-pr<br/>(specialized review agents)"]
    CR["Anthropic code-review skill<br/>(+ reviews/*.md as stack criteria)"]
    SEC["/sec-review<br/>(security-sensitive changes)"]
    ARCH["architecture-reviewer agent<br/>(structural changes)"]

    TRIGGER --> PRT
    TRIGGER --> CR
    TRIGGER --> SEC
    TRIGGER --> ARCH

    PRT --> REPORT["Findings reported<br/>human decides the merge"]
    CR --> REPORT
    SEC --> REPORT
    ARCH --> REPORT

    style TRIGGER fill:#f39c12,stroke:#d68910,color:#fff
    style PRT fill:#2ecc71,stroke:#27ae60,color:#fff
    style CR fill:#2ecc71,stroke:#27ae60,color:#fff
    style SEC fill:#e74c3c,stroke:#c0392b,color:#fff
    style ARCH fill:#4a90d9,stroke:#2c5f8a,color:#fff
    style REPORT fill:#2ecc71,stroke:#27ae60,color:#fff
```

> The previous in-repo `/code-review` skill fanned out to three nested subagents (security, architecture, stack) loading `reviews/` guides as sectioned prompts. It was deprecated after a benchmark (`code-review-workspace/iteration-1/`) showed no detection lift over a no-skill baseline at ~1.5× the cost, and its nested subagents didn't execute in parallel as designed.

---

## Model Strategy: Quality Where It Matters

Not every task requires the same level of reasoning. The workflow uses a tiered model strategy to optimize cost without sacrificing quality where it matters most:

```mermaid
flowchart LR
    subgraph OPUS["Opus (highest reasoning)"]
        direction TB
        O1["Design & Planning"]
        O2["Implementation"]
        O3["Security Review"]
    end

    subgraph SONNET["Sonnet (efficient execution)"]
        direction TB
        S1["Architecture Review"]
        S2["Stack-Specific Review"]
    end

    style OPUS fill:#e74c3c,stroke:#c0392b,color:#fff
    style SONNET fill:#4a90d9,stroke:#2c5f8a,color:#fff
```

| Task Type | Model | Why |
|-----------|-------|-----|
| Spec writing, interviews, design | **Opus** | Creative reasoning, catching edge cases |
| Implementation (main session) | **Opus** | Complex design decisions |
| Security review | **Opus** | False negatives are catastrophic |
| Architecture review | **Sonnet** | Structured criteria, checklist-driven |
| Stack-specific review | **Sonnet** | Matching against loaded review guides |

The principle: **Opus for decisions, Sonnet for execution.** Security is the exception — even though it follows structured criteria, the cost of missing a vulnerability far outweighs the savings from a cheaper model.

---

## Quality Gates: Defense in Depth

SDD doesn't rely on any single gate. Quality is enforced at every layer:

```mermaid
flowchart TB
    subgraph L1["Layer 1: Hooks (every edit)"]
        H1["Lint on file change"]
        H2["Typecheck on file change"]
    end

    subgraph L2["Layer 2: Pre-commit (every commit)"]
        PC1["Full test suite"]
        PC2["Security scan (gitleaks)"]
        PC3["Type checking"]
    end

    subgraph L3["Layer 3: Agent Review (per feature)"]
        AR1["Security reviewer (Opus)"]
        AR2["Architecture reviewer (Sonnet)"]
        AR3["Stack-specific reviewer (Sonnet)"]
    end

    subgraph L4["Layer 4: CI/CD (per PR)"]
        CI1["Full build"]
        CI2["All test layers"]
        CI3["SAST + dependency scan"]
    end

    subgraph L5["Layer 5: Human Review (per PR)"]
        HR1["Business logic correctness"]
        HR2["Design decisions"]
        HR3["What's missing?"]
    end

    L1 --> L2 --> L3 --> L4 --> L5

    style L1 fill:#2ecc71,stroke:#27ae60,color:#fff
    style L2 fill:#4a90d9,stroke:#2c5f8a,color:#fff
    style L3 fill:#f39c12,stroke:#d68910,color:#fff
    style L4 fill:#e74c3c,stroke:#c0392b,color:#fff
    style L5 fill:#7b68ee,stroke:#5a4fcf,color:#fff
```

---

## When to Use What

Not every project needs every step. Here's a decision guide:

| Scenario | What to use |
|----------|-------------|
| Quick fix or small feature on existing project | `/spec` + `/issues`, then `/feature-dev:feature-dev` |
| New feature touching multiple components | `/spec` + `/issues`, then `/feature-dev:feature-dev` |
| Greenfield project | `/new-project` + `/prd` + `/architecture` + `/tdd` + `/security` + `/roadmap` + `/spec` + `/issues`, then `/feature-dev:feature-dev` per issue |
| Full roadmap with many features | All of the above; work through the issues with `superpowers`' `subagent-driven-development` or `executing-plans` (no one-command roadmap pipeline) |
| Architectural decision | `/adr` |
| Significant change needing team input | `/rfc` |
| Bug fix | `superpowers`' `systematic-debugging` skill (root cause first, no spec needed) |
| Security audit | `/sec-review` (standalone, 4 parallel agents on Opus) |
| Code review | `/pr-review-toolkit:review-pr` (multi-agent PR review) or Anthropic's `code-review` skill (stack-aware) |

---

## Key Principles

1. **Specs are contracts, not documentation.** They define what "done" means. Verification criteria are concrete test cases with inputs and expected outputs — not vague acceptance criteria.

2. **The human decides what; the AI decides how.** Specs capture decisions. Implementation agents have freedom in *how* they build, but not in *what* they build.

3. **Context flows down, never up.** Higher-level documents (PRD, architecture) inform lower-level ones (specs, roadmap). Implementation agents read the spec and its references — they don't need the full conversation history.

4. **Review is separate from writing.** The writer/reviewer pattern uses fresh sessions to avoid confirmation bias. The agent that wrote the code never reviews it.

5. **Security is non-negotiable.** Security review always runs on the highest-quality model. The cost of a missed vulnerability dwarfs any model cost savings.

6. **Parallel by default.** Worktrees, background agents, and phased roadmaps allow multiple streams of work without conflicts. The orchestrator stays thin — it tracks progress, not code.
