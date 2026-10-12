# Global Defaults

## Verification
- Run the project's lint, typecheck and tests before saying a change is done, and fix what fails. Report each check in one line (command, result); paste output only for a failure.
- If the project has no such checks, say so and say what you verified instead. Never report a check you did not run.
- Check the result against the spec or design it implements, not only against the checks.

## Workflow
- Spec first, code second: read the spec before implementing. A bug fix, or a chore that adds no behaviour, does not need a spec written for it.
- Commits are conventional (`feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`, `perf:`, `build:`, `ci:`, `security:`), split by logical concern, and each leaves the codebase working.
- Security-sensitive changes — auth, crypto, input parsing, secrets, permissions, anything that runs automatically — get the built-in `/security-review` before the PR is marked ready. Its `HIGH` and `MED` findings block the PR and are fixed like the reviewer's (Review, below); `LOW` findings are fixed or listed.

## Review
- **Every PR that changes behaviour is reviewed by a fresh context before it is ready** — the `wf:reviewer` agent, which `/wf:pr` dispatches, or a fresh session. The context that wrote the code never reviews it. Do this unprompted; a small or test-only diff is not a reason to skip it.
- **One reviewer per PR, not per commit.** Fix `HIGH` and `MED` findings and re-review once per round, at most two rounds. `LOW` findings are fixed or listed, and never trigger another round. A PR that has not converged after two rounds stays a draft and comes to me with the findings.
- **What may skip the reviewer:** only a diff that is entirely typo, spelling or formatting fixes in prose, or a changelog entry or project-version bump. Text that instructs an agent — a skill, an agent definition, a `CLAUDE.md`, a prompt — is behaviour and never qualifies; neither does a revert, a file move, or a dependency bump. When unsure, review. State a skipped review in the PR body (`Review: skipped — <reason>`).
- A PR that changes after a `PASS` is re-reviewed only if the new commits change behaviour.
- **Merging is my call, not the review's.** After the review, report the findings and stop. Merge on your own only when I said so for that piece of work ("merge it", "merge if it passes", "autonomous", or `/wf:autopilot` without `--supervised`). That authorization covers only the task I gave it for and never carries to the next one.

## Git
- Before a commit or PR, confirm you are in the intended repository and on the intended branch.
- Sync before starting: `git fetch` at the start of a session and before each new task, and check the branch against its upstream — I work from parallel sessions and machines. If histories have diverged, reconcile before building; published history wins, and never force-push over commits you have not seen.

## Trunk-Based Workflow
- `main` is trunk and always deployable. No long-lived `develop` or `release/*` branches.
- Branches are short-lived (hours to about two days) and named by type: `feat/<slug>`, `fix/<slug>`, `refactor/<slug>`, `docs/<slug>`, `chore/<slug>`, `test/<slug>`, `perf/<slug>`, `build/<slug>`, `ci/<slug>`, `security/<slug>`.
- **One branch = one PR = one concern.** A PR should be something a reviewer can hold in one pass: one vertical slice, independently mergeable, with its docs.
- **Size is a signal, not a quota.** Past roughly **500 added source lines**, stop and ask whether it is really one concern; split it if it is two. Tests, generated files, lockfiles, pure moves or renames, and deletions do not count, so never trim tests to fit. Do not split one concern into several PRs just to stay under the number — small PRs that only make sense together cost more review than one coherent PR.
- Large features ship as independently mergeable slices off `main`, not stacked on each other. A slice that is not user-ready merges behind a feature flag.
- Worktrees live outside the repo (`../<repo>-<slug>`), so `git status` stays clean.
- After a merge, delete the branch (local and remote) and remove the worktree. Never reuse a merged branch.
- A PR description has a summary, a test plan, and — when they apply — a link to the spec and a security checklist.
- The reasoning, recipes and FAQ are in `docs/TRUNK_BASED_WORKFLOW.md` in the ai-workflow repo.

## Code Quality
- Keep code as simple as it can be: no unnecessary abstractions, no speculative features, no premature generalization.
- Validate at system boundaries (user input, external APIs); trust internal code.
- Tests cover the verification criteria in the spec.
- Prefer changing an existing file to adding a new one, and ask before introducing a parallel doc or config.

## UI Work
- When the project has a design source (a Paper file, `docs/design/`), load it before implementing UI and build from it. If there is none, say so rather than inventing one.

## Toolkit
- The workflow skills come from the `wf` plugin (`/wf:spec`, `/wf:feature`, `/wf:fix`, `/wf:commit`, `/wf:pr`, …); the usual path is spec → feature → commit → PR.
- To review someone else's branch or PR, use the built-in `/code-review`; for a security pass, the built-in `/security-review`.
