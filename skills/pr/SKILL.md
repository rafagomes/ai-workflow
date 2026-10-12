---
name: pr
description: "Push the current branch and open a pull request with gh (commits must already exist). Use when the user says 'open a PR', 'push this up for review', 'ship this branch', or 'create a draft PR'. Opens a draft, has the fresh-context wf:reviewer review it, fixes HIGH/MED findings (max 2 rounds), then marks it ready on PASS. Never merges."
argument-hint: "[--draft] [--no-review]"
---
Open a pull request for the current branch. Commits must already exist (from `/wf:commit`, `/wf:feature`, `/wf:fix`, or by hand).

Default flow: open as a draft, have a fresh-context reviewer review the branch, fix HIGH/MED findings in a bounded loop, then mark the PR ready on a pass. This is the writer/reviewer rule in your global `CLAUDE.md`: a reviewer with cold context sees the branch before it becomes review-ready.

## Parse Arguments

$ARGUMENTS may contain:
- **`--draft`** — leave the PR a draft even after the review passes. The review still runs; only the final `gh pr ready` is skipped.
- **`--no-review`** — skip the review loop and open the PR directly (ready, unless `--draft`). Two cases allow it. First, a fresh-context review of these exact commits already ran (say which). Second, the allow-list in your global `CLAUDE.md` → **Review**, repeated here so the skill is self-contained (update both together): the whole diff is a typo, spelling or formatting fix in prose, or a changelog entry or project-version bump. Text that instructs an agent — a skill, an agent definition, a `CLAUDE.md`, a prompt — is behaviour and never qualifies; neither does a revert, a file move, or a dependency bump. When unsure, review. Small or urgent is not a reason to skip. State it in the PR body as `Review: skipped — <reason>`.
- **No flags** — the default flow.

## Guardrails

- **Don't force-push without explicit confirmation, and never to the trunk branch.** Force-pushing rewrites history under everyone who has pulled it; surface the risk and confirm first.
- **Don't merge, request reviewers, add labels or milestones, or close issues.** Those depend on team conventions this skill doesn't have. The body or commits may reference an issue (`Closes #N`), but closing is the user's decision.
- **No Claude / Anthropic co-author tags in the PR body.** Co-authorship belongs on commits, not repeated in the description.
- **A dirty working tree stops the skill**; point the user at `/wf:commit`. Mixing uncommitted work in obscures what the PR contains. The only commits this skill makes are review fixes in step 9, staging just the files it fixed.

## Steps

1. **Check preconditions** (in parallel where possible).
   - `gh auth status` — if it fails, stop and print the manual `git push` plus the proposed title and body.
   - `gh pr view --json url,state,isDraft 2>/dev/null` — if an open PR already exists for this branch, don't create another: push any new commits and continue at step 8 (review).
   - Resolve the trunk branch once as `<base>`: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name`, falling back to `git symbolic-ref --short refs/remotes/origin/HEAD` (strip `origin/`). Run `git fetch origin <base>` and use `origin/<base>` in every range below.
   - `git status` and `git rev-parse --abbrev-ref HEAD`.
   - **Dirty tree:** stop — *"Working tree has uncommitted changes. Run `/wf:commit` first, then re-run `/wf:pr`."*
   - **On `<base>`:** stop — *"You're on `<base>`. Create a feature branch first."*
   - **Branch name off the convention** (`feat|fix|refactor|docs|chore|test|perf|build|ci|security/<slug>`, see **Trunk-Based Workflow** in your global `CLAUDE.md`): warn and offer to rename before pushing.
   - **Size.** Measure the added hand-written source:
     `git diff --numstat origin/<base>...HEAD -- . ':(exclude,glob)**/tests/**' ':(exclude,glob)**/__tests__/**' ':(exclude,glob)**/*_test.*' ':(exclude,glob)**/*.test.*' ':(exclude,glob)**/*.spec.*' ':(exclude,glob)**/*_spec.*' ':(exclude,glob)**/test_*' ':(exclude,glob)**/*.lock' ':(exclude,glob)**/*-lock.*'`
     and sum the first column. Leave out generated files and files that only moved. Over ~500: decide whether it is one concern. One concern: carry on, say in your report how large it is and why it stays together, and add that line to the PR body. More than one: warn, suggest the split, and proceed only if the user confirms. Never split one concern to get under the number.

2. **Gather the range:** `git log origin/<base>..HEAD --oneline`, `git diff origin/<base>...HEAD --stat`, and the full diff when drafting. Empty range: stop, nothing to PR. Read every commit and the whole diff — the summary describes the branch, not the tip commit.

3. **Check upstream state:** `git rev-parse --abbrev-ref --symbolic-full-name @{u}` and `git status -sb`.
   - No upstream: `git push -u origin <branch>`.
   - Ahead: `git push origin <branch>`.
   - Behind or diverged: stop; don't pull, rebase or force-push. Tell the user.
   - Up to date: proceed.

4. **Title** — under 70 characters, imperative, **no type prefix** (that belongs in commit messages), describing the outcome. Good: `Add rate limiting to auth endpoints`. Bad: `feat: added rate limiter middleware with token bucket algorithm`.

5. **Body** — these sections in order; delete any that has nothing to say:

   ```markdown
   ## Summary
   - <1-3 bullets on what changed and why>

   ## Spec
   <link to the matching spec (scan docs/specs/, specs/, the feature dir)>

   ## Review
   <only with --no-review: `Review: skipped — <reason>`>

   ## Security checklist
   <only if the diff touches auth, sessions, crypto, password handling, input validation,
   SQL/command construction, file uploads, secrets, env vars, or external API calls>
   - [ ] Inputs validated at system boundary
   - [ ] No secrets or credentials in code/logs
   - [ ] Auth/authz checks unchanged or reviewed
   - [ ] External API calls use timeouts and error handling
   - [ ] <checks specific to what changed>

   ## Test plan
   - [ ] <how to verify each change: commands, URLs, manual steps>
   ```

   The Test plan is always required; "run the existing suite" counts. A focused 5-line body beats a templated 30-line one.

6. **Present the draft** and wait for approval; revise on edits and re-present.
   ```
   Title: <title>
   Base:  <base>
   Head:  <branch>
   Flow:  draft → fresh review → ready   (or: draft-only [--draft] / direct, no review [--no-review])

   Body:
   <full body>
   ```

7. **Create the PR** with a HEREDOC body:
   ```
   gh pr create --base <base> --title "<title>" [--draft] --body "$(cat <<'EOF'
   <body>
   EOF
   )"
   ```
   Always pass `--draft` when the review loop will run, so the branch is never review-ready before its review. With `--no-review`, pass it only if the user wants a draft.

8. **Review.** Skip only when `--no-review` was passed. You are the writer and never review your own work; an in-session review skill runs in your context and does not count. Dispatch the `wf:reviewer` agent, which starts cold. It runs in your working tree, so the tree must be clean:

   ```
   Agent(
     subagent_type: "wf:reviewer",
     description: "Review PR branch",
     prompt: "Base: <base>\nSpec: <spec-path, or 'none'>\nVerify: <the project's lint / typecheck / test commands>"
   )
   ```

   Take the `Verify` commands from the project's `CLAUDE.md`, `Makefile` or package scripts; pass `none` if there are none. It returns `VERDICT` (`PASS` or `FIX_REQUIRED`), `CHECKS`, `FINDINGS` (`HIGH` / `MED` / `LOW`) and `SUMMARY`.

9. **Process the verdict and fix.** Record the verdict as a PR comment (`gh pr comment <url> --body …`), never as `gh pr review --approve`.
   - `PASS`, no findings: `Review: PASS`; go to step 10.
   - `PASS` with only LOW findings: `Review: PASS_WITH_NITS`; list the LOW items in the final report; go to step 10.
   - `FIX_REQUIRED`: fix exactly the listed HIGH/MED items, re-run the project's lint, typecheck and tests, commit the fixes (conventional message), `git push`, and re-dispatch the reviewer with an extra line `Previous findings: <list>`.

   At most 2 fix cycles. If cycle 2 still returns `FIX_REQUIRED`, record `Review: NEEDS_HUMAN — <count> HIGH/MED unresolved after 2 cycles` (add `Spec ambiguity suspected at <spec-path>` if one finding category recurred), leave the PR a draft, and stop looping. `PASS_WITH_NITS` and `NEEDS_HUMAN` are this skill's labels, not reviewer verdicts. Commits that change behaviour after a `PASS` need a fresh review before merge.

10. **Ready transition.**
    - If the diff touches auth, crypto, input parsing, secrets or permissions, run the built-in `/security-review` first (fresh context). A HIGH or MED finding keeps the PR a draft: fix it as in step 9, within the same 2-cycle budget, and have the reviewer look at the fix commits, since they change behaviour. List LOW findings in the report.
    - `PASS` or `PASS_WITH_NITS` and no `--draft`: `gh pr ready <url>`.
    - `--draft`: leave it a draft and report the passing verdict.
    - `NEEDS_HUMAN`: leave it a draft and report the unresolved items.
    - `--no-review`: nothing to flip; step 7 set the final state.

11. **Report** the PR URL, its draft/ready state, and the review outcome (`PASS`, `PASS_WITH_NITS` with the nits, or `NEEDS_HUMAN` with the unresolved items). If the reviewer's `CHECKS` says a check left the tree dirty, say so, or the next `/wf:pr` run stops on a dirty tree unexplained. Then add this reminder without running it (the PR isn't merged yet):

    *"After merge: `git checkout <base> && git pull --ff-only && git push origin --delete <branch>; git branch -D <branch>` (only once the PR shows MERGED; the remote delete is a no-op if GitHub already deleted it), plus `git worktree remove <path>` if you used a worktree. Never reuse a merged branch."*

The skill ends here.
