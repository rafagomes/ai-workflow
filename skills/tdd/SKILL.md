---
name: tdd
description: "Create or update docs/TECHNICAL_DESIGN_DOCUMENT.md — testing strategy, dev environment, CI/CD, coding standards, linter/formatter choices. Use when the user asks to define testing strategy, set up CI/CD, pick linters/formatters, standardize the dev setup, or says 'how should we test this', 'what's our coding style', 'write the tech design doc', 'set up conventions for the repo'."
---
Create the Technical Design Document. Argument: $ARGUMENTS

## Context Gathering

Before interviewing, explore the project's current build and test setup:

1. **Check for existing docs:**
   - Read `docs/TECHNICAL_DESIGN_DOCUMENT.md` — if revising, don't start from scratch
   - Read `CLAUDE.md` for build/test commands
   - Read `docs/ARCHITECTURE.md` if it exists (for technology context)
   - Read `README.md` for setup instructions

2. **Explore the codebase:**
   - Look for test directories (`tests/`, `__tests__/`, `spec/`, `*_test.go`, `*.test.ts`, `test_*.py`)
   - Read `package.json`, `pyproject.toml`, `Cargo.toml`, `Makefile`, `docker-compose.yml` for tooling, test commands, dependencies
   - Read 1-2 existing test files to understand patterns (fixtures, helpers, naming)
   - Check for CI config (`.github/workflows/`, `.gitlab-ci.yml`, `Jenkinsfile`)
   - Check for linter/formatter config (`.eslintrc`, `ruff.toml`, `.golangci.yml`, `rustfmt.toml`)
   - Summarize what you found to the user before starting — "Here's what I see in the project: ..."

## Interview

Use AskUserQuestion to understand how the team builds, tests, and ships. Adapt based on what the codebase already reveals.

1. **Testing strategy** — What test frameworks are in use? Where do tests live? Are there separate unit/integration/e2e layers? What needs integration tests vs unit tests? Any critical flows that need e2e coverage?
2. **Dev environment** — How do developers set up locally? Docker, nix, manual install? What external services are needed (databases, queues, caches)?
3. **CI/CD pipeline** — What runs on every PR? What runs nightly? What gates block merging? How are deployments triggered?
4. **Coding standards** — Linter config, formatter, type checker? Any style guides or conventions not captured in tooling?
5. **Tooling decisions** — Package manager, build system, monorepo tools? Why these over alternatives?
6. **Error handling & observability** — Logging framework, error tracking, metrics? How do you debug production issues?
7. **Dependencies** — How are deps managed? Pinned versions? Vulnerability scanning? Update cadence?

For inherited projects, explore before asking — "I see you have pytest with a `tests/` folder but no integration tests yet — is that intentional?" and "Your CI runs `make test` but there's no lint step — is that by design?"

## Write

Write to `docs/TECHNICAL_DESIGN_DOCUMENT.md`:

```markdown
# Technical Design Document

**Version:** [version]
**Date:** [date]

## Testing Strategy

[This section is the source of truth that the planning skills (/spec, /roadmap) and whoever implements a task reference when deciding what tests to write.]

### Test Layers

| Layer | Scope | Framework | Run Command | When to Write |
|-------|-------|-----------|-------------|---------------|
| Unit | Single function/module, no I/O | [e.g., pytest, vitest, go test] | [e.g., make test-unit] | Every change — business logic, pure functions, validators |
| Integration | Component boundaries, real dependencies | [e.g., pytest + testcontainers, supertest] | [e.g., make test-integration] | API endpoints, database queries, service interactions, middleware |
| E2E | Full user flows, production-like environment | [e.g., playwright, cypress, k6] | [e.g., make test-e2e] | Critical user paths, auth flows, payment flows |

### Test Conventions

- **File location:** [e.g., `tests/unit/`, `tests/integration/`, `tests/e2e/` or colocated `__tests__/`]
- **Naming:** [e.g., `test_<module>.py`, `<module>.test.ts`, `<module>_test.go`]
- **Fixtures/factories:** [where shared test helpers live]
- **Test database:** [how integration tests get a database — testcontainers, sqlite, etc.]
- **CI behavior:** [which layers run on PR, which run nightly]

### Coverage Expectations

- Unit tests: cover all business logic, validation, and error paths
- Integration tests: cover all API endpoints, database operations, and external service calls
- E2E tests: cover critical user journeys (list the 3-5 most important flows)

## Dev Environment

### Setup

[Step-by-step local setup. Prerequisites, install commands, env vars.]

### External Dependencies

| Service | Local Setup | Purpose |
|---------|------------|---------|
| [e.g., PostgreSQL] | [e.g., docker compose up] | [e.g., primary data store] |

## CI/CD Pipeline

### PR Checks

| Check | Command | Blocks Merge |
|-------|---------|-------------|
| [e.g., Lint] | [e.g., make lint] | Yes |
| [e.g., Unit tests] | [e.g., make test-unit] | Yes |
| [e.g., Integration tests] | [e.g., make test-integration] | Yes |
| [e.g., E2E tests] | [e.g., make test-e2e] | No (nightly) |

### Deployment

[How deployments are triggered. Environments, promotion strategy, rollback procedure.]

## Coding Standards

- **Linter:** [tool and config file]
- **Formatter:** [tool and config file]
- **Type checker:** [tool and config file]
- **Conventions not captured in tooling:** [anything humans need to know]

## Tooling

| Tool | Purpose | Why This Over Alternatives |
|------|---------|---------------------------|
| [tool] | [what it does] | [rationale] |

## Error Handling & Observability

- **Logging:** [framework, format, levels]
- **Error tracking:** [service, how errors are reported]
- **Metrics:** [what's measured, where dashboards live]

## Dependency Management

- **Package manager:** [tool]
- **Version strategy:** [pinned, ranges, etc.]
- **Vulnerability scanning:** [tool, frequency]
- **Update cadence:** [how often, who owns it]
```

Adapt the structure to the project. A small project may skip Observability. A monorepo may need per-package sections. Use judgment.

## After Writing

1. Present the document to the user for review. Iterate until they're satisfied.
2. Suggest next steps based on what exists:
   - No architecture doc? → "Define system structure with `/architecture`"
   - No threat model? → "Consider `/security` for the threat model"
   - Ready to build? → "Create feature specs with `/spec <name>`, then `/roadmap`"
