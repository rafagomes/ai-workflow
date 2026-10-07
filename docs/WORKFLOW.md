# High-Performance AI-Assisted Development Workflow

> A team workflow optimized for parallel development, security-first practices, and outstanding code quality using Claude Code.

---

## Table of Contents

1. [Philosophy](#philosophy)
2. [Phase 0: Project Setup](#phase-0-project-setup)
3. [Phase 1: Spec-Driven Design](#phase-1-spec-driven-design)
4. [Phase 2: Roadmap & Task Breakdown](#phase-2-roadmap--task-breakdown)
5. [Phase 3: Parallel Implementation](#phase-3-parallel-implementation)
6. [Phase 4: Quality Gates](#phase-4-quality-gates)
7. [Phase 5: Review & Merge](#phase-5-review--merge)
8. [Team Conventions](#team-conventions)
9. [CI/CD Integration](#cicd-integration)
10. [Continuous Improvement](#continuous-improvement)

---

## Philosophy

AI acts as a **multiplier of existing engineering quality**, not a replacement for it. The 2025 DORA Report confirms: teams with clear processes and good documentation see the biggest gains. Teams with fragmented workflows see AI amplify their chaos.

**Core principles:**
- **Spec first, code second** — AI executes specs; vague specs produce vague code
- **Parallel by default** — worktrees enable multiple streams of work without conflicts
- **Security is shift-left** — review happens during development, not after
- **Context is the bottleneck** — manage it aggressively (clear, compact, scope)
- **Verify everything** — AI-generated code needs tests, not trust

**Key metric to watch:** PR review time increases ~91% with high AI adoption. The bottleneck shifts from generation to review. This workflow addresses that directly.

---

## Phase 0: Project Setup

### CLAUDE.md — The Team's Shared Brain

Every project gets a `CLAUDE.md` at the root. This is the single most impactful thing for consistent AI output across a team.

```markdown
# CLAUDE.md

## Build & Test
- `make test` — run test suite
- `make lint` — run linters
- `make typecheck` — type checking

## Code Style
- [Only include rules Claude would get wrong without them]
- [If Claude already does it correctly, don't write it here]

## Architecture
- [Key patterns: where things live, why]
- [Non-obvious decisions and their reasoning]

## Workflow
- All PRs require passing CI + human review
- Commit messages use conventional commits (feat:, fix:, refactor:, chore:)
- Security-sensitive changes require /sec-review before PR
```

**Budget:** ~150-200 instructions max. Beyond that, compliance drops. For each line ask: *"Would removing this cause Claude to make mistakes?"* If not, cut it.

**Hierarchy:**
- `~/.claude/CLAUDE.md` — personal defaults (all projects)
- `./CLAUDE.md` — team shared (committed to git)
- `./CLAUDE.local.md` — personal overrides (.gitignored)
- `./subdir/CLAUDE.md` — subdirectory-specific (loaded on demand)

### Custom Subagents

Create specialized reviewers in `.claude/agents/`:

```markdown
# .claude/agents/security-reviewer.md
---
name: security-reviewer
description: Reviews code for security vulnerabilities
tools: Read, Grep, Glob, Bash
model: opus
---
You are a senior security engineer. Review code for:
- Injection vulnerabilities (SQL, XSS, command injection)
- Authentication and authorization flaws
- Secrets or credentials in code
- Insecure data handling
- OWASP Top 10

Provide specific line references and suggested fixes.
```

```markdown
# .claude/agents/architecture-reviewer.md
---
name: architecture-reviewer
description: Reviews code for architectural consistency
tools: Read, Grep, Glob, Bash
model: opus
---
You are a senior architect. Review for:
- Consistency with existing patterns in the codebase
- Proper separation of concerns
- No unnecessary abstractions or premature optimization
- API contract stability
- Dependency hygiene
```

### Hooks — Deterministic Quality Gates

Unlike CLAUDE.md instructions (advisory), hooks are **guaranteed to run**. Configure in `.claude/settings.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "command": "make lint-changed 2>&1 | head -20",
        "description": "Lint after every file edit"
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Bash(git commit*)",
        "command": "make typecheck 2>&1 | tail -10",
        "description": "Typecheck before any commit goes through"
      }
    ]
  }
}
```

### Skills — Reusable Workflows

Create team skills in `.claude/skills/`:

```markdown
# .claude/skills/feature/SKILL.md
---
name: feature
description: Implement a feature from a spec
---
Implement the feature described in $ARGUMENTS.

1. Read the spec file thoroughly
2. Plan the implementation (use Plan Mode if complex)
3. Implement with tests
4. Run the full test suite
5. Use a subagent for security review
6. Use a subagent for architecture review
7. Commit with conventional commit message
8. Push and create PR with summary
```

---

## Phase 1: Spec-Driven Design

### Why Specs Matter More with AI

AI executes what you describe. A vague spec produces code that "looks right but doesn't work." A precise spec produces code that's correct on the first pass.

### The Interview Pattern

For new features, let Claude interview you before writing the spec:

```
I want to build [brief description]. Interview me in detail using the AskUserQuestion tool.

Ask about technical implementation, edge cases, security concerns, and tradeoffs.
Don't ask obvious questions — dig into the hard parts I might not have considered.

Keep interviewing until we've covered everything, then write a complete spec to docs/specs/FEATURE_NAME.md.
```

### Spec Structure

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
[Which components change. How they interact.]

## Security Considerations
[Auth requirements, input validation, data exposure risks]

## Verification Criteria
[How do we know this works? Test cases, expected behaviors]
- [ ] Test case 1: [input] → [expected output]
- [ ] Test case 2: [edge case] → [expected behavior]
- [ ] Test case 3: [failure mode] → [expected error]

## Out of Scope
[What this does NOT include, to prevent scope creep]
```

### Supporting Documents (as needed)

- **Architecture doc** — for changes that affect system structure
- **Security doc** — for auth/data/access changes
- **PRD** — for user-facing features that need product context

Start each in a new Claude session with clean context. The spec is the source of truth.

---

## Phase 2: Roadmap & Task Breakdown

### Roadmap Structure

Create `docs/roadmap/NNN_phase-name.md` per phase — the zero-padded prefix (`001_`, `002_`, ...) makes phase order obvious and keeps files sorted on disk:

```markdown
# Phase: [Name]

## Context
[What this phase accomplishes. Dependencies on prior phases.]

## Tasks

### Task 1: [Name]
- **Spec:** docs/specs/feature_x.md
- **Files:** src/api/routes.py, src/models/user.py
- **Dependencies:** None
- **Verification:** `make test-feature-x`
- **Estimated complexity:** Low/Medium/High

### Task 2: [Name]
- **Spec:** docs/specs/feature_y.md
- **Files:** src/services/auth.py
- **Dependencies:** Task 1 (needs new user model)
- **Verification:** `make test-auth`
- **Estimated complexity:** Medium

### Task 3: [Name] (can parallelize with Task 2)
- **Spec:** docs/specs/feature_z.md
- **Files:** src/ui/dashboard.py (no overlap with Task 2)
- **Dependencies:** Task 1
- **Verification:** `make test-dashboard`
- **Estimated complexity:** Low
```

### Key Rules for Task Breakdown

1. **Identify parallelizable tasks** — tasks that touch different files can run simultaneously
2. **Mark dependencies explicitly** — if Task B needs Task A's output, say so
3. **Keep tasks small enough for one worktree session** — if a task fills context, it's too big
4. **Include verification commands** — every task needs a way to prove it works

---

## Phase 3: Parallel Implementation

### Worktree-Based Parallel Development

Each task gets its own worktree. Worktrees auto-create branches.

```bash
# Start a worktree for each independent task
claude --worktree feature-auth    # creates branch worktree-feature-auth
claude --worktree feature-dashboard  # creates branch worktree-feature-dashboard

# Or use tmux for multiple panes
claude --worktree feature-auth --tmux
```

**What happens under the hood:**
1. Creates isolated directory at `.claude/worktrees/<name>/`
2. Creates git branch `worktree-<name>` from `origin/HEAD`
3. Starts Claude in that isolated directory

**Cleanup:**
- No changes → auto-deleted on exit
- Changes exist → Claude prompts to keep or remove

### Implementation Flow per Worktree

```
# In each worktree session:

Read the spec at docs/specs/FEATURE_NAME.md and the roadmap task at
docs/roadmap/NNN_phase-name.md#task-N.

Implement the feature following the spec exactly.
Write tests that cover all verification criteria from the spec.
Run the test suite and fix any failures.

When done:
1. Use a subagent to review for security issues
2. Use a subagent to review for architectural consistency
3. Commit with conventional commit messages (split by logical concern)
4. Push the branch
5. Create a PR with summary and test plan
```

### The feature-dev Plugin Pattern

Use the `feature-dev` plugin (`claude-plugins-official` marketplace) to implement one issue within a single session using subagents. It is not spec-file driven by itself — give it the issue and its spec path as the argument:

```
/feature-dev:feature-dev implement issue #42 per docs/specs/feature_x.md
```

This triggers a guided, interactive workflow which:
1. Confirms what needs to be built (discovery)
2. Launches code-explorer subagents to map the relevant code
3. Asks clarifying questions and waits for your answers
4. Launches code-architect subagents and asks which approach you prefer
5. Implements, after your explicit approval
6. Launches code-reviewer subagents and asks what to fix
7. Summarizes what was built

It does not commit, push, or open a PR — run `/pr-review-toolkit:review-pr` on the uncommitted diff, then `/commit`, `git push` and `gh pr create`.

### Fan-Out for Large Migrations

For bulk operations across many files:

```bash
# Generate file list
claude -p "List all Python files that need X migration" > files.txt

# Process in parallel
for file in $(cat files.txt); do
  claude -p "Migrate $file following the pattern in docs/specs/migration.md" \
    --allowedTools "Edit,Read,Bash(make test*)" &
done
wait
```

### Monitoring Parallel Work

Configure notification hooks so you don't have to watch terminals:

```json
// ~/.claude/settings.json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "notify-send 'Claude Code' 'Claude Code needs your attention'"
          }
        ]
      }
    ]
  }
}
```

**Intervention cadence:**
- **5 min after launch** — verify direction and scope
- **Every 15-20 min** — sweep for completions/blockages
- **Rely on hooks** rather than watching terminals

### Avoiding Conflicts in Parallel Work

1. **Task isolation** — each task should touch different files
2. **If overlap is unavoidable** — sequence those tasks, don't parallelize
3. **Interface-first** — define shared interfaces/types first in a base task, then implement in parallel
4. **Frequent rebasing** — rebase worktree branches onto main regularly

---

## Phase 4: Quality Gates

### Layered Defense

```
Layer 1: Hooks (automatic, every edit)
    → Lint, format, typecheck on each file change

Layer 2: Pre-commit (automatic, every commit)
    → Full test suite, security scan, type check

Layer 3: Subagent Review (per feature, before PR)
    → Security review, architecture review

Layer 4: CI/CD (per PR)
    → Full build, all tests, SAST, dependency scan

Layer 5: Human Review (per PR)
    → Business logic, design decisions, edge cases
```

### Secret Sprawl Prevention (Critical)

The 2026 Secret Sprawl Report found Claude Code commits leak secrets **2x more than baseline**. This is mandatory:

```bash
# Install gitleaks or trufflehog as pre-commit hook
brew install gitleaks  # or: pip install trufflehog

# Add to .pre-commit-config.yaml
# - repo: https://github.com/gitleaks/gitleaks
#   hooks:
#     - id: gitleaks
```

Additionally, block Claude from writing to sensitive files via hooks:

```bash
#!/bin/bash
# .claude/hooks/protect-secrets.sh
FILE=$(echo "$TOOL_INPUT" | jq -r '.file_path // empty')
if [[ "$FILE" =~ \.(env|pem|key)$ ]] || [[ "$FILE" =~ credentials|secrets ]]; then
  echo "BLOCKED: Cannot write to sensitive file: $FILE" >&2
  exit 1
fi
```

### Security Review Checklist

Run `/sec-review` or invoke the security-reviewer subagent before every PR:

- Input validation at system boundaries
- No SQL/command/XSS injection vectors
- Auth/authz checks on all endpoints
- No secrets in code or config
- Secure defaults (deny by default)
- Dependencies scanned for known CVEs

### Pre-commit Hook Configuration

```yaml
# .pre-commit-config.yaml
repos:
  - repo: local
    hooks:
      - id: typecheck
        name: Type Check
        entry: make typecheck
        language: system
        pass_filenames: false
      - id: test
        name: Tests
        entry: make test
        language: system
        pass_filenames: false
      - id: security-scan
        name: Security Scan
        entry: make security-scan
        language: system
        pass_filenames: false
```

---

## Phase 5: Review & Merge

### Writer/Reviewer Pattern

**Always trigger a fresh reviewer.** This is an obligation, not just the prohibition it's often stated as. "Don't review your own code" is true but insufficient — the point is that a reviewer with clean context is *actively spawned* every time an implementation lands on a branch, whether that's a subagent that did not write the code or a genuine fresh session. Never skip it because the diff is small, test-only, or looks obviously fine.

Merging stays a separate decision. Default: report the review findings and stop — the human merges. Merge autonomously only when they've said so for that specific piece of work ("autonomous", "merge if it passes"); the authorization is per-task and never carries to the next one.

```
Session A (Writer):   Implements the feature in worktree
Session B (Reviewer): Reviews the PR in a fresh session
```

```
# In fresh session for review:
Review the PR at [branch]. Focus on:
1. Does it match the spec at docs/specs/FEATURE_NAME.md?
2. Edge cases and error handling
3. Security (use security-reviewer subagent)
4. Test coverage — are verification criteria from spec covered?
5. Architectural consistency

Do NOT rewrite the implementation. Flag issues with specific line references.
```

### PR Structure

```markdown
## Summary
- [1-3 bullet points of what changed and why]

## Spec
- Link to docs/specs/FEATURE_NAME.md

## Changes
- [Key files modified and what changed]

## Security
- [ ] Security review completed (subagent or /sec-review)
- [ ] No new dependencies with known CVEs
- [ ] Input validation at all boundaries

## Test Plan
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Verification criteria from spec covered
- [ ] Edge cases from spec tested

## Rollback
- [How to revert if something goes wrong]
```

### Human Review Focus

When AI generates most code, human reviewers should focus on:

1. **Business logic correctness** — does it solve the actual problem?
2. **Design decisions** — are the tradeoffs right?
3. **What's missing** — what didn't the AI think of?
4. **Spec compliance** — does the implementation match the spec?
5. **Security boundaries** — trust the subagent scan but verify auth/access patterns

Don't waste time on style, formatting, or obvious bugs — those should be caught by gates.

### Stacked PRs Tooling

For high-velocity teams, stacked PRs keep individual PRs small (<200 lines) while allowing continuous work:

- **Graphite** (`gt` CLI) — best-in-class. `gt create -am "message"` to stack, `gt submit` to push all with dependencies. Shopify reported 33% more PRs merged per developer.
- **GitHub merge queues** — native support, good for simpler stacking needs
- Graphite Agent data: devs change code **55% of the time** when AI flags an issue (higher than 49% for human reviewers)

### Agent Teams (Experimental)

For complex multi-agent coordination:

```json
// .claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

Agents claim tasks from a shared list, message each other, and coordinate automatically. Useful for: parallel code review (security + architecture + tests), large refactors across modules, complex feature implementation.

---

## Team Conventions

### Branch Naming

```
worktree-<feature-name>     # Auto-created by Claude worktrees
feat/<feature-name>          # Manual feature branches
fix/<issue-description>      # Bug fixes
```

### Commit Messages

```
feat: add OAuth2 authentication flow
fix: handle token refresh race condition
refactor: extract auth middleware to separate module
chore: update dependencies
test: add integration tests for auth flow
docs: add architecture decision record for auth
security: patch XSS vulnerability in input sanitizer
```

Split commits by logical concern. Each commit should leave the codebase in a working state.

### Session Management

- `/clear` between unrelated tasks
- `/compact` when context is getting heavy mid-task
- `/rewind` when an approach fails — don't correct more than twice
- Name sessions: `/rename oauth-migration` for easy resumption
- `claude --continue` to resume, `claude --resume` to pick from list

### Memory & Knowledge Sharing

- **CLAUDE.md** — team conventions (committed to git)
- **Skills** — reusable workflows (committed to git)
- **Agents** — specialized reviewers (committed to git)
- **Hooks** — deterministic quality gates (committed to git)
- **Memory** — personal context (NOT committed, per-developer)

---

## CI/CD Integration

### GitHub Actions Example

```yaml
name: AI-Assisted PR Pipeline

on:
  pull_request:
    branches: [main]

jobs:
  quality-gates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Install dependencies
        run: make install
      - name: Lint
        run: make lint
      - name: Type Check
        run: make typecheck
      - name: Test
        run: make test
      - name: Security Scan
        run: make security-scan

  ai-review:
    runs-on: ubuntu-latest
    needs: quality-gates
    steps:
      - uses: actions/checkout@v4
      - name: AI Code Review
        run: |
          claude -p "Review this PR diff for security issues, \
            architectural concerns, and spec compliance. \
            Be concise — only flag real issues." \
            --output-format json
```

### Non-Interactive Claude in CI

```bash
# PR description generation
claude -p "Generate a PR description for the changes on this branch" --print

# Automated migration
claude -p "Apply migration pattern X to all files matching Y" \
  --allowedTools "Edit,Read" \
  --output-format json

# Security audit
claude -p "Audit this codebase for OWASP Top 10 vulnerabilities" \
  --output-format json > security-report.json
```

---

## Continuous Improvement

### Feedback Loop

1. **After each PR review**, note what Claude got wrong → update CLAUDE.md or create a hook
2. **After each session**, if you corrected Claude on something non-obvious → save to memory
3. **Monthly**, prune CLAUDE.md — remove rules Claude already follows naturally
4. **Quarterly**, review hooks and skills — are they still needed? Are new ones warranted?

For workhorse skills (those that fire across many tasks), don't tune on vibes — benchmark. See [SKILL_QUALITY.md](./SKILL_QUALITY.md) for the A/B process, graded assertions, and a worked example of iterating the (since retired) `/feature` skill through two rounds.

### Metrics to Track

- **PR cycle time** — from branch creation to merge
- **Review iteration count** — how many rounds of feedback per PR
- **Test coverage on AI-generated code** — should be ≥ coverage on human code
- **Security findings in review** — should decrease over time as hooks catch more
- **Context resets per session** — high count suggests tasks are too broad

### The Review Bottleneck

With AI generating more code, review becomes the bottleneck. Address this by:

1. **Smaller, focused PRs** — one concern per PR, easier to review
2. **Spec compliance** — reviewer checks against spec, not reimagines the solution
3. **Automated gates** — catch mechanical issues before human review
4. **AI pre-review** — use Writer/Reviewer pattern to catch issues before human sees it
5. **Stacked PRs** — merge independent work streams without waiting

---

## Quick Reference

```
# Daily workflow
claude --worktree feature-x          # Start isolated work
/issues docs/specs/feature_x.md      # File the GitHub issue for the spec
/feature-dev:feature-dev implement issue #N per docs/specs/feature_x.md   # Implement (feature-dev plugin)
# Or, for a bug (no spec needed): describe it — superpowers' systematic-debugging skill finds the root cause first
/design auth                         # UI features: mock in Paper first
/verify-design owner                 # Then diff running UI vs Paper refs, fix in place
/sec-review                          # Security check
/pr-review-toolkit:review-pr         # Fresh reviewer agents on the uncommitted diff (pr-review-toolkit plugin)
/commit                              # Stage + commit by logical concern
git push && gh pr create             # Open PR (add --draft for WIP)

# Several tasks in one session (superpowers plugin skills — no one-command roadmap pipeline)
# subagent-driven-development / executing-plans / dispatching-parallel-agents

# Parallel work
claude --worktree task-a --tmux      # Terminal 1
claude --worktree task-b --tmux      # Terminal 2
claude --worktree task-c --tmux      # Terminal 3

# Review
claude --continue                    # Resume session
# or fresh session for unbiased review

# Maintenance
/clear                               # Reset context
/compact                             # Compress context
/rewind                              # Undo mistakes
```

---

## Sources & Further Reading

- [Claude Code Best Practices](https://code.claude.com/docs/en/best-practices)
- [Common Workflows](https://code.claude.com/docs/en/common-workflows)
- [Claude Code Hooks Guide](https://code.claude.com/docs/en/hooks-guide)
- [Claude Code Skills](https://code.claude.com/docs/en/skills)
- [Claude Code Subagents](https://code.claude.com/docs/en/sub-agents)
- [Permission Modes](https://code.claude.com/docs/en/permission-modes)
- [2025 DORA Report — AI Impact](https://www.infoq.com/news/2026/03/ai-dora-report/)
- [Parallel Development with Worktrees](https://code.claude.com/docs/en/common-workflows#run-parallel-claude-code-sessions-with-git-worktrees)
- [Claude Code Ultimate Guide](https://github.com/FlorianBruniaux/claude-code-ultimate-guide)
