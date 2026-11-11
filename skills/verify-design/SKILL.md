---
name: verify-design
description: "Compare the running UI with its Paper artboards in a real browser (Playwright, desktop and mobile) and fix the mismatches in the code. Use when the user says 'verify the design', 'does this match Paper', 'check design fidelity', 'the UI drifted from the mock', or after building a page that has a Paper artboard. Edits source files; needs the Paper MCP, Playwright and a runnable dev server. Not for creating designs (use /wf:design) or for a review that must not change code."
argument-hint: "[page | component | path] [notes]"
---
Verify the current UI against its Paper design references for: $ARGUMENTS

In hosts that do not substitute `$ARGUMENTS` (e.g. Codex), it is the text the user wrote after the skill name.

This is a fix-in-place fidelity pass: load the Paper artboards and tokens, drive the running app in a real browser, fix what differs, and re-verify. Fix what you find in the same session; a report of mismatches leaves the user to redo the work you just did. Ask only when a mismatch looks intentional or the fix changes scope.

Tools are named by short name (Paper's `get_basic_info`, Playwright's `browser_navigate`); the MCP prefix depends on how each is installed. Paper preflight: load Paper's guide first (`get_guide`, topic `paper-mcp-instructions`), call `get_font_family_info` before any typographic styling, call `finish_working_on_nodes` if you edit the canvas, and never show raw node IDs to the user. If the Paper MCP is not connected, or the open file is not the project's, stop and say so. Only if the user agrees, fall back to `docs/design/DESIGN_SYSTEM.md` and `docs/design/assets/` screenshots, and mark every finding "doc-derived, not verified in Paper". If the Playwright MCP is not available, stop and suggest installing it; a static comparison cannot catch console errors, clipping or broken interactions.

## Arguments

- none: every page with design references. If that is more than about 5 pages, show the scope table and ask which to start with, or work in roadmap priority order.
- A page or route name (`dashboard`), or a component name or file path (`Hero`).
- Free-form notes (specific bugs, reference screenshots, a page to use as style anchor) are priority work items.

## 1. Locate design references

Find artboards in this order: the roadmap's `Design reference` field and the Canvas Map in `docs/design/DESIGN_SYSTEM.md`; then the `Flow / Screen / State / Platform` artboard names via `find_nodes`; then artboard IDs in specs. Names survive a rebuilt Paper file; IDs go stale.

Build a scope table (page, desktop artboard, mobile artboard, source file). If there is a desktop and a mobile artboard, check both. If there is no design material at all, stop and tell the user to run `/wf:design` first.

## 2. Load tokens and artboards

Read `docs/design/DESIGN_SYSTEM.md` and the project's token sources (global stylesheet, theme config such as `globals.css` or `tailwind.config.*`; find them, do not assume a path). Record palette, type scale, spacing, radii, shadows, and flag hardcoded values that duplicate a token.

From Paper: `get_basic_info` once per session (it gives artboard sizes), `get_screenshot` per artboard in scope, and `get_jsx` / `get_computed_styles` on key nodes. Never read sizes or colours from screenshots.

## 3. Read the source

Read every file the target page touches: page, components, global CSS, UI primitives.

## 4. Check in a real browser

Take the dev server's start command and URL from the project's agent instructions (`CLAUDE.md` or `AGENTS.md`), `package.json` scripts or `Makefile`; if it is not running, start it in the background, and stop any server you started when done. If you cannot tell how to start it, ask. If the page needs authentication, ask once for test credentials or a seed route; do not guess or create accounts.

For each page in scope:

1. `browser_resize` to the desktop artboard's size (default 1440x900), `browser_navigate`, full-page `browser_take_screenshot`.
2. The same at the mobile artboard's size (default 390x844). If a page has an artboard for only one viewport, still load the other to check overflow and clipping, and report that it has no design reference.
3. `browser_console_messages` with `level: "error"`. Any runtime error is HIGH.
4. If the artboard has a `/ Dark` variant and the app supports dark mode, repeat with `browser_emulate_media` `colorScheme: "dark"`.
5. Exercise interactive elements the user flagged (menus, drawers, dialogs, forms): open, screenshot, close by every documented path (button, Esc, backdrop). If motion is in scope, repeat with `reducedMotion: "reduce"`.
6. Compare each browser screenshot with its Paper screenshot: typography, colour, spacing, alignment, overflow and clipping.

Keep the findings list in your working notes; do not write a report file.

| Severity | Examples |
|---|---|
| HIGH | wrong font family or primary colour; missing page section; broken responsive layout; console errors; inoperable controls (menu cannot close); visible overflow or clipping; a loading, empty or error state that Paper shows but the UI lacks |
| MEDIUM | font size off by more than 2 steps; wrong spacing in a primary content area; a token replaced by a hardcoded value |
| LOW | spacing drift of 2px or less; slightly off shadow; minor radius mismatch |

A state that neither Paper nor the UI has: note it, do not invent it. Source of truth, in order: Paper computed values, design doc values, token config, screenshots.

## 5. Fix in place

- Make targeted edits; do not rewrite components unless necessary, and do not bundle unrelated refactors.
- Prefer a token (class or CSS variable) over an ad-hoc value, and replace raw hex, px and font names that should be tokens.
- For interactive bugs, fix the interaction, not only the visual.
- If a fix would change documented behaviour or scope, stop and ask.

## 6. Re-verify

Repeat the browser pass (desktop, mobile, flagged interactions) and confirm the screenshots match Paper and the console is clean. Run the project's lint, typecheck and tests (from the project's agent instructions, `package.json` or the `Makefile`); report each in one line (command, result) and show output only for a failure.

## Report

Final message: pages checked; mismatches fixed (before -> after, with exact values); anything left because it looked intentional; the check results. Leave the changes uncommitted unless asked and suggest `/wf:commit`. This skill edits code, so the changes still go through the normal commit and `/wf:pr` review; it does not replace `wf:reviewer`.
