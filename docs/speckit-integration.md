# Using ai-workflow with GitHub Spec Kit

ai-workflow and [GitHub Spec Kit](https://github.com/github/spec-kit) solve overlapping problems from different angles. This guide shows how to combine them into a single workflow that plays to each tool's strengths.

## Where Each Tool Shines

| Phase | ai-workflow | Spec Kit |
|-------|-------------|----------|
| **Requirements** | Deep interview-driven PRDs (`/prd`) | Structured spec templates (`/speckit.specify`) |
| **Principles** | Global conventions via `CLAUDE.md` | Project constitution (`/speckit.constitution`) |
| **Architecture** | Dedicated architecture docs (`/architecture`) | Embedded in implementation plan (`/speckit.plan`) |
| **Technical design** | Dedicated TDD docs — testing, dev env, CI/CD, standards (`/tdd`) | Test-first enforcement via constitution articles |
| **Threat modeling** | Dedicated security docs + agents (`/security`) | Available via community extensions |
| **Feature specs** | `/spec` with verification criteria | `/speckit.specify` with acceptance criteria |
| **Task breakdown** | `/roadmap` with phase dependencies, `/issues` to file them on GitHub | `/speckit.tasks` with parallelization markers |
| **Implementation** | Not in the toolkit — handed to Claude Code plugins (`feature-dev`, `superpowers`) | `/speckit.implement` |
| **Code review** | `/sec-review`, language guides in `reviews/` for Anthropic's `code-review` skill; PR review via the `pr-review-toolkit` plugin | Community extensions |
| **Security review** | Dedicated agents + `/sec-review` | Community extensions |
| **Governance** | `/adr`, `/rfc` at any point | Constitution amendments |

**ai-workflow** is deeper on design, planning, and review.
**Spec Kit** is stronger on structured templates, traceability, and agent-agnostic portability.

Together, they cover the full lifecycle without gaps.

## Combined Workflow

```mermaid
flowchart TD
    subgraph Discovery ["Discovery & Requirements"]
        A["/prd — Interview-driven PRD"] --> B["PRD document"]
    end

    subgraph Design ["System Design"]
        B --> C["/architecture"]
        B --> D["/tdd"]
        B --> E["/security"]
        C --> F["Architecture doc"]
        D --> G["Technical Design Doc"]
        E --> H["Threat model"]
    end

    subgraph Constitution ["Project Governance"]
        F --> I["/speckit.constitution"]
        G --> I
        H --> I
        I --> J["Constitution<br/>(informed by ai-workflow design docs)"]
    end

    subgraph Planning ["Roadmap & Task Breakdown"]
        F --> R["/roadmap<br/>(from all design docs)"]
        G --> R
        H --> R
        R --> TASKS["Phases with tasks"]
    end

    subgraph Specification ["Spec Per Task"]
        TASKS --> K{Choose spec tool}
        K -->|"Deep context needed"| L["/spec — ai-workflow"]
        K -->|"Template traceability needed"| M["/speckit.specify — Spec Kit"]
        L --> N["Detailed feature specs"]
        M --> N
    end

    subgraph Execution ["Implementation"]
        N --> T["/issues<br/>then feature-dev plugin per issue"]
        N --> U["/speckit.implement"]
    end

    subgraph Review ["Review & Quality"]
        T --> W["pr-review-toolkit plugin + code-review (Anthropic)"]
        U --> W
        W --> X["/sec-review"]
        X --> Y["Merge"]
    end

    style Discovery fill:#e8f4f8,stroke:#2196F3
    style Design fill:#e8f4f8,stroke:#2196F3
    style Constitution fill:#fff3e0,stroke:#FF9800
    style Planning fill:#f3e5f5,stroke:#9C27B0
    style Specification fill:#f3e5f5,stroke:#9C27B0
    style Execution fill:#e8f5e9,stroke:#4CAF50
    style Review fill:#e8f4f8,stroke:#2196F3
```

## The Three Integration Patterns

Depending on your team and project, you can integrate at different levels.

### Pattern 1: ai-workflow for design, Spec Kit for execution

Best for: teams that want deep upfront design with structured, traceable task execution.

```mermaid
flowchart LR
    subgraph AW ["ai-workflow"]
        direction TB
        A1["/prd"] --> A2["/architecture"]
        A2 --> A3["/tdd"]
        A3 --> A4["/security"]
        A4 --> A5["/roadmap"]
    end

    subgraph SK ["Spec Kit — Specify & Execute"]
        direction TB
        B1["/speckit.constitution"] --> B2["/speckit.specify<br/>per task"]
        B2 --> B3["/speckit.plan"]
        B3 --> B4["/speckit.tasks"]
        B4 --> B5["/speckit.implement"]
    end

    subgraph AW2 ["ai-workflow — Review"]
        direction TB
        C1["code-review (Anthropic)"] --> C2["/sec-review"]
    end

    AW -->|"Roadmap + design docs"| SK
    SK -->|"PRs ready"| AW2

    style AW fill:#e8f4f8,stroke:#2196F3
    style SK fill:#fff3e0,stroke:#FF9800
    style AW2 fill:#e8f4f8,stroke:#2196F3
```

**Steps:**

1. `/prd` — interview and capture requirements
2. `/architecture` + `/tdd` + `/security` — design the system (architecture, technical design, threat model)
3. `/roadmap` — break the design into phased tasks from all available design docs
4. `/speckit.constitution` — encode architecture decisions and coding standards as constitutional articles
5. `/speckit.specify` — create detailed, traceable specs for each task in the roadmap
6. `/speckit.plan` — technical implementation plan per spec
7. `/speckit.tasks` + `/speckit.implement` — execute
8. Anthropic's `code-review` + `/sec-review` — review with language-aware agents

**Why this works:** ai-workflow's interview-driven design phase produces richer context than going straight to Spec Kit templates. The roadmap gives structure *before* detailed specs exist. Then Spec Kit's constitutional compliance and task traceability keep specification and implementation disciplined. ai-workflow's review agents catch what CI can't.

---

### Pattern 2: Spec Kit for structure, ai-workflow for power

Best for: teams that like Spec Kit's template discipline but need ai-workflow's phasing, GitHub issues and deep review. In this pattern, Spec Kit leads the design and specification — ai-workflow takes over for phasing, issue filing and review, with execution handed to Claude Code plugins.

```mermaid
flowchart LR
    subgraph SK ["Spec Kit — Design & Specify"]
        direction TB
        A1["/speckit.constitution"] --> A2["/speckit.specify"]
        A2 --> A3["/speckit.plan"]
        A3 --> A4["/speckit.tasks"]
    end

    subgraph AW ["ai-workflow — Phase, File & Review"]
        direction TB
        B1["/roadmap<br/>(from Spec Kit tasks)"] --> B2["/issues<br/>Milestones + issues"]
        B2 --> B3["Plugins: feature-dev / superpowers<br/>Implement per issue"]
        B3 --> B4["pr-review-toolkit + code-review (Anthropic)"]
        B4 --> B5["/sec-review"]
    end

    SK -->|"tasks.md"| AW

    style SK fill:#fff3e0,stroke:#FF9800
    style AW fill:#e8f4f8,stroke:#2196F3
```

**Steps:**

1. `/speckit.constitution` — establish project principles
2. `/speckit.specify` — create structured feature specs (Spec Kit leads here)
3. `/speckit.plan` — technical implementation plan
4. `/speckit.tasks` — generate task list with `[P]` parallelization markers
5. `/roadmap` — convert Spec Kit tasks into phased roadmap with dependencies
6. `/issues` — file one milestone per phase and one issue per task
7. Implement each issue with the `feature-dev` plugin (`/feature-dev:feature-dev implement issue #<N> per <spec path>`), or work through several with the `superpowers` plugin's `subagent-driven-development` skill
8. `/pr-review-toolkit:review-pr` + Anthropic's `code-review` + `/sec-review` — full review pipeline

**Why this works:** Spec Kit's templates enforce structure that prevents vague specs. ai-workflow's `/roadmap` then phases those tasks with dependency ordering and `/issues` turns them into trackable, independently mergeable units of work. ai-workflow itself no longer ships a one-command pipeline that executes the roadmap; execution is done by plugins or by `/speckit.implement`.

---

### Pattern 3: Cherry-pick the best of each

Best for: solo developers or small teams that want flexibility.

Pick the tool that fits each phase:

| Phase | Recommended | Why |
|-------|-------------|-----|
| Requirements | `/prd` (ai-workflow) | Interactive interview surfaces edge cases better than filling templates |
| Principles | `/speckit.constitution` (Spec Kit) | Constitutional articles are more enforceable than CLAUDE.md conventions |
| Architecture | `/architecture` (ai-workflow) | Dedicated doc is easier to reference than embedded plan sections |
| Technical design | `/tdd` (ai-workflow) | Separate doc covers testing, dev env, CI/CD, and coding standards |
| Roadmap | `/roadmap` (ai-workflow) | Generates phased tasks from all available design docs before detailed specs exist |
| Feature spec | Either — depends on the feature | Use `/spec` for complex features needing deep context; `/speckit.specify` for well-understood features needing traceability |
| Task breakdown | `/speckit.tasks` (Spec Kit) | Better traceability with `[P]` markers and spec references |
| Implementation | `feature-dev` / `superpowers` plugins (Claude Code) or `/speckit.implement` | `/feature-dev:feature-dev` for one issue at a time with codebase exploration and clarifying questions; `superpowers`' `subagent-driven-development` for several tasks; `/speckit.implement` when you are not on Claude Code |
| Code review | Anthropic's `code-review` skill + ai-workflow's language guides in `reviews/` | Language-specific review guides are deeper |
| Security review | `/sec-review` (ai-workflow) | Dedicated parallel analysis agents |
| Governance | `/adr` (ai-workflow) | Lightweight and can be created at any point |

---

## Setting Up Both Tools

### Install ai-workflow

```bash
git clone https://github.com/0xrafasec/ai-workflow.git
cd ai-workflow
./install.sh
```

### Install Spec Kit

```bash
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git@v0.1.4
```

Then initialize in your project:

```bash
cd your-project
specify init .
```

### Connecting the Design Docs

When running `/speckit.constitution`, reference the ai-workflow design docs:

```
Create the project constitution. Use these documents as input:
- Architecture: docs/architecture.md
- Technical design: docs/tdd.md
- Security: docs/security.md

Encode the key decisions from these documents as constitutional articles.
```

When running `/speckit.plan`, reference the feature spec:

```
/speckit.plan

Use the feature spec at docs/specs/feature-name.md as the primary input.
The architecture is defined in docs/architecture.md.
```

### Feeding Spec Kit Tasks into ai-workflow

Convert `tasks.md` into a roadmap:

```
/roadmap

Read the tasks from .speckit/features/NNN-feature-name/tasks.md.
Group them into phases based on dependencies.
Tasks marked [P] can run in parallel within the same phase.
```

Then file the issues and implement them one at a time:

```
/issues docs/roadmap/001_feature-name.md
/feature-dev:feature-dev implement issue #<N> per <spec path>
```

### Roadmap → Specify Per Feature

The most natural integration point: use ai-workflow for the high-level phases, then Spec Kit (or `/spec`) to detail each feature before execution.

```mermaid
flowchart TD
    DOCS["Design docs<br/>(PRD, Architecture, TDD, Security)"] --> ROAD["/roadmap<br/>Phase breakdown"]

    ROAD --> P1["Phase 1"]
    ROAD --> P2["Phase 2"]
    ROAD --> P3["Phase 3"]

    P1 --> T1A["Task: Auth system"]
    P1 --> T1B["Task: Database schema"]

    P2 --> T2A["Task: API endpoints"]
    P2 --> T2B["Task: Background jobs"]

    P3 --> T3A["Task: Dashboard UI"]

    T1A --> S1A["/speckit.specify or /spec<br/>Detailed spec for auth"]
    T1B --> S1B["/speckit.specify or /spec<br/>Detailed spec for schema"]
    T2A --> S2A["/speckit.specify or /spec<br/>Detailed spec for API"]
    T2B --> S2B["/speckit.specify or /spec<br/>Detailed spec for jobs"]
    T3A --> S3A["/speckit.specify or /spec<br/>Detailed spec for UI"]

    S1A --> E1["/issues, then plugins<br/>Execute Phase 1"]
    S1B --> E1
    S2A --> E2["/issues, then plugins<br/>Execute Phase 2"]
    S2B --> E2
    S3A --> E3["/issues, then plugins<br/>Execute Phase 3"]

    E1 --> R1["code-review (Anthropic) + /sec-review"]
    E2 --> R2["code-review (Anthropic) + /sec-review"]
    E3 --> R3["code-review (Anthropic) + /sec-review"]

    style DOCS fill:#1976D2,stroke:#0D47A1,color:#fff
    style ROAD fill:#7B1FA2,stroke:#4A148C,color:#fff
    style P1 fill:#9C27B0,stroke:#6A1B9A,color:#fff
    style P2 fill:#9C27B0,stroke:#6A1B9A,color:#fff
    style P3 fill:#9C27B0,stroke:#6A1B9A,color:#fff
    style T1A fill:#F57C00,stroke:#E65100,color:#fff
    style T1B fill:#F57C00,stroke:#E65100,color:#fff
    style T2A fill:#F57C00,stroke:#E65100,color:#fff
    style T2B fill:#F57C00,stroke:#E65100,color:#fff
    style T3A fill:#F57C00,stroke:#E65100,color:#fff
    style S1A fill:#388E3C,stroke:#1B5E20,color:#fff
    style S1B fill:#388E3C,stroke:#1B5E20,color:#fff
    style S2A fill:#388E3C,stroke:#1B5E20,color:#fff
    style S2B fill:#388E3C,stroke:#1B5E20,color:#fff
    style S3A fill:#388E3C,stroke:#1B5E20,color:#fff
    style E1 fill:#2E7D32,stroke:#1B5E20,color:#fff
    style E2 fill:#2E7D32,stroke:#1B5E20,color:#fff
    style E3 fill:#2E7D32,stroke:#1B5E20,color:#fff
    style R1 fill:#1976D2,stroke:#0D47A1,color:#fff
    style R2 fill:#1976D2,stroke:#0D47A1,color:#fff
    style R3 fill:#1976D2,stroke:#0D47A1,color:#fff
```

**The flow:**

1. `/prd` — capture product requirements through an interview
2. `/roadmap` — break the PRD into phased work (even without detailed specs yet)
3. **Per task in each phase:** run `/spec <task-name>` or `/speckit.specify` to create a detailed, traceable spec
4. `/issues` — file the phase's issues, now that every task has a spec; then implement each one (`feature-dev` / `superpowers` plugins, or `/speckit.implement`)
5. Anthropic's `code-review` + `/sec-review` — review before merging

**Why this matters:** You don't always have detailed specs upfront. Often you have a PRD and a rough idea of phases. The roadmap gives you structure and ordering; then you specify each task *just before* implementing it, with the full roadmap context available. This avoids specifying tasks that might change as earlier phases are completed.

**When to specify all upfront vs. per-phase:**

| Approach | When to use |
|----------|-------------|
| Specify all tasks before starting | Small project, well-understood domain, stable requirements |
| Specify per phase (just-in-time) | Large project, evolving requirements, later phases depend on learnings from earlier ones |
| Mix — specify Phase 1 fully, others loosely | Most common — get started fast, refine as you learn |

## Lifecycle Overview

```mermaid
graph TB
    subgraph Idea ["From Idea..."]
        I((Idea))
    end

    subgraph Requirements ["Requirements"]
        I --> PRD["/prd<br/>Interview & capture"]
    end

    subgraph Design ["Design"]
        PRD --> ARCH["/architecture"]
        PRD --> TDD["/tdd"]
        PRD --> SEC["/security"]
    end

    subgraph Governance ["Governance"]
        ARCH --> CONST["/speckit.constitution"]
        TDD --> CONST
        SEC --> CONST
        ADR["/adr — decisions"] -.->|"anytime"| CONST
        RFC["/rfc — proposals"] -.->|"anytime"| CONST
    end

    subgraph Planning ["Planning"]
        PRD --> ROAD["/roadmap<br/>Phase breakdown"]
    end

    subgraph Specification ["Specify Per Feature"]
        ROAD --> SPEC["/spec or /speckit.specify<br/>per task in each phase"]
        CONST --> SPEC
    end

    subgraph Implementation ["Implementation"]
        SPEC --> AUTO["/issues<br/>GitHub milestones + issues"]
        AUTO --> FEAT["feature-dev / superpowers plugins<br/>Per issue"]
        SPEC --> IMPL["/speckit.implement"]
    end

    subgraph Review ["Review"]
        FEAT --> CR["code-review (Anthropic)"]
        IMPL --> CR
        CR --> SR["/sec-review"]
        SR --> REV["pr-review-toolkit plugin<br/>Writer/reviewer separation"]
    end

    subgraph Ship ["...to Production"]
        REV --> MERGE((Merge & Ship))
    end

    style Idea fill:#fce4ec,stroke:#E91E63
    style Requirements fill:#e8f4f8,stroke:#2196F3
    style Design fill:#e8f4f8,stroke:#2196F3
    style Governance fill:#fff3e0,stroke:#FF9800
    style Specification fill:#f3e5f5,stroke:#9C27B0
    style Planning fill:#f3e5f5,stroke:#9C27B0
    style Implementation fill:#e8f5e9,stroke:#4CAF50
    style Review fill:#e8f4f8,stroke:#2196F3
    style Ship fill:#e8f5e9,stroke:#4CAF50
```

## When to Use Which

| Scenario | Recommendation |
|----------|---------------|
| Greenfield project, solo developer | ai-workflow plus its three Claude Code plugins — less setup, full lifecycle |
| Team with mixed AI tools (Copilot, Cursor, Claude) | Spec Kit for specs + implementation (agent-agnostic), ai-workflow for design, roadmap, issues + review |
| Existing Spec Kit project, want better reviews | Add ai-workflow's `/sec-review`, plus Anthropic's `code-review` skill with this repo's `reviews/` guides |
| Existing ai-workflow project, want better traceability | Add Spec Kit's `/speckit.constitution` and `/speckit.tasks` |
| Large project, many parallel features | Both — Spec Kit for structure, ai-workflow `/roadmap` + `/issues` for phasing; execute with the `superpowers` plugin or `/speckit.implement` |
| Compliance-heavy project | Both — Spec Kit constitution for enforcement, ai-workflow `/sec-review` for auditing |
