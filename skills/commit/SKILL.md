---
name: commit
description: "Stage and commit the working tree, splitting unrelated changes into separate conventional commits. Use when the user says 'commit this', 'save my work', 'wrap this up', 'check in the changes', wants the working tree split into logical commits with conventional-commit messages, or is ready to record progress in git before moving on."
---
Stage and commit the current working tree.

## Guardrails

A few things that matter, and why:

- **Keep commits focused — one concern per commit.** A bug fix and a refactor, even if both are tiny, go in separate commits. This is what makes `git log` and `git blame` useful later, and it's what lets reviewers (and `git revert`) isolate one change without dragging in others.
- **Don't push, force-push, amend, reset, or touch the remote.** Those belong to the PR step (`gh pr create`) or the user. This skill's job ends at the local commit — staying in that lane keeps the two operations reviewable independently.
- **Don't bypass pre-commit hooks with `--no-verify`.** Hooks exist to catch real problems (lint, types, secrets). If one fails, the commit didn't happen — fix the underlying issue and commit again. Do **not** `--amend` after a hook failure: since the commit didn't land, `--amend` would rewrite the *previous* commit, quietly overwriting earlier work.
- **Stage explicit paths, not `git add .` / `-A`.** Wildcards sweep in whatever's lying around — `.env`, credentials, build artifacts, half-finished scratch files. Naming paths explicitly keeps that stuff out.
- Follow the global CLAUDE.md rule: *"Split commits by logical concern; each commit leaves the codebase working."*

## Steps

1. **Survey the working tree** — run in parallel:
   ```
   git status
   git diff --stat
   git log --oneline -10
   ```
   - `status` + `diff --stat` show the full picture of what changed.
   - `log --oneline -10` shows the repo's existing commit style so your messages match it.
   - If the tree is clean (nothing staged, nothing unstaged, no untracked relevant files), stop and tell the user there's nothing to commit.

2. **Read the actual diffs** — for any files where the nature of the change isn't obvious from the path, run `git diff <file>` (or `git diff --cached <file>` for already-staged changes) so you understand what each hunk does. Don't guess — a file named `auth.go` could contain a typo fix or a complete rewrite.

3. **Group by logical concern** — walk every changed file and assign it to exactly one commit group. Valid concern boundaries:
   - A new feature or capability (`feat:`)
   - A bug fix (`fix:`)
   - A refactor that preserves behavior (`refactor:`)
   - Docs-only changes (`docs:`)
   - Test additions or fixes (`test:`)
   - Config, tooling, or build changes (`chore:`, `build:`, `ci:`)
   - Performance work (`perf:`)
   - Security fixes (`security:`)

   **Rules:**
   - A single file can be split across commits using `git add -p` if its hunks belong to different concerns. Prefer this over lumping.
   - If two groups depend on each other (group B doesn't build without group A), order them so each commit leaves the codebase working.
   - If the tree really does represent one concern, one commit is correct — don't invent splits.

4. **Draft commit messages** — for each group:
   - **Type:** feat / fix / refactor / docs / test / chore / perf / security / build / ci
   - **Subject:** imperative mood, under 72 chars, no trailing period. Describe the outcome, not the mechanism. (`fix: reject empty passwords` not `fix: added if statement`)
   - **Body (optional):** only when the *why* is non-obvious — a hidden constraint, a past incident, a tradeoff the reader wouldn't infer from the diff. Skip the body for self-evident changes.
   - Match the casing and style of recent commits from step 1.

5. **Present the plan** — show the user the full commit plan BEFORE touching git:

   ```
   Commit 1/N — <type>: <subject>
     Files:
       path/to/file1
       path/to/file2
     [Body if present]

   Commit 2/N — ...
   ```

   Wait for explicit approval. Accept:
   - **"yes" / "proceed" / "looks good"** → commit as planned
   - **Targeted edits** → `"merge 2 and 3"`, `"reword commit 1 as ..."`, `"move file X from commit 2 to commit 1"`, `"drop commit 3 entirely"` — revise the plan and re-present until approved
   - **"no" / "stop"** → abort, leave the working tree untouched

6. **Commit sequentially** — for each approved group:
   - `git reset` any previously staged changes that don't belong to this commit (start from a clean index each time)
   - Stage explicit paths: `git add path/to/file1 path/to/file2` (or `git add -p path/to/file` for partial-file splits)
   - Commit with a HEREDOC for the message:
     ```
     git commit -m "$(cat <<'EOF'
     <type>: <subject>

     <body if any>
     EOF
     )"
     ```
   - **Do not** add `Co-Authored-By` trailers unless the user has that configured as a repo convention (check recent commits in step 1).

7. **On pre-commit hook failure** — stop immediately. Show the user:
   - The exact hook error output
   - Which commit was being created
   - The current index state (`git status`)

   Ask how to proceed. Common paths: fix the issue and retry as a *new* commit (not `--amend`), or unstage and escalate to the user. Never bypass with `--no-verify`.

8. **Report** — after all commits land:
   ```
   git status
   git log --oneline -<N>
   ```
   where `<N>` is the number of commits created. Show both to the user so they can verify the result and see the new history.

## Scope boundary

This skill is **local-only**. It stops after the final `git log`. If the user wants to push and open a PR, that is a separate step (`git push` + `gh pr create`).
