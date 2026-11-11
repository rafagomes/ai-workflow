---
name: architecture
description: "Create or update docs/ARCHITECTURE.md — the system (components, data flow, stack, deployment, key decisions) and how it is engineered (testing strategy, dev environment, CI/CD, coding standards). Use when the user wants to design or document the system, map how the pieces fit, define a testing strategy or repo conventions, or says 'how should this be structured', 'let's architect this', 'how should we test this', 'write the tech design doc'. Documents CI/CD but does not create pipeline files."
argument-hint: "[focus area]"
---
Create or update the architecture document. Argument: $ARGUMENTS

`docs/ARCHITECTURE.md` has two parts. **System** says what is being built and how the pieces fit. **Engineering** says how it is built, tested and shipped. They live in one file because they share the stack and deployment decisions, and because `/wf:spec`, `/wf:feature`, `/wf:fix` and `/wf:autopilot` read both before touching code.

With a focus area (e.g. `testing`), update only that part and leave the rest.

## Context Gathering

Read what already exists before asking anything:

1. **Existing docs** — `docs/ARCHITECTURE.md` (if revising, don't start from scratch), `docs/PRD.md` or `docs/prd/`, `docs/THREAT_MODEL.md`, `README.md`, the project's agent instructions (`CLAUDE.md` or `AGENTS.md`), any whitepaper or design doc.
2. **Legacy split** — if `docs/TECHNICAL_DESIGN_DOCUMENT.md` exists, the project predates the merged document. Read it, carry its content into the Engineering part, and ask whether to delete it once the merged file is written.
3. **The codebase:**
   - Directory structure and key entry points (main files, route definitions, config).
   - `package.json`, `Cargo.toml`, `pyproject.toml`, `go.mod`, `Makefile`, `docker-compose.yml` — dependencies, tooling, test commands.
   - Test directories and 1–2 existing test files, to see the patterns (fixtures, helpers, naming).
   - CI config (`.github/workflows/`, `.gitlab-ci.yml`) and linter/formatter config.
   - `git log --oneline -20` for recent direction.

With no codebase yet, derive the document from the PRD and mark unconfirmed choices `(proposed)`. In a monorepo, describe the repo-level toolchain once and note per-package differences.

## Interview

Summarize what you learned first ("Here's what I understand about this project so far: ..."), then ask only what the code and docs do not answer, using AskUserQuestion in 3–4 rounds of at most 3–4 questions. For an inherited project, ask "is my understanding correct?" and "what would you change?" rather than "what do you want?". For a greenfield project with a PRD, propose a stack and ask for corrections instead of asking open questions. If the user cannot be asked (a headless run), write from what exists and list each assumption under Constraints and Limitations.

**System**

1. **Components** — What are the main components/services/modules? How do they communicate? Where are the trust boundaries?
2. **Data flow** — How does data enter, get processed, and get stored? What are the critical paths?
3. **Technology choices** — What stack and why? Hard constraints versus preferences?
4. **Deployment** — How does this run (single binary, services, serverless) and where?
5. **Scale and performance** — Expected load? Where are the bottlenecks? What must be fast?
6. **Integration points** — What external systems does it talk to? What does it expose?
7. **Key decisions** — What has already been decided, and what tradeoffs were accepted?

**Engineering**

8. **Testing strategy** — Which frameworks? Where do tests live? Which layers exist (unit / integration / e2e), and what belongs in each? Which flows need e2e coverage?
9. **Dev environment** — How does someone set up locally? Which external services are needed?
10. **CI/CD** — What runs on every PR? What blocks a merge? How are deployments triggered and rolled back?
11. **Coding standards** — Linter, formatter, type checker; conventions the tooling does not capture.
12. **Observability and dependencies** — Logging, error tracking, metrics; how dependencies are pinned, scanned and updated.

## Write

Write to `docs/ARCHITECTURE.md` using the structure in `references/template.md` (read it now). Adapt it to the project: a small project may not need Deployment, Scale and Performance, or Observability, and a monorepo may need a package layout section. Keep the `## Testing Strategy` heading whatever else changes, because other skills look for it.

## After Writing

1. Present the document for review. Iterate until the user is satisfied.
2. Suggest next steps based on what exists:
   - No threat model and the system has trust boundaries? → "Consider `/wf:threat-model`"
   - A decision here deserves its own record? → "Capture it with `/wf:adr <title>`"
   - Ready to plan the build? → "Run `/wf:roadmap`, then `/wf:spec <task>` per task (or `/wf:spec <name>` directly for one feature outside a roadmap)"
