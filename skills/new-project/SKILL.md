---
name: new-project
description: "Scaffold a new project with the full AI-assisted development workflow — Makefile targets, linter/formatter configs, pre-commit hooks, CLAUDE.md, docs skeleton, tailored to the chosen stack (python, go, typescript/nextjs, rust, etc.). Use when the user says 'start a new project', 'bootstrap a repo', 'scaffold X', 'set up a fresh codebase for Y', 'init a new service'."
---
Scaffold a new project with the AI-assisted development workflow.

**Argument format:** `<project-name> [language/framework]`

- `<project-name>` (required) — name of the project directory to create
- `[language/framework]` (optional) — the tech stack, used to tailor Makefile targets, linter config, .gitignore, and pre-commit hooks. Examples: `python`, `python/fastapi`, `go`, `typescript/nextjs`, `rust`. If omitted, you will be asked.

**Examples:**
- `/new-project my-api python/fastapi` — creates `./my-api/` with Python/FastAPI tooling
- `/new-project my-cli go` — creates `./my-cli/` with Go tooling
- `/new-project my-app` — creates `./my-app/`, asks what stack to use

## Process

### 1. Interview (if needed)

If no language/framework was given, ask the user:
- What language/framework?
- What type of project? (API, CLI, library, web app, etc.)
- Any specific tooling preferences? (test framework, linter, etc.)

### 2. Initialize the project

Create the project directory **inside the current working directory** and initialize git:

```bash
mkdir -p <project-name>
cd <project-name>
git init
```

The project is created at `$PWD/<project-name>/`. If you want it elsewhere, `cd` to the desired parent directory first.

### 3. Create workflow structure

Create these directories:

```
.claude/
.claude/agents/
docs/
docs/specs/
docs/roadmap/
docs/adr/
docs/rfc/
```

**Note:** Skills are installed globally at `~/.claude/skills/`. Do NOT create project-level skill copies — they'd duplicate and drift from the global versions. The global skills (`/architecture`, `/tdd`, `/security`, `/adr`, `/rfc`, `/spec`, `/roadmap`, `/issues`) are already available. Implementation, debugging and PR review come from the `feature-dev`, `superpowers` and `pr-review-toolkit` plugins (`claude-plugins-official` marketplace), not from this toolkit. For stack-aware code review, install Anthropic's official `code-review` skill from `claude-code-plugins`. Only create project-level agents and settings.

### 4. Create CLAUDE.md

Create a `CLAUDE.md` at the project root tailored to the language/framework:

```markdown
# CLAUDE.md

## Build & Test
- `make test` — run test suite
- `make lint` — run linters
- `make typecheck` — type checking (if applicable)
- `make build` — build the project (if applicable)

## Code Style
- [Language-specific conventions that Claude might get wrong]

## Architecture
- [Brief description of project structure]

## Workflow
- All PRs require passing CI + human review
- Commit messages use conventional commits (feat:, fix:, refactor:, chore:)
- Security-sensitive changes require /sec-review before PR
- Features start with a spec in docs/specs/
```

Adapt the build commands and style section to the chosen language/framework.

### 5. Create project-level agents

Copy the security-reviewer and architecture-reviewer into `.claude/agents/`, tailored to the project's language if needed.

### 6. Create project-level settings

Create `.claude/settings.json` with hooks appropriate to the language:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "make lint-changed 2>&1 | head -20",
        "description": "Lint after every file edit"
      }
    ]
  }
}
```

### 7. Create Makefile

Create a `Makefile` with standard targets for the chosen language/framework:
- `test` — run tests
- `lint` — run linter
- `typecheck` — run type checker (if applicable)
- `build` — build (if applicable)
- `lint-changed` — lint only changed files
- `security-scan` — run security scanner (gitleaks, bandit, gosec, etc.)

### 8. Create .pre-commit-config.yaml

Set up pre-commit hooks:
- Language-appropriate linter
- Type checker (if applicable)
- Test runner
- gitleaks for secret detection

### 9. Create .gitignore

Appropriate for the language/framework. Always include:
- `.claude/` local files
- `.env`
- Language-specific build artifacts

### 10. Create initial docs

Create `.gitkeep` files to preserve directory structure:
- `docs/specs/.gitkeep`
- `docs/roadmap/.gitkeep`
- `docs/adr/.gitkeep`
- `docs/rfc/.gitkeep`

### 11. Summary

Tell the user what was created and suggest next steps:
1. `cd <project-name>`
2. `pre-commit install`
3. `/prd <project-name>` — define what we're building
4. `/architecture` — define system structure
5. `/tdd` — define testing strategy, dev environment, CI/CD
6. `/security` — define the threat model (if applicable)
7. `/spec <first-feature>` — write your first feature spec
8. `/issues docs/specs/<first-feature>.md` — file the GitHub issue
9. `/feature-dev:feature-dev implement issue #<N> per docs/specs/<first-feature>.md` — implement it (`feature-dev` plugin)
