# Trunk-Based Development with AI

> The branching model this toolkit is built around — why we left Git Flow behind, and how trunk-based development matches the way AI changes the shape of a workday.

---

## Table of Contents

1. [Why this matters now](#why-this-matters-now)
2. [Git Flow — the past](#git-flow--the-past)
3. [Trunk-Based — the present (and future)](#trunk-based--the-present-and-future)
4. [The seven rules](#the-seven-rules)
5. [How the skills enforce it](#how-the-skills-enforce-it)
6. [Recipes](#recipes)
7. [FAQ](#faq)

---

## Why this matters now

Before AI, a developer produced maybe 2–5 meaningful diffs per day. A long-lived branch model (Git Flow) added friction, but the friction was absorbed into human thinking time.

With AI in the loop, generation time collapses. A developer + Claude can produce dozens of shippable diffs per day. The bottleneck shifts: **review, merge, and integration become the slow path.** The 2025 DORA Report confirms this — PR review time rises ~91% in high-AI-adoption teams.

A branching model optimised for "protect main from incomplete work" (Git Flow) now *creates* the bottleneck. A branching model optimised for "integrate continuously, protect main with gates" (trunk-based) removes it.

This is why every modern high-velocity org — Google, Meta, Netflix, Shopify, most well-run startups — runs trunk-based. AI didn't invent trunk-based, but AI makes Git Flow actively harmful.

---

## Git Flow — the past

Introduced by Vincent Driessen in 2010. Five branch types:

- `master` — production
- `develop` — integration
- `feature/*` — per-feature, long-lived, off `develop`
- `release/*` — stabilisation before deploy
- `hotfix/*` — emergency patches off `master`

**Why it worked in 2010:**
- Desktop software with quarterly releases.
- No CI/CD, no feature flags, no canaries.
- Merging was risky; long-lived branches were a defensive moat.

**Why it breaks in 2026 (especially with AI):**
- **Merge debt compounds.** A `feature/*` branch open for two weeks rebases against a `develop` that moved by hundreds of commits. With AI producing diffs 10× faster, the rebase cost 10×es.
- **Integration happens late.** Bugs from the interaction between two features surface at `release/*` time — days or weeks after the code was written. Context is gone.
- **`develop` is a lie.** It's never in a shippable state. "Are we green?" has no answer.
- **Feature flags are absent.** All un-ready work hides on branches, invisible to CI.
- **The ceremony tax.** Cutting release branches, merging up and down between `master` and `develop`, resolving cross-branch conflicts — pure overhead with no product value.

Git Flow optimises for a world where integration is dangerous. Modern CI, feature flags, and AI-assisted testing make integration safe. The defensive moat becomes a swamp.

---

## Trunk-Based — the present (and future)

One long-lived branch: `main` (the trunk). Everything else is a short-lived topic branch that merges back within hours to ~2 days.

```
main  ────●────●────●────●────●────●────●────●────►
           \       \       \       \
            feat/a  fix/b   feat/c  feat/d
            (2 hrs) (4 hrs) (1 day) (6 hrs)
```

**Core moves:**
- `main` is always deployable. Broken main = stop-the-line incident.
- Features ship as multiple small slices, not one big branch. If a slice isn't user-ready, merge it behind a feature flag.
- CI runs on every PR, full suite, with quality gates (lint, typecheck, tests, security review).
- After merge, branch is deleted. There is no "keep it around in case."

**Why it fits AI:**
- AI makes generation cheap; trunk-based makes integration cheap. Compounds.
- Short branches ⇒ small PRs ⇒ reviewable by humans *and* by AI reviewers in one pass.
- Feature flags decouple "merged" from "shipped" — you can integrate continuously and release on human timing.
- No `develop`, no `release/*`, no up-merge/down-merge ceremony. Claude writes code, not calendar invites.

---

## The seven rules

These live in root `CLAUDE.md` → **Trunk-Based Workflow**. The planning skills in this toolkit are built around them; during implementation they apply as global rules.

1. **One trunk.** `main` only. No `develop`, no `release/*`. If you need to stabilise for a release, use a tag + a feature flag, not a branch.

2. **Short-lived branches.** Hours to ~2 days. If a branch lives longer, it's a planning failure — re-slice the work.

3. **Typed branch names.** `feat/<slug>`, `fix/<slug>`, `refactor/<slug>`, `docs/<slug>`, `chore/<slug>`, `test/<slug>`, `perf/<slug>`, `security/<slug>`. The prefix tells reviewers what lens to apply.

4. **One branch = one PR = one vertical slice.** ≤200 lines of diff **excluding tests** — source lines only; test lines never count toward the budget. Exceed this and you've conflated two concerns; split.

5. **Vertical slicing.** A "feature" that's too big becomes N slices, each end-to-end (DB → API → UI for *one* capability), each independently mergeable. Never horizontal (all DB first, then all API). Horizontal slices pile up un-shippable state.

6. **Feature flags over long branches.** If a slice isn't user-ready, merge it behind a flag (default off). `main` stays deployable; the flag flips when the feature is whole.

7. **Delete after merge.** Branch gone from local + remote, worktree removed. Never reuse a merged branch. The history is in `git log`, not in branch names.

---

## How the skills enforce it

This toolkit is wired so the trunk-based rules are defaults, not discipline:

| Skill | What it enforces |
|-------|------------------|
| **`/spec`** | If the feature is estimated >200 lines, produces N sub-specs under `docs/specs/<feature>/NNN_<slice>.md` with an index. Each sub-spec has a `## Feature Flag` section. |
| **`/issues`** | One issue per task/slice, labelled `type:<type>`, carrying the spec path, the feature flag, and the `<type>/<issue-number>-<slug>` branch name. |
| **`/commit`** | One concern per commit. Each commit leaves the tree green. |
| **`/roadmap`** | "One task = one PR." Phases are independently mergeable units. |

Implementation, PR and review are no longer skills in this toolkit — they are handled by marketplace plugins (`feature-dev`, `superpowers`, `pr-review-toolkit`; see the README's "Required plugins"). Those plugins know nothing about these rules, so the typed branch name, the ≤200-line slice budget, the feature flag wiring and the post-merge cleanup apply through the global `CLAUDE.md`, which is loaded in every session. To measure a slice against the budget, count source lines only:

```bash
git diff --stat main...HEAD -- . ':(exclude)**/tests/**' ':(exclude)**/*_test.*' ':(exclude)**/*.test.*' ':(exclude)**/test_*'
```

Nothing is configured in `git` itself. The rules live in docs + the global `CLAUDE.md` + (optionally) GitHub branch protection. Portable, reversible, visible.

---

## Recipes

### A small feature (≤200 lines)

```bash
# 1. Spec
/spec user-avatar-upload

# 2. Branch + worktree (outside repo)
git worktree add -b feat/user-avatar-upload ../myrepo-avatar main
cd ../myrepo-avatar

# 3. Implement, then ship
/feature-dev:feature-dev implement docs/specs/user-avatar-upload.md
# review the diff (review-pr reads uncommitted changes), then commit and open the PR:
/pr-review-toolkit:review-pr
/commit
git push && gh pr create

# 4. After merge, clean up
git checkout main && git pull
git branch -d feat/user-avatar-upload
git push origin --delete feat/user-avatar-upload
cd -
git worktree remove ../myrepo-avatar
```

### A larger feature (sliced)

```bash
# 1. Spec — /spec detects >200 lines and slices
/spec oauth-integration

# Produces:
# docs/specs/oauth-integration/README.md       (index)
# docs/specs/oauth-integration/001_provider-config.md
# docs/specs/oauth-integration/002_callback-handler.md
# docs/specs/oauth-integration/003_session-wiring.md
# docs/specs/oauth-integration/004_ui-login-button.md
# Each sub-spec names the feature flag: `oauth_enabled` (default off)

# 2. Implement each slice in its own branch, back to back
git worktree add -b feat/oauth-provider-config ../myrepo-oauth-1 main
cd ../myrepo-oauth-1
/feature-dev:feature-dev implement docs/specs/oauth-integration/001_provider-config.md
# `/pr-review-toolkit:review-pr` on the diff, then `/commit` + `git push` + `gh pr create`
# merge, delete, repeat for 002, 003, 004

# 3. Flip the flag when 004 merges (or on product's timeline)
```

Note: slices 002–004 are cut from `main` *after* 001 is merged — never stacked on 001's branch.

### A bug fix

```bash
git checkout -b fix/login-semicolon
# Describe the bug: "login fails when password contains ';'" — the superpowers
# `systematic-debugging` skill finds the root cause before any fix is proposed.
# `/pr-review-toolkit:review-pr` on the diff, then `/commit` + `git push` + `gh pr create`.
```

### Emergency rollback

Trunk-based doesn't need `hotfix/*` branches. Options, in order of preference:

1. **Flip the feature flag off.** Zero-risk, seconds.
2. **Revert the offending commit** (`git revert <sha>`) on a `fix/revert-<topic>` branch → PR → merge.
3. **Roll forward** with a new fix on `fix/<slug>`.

The old Git Flow pattern of "cherry-pick hotfix to master and merge down to develop" doesn't exist here. There's no `develop` to merge down to.

---

## FAQ

**Q: How do we do releases without `release/*` branches?**
A: Tag `main` at the point you want to release (`git tag v1.4.0`). Deploy from the tag. If you need to patch the release, cherry-pick onto a short-lived `fix/<slug>` branch, re-tag (`v1.4.1`), re-deploy. No long-lived release branch required.

**Q: What if my PR is 350 lines and I can't reasonably split it?**
A: Almost always, "can't split" means "haven't tried hard enough to slice vertically." But the 200-line target is a warning, not a hard block — you can go over it with explicit confirmation. Use the override as a smell: if it happens often, your slicing technique needs work, not the threshold.

**Q: We don't have feature flags. Do we need a whole system?**
A: No. A `const FEATURE_X_ENABLED = false` in a config file is a feature flag. Grow into a proper flag service (LaunchDarkly, Unleash, homegrown) only when you need runtime toggles, percentage rollouts, or per-user targeting. Most teams over-engineer this.

**Q: Won't small PRs flood reviewers?**
A: They flood less than big PRs. Small PRs review in minutes; big PRs bounce between author and reviewer for days. Throughput goes up. Tooling matters too — auto-assign reviewers, require only one approval for small changes, use merge queues.

**Q: How does this work with multiple worktrees at once?**
A: Perfectly — it's the reason worktrees exist. Each slice gets its own worktree (outside the repo), its own branch, its own Claude session. You can run 3–5 in parallel without context collisions. For agent-orchestrated versions, see the `superpowers` plugin's `subagent-driven-development` and `dispatching-parallel-agents` skills.

**Q: Isn't "commit to main" dangerous?**
A: No one commits to main. Trunk-based = PRs to main. The trunk is protected by branch-protection rules (require PR, passing CI, linear history). The difference from Git Flow isn't "less safety" — it's "safety via gates on one branch, not via isolation on five."

**Q: What about GitHub branch protection — is it required?**
A: Recommended. Minimum useful config:
- Require PR before merging to `main`
- Require status checks to pass (CI, lint, tests)
- Require linear history (no merge commits — use squash or rebase)
- Auto-delete merged branches
- Dismiss stale approvals on new commits

Nothing in this toolkit *requires* it; the rules work on discipline alone. But for teams, protection rules turn discipline into defaults.

---

## Further reading

- [Trunk-Based Development](https://trunkbaseddevelopment.com/) — the canonical reference
- [DORA Report](https://cloud.google.com/devops/state-of-devops) — data on trunk-based vs other models
- Root `CLAUDE.md` → **Trunk-Based Workflow** — the terse rules
- `docs/WORKFLOW.md` — how these rules slot into the full AI-assisted workflow
