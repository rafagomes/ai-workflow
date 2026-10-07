---
name: issues
description: "File GitHub milestones + issues for a roadmap, a phase, or a spec — one milestone per phase, one issue per task/slice — using the trunk-based patterns from /spec and /roadmap. Use when the user says 'create the GitHub issues', 'file the issues for this roadmap', 'open issues for this spec', 'make the milestones', or points at docs/roadmap/*.md or docs/specs/*.md and asks to hand them to GitHub."
---
File GitHub milestones and issues for: $ARGUMENTS

## What this skill does

`/issues` is the hand-off between planning artifacts (`docs/roadmap/*.md`, `docs/specs/*.md`) and GitHub. It files:

- **One milestone per phase** — `Phase NNN — <phase-name>`
- **One issue per task/slice** — title `[NNN.N] <task-name>` for a roadmap task, `[NNN.N.N] <slice-name>` for a sliced sub-task, or `[<feature>.NNN] <slice-name>` for a standalone spec's slice.
- **Labels per issue** — `type:<type>`, `complexity:<low|med|high>`, `mvp` or `post-mvp` (if derivable), and `needs-spec` / `spec-ready` / `blocked` as appropriate.
- **Issue body** — spec link, file list, dependencies, verification command, feature flag, acceptance criteria pulled from the spec.

After filing, `/issues` writes the issue numbers back into the source `Issue:` / `Issues:` columns so whoever implements the task can read them when building branch names.

## Parse arguments

The argument is one of:

- **Roadmap index** — `/issues docs/roadmap/README.md` files *everything*: one milestone per phase file, one issue per task, one issue per slice where a task points at a sliced spec.
- **Phase file** — `/issues docs/roadmap/NNN_<phase>.md` files one milestone + the phase's tasks (and slices where applicable).
- **Sliced spec index** — `/issues docs/specs/NNN_<feature>/README.md` files one issue per row in the Slices table. Uses the feature's existing milestone if found (matched by phase reference in the spec), otherwise creates a standalone no-milestone batch.
- **Single spec** — `/issues docs/specs/NNN_<feature>.md` files one issue. No milestone unless the spec references a phase.

No argument? Default to `docs/roadmap/README.md` if it exists; otherwise prompt.

## Transport: GitHub MCP first, `gh` fallback

Prefer the **GitHub MCP** (tool names starting with `mcp__github__*` or similar) for every read and write. It gives structured JSON in/out and avoids shelling out.

Detection order at skill start:
1. If `mcp__github__*` tools are available in this session, use them. Call `mcp__github__authenticate` (or the equivalent) first if the server reports unauthenticated. If the MCP tool list includes create/update/list tools for issues, milestones, and labels, run the entire skill through MCP.
2. If GitHub MCP is **not** available, or a specific action isn't exposed by the MCP, fall back to the `gh` CLI. Run `gh auth status` once; if it fails, tell the user to run `gh auth login` (their call — don't do it for them) and stop.
3. **Never mix** mid-run for the same action type. Pick one transport per session; if you start on MCP and hit a missing tool, switch everything remaining to `gh` rather than interleaving.

The MCP-equivalent operations map to these `gh` calls (shown as the fallback reference — use the MCP tool first when present):

| Operation | MCP (preferred) | `gh` fallback |
|-----------|-----------------|---------------|
| List milestones | `mcp__github__list_milestones` | `gh api "repos/{owner}/{repo}/milestones?state=all" --jq '.[]'` |
| Create milestone | `mcp__github__create_milestone` | `gh api "repos/{owner}/{repo}/milestones" -f title=... -f description=...` |
| List labels | `mcp__github__list_labels` | `gh label list --json name,color` |
| Create label | `mcp__github__create_label` | `gh label create "<name>" --color <hex>` |
| Create issue | `mcp__github__create_issue` | `gh issue create --title ... --body-file <tmp> --milestone "..." --label "..."` |
| View issue | `mcp__github__get_issue` | `gh issue view <N> --json title,state,milestone,labels,body` |
| Edit issue | `mcp__github__update_issue` | `gh issue edit <N> --title ... --add-label ... --remove-label ... --milestone ...` |
| Close issue | `mcp__github__close_issue` | `gh issue close <N> --comment "..."` |
| List issues | `mcp__github__list_issues` | `gh issue list --state all --json number,title,labels,milestone` |

If the exact MCP tool name differs from the table, use whichever MCP tool matches the operation — inspect the available MCP tools, don't hard-code the name.

## User prompts — use `AskUserQuestion`

Every interactive decision point in this skill must use the `AskUserQuestion` tool, not free-text prompts. Confirmations rendered as plain text are easy for the user to miss and produce ambiguous answers ("ok", "sure", "go"); structured options are faster to answer, unambiguous to parse, and let the user pick "Other" to override.

The four decision points in this skill are:

| When | Question | Header (≤12 chars) | Options (first = recommended) |
|------|----------|--------------------|-------------------------------|
| Preflight step 4 — drifted / gone issues found | "How should I reconcile the drifted or closed issues?" | `Reconcile` | **Update in place (Recommended)**, Close + refile, Skip |
| Preflight step 6 — dry-run confirmation | "Proceed with the plan above?" | `Proceed?` | **Yes, proceed (Recommended)**, Cancel |
| Pacing — roadmap-index horizon | "Which horizon should I file?" | `Horizon` | **Current + next phase (Recommended)**, Full roadmap |
| Execution loop — after each milestone batch | "Proceed to Phase NNN+1?" | `Next phase` | **Yes, continue (Recommended)**, Stop here |

All four are single-select (`multiSelect: false`). The user can always pick the auto-added "Other" to type free-form guidance — treat that as a correction and re-plan rather than proceeding.

If two decisions are needed back-to-back (e.g., horizon choice + dry-run confirm on the same roadmap-index run), batch them into one `AskUserQuestion` call with two questions, so the user clicks once.

## Preflight

1. **Pick transport** (above). Stop if neither works.
2. **Confirm we're in a git repo with a GitHub remote** — `git remote get-url origin` and check it's a github.com URL. If not, stop.
3. **Read the source file(s) top-to-bottom** — parse the Tasks and Slices tables, collect `Type`, `Complexity`, `Feature flag`, `Dependencies`, `Spec`, and the existing `Issue:` / `Issues:` columns.
4. **Detect already-filed issues.**
   - For each row that already has a `#<N>` in the `Issue` column, fetch the issue (MCP `get_issue` or `gh issue view`).
   - Classify each as `match` (still aligned with the source), `drift` (title/labels/milestone or body need an update), or `gone` (issue was closed or deleted).
   - Print the summary in text: `X rows already filed: Y match / Z drift / W gone`.
   - Then call `AskUserQuestion` (see "User prompts" above) with a single `Reconcile` question to choose the bulk action (Update in place / Close + refile / Skip). If the user picks "Other" and names specific rows, re-plan per-row before proceeding.
   - Rows without an `Issue` value are always new and don't enter this prompt.
5. **Fetch existing milestones** — match phase filenames against existing milestone titles so reruns are idempotent.
6. **Dry-run the plan.** Before any write, print the full list of what will be created or changed — milestones, issues (title + labels + milestone), and writebacks. Then call `AskUserQuestion` with a `Proceed?` question (Yes / Cancel) to confirm before proceeding. Do not proceed on free-text affirmations — wait for the structured answer. For a roadmap-index input, batch this with the `Horizon` question in the same `AskUserQuestion` call.

## Milestone shape

- **Title:** `Phase NNN — <phase-name>` (exact, copy from `docs/roadmap/NNN_<phase-name>.md`'s `# Phase NNN:` heading)
- **Description:** copy the phase's `## Context` paragraph (truncate to ~500 chars).
- **Due date:** skip unless the phase file names one.

Create via MCP `create_milestone` (preferred) or `gh api "repos/{owner}/{repo}/milestones" -f title="..." -f description="..."` (fallback).

## Issue shape

**Title patterns:**

| Source | Title |
|--------|-------|
| Roadmap task (single-file spec) | `[NNN.N] <task-name>` — e.g., `[003.2] Jira sync worker` |
| Roadmap task (sliced spec, sub-issue) | `[NNN.N.N] <slice-name>` — e.g., `[003.2.1] Jira issue-list fetcher` |
| Standalone spec slice | `[<feature>.NNN] <slice-name>` — e.g., `[atlassian.002] Confluence page index` |
| Standalone single-file spec | `<feature-name>` — e.g., `atlassian-integration` |

**Labels (apply in this order):**

- `type:<type>` — from the spec's `Type` field (one of `feat`, `fix`, `refactor`, `chore`, `test`, `docs`, `perf`, `security`).
- `complexity:low` / `complexity:med` / `complexity:high` — from the spec's `Complexity` field.
- `mvp` or `post-mvp` — derivable only from the roadmap index's MVP column. Omit when not derivable.
- `needs-spec` — if the task's spec file doesn't exist yet.
- `spec-ready` — if the spec exists and has a filled-in Verification section.
- `blocked` — if `Dependencies` names another task whose issue is still open.

**Bootstrap the labels on first run.** Via MCP `list_labels` + `create_label` (preferred) or `gh label list --json name --jq '.[].name'` + `gh label create "<name>" --color <color>` (fallback). Enumerate existing labels and create only what's missing, using this default palette:

- `type:feat` — `1d76db` (blue)
- `type:fix` — `d73a4a` (red)
- `type:refactor` — `a2eeef` (cyan)
- `type:chore` — `cccccc` (grey)
- `type:test` — `0e8a16` (green)
- `type:docs` — `0075ca` (dark blue)
- `type:perf` — `fbca04` (yellow)
- `type:security` — `b60205` (dark red)
- `complexity:low` — `c2e0c6` (light green)
- `complexity:med` — `fef2c0` (light yellow)
- `complexity:high` — `f9d0c4` (light red)
- `mvp` — `0e8a16` (green)
- `post-mvp` — `cfd3d7` (light grey)
- `needs-spec` — `e99695` (salmon)
- `spec-ready` — `c5def5` (pale blue)
- `blocked` — `b60205` (dark red)

**Body template:**

```markdown
## Context
<one-paragraph summary from the task's Context or the spec's Problem>

## Spec
- File: [<path>](<path>)
- Trunk metadata: type=<type>, flag=<flag>, complexity=<complexity>

## Files
<bullet list of files from the task's Files field>

## Dependencies
<one of: `None.` · `Blocked by {{issue:<slice-id>}}[, {{issue:<slice-id>}}...].` — see "Dependencies: two-pass resolution" below>

## Verification
```
<verification command from the spec>
```

## Acceptance Criteria
<pull Verification Criteria bullets from the spec — each becomes a `- [ ]` checklist item>

## Feature Flag
<flag name and default, or `None — slice is user-ready on merge`>

## Branch
`<type>/<issue-number>-<slug>` — created with `gh issue develop` after this issue is filed, or manually via `git checkout -b <type>/<this-issue-number>-<slug>`.

---
Filed by `/issues` from `<source-file>`.
```

Create via MCP `create_issue` (preferred; pass title/body/milestone/labels as fields) or `gh issue create --title "..." --body-file <tmp> --milestone "Phase NNN — <name>" --label "type:feat" --label "complexity:med" ...` (fallback).

## Dependencies: two-pass resolution

**Never write `#001`, `#002`, … in an issue body.** GitHub auto-links any `#N` to the real issue with that number — so `#001` resolves to issue #1 in the repo, not the slice you meant. This silently produces cross-linked, wrong references.

GitHub issue numbers are assigned by the server at creation time and can't be predicted, so dependency references must be filled **after** each issue is created. Use a two-pass approach:

**Pass 1 — write with placeholders.** In the body template's `Dependencies` section, reference other slices/tasks using a `{{issue:<slice-id>}}` token whose key is the source identifier (e.g., `{{issue:atlassian.001}}`, `{{issue:003.2}}`, `{{issue:004.2.1}}`), not a `#N`. Example body fragment:

```markdown
## Dependencies
Blocked by {{issue:atlassian.001}}, {{issue:atlassian.004}}.
```

Any `#` token you write at this stage is a bug. If a dependency is external (already filed), write its real `#N` directly — those are stable.

**Pass 2 — rewrite once the mapping is known.** After all issues in this batch are filed and you have a `slice-id → #N` map (e.g., `atlassian.001 → #48`), walk every filed issue in the batch, substitute each `{{issue:<slice-id>}}` token with the corresponding `#<N>`, and update the body via MCP `update_issue` / `gh issue edit --body-file <tmp>`. Pass 2 is also where you update the **source spec files' Dependencies fields** if they used slice-id references — the canonical form in the repo should match the canonical form on GitHub.

**Idempotency.** On re-runs, any `{{issue:…}}` token still present in a filed issue body means pass 2 was interrupted; resolve it. Any `#N` already in place that matches the current mapping is left alone.

**Applies to every source type** (roadmap index, phase file, sliced spec, single spec). Single-spec inputs with `None.` dependencies skip pass 2 entirely.

## Pacing: two-milestone horizon (default recommendation)

When the input is a roadmap index (`docs/roadmap/README.md`) spanning many phases, **default to filing only the current phase + the next phase** — not the entire roadmap. Everything further out stays in the roadmap doc and nowhere else.

Why this is the default (team practice that translates cleanly to solo):
- GitHub issues rot. Filing 50+ upfront creates stale `blocked` / `needs-spec` labels, milestones that close with half their items undone, and branches pointing at dead scope.
- The roadmap doc is the long-range artifact; GitHub issues are the short-range one. Don't duplicate them — they serve different cadences.
- Two phases of horizon is enough to see upcoming dependencies without fabricating backlog pressure for work months out.
- A solo dev gets team discipline (issue-per-PR, milestone-scoped work) without the team overhead (triage meetings, stale-label maintenance).

**Dropped on purpose** (team overhead with no solo payoff):
- Story points / effort estimates.
- Skeleton issues for every post-MVP phase.
- `needs-spec` / `blocked` labels on work 3+ phases out — the roadmap doc already carries that state.

**Default behavior when the input is a roadmap index:**

1. Identify the **current phase** — first phase whose status is not `Completed` in the index table, or whose tasks don't all have filled `Issue` values.
2. Identify the **next phase** — the phase directly after the current one in the index.
3. Propose filing *only those two* in the dry-run. Explicitly list the phases being skipped ("Phases 004–009 stay in docs/roadmap/ for now — re-run `/issues` when you're ready to start the next wave").
4. Ask the user via `AskUserQuestion` (see "User prompts" above) with the `Horizon` question — options "Current + next phase (Recommended)" and "Full roadmap". If they pick full, proceed without the horizon cap — but warn them about the label-rot cost. Batch this with the dry-run `Proceed?` question in the same call to save a click.

This rule does not apply to phase-file or single-spec inputs — those are already scoped.

**Rolling forward:** re-running `/issues docs/roadmap/README.md` later is idempotent on already-filed phases (see Idempotency rules) and picks up the next two-phase window. Typical rhythm: when you're mid-way through the current milestone, re-run to file the next-next phase, keeping the two-phase buffer ahead of active work.

## Execution mode: per-milestone confirmation

For roadmap/phase inputs, file **one milestone + its issues at a time**, in roadmap order. After each milestone batch:

1. Print the created milestone URL + issue URLs and numbers.
2. **Run pass 2** (see "Dependencies: two-pass resolution"): build the `slice-id → #N` map from this batch, then rewrite every issue in the batch whose body contains `{{issue:…}}` tokens. Do this before the writeback in step 3 so downstream spec edits can reference final `#N` values.
3. Patch the `Issue:` / `Issues:` columns in the source roadmap/spec files with the newly-minted `#<N>` values.
4. Call `AskUserQuestion` with the `Next phase` question (Yes, continue / Stop here) — halt unless the user selects "Yes, continue". An "Other" response is also a halt: re-plan before continuing.

This keeps a broken run recoverable (stop after any batch and fix the source file) and keeps writebacks atomic per phase.

For single-spec inputs, skip the confirmation loop — file the issue(s), writeback, done.

## Writeback

After filing, update the source Markdown in place:

- **Roadmap tasks:** replace `- **Issues:** —` with `- **Issues:** #<N>` (or `#<N>, #<N+1>, ...` for sliced tasks).
- **Spec Slices table:** replace the `—` in the `Issue` column with `#<N>`.
- **Single-spec Trunk Metadata:** replace `- **Issue:** — (filled by `/issues`)` with `- **Issue:** #<N>`.

Do this with `Edit` (exact-string replace), not by rewriting the file — preserve surrounding formatting.

If a row was updated in place (not newly filed), leave the `Issue:` column alone.

## Idempotency rules

- Re-running on a fully-filed source is a no-op: dry-run shows 0 creates, 0 updates.
- Re-running after some rows were hand-closed on GitHub treats them as `gone` and offers refile/skip.
- Re-running after the source spec was edited surfaces drift for every affected row; user decides update-in-place vs. close+refile.
- Never delete issues; close them with a pointer comment instead. The user can clean up closed issues manually.

## After writing

1. Print a final summary: N milestones created, M issues created, K updated, list the URLs.
2. Remind the user of the horizon: which phases were filed, which stayed in the roadmap doc, and when to re-run to advance the window.
3. Suggest the next step based on what's now in place:
   - **Current phase filed?** → "Each issue now carries its spec and is ready to be implemented. In Claude Code, hand one to the `feature-dev` plugin: `/feature-dev:feature-dev implement issue #<N> per docs/specs/NNN_<name>.md` (or a slice file `docs/specs/NNN_<name>/MMM_<slice>.md`). There is no one-command 'run the phase end-to-end' pipeline in this toolkit; for several tasks in one session, see the `superpowers` plugin's `subagent-driven-development` / `executing-plans` skills."
   - **Mid-phase check-in?** → "When you're ~halfway through the current phase, re-run `/issues docs/roadmap/README.md` to file the next phase and keep a two-phase buffer ahead."
   - **Finished a phase?** → "Mark the phase `Completed` in the roadmap index's Status column, then re-run `/issues docs/roadmap/README.md` — it'll advance the window to the next unstarted phase."
