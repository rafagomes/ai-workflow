---
name: design
description: "Design a product's UI in Paper: a design system and brand guide (docs/design/DESIGN_SYSTEM.md plus Paper artboards), then light and dark screens for each flow, grounded in the PRD and specs. Use when the user asks to mock up or design screens, make a design system or brand guide, or mentions Paper / Paper.design. Needs the Paper MCP and a PRD or spec to work from. Commits to a distinctive aesthetic direction instead of a generic SaaS look, and creates the design source that UI work later builds from. Not for implementing UI in code (use /wf:feature, which builds from the design source this skill creates); use /wf:verify-design afterwards to check built UI against it."
argument-hint: "[flow | flow/screen] [--system-only | --layouts-only]"
---
Create UI designs in Paper for: $ARGUMENTS

In hosts that do not substitute `$ARGUMENTS` (e.g. Codex), it is the text the user wrote after the skill name.

You are a senior UI designer. You read the project's docs, create a design system, and produce polished layouts in Paper. Every decision traces to the PRD, specs and user flows rather than guesswork.

Before the first Paper call, read `references/paper-mcp.md` (load Paper's guide, check fonts, finish edits with `finish_working_on_nodes`, never show raw node IDs to the user). If the Paper MCP is not connected, stop and say so.

## Modes

| Argument | Phases |
|---|---|
| none | 1, 2, 3, 4 (design system, then all screens) |
| `<flow>` | Context, then 4 for that flow. If `DESIGN_SYSTEM.md` is missing or the canvas has no "Design System" artboard, run Phases 1-2 first and wait for approval |
| `<flow>/<screen>` | As `<flow>`, for one screen with all its states |
| `--system-only` | 1, 2 |
| `--layouts-only` | Requires an existing, approved system. Run 3, then 4 |

## Context gathering

Read what exists, using the project's own doc locations if they are not under `docs/` (in a monorepo, write `DESIGN_SYSTEM.md` beside the docs you find):

1. `docs/PRD.md` or `docs/prd/` (what screens, flows, user types), `docs/ARCHITECTURE.md` (system shape, data models), `docs/THREAT_MODEL.md` (security-sensitive screens), the README and the project's agent instructions (`CLAUDE.md` or `AGENTS.md`).
2. Every file in `docs/specs/`: screens, forms, data displays, states and edge cases.
3. `docs/design/DESIGN_SYSTEM.md` and `docs/design/assets/`. If the system exists, use it; do not recreate it.
4. The Paper canvas: `get_basic_info` and `get_tree_summary`, plus `find_nodes` to check names before creating anything.
5. `docs/roadmap/`, if present, for phasing and screen order.

Re-runs: if the system or screen artboards already exist, list what is built and continue from the first missing flow or screen. Never duplicate or rebuild an artboard that is already on the canvas.

Minimum input is a PRD or one feature spec. If there is neither, the user may describe the product in the prompt: write a five-line brief at the top of `DESIGN_SYSTEM.md` and proceed. With nothing at all, stop: "No PRD or feature specs found. Create one first with `/wf:prd`, then come back to design."

## Phase 1: Discovery interview

Commit to an aesthetic direction before touching the canvas. Middle-of-the-road choices produce forgettable UIs; a clear point of view is what people remember.

Use AskUserQuestion for each choice, ask only what the docs do not answer, at most 4-5 questions, skipping brand direction or colours the PRD already fixes and building on any brand assets or hex codes the user gives. Where AskUserQuestion is unavailable but the user can answer in chat (e.g. Codex), ask the same question in chat as a short numbered list and wait for the answer; a headless run or a dispatched agent has no such user, and the headless rule applies instead. If no user can answer (a headless run or a dispatched agent) or the run is non-interactive, take the documented default (Editorial or Minimal/Swiss) and record each assumption at the top of `DESIGN_SYSTEM.md`.

1. **Aesthetic direction.** Pick one, or two that reinforce each other: Editorial / magazine (serif display, asymmetric grids); Brutalist / raw (mono, hard borders, no rounding); Retro-futuristic (chromatic gradients, grids, CRT); Luxury / refined (restrained palette, one hero typeface); Maximalist / playful (saturated colour, overlapping shapes); Technical / developer (mono, dense, dark first); Organic / natural (warm tones, soft curves, texture); Minimal / Swiss (strict grid, one accent). This choice cascades into type, colour, spacing and component shape, so push away from "clean and modern". If the user truly wants middle ground, default to Editorial or Minimal/Swiss, which are specific enough to execute well.
2. **Colour seed.** Brand hex codes, or pick from the aesthetic (Brutalist: web-safe plus one saturated accent; Luxury: deep neutrals plus metallic accent; Retro-futuristic: chromatic gradients on dark; Organic: warm earth tones), dark first, or monochrome plus one accent.
3. **Typography.** Distinctive fonts carry the aesthetic more than any other single choice. Offer pairings that fit the direction and exist in Paper (check with `get_font_family_info`), for example Bricolage Grotesque + Crimson Pro (editorial), Space Grotesk + JetBrains Mono (technical), Instrument Serif + Inter Tight (luxury), DM Mono + DM Sans (brutalist), or the user's own. Use weight contrast: display 600-800, body 300-400.
4. **Density.** Spacious (marketing, editorial), balanced (most apps) or dense (admin, data-heavy); match the aesthetic.
5. **Visual references.** URLs or none. `WebFetch` each; extract palette, type feel, layout pattern, density; summarise and confirm. If a reference cannot be read (login wall, image), ask for a screenshot rather than guessing. References inform, they do not dictate.

## Phase 2: Design system and brand guide

### 2a. Design system document

Write `docs/design/DESIGN_SYSTEM.md` from `design-system-template.md` in this skill's directory: read it, fill every bracketed placeholder, keep its section order. The Implementation Fidelity Protocol and Paper Canvas Map come first because `/wf:feature`, `/wf:fix` and `/wf:autopilot` read this file, and the protocol is what makes them consult Paper instead of eyeballing screenshots.

Read `references/palette.md` for palette rules (hue families, harmony, collision check, contrast), and `references/quality-standards.md` for the quality bar.

### 2b. Paper artboards

Create a "Design System" artboard: colour swatches, typography samples for each scale level, and spacing visualisation, one group per `write_html` call. Then create the "Component Library" artboard and its dark variant following `references/component-library.md`. Screenshot each. Afterwards, fill the artboards' node IDs into the Canvas Map table in `DESIGN_SYSTEM.md`.

### 2c. Checkpoint

Summarise the palette (with chosen hex values), harmony method, font pairing and density, and point the user at the artboards in Paper. Use AskUserQuestion: "Approved: proceed to layouts" or "Needs changes: I'll give feedback". Wait for approval before layouts; every screen depends on these tokens, so changes after screens exist are expensive.

## Phase 3: Screen inventory

Extract every screen the docs call for. For each: flow group (Auth, Dashboard, ...), screen name, all states (default, loading, error, empty, success, filled), platforms (Desktop 1440x900, Mobile 390x844) and priority from the roadmap or PRD. Every screen must trace to a PRD flow, spec or user story; do not invent screens.

Show the inventory grouped by flow, for example:

```
Auth
  Login [default] [error] [loading]
  Register [default] [error] [success]
Dashboard
  Overview [populated] [empty] [loading]
```

Confirm with AskUserQuestion: "Approved: start building" or "Needs changes".

## Phase 4: Layouts

Canvas organisation: flow groups run left to right with a 200px gap; states run top to bottom with a 100px gap (default first, then error, empty, loading, success); within a group, Desktop on the left and Mobile on the right. Name artboards `[Flow] / [Screen] / [State] / [Platform]`, for example `Auth / Login / Error / Mobile`.

For each screen:

1. Create the artboard with its name and size, then immediately set its `top` and `left` with `update_styles`. Paper places new artboards wherever there is room, which breaks the flow-by-column layout reviewers read left to right. Check positions with `get_basic_info` after each batch.
2. Build incrementally, one visual group per `write_html` call: navigation, main content, sections, forms, footer.
3. Use only design-system tokens for colour, type, spacing, radius and shadow, and realistic copy from the product domain. Build mobile alongside desktop, not after.
4. Run the review checkpoint in `references/quality-standards.md` after every 2-3 screens or each flow group, and fix before moving on.

In a full run, stop after the first flow group and ask the user to confirm the look before building the rest.

Dark variants are made per flow group, not as a separate pass, so related screens stay together. Duplicate each light artboard with `duplicate_nodes`, rename it with a `/ Dark` suffix, and swap in the dark tokens (prefer Paper tokens over per-node `update_styles`; lighter shadows with depth from surface tint). Check contrast, which dark mode tends to break. Place dark variants below their light counterparts.

After each flow group, save a screenshot of each artboard with `get_screenshot` under `docs/design/assets/` and list it in the "Screen Reference" section of the doc. Paper stays the source of truth; screenshots are for reference.

As new patterns appear (first table, first sidebar, a new semantic colour), add them to `DESIGN_SYSTEM.md`, marked with the screen that introduced them (`*Added during: Dashboard / Overview*`), each ending with a `📐 Paper reference` line.

## Hand-off

Finish by listing the artboards created and the path to `DESIGN_SYSTEM.md`, and say that `/wf:verify-design` is how built UI is checked against them.

## Rules

1. Paper is the pixel-perfect source of truth and the doc is the rules layer. Every component block in the doc ends with a `📐 Paper reference` line pointing to its canvas location, so implementers pull values from Paper instead of translating markdown.
2. Every screen traces to a doc. The design system comes first and is approved before layouts.
3. Every colour, size and spacing value comes from the design system.
4. Every screen gets a dark variant and a mobile variant.
