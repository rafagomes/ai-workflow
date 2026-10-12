---
name: fix
description: "Diagnose the root cause of a bug and fix it with a regression test, from a description, a stack trace or error output, or a GitHub issue link. Stops with a working tree to review. Use for 'fix this', 'this is broken', a pasted traceback, or an issue link where a patch is expected. For a feature use /wf:feature."
argument-hint: "<description | issue link | error text>"
---
Fix the bug described in $ARGUMENTS.

## Parse arguments

- **Description:** `/wf:fix users can't login when password contains special chars`
- **Issue link or number:** `/wf:fix https://github.com/org/repo/issues/42`. Run `gh issue view <url|N> --comments` and read the description, comments and labels. If `gh` is unavailable, ask for the issue text.
- **Error output or stack trace:** use it as the reproduction.

## Branch

Run `git fetch origin`, and if the tree is dirty with unrelated changes, say so before starting. Resolve the trunk branch as `<base>`: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`, falling back to `git symbolic-ref --short refs/remotes/origin/HEAD` with `origin/` stripped. Work on a short-lived branch cut from `origin/<base>`, not from another feature branch: `fix/<N>-<slug>` when there is an issue, `fix/<slug>` otherwise. Worktree conventions are in your global `CLAUDE.md` (Trunk-Based Workflow).

## Steps

1. **Reproduce and locate.** Check the project's `CLAUDE.md`, `README.md` and `docs/` for context (for a UI bug, `docs/design/DESIGN_SYSTEM.md` too, if it exists). Find the code path, then reproduce the failure by running the failing test or the reported steps, telling the user what you are doing. Check `git log` on the affected files for the change that may have introduced it. If you cannot reproduce it, say so, list what you tried and ask for the missing input; do not patch on a guess.

2. **Diagnose the root cause.** Trace the data flow from input to the failure point. Explain the cause, not the symptom, in 1-2 sentences before changing code.

3. **Pick the test layer** as in `/wf:feature` step 2 (`docs/ARCHITECTURE.md` Testing Strategy, else inferred from the project): unit for pure logic, integration at a boundary (API, database, service interaction), e2e only if a critical user flow broke and had no e2e coverage.

4. **Fix.** Write the regression test first and watch it fail for the right reason. Then make the minimal change that fixes the root cause, without refactoring surrounding code, and confirm the test passes. If the bug is at a trust boundary or in auth, crypto, input parsing, secrets, permissions, dependencies, or anything that runs automatically, note that it needs `/security-review` before the PR.

5. **Quality checks.** Run the project's lint, typecheck and the full test suite (so a regression elsewhere shows up); report each in one line (command, result) and paste output only for a failure.

   **Size gate.** Measure the hand-written source this change adds:
   `git diff --numstat $(git merge-base origin/<base> HEAD) -- . ':(exclude,glob)**/tests/**' ':(exclude,glob)**/__tests__/**' ':(exclude,glob)**/*_test.*' ':(exclude,glob)**/*.test.*' ':(exclude,glob)**/*.spec.*' ':(exclude,glob)**/*_spec.*' ':(exclude,glob)**/test_*' ':(exclude,glob)**/*.lock' ':(exclude,glob)**/*-lock.*'`
   This compares the working tree with the point the branch left the trunk, so it counts committed and uncommitted work alike. Sum the first column and add the line counts of new untracked source files (`git status --porcelain` lists them; `git diff` does not), applying the same exclusions and skipping binaries. Leave out generated files and files that only moved. Over ~500: decide whether it is one concern. One concern: carry on, and say in the report how large it is and why it stays together. More than one (a fix that grows into a refactor is two slices): stop and propose a split via AskUserQuestion, and do not leave it in the working tree without the user's override.

6. **Report and stop.** Do not review your own fix: `/wf:pr` dispatches `wf:reviewer` once the commits exist. Summarize:
   - **Root cause** - 1-2 sentences on what was broken.
   - **Files changed** - `git diff --stat`, or a short list.
   - **Regression tests** - layers added, where they live, how to re-run them.
   - **Verification** - each check in one line.
   - **Issue link** - if one was provided.

   Then stop. The user reviews the working tree and decides next steps, typically `/wf:commit` then `/wf:pr`.
