# v2-keyhop

A Tab keycap hops from a source window tile toward a destination window tile. The short arch and landing arrow convey one quick switch. The filled keycap selects one object above two outlined windows. The rounded square and restrained geometry give omahop a small utility presence beside its siblings.

## Palette

- Orange: #FF8A3D, the single accent.
- Charcoal: #20242B, the neutral tile and negative space.
- Black: #000000, the transparent stencil for light themes.
- White: #FFFFFF, the additional transparent stencil for dark themes.

The colour master uses only orange and charcoal. The stencil files each use one colour. Their arrow and window interiors are actual transparent holes, so they can sit on any theme background.

## Difference from the references

DockDoor contributes the idea of choosing a window, but this mark centres the keyboard gesture rather than a preview interface and does not reproduce its icon or name. Contexts contributes fast selection, but there is no vertical list or copied mark. Omarchy contributes a restrained utility feel, but this is orange, smoothly rounded and not its green or its pixel geometry. omagnet shares the rounded app tile and single accent approach, but this has neither violet nor a four-quarter ring. The generic Tab arrow is not a keyboard brand or OS logo.

## Small-size assessment

I inspected icon-16.png at its actual 16 px size. The orange keycap, two window shapes and curved jump remain visible, but the Tab arrow and its stop bar become cramped and need familiarity to decode. The overall switching silhouette works; the exact Alt+Tab gesture is only partly readable at 16 px. The 512 px master reads clearly. The monochrome variants preserve the same geometry and transparent cutouts.

## Production

The built-in image generation tool made the first concept image. codex-first.png preserves that first raw output unchanged at 1254 x 1254. concept.png is the same generated artwork resized to the requested 1024 x 1024. It has slight generated surface variation. The hand-written SVG master makes the same arrangement flat, precise and limited to two colours. Both required PNG icon exports come directly from icon.svg through rsvg-convert at 512 and 16 px. Both monochrome SVG variants were also rendered with rsvg-convert for verification.

Generation prompt: Create a flat app icon for omahop, a fast Alt+Tab window switching utility. No text or letters. A charcoal #20242B rounded-square background. Two small orange #FF8A3D rounded outline window tiles along the lower portion. Above and partially overlapping the left tile is a larger orange rounded rectangular Tab keycap, with a charcoal right-pointing tab arrow and its vertical stop bar cut into it. A short thick orange hop arc curves from the keycap toward the right window tile and ends in a simple arrow tip. Very simple shapes, generous spacing, bold strokes, flat front view. No gradients, shadows, texture, perspective, OS logos, real keyboard branding, violet or green.

Artwork made for omahop and released under the project's MIT licence unless the maintainer chooses otherwise.
