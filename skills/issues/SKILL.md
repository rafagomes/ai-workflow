---
name: issues
description: "File GitHub milestones and issues from a roadmap, a phase file or a spec — one milestone per phase, one issue per task or slice — then write the issue numbers back into the docs so /wf:feature and /wf:autopilot can name branches and close issues. Safe to re-run: reconciles issues already filed. Use when the user says 'create the GitHub issues', 'file the issues for this roadmap', 'open issues for this spec', 'make the milestones', or points at docs/roadmap or docs/specs and wants them on GitHub."
argument-hint: "<roadmap, phase or spec file>"
---
File GitHub milestones and issues for: $ARGUMENTS

## What this skill does

`/wf:issues` is the hand-off between planning artifacts (`docs/roadmap/*.md`, `docs/specs/*.md`) and GitHub. It files:

- **One milestone per phase:** `Phase NNN — <phase-name>`
- **One issue per task/slice:** title `[NNN.N] <task-name>` for a roadmap task, `[NNN.N.N] <slice-name>` for a slice of a roadmap task, `[<feature>.NNN] <slice-name>` for a standalone spec's slice, `<feature-name>` for a standalone single-file spec. `N` in `[NNN.N]` is the task's position in its phase (Task 2 gives `[003.2]`), not the letter suffix of the spec file.
- **Labels:** `type:<type>`, `complexity:<low|med|high>`, `mvp` or `post-mvp` (if derivable), `needs-spec` if the spec file does not exist yet, `risk:<t0|t1|t2>` when the source has a `Risk`.
- **Body:** spec link, file list, dependencies, parallelization (its wave and the issues it runs alongside), verification command, flag, acceptance criteria from the spec.

Before filing it plans **execution waves** per milestone, so the issues say what can run concurrently, and flags dependencies the source leaves out.

It then writes the issue numbers back into the source docs (see Writeback).

## Parse arguments

- **Roadmap index** (`docs/roadmap/README.md`): everything: a milestone per phase file, an issue per task, an issue per slice where a task points at a sliced spec.
- **Phase file** (`docs/roadmap/NNN_<phase>.md`): one milestone plus its tasks (and slices).
- **Sliced spec index** (`docs/specs/NNN_<feature>/README.md`): one issue per Slices row. Uses the feature's existing milestone if the spec references a phase, otherwise no milestone.
- **Single spec** (`docs/specs/NNN_<feature>.md`): one issue; a milestone only if the spec references a phase.

No argument: use `docs/roadmap/README.md`; if it is missing but `docs/roadmap/NNN_*.md` exist, offer those; otherwise ask.

## Transport: `gh` CLI

Every read and write goes through `gh`. Run `gh auth status` once at the start; if it fails, tell the user to run `gh auth login` (their call) and stop. Milestones have no `gh milestone` command, so use `gh api "repos/{owner}/{repo}/milestones"` (list with `?state=all&per_page=100 --paginate`, create with `-f title=... -f description=...`). Create issues with `gh issue create --title ... --body-file <tmp> --milestone "..." --label "..."`; the body goes through a file so Markdown and backticks survive.

## Asking the user

Use `AskUserQuestion` at each decision point: structured options are unambiguous where "ok"/"go" is not. First option is the recommendation; "Other" means the user is correcting you, so re-plan. Batch decisions needed back-to-back into one call. Where AskUserQuestion is unavailable (e.g. in Codex), ask the same question in chat as a short numbered list and wait for the answer.

- **Reconcile** (drifted or closed issues found): Update in place (recommended) / Close + refile / Skip.
- **Horizon** (roadmap index only): Current + next phase (recommended) / Full roadmap. Asked first, because everything after it is planned only for the phases in the horizon.
- **Hidden sequencing** (shared files with no declared dependency, see Preflight step 5): one question per pair, or one for all of them: Add the dependency (recommended) / Keep as-is. A "Keep as-is" is not recorded, so a re-run asks again, by design: the source still has the gap.
- **Proceed?** (dry-run confirmation): Yes / Cancel.
- **Next phase** (after each milestone batch, only when the user chose Full roadmap): Yes, continue / Stop here.

If the user cannot be asked (a headless run), do not file anything: print the dry-run plan and stop. Creating milestones and issues is outward-facing, so only the user's own answer approves it.

## Preflight

1. **`gh auth status`** (above). Stop if it fails.
2. **Confirm a GitHub remote:** `gh repo view --json nameWithOwner` must succeed (this also covers GitHub Enterprise). If not, stop.
3. **Read the source file(s) top to bottom.** Collect `Type`, `Complexity`, `Risk`, `Flag`, `Depends on`, `Spec` and the existing `Issue` / `Issues` values from the Tasks and Slices tables and Trunk Metadata. Read a Slices table by its column headers, not by position (the `Risk` column was added between `Complexity` and `Issue`). A source with no `Risk` (an older spec) gets no `risk:*` label. A slice's files (and a single-file spec's) are in its spec's `### Affected Files`; for a task with a single-file spec or no spec, fall back to the roadmap task's `Files`. A roadmap task that points at a sliced spec has a task-level `Files` that spans slices, so do not use it per slice.
4. **Fetch existing milestones** and match them against the phase titles so reruns are idempotent.
5. **Plan waves, per milestone,** from each task's or slice's `Depends on` and files (as collected in step 3), by the rule in `/wf:autopilot` step 4 (Plan waves); this skill does not adapt it. For a roadmap index, ask **Horizon** first and plan only the phases in it. A spec input with no milestone (one that references no phase, see Parse arguments) has none: compute the waves over its slices, and the body says `Wave <n> of <spec title>` (`Runs alone.` for a single spec) with no milestone block. Then check for **hidden sequencing**:
   - Two tasks or slices that share a file but declare no dependency cannot run in parallel, so the plan serialises them. List every such pair.
   - If the roadmap's `## Execution Order` marks as parallel tasks that rule says cannot be, list those too.
   - Ask **Hidden sequencing** (before Reconcile and Proceed, so the counts and the dry-run see the final plan): add a dependency in the source doc (recommended: the later task in roadmap order depends on the earlier one), or keep as-is and let the wave plan serialise them. An added dependency is recorded in the plan and the waves are recomputed, but the source is written only after **Proceed?** (see Execution). Headless: file nothing, just print the list.
6. **Detect already-filed issues.**
   - For each row with a `#<N>`, run `gh issue view`. Classify it `match` (aligned with the source), `drift` (title, labels, milestone or body need an update) or `gone` (closed or deleted). The body's Dependencies section matches when every task or slice in `Depends on` appears as its filed `#N` and every phase as `Needs all of <milestone title>`; an `Also needs:` sentence is never drift, and an update in place keeps it.
   - For rows with no `Issue` value, search open and closed issues by title prefix (`gh issue list --state all --search "[003.2] in:title"`). Adopt a match instead of creating a duplicate: a previous run may have died between creating the issue and the writeback.
   - The body also matches only when its `## Parallelization` section and the milestone's `Execution waves` block equal the final plan from step 5. A change to dependencies or files is drift, and the waves and peers are recomputed.
   - Print `X rows already filed: Y match / Z drift / W gone`, then ask the **Reconcile** question. If the user names specific rows under "Other", re-plan per row.
7. **Dry-run.** Print everything that will be created or changed (milestones, issues with title, labels and milestone, writebacks) and the waves per milestone (`Wave 1: <task>, <task>` / `Wave 2: <task>`), and ask **Proceed?**. A free-text "ok" does not count; wait for the structured answer. No source file is edited before it, dependency edits included.

## Milestone shape

- **Title:** `Phase NNN — <phase-name>`, copied from the task's `Milestone:` field when the roadmap has one, otherwise built from the phase file's `# Phase NNN: <name>` heading. Match an existing milestone by its `Phase NNN` prefix, not the full title, so a differently-cased name does not create a second one. A roadmap written before 1.1 may use `# Phase: <name>`, `Feature flag` and `Dependencies`: read those as `# Phase NNN: <name>` (number from the file name), `Flag` and `Depends on`.
- **Description:** the phase's `## Context` paragraph, truncated to ~500 chars, then an `Execution waves` block with real issue numbers (`Wave 1: #1, #2 · Wave 2: #3`), written once the milestone's batch is created and updated whenever the waves change.
- **Due date:** skip unless the phase file names one.

## Issue shape

**Labels:**

- `type:<type>` from the `Type` field (`feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `perf`, `build`, `ci`, `security`).
- `complexity:low` / `complexity:med` / `complexity:high` from `Complexity`.
- `mvp` or `post-mvp` from the roadmap index's MVP column; omit when not derivable.
- `needs-spec` if the task's spec file does not exist yet.
- `risk:t0` / `risk:t1` / `risk:t2` from the `Risk` field or column (the tier before the `—`); omit when absent.

There are no `wave:*` labels: waves are relative to a milestone and rot as work merges, so they live in the issue body and the milestone description instead.

Create missing labels on first run (`gh label list --limit 200 --json name`, then `gh label create "<name>" --color <hex>`). Colors: `type:feat` `1d76db`, `type:fix` `d73a4a`, `type:refactor` `a2eeef`, `type:chore` `cccccc`, `type:test` `0e8a16`, `type:docs` `0075ca`, `type:perf` `fbca04`, `type:build` `5319e7`, `type:ci` `bfd4f2`, `type:security` `b60205`; `complexity:low` `c2e0c6`, `complexity:med` `fef2c0`, `complexity:high` `f9d0c4`; `mvp` `0e8a16`, `post-mvp` `cfd3d7`, `needs-spec` `e99695`; `risk:t0` `bfdadc`, `risk:t1` `c5def5`, `risk:t2` `d93f0b`.

**Body template:**

```markdown
## Context
<one-paragraph summary from the task's Context or the spec's Problem>

## Spec
- File: [<path>](<path>)
- Trunk metadata: type=<type>, flag=<flag>, complexity=<complexity>

## Files
<bullet list of the files collected in Preflight step 3 for this issue>

## Dependencies
<`None.` or, one sentence each and in this order, whichever apply: `Blocked by #<N>[, #<N>...].` `Needs all of <milestone title>.` `Also needs: <text>.`>

## Parallelization
<`Wave <n> of <milestone title>.` and `Runs in parallel with #<A>, #<B>.` or `Runs alone.`>

## Verification
```
<verification command from the spec>
```

## Acceptance Criteria
<Verification Criteria bullets from the spec, each as a `- [ ]` item>

## Feature Flag
<flag name and default, or `None — slice is user-ready on merge`>

---
Filed by `/wf:issues` from `<source-file>`.
```

## Dependencies

File issues in dependency order. Roadmap order already puts dependencies first, and `/wf:spec` forbids a slice depending on an unmerged slice. Each body then names the real `#N` of an already-filed blocker. A dependency already filed earlier is looked up in the source docs' `Issue` / `Issues` values. If a dependency points forward (to something not yet filed), stop and fix the source ordering.

A `Depends on` value can mix three kinds, and the body's `## Dependencies` section gets one sentence per kind present, in this order:

- **Tasks or slices:** `Blocked by #<N>[, #<N>...].`
- **A whole phase** (`Depends on: Phase 002`), which has no single issue: `Needs all of <milestone title>.`, with the title built as in Milestone shape. One sentence per phase.
- **Something that is not a task** (an owner decision, a design artboard to draw first): `Also needs: <text>.`, copying the source's wording.

**Never write the source's `001`, `002`, ... as `#001` in a body.** GitHub auto-links `#N` to the issue with that number, so `#001` silently points at issue #1, not the slice you meant.

A task's wave peers may be filed after it, so when an issue is created its `Runs in parallel with` line is not yet complete. Once the milestone's batch exists, do a second pass: `gh issue edit <N> --body-file <tmp>` for each issue with peers, then update the milestone description's `Execution waves` block (`gh api -X PATCH "repos/{owner}/{repo}/milestones/<number>" -f description=...`).

## Pacing: two-phase horizon

For a roadmap index spanning many phases, default to filing only the current phase and the next. Issues are the short-range artifact and the roadmap is the long-range one; filing 50 issues up front just rots into stale labels and half-done milestones. Phase and single-spec inputs are already scoped and skip this.

1. **Current phase:** the first phase whose Status is not `Completed`, or whose tasks don't all have `Issue` values.
2. **Next phase:** the phase after it in the index.
3. Ask **Horizon** in Preflight step 5, before planning waves. If the user picks Full roadmap, drop the cap and warn about the label-rot cost.
4. The dry-run files only the phases in the horizon and lists the skipped ones ("Phases 004–009 stay in docs/roadmap/ for now; re-run `/wf:issues` when you're ready for the next wave").

Re-running later is idempotent on filed phases and picks up the next window.

## Execution: one milestone at a time

After **Proceed?**, first write any accepted dependency edits to the source. For roadmap and phase inputs, file one milestone and its issues at a time, in roadmap order, so a broken run is recoverable and writebacks stay atomic per phase. Write each `#N` back into the source right after its issue is created, so an interrupted run does not leave an issue the source does not know about. After each batch, print the milestone and issue URLs. When the user chose Full roadmap, ask **Next phase** and halt unless they continue; otherwise move on to the next phase in the horizon. Single-spec inputs: file, write back, done.

## Writeback

Update the source Markdown with `Edit` (exact-string replace), preserving surrounding formatting:

- **Roadmap task:** `- **Issues:** —` becomes `- **Issues:** #<N>` (or `#<N>, #<N+1>, ...` for a sliced task).
- **Roadmap task with a single-file spec:** also write `#<N>` to the spec's Trunk Metadata `**Issue:**` line, because `/wf:feature` and `/wf:autopilot` read it there.
- **Roadmap task with a sliced spec:** write each slice's `#<N>` to the Slices table `Issue` column and list them all in the roadmap's `Issues:`.
- **Standalone sliced spec:** `#<N>` in the Slices table `Issue` column.
- **Standalone single spec:** `- **Issue:** — (filled by `/wf:issues`)` becomes `- **Issue:** #<N>`.

A row updated in place (not newly filed) keeps its existing `Issue` value.

## Idempotency

- Re-running on a fully filed source is a no-op: the dry-run shows 0 creates, 0 updates.
- Rows hand-closed on GitHub are `gone`; offer refile or skip.
- Spec edits since filing show up as `drift` on the affected rows.
- Never delete issues; close them with a pointer comment (`gh issue close <N> --comment "..."`).

## After writing

1. Print a summary: milestones created, issues created, issues updated, with URLs.
2. Say which phases were filed and which stayed in the roadmap, and when to re-run to advance the window.
3. Suggest the next step: `/wf:feature docs/specs/NNN_<name>.md` (or a slice file `docs/specs/NNN_<name>/MMM_<slice>.md`) for one task, or `/wf:autopilot docs/roadmap/NNN_<phase>.md` for a whole phase. When a phase finishes, `/wf:autopilot` marks it `Completed`; re-run `/wf:issues docs/roadmap/README.md` to advance the window.
