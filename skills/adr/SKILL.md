---
name: adr
description: "Write an Architecture Decision Record — one numbered file in docs/adr/ with context, options considered and the choice. Use when the user says 'write an ADR', 'record why we picked X', 'document this decision', or has just made a technical choice future contributors will question. Not for whole-system design (use /wf:architecture)."
argument-hint: "[title]"
---
Create an Architecture Decision Record. Argument: $ARGUMENTS

## Context Gathering

1. Find the ADR directory (default `docs/adr/`; use the existing one if the repo has `docs/decisions/` or similar) and take the next number, zero-padded to the existing width, starting at `0001`.
2. Read recent ADRs (last 2-3) to match the project's style and voice.
3. If the decision relates to architecture, read `docs/ARCHITECTURE.md` for context.
4. If this decision replaces an earlier ADR, set the old one's status to `Superseded by ADR-NNNN` and link it in Related.

## Interview

Use AskUserQuestion to extract the decision. Where AskUserQuestion is unavailable (e.g. in Codex), ask the same question in chat as a short numbered list and wait for the answer. Keep it focused — an ADR is one decision, not a design doc. If the decision was just made in this session, draft from the conversation and ask only for what is missing.

1. **What's the decision?** — What are you deciding? What triggered this decision?
2. **Context** — What constraints, requirements, or pressures led to this? What's the current state?
3. **Options considered** — What alternatives did you evaluate? What are the tradeoffs of each?
4. **Decision** — What did you choose and why? What was the deciding factor?
5. **Consequences** — What changes as a result? What are the known downsides you're accepting?

If the decision is straightforward (user already knows what they want and why), keep the interview to 1-2 questions to fill in gaps. If the user is asking you to decide, present the options and a recommendation before writing.

## Write

Write to `docs/adr/NNNN-<slug>.md`:

```markdown
# ADR-NNNN: [Title]

**Status:** Proposed | Accepted | Deprecated | Superseded by [ADR-XXXX]
**Date:** [date]
**Deciders:** [the user plus anyone they name; if unnamed, `git config user.name`]

## Context

[What is the issue? What forces are at play? What constraints exist?]

## Decision

[What was decided. State it clearly in one sentence, then elaborate if needed.]

## Options Considered

### Option A: [Name]
- **Pros:** [benefits]
- **Cons:** [drawbacks]

(Repeat per option, at least two.)

## Consequences

### Positive
- [What improves]

### Negative
- [What gets harder or what risks are accepted]

## Related

- [Links to related ADRs, specs, issues, or documents]
```

## After Writing

Present the ADR for review. Status is `Proposed` unless the user said the decision is made.
