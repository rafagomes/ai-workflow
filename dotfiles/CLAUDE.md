# Global Defaults

## Language
- **Everything you create is in English**: docs, code, comments, identifiers, commit messages, PRs, issues, config and any other written artifact, whatever language I am speaking, until I explicitly say otherwise for that piece of work.
- Chat replies follow the language of my message, and English when it is unclear.

## Verification
- Before saying a change is done, run the project's lint, typecheck and tests and fix what fails. Report each check in one line (command, result); paste output only for a failure.
- If the project has no such checks, say so and say what you verified instead. Never report a check you did not run.
- Check the result against the spec or design it implements, not only against the checks.

## Workflow
- Spec first, code second: read the spec before implementing. A bug fix, or a chore that adds no behaviour, needs no spec.
- Commits are conventional (`feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`, `perf:`, `build:`, `ci:`, `security:`), split by logical concern, and each leaves the codebase working.
- **Security triggers:** a trust boundary, auth, crypto, input parsing, secrets, permissions, dependencies, anything that runs automatically. A change touching one gets the built-in `/security-review` (in Codex, a fresh-context security review prompt, or the Codex Security plugin if installed) before the PR is marked ready. Its `HIGH` and `MED` findings block the PR and are fixed within the reviewer's two rounds (Review), not two more; `LOW` findings are listed.

## Review
- **Every PR that changes behaviour is reviewed by a fresh context before it is ready**, unprompted, however small or test-only: the `wf:reviewer` agent (Claude Code, on Opus) or `wf-reviewer` (Codex), which `/wf:pr` dispatches, or a fresh session. The context that wrote the code never reviews it.
- **One reviewer per PR, at most two fix rounds.** Each round fixes the `HIGH` and `MED` findings and re-reviews. A PR that has not converged after two rounds stays a draft and comes to me with the findings.
- **A fix round changes only what the `HIGH` and `MED` findings require**, each fix with a test that fails without it where the project's suite can test it (otherwise say how it was verified), and the whole suite runs again before the push. `LOW` findings are never fixed in a fix round: that would be new code the next review was not asked to read. The `LOW` findings of every round go in the PR's final review comment.
- **The first review is the full one; a re-review is narrow.** It confirms each previous finding is resolved and reads the commits made since for what they broke. Anything those commits introduced or broke keeps its severity and blocks, in a caller they did not touch too. A defect that was already there and the first review missed blocks only when it is `HIGH`; anything less is listed in the PR for me with its severity. Rounds I allow past two are re-reviews of this kind, never a second full review.
- **What may skip the reviewer:** only a diff that is entirely typo, spelling or formatting fixes in prose, or a changelog entry or project-version bump. Text that instructs an agent — a skill, an agent definition, a `CLAUDE.md` or `AGENTS.md`, a prompt — is behaviour and never qualifies; neither does a revert, a file move, or a dependency bump. When unsure, review. State a skipped review in the PR body (`Review: skipped — <reason>`).
- A PR that changes after a `PASS` is re-reviewed only if the new commits change behaviour.
- **Merging is my call, not the review's.** After the review, report the findings and stop. Merge on your own only when I said so for that piece of work ("merge it", "merge if it passes", "autonomous", or `/wf:autopilot` without `--supervised`). That covers only the task I gave it for, and never a T2 PR unless I said so for T2 work.

## Risk tiers
Review depth follows blast radius and reversibility, not size. This is the one definition, and everything else points here. The highest matching tier wins; when unsure, take the higher one.
- **T0** — the diff is entirely what may skip the reviewer (Review). Review skipped.
- **T1** — an ordinary change. One reviewer pass.
- **T2** — touches a security trigger (Workflow), a data migration or schema, CI/CD, deploy or infra config, a public API or contract other code depends on, a shared core module with many callers, or anything hard to reverse. The reviewer, the `/security-review` gate when a security trigger applies, and **a human merge**: a blanket merge authorization does not cover a T2 PR unless I said so explicitly for T2 work in that task.
- The tier is declared in the spec or task, derived from the diff by whoever writes the code, and assessed again by the reviewer; the diff wins when it is higher. A higher assessed tier is a correction the dispatcher makes to the PR body, not a review finding, a fix round or a reason to re-review.

## Git
- Before a commit or PR, confirm you are in the intended repository and on the intended branch.
- Sync before starting: `git fetch` at the start of a session and before each new task, and check the branch against its upstream — I work from parallel sessions and machines. Reconcile diverged histories before building; published history wins, and never force-push over commits you have not seen.
- The `wf` plugin's hooks block `--no-verify`, force-pushing or deleting the trunk, and `gh pr review --approve` in Bash commands. They are a heuristic guardrail, not a security boundary; `WF_GUARD=off` in the settings `env` disables them.

## Trunk-Based Workflow
- `main` is trunk and always deployable. No long-lived `develop` or `release/*` branches.
- Branches are short-lived (hours to about two days) and named `<type>/<slug>`, with a commit type from Workflow (`feat/<slug>`, `fix/<slug>`, …).
- **One branch = one PR = one concern**: something a reviewer can hold in one pass, one vertical slice, independently mergeable, with its docs.
- **Size is a signal, not a quota.** Past roughly **1,000 added source lines or ~40 changed source files**, check it is still one concern, and split it if it is two. Tests, generated files, lockfiles, pure moves or renames, and deletions do not count, so never trim tests to fit; and never split one concern to get under the number, since small PRs that only make sense together cost more review than one coherent PR. Risk, not size, sets the review depth (Risk tiers).
- Large features ship as independently mergeable slices off `main`, not stacked on each other. A slice that is not user-ready merges behind a feature flag.
- Worktrees live inside the repo at `.claude/worktrees/<slug>`, where Claude Code creates them, never as siblings like `../<repo>-<slug>`. Before creating one, check `git check-ignore -q .claude/worktrees/x`; if the path is not ignored, add `.claude/worktrees/` to the global excludes file git actually reads (`git config --global core.excludesFile`, else `${XDG_CONFIG_HOME:-~/.config}/git/ignore`) and check again, so `git status` stays clean and `git add .claude` never stages a worktree.
- After a merge, delete the branch (local and remote) and remove the worktree. Never reuse a merged branch.
- A PR description has a summary and a test plan, plus a spec link and a security checklist when they apply.
- The reasoning, recipes and FAQ are in `docs/TRUNK_BASED_WORKFLOW.md` in the ai-workflow repo.

## Code Quality
- Keep code as simple as it can be: no unnecessary abstractions, no speculative features, no premature generalization.
- Validate at system boundaries (user input, external APIs); trust internal code.
- Tests cover the spec's verification criteria and must be able to fail: before asking for a review, remove or break the behaviour each new test covers and see the test fail. Test data varies whatever the code depends on (sizes, lengths, order, scale); uniform fixtures hide bugs.
- Prefer changing an existing file to adding a new one, and ask before introducing a parallel doc or config.

## UI Work
- When the project has a design source (a Paper file, `docs/design/`), load it before implementing UI and build from it. If there is none, say so rather than inventing one.

## Toolkit
- The workflow skills come from the `wf` plugin; the usual path is `/wf:spec` → `/wf:feature` → `/wf:commit` → `/wf:pr`.
- **Implementing a spec goes through the `wf` workflow by default:** `/wf:feature` for one task, written on this session's model (do not spawn a writer for it); for a phase or roadmap, `/wf:autopilot`, which only I can start, so tell me to type it. Do not invent a different loop.
- **Orchestrating by hand**, when I ask for several tasks and do not type `/wf:autopilot` after you point me to it, or the work does not fit it. In Claude Code the orchestrator (this session) runs on Opus, and dispatches:
  - **Writer:** a `general-purpose` agent in an isolated worktree, one task each, dispatched with `effort: "medium"` (so it does not inherit the session's effort) and `model: "sonnet"` for a T0 or T1 task, `model: "opus"` for T2. A Sonnet writer whose PR needs a second fix round is not resumed, since a resumed agent keeps its model: a fresh Opus writer takes that round on the same branch with the open findings.
  - **Reviewer:** `wf:reviewer`, fresh context, one per PR (Review). **Security gate:** a fresh agent on Opus running `/security-review` when the change touches a security trigger; its `HIGH` and `MED` findings block the merge.
  - **Fix loop:** resume the writer with only the `HIGH` and `MED` findings from the reviewer and the security gate, then re-run both on the new commits. The reviewer's prompt carries `Previous findings: <list>` and `Reviewed at: <sha>`, the `REVIEWED_AT` sha its latest verdict returned. Two rounds per PR in total (Review).
  - **Merge** only as Review and Risk tiers allow; otherwise stop with the PRs open.
  - In other hosts (Codex): the strongest available model for the orchestrator, the reviewer (`wf-reviewer`) and the security gate; for writers, the faster model for T0 and T1 and the strongest configured model for T2.
- To review someone else's branch or PR, use the built-in `/code-review`; for a security pass, the built-in `/security-review` (in Codex, a fresh-context security review prompt).
