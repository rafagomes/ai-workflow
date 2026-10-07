# Skill Quality Process

> How skills in this repo are designed, benchmarked, and refined — not vibes.

Skills compound: a small improvement that fires hundreds of times per week is worth more than a big improvement that fires once. That also means a small *regression* compounds. We benchmark before we ship.

---

## The loop

The skill-creator workflow (from `claude-plugins-official`) formalizes this, but the shape is simple:

1. **Draft or edit** the skill.
2. **Build 3–5 real test specs** that cover the complexity range the skill will actually see.
3. **Run A/B in parallel** — one agent with the skill, one without (new skill) or one with the prior version (iteration).
4. **Grade programmatically** — assertions that score correctness, hygiene, and cost. No eyeballing.
5. **Read the qualitative outputs** — commits, PR bodies, file structure. Numbers miss style.
6. **Decide** — ship, iterate, or discard.

Seed repos are throwaway (`git init`, implement, measure, delete). Each run happens in its own workspace so agents can't interfere.

---

## What we measure

Depending on the skill, the fixed assertion set covers some mix of:

- **Correctness** — tests pass, verification criteria met, spec-specific outputs produced
- **Hygiene** — commits split by logical concern, conventional commit messages, no config drift
- **PR readiness** — summary, spec link, security verdict, test plan (per layer)
- **Cost** — wall-clock duration, token usage (higher isn't worse if quality lifts; we watch the tradeoff)

Assertions are graded with a Python script, not an LLM. That keeps scoring cheap, reproducible, and free of model bias. Subjective dimensions (code style, commit message quality) get read qualitatively after the numbers settle.

---

## Case study: `/feature` (Apr 2026)

> `/feature` has since been retired in favour of the `feature-dev` marketplace plugin (see the README's "Required plugins"). The case study is kept as a worked example of the process.

The `/feature` skill implemented a feature end-to-end from a spec file. It was the workhorse — it fired dozens of times per week across the team — so small lifts mattered.

### Iteration 1 — does the skill earn its keep?

**Setup:** 4 specs spanning complexity (pure util, stdlib CLI, FastAPI CRUD, refactor). With-skill vs plain-Claude baseline, 8 parallel agents.

| | with `/feature` | baseline |
|---|---|---|
| Pass rate | **100%** (46/46) | 84.7% (39/46) |
| Avg duration | 163.7s | 145.1s |
| Avg tokens | 39,178 | 35,918 |

**Where the lift came from:** Only **two** assertions discriminated — security verdict in PR body (4/4 vs 0/4) and commit-split ≥3 (4/4 vs 1/4). Correctness, conventional commits, test coverage, PR summary/spec-link — baseline handled them all unprompted.

**Interpretation:** Today's Claude is strong enough to implement tight specs without prompting. The skill earns its keep on *pre-merge hygiene* — the stuff reviewers notice.

### Iteration 2 — trim the dead weight, stress-test with ambiguity

Based on iter-1 findings:
- **Compressed** the test-strategy discovery step (4 bullets → 1 paragraph)
- **Sharpened** the security-verdict format with an explicit example for zero-surface features
- **Added** concrete commit-split patterns (CRUD: db → schemas → endpoints → tests)
- **Named** the "impl + docs = 2 commits" anti-pattern so the model would recognize it
- **Added** a 5th eval: an intentionally underspecified rate-limiter (algorithm, time source, defaults = implementer's call) to test whether the correctness gap emerges on messier specs

| | v2 (trimmed) | v1 (original) |
|---|---|---|
| Pass rate | **100%** (59/59) | 87.9% (52/59) |
| Avg duration | **134.5s** | 211.6s (−36%) |
| Avg tokens | **34,568** | 44,484 (−22%) |

**v2 won on every axis.** Shorter skill → faster, cheaper, *and* more reliable. Two v1 runs (slug-py, legacy-refactor) over-generalized a "don't push" instruction into "don't commit either" — v1's longer prose created ambiguity that v2's leaner shape didn't.

**Messy-spec finding:** Both variants scored 13/13 on rate-limiter. No correctness gap. **But** v1 took 488s vs v2's 131s because v1's self-review caught a real bug (`0.1 * 10 ≠ 1.0` float precision → infinite wait on `acquire()`) and iterated to fix it. v2 didn't hit the bug. Unclear whether v2 would have hit it in production; this warrants multi-seed verification.

### What shipped

v2 (`skills/feature/SKILL.md`, now only in git history). The review step (originally v1's step 7) was kept but compressed — the rate-limiter finding shows it occasionally catches real concurrency bugs that would otherwise ship.

### What didn't

- Dropping the review step entirely — too risky based on rate-limiter evidence
- Single-seed assumption — every cell in the matrix is n=1. A real prod change would want n=3 to bound noise

---

## Running a benchmark

The workspace layout we used:

```
skills/<skill>-workspace/
├── seeds/                  # clean seed repos (one per eval)
├── evals/evals.json        # eval definitions
├── iteration-1/
│   ├── eval-0-<name>/
│   │   ├── with_skill/workspace/  # agent runs here
│   │   └── without_skill/workspace/
│   ├── REPORT.md
│   └── summary.json
├── grade.py                # assertion grader (programmatic)
└── skill-snapshot-vN-SKILL.md  # for iterations against prior versions
```

The skill-creator's `aggregate_benchmark.py` expects a specific layout we didn't fully match; a 20-line `grade.py` + summary script was simpler and gave us the same information.

---

## Principles we settled on

- **A/B against the right baseline.** For new skills, the baseline is plain Claude with no skill. For iterations, the baseline is the prior version — we want to know if we improved *the skill*, not re-measure the gap over baseline.
- **Measure what actually discriminates.** Most assertions passed for both variants. The two that didn't are where the skill's value lives. Double down on those; trim prose that doesn't move any needle.
- **Cost is a dimension, not just a footnote.** A skill that adds 30% tokens for no correctness lift is a tax. A skill that saves 36% duration *while* lifting correctness is a bargain.
- **Qualitative review is not optional.** The grader said v1 and v2 tied on rate-limiter correctness. Reading the transcripts revealed v1 found a real bug and v2 didn't. Automation told half the story.
- **Single-seed findings are directional, not definitive.** For skills we actually care about, multi-seed (n≥3 per cell) is the bar before calling a change "shipped."

---

## When to benchmark

Not for every skill change. The cost of benchmarking is real (spawning 8–10 subagents burns tokens), so we reserve it for:

- **Workhorse skills** — `/spec`, `/roadmap`, `/issues`. These fire constantly; regressions compound fast.
- **Structural rewrites** — any change that drops, adds, or reorders a full step.
- **Skills under suspicion** — if a skill "feels" slow or inconsistent, benchmark before tuning.

Quick description tweaks, typo fixes, and example-adds can skip the loop. Use judgment.
