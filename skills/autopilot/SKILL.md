---
name: autopilot
description: "Deliver a roadmap, one phase, or one GitHub milestone end-to-end: develop each task in a worktree, review it in a fresh context, fix findings, and merge to the trunk branch. Autonomous by default, except T2 (high-risk) PRs, which are parked for a human merge; --supervised stops with every PR open for a human to merge."
argument-hint: "[roadmap or phase file] | --phase <NNN> | --milestone <N> [--supervised] [--dry-run]"
disable-model-invocation: true
---
Run the delivery pipeline for: $ARGUMENTS

In hosts that do not substitute `$ARGUMENTS` (e.g. Codex), it is the text the user wrote after the skill name.

## What autopilot is

You are the **orchestrator** of **develop → review → fix → merge** for every task in scope. You dispatch writer agents in worktrees and the `wf:reviewer` agent on each PR, triage verdicts, merge, update status, and loop. You do not implement, review, or read diffs yourself; you keep only compact results (`branch`, `PR`, `verdict`). Typing `/wf:autopilot` grants merge authority for this run only, and not for T2 PRs: those are parked for a human merge (**Risk tiers** in your global agent instructions (`~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md`) defines the tiers).

Model roles: the orchestrator (this session), the reviewer and the security gate run on Opus, the writers you dispatch on Sonnet. A dispatch that drops the writer's `model: "sonnet"` or the gate's `model: "opus"`, or overrides the reviewer's model, breaks that split.

## Scope

- **`/wf:autopilot docs/roadmap/README.md`** (or no path, if that file exists) — every phase in the roadmap, in order.
- **`/wf:autopilot docs/roadmap/NNN_<phase>.md`** or **`--phase NNN`** — one phase.
- **`--milestone <N>`** — one GitHub milestone.
  - Read its title with `gh api "repos/{owner}/{repo}/milestones/<N>"` and match it to the phase file (`/wf:issues` titles milestones `Phase NNN — <phase-name>`).
  - The task list is its **open** issues: `gh issue list --milestone "<title>" --state open --limit 200 --json number,title,body,url`. Closed issues are done.
  - The phase file stays the source of truth for spec paths, files and dependencies. Match each issue to its task or slice by the `#N` in the `**Issue:**` line of a single-file spec's Trunk Metadata, or in the `Issue` column of a sliced spec's Slices table (the phase file's `Issues:` field indexes both), falling back to the spec link in the issue body.

## Modes

- **autonomous (default)** — merge each T0 and T1 PR to the trunk branch once its review passes, phase after phase, with no human gate. A T2 PR is parked as `awaiting-human-merge` (step 5e) and does **not** stop the run: it keeps running every task that does not depend on a parked PR, later phases whose dependencies are met included. It stops, lists the parked PRs and waits for `continue` only when nothing left can proceed without one of them being merged; otherwise it stops only on a stop condition (below).
- **`--supervised`** — do everything except merge. Each PR carries its review verdict as a PR **comment** (never `gh pr review --approve` or `--request-changes` — approval is the human's). Stop whenever every remaining task in the phase is waiting on an unmerged PR, or every task in the phase has a PR, and wait for `continue` / `retry <task>` / `skip <task>` / `stop`.
- **`--dry-run`** — do steps 1–4, print the wave plan, dispatch nothing.

Never switch modes silently. If the trunk branch turns out to be protected against your merge, say so and continue as `--supervised`.

### On `continue`

On `continue`, in both modes, after a stop for unmerged PRs:
1. `git pull --ff-only origin <base>`, then read the state of every parked or open PR with `gh pr view <n> --json state`.
2. Remove the writer worktree of each PR that is now `MERGED`.
3. Dispatch the tasks whose dependencies are all `MERGED`.
4. Run step 5f for each phase whose PRs are all `MERGED` (or whose tasks were skipped). The status commit follows the mode: autonomous pushes it directly, unless `<base>` only accepts PRs; `--supervised` goes through its own small PR cut from the current `<base>`, which you also leave for the human and list in the final summary if it is still open when the run ends. `--supervised` advances to the next phase only when every PR of the phase is `MERGED`.
5. While any PR is still `OPEN`, or was `CLOSED` without merging, and nothing else can proceed, list those PRs and stop again; a closed one needs `retry <task>` or `skip <task>`.

## Process

### 1. Parse the scope

For each phase extract: name, goal, feature flag (if any), and its tasks — each with name, spec path, files touched, dependencies, verification command and test layers. A task with `Complexity: high` normally points at a sliced spec directory (a single-file `high` spec is one concern its author chose to keep together, and is one task); every slice is its own task and its own PR.

If a task's spec is missing, or the roadmap lacks the detail to plan (no file list, unclear dependencies), **stop and say what is missing**. Do not invent specs — that is `/wf:spec`'s job, and it needs the user.

### 2. Read project context (once)

This is the only heavy reading you do:

- The project's agent instructions (`CLAUDE.md` or `AGENTS.md`) — build/test commands, conventions, merge rules.
- `docs/PRD.md` — what the project is.
- `docs/ARCHITECTURE.md` — system structure and the **Testing Strategy** (in older projects the testing strategy lives in `docs/TECHNICAL_DESIGN_DOCUMENT.md`).
- `docs/THREAT_MODEL.md` — trust boundaries, if it exists.

Reduce it to 3–5 lines including the test strategy and the exact lint / typecheck / test commands, preceded by the dependency setup command (e.g. `npm ci`): writers and reviewers start in a bare worktree with nothing installed. Every agent gets this summary instead of re-reading the docs.

### 3. Preflight (once)

Verify, and fix or surface, before the first dispatch:

- **Trunk branch.** Resolve `<base>` once: `gh repo view --json defaultBranchRef -q .defaultBranchRef.name` (fallback `git symbolic-ref --short refs/remotes/origin/HEAD`, strip `origin/`), then `git fetch origin <base>`. Use it wherever this file names the trunk branch.
- **Specs are committed and on `<base>`.** Worktree agents branch from committed history; an untracked spec is invisible to them.
- **Toolchain present** — the build/test/lint tools resolve in a fresh login shell.
- **`gh auth status` passes** and the remote is reachable.
- **Merge authority** (autonomous mode) — `gh repo view --json viewerPermission,rebaseMergeAllowed,mergeCommitAllowed,squashMergeAllowed` must show `viewerPermission` of WRITE or higher, and `<base>` must not require approvals you cannot supply. Otherwise, or if unsure, fall back to `--supervised` and say so. Record which merge methods are allowed (step 5e).
- **Working tree is clean** of unrelated work.
- **UI tasks have a design reference** — for a task that builds a page or component, check its `Design reference` and `docs/design/`. If there is one, note "run `/wf:verify-design` on this page before merge" on that task. If there is none, warn that the design source is missing; don't block.

### 4. Plan waves

Within a phase, group tasks into **waves**:

- A wave is a set of tasks with no dependency between them and **no file in common**. Two writers must never touch the same file; sequence them instead. A task whose spec lists no files runs alone.
- **At most 5 writers per wave.** Split a larger wave.
- A task that depends on another waits until that dependency is **merged to `<base>`**, not merely written — its worktree must branch from a `<base>` that contains it. In `--supervised` mode, and for a parked T2 PR, you do not merge, so a dependent task is reported as "waiting on merge of #N" and picked up on `continue` once the human has merged.

Announce the plan:

```
## Phase N: <name>
Goal: <goal>   Flag: <feature flag or none>
Wave 1: <task>, <task>     Wave 2: <task>
```

Skip phases whose Status in the roadmap index is `Completed`. Within a phase, look each task up by its branch before planning it: `gh pr list --state all --head <branch> --json number,state`. The branch name is derived from the task, never invented per run — the one `/wf:feature` defines under "Branch": `<type>/<issue-number>-<slug>`, or `<type>/<slug>` when there is no issue, where the slug is the spec file's name without its prefix and `.md`, and for a slice the parent's slug joined to the slice's (`jira-sync-webhook`) — so a later run, or a PR someone opened with `/wf:feature`, is found under the same name.

- `MERGED` → done; leave it out of the plan. A phase that is not `Completed` and whose tasks are all `MERGED` (or skipped) goes straight to step 5f, so a re-run after a human merged the parked T2 PRs records the phase.
- `OPEN` → an earlier run got this far. Do not dispatch a second writer; pick the PR up at step 5b. If its last comment is already a `PASS` verdict, go straight to 5e (autonomous) or report it as waiting on the human (`--supervised`, or a T2 PR). If it needs fixes there is no writer to resume, so dispatch a fresh one on the existing branch with the findings; the same goes for a rebase in step 5e.
- no PR → dispatch. Only `CLOSED` ones → dispatch in autonomous mode; in `--supervised` mode the human closed it, so ask for `retry <task>` or `skip <task>`.

### 5. Run the pipeline per task

Tasks in one wave run concurrently — dispatch all their writers in a single message, in the background.

**a. Develop.** Dispatch a writer: `Agent(subagent_type: "general-purpose", model: "sonnet", isolation: "worktree", prompt: <writer template below>)` — writers follow a detailed spec, they don't design. Record its branch and PR URL. If a writer fails outright, do not retry on your own — record it and report it.

**b. Review.** When the PR is open, dispatch the `wf:reviewer` agent on it with `isolation: "worktree"` (so it can run the checks), no `model` override (its definition sets Opus), and a prompt with one field per line: `Base: <base>`, `Branch: <branch>`, `Spec: <path>`, `Risk: <the task's declared tier>`, `Verify: <commands>`. A verdict whose findings say the diff was empty is a dispatch error, not a pass — fix the prompt and re-dispatch once; if the second verdict is the same, mark the task `NEEDS_HUMAN`. Remove the reviewer's worktree once you have its verdict. Never review in your own context and never let the writer review itself. The verdict comes back as `VERDICT` / `REVIEWED_AT` / `RISK` / `CHECKS` / `FINDINGS` / `SUMMARY`. The PR's tier is the highest of the task's declared `Risk`, the writer's `## Risk` section and the reviewer's `RISK`. The reviewer reports its tier only in the `RISK` line, never as a finding: if it is higher than the PR body's, you update the body's `## Risk` section yourself (`gh pr edit`). That correction is not a fix cycle and needs no re-review. Post it on the PR as a comment, sha included: a re-review, also on a resumed run, takes its `Reviewed at` from the latest such comment. `PASS` with LOW findings still merges. Keep the LOW findings of every round, not only the passing one (they are not fixed and a re-review does not repeat them): put the whole list in the final comment and in the phase table's Notes column, and name any `outside the fix (MED)` item in the final summary.

**c. Security gate, when warranted.** If the task touches a security trigger (**Security triggers** in your global agent instructions (`~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md`); the security subset of T2), dispatch one more fresh agent with `isolation: "worktree"` and `model: "opus"` (stated, so a run typed in a Sonnet session does not put the gate on Sonnet) to run `/security-review`, and take back its HIGH and MED findings; LOW findings go in the PR comment and the Notes column, as in 5b. The branch is checked out in the writer's worktree, so tell it to `git fetch origin <branch> && git checkout --detach origin/<branch>` rather than check the branch out. A HIGH or MED finding blocks the merge: send it to the writer as in 5d, then re-dispatch the reviewer as 5d's narrow re-review, with the security findings in `Previous findings`, and redo 5c on the new commits. Reviewer and security fixes share one budget of 2 fix cycles per PR, not 2 each; with none left, mark the task `NEEDS_HUMAN`. Skip it for plainly non-security work.

**d. Fix loop, bounded.** On `FIX_REQUIRED`, resume the **writer** with `SendMessage` and only the HIGH/MED items (the reviewer's and the security gate's) — it already holds the spec and files; a fresh fixer would pay to load them again. Never send LOW items: a LOW fix is new code the re-review is not asked to read, so LOW findings are listed, not fixed. The writer fixes, each fix with a test that fails without it where the project's suite can test it (otherwise say how it was verified), re-runs the whole suite and pushes; re-dispatch the reviewer with `Previous findings: <list>` and `Reviewed at: <the REVIEWED_AT sha of the latest verdict>`, which makes it a narrow re-review (it reads the fix commits; what they broke blocks as usual, and a defect that was already there blocks only when HIGH), and run 5c again on the new commits if the gate applies. **Maximum 2 fix cycles per PR, counting both.** A finding that survives both usually means the spec is ambiguous: mark the task `NEEDS_HUMAN` (an autopilot status, not a reviewer verdict), leave the PR open with the reviewer's comment, and carry on with independent tasks.

**e. Merge** (autonomous mode only). On `PASS` with the security gate clear, and the PR's tier T0 or T1:

- Wait for remote CI: `gh pr checks <n> --watch --fail-fast`. A failing check goes to the fix loop like a reviewer finding; a PR with no checks is fine only if the repo has none (no `.github/workflows/`, no required checks) — right after a push they may simply not have registered yet, so retry once after a short wait before concluding that. Commits pushed after a `PASS` that change behaviour need a fresh review first.
- `gh pr merge <n> --rebase --delete-branch`. Do not `--squash`, which destroys the writer's logical commit split, unless the project's agent instructions (`CLAUDE.md` or `AGENTS.md`) mandates it. If preflight showed rebase merges disabled, use `--merge` and say so.
- If the branch no longer applies because `<base>` moved under a parallel wave, have the writer rebase and re-verify, then merge. A conflict that is not mechanical is a stop condition.
- Remove the writer's worktree. Never reuse a merged branch.
- `git pull --ff-only origin <base>`, so the next wave and your own status commits start from what was just merged.

A **T2** PR that passed the review and the gate is not merged. Park it: status `awaiting-human-merge`, the PR left ready (not a draft), with a PR comment saying it is T2, why, and that the review and the gate passed. Its dependents wait (step 4); independent tasks continue. Autonomy covers T2 only if the user said so explicitly for T2 work in this run's request. When every other task is done and only independent parked T2 PRs remain, the run ends: list them in the final summary as awaiting a human merge. No `continue` is needed; the human merges and, if they want the status commit, re-runs the command, which finds the merged PRs at step 4.

**f. Record** (after a merge only — in `--supervised` mode, or for a parked T2 PR, an open PR is not done). The PR's `Closes #N` closes the issue. When every task in a phase is merged — by you, or by a human: in `--supervised` mode, or for a parked T2 PR — tick the phase file's Phase Checklist, set the phase's Status to `Completed` in `docs/roadmap/README.md`, and land that as one `docs:` commit on an up-to-date `<base>`: pushed directly in autonomous mode (a status-only docs commit changes no behaviour, so it skips the PR and the review), or through a small PR when `<base>` only accepts PRs or the run is `--supervised`. A task's merged PR (step 4) and a phase's `Completed` status are what make an interrupted run resumable.

### 6. Feature flags

A phase that ships behind a flag lands every task with the flag **off**. Flip it on once, at phase end, as its own small PR through the same pipeline.

### 7. Phase and final summary

When a phase finishes — or, as `## Phase N status`, when `--supervised` stops part-way through one:

```
## Phase N complete
| Task | Status | PR | Tier | Review | Notes |
|------|--------|----|------|--------|-------|
| <name> | merged / open / awaiting-human-merge / needs-human / failed | #<n> | T0 / T1 / T2 | PASS / FIX_REQUIRED | <note> |
```

Autonomous mode proceeds to the next phase and keeps running tasks that do not depend on a parked PR (see Modes); it waits for `continue` only when nothing else can proceed. `--supervised` stops here and advances on `continue`, as described under Modes. At the end of the run, print one table of what was delivered, what is parked for a human (`needs-human`, `awaiting-human-merge`) and why, and what remains.

## Usage limits: resume after reset

A usage limit stops the orchestrator and its background agents mid-run; nothing restarts them unless you scheduled it.

- **Schedule a resume check** at the start of the run, and again whenever the session reports usage high (≈70%+) or a limit message gives the reset time: `CronCreate` with `recurring: false`, 1 minute after the reset time (when the time is approximate, avoid the :00 and :30 marks).
  - The prompt is self-contained: the task and scope, the mode, the state of every task (branch, PR, verdict, fix cycles used), the paths of the briefs and the project summary, and the next steps.
  - It runs `ReadNotifications`, checks every background agent, resumes each one the limit stopped with `SendMessage` to that same agent ("continue where you left off"), then continues the loop: review → fix → merge only as already authorized.
- **One resume job per reset.** Before scheduling, `CronList` and `CronDelete` the stale ones, or replace them.
- **Keep progress durable before it can be cut off.** Writers commit and push WIP on their feature branches; you write the run state (the per-task table above) to memory or the job dir, so the resumed run picks up from it rather than from context.
- **Cron jobs live only in this session.** If the session may exit, tell the user that the resume dies with it. Where available, a `RemoteTrigger` routine is the durable fallback; offer it, don't require it.
- **The resumed run inherits no new authority.** It merges only what this run was authorized to merge, never work outside the original scope.

## Writer prompt template

```
## Project context
<your 3–5 line summary, including the test strategy>

## Commands
<exact lint / typecheck / test / build commands>

## Your task
Phase: <phase>   Task: <task>   Issue: <#N or none>
Spec: <path> — read it first, in full, plus: <architecture / threat-model / referenced specs>
Files to create or modify: <list> — do not touch anything else unless strictly necessary
Test layers: <from the roadmap task>
Base: origin/<base> (run `git fetch origin` first)   Branch: <the branch name from step 4> — create it, or check it out if it already exists on origin

## Instructions
1. Confirm you are in your worktree and on the branch above before changing anything.
2. Implement exactly what the spec says. Record any judgement call in the PR body.
3. Write tests at the layers above, covering every verification criterion in the spec. Vary the test data in whatever the code depends on (sizes, lengths, order, scale); uniform fixtures hide bugs. Before the PR, remove or break the behaviour each new test covers and see the test fail; a test that still passes is rewritten.
4. Run lint, typecheck and tests; fix until all pass. No PR while any of them fails, and never `--no-verify`.
5. Commit with conventional messages, split by logical concern. Push. Open a PR against <base> (PR title: imperative, no type prefix, under 70 characters) with: summary, spec link, `Closes #<N>` if there is an issue, a `## Risk` section (`T1 — <why>`, the tier from **Risk tiers** in your global agent instructions (`~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md`), T2 if the diff touches any of its triggers), a security checklist when the change touches a security trigger (**Security triggers** in your global agent instructions (`~/.claude/CLAUDE.md` or `~/.codex/AGENTS.md`)), and a test plan listing each verification criterion.
6. Do not merge, force-push, or touch <base>.
7. Report: branch, PR URL, the tail of each check, and any blocker.

You may be resumed with review findings to fix — keep your context. Then change only what the findings require, including the callers, docs and tests the fix needs, each fix with a test that fails without it where the project's suite can test it (otherwise say how it was verified), and re-run the whole suite before pushing; no other clean-up in that round.
```

## Stop conditions

Halt and surface, in either mode (the first item parks one task rather than halting the run):

- A check failure, a reviewer finding, or a HIGH or MED security finding left after the 2 fix cycles: park the task as `NEEDS_HUMAN` with its PR open and carry on with the tasks that do not depend on it (5d); halt the run when nothing else can proceed.
- A merge conflict that is not mechanically resolvable.
- A spec that is missing, contradictory, or contradicts the architecture.
- Anything destructive or irreversible outside the roadmap's scope — a lossy data migration, deleting user data, force-pushing shared history, publishing a release. These need explicit sign-off regardless of mode. (A parked T2 PR is not a stop condition: see Modes.)
