# Palette generation

Read in Phase 2a, when filling the Color Palette section of the template.

- Generate at least three hue families (Primary, Secondary, Accent) plus Neutral and Semantic. A single hue with shade variations looks flat and gives no way to separate primary from secondary actions.
- Start from the user's seed colours and find the primary hue angle on the HSL wheel. Derive Secondary and Accent by harmony, chosen to suit the brand direction:
  - Analogous (30-60 degrees from primary): harmonious, subtle. Minimal or sophisticated products.
  - Split-complementary (180 +/- 30 degrees): high contrast with less tension than complementary. Professional products.
  - Triadic (120 degrees): balanced and vibrant. Energetic or creative products.
  - Complementary (180 degrees): maximum contrast; let one hue dominate and the other accent.
- Collision check: if a derived hue is within 20 degrees of a semantic hue (success green ~142, warning amber ~38, error red ~0, info blue ~217), shift it or pick another harmony. Report the chosen hex values in the checkpoint so the check is visible.
- Build a 50-900 scale per hue: fix the hue, vary saturation by -5 to +5 and lightness from 95 to 10.
- Neutral and semantic tokens may start from the template values, adjusted to the palette's undertone. The dark-mode table is derived from the palette too; do not copy neutral greys that clash with it.
- Contrast: apply the ratios in `quality-standards.md` (Accessibility). After generating, check these pairings in light and dark: primary text, secondary text, muted text on input backgrounds, primary button text on its background, semantic colours on their tints, badge text on badge backgrounds.
