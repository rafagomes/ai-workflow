---
name: threat-model
description: "Create or update docs/THREAT_MODEL.md — a STRIDE-style design-level threat model with trust boundaries, attack surface, threats and mitigations. Use when the user asks for a threat model, an attack-surface analysis or a STRIDE pass, or says 'what could go wrong security-wise', 'identify the threats', 'lock this down before launch'. For reviewing a specific diff or branch, use the built-in /security-review instead."
argument-hint: "[focus area]"
---
Create or update the threat model. Argument: $ARGUMENTS (an optional focus area; update only that part and leave the rest)

In hosts that do not substitute `$ARGUMENTS` (e.g. Codex), it is the text the user wrote after the skill name.

## Context Gathering

Before interviewing, understand the system's security surface:

1. **Check for existing docs:**
   - Read `docs/THREAT_MODEL.md` — if revising, don't start from scratch
   - Read `docs/ARCHITECTURE.md` for system structure and trust boundaries
   - Read the project's agent instructions (`CLAUDE.md` or `AGENTS.md`) and `README.md`

2. **Survey the codebase** for auth, input handling, data access (raw SQL vs parameterized), secrets, exposed endpoints and service exposure (`docker-compose.yml`, deployment config).
3. Summarize what you found — "Here's what I see from a security perspective: ..."

## Interview

Use AskUserQuestion, asking only what the code and docs do not answer, in rounds of at most 3-4 questions. Where AskUserQuestion is unavailable but the user can answer in chat (e.g. Codex), ask the same question in chat as a short numbered list and wait for the answer; a headless run or a dispatched agent has no such user, and the headless rule applies instead. If the user cannot be asked (a headless run), write from what exists and list each assumption as an open question.

1. **Trust boundaries** — What is trusted? What is untrusted? Where are the boundaries?
2. **Authentication** — How do users/agents/services prove identity? What mechanisms exist today?
3. **Authorization** — Who can do what? How are permissions modeled?
4. **Sensitive data** — What data is sensitive? Credentials, PII, financial? Where does it live? How is it protected at rest and in transit?
5. **Attack surface** — What is exposed to the internet? To local users? To other services? What inputs does the system accept?
6. **Threat actors** — Who would attack this? Script kiddies, insiders, nation states? What are their capabilities?
7. **Compliance** — Any regulatory requirements? SOC2, GDPR, HIPAA, PCI? (skip if none apply)
8. **Existing security measures** — What's already in place? What's missing?

For inherited projects: "I see you're using X for auth — is that intentional or legacy? I notice Y has no input validation — is that a known gap?"

## Write

Write to `docs/THREAT_MODEL.md`:

```markdown
# Threat Model

**Last updated:** [date]

## Trust Assumptions

[What is the trust model? What is trusted, what is untrusted? Include a Mermaid diagram of the trust hierarchy.]

## Security Properties

[Non-negotiable security invariants. Things that must always hold.]

- [Property 1]
- [Property 2]

## Attack Surface

| Surface | Exposure | Controls |
|---------|----------|----------|
| [surface] | [who can reach it] | [what protects it] |

## Threats

[Walk each trust boundary and data flow through S/T/R/I/D/E (spoofing, tampering, repudiation, information disclosure, denial of service, elevation of privilege); omit categories that do not apply. If a control cannot be confirmed from the code, mark it `unverified`, never `implemented`.]

### [Component or flow]

| # | STRIDE | Attack | Impact | Likelihood | Defense | Status |
|---|--------|--------|--------|------------|---------|--------|
| 1 | [S/T/R/I/D/E] | [attack description] | [what happens] | [Low/Med/High] | [how it's prevented] | [implemented / unverified / missing] |

## Sensitive Data Inventory

| Data | Classification | At Rest | In Transit | Access Control |
|------|---------------|---------|------------|----------------|
| [data type] | [level] | [protection] | [protection] | [who can access] |

## Gaps (not yet implemented)

- [Control — what it protects against — priority]

## Compliance Requirements

[Only if applicable. Regulatory frameworks, what they require, current status.]
```

## After Writing

1. Present the document to the user for review. Iterate until they're satisfied.
2. Suggest next steps based on what exists:
   - No architecture doc? → "Define system structure with `/wf:architecture`"
   - Ready to plan the build? → "Run `/wf:roadmap`, then `/wf:spec <task>` per task (or `/wf:spec <name>` directly for one feature outside a roadmap)"
3. Remind the user that security-sensitive PRs still need `/security-review`; this document is its input, not a substitute.
