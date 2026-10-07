<p align="center">
  <h1 align="center">AI Workflow</h1>
  <p align="center">
    Full SDLC (Software Development Life Cycle) for AI-assisted coding — from idea to production.<br/>
    Built on SDD (Spec-Driven Development): specs are the source of truth, AI agents execute them.<br/>
    Skills, agents, review guides, and conventions — installed globally, applied everywhere.<br/><br/>
    Works with <a href="https://docs.anthropic.com/en/docs/claude-code">Claude Code</a>, <a href="https://www.cursor.com/">Cursor</a>, and <a href="https://openai.com/codex">OpenAI Codex CLI</a>.
  </p>
</p>

<p align="center">
  <a href="https://github.com/0xrafasec/ai-workflow/blob/main/LICENSE"><img src="https://img.shields.io/github/license/0xrafasec/ai-workflow?style=flat-square" alt="License"></a>
  <a href="https://github.com/0xrafasec/ai-workflow/issues"><img src="https://img.shields.io/github/issues/0xrafasec/ai-workflow?style=flat-square" alt="Issues"></a>
  <a href="https://github.com/0xrafasec/ai-workflow/stargazers"><img src="https://img.shields.io/github/stars/0xrafasec/ai-workflow?style=flat-square" alt="Stars"></a>
</p>

---

## What is this?

AI Workflow covers the software development lifecycle for AI-assisted coding — its own skills take you from the initial idea through design, roadmap, specs and GitHub issues, and it hands implementation, review, and delivery to maintained Claude Code plugins. It installs as a set of global skills, agents, and conventions that apply to every project you work on.

Each phase of development has dedicated tooling:

- **Discovery** — interview-driven requirements gathering (`/prd`)
- **Design** — architecture, technical design, and threat modeling (`/architecture`, `/tdd`, `/security`)
- **Specification** — detailed feature specs with verification criteria (`/spec`)
- **Planning** — phased roadmaps with dependency tracking (`/roadmap`)
- **Issues** — GitHub milestones and issues filed from the roadmap and specs (`/issues`) — the planning chain ends here, with an issue that has a spec and is ready to be implemented
- **Implementation** — not part of this toolkit: handed to marketplace plugins (`feature-dev`, `superpowers`; see [Required plugins](#required-plugins-claude-code))
- **Review** — security audit with specialized agents (`/sec-review`); PR review via the `pr-review-toolkit` plugin (for stack-aware code review, use Anthropic's official `code-review` skill from `claude-code-plugins`)
- **Governance** — decision records and change proposals at any point (`/adr`, `/rfc`)

## Features

- **13 slash-command skills** covering planning from idea to a GitHub issue with a spec, plus design and commits
- **Multi-platform** — native support for Claude Code, Cursor, and OpenAI Codex CLI
- **Specialized review agents** — architecture and security reviewers spawned as subagents
- **Language-aware review guides** — stack-specific best practices for Go, Rust, TypeScript, and Python, to hand to a reviewer
- **Execution via plugins** — implementation, debugging and PR review are delegated to maintained marketplace plugins instead of in-repo skills
- **Writer/reviewer separation** — a fresh-context reviewer is always spawned for every branch, never the session that wrote it; merging stays a separate, human-gated decision
- **Notification hooks** — desktop notifications when Claude needs attention (Claude Code)
- **Custom status line** — git branch, model and context on one quiet row; rate limits and their reset times appear only once they need attention (Claude Code)
- **Composable with other tools** — works alongside [GitHub Spec Kit](https://github.com/github/spec-kit) and other SDD toolkits ([integration guide](docs/speckit-integration.md))

## Platform Support

| Platform | How it installs | How skills are invoked |
|----------|----------------|------------------------|
| **Claude Code** | Symlinks into `~/.claude/` — skills, agents, CLAUDE.md, settings | `/skill-name` slash commands |
| **Cursor** | Generates `~/.cursor/rules/aiwf-*.mdc` — one MDC rule per skill | Reference by name: `"follow the /spec workflow for X"` |
| **Codex CLI** | Symlinks each skill into `~/.agents/skills/aiwf-*/` (native Codex skills) + writes `~/.codex/AGENTS.md` with global conventions | `$skill-name` at the prompt (e.g. `$spec`, `$roadmap`) or describe the task and Codex matches by description |

The bootstrap script auto-detects which tools are installed and sets up all of them. You can also install for each platform independently.

## Development Lifecycle

The toolkit implements a layered document pipeline where each phase builds on the ones above it. Humans decide *what* to build through structured interviews and specs; AI agents decide *how* to build it by following those specs with full context.

```
Idea → PRD (why) → Architecture + TDD + Security (how) → Roadmap (when) → Specs (what, per task) → GitHub issues → Implementation → Review → Ship
```

A feature spec references the architecture, technical design, and threat model — so implementation agents have complete context without repetition.

The toolkit's own skills cover everything up to the GitHub issue. Implementation, review and shipping are handed to plugins (see [Required plugins](#required-plugins-claude-code)).

For a detailed explanation with diagrams, see [docs/spec-driven-development.md](docs/spec-driven-development.md).

### Model Strategy

The workflow uses a tiered model strategy — Opus for decisions, Sonnet for execution:

| Task | Model | Reasoning |
|------|-------|-----------|
| Spec writing, design, interviews | **Opus** | Creative reasoning, edge case discovery |
| Implementation (main session) | **Opus** | Complex design decisions |
| Security review | **Opus** | False negatives are catastrophic |
| Architecture review | **Sonnet** | Structured criteria, checklist-driven |
| Stack-specific review | **Sonnet** | Pattern matching against review guides |

## Quick Start

### Prerequisites

- At least one of: [Claude Code](https://docs.anthropic.com/en/docs/claude-code), [Cursor](https://www.cursor.com/), or [Codex CLI](https://openai.com/codex)
- `git`, `bash`
- Claude Code extras: `jq` (status line — required), `notify-send` (Linux) or `osascript` (macOS, built in) for desktop notifications

### Required plugins (Claude Code)

The toolkit covers planning — PRD → architecture → roadmap → spec → GitHub issue. Implementation, debugging and PR review are handled by three plugins from the `claude-plugins-official` marketplace. Install them inside Claude Code:

```
/plugin install feature-dev@claude-plugins-official
/plugin install pr-review-toolkit@claude-plugins-official
/plugin install superpowers@claude-plugins-official
```

| Plugin | Used for | Entry point |
|--------|----------|-------------|
| `feature-dev` | Implementing an issue from its spec | `/feature-dev:feature-dev` |
| `pr-review-toolkit` | Reviewing a branch or PR | `/pr-review-toolkit:review-pr` |
| `superpowers` | Debugging, multi-task execution, finishing a branch | skills: `systematic-debugging`, `subagent-driven-development`, `executing-plans`, `dispatching-parallel-agents`, `finishing-a-development-branch` |

`feature-dev` and `pr-review-toolkit` are **Claude Code only**; `superpowers` also ships Codex and Cursor installs (see its own README). The Cursor and Codex adapters in this repo install the planning skills and no execution skills.

**`superpowers` changes every session it is enabled in.** Its session-start hook tells Claude to look for an applicable superpowers skill before any task, and its `brainstorming` skill overlaps `/prd` and `/spec`. If that competes with your own conventions, leave it out: it is only needed for the debugging and multi-task replacements.

### Install (recommended — one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/0xrafasec/ai-workflow/main/bootstrap.sh | bash
```

This clones the repo into `~/.local/share/ai-workflow`, installs for all detected platforms, and puts `aiwf` in `~/.local/bin`. Pin to a specific release with `AIWF_REF=v0.1.0 bash`.

**Auto-detection:** bootstrap installs for Claude Code always, then checks for Cursor (`~/.cursor` or `cursor` binary) and Codex CLI (`~/.codex` or `codex` binary) and installs those too.

Prefer to read the script before running it? [bootstrap.sh](bootstrap.sh) is short and auditable — the whole toolkit is bash + markdown by design.

### Install from a git clone (no curl)

```bash
git clone https://github.com/0xrafasec/ai-workflow.git
cd ai-workflow
./install.sh          # Claude Code + install the aiwf launcher in ~/.local/bin
aiwf install-cursor   # add Cursor
aiwf install-codex    # add Codex CLI
# or all at once:
aiwf install-all
```

### Per-platform install

```bash
aiwf install           # Claude Code — symlinks into ~/.claude/
aiwf install-cursor    # Cursor — generates ~/.cursor/rules/aiwf-*.mdc
aiwf install-codex     # Codex CLI — symlinks skills into ~/.agents/skills/ + writes ~/.codex/AGENTS.md
aiwf install-all       # all three at once
```

### Manage the install

Once `aiwf` is on your PATH:

```bash
aiwf status            # install dir, version, and per-platform health
aiwf update            # git pull + re-link Claude (refuses dirty trees; --force stashes)
aiwf reinstall         # repair broken Claude symlinks
aiwf uninstall         # remove Claude symlinks (--purge deletes the clone too)
aiwf uninstall-cursor  # remove Cursor rules
aiwf uninstall-codex   # remove Codex instructions
aiwf uninstall-all     # remove from all platforms
aiwf version           # git describe
aiwf help              # all commands
```

**Keeping Cursor/Codex in sync with updates:**

```bash
aiwf update            # pull latest from git
aiwf install-cursor    # regenerate Cursor rules
aiwf install-codex     # recompile Codex instructions
# or just:
aiwf update && aiwf install-all
```

**Update conflict handling.** `aiwf update` fast-forwards `main` by default and refuses to proceed if the working tree is dirty or your local branch is ahead of `origin/main`. Both suggest you've edited the clone directly — which is supported. Resolve by committing/pushing, or use `--force` to auto-stash and hard-reset.

### Selective Claude install

```bash
# Install only specific files into ~/.claude/
./install.sh settings.json
./install.sh skills/spec/SKILL.md CLAUDE.md
# or: aiwf install settings.json
```

The filter matches on path, destination, or basename.

### Multiple Claude Code profiles

Claude Code can run isolated profiles — separate login, settings, MCP servers, history — by pointing its own `CLAUDE_CONFIG_DIR` at a different directory:

```bash
alias claude-work='CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude'
```

Each profile carries its own `skills/`, `agents/`, `commands/` and `CLAUDE.md`, so a new profile starts with none of the toolkit. Set `CLAUDE_DIR` to install into it:

```bash
CLAUDE_DIR="$HOME/.claude-work" ./install.sh
# or: CLAUDE_DIR="$HOME/.claude-work" aiwf install
```

**`settings.json` is not shared.** Account, theme, model, status line and enabled plugins are the reason to run separate profiles in the first place, so only the primary `~/.claude` gets the repo's `settings.json` — a secondary `CLAUDE_DIR` keeps its own file untouched. That follows from `CLAUDE_DIR`, not from a flag, so it still holds when `aiwf update` or `aiwf reinstall` re-runs the install for you. Override with `--with-settings` (share one settings file everywhere) or `--no-settings` (skip it even for the primary dir).

What each profile sets for itself, in its own `settings.json` — model, permission mode, theme, status line:

```json
{
  "model": "claude-opus-4-8[1m]",
  "theme": "dark",
  "permissions": { "defaultMode": "bypassPermissions" },
  "statusLine": {
    "type": "command",
    "command": "bash \"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/statusline-command.sh\"",
    "refreshInterval": 30
  }
}
```

`model` takes a full model id, not just an alias, when you want a specific variant — `claude-opus-4-8[1m]` for the 1M-context window, `claude-opus-5`, `claude-sonnet-5`. The status line path resolves per profile, so each one runs the shared script against its own config dir.

`--with-settings` and `--no-settings` are last-wins if you pass both.

Uninstall the same way (`CLAUDE_DIR="$HOME/.claude-work" ./uninstall.sh`). It only removes symlinks, so a profile-local `settings.json` survives, and it leaves `~/.local/bin/aiwf` in place because the launcher is shared by every profile.

`install-all` and `uninstall-all` are only **half** profile-scoped: the Claude half honours `CLAUDE_DIR`, but the Cursor and Codex adapters write to `~/.cursor` and `~/.codex`, which have no profile concept — so an `uninstall-all` run from a profile still wipes those globally. Use plain `aiwf install` / `aiwf uninstall` for a profile. `aiwf uninstall --purge` deletes the shared clone every profile links against, so it is refused unless `CLAUDE_DIR` is the primary dir.

### Uninstall

```bash
aiwf uninstall-all        # remove from all platforms
aiwf uninstall --purge    # remove from Claude + delete the clone
```

## Skills

Skills are multi-step workflows invoked as slash commands inside Claude Code.

### Planning

| Skill | Description |
|-------|-------------|
| `/prd` | Interview-driven Product Requirements Document |
| `/architecture` | System architecture document |
| `/tdd` | Technical Design Document (testing, dev env, CI/CD, coding standards) |
| `/security` | STRIDE-style threat model (`docs/THREAT_MODEL.md`) |
| `/adr <title>` | Architecture Decision Record |
| `/rfc <title>` | Request for Comments |

### Design

| Skill | Description |
|-------|-------------|
| `/design` | Produce distinctive, production-grade UI designs in Paper.design MCP |
| `/verify-design` | Diff the running UI against Paper design refs with Playwright and fix mismatches |

### Roadmap, specs, and issues

| Skill | Description |
|-------|-------------|
| `/roadmap` | Phased task breakdown from design docs |
| `/spec <feature>` | Feature implementation spec with verification criteria |
| `/issues <roadmap or spec>` | File GitHub milestones + issues — one milestone per phase, one issue per task/slice, each carrying its spec path |
| `/new-project <name>` | Scaffold a new project with the full workflow |

### Review

| Skill | Description |
|-------|-------------|
| `/sec-review` | Full security audit with parallel analysis agents |

> **Stack-aware code review:** use Anthropic's official `code-review` skill from [`claude-code-plugins`](https://github.com/anthropics/claude-code). The previous in-repo `/code-review` skill was deprecated after a benchmark (see `code-review-workspace/iteration-1/`) showed no detection lift over baseline at ~1.5× the cost. Language-specific guides in `reviews/` stay installed — hand the matching one to the reviewer as stack criteria.

### Delivery

| Skill | Description |
|-------|-------------|
| `/commit` | Stage and commit the working tree as one or more logical conventional commits (local-only, never pushes) |

### Execution (plugins, not skills)

The six execution skills (`/feature`, `/fix`, `/review`, `/pr`, `/autopilot`, `/factory`) were retired; maintained marketplace plugins cover the same ground (see [Required plugins](#required-plugins-claude-code)).

| Retired skill | Use instead |
|---------------|-------------|
| `/feature <spec>` | `/feature-dev:feature-dev` (`feature-dev` plugin) — a guided 7-phase workflow (discovery, codebase exploration, clarifying questions, architecture design, implementation, quality review, summary). It is not spec-file driven by itself: give it the issue and its spec path as the argument, e.g. `/feature-dev:feature-dev implement issue #42 per docs/specs/003_auth.md` |
| `/fix <issue>` | `superpowers` plugin's `systematic-debugging` skill — root-cause investigation before any fix is proposed. It triggers when you describe a bug, test failure, or unexpected behaviour |
| `/review` | `/pr-review-toolkit:review-pr` (`pr-review-toolkit` plugin) — runs specialized review agents (code, tests, error handling, comments, types, simplification) over the current diff and aggregates findings by severity |
| `/pr` | No dedicated replacement: run `/pr-review-toolkit:review-pr` before committing (it reads uncommitted changes), then `git push` + `gh pr create` (or ask Claude to open the PR). `superpowers` also has `finishing-a-development-branch` (verify tests, then merge / push + PR / keep) |
| `/autopilot`, `/factory` | `superpowers` skills `subagent-driven-development` (fresh implementer subagent per task + review after each), `executing-plans` (same plan, inline in one session) and `dispatching-parallel-agents`. There is no longer a one-command "run the whole roadmap/milestone and merge" pipeline in this toolkit |

## Agents

Agents are specialized reviewers spawned as subagents during implementation or review.

| Agent | What it reviews |
|-------|-----------------|
| `architecture-reviewer` | Pattern consistency, separation of concerns, API stability, dependency hygiene |
| `security-reviewer` | Injection flaws, auth issues, secrets in code, crypto weaknesses, data exposure |

## Language-Specific Review Guides

Hand the matching guide to a reviewer as stack criteria (for example Anthropic's `code-review` skill or a review subagent). Polyglot projects use multiple guides.

| Guide | Covers |
|-------|--------|
| Go | Error handling, concurrency, injection, interface design, project layout |
| Rust | Unsafe audit, FFI, ownership, async patterns, error design, type system |
| TypeScript | Node.js, Next.js, Nest.js — prototype pollution, SSR, DI, async patterns |
| Python | Django, FastAPI, Flask — injection, path traversal, async, ORM patterns |

## How It Works

### The Document Pipeline

The typical flow from idea to an issue ready to be implemented:

```
/prd                       Define what to build and why
  │
/architecture              System structure
/tdd                       Technical design (testing, dev env, CI/CD, standards)
/security                  Threat model
  │
/roadmap                   Phase breakdown from design docs
  │
/spec <feature>            Detail each task in the roadmap
  │
  │   /design [flow]       UI designs in Paper (for UI features)
  │   /verify-design       Diff running UI against Paper refs, fix in place
  │
/issues <roadmap or spec>  GitHub milestones + issues, each linked to its spec
  │
  ▼  an issue with a spec, ready to be implemented — the toolkit's pipeline ends here

Execution (Claude Code plugins):
/feature-dev:feature-dev implement issue #N per docs/specs/NNN_<name>.md
/pr-review-toolkit:review-pr     Independent review by fresh reviewer agents (reads uncommitted changes)
/commit                          Logical conventional commits
git push && gh pr create         Open the PR
```

Bug fixes need no spec — describe the bug and the `superpowers` plugin's `systematic-debugging` skill takes it from there. `/adr` and `/rfc` can be used at any point to capture decisions or propose changes.

### Parallel Development

Each task runs in its own [git worktree](https://git-scm.com/docs/git-worktree), isolated from other work:

```bash
claude --worktree feature-auth
claude --worktree feature-dashboard
```

For agent-orchestrated execution of several tasks, use the `superpowers` plugin's `subagent-driven-development`, `executing-plans` and `dispatching-parallel-agents` skills. This toolkit no longer has a one-command pipeline that runs a whole roadmap or milestone and merges it.

### Quality Gates

```
Hooks          →  Lint and format on every edit
Pre-commit     →  Tests, type checks on every commit
Subagent review →  Security + architecture review before PR
CI/CD          →  Full build, SAST, dependency scan
Human review   →  Business logic, design decisions, edge cases
```

## Project Structure

```
ai-workflow/
├── CLAUDE.md                  # Project-only rules (loads when working IN this repo)
├── dotfiles/CLAUDE.md          # Global conventions (symlinked to ~/.claude/)
├── settings.json              # Hooks, permissions, model config (Claude Code)
├── statusline-command.sh      # Custom status line script (Claude Code)
├── aiwf                       # Toolkit manager CLI
├── install.sh                 # Claude Code symlink installer
├── uninstall.sh               # Claude Code uninstaller
├── bootstrap.sh               # One-liner multi-platform bootstrap
├── adapters/
│   ├── cursor/
│   │   ├── install.sh         # Generates ~/.cursor/rules/aiwf-*.mdc
│   │   └── uninstall.sh       # Removes ~/.cursor/rules/aiwf-*.mdc
│   └── codex/
│       ├── install.sh         # Symlinks skills into ~/.agents/skills/aiwf-* + writes ~/.codex/AGENTS.md
│       └── uninstall.sh       # Removes skill symlinks and AGENTS.md
├── agents/
│   ├── architecture-reviewer.md
│   └── security-reviewer.md
├── commands/
│   └── sec-review.md
├── reviews/
│   ├── go.md
│   ├── rust.md
│   ├── typescript.md
│   └── python.md
├── skills/
│   ├── prd/
│   ├── architecture/
│   ├── tdd/
│   ├── security/
│   ├── adr/
│   ├── rfc/
│   ├── spec/
│   ├── roadmap/
│   ├── issues/
│   ├── new-project/
│   ├── commit/
│   ├── design/
│   └── verify-design/
└── docs/
    ├── WORKFLOW.md            # Full workflow documentation
    └── REFERENCE.md           # Quick reference for all components
```

## Configuration

### Global Conventions (`dotfiles/CLAUDE.md`)

Source: `dotfiles/CLAUDE.md`. Installed at `~/.claude/CLAUDE.md` (symlink). Applies to every Claude Code session in every project. The repo-root `CLAUDE.md` is **separate** — it's the project-only rules for working inside the ai-workflow repo itself, and is not installed.

- Conventional commits (`feat:`, `fix:`, `refactor:`, etc.)
- Spec-first development
- Writer/reviewer separation
- PRs under 200 lines of non-test diff, one concern each

### Settings (`settings.json`)

Desktop notification hooks, permission mode, and model preference. See `settings.json` for the current config.

### Status Line

The bundled `statusline-command.sh` renders one row in Claude Code's status bar, and a second only when a rate limit needs attention:

```
ai-workflow · main ✚2 · Opus 5 (1M) · high · ctx 69k/1M
5h ███████░  88% ↻ today 22:00 (39m)
```

**Row 1 — identity:** directory, git branch + uncommitted count, model, reasoning effort (plus `⚡` in fast mode and any non-default output style), and the context in absolute tokens. Only the uncommitted count and the context count move while you work (and the cost, on API-key billing), so the rest can be read once and then ignored.

**Row 2 — rate-limit alert:** a window (5-hour, 7-day) is drawn only once it reaches 70% used, with a usage bar and **the local clock time the allowance resets**, followed by a countdown. Below that there is no decision to make, so the row is not printed. Set `CLAUDE_STATUSLINE_LIMIT_SHOW` to another percentage to move the threshold, or to `0` to always show both windows.

The reset stamp is anchored so it can't be misread: `today 22:00` and `tomorrow 05:00` when the reset is that close, and the full `Mon 10 Aug 05:00` otherwise. A bare weekday would be ambiguous for the 7-day window, which can land up to a week out.

Limit bars and percentages are green below 70%, amber from 70–89% and red at 90%+; at the default threshold a window is therefore never drawn green. The context count is graded on absolute tokens instead: amber past 150k (`CLAUDE_STATUSLINE_CTX_IDEAL`), red once auto-compact is close.

Details worth knowing:

- **No context bar or percentage.** On a 1M window the percentage stays in single digits for a whole working session, so the token count carries the meaning and its colour says whether to act.
- **Cost appears only on API-key billing**, from `cost.total_cost_usd`. On a Claude.ai subscription the figure is notional and is not shown.
- **Set `refreshInterval`** in `settings.json` (30s is a good default) so the reset countdown keeps ticking while the session is idle. Status lines are otherwise event-driven and the clock would freeze.
- **Width-adaptive** via `$COLUMNS` (needs Claude Code ≥ 2.1.153): countdowns drop below 90 columns, limit bars below 70, and the context window size below 80.
- Honours `NO_COLOR`, runs a single `jq` pass, caches `git status` for 3s, and always exits 0 — a broken status line is worse than a plain one.

## Documentation

| Document | Description |
|----------|-------------|
| [Spec-Driven Development](docs/spec-driven-development.md) | Detailed explanation of the SDD methodology with Mermaid diagrams |
| [Spec Kit Integration](docs/speckit-integration.md) | How to combine AI Workflow with GitHub Spec Kit |
| [Workflow Guide](docs/WORKFLOW.md) | Full workflow guide — phases, conventions, CI/CD integration, team practices |
| [Reference](docs/REFERENCE.md) | Quick reference for all agents, skills, settings, and daily patterns |
| [Changelog](CHANGELOG.md) | Release notes — what changed in each version |

## Modifying the Toolkit

All config lives in this repo. **Never edit platform config files directly** (`~/.claude/`, `~/.cursor/rules/aiwf-*.mdc`, `~/.codex/AGENTS.md`, `~/.agents/skills/aiwf-*/`) — changes will be lost on the next install or symlink conflict.

To modify anything:

1. Edit the source file in this repo (skills, agents, CLAUDE.md, reviews, etc.)
2. Commit and push

**Claude Code / Codex** — skills are symlinked (`~/.claude/skills/`, `~/.agents/skills/aiwf-*/`), so edits to SKILL.md files in this repo take effect immediately. Re-run `aiwf install-codex` only when adding new skills or changing global conventions/agents/reviews (the AGENTS.md file is compiled, not symlinked).

**Cursor** — uses generated MDC files; regenerate after any change:

```bash
aiwf install-cursor   # regenerate ~/.cursor/rules/aiwf-*.mdc
aiwf install-codex    # re-link skills + recompile ~/.codex/AGENTS.md
# or both:
aiwf install-all
```

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines on how to contribute.

## Security

See [SECURITY.md](SECURITY.md) for our vulnerability disclosure policy.

## Code of Conduct

See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

[MIT](LICENSE) — 0xrafasec
