# v3-pixelhop

A solid terminal cursor hangs above three separated window tiles. Two single-cell steps rise from the left tile toward the cursor, making a quick hop into the middle window. The open row suggests windows available to switch to. The small vocabulary of blocks suits a precise floating-workspace utility.

Palette: amber #FFB547 and charcoal #20242B. The black stencil uses #000000 on transparency for light themes. The companion icon-mono-light.svg uses #FFFFFF on transparency for dark themes. No violet or green is used.

The vector master uses a 16 by 16 grid with 32-unit cells in a 512 by 512 viewBox. Every rectangle starts on a grid boundary and spans a whole number of cells. The app tile has one-cell corner notches. Window outlines use one-cell borders; their inner openings remain transparent in the stencils. The cursor is three cells square. No gradients, filters, text, strokes or bitmaps appear in the SVGs.

DockDoor supplies the general idea of jumping among window previews, but this mark uses abstract pixel outlines rather than its icon or name. Contexts supplies the idea of finding a window quickly, but there is no vertical list or borrowed mark. Omarchy supplies the terminal-native pixel sensibility; the amber, row of three windows and ascending cursor are our own composition. omagnet supplies the clean family feel; this design uses neither its violet nor its four-quarter ring. These references are conceptual comparisons, not a claim of an exhaustive visual similarity audit.

I viewed icon-16.png at its native size. The three hollow tiles, suspended block and two motion pixels remain distinct and crisp. The hop works as an abstract symbol, but the tiles only weakly read as windows at 16 px because their interiors are just one pixel wide. There is no room for additional title-bar detail. The one-colour stencil preserves the same geometry.

concept.png is a 1024 by 1024 concept render from the built-in image generation tool. codex-first.png preserves the first raw result byte for byte. The generated picture has slight tonal variation and looser proportions; the hand-written SVG is the exact-grid production master. Only the concept was resized to the requested dimensions. The icon PNGs were exported from icon.svg with the requested rsvg-convert commands. Both main SVGs rendered successfully, including the stencil at 16 px.

Generation prompt: Create a flat pixel art app icon for omahop on an exact 16 by 16 grid. Use charcoal #20242B and amber #FFB547. Place three hollow window tiles in a bottom row, a solid three-cell cursor above the middle tile, and two isolated ascending motion pixels to its left. Use a pixel-notched square background. Keep it abstract, crisp and grid aligned, with no text, literal objects, green, violet, gradients, shadows or mockup effects.

Artwork made for omahop and released under the project's MIT licence unless the maintainer chooses otherwise.
