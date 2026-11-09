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

These live in root `CLAUDE.md` → **Trunk-Based Workflow**. Every skill in this toolkit enforces them.

1. **One trunk.** `main` only. No `develop`, no `release/*`. If you need to stabilise for a release, use a tag + a feature flag, not a branch.

2. **Short-lived branches.** Hours to ~2 days. If a branch lives longer, it's a planning failure — re-slice the work.

3. **Typed branch names.** `feat/<slug>`, `fix/<slug>`, `refactor/<slug>`, `docs/<slug>`, `chore/<slug>`, `test/<slug>`, `perf/<slug>`, `build/<slug>`, `ci/<slug>`, `security/<slug>`. The prefix tells reviewers what lens to apply.

4. **One branch = one PR = one concern.** A PR is one vertical slice a reviewer can hold in one pass. Size is a signal, not a quota: past roughly **500 added source lines**, ask whether it is really one concern, and split it if it is two. Tests, generated files, lockfiles, pure moves and deletions do not count. Do not cut one concern into several PRs to get under the number — PRs that only make sense together cost more review than one coherent PR.

5. **Vertical slicing.** A "feature" that's too big becomes N slices, each end-to-end (DB → API → UI for *one* capability), each independently mergeable. Never horizontal (all DB first, then all API). Horizontal slices pile up un-shippable state.

6. **Feature flags over long branches.** If a slice isn't user-ready, merge it behind a flag (default off). `main` stays deployable; the flag flips when the feature is whole.

7. **Delete after merge.** Branch gone from local + remote, worktree removed. Never reuse a merged branch. The history is in `git log`, not in branch names.

---

## How the skills enforce it

This toolkit is wired so the trunk-based rules are defaults, not discipline:

| Skill | What it enforces |
|-------|------------------|
| **`/wf:spec`** | If the feature is estimated at over ~500 source lines and is more than one concern, produces N sub-specs under `docs/specs/<feature>/NNN_<slice>.md` with an index. Each sub-spec has a `## Feature Flag` section. |
| **`/wf:feature`** | Requires a typed branch (`feat/<slug>`). Runs a slice-size gate (`git diff --numstat`, added source lines) — stops and asks when the change is over ~500 lines and more than one concern. Verifies the feature flag wiring from the spec. Implements sliced specs one slice at a time. |
| **`/wf:fix`** | Requires `fix/<slug>`. Same slice-size gate. |
| **`/wf:commit`** | One concern per commit. Each commit leaves the tree green. |
| **`/wf:pr`** | Validates the branch name against the convention. Warns when the diff is over ~500 source lines and more than one concern. Prints the post-merge cleanup command (branch delete + worktree remove). |
| **`/wf:roadmap`** | "One task = one PR." Phases are independently mergeable units. |
| **`/wf:autopilot`** | Executes phases via worktrees — natural fit for parallel, short-lived branches. |

Nothing is configured in `git` itself. The rules live in docs + skill gates + (optionally) GitHub branch protection. Portable, reversible, visible.

---

## Recipes

### A small feature (one concern)

```bash
# 1. Spec
/wf:spec user-avatar-upload

# 2. Branch + worktree (under .claude/worktrees/, git-ignored)
git worktree add -b feat/user-avatar-upload .claude/worktrees/avatar main
cd .claude/worktrees/avatar

# 3. Implement, then ship
/wf:feature docs/specs/user-avatar-upload.md
# review the diff, then:
/wf:commit
/wf:pr

# 4. After merge, clean up
git checkout main && git pull
git branch -d feat/user-avatar-upload
git push origin --delete feat/user-avatar-upload
cd -
git worktree remove .claude/worktrees/avatar
```

### A larger feature (sliced)

```bash
# 1. Spec — /wf:spec sees more than one concern and slices
/wf:spec oauth-integration

# Produces:
# docs/specs/oauth-integration/README.md       (index)
# docs/specs/oauth-integration/001_provider-config.md
# docs/specs/oauth-integration/002_callback-handler.md
# docs/specs/oauth-integration/003_session-wiring.md
# docs/specs/oauth-integration/004_ui-login-button.md
# Each sub-spec names the feature flag: `oauth_enabled` (default off)

# 2. Implement each slice in its own branch, back to back
git worktree add -b feat/oauth-provider-config .claude/worktrees/oauth-1 main
cd .claude/worktrees/oauth-1
/wf:feature docs/specs/oauth-integration/001_provider-config.md
# review the diff, then `/wf:commit` + `/wf:pr`
# merge, delete, repeat for 002, 003, 004

# 3. Flip the flag when 004 merges (or on product's timeline)
```

Note: slices 002–004 are cut from `main` *after* 001 is merged — never stacked on 001's branch.

### A bug fix

```bash
/wf:fix "login fails when password contains ';'"
# Lands on fix/login-semicolon. Review the diff, then `/wf:commit` + `/wf:pr`.
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

**Q: What if my PR is 800 lines and I can't reasonably split it?**
A: First ask whether it is one concern. If it is two, split it — vertically, so each half is mergeable on its own. If it is genuinely one (a rename that touches many files, a feature whose parts are meaningless apart), ship it as one PR and say why in the description. The 500-line mark is a prompt to ask the question, not a block: `/wf:feature` and `/wf:pr` flag it and you can override. The number was 200 when a human read every line; with a fresh-context reviewer on every PR, a string of tiny PRs costs more in review rounds and merge overhead than it saves.

**Q: We don't have feature flags. Do we need a whole system?**
A: No. A `const FEATURE_X_ENABLED = false` in a config file is a feature flag. Grow into a proper flag service (LaunchDarkly, Unleash, homegrown) only when you need runtime toggles, percentage rollouts, or per-user targeting. Most teams over-engineer this.

**Q: Won't small PRs flood reviewers?**
A: They flood less than big PRs. Small PRs review in minutes; big PRs bounce between author and reviewer for days. Throughput goes up. Tooling matters too — auto-assign reviewers, require only one approval for small changes, use merge queues.

**Q: How does this work with multiple worktrees at once?**
A: Perfectly — it's the reason worktrees exist. Each slice gets its own worktree (under `.claude/worktrees/`), its own branch, its own Claude session. You can run 3–5 in parallel without context collisions. See `/wf:autopilot` for the agent-orchestrated version.

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
