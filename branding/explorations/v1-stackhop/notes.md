# v1-stackhop

omahop finds one window among many and gets you there in one quick hop. Two overlapping window outlines form a compact cascade. A filled window lifts up and right, with a short curved motion trail. The filled shape signals the chosen window. Rounded geometry and a restrained tile suit a small Omarchy utility without claiming official status.

## Palette

- Warm orange: #FF8A3D, the single confident accent.
- Charcoal: #20242B, the neutral tile.
- Black: #000000, the transparent stencil for light backgrounds.
- White: #FFFFFF, the alternate transparent stencil for dark backgrounds.

The main icon uses only two colours. No gradients, filters, text, bitmaps or title-bar details are used in the SVGs. Title-bar hints would add noise at small sizes. The stencil paths have real open spaces rather than background-coloured patches.

## Distinction

DockDoor provides the useful idea of choosing live window cards. This mark uses an abstract cascade and a hopping selection rather than its icon or name. Contexts provides the idea of quick selection from a list; this mark uses spatial overlap rather than a vertical list or its identity. Omarchy contributes the small, precise utility context, but this design uses rounded windows and orange instead of its green, pixel blocks or logo. omagnet is a geometric sibling, but this mark has neither its violet nor its ring of four quarters. No reference brand marks appear in the artwork.

## Small-size check

I inspected icon-16.png at its native size. The filled lifted window and the stacked outlines remain recognizable, so the main selection idea works. The two outlines become a compact interlocked shape, and the arc reads as a small curved dash rather than an unmistakable hop. It is usable at 16 px, but the motion story is clearer at 32 px and above. No title-bar detail is needed.

## Files and verification

icon.svg is the hand-written vector master with a 0 0 512 512 viewBox. icon-mono.svg is black on transparent; icon-mono-light.svg is white on transparent. Both stencils contain only the mark, without a tile. Their geometry matches the colour master. All three SVGs were rendered successfully with rsvg-convert. icon-512.png and icon-16.png were exported directly from icon.svg using the requested commands. The extra stencil PNGs are rendering checks.

concept.png is a 1024 by 1024 concept render from the built-in image generation tool. codex-first.png preserves the first raw output unchanged. The tool returned a larger square image, so concept.png is a Lanczos resize of it. The generated concept has slight tonal variation; the SVG master makes the palette flat and the geometry precise.

## Generation prompt

Built-in image generation was used with this prompt:

> Use case: logo-brand. Create a 1024x1024 flat app icon for omahop, a fast floating-window switcher. No text. A charcoal #20242B rounded-square tile fills the square canvas, with generous rounded corners. Center a simple geometric mark: two overlapping outlined rounded-rectangle windows cascaded down and left in the lower half; one solid warm orange #FF8A3D rounded-rectangle window is lifted above and right, visibly separated from the stack. A short thick orange curved motion arc above the stack suggests the selected window hopping upward. All mark shapes orange, tile charcoal, no other colors except antialiasing. Bold geometry, broad strokes and negative spaces readable at 16 pixels. No title-bar details, no gradients, shadows, glow, texture, lettering, arrows, OS logos, violet, green, or four-quarter rings. Clean straight-on vector-like artwork, one icon only.

## Licence

Created for this project and released with it under the same MIT licence, unless the maintainer chooses otherwise.
