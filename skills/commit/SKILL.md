---
name: commit
description: "Stage and commit the working tree as one or more conventional commits, split by logical concern. Use when the user says 'commit this', 'save my work', 'check in the changes', or is ready to record progress in git before moving on. Local only: never pushes (use /wf:pr for that). Not for fixing a bug or building a feature (use /wf:fix or /wf:feature, which can commit with --commit)."
---
Stage and commit the current working tree.

## Guardrails

- **One concern per commit.** A bug fix and a refactor, even if both are tiny, go in separate commits. That keeps `git log` and `git blame` useful and lets `git revert` isolate one change.
- **Don't push, force-push, amend, `reset --hard`, or touch the remote.** Those belong to `/wf:pr` or the user; staying in that lane keeps the two operations reviewable independently.
- **Don't bypass pre-commit hooks with `--no-verify`.** Hooks catch real problems (lint, types, secrets). If one fails, the commit didn't happen, so fix the cause and commit again. Never `--amend` after a hook failure: it would rewrite the *previous* commit and quietly overwrite earlier work.
- **Stage explicit paths, not `git add .` / `-A`.** Wildcards sweep in `.env`, credentials, build artifacts and scratch files. Never stage key or credential files or large binaries; list untracked files and ask about any you're unsure of.

## Steps

1. **Survey the working tree** — run in parallel: `git status`, `git diff --stat`, `git log --oneline -10` (the log shows the repo's commit style; match it).
   - Clean tree (nothing staged, unstaged, or untracked and relevant): stop and say there's nothing to commit.
   - On the trunk branch (`main`/`master`, or whatever `git symbolic-ref --short refs/remotes/origin/HEAD` names) or a detached HEAD: trunk is never committed to directly, so propose a `<type>/<slug>` branch per the trunk convention in your global agent instructions (`~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md`) and create it once approved.
   - Changes the user already staged are a hint for grouping, not a mandate.

2. **Read the diffs** of any file whose change isn't obvious from its path (`git diff <file>`, or `git diff --cached <file>` for staged changes). A file named `auth.go` could hold a typo fix or a rewrite.

3. **Group by concern** — assign every changed file to exactly one commit.
   - Types: `feat`, `fix`, `refactor` (behaviour preserved), `docs`, `test`, `perf`, `security`, `chore`, `build`, `ci`.
   - Split a file across commits with `git add -p` when its hunks belong to different concerns.
   - Order groups so each commit leaves the codebase working.
   - If the tree is one concern, one commit is correct. Don't invent splits.

4. **Draft messages** — `<type>: <subject>`, or `<type>(<scope>): <subject>` when recent commits use scopes: imperative, under 72 characters, no trailing period, describing the outcome rather than the mechanism (`fix: reject empty passwords`, not `fix: added if statement`). Add a body only when the *why* is non-obvious: a hidden constraint, a past incident, a tradeoff. Match the casing of recent commits.

5. **Present the plan** before touching git, and wait for explicit approval:

   ```
   Commit 1/N — <type>: <subject>
     Files:
       path/to/file1
     [Body if present]
   ```

   "yes" / "proceed" commits as planned. Targeted edits ("merge 2 and 3", "reword commit 1", "move file X to commit 1", "drop commit 3") revise the plan, which you re-present. "no" / "stop" aborts and leaves the tree untouched.

6. **Commit sequentially.** For each group:
   - Start from an empty index: `git restore --staged .` (the working tree stays intact; in a repository with no commits yet, use `git rm -r --cached -q .` instead).
   - Stage explicit paths (`git add <paths>`, or `git add -p <path>` for partial files).
   - Commit with a HEREDOC:
     ```
     git commit -m "$(cat <<'EOF'
     <type>: <subject>

     <body if any>
     EOF
     )"
     ```
   - Add an attribution trailer (`Co-Authored-By`) only if recent commits carry one or the session's instructions require it.

7. **On a hook failure**, stop. Show the hook output, which commit was being made, and `git status`. Then fix and make a new commit, or ask how to proceed.

8. **Report** — run `git status` and `git log --oneline -<N>` (N = commits created) and show both. The skill ends here; pushing and opening a PR is `/wf:pr`.
