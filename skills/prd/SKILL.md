---
name: prd
description: "Interview the user and write a Product Requirements Document at docs/PRD.md (or docs/prd/<name>.md for a feature) — problem, scope, user types, key flows, success criteria, risks. Use when the user wants to write a PRD, scope a product or feature, capture requirements or success metrics, or says 'what should we build', 'let's scope this', 'write up the requirements'. Run first, before /wf:architecture and /wf:roadmap. Not for implementation detail (/wf:spec)."
argument-hint: "[product or feature name]"
---
Create a Product Requirements Document for: $ARGUMENTS

In hosts that do not substitute `$ARGUMENTS` (e.g. Codex), it is the text the user wrote after the skill name.

## Context Awareness

Before starting, check what already exists:
- Read `docs/` directory structure if it exists
- Read any existing PRD, README, or whitepaper — do not duplicate what's already written
- If `docs/PRD.md` exists, revise it in place and interview only about what is changing; start over only if the user asks. If `$ARGUMENTS` names a feature and a project PRD exists, write `docs/prd/<name>.md`.

## Process

### 1. Deep Interview

Use AskUserQuestion to interview the user. Where AskUserQuestion is unavailable (e.g. in Codex), ask the same question in chat as a short numbered list and wait for the answer. If they gave a brief, a README or a pasted idea, restate it in 3-5 lines and interview only the gaps. Ask at most 3-4 questions per round. If the user cannot be asked (a headless run), write the PRD from what exists and list each guess under Risks and Open Questions.

**Start broad, then go deep:**

1. **The problem** — What problem are you solving? Who has this problem? How are they solving it today? What's broken about the current approach?
2. **The solution** — What's your high-level approach? What makes it different from existing solutions? What's the core insight?
3. **Scope and boundaries** — What does v1 include? What is explicitly out of scope? What are the non-negotiable requirements vs nice-to-haves?
4. **Users and stakeholders** — Who are the primary users? Are there different user types with different needs? Who else cares about this (ops, security, compliance)?
5. **Success criteria** — How do you know this works? What does success look like in 1 month? 6 months?
6. **Constraints** — Technical constraints (language, platform, infra)? Business constraints (timeline, team size, budget)? Regulatory constraints?
7. **Risks** — What could go wrong? What are the biggest unknowns? What keeps you up at night about this?

**Interview rules:**
- Dig into contradictions and tensions — "you said X but also Y, how do those reconcile?"
- Ask about the hard parts the user might not have thought through
- It's OK to push back or challenge assumptions — the goal is a solid PRD, not agreement

### 2. Write the PRD

Write to `docs/PRD.md`, or `docs/prd/<name>.md` for a feature PRD (see Context Awareness).

```markdown
# [Project/Feature Name]

**Last updated:** [date]

## Problem

[What problem does this solve? Who is affected? What's the current state and why is it broken?]

## Solution

[High-level approach. What is this thing? What's the core insight? How does it work at a conceptual level?]

## Design Principles

[Non-negotiable properties of the solution. The "even if everything else changes, these must hold" rules.]

## Scope

### In Scope (v1)
- [Concrete deliverable 1]
- [Concrete deliverable 2]

### Out of Scope
- [Explicit exclusion 1 — and why]
- [Explicit exclusion 2 — and why]

## User Types

### [User Type 1]
- Who they are
- What they need
- How they interact with the system

## Key Flows

[The 2-4 most important user/system flows. Use prose, diagrams (Mermaid), or step-by-step — whatever is clearest.]

## Success Criteria

- [ ] [Measurable criterion 1]
- [ ] [Measurable criterion 2]

## Constraints

- **Technical:** [language, platform, infra, dependencies]
- **Business:** [timeline, team, budget]
- **Regulatory:** [compliance, security, legal]

## Risks and Open Questions

| Risk/Question | Impact | Mitigation/Answer |
|---------------|--------|-------------------|
| [Risk 1] | [What happens if it materializes] | [How to handle it] |

## Future Work

[What comes after v1? What was deferred and why?]
```

Drop sections that don't apply; add one if the domain needs it.

### 3. Present for Review

Show the user the PRD and ask for feedback. Iterate until they're satisfied.

### 4. Suggest Next Steps

Based on the PRD complexity, suggest which specs to create next:
- "This needs an architecture doc (system structure + testing strategy) — run `/wf:architecture`"
- "There are security-sensitive parts — run `/wf:threat-model`"
- "Ready to plan the build — run `/wf:roadmap`, then `/wf:spec <task>` for each task. For one feature outside a roadmap, run `/wf:spec <feature-name>` directly"
