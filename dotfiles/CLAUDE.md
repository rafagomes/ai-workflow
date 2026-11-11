# Global Defaults

## Language
- **Everything you create is in English**: docs, code, comments, identifiers, commit messages, PR titles and bodies, issues, config, and any other written artifact. This holds whatever language I am speaking, until I explicitly say otherwise for that piece of work.
- Chat replies follow the language of my message: reply in the language I wrote in, and in English when it is unclear.

## Verification
- Run the project's lint, typecheck and tests before saying a change is done, and fix what fails. Report each check in one line (command, result); paste output only for a failure.
- If the project has no such checks, say so and say what you verified instead. Never report a check you did not run.
- Check the result against the spec or design it implements, not only against the checks.

## Workflow
- Spec first, code second: read the spec before implementing. A bug fix, or a chore that adds no behaviour, does not need a spec written for it.
- Commits are conventional (`feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`, `perf:`, `build:`, `ci:`, `security:`), split by logical concern, and each leaves the codebase working.
- **Security triggers:** a trust boundary, auth, crypto, input parsing, secrets, permissions, dependencies, anything that runs automatically. A change touching any of these is security-sensitive and gets the built-in `/security-review` before the PR is marked ready. Its `HIGH` and `MED` findings block the PR and are fixed within the same two rounds as the reviewer's (Review, below), not two more; `LOW` findings are listed.

## Review
- **Every PR that changes behaviour is reviewed by a fresh context before it is ready** — the `wf:reviewer` agent (on Opus), which `/wf:pr` dispatches, or a fresh session. The context that wrote the code never reviews it. Do this unprompted; a small or test-only diff is not a reason to skip it.
- **One reviewer per PR, not per commit.** Fix `HIGH` and `MED` findings and re-review once per round, at most two rounds. A PR that has not converged after two rounds stays a draft and comes to me with the findings.
- **A fix round changes only what the `HIGH` and `MED` findings require.** `LOW` findings are listed in the PR and never fixed in a fix round: a `LOW` fix is new code the next review was not asked to look at, and never triggers another round. Each fix comes with a test that fails without it where the project's suite can test it (otherwise say how it was verified), and the whole suite runs again before the push. The `LOW` findings of every round, not only the last, are in the PR's final review comment.
- **The first review is the full one; a re-review is narrow.** It confirms each previous finding is resolved and reads the commits made since for what the fix broke. Anything those commits introduced or broke keeps its severity and blocks, wherever it shows, a caller they did not touch included. Only a defect that was already there and the first review missed is treated differently: it blocks when it is `HIGH`, and anything less is listed in the PR for me with its severity. When I allow a PR past two rounds, every further check is a re-review of this kind, never a second full review.
- **What may skip the reviewer:** only a diff that is entirely typo, spelling or formatting fixes in prose, or a changelog entry or project-version bump. Text that instructs an agent — a skill, an agent definition, a `CLAUDE.md`, a prompt — is behaviour and never qualifies; neither does a revert, a file move, or a dependency bump. When unsure, review. State a skipped review in the PR body (`Review: skipped — <reason>`).
- A PR that changes after a `PASS` is re-reviewed only if the new commits change behaviour.
- **Merging is my call, not the review's.** After the review, report the findings and stop. Merge on your own only when I said so for that piece of work ("merge it", "merge if it passes", "autonomous", or `/wf:autopilot` without `--supervised`), and never a T2 PR unless I said so for T2 work (Risk tiers). That authorization covers only the task I gave it for and never carries to the next one.

## Risk tiers
Review depth scales with blast radius and reversibility, not with size. Every change has a tier; this section is the one definition, and everything else points here. The highest matching tier wins; when unsure, take the higher one.
- **T0** — the diff is entirely what may skip the reviewer (see Review). Text that instructs an agent is never T0. Review skipped.
- **T1** — an ordinary change. One `wf:reviewer` pass.
- **T2** — touches any security trigger (the list in Workflow; the security gate is the security subset of T2), or a data migration or schema change, CI/CD, deploy or infra config, a public API or contract other code depends on, a shared core module with many callers, or anything hard to reverse. The reviewer, plus the `/security-review` gate when a security trigger applies, plus **a human merge**: a blanket merge authorization ("autonomous", "merge if it passes", `/wf:autopilot` without `--supervised`) does not cover a T2 PR unless I said so explicitly for T2 work in that task.
- The tier is declared in the spec or task, derived from the diff by whoever writes the code, and assessed again by the reviewer. The diff wins over the declaration when it is higher. A higher assessed tier is a correction the dispatcher makes to the PR body, not a review finding, a fix round or a reason to re-review.

## Git
- Before a commit or PR, confirm you are in the intended repository and on the intended branch.
- Sync before starting: `git fetch` at the start of a session and before each new task, and check the branch against its upstream — I work from parallel sessions and machines. If histories have diverged, reconcile before building; published history wins, and never force-push over commits you have not seen.

## Trunk-Based Workflow
- `main` is trunk and always deployable. No long-lived `develop` or `release/*` branches.
- Branches are short-lived (hours to about two days) and named by type: `feat/<slug>`, `fix/<slug>`, `refactor/<slug>`, `docs/<slug>`, `chore/<slug>`, `test/<slug>`, `perf/<slug>`, `build/<slug>`, `ci/<slug>`, `security/<slug>`.
- **One branch = one PR = one concern.** A PR should be something a reviewer can hold in one pass: one vertical slice, independently mergeable, with its docs.
- **Size is a signal, not a quota.** One concern is the rule. Past roughly **1,000 added source lines or ~40 changed source files**, stop and check it is still one concern; split it if it is two. Tests, generated files, lockfiles, pure moves or renames, and deletions do not count, so never trim tests to fit. Never split one concern to get under the number — small PRs that only make sense together cost more review than one coherent PR. Risk, not size, decides how deep the review goes (Risk tiers).
- Large features ship as independently mergeable slices off `main`, not stacked on each other. A slice that is not user-ready merges behind a feature flag.
- Worktrees live inside the repo at `.claude/worktrees/<slug>`, where Claude Code creates them (`isolation: "worktree"`, `claude --worktree`), never as siblings like `../<repo>-<slug>`. Before creating one, check `git check-ignore -q .claude/worktrees/x`; if the path is not ignored, add `.claude/worktrees/` to the global excludes file git actually reads (`git config --global core.excludesFile`, else `${XDG_CONFIG_HOME:-~/.config}/git/ignore`) and run the check again to confirm, so `git status` stays clean and `git add .claude` never stages a worktree.
- After a merge, delete the branch (local and remote) and remove the worktree. Never reuse a merged branch.
- A PR description has a summary, a test plan, and — when they apply — a link to the spec and a security checklist.
- The reasoning, recipes and FAQ are in `docs/TRUNK_BASED_WORKFLOW.md` in the ai-workflow repo.

## Code Quality
- Keep code as simple as it can be: no unnecessary abstractions, no speculative features, no premature generalization.
- Validate at system boundaries (user input, external APIs); trust internal code.
- Tests cover the verification criteria in the spec.
- A test must be able to fail: before asking for a review, remove or break the behaviour each new test covers and see the test fail. Test data varies whatever the code depends on (sizes, lengths, order, scale); uniform fixtures hide bugs.
- Prefer changing an existing file to adding a new one, and ask before introducing a parallel doc or config.

## UI Work
- When the project has a design source (a Paper file, `docs/design/`), load it before implementing UI and build from it. If there is none, say so rather than inventing one.

## Toolkit
- The workflow skills come from the `wf` plugin (`/wf:spec`, `/wf:feature`, `/wf:fix`, `/wf:commit`, `/wf:pr`, …); the usual path is spec → feature → commit → PR.
- **Implementing a spec goes through the `wf` workflow by default:** `/wf:feature` for one task; for a phase or roadmap, `/wf:autopilot`, which only I can start — you cannot invoke it, so tell me to type it. Do not invent a different loop.
- **Model roles when a session dispatches writers:** orchestrator and reviewer on Opus, dispatched writers on Sonnet. `/wf:feature` run directly in a session writes on that session's model; do not spawn a writer for it.
- If I ask you to deliver several tasks and do not type `/wf:autopilot` after you have pointed me to it, or the work does not fit `/wf:autopilot`, orchestrate by hand under the same dispatch rules. That never grants merge authority: stop with the PRs open unless I said to merge; a T2 PR (Risk tiers) stays open for me even then, unless I said to merge T2 work.
  - **Writer:** a `general-purpose` agent with `model: "sonnet"`, in an isolated worktree, one task per writer.
  - **Reviewer:** `wf:reviewer` (Opus), fresh context, one per PR (see Review).
  - **Security gate:** a fresh agent on Opus running `/security-review`, when the change touches a security trigger (Workflow). `HIGH` and `MED` findings block the merge.
  - **Fix loop:** resume the same writer with only the `HIGH` and `MED` findings from the reviewer and the security gate, then re-run both on the new commits, the reviewer as a narrow re-review (see Review): its prompt carries `Previous findings: <list>` and `Reviewed at: <sha>`, the `REVIEWED_AT` sha its latest verdict returned; at most two rounds per PR in total. Not converged: the PR stays a draft and comes to me.
  - **Merge:** only when I authorised it (see Review); a T2 PR only when I said so for T2 work (see Risk tiers).
- To review someone else's branch or PR, use the built-in `/code-review`; for a security pass, the built-in `/security-review`.
