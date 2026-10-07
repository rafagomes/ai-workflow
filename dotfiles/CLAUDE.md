# Global Defaults

## Verification
- Always verify work before claiming completion: run lint/build/tests and check outputs against the stated design or spec references.
- Before saying you're done, run lint, typecheck, and tests, and paste the tail of each output. If anything fails, fix and re-run.

## Workflow
- Spec first, code second - read the spec before implementing
- Commit messages use conventional commits: feat:, fix:, refactor:, chore:, test:, docs:, security:
- Split commits by logical concern; each commit leaves the codebase working
- Security-sensitive changes require /sec-review before PR
- **Writer/reviewer pattern — ALWAYS trigger a fresh reviewer.** This is an obligation, not just a prohibition. "Don't review your own code" is true but insufficient: once an implementation is on a branch, actively spawn a reviewer with clean context — a subagent that did not write the code, or a fresh session. Do this every time, unprompted. Never skip it because the diff is small, test-only, or "obviously fine".
- **Merging is gated on me, not on the review passing.** Default: after the review, report the findings and stop — I merge. Merge autonomously only when I have said so for that specific piece of work ("autonomous", "you can merge", "merge if it passes"). That authorization is per-task and never carries to the next one.

## UI Work
- Before implementing UI work, always load and reference the Paper design source; do not proceed without it.

## File Conventions
- Prefer refactoring existing files over creating new ones; ask before introducing parallel docs/configs.

## Git Workflow
- Check you are in the correct project directory and that it is a git repo before running commit/PR/bootstrap commands.
- Sync with the remote before starting work: `git fetch origin` at the start of every session and before each new task/phase, and check for divergence from the tracking branch — the user works from parallel sessions/machines, so the remote may have moved. If histories have diverged, reconcile before building (published history wins by default); never force-push over unseen remote commits.

## Trunk-Based Workflow
- `main` is trunk; always deployable. No long-lived `develop` or `release/*` branches.
- Branches are short-lived (hours to ~2 days). Name them by type: `feat/<slug>`, `fix/<slug>`, `refactor/<slug>`, `docs/<slug>`, `chore/<slug>`, `test/<slug>`, `perf/<slug>`, `security/<slug>`.
- **One branch = one PR = one vertical slice.** Target ≤200 lines of diff **excluding tests** — count source lines only. Test lines never count toward the budget, so never trim or skip tests to fit. If larger, split before opening the PR.
- Large features ship as N independently mergeable slices off `main`, not stacked on each other. If a slice isn't user-ready, merge it behind a feature flag so `main` stays deployable.
- Worktrees live **outside the repo** (e.g., `../<repo>-<slug>`) to keep `git status` clean. If kept inside, add the directory to `.gitignore`.
- After merge: delete the branch (local + remote) and remove the worktree. Never reuse a merged branch.
- Canonical feature flow: `/spec` → (slice if >200 lines) → `/issues` (file milestones + issues on GitHub) → implement the issue from its spec (in Claude Code: `/feature-dev:feature-dev <issue + spec path>`) → review the diff → `/commit` → push + `gh pr create` → **fresh reviewer (subagent or fresh session) — always, never optional** → report findings → merge (mine to call unless I declared the task autonomous) → delete branch + worktree.
- Full guide (why, how, recipes, FAQ): `docs/TRUNK_BASED_WORKFLOW.md` in the ai-workflow repo.

## Code Quality
- No unnecessary abstractions - keep code as simple as it can be
- No speculative features or premature generalization
- Validate at system boundaries (user input, external APIs), trust internal code
- Tests must cover verification criteria from the spec

## PR Structure
- Keep PRs focused: one concern per PR, under 200 lines of **non-test** diff when possible (see **Trunk-Based Workflow** above for slicing rules and feature-flag expectations)
- PR description must include: summary, link to spec, security checklist, test plan

## Context Management
- /clear between unrelated tasks
- /compact when context gets heavy mid-task
- /rewind when an approach fails after 2 corrections

## Toolkit (available skills)
- Core skills installed under `~/.claude/skills/`: `/prd`, `/architecture`, `/tdd`, `/security`, `/adr`, `/rfc`, `/spec`, `/roadmap`, `/issues`, `/commit`, `/new-project`, `/sec-review`, `/design`, `/verify-design`.
- For stack-aware code review, use Anthropic's official `code-review` skill (from `claude-code-plugins`). The previous custom `/code-review` was deprecated after a benchmark showed no detection lift over baseline at ~1.5× cost. Language guides in `~/.claude/reviews/` stay installed — hand the matching guide to the reviewer as stack criteria.
- Execution is not part of this toolkit — it comes from `claude-plugins-official` plugins, which may not be installed: `feature-dev` (`/feature-dev:feature-dev`, implement an issue from its spec; interactive, Claude Code only), `pr-review-toolkit` (`/pr-review-toolkit:review-pr`; Claude Code only; it reads uncommitted changes, so run it before `/commit` or give the reviewer the range `main...HEAD`), and `superpowers` (`systematic-debugging` for bugs; `subagent-driven-development`, `executing-plans`, `dispatching-parallel-agents` for multi-task plans; `finishing-a-development-branch`; also installs on Codex and Cursor). Where a plugin is missing, do the step directly. Open PRs with `git push` + `gh pr create`.
- Skill sources, installer, and maintenance rules live in the `ai-workflow` repo. Maintenance instructions only apply when working inside that repo — see its project-level `CLAUDE.md`.
