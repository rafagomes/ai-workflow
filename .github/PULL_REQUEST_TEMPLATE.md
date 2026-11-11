## Summary

<!-- What changed and why, in 1-3 bullets. Link related issues: Fixes #123 -->

-

## Spec

<!-- Link to the spec or issue this implements, or delete this section. -->

## Risk

<!-- T0 | T1 | T2 — why. Tiers are defined in dotfiles/CLAUDE.md (Risk tiers).
T0: prose typo, changelog entry or version bump only (never text that instructs an agent).
T1: an ordinary change.
T2: CI/CD, installer or anything that runs automatically, permissions or secrets, a public contract, anything hard to reverse. A maintainer merges it. -->

T1 — 

## Review

<!-- Reviewed by a fresh context (wf:reviewer or a fresh session): PASS / findings, LOW findings listed.
Only for T0: "Review: skipped — <reason>". -->

## Security checklist

<!-- Only when a security trigger applies (trust boundary, auth, crypto, input parsing, secrets, permissions, dependencies, anything that runs automatically); otherwise delete this section. -->

- [ ] `/security-review` run; no open `HIGH` or `MED` findings
- [ ] No secrets, paid services or LLM calls added to CI; actions stay pinned to a commit SHA

## Test plan

<!-- How you verified it. For a skill or agent change, what you ran in a `claude --plugin-dir .` session. -->

- [ ]

## Checklist

- [ ] CI is green (`validate`, `shellcheck`, `installer`, `links`)
- [ ] `claude plugin validate .` passes
- [ ] Docs updated per the table in `CLAUDE.md` (README, CHANGELOG `[Unreleased]`, and so on)
- [ ] Skill or agent change: tried in a session with `claude --plugin-dir .`
