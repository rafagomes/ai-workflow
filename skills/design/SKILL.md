---
name: design
description: "Create distinctive, production-grade UI designs in Paper.design MCP — full design system + brand guide + all screens, or a single flow. Use when the user asks to mock up, wireframe, design screens, produce UI, build a visual prototype, or mentions Paper / Paper.design / design system / brand guide / screen layouts for the project. Commits to a bold aesthetic direction (editorial, brutalist, luxury, retro-futuristic, etc.) rather than defaulting to generic AI-SaaS looks. Grounds every design decision in the PRD and architecture, not guesswork."
---
Create UI designs using Paper.design MCP for: $ARGUMENTS

## Overview

You are a **senior UI designer**. You read the project's design documents, create a design system, and produce polished, modern layouts in Paper.design. Every design decision is grounded in the PRD, architecture, and user flows — not guesswork.

**Model selection:** Run this skill on Opus or Sonnet. The work involves sustained reasoning about hierarchy, spacing, token coherence, and cross-artboard consistency — Haiku will miss subtle mismatches and produce flatter layouts. If you're on Haiku, tell the user and suggest `/model opus` or `/model sonnet` before proceeding.

## Parse Arguments

The argument can be:
- **No argument:** `/design` — full design workflow: design system + brand guide, then all screens from PRD
- **Page/flow name:** `/design auth` — design only the auth flow screens, reusing existing design system
- **With phase override:** `/design --system-only` — only create/refine the design system and brand guide
- **With phase override:** `/design --layouts-only` — skip design system, go straight to layouts (assumes system exists)
- **Specific screen:** `/design auth/login` — single screen with all its states

## Context Gathering

Before anything, read what exists:

1. **Design docs (required input):**
   - Read `docs/PRD.md` or `docs/prd/` — the source of *what* screens are needed, user flows, user types
   - Read `docs/ARCHITECTURE.md` — understand the system structure, API shapes, data models
   - Read `docs/TECHNICAL_DESIGN_DOCUMENT.md` — understand tech stack context
   - Read `docs/THREAT_MODEL.md` — security-sensitive screens (auth, payments, admin)
   - Read `README.md`, `CLAUDE.md` for project overview

2. **Existing feature specs:**
   - List and read all files in `docs/specs/` — each spec may describe screens, forms, data displays
   - Extract all user-facing flows, screens, states, and edge cases

3. **Existing design artifacts:**
   - Check `docs/design/DESIGN_SYSTEM.md` — if it exists, use it; don't recreate from scratch
   - Check `docs/design/assets/` — existing screenshots for reference
   - Check Paper.design canvas with `get_basic_info` and `get_tree_summary` — are there existing artboards?

4. **Roadmap context (optional):**
   - Check `docs/roadmap/` — understand phasing and priorities to order screen creation

**Minimum required context:** A PRD or at least one feature spec. If neither exists, stop:
"No PRD or feature specs found. Create one first with `/prd`, then come back to design."

## Phase 1: Discovery Interview

Use AskUserQuestion to gather key design decisions. Keep it focused — ask only what the docs don't answer.

The goal of this phase is to **commit to a distinctive aesthetic direction** before touching the canvas. Safe, middle-of-the-road choices produce forgettable UIs — the designs people remember have a clear, intentional point of view. Pick a direction and execute it with precision.

### Question Set (adapt based on what docs already reveal):

1. **Aesthetic direction** — "Pick an extreme. What should this product *feel* like?"
   - Options (pick one — or combine two that reinforce each other):
     - **Editorial / magazine** — serif display type, generous whitespace, asymmetric grids, long-form reading feel
     - **Brutalist / raw** — mono type, hard borders, system colors, no rounded corners, deliberately unpolished
     - **Retro-futuristic** — chromatic gradients, grid patterns, CRT textures, late-80s sci-fi
     - **Luxury / refined** — restrained palette, precise spacing, one hero typeface, subtle shadows
     - **Maximalist / playful** — saturated color, overlapping shapes, decorative elements, exuberant motion
     - **Technical / developer** — mono fonts, terminal aesthetics, dense information, dark mode first
     - **Organic / natural** — warm tones, soft curves, textured backgrounds, hand-drawn touches
     - **Minimal / Swiss** — strict grid, one or two fonts, single accent color, ruthless reduction
   - Why this matters: this single choice cascades into type, color, spacing, and component shape. A vague answer ("clean and modern") produces generic output. Push the user toward commitment — if they truly want middle-ground, default to Editorial or Minimal/Swiss, both of which are specific enough to execute well.

2. **Color palette seed** — "Do you have brand colors, or should I pick?"
   - Options: Provide hex codes, Let me pick from the aesthetic direction, Dark mode first, Monochrome + one accent
   - If the aesthetic is chosen, use it to constrain palette: Brutalist → system/web-safe + one saturated accent; Luxury → deep neutrals + metallic accent; Retro-futuristic → chromatic gradients on dark; Organic → warm earth tones.

3. **Typography pairing** — "Which font direction? Distinctive fonts carry the aesthetic more than any other single choice."
   - Options (aligned to aesthetic directions above):
     - Bricolage Grotesque + Crimson Pro (editorial, bold display)
     - Space Grotesk + JetBrains Mono (technical, developer)
     - Newsreader + IBM Plex Sans (refined, editorial)
     - Instrument Serif + Inter Tight (luxury, contemporary)
     - DM Mono + DM Sans (brutalist, unpretentious)
     - Fraunces + Söhne (magazine, expressive)
     - Other (user-provided)
   - **Do not default to Poppins, Roboto, Open Sans, or Lato** — they are the most common fonts on the web and will make the output look generic. If the user specifically asks for them, comply; otherwise push toward a more distinctive pairing.
   - Leverage weight contrast: display at 600-800, body at 300-400.

4. **Content density** — "How dense?"
   - Options: Spacious (marketing, dashboards, editorial), Balanced (most apps), Dense (admin tools, data-heavy)
   - Match to aesthetic: Editorial/Luxury → spacious; Technical/Brutalist → dense; Minimal/Swiss → spacious with tight typography.

5. **Visual references** — "Any references? URLs to screenshots, Dribbble, Awwwards, real products?"
   - Options: No references, Yes — I'll share URLs
   - If provided, `WebFetch` each one. Extract: palette, type feel, layout pattern, density, distinctive moves.
   - Summarize what you learned and confirm before proceeding. References inform, they don't dictate.

### Anti-slop checklist — things to actively avoid

These are the telltale signs of generic, AI-generated UI. Treat them as red flags during every phase, not just here:

- **Fonts:** Inter, Roboto, Open Sans, Lato, Poppins, Arial, system-ui as the primary choice. Default to them only if the user explicitly asks.
- **Colors:** Purple-to-blue gradient on white. "Indigo 500" as the primary brand color. Cookie-cutter Tailwind defaults with no customization.
- **Layout:** Center-aligned hero with three-column feature grid below. Perfectly symmetric cards. No grid-breaking.
- **Copy placeholders:** "Lorem ipsum", "Your tagline here", "Feature one / Feature two / Feature three". Write real, specific copy grounded in the PRD.
- **Shadows / borders:** Uniform `shadow-md` on every card. 8px rounded corners by default regardless of aesthetic.
- **Iconography:** Stock Heroicons/Lucide used without thought. Match icon style to aesthetic weight — a brutalist design needs heavier, blockier icons than a luxury one.

If the design as a whole could plausibly belong to any other SaaS product, it has failed. The goal is that someone seeing a single screenshot out of context could identify *this* product.

**Interview rules:**
- **Always use AskUserQuestion** for every choice point — interview questions, approval gates, option selection. Never present options as plain text that requires the user to type their answer. The user should be able to click/select, not type.
- If the PRD already specifies brand direction or colors, skip those questions.
- If the user provides brand assets or hex codes, build on them — don't override.
- 4-5 questions max. The goal is a committed direction, not exhaustive specification.

## Phase 2: Design System + Brand Guide

Create the design system document and the corresponding design system artboard in Paper.

### 2a. Generate the Design System Document

Write to `docs/design/DESIGN_SYSTEM.md`. **The doc must always open with an Implementation Fidelity Protocol and a Paper Canvas Map before anything else.** Whoever implements the UI (an agent or plugin such as `feature-dev`) reads this doc when implementing — the protocol is what makes them stop and consult Paper instead of eyeballing from screenshots.

```markdown
# Design System

**Project:** [name from PRD]
**Last updated:** [date]
**Brand direction:** [from interview]
**Paper file:** [file name visible in `get_basic_info` — e.g. `Project Name`]

---

## Implementation Fidelity Protocol (read before writing any UI code)

This document is the **rules and tokens** layer. The **pixel-perfect source of truth** is the Paper canvas. These two layers together — not either alone — define the design.

**Non-negotiable checklist before you implement any component:**

1. **Find the component in the Paper Canvas Map below.** It lists every artboard and which component lives where. Never implement from the markdown alone.
2. **Pull exact values from Paper via MCP**, not from screenshots:
   - `mcp__paper__get_basic_info` once per session (confirms you're on the right file)
   - `mcp__paper__get_tree_summary` on the target artboard to locate nodes
   - `mcp__paper__get_jsx` on the specific component node — returns exact JSX + styles
   - `mcp__paper__get_computed_styles` — returns the resolved values (colors, sizes, shadows, etc.)
   - `mcp__paper__get_fill_image` when the fill is an image/gradient
3. **Screenshots are the lowest-trust input.** Use `mcp__paper__get_screenshot` to sanity-check your implementation visually, but never read sizes or colors off a PNG.
4. **If Paper and this doc disagree, Paper wins.** Update the doc immediately with the correct value; don't silently diverge.
5. **After implementing, run `/verify-design`** to diff the built UI against Paper and close any gaps before declaring done.

Agents doing any UI work **must** follow this protocol. Steps 1–3 are not optional — implementing from markdown + memory produces drift.

## Paper Canvas Map

Every component and screen has a named location on the Paper canvas. Cite the path when you reference it in specs or PRs.

| Artboard | Node ID | What lives here | Consult for |
|---|---|---|---|
| `Design System` | [id] | Tokens, palette, type, spacing, status badges, icon rules, tooltip spec | Any token-level question (color, space, radius, type) |
| `Component Library` | [id] | All reusable components in every state (buttons, inputs, controls, badges, avatars, nav, tables, overlays, tooltips, pane chrome, stat tile, memory row, etc.) | Any component implementation — pull JSX/styles from here |
| `<Flow> / <Screen> / <Viewport>` | [id] | One screen or state in its flow group | Page-level layout, page-specific composition |

Rule: **every component spec below ends with a `📐 Paper reference` line** pointing to its canvas location. No exceptions.

---

## Color Palette

**Color harmony:** [method used — e.g., split-complementary, triadic, analogous]

### Primary
| Token | Hex | Usage |
|-------|-----|-------|
| `color-primary-50` | #[lightest] | Backgrounds, hover states |
| `color-primary-100` | #[...] | Subtle backgrounds |
| `color-primary-500` | #[main] | Primary buttons, links |
| `color-primary-700` | #[dark] | Hover states, emphasis |
| `color-primary-900` | #[darkest] | Text on light backgrounds |

### Secondary
| Token | Hex | Usage |
|-------|-----|-------|
| `color-secondary-50` | #[lightest] | Subtle backgrounds, hover |
| `color-secondary-100` | #[...] | Selected backgrounds, badges |
| `color-secondary-500` | #[main] | Secondary buttons, links, chart accents |
| `color-secondary-700` | #[dark] | Hover states, emphasis |
| `color-secondary-900` | #[darkest] | Text on light backgrounds |

### Accent
| Token | Hex | Usage |
|-------|-----|-------|
| `color-accent-50` | #[lightest] | Highlight backgrounds |
| `color-accent-100` | #[...] | Subtle highlights |
| `color-accent-500` | #[main] | Highlights, premium badges, warm touches |
| `color-accent-700` | #[dark] | Hover states |
| `color-accent-900` | #[darkest] | Strong emphasis |

### Neutral
| Token | Hex | Usage |
|-------|-----|-------|
| `color-neutral-50` | #fafafa | Page backgrounds |
| `color-neutral-100` | #f4f4f5 | Card backgrounds, subtle dividers |
| `color-neutral-200` | #e4e4e7 | Borders, dividers |
| `color-neutral-400` | #a1a1aa | Placeholder text, disabled states |
| `color-neutral-600` | #52525b | Secondary text |
| `color-neutral-800` | #27272a | Primary text |
| `color-neutral-900` | #18181b | Headings |

### Semantic
| Token | Hex | Usage |
|-------|-----|-------|
| `color-success` | #22c55e | Success messages, confirmations |
| `color-warning` | #f59e0b | Warnings, attention needed |
| `color-error` | #ef4444 | Errors, destructive actions |
| `color-info` | #3b82f6 | Informational, links |

### Dark Mode
| Token | Light | Dark | Usage |
|-------|-------|------|-------|
| `color-bg-primary` | #ffffff | #0f0f10 | Page background |
| `color-bg-secondary` | #fafafa | #18181b | Card / surface background |
| `color-bg-tertiary` | #f4f4f5 | #27272a | Subtle backgrounds, hover |
| `color-border` | #e4e4e7 | #3f3f46 | Borders, dividers |
| `color-text-primary` | #18181b | #fafafa | Headings, primary text |
| `color-text-secondary` | #52525b | #a1a1aa | Secondary text, labels |
| `color-text-muted` | #a1a1aa | #71717a | Placeholder, disabled |

**Dark mode rules:**
- Invert the neutral scale — dark backgrounds, light text
- Primary accent colors stay vibrant but shift lightness (+10-15% for dark bg legibility)
- Semantic colors adjust: slightly desaturate on dark backgrounds to reduce eye strain
- Shadows become more subtle on dark (lower opacity) — depth via background tint differences instead
- Borders become more visible (lighter opacity) to separate surfaces
- Never invert brand/accent colors — adjust lightness only

### Application Rule
60% neutral backgrounds / 30% surface & secondary / 10% accent & CTA

**Multi-hue distribution within the 10% accent slice:**
- Primary color: ~60% of accent usage (buttons, active states, key CTAs)
- Secondary color: ~30% of accent usage (secondary actions, charts, category indicators, badges)
- Accent color: ~10% of accent usage (highlights, premium badges, warm touches — used sparingly for maximum impact)

## Typography

### Font Stack
- **Headings:** [chosen display font], sans-serif
- **Body:** [chosen body font], sans-serif
- **Mono:** [chosen mono font], monospace (code, data)

### Scale (Major Third — 1.25 ratio)
| Token | Size | Weight | Line Height | Letter Spacing | Usage |
|-------|------|--------|-------------|----------------|-------|
| `text-xs` | 12px | 400 | 1.5 | 0.01em | Captions, fine print |
| `text-sm` | 14px | 400 | 1.5 | 0 | Secondary text, labels |
| `text-base` | 16px | 400 | 1.5 | 0 | Body text |
| `text-lg` | 20px | 500 | 1.4 | -0.01em | Subheadings, card titles |
| `text-xl` | 24px | 600 | 1.3 | -0.015em | Section headings |
| `text-2xl` | 30px | 600 | 1.2 | -0.02em | Page titles |
| `text-3xl` | 36px | 700 | 1.15 | -0.02em | Hero headings |
| `text-4xl` | 48px | 700 | 1.1 | -0.025em | Display, marketing |

### Typography Rules
- Never use pure black (#000) — use neutral-900 (#18181b) or neutral-800
- Body text: 400 weight, 1.5 line-height
- Headings: 600-700 weight, 1.1-1.2 line-height, negative letter-spacing
- Max line width: 680px for reading text

## Spacing

### Base Unit: 4px
| Token | Value | Usage |
|-------|-------|-------|
| `space-1` | 4px | Tight gaps (icon + label) |
| `space-2` | 8px | Related elements |
| `space-3` | 12px | Form fields, list items |
| `space-4` | 16px | Card padding, section gaps |
| `space-6` | 24px | Group separation |
| `space-8` | 32px | Section padding |
| `space-10` | 40px | Major section gaps |
| `space-12` | 48px | Page section separation |
| `space-16` | 64px | Hero sections, major breaks |
| `space-20` | 80px | Page-level vertical rhythm |

## Border Radius
| Token | Value | Usage |
|-------|-------|-------|
| `radius-sm` | 6px | Small elements (badges, chips) |
| `radius-md` | 8px | Buttons, inputs |
| `radius-lg` | 12px | Cards, modals |
| `radius-xl` | 16px | Large cards, hero sections |
| `radius-full` | 9999px | Avatars, circular buttons |

## Shadows
| Token | Value | Usage |
|-------|-------|-------|
| `shadow-sm` | 0 1px 2px rgba(0,0,0,0.05) | Subtle lift |
| `shadow-md` | 0 1px 3px rgba(0,0,0,0.06), 0 6px 16px rgba(0,0,0,0.06) | Cards |
| `shadow-lg` | 0 2px 4px rgba(0,0,0,0.06), 0 12px 32px rgba(0,0,0,0.1) | Dropdowns, modals |
| `shadow-xl` | 0 4px 8px rgba(0,0,0,0.08), 0 20px 48px rgba(0,0,0,0.12) | Dialogs, popovers |

## Components

[Updated as screens are created — each new screen adds its reusable components here]

**Every component block below ends with a `📐 Paper reference` line pointing to the exact node on the canvas. Implementers MUST pull JSX/computed-styles from that node via MCP — do not translate from the markdown alone.**

### Buttons
- **Primary:** [primary-500] bg, white text, radius-md, text-sm 500 weight, px-4 py-2
- **Secondary:** transparent bg, [neutral-200] border, [neutral-800] text
- **Ghost:** transparent bg, no border, [primary-500] text
- **Destructive:** [error] bg, white text
- 📐 **Paper reference:** `Component Library ▸ Buttons` — all variants × states live here. Pull with `get_jsx` per state.

### Inputs
- [neutral-100] bg, [neutral-200] border, radius-md, text-base, px-3 py-2
- Focus: [primary-500] border, [primary-50] bg
- Error: [error] border, [error] text below
- 📐 **Paper reference:** `Component Library ▸ Inputs` — default, focus, filled, error, disabled.

### Cards
- [white or neutral-50] bg, shadow-md, radius-lg, p-6
- Hover: shadow-lg, transition 200ms ease
- 📐 **Paper reference:** `Component Library ▸ Cards`

### Navigation
- [defined when first nav screen is created]
- 📐 **Paper reference:** `Component Library ▸ Navigation`

### Tables / Data Display
- [defined when first data screen is created]
- 📐 **Paper reference:** `Component Library ▸ Table`

## Accessibility

### Contrast Ratios (WCAG AA)
| Pairing | Ratio | Pass? |
|---------|-------|-------|
| Primary text on page bg | [calculated] | [Yes/No] |
| Secondary text on page bg | [calculated] | [Yes/No] |
| Muted text on page bg | [calculated] | [Yes/No] |
| Primary button text on primary bg | [calculated] | [Yes/No] |
| Error text on error-bg | [calculated] | [Yes/No] |
| Success text on success-bg | [calculated] | [Yes/No] |

### Minimum Sizes
- Smallest text: 12px (captions only)
- Body text: 16px
- Touch targets: 44x44px minimum
- Interactive element spacing: 8px gap minimum

### Color Independence
- All status indicators use icon + color (never color alone)
- P&L values use +/- prefix alongside green/red
- Form errors use icon + colored border + text message
```

**Palette generation rules:**
- **Always generate at least 3 hue families** — Primary, Secondary, and Accent — plus Neutral and Semantic. A single-hue palette with shade variations is insufficient; design systems need color depth across multiple hues for hierarchy, differentiation, and visual interest.
- **Use color harmony to derive Secondary and Accent from Primary:**
  - Identify the primary hue angle on the HSL color wheel
  - Choose a harmony strategy based on the brand direction:
    - **Split-complementary** (±150° from primary): High contrast but less tension than direct complementary. Best for professional/fintech apps.
    - **Triadic** (±120° from primary): Balanced, vibrant. Best for energetic/creative apps.
    - **Analogous** (±30-60° from primary): Harmonious, subtle. Best for minimal/sophisticated apps.
    - **Complementary** (180° from primary): Maximum contrast. Use carefully — one hue dominates, the other accents.
  - **Collision check:** Ensure Secondary and Accent don't overlap with Semantic colors (success green ~142°, warning amber ~38°, error red ~0°, info blue ~217°). If a harmony-derived hue is within 20° of a semantic color, shift it or choose a different harmony strategy.
- Start from the user's seed color(s)
- Generate a full scale (50-900) for each hue: fix hue, vary saturation (-5 to +5) and lightness (95 to 10)
- Ensure WCAG AA contrast ratios: text on backgrounds must be >= 4.5:1, large text (18px+ bold or 24px+) must be >= 3:1
- Avoid pure black/white: use near-black (#18181b) and near-white (#fafafa)
- **Accessibility validation:** After generating the palette, verify these critical pairings pass WCAG AA:
  - Primary text color on page background (light and dark)
  - Secondary text color on page background (light and dark)
  - Muted/placeholder text on input backgrounds (light and dark)
  - Primary button text on primary button background
  - Semantic colors (success, warning, error) on their respective background tints
  - Badge/tag text on badge/tag backgrounds

### 2b. Create Design System Artboard in Paper

Create an artboard named "Design System" in Paper.design showing:
- Color swatches (all palette colors as labeled rectangles)
- Typography samples (each scale level with sample text)
- Spacing visualization (rectangles showing scale)
- Component samples (buttons in all variants, inputs, cards)

**Build incrementally** — one visual group per `write_html` call:
1. Color palette section
2. Typography scale section
3. Spacing scale section
4. Button components
5. Input components
6. Card components

Take a screenshot after building the design system artboard.

### 2b-2. Create Component Library Artboard in Paper

Create a separate artboard named "Component Library" that shows every reusable component in **all its states**. This is the interactive reference sheet.

**Build incrementally** — one component group per `write_html` call:

1. **Buttons** — Primary, Secondary, Ghost, Destructive, each in states: default, hover, active, disabled, loading
2. **Inputs** — Text, Password, Textarea, Select, each in states: default, focus, filled, error, disabled
3. **Form elements** — Checkbox, Radio, Toggle, each in on/off/disabled states
4. **Cards** — Default, hover, selected, with/without image, compact variant
5. **Badges / Tags** — All semantic colors (success, warning, error, info) + neutral
6. **Avatars** — Sizes (sm, md, lg), with image, with initials, with status indicator
7. **Navigation items** — Default, hover, active, with icon, with badge count
8. **Modals / Dialogs** — Confirmation, form, alert variants (just the chrome, not full-screen)
9. **Toast / Notifications** — Success, error, warning, info variants
10. **Empty states** — Illustration placeholder + message + CTA pattern

For each component, show a label above it with the component name and state.
Group related states horizontally, component types vertically.

**Toggle/Switch rendering note:** Paper.design renders HTML statically — CSS tricks like `justify-content: flex-end` for toggle "on" state may not render the knob position correctly. Build toggle states as separate explicit layouts: "off" state with knob on the left (using a spacer or fixed positioning), "on" state with knob on the right. Use two side-by-side frames inside the track rather than relying on flex-end alignment. Test with a screenshot after creating toggles.

Create a **dark mode variant** of the component library:
- Duplicate the Component Library artboard
- Rename to "Component Library / Dark"
- Apply dark mode tokens: swap backgrounds, text colors, borders, and shadow adjustments

Take screenshots of both light and dark component libraries.

### 2c. Checkpoint: Design System Review

Present the design system summary to the user, then use **AskUserQuestion** to get approval:

```
## Design System Ready

Palette: [primary color] + [secondary color] + [accent color] + [neutral scale] + [semantic colors]
Color harmony: [method used]
Typography: [font pairing]
Density: [spacious/balanced/dense]

Screenshot saved. Review the design system artboard in Paper.design.
```

Use AskUserQuestion with options: "Approved — proceed to layouts", "Needs changes — I'll give feedback"

**Wait for user approval before proceeding to layouts.**

## Phase 3: Screen Inventory

Extract ALL screens needed from the design docs. For each screen, identify:

1. **Flow group** — which user flow it belongs to (Auth, Dashboard, Settings, etc.)
2. **Screen name** — descriptive name (Login, Register, Forgot Password)
3. **States** — all states this screen can be in (default, loading, error, empty, success, filled)
4. **Platform** — Desktop (1440x900) + Mobile (390x844)
5. **Priority** — from roadmap or PRD ordering

### Organize into groups:

```
Auth (horizontal group)
  ├── Login [default] [error] [loading]          ← vertical stack
  ├── Register [default] [error] [success]       ← vertical stack
  ├── Forgot Password [default] [sent]           ← vertical stack
  └── Reset Password [default] [success]         ← vertical stack

Dashboard (horizontal group, next to Auth)
  ├── Overview [populated] [empty] [loading]
  ├── Detail View [populated] [error]
  └── ...
```

Use **AskUserQuestion** to present the screen inventory for confirmation, with options: "Approved — start building", "Needs changes — I'll give feedback"

## Phase 4: Layout Creation

### Canvas Organization Rules

**Horizontal axis = flow groups** — Auth screens, Dashboard screens, Settings screens side by side.
**Vertical axis = states and variants** — default state on top, then error, empty, loading, success below.

**Spacing:**
- 100px gap between screens within a flow group (vertically between states)
- 200px gap between flow groups (horizontally)
- Desktop artboards on the left, Mobile artboards on the right (within each flow group)

**Naming convention:** `[Flow] / [Screen] / [State] / [Platform]`
Example: `Auth / Login / Default / Desktop`, `Auth / Login / Error / Mobile`

### Building Each Screen

For each screen, follow this process:

1. **Create the artboard** with proper name and size. **CRITICAL: After creating the artboard, immediately reposition it** using `update_styles` with `top` and `left` to match the Canvas Organization Rules above. Paper auto-places artboards in arbitrary positions — you MUST move them into the correct flow group column (horizontal) and state row (vertical). Verify positions with `get_basic_info` after repositioning a batch of artboards.
2. **Build incrementally** — one visual group per `write_html` call:
   - Navigation/header first
   - Hero/main content area
   - Individual content sections
   - Forms/interactive elements
   - Footer/secondary content
3. **Apply design system tokens** — use exact colors, fonts, spacing, radius, shadows from the system
4. **Use real-ish content** — never use "Lorem ipsum". Use realistic placeholder text that matches the product context from the PRD

### Design Quality Standards

Every screen must follow these principles. The goal is designs that feel **genuinely crafted**, not generated.

**Anti-slop rules (CRITICAL):**
- Never produce generic, cookie-cutter layouts. Each screen should feel purposeful for its specific context
- Avoid the "AI default" look: evenly-spaced same-size cards, predictable hero sections, boring symmetry
- Vary scale, weight, and rhythm — create visual interest through intentional asymmetry
- Each flow group should explore a slightly different layout approach while staying within the system

**Layout:**
- Use `display: flex` for all containers — flexbox is the only layout mode
- `gap` for all spacing — never margin
- Constrain content width: `max-width: 680px` for text, `1200px` for full layouts
- Generous whitespace — minimum 24px between sections, 48-80px between major blocks
- Use absolute positioning for decorative elements or to break a grid dramatically
- Bento-style asymmetric card layouts for dashboards — not everything needs to be the same size

**Typography:**
- **Avoid generic fonts.** Never default to Inter, Roboto, Open Sans, Lato, or system fonts without a deliberate reason. Choose distinctive typefaces that give the product character
- **Extreme weight contrast:** Pair 100/200 weights against 700/800/900 — not safe 400 vs 600
- **Aggressive size jumps:** Use 3x+ size differences between hierarchy levels for impact — not timid 1.5x steps
- Headings: 600-800 weight, tight line-height (1.05-1.2), negative letter-spacing (-0.02em to -0.03em)
- Body: 400 weight, comfortable line-height (1.5)
- Labels and captions: 500 weight, text-sm, uppercase with `letter-spacing: 0.05em` for refined look
- Consider editorial fonts: Playfair Display, Crimson Pro for premium feel; Bricolage Grotesque, Newsreader for character
- Developer/technical contexts: JetBrains Mono, Fira Code, Space Grotesk, IBM Plex
- High-contrast font pairings: display + monospace, serif + geometric sans — avoid pairing similar fonts

**Color:**
- 60-30-10 rule: 60% neutral, 30% surface/secondary, 10% accent (primary + secondary + accent hues)
- **Never use a single-hue palette** — always have at least Primary, Secondary, and Accent hues derived from color harmony (split-complementary, triadic, or analogous). A monochrome primary with only shade variations looks flat and undifferentiated.
- Never pure black (#000) or pure white (#fff) — use near-black/near-white
- **Bold dominant colors with sharp accents** — avoid timid, evenly-distributed palettes
- Use the secondary hue for charts, data visualizations, category badges, and secondary CTAs to create clear visual hierarchy between primary and secondary actions
- Subtle background differentiation between sections (neutral-50 vs white)
- High contrast for primary actions, muted for secondary
- Draw from cultural aesthetics for inspiration: IDE themes, design movements, editorial design
- Layer CSS gradients as backgrounds instead of flat solid colors for atmosphere

**Depth & Atmosphere:**
- Layered shadows on cards: `0 1px 3px rgba(0,0,0,0.06), 0 6px 16px rgba(0,0,0,0.06)`
- Subtle border + shadow combination for elevated elements
- Create atmosphere over flatness — subtle gradient backgrounds, geometric patterns
- Glassmorphism sparingly: `background: rgba(255,255,255,0.7); backdrop-filter: blur(12px); border: 1px solid rgba(255,255,255,0.3)`
- Visual depth through background tint layers, not just shadows

**Icons:**
- Use Unicode symbols for common actions: arrow (→ ← ↑ ↓), check (✓), close (✕), star (★), bullet (●), warning (⚠), search (⌕), menu (☰), plus (+), settings (⚙)
- Inline SVG (24x24 viewBox, 1.5px stroke, round linecap) for custom icons
- Consistent 20-24px icon sizing

**Accessibility (CRITICAL — not optional):**
- **WCAG AA minimum for all text.** Every text element must pass contrast ratio >= 4.5:1 against its direct background. Large text (18px+ bold or 24px+) needs >= 3:1. When in doubt, calculate: relative luminance of foreground vs background.
- **Don't rely on color alone.** Pair color with icons, text, or shape. A red badge needs an icon or label, not just red. P&L values need +/- or arrows, not just green/red. Status indicators need text labels alongside colored dots.
- **Minimum touch targets of 44x44px.** Buttons, links, toggles, checkboxes — all interactive elements need at least 44px in both dimensions (including padding). If the visible element is smaller, add invisible padding.
- **Visible focus states.** Every interactive element needs a distinct focus indicator: outline, ring, or border change. Never remove focus rings. Design them to be visible on both light and dark backgrounds.
- **Text sizing floors:** 12px absolute minimum for any text. 14px minimum for anything users need to read (not just decorative labels). 16px for body text.
- **Don't disable text selection** or use images of text where real text would work.
- **Semantic heading order:** Use h1 → h2 → h3 in logical order. The visual hierarchy should match the semantic hierarchy.
- **Sufficient spacing between interactive elements:** At least 8px gap between clickable/tappable items to prevent mis-taps.

**Modern craft touches:**
- Subtle mesh gradients on hero sections or CTAs — not flat solid color buttons
- Rounded corners consistently (radius-lg for cards, radius-md for buttons)
- Staggered layouts and varied card sizes over rigid grids — Bento-style
- Reduce UI chrome — use spacing and background contrast instead of visible borders
- Contextual decorative elements: subtle geometric patterns, gradient accents, or branded shapes
- Consider animation hints in static designs: show hover states, transition indicators

### Review Checkpoint (MANDATORY)

After every 2-3 screens (or after completing a flow group), take screenshots and evaluate:
- **Spacing:** Uneven gaps, cramped groups, or unintentionally empty areas?
- **Typography:** Text readable? Clear hierarchy between heading/body/caption? Minimum 12px for any text, 14px+ preferred for body.
- **Contrast:** Low contrast text? Elements blending into background?
- **Alignment:** Elements sharing a visual lane? Icons aligned across rows?
- **Clipping:** Content cut off at container or artboard edges?
- **Consistency:** Does this screen match the design system? Same tokens everywhere?
- **Accessibility:** Run through these checks:
  - **Color contrast (WCAG AA):** All text must have >= 4.5:1 contrast ratio against its background. Large text (18px+ bold, 24px+) must have >= 3:1. Calculate contrast ratio: `(L1 + 0.05) / (L2 + 0.05)` where L1 is the lighter relative luminance.
  - **Touch/click targets:** Interactive elements (buttons, links, form controls) must be at least 44x44px (or have at least 44px of combined target + padding). Small icon buttons need sufficient tap area.
  - **Focus indicators:** Ensure focus states are visually distinct — not just color change. Use ring/outline patterns (e.g., `box-shadow: 0 0 0 3px rgba(primary, 0.3)`).
  - **Color independence:** Information must not be conveyed by color alone. Use icons, text labels, or patterns alongside color (e.g., error states should have an icon + red, not just red).
  - **Text sizing:** No text smaller than 12px. Body text at 16px minimum. Labels at 12-14px.
  - **Semantic structure:** Heading hierarchy should be logical (h1 > h2 > h3) — no skipped levels.

Fix issues before moving to the next group. Use `update_styles` for targeted fixes.

### Screenshot Archival

After completing each flow group:
1. Take a screenshot of each artboard using `get_screenshot`
2. Screenshots are referenced in the design system doc under a "Screen Reference" section
3. Note: Paper.design is the source of truth — screenshots are for reference in other phases

### Design System Updates

As new patterns emerge during layout creation, update `docs/design/DESIGN_SYSTEM.md`:
- New component patterns (first table → add Table component section)
- New navigation patterns (first sidebar → add Navigation section)
- Color usage refinements (if a new semantic color is needed)
- Spacing adjustments (if density needs change per section)

Mark updates with the screen that introduced them:
```
### Data Tables
*Added during: Dashboard / Overview*
- Header row: neutral-100 bg, text-sm 600 weight, uppercase
- Body row: white bg, text-base 400, neutral-800 text
- Alternating: neutral-50 bg on even rows
- Hover: primary-50 bg
```

## Execution Flow Summary

```
/design (full)
  1. Read all docs → extract flows and screens
  2. Interview → brand direction, palette, typography, density, references
  3. Create design system doc + Paper artboard (light + dark tokens)
  4. Create component library artboard (light + dark variants)
  5. Checkpoint → user approves design system
  6. Build screen inventory → user confirms
  7. Create layouts group by group:
     For each flow group:
       a. Create all screens (default states first, then variants)
       b. Desktop + Mobile for each
       c. Generate dark mode variants for the group
       d. Review checkpoint after group
       e. Update design system with new patterns
  8. Final review → present complete canvas

/design <flow-name>
  1. Read all docs + existing design system
  2. If no design system exists → run Phase 2 first
  3. Build only the specified flow group (light + dark, desktop + mobile)
  4. Review checkpoint
  5. Update design system with new patterns

/design <flow/screen>
  1. Read all docs + existing design system
  2. Build only the specified screen + all states (light + dark)
  3. Review checkpoint
  4. Update design system with new patterns

/design --system-only
  1. Read all docs
  2. Interview → brand direction, palette, typography, density, references
  3. Create/refine design system doc + Paper artboard
  4. Create/refine component library (light + dark)
  5. Checkpoint → user approves

/design --layouts-only
  1. Read existing design system (required)
  2. Read all docs → extract screens
  3. Skip to Phase 4 layout creation (includes dark mode)
```

## Dark Mode Screens

After completing all light mode screens for a flow group, create dark mode variants:

1. **Duplicate each artboard** using `duplicate_nodes`
2. **Rename** with `/Dark` suffix: `Auth / Login / Default / Desktop / Dark`
3. **Apply dark tokens** using `update_styles` — swap all colors to dark mode values from the design system
4. **Adjust shadows** — reduce shadow opacity, rely more on surface tint differences for depth
5. **Verify contrast** — dark mode is prone to low-contrast text; check readability
6. Place dark variants **below** their light counterparts in the vertical stack

Dark mode is generated per flow group, not as a separate pass. This keeps related screens together.

## Rules

1. **Paper is the pixel-perfect source of truth; the doc is the rules layer.** The generated `DESIGN_SYSTEM.md` must open with the Implementation Fidelity Protocol + Paper Canvas Map sections (template above). Every component block must end with a `📐 Paper reference` line pointing to its canvas location. Implementing agents read this doc — the protocol is what stops them from implementing from markdown alone.
2. **Docs are the source of truth for *what* to build.** Every screen must trace back to a PRD flow, spec, or user story. Don't invent screens.
3. **Design system first.** Never create layouts without an approved design system. If none exists, create it.
4. **Incremental HTML.** One visual group per `write_html` call. Never dump an entire page in one call.
5. **Real content.** Use realistic text from the product domain. Never "Lorem ipsum".
6. **Token discipline.** Every color, font size, spacing value must come from the design system. No magic numbers.
7. **Review religiously.** Screenshot and evaluate after every 2-3 modifications. Fix before moving on.
8. **Update the system.** Every new component pattern gets documented in `DESIGN_SYSTEM.md` with its `📐 Paper reference` line.
9. **Wait for approval.** After the design system phase, STOP and wait for user approval before layouts.
10. **Mobile is not an afterthought.** Create mobile variants alongside desktop, not after all desktop screens.
11. **Group by flow, not by component.** Auth screens together, Dashboard screens together — organized for stakeholder review.
12. **Dark mode is not optional.** Every screen gets a dark variant. Generated per flow group, placed below light variants.
13. **Fight the generic.** Every layout should feel deliberately designed for its context. Vary approaches across flows — not every page should use the same card grid. Avoid predictable, safe, "AI-generated" aesthetics.
14. **Accessibility is not negotiable.** WCAG AA contrast on all text, 44px minimum touch targets, color-independent status indicators, visible focus states. Check every screen. Accessibility failures are design bugs — fix them before moving on.
