# Skill Quality Process

> How skills in this repo are tested and refined: with measurements, not vibes.

Skills compound: a small improvement that fires hundreds of times per week is worth more than a big improvement that fires once. That also means a small *regression* compounds. For the skills that matter, we measure before we ship.

The measuring tool is Claude Code's built-in `claude plugin eval`. The cases live in [`evals/`](../evals/) and run against the working tree.

> **Evals are local and opt-in. They are never run in CI.** Every run calls a model on the developer's own account and costs money, and this project's pipeline uses nothing paid. Do not add `claude plugin eval` to a workflow in `.github/`.

---

## When to run

Not for every skill change. A run costs real money and a few minutes, so we reserve it for:

- **Workhorse skills**: `/wf:commit`, `/wf:feature`, `/wf:fix`, `/wf:pr`. They fire constantly and regressions compound fast.
- **Structural rewrites**: any change that drops, adds or reorders a full step.
- **Skills under suspicion**: if a skill "feels" slow or inconsistent, measure before tuning.

Description tweaks, typo fixes and example additions skip it. Use judgment.

## What is in the suite

`evals/<case>/` holds one case: a `case.yaml` (prompt, limits, graders) and a `scaffold.sh` that builds a throwaway git repository for it. Every case is tagged with its skill, and none needs a network, GitHub or a remote.

| Case | Tag | What it checks |
|---|---|---|
| `commit-split-python` | `commit` | Three unrelated changes become three conventional commits; an untracked `.env` is never staged; no `git add .`, push or `--no-verify` |
| `commit-one-concern-shell` | `commit` | One concern is one commit (no invented splits); build output and scratch files stay untracked |
| `feature-python-issue-branch` | `feature` | Branch `feat/42-slug-truncate` from Trunk Metadata; a test for each verification criterion; checks run; nothing committed |
| `feature-shell-unfiled` | `feature` | Unfiled issue gives `feat/quiet-flag` (no number); shell test harness covers the criteria; nothing committed |
| `fix-python-pagination` | `fix` | Off-by-one fixed (checked by running the code); regression test added; tests run before and after; root cause reported; nothing committed |
| `fix-shell-kv-parse` | `fix` | Value truncated at `=` fixed (checked by running the script); regression check added; root cause reported |
| `pr-dirty-tree` | `pr` | Uncommitted changes: stops and points at `/wf:commit`; no push, no PR |
| `pr-on-trunk` | `pr` | On `main`: stops and asks for a feature branch; no push, no PR |

Graders are deterministic wherever a check exists: regexes over the final message or over files the run produced, and `tool_used` checks on the tool calls. Only the two root-cause assertions in the `fix` cases use an LLM judge (haiku by default), because "names the cause, not the symptom" has no mechanical check. A `skill-fired` grader in every case is marked `arm: with-only`: it shows that the skill loaded and is not part of the score.

## How to run

Run from the repo root. Cases that build a repository need `--scaffold`, and the agent's shell needs a grant:

```bash
# One case, one run, no baseline: the cheapest sanity check
claude plugin eval . --case commit-one-concern-shell --runs 1 --ablation none \
  --no-publish --scaffold --trust-plugin --allow-tools Bash Write Edit --max-cost-usd 1

# One skill, by tag
claude plugin eval . --tag fix --scaffold --no-publish --allow-tools Bash Write Edit --max-cost-usd 5

# The full suite against a no-plugin baseline (the default, `--ablation with-without`)
claude plugin eval . --scaffold --no-publish --allow-tools Bash Write Edit --max-cost-usd 15 \
  --json evals/results/latest.json
```

Flags that matter:

- `--scaffold` runs each case's `scaffold.sh` as you, outside the agent's sandbox. Pass it only for cases you or this repo's maintainers wrote.
- A tool needs two things: it must be in the case's `allowed_tools` and be granted with `--allow-tools`. The cases list `Bash` (and `Write`, `Edit` for `feature` and `fix`); `--allow-tools Bash Write Edit` is the other half. Without either half the tool is silently removed and the run only fails its graders (the CLI says `not granted` in its progress output). The agent's shell runs in Claude Code's OS sandbox, confined to the run's workspace.
- `--runs N` overrides the per-case run count (default 3). One run is a smoke test; use 3 or more before calling a result real.
- `--max-cost-usd` is a hard ceiling. Set it every time.
- `--no-publish` keeps the HTML report local.
- `--threshold 0.8` makes the exit code non-zero below that score (default 1.0).
- `--judge-model` changes the LLM judge; `--model` changes the model under test.

### Iterating on a skill against its previous version

To know whether an edit improved the *skill*, not just the gap over no plugin, run the same suite on the old commit and the new one and compare:

```bash
git worktree add .claude/worktrees/eval-base <old-commit-or-main>
claude plugin eval .claude/worktrees/eval-base --tag feature --scaffold --no-publish \
  --allow-tools Bash Write Edit --ablation none --runs 3 --json /tmp/base.json
claude plugin eval . --tag feature --scaffold --no-publish \
  --allow-tools Bash Write Edit --ablation none --runs 3 --json /tmp/new.json
git worktree remove .claude/worktrees/eval-base
```

The target is a plugin path, so the old checkout is evaluated as it was. Check `git check-ignore -q .claude/worktrees/x` first (see the worktree rule in the global `CLAUDE.md`). Both worktrees need the same `evals/` directory; when the old commit predates a case, copy it in.

## How to read results

Each case prints a score (the weighted fraction of graders that passed, averaged over runs), the cost, and one line per grader. With the baseline arm on, the report also shows the score of the no-plugin run and the delta.

- **A grader that passes in both arms measures Claude, not the skill.** Keep it only as a guard against regression; the value of the suite is in the graders where the plugin arm passes and the baseline does not.
- **A grader that fails in both arms is probably a bad grader.** Read the trace before blaming the skill.
- **Read the transcript, not only the number.** The HTML report links each run's trace. Numbers miss style: whether the commit plan was sensible, whether the root-cause sentence was true.
- **One run is noise.** Before shipping a change on the strength of a delta, rerun with `--runs 3` or more.
- If the progress output says a tool was `not granted`, or a `tool_used` grader with `max: 0` passes with `Bash called 0x`, the tool never ran: check both halves of the grant (above). The graders that guard against a forbidden command only mean something when `Bash` really ran.
- A `grader threw ... does not exist` line means the run never produced the file the grader reads: usually a tool was not granted, or the agent stopped early. Look at the trace.

## How to add a case

1. Pick the behaviour the skill adds over plain Claude. If a no-skill run would do it anyway, it is a weak case.
2. Make `evals/<skill>-<what-it-checks>/` with a `case.yaml` and a `scaffold.sh`. Start from `claude plugin eval init --bare <name>` if you want the blank template; the files here use the single-file `case.yaml` form (`schema_version: "1.1"`).
3. The scaffold builds a tiny repository: varied fixtures (different languages, a Makefile `test` or `lint` target), no network, no remote. It runs in the empty workspace with a minimal environment, and a non-zero exit fails the run.
4. Write the prompt the way a user would, and say that the run is non-interactive so the agent takes recommended defaults instead of waiting. Do not name the skill; the `skill-fired` grader tells you whether it loaded.
5. Prefer deterministic graders, and list every tool the skill needs in the case's `allowed_tools` (it must also be granted with `--allow-tools`). There is no command grader, so for state that only a command can show (commits, the result of running code), end the prompt with a line asking the agent to write it to a file (`git log ... > eval-commits.txt`) and grade the file with a `regex` grader using `target: { source: file, path: ... }`.
6. Tag the case with the skill, keep `max_turns` and `timeout_seconds` tight, and check the case can fail: break the behaviour (or run the baseline arm) and see the grader go red.

## Principles we settled on

- **A/B against the right baseline.** For new skills, the baseline is plain Claude with no skill. For iterations, the baseline is the prior version: we want to know if we improved *the skill*, not re-measure the gap over baseline.
- **Measure what actually discriminates.** Most assertions pass for both variants. The few that do not are where the skill's value lives. Double down on those; trim prose that moves no needle.
- **Cost is a dimension, not just a footnote.** A skill that adds 30% tokens for no correctness lift is a tax. A skill that saves 36% duration *while* lifting correctness is a bargain.
- **Qualitative review is not optional.** The grader said two versions tied on correctness; reading the transcripts showed one had found a real bug and the other had not. Automation told half the story.
- **Single-seed findings are directional, not definitive.** For skills we care about, n of 3 or more per cell is the bar before calling a change shipped.

## History

The first benchmark (April 2026) was on `/wf:feature`, then called `/feature`, with a hand-rolled harness: one agent with the skill, one without, a small `grade.py` over the outputs. Two findings shaped how we work now:

- **The skill earned its keep on pre-merge hygiene.** With four specs and 46 assertions, the skill scored 100% against 84.7% for plain Claude. Only two assertions discriminated (a security verdict in the PR body, and splitting work into three or more commits); correctness, conventional commits and tests were handled by baseline unprompted. Today's Claude implements tight specs well without help, so the skill's value is in what reviewers notice.
- **Shorter prose won on every axis.** Trimming the skill (compressing test-strategy discovery, adding concrete commit-split patterns, naming the "impl + docs = 2 commits" anti-pattern) took the pass rate from 87.9% to 100%, duration down 36% and tokens down 22%. The longer version had made two runs over-generalize "don't push" into "don't commit either". The review step was kept because, on one messy spec, it caught a real float-precision bug; it has since moved to `/wf:pr`, which dispatches the `wf:reviewer` agent on the committed branch.

Every cell in that benchmark was n=1, which is why the single-seed principle above exists. The harness has been replaced by `claude plugin eval`, so these results are no longer reproducible with the repo's tools.
