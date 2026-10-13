---
name: feature
description: "Implement a feature from a spec (docs/specs/NNN_<name>.md), a spec slice, or a GitHub issue: write the code and tests, run the checks, and stop with a working tree to review. --commit also commits; --pr also opens the PR and runs its review. Use for 'implement the auth spec', 'build feature X', 'code up the Y spec', 'work on issue #42', or any request to execute a spec. For bugs use /wf:fix."
argument-hint: "<spec name | path | #issue> [--commit | --pr]"
---
Implement the feature described in $ARGUMENTS.

## Parse arguments

- `<name>` → resolve to `docs/specs/NNN_<name>.md` by matching the suffix after the `NNN` prefix (numbering rules are in `/wf:spec`). A sliced spec is a directory `docs/specs/NNN_<name>/`: implement one slice at a time, ask which slice, and never use its `README.md`. If several specs match, ask which.
- `<path>.md` → use that path.
- `#<N>` → run `gh issue view <N> --comments` and find the spec whose `**Issue:**` line in `## Trunk Metadata` is `#<N>`, or the slice whose row in a sliced spec's `README.md` Slices table has `#<N>` in its `Issue` column. If none matches, ask whether to create a spec first (`/wf:spec`) or build inline from the issue text. If `gh` is unavailable, ask for the issue text.
- No spec found → ask whether to create one via `/wf:spec <name>` or build from an inline description.
- `--commit` → once the feature is complete and verified, commit by following `/wf:commit`, skipping only the step that asks you to approve the commit plan. Output only the `git log --oneline -<N>` lines for the new commits.
- `--pr` → implies `--commit`, then open the PR by following `/wf:pr`, skipping only the step that asks you to approve the title and body. `/wf:pr`'s fresh-context review still runs. Output only the `git log` lines, the PR URL and the review verdict. If the review has not converged after two rounds, leave the PR as a draft and report the findings.

Ask decisions with AskUserQuestion (recommended option first, labelled "(Recommended)"). If the user cannot be asked (a headless run), take the recommended option and list it as an assumption in the report.

## Branch

Start with `git fetch origin` and compare against the tracking branch, since work may have moved on another machine. If the tree is dirty with unrelated changes, say so before starting. If the branch already has commits for this spec, read them and continue instead of redoing finished work.

Resolve the trunk branch as `<base>`: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`, falling back to `git symbolic-ref --short refs/remotes/origin/HEAD` with `origin/` stripped. Work on a short-lived branch cut from `origin/<base>`, never from another feature branch (trunk forbids stacking). If uncommitted work sits on the wrong branch, carry it over with `git switch -c` rather than stashing.

Name the branch from the spec's `## Trunk Metadata` — for a slice, from its row in the parent `README.md` Slices table, which holds the same fields:
- `<type>/<N>-<slug>` when `**Issue:**` holds `#<N>` (e.g. `feat/42-jira-sync`).
- `<type>/<slug>` when it is `—` or empty: the issue is unfiled. Do not rename the branch when the issue is filed later; put `Closes #<N>` in the PR body.
- `<slug>` is the spec's file name with everything up to and including the first `_` removed, and without `.md`: `docs/specs/003_jira-sync.md` → `jira-sync` (and `003.A_jira-sync.md` → `jira-sync`). For a slice, join the parent directory's slug and the slice's, so two features with a same-named slice cannot collide: `docs/specs/003_jira-sync/002_webhook.md` → `jira-sync-webhook`. `/wf:autopilot` derives the same name to find a task's PR, so do not improvise one.
- `<type>` is the spec's `**Type:**` (`feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `perf`, `build`, `ci`, `security`). If `Type` is missing, warn and use `feat`.

Worktree conventions are in your global `CLAUDE.md` (Trunk-Based Workflow).

**UI work.** If the spec names a design reference, or `docs/design/DESIGN_SYSTEM.md` exists, read it before writing UI code and follow its Implementation Fidelity Protocol; if the task is UI and there is no design source, say so in the report rather than inventing one.

## Workflow

1. **Read the spec.** Your tests must cover each Verification Criterion.

2. **Pick a test strategy.** Read the Testing Strategy in `docs/ARCHITECTURE.md` (in older projects, `docs/TECHNICAL_DESIGN_DOCUMENT.md`) if it exists; otherwise infer it from the project (test dirs, `package.json` / `pyproject.toml` / `Makefile`, one or two existing tests). Unit tests always; integration tests when the feature crosses a boundary (API, DB, filesystem, subprocess); e2e only for critical user flows. In a monorepo, run checks from the package the spec touches. If no tests exist yet, set up the minimum infrastructure and tell the user.

   Place each test by what it covers, mirroring the project's `unit/` and `integration/` split: a test that crosses a real boundary is integration even if it runs fast, and pure logic is unit. Misplaced tests drift out of the slow-path CI filter and stop catching boundary regressions.

3. **Plan if non-trivial.** If the change touches 3+ files or has non-obvious design decisions, use Plan Mode to align before writing code.

4. **Implement with tests, layer by layer.** Unit, then integration, then e2e. Run each layer and fix failures before moving on. Vary the test data in whatever the code depends on (sizes, lengths, order, scale); uniform fixtures hide bugs. Before the quality checks, remove or break the behaviour each new test covers and see the test fail; rewrite a test that still passes.

5. **Quality checks.** Run the project's lint, typecheck and tests (commands are in the project's `CLAUDE.md` or Makefile); report each in one line (command, result) and paste output only for a failure.

   **Feature flag.** If the spec's `**Flag:**` names a flag other than `none` (or its `## Feature Flag` section does), verify the new behavior is gated by it. If the flag does not exist yet, create it, default off, as part of this slice.

   **Size gate.** Measure the hand-written source this change adds:
   `git diff --numstat $(git merge-base origin/<base> HEAD) -- . ':(exclude,glob)**/tests/**' ':(exclude,glob)**/__tests__/**' ':(exclude,glob)**/*_test.*' ':(exclude,glob)**/*.test.*' ':(exclude,glob)**/*.spec.*' ':(exclude,glob)**/*_spec.*' ':(exclude,glob)**/test_*' ':(exclude,glob)**/*.lock' ':(exclude,glob)**/*-lock.*'`
   This compares the working tree with the point the branch left the trunk, so it counts committed and uncommitted work alike. Sum the first column and add the line counts of new untracked source files (`git status --porcelain` lists them; `git diff` does not), applying the same exclusions and skipping binaries. Leave out generated files and files that only moved. Over ~500: decide whether it is one concern. One concern: carry on, and say in the report how large it is and why it stays together. More than one: stop and ask. For a single-file spec, offer "ship as-is" plus one or two concrete splits (e.g. sub-slices under `docs/specs/NNN_<name>/`), recommending "ship as-is" only when the bulk is mechanical. For a slice of a sliced feature, offer "ship as-is" and "defer these hunks to a follow-up slice". The number prompts the question and is not a cap: never split one concern to get under it.

6. **Report and stop.** A reviewer needs cold context, so do not review your own work here: `/wf:pr` dispatches `wf:reviewer` once the commits exist. With `--commit` or `--pr`, run the flow under Parse arguments; on a pre-commit hook failure, stop and surface the error, never bypass with `--no-verify`.

   Without a flag, summarize:
   - **Files changed** - `git diff --stat`, or a short list.
   - **Verification** - each check in one line.
   - **Slice metadata** - spec link and `Closes #N` (or "none, ran before /wf:issues"), flag state, test plan.

   Then stop. The user reviews the working tree and decides next steps, typically `/wf:commit` then `/wf:pr`.
