---
name: new-project
description: "Scaffold a new project directory for a chosen stack: git init, an AGENTS.md (plus a one-line CLAUDE.md importing it) with the real build and test commands, a Makefile with test and lint targets, a lint-on-edit hook, a .gitignore, secret scanning, a free GitHub Actions CI workflow and the docs/ skeleton the other /wf skills write into. Use for 'start a new project', 'bootstrap a repo', 'scaffold X', 'init a new service'. Creates a new directory only; it does not touch an existing repo."
argument-hint: "<project-name> [language/framework]"
disable-model-invocation: true
---
Scaffold a new project: `$ARGUMENTS` is `<project-name> [language/framework]`, e.g. `my-api python/fastapi`, `my-cli go`, `my-app typescript/nextjs`.

In hosts that do not substitute `$ARGUMENTS` (e.g. Codex), it is the text the user wrote after the skill name.

Generate only what you can name a working command for. If a tool for the stack is uncertain, leave it out and say so in the summary. Never write a bracketed placeholder into a generated file.

## Process

### 1. Check the target and the stack

- The project goes in `$PWD/<project-name>/`. If that directory exists and is not empty, stop and ask the user to confirm before touching it. Even when confirmed, never overwrite an existing file: skip it and list what you skipped.
- If no stack was given, ask one AskUserQuestion for stack and project type (API, CLI, library, web app). Where AskUserQuestion is unavailable but the user can answer in chat (e.g. Codex), ask the same question in chat as a short numbered list and wait for the answer; a headless run or a dispatched agent has no such user, and the headless rule applies instead. Take the test runner, linter and formatter from `references/stacks.md`. If you cannot ask, stop with a one-line error instead of guessing a stack.

### 2. Initialize

```bash
mkdir -p <project-name> && cd <project-name> && git init
mkdir -p docs/specs docs/roadmap docs/adr
touch docs/specs/.gitkeep docs/roadmap/.gitkeep docs/adr/.gitkeep
```

The `wf` plugin provides the workflow skills; do not copy them into the project.

### 3. Tooling

Read `references/stacks.md` for the chosen stack, then create:

- **`Makefile`** with `test`, `lint`, `lint-changed` (lint only changed files; exit 0 when nothing changed or the repo has no commits), plus `typecheck` and `build` only where the stack has them.
- **`.gitignore`** for the stack, always including `.claude/settings.local.json` (personal overrides; `.claude/settings.json` is committed), `.env` and `.env.*` with `!.env.example`.
- **`.pre-commit-config.yaml`** with the stack's formatter/linter and gitleaks. Look up gitleaks' current release tag (`git ls-remote --tags https://github.com/gitleaks/gitleaks`) for `rev`; never write a guessed one. Keep tests out of pre-commit.
- **`.github/workflows/ci.yml`**, a free CI that runs the Makefile's `lint`, `typecheck` (only if the Makefile has it) and `test`, so the checks that gate local work also gate the PR. It runs on `pull_request` and on `push` to the trunk branch, with top-level `permissions: contents: read` and no secrets. Pin every action to a full commit SHA, looked up with `git ls-remote https://github.com/<owner>/<repo> refs/tags/<tag>` (for an annotated tag, the `^{}` line is the commit); never write a guessed SHA, and leave a `# <tag>` comment beside it. Use `actions/checkout` with `persist-credentials: false`, then the stack's setup step from `references/stacks.md` (also SHA-pinned) only when the runner lacks the toolchain, then the dependency install if the stack has one, then `make lint`, `make typecheck`, `make test`. No LLM calls, paid services or cloud accounts.
- **`.claude/settings.json`**, so lint failures reach Claude. A `PostToolUse` hook only does that when it exits 2 and writes to stderr:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "out=$(make lint-changed 2>&1) || { printf '%s\\n' \"$out\" | head -20 >&2; exit 2; }"
          }
        ]
      }
    ]
  }
}
```

### 4. AGENTS.md and CLAUDE.md

Write a short `AGENTS.md` (the instructions file Codex reads) with only what is true of this project: the `make` commands that exist in the Makefile you generated, the code-style points an agent tends to get wrong for this stack, and a one-line architecture note. Leave out a section you cannot fill. Do not copy the user's global workflow rules (commit style, review, security review); they apply in every project. End with: "Features start from a spec in `docs/specs/`; see `/wf:spec`." Then write a `CLAUDE.md` containing only the line `@AGENTS.md` (Claude Code's import), so both hosts read the same rules.

### 5. Verify

Run `make lint` and `make test` once. Each should exit 0 on the empty scaffold; if one does not, fix the target or say why. If the stack's toolchain is not installed, scaffold anyway and list what to install.

### 6. Commit and summarize

Make the initial commit on the trunk branch with the subject `chore: scaffold project`. Tell the user what was created (CI workflow included) and what was skipped, then suggest next steps:
1. `pre-commit install` (after `pipx install pre-commit` if needed)
2. `/wf:prd <project-name>`, then `/wf:architecture` (until it exists, `/wf:feature` and `/wf:fix` infer the testing strategy from the code)
3. `/wf:threat-model` if applicable
4. `/wf:spec <first-feature>`, then `/wf:feature <first-feature>`
