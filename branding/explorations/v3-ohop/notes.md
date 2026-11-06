# v3-ohop

The name as a picture: a continuous round o stands for the oma prefix, while a single rounded window hops above and to its right. No text is drawn.

Shared family construction: the ring has a 64-unit stroke, matching omagnet's finished ring arms. The graphite tile has radius 96 on a 512-unit canvas, or 18.75 percent, following the finished brand sheet. The violet window is an 88-unit square with radius 16. The three grey ticks copy omagnet's finished glyph: 18-by-18 diagonal strokes, width 9, round caps, and vertical pitch 19. Their placement keeps them clear of both shapes.

The exact palette, smooth chunky geometry, rounded tile, one moved violet element and three ticks make it a sibling. The idea differs: a single uninterrupted circular o with a detached whole window, rather than four snapping quarters. It is not a square ring.

## Palette

- Graphite tile and light-background ink: #16181d
- White-lilac ring: #e8e6ff
- Electric violet window: #8b7bff
- Mid-grey ticks on dark: #6b7080
- Deep violet window on light: #6a5af0
- Grey ticks on light: #5b5f6e
- One-colour stencil: #000000 on transparent

The light tick colour follows the requested palette and finished brand sheet. The older sibling glyph-light.svg uses a different grey.

## At 16 px

Inspected icon-16.png at native size. The open o and detached window remain distinct, with a ring stroke about two pixels wide and a window just under three pixels wide. The three grey ticks become a faint diagonal cluster and cannot reliably be counted. The ring and window carry the identity without the decoration. The black stencil retains the open counter and detached window in one colour; its tiny ticks also lose definition.

## Production

The four SVG masters are hand-written simple geometry with flat colours, no filters, gradients, text or bitmaps. Transparent glyphs share the icon's coordinates. Icon PNGs are exported from icon.svg with rsvg-convert at 512 and 16 pixels. All four SVGs were parsed and rendered successfully.

Built-in image generation produced codex-first.png, preserved unchanged. Its shading and checkerboard corners are generation defects. concept.png is the second image-tool render, normalized to 1024 pixels. Its corners are transparent, but the generator retained subtle shading despite the flat-colour instruction, so the raster concept is not an exact flat-palette master. The SVG master is the exact palette and geometry authority.

Final image prompt: faithfully render the supplied icon at 1024x1024, preserving the continuous lilac circle, detached violet rounded window, three grey round-capped ticks, and rounded graphite tile, using the exact family palette and transparent outer corners. No text, shading, gradients, textures, shadows or glow.

Artwork follows the project's MIT licence.
