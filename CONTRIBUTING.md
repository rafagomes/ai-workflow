# Contributing to ai-workflow

Thanks for your interest in contributing. This guide covers how to report issues, suggest improvements, and submit changes.

## Reporting Bugs

Open an [issue](https://github.com/rafagomes/ai-workflow/issues/new?template=bug_report.md) with:

- **What happened** — the actual behavior
- **What you expected** — the correct behavior
- **Steps to reproduce** — minimal instructions to trigger the bug
- **Environment** — OS, Claude Code version, shell

## Suggesting Features

Open an [issue](https://github.com/rafagomes/ai-workflow/issues/new?template=feature_request.md) with:

- **Problem** — what you're trying to do and why the current toolkit doesn't support it
- **Proposed solution** — how you'd like it to work
- **Alternatives considered** — other approaches you thought about

## Submitting Changes

### Setup

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/ai-workflow.git
   cd ai-workflow
   ```
3. Create a branch:
   ```bash
   git checkout -b feat/your-feature
   ```

### Development

After making changes, validate the plugin and try it in a session:

```bash
claude plugin validate .
claude --plugin-dir .
```

Skills and agents are discovered from `skills/` and `agents/`; nothing needs registering. `install.sh` and `uninstall.sh` only handle the global `CLAUDE.md` and `settings.json`.

#### CI

`.github/workflows/ci.yml` runs on every pull request and on pushes to `main`. Run the same checks locally before you push:

| Job | What it checks | Run locally |
|-----|----------------|-------------|
| `validate` | The plugin and marketplace manifests | `claude plugin validate .` (warnings about the missing `version` and icon are expected) |
| `shellcheck` | Every tracked `*.sh` | `shellcheck install.sh uninstall.sh tests/*.sh` |
| `installer` | `install.sh` and `uninstall.sh`, against a throwaway `HOME` and `CLAUDE_DIR` | `bash tests/install_test.sh` |
| `hooks` | The guardrail hook (`hooks/guard.sh`) against JSON fixtures | `bash tests/hooks_test.sh` |
| `links` | Relative links and anchors in tracked Markdown (external URLs are not checked) | `python3 -I tests/check_links.py` |

CI is free-only: no API keys or secrets, no LLM calls (so no `claude plugin eval`), no paid services. Third-party actions are pinned to a full commit SHA with the version in a comment, and the workflow token is read-only. Keep it that way when you change the workflow.

### Commit Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
feat:       New skill, agent, or capability
fix:        Bug fix in existing functionality
refactor:   Code restructuring without behavior change
docs:       Documentation changes
chore:      Maintenance (install scripts, config)
test:       Test additions or changes
perf:       Performance improvement
build:      Build or packaging changes
ci:         CI configuration (`.github/workflows/`)
security:   Security fix or hardening
```

Each commit should leave the toolkit in a working state. Split unrelated changes into separate commits.

### Pull Requests

1. Keep PRs focused — one concern per PR
2. Write a clear description of what changed and why
3. Link to any related issues
4. Fill in the PR template, including its `## Risk` section: **T0** (prose typo, changelog entry or version bump only; review skipped), **T1** (an ordinary change) or **T2** (CI/CD, installer or anything that runs automatically, permissions or secrets, a public contract, anything hard to reverse; a maintainer merges it). Text that instructs an agent (a skill, the agent, a `CLAUDE.md`) is never T0. See [Risk-tiered review](docs/TRUNK_BASED_WORKFLOW.md#risk-tiered-review)
5. Run the [CI checks](#ci) locally: `claude plugin validate .`, `shellcheck` on any shell script you touched, `bash tests/install_test.sh` if you touched `install.sh` or `uninstall.sh`, and `python3 -I tests/check_links.py` if you touched Markdown

### What Makes a Good Skill

If you're contributing a new skill:

- **Single purpose** — one clear workflow per skill
- **Self-contained** — the SKILL.md should include all instructions Claude needs
- **Consistent** — follow the patterns in existing skills
- **Documented** — update the README skills table and tree, the changelog, and the other docs listed in the table in `CLAUDE.md`

## Code of Conduct

This project follows the [Contributor Covenant](CODE_OF_CONDUCT.md). By participating, you agree to uphold it.

## Questions?

Open a [discussion](https://github.com/rafagomes/ai-workflow/discussions) or an issue. No question is too small.
