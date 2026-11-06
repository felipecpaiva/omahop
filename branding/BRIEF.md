# omahop brand brief

The brief behind every logo concept. Written 2026-11-06, before any image was made, so the concepts can be judged against it and not
against taste alone. Same method as the sister project omagnet (`omagnet/branding/BRIEF.md`).

## What the project is, in one line

Fast window switching for Omarchy's floating workspaces: hold Alt, press Tab, and a list or a strip of your windows appears in your
Omarchy theme; let go and you are in the window you picked.

## Who it is for

Omarchy and Hyprland users who run floating workspaces and have many windows open, who want to jump to the right one at once, the way
they could on a Mac or Windows. Terminal-comfortable people who like small, sharp tools, read a README before they install, and judge a
project in the few seconds it takes to see its logo and its first screenshot.

## What the brand has to say

1. **Hop.** One quick move and you are in the window you wanted. Speed, not ceremony.
2. **Windows, stacked and found.** The mark can say "many windows, one of them chosen".
3. **At home on Omarchy, and beside omagnet.** It looks like it belongs beside Omarchy's own apps and themes, and is clearly the sibling of omagnet, without pretending to be official.
4. **Small and precise.** A sharp utility, not a platform.

## Name

`omahop`, written lowercase, one word. The `oma` prefix is Omarchy's habit (omarchy, omagnet, the community's `oma...` plugins) and `hop` is
the move: hop to a window. Say it "oh-ma-hop".

## Family: a sibling of omagnet (this is the main rule)

omahop is the second plugin of the same maker, and the two must look like one family on a README, a launcher and a social card. Study omagnet's finished identity before drawing
anything: `~/Work/omagnet/branding/brand-sheet.png`, `branding/explorations/v2-snapgrid/` (`icon.svg`, `notes.md`) and `branding/logo/glyph.svg`. Keep EXACTLY these family traits:

- **Palette:** graphite ground `#16181d`, white-lilac main shape `#e8e6ff`, electric violet accent `#8b7bff` (on light backgrounds: ink `#16181d` and deep violet `#6a5af0`), mid-grey `#6b7080` for the small decoration. Nothing else.
- **The three motion ticks:** three short parallel diagonal strokes (mid-grey, round caps) that show movement. omagnet uses them for "a window clicked into place"; omahop uses them for "a window hopped".
- **Construction:** smooth rounded geometry, one violet element that has just moved, the rest in lilac, on a rounded graphite tile (radius about 19% of the width). Flat colour, no gradients, shadows or glows.
- **Type:** JetBrains Mono for text; the wordmark is lowercase, one word, drawn as geometric monoline strokes, with the first letter `o` in violet, exactly like omagnet's wordmark.

What must differ from omagnet: the IDEA. omagnet is a ring of four rounded quarters snapping into place. omahop must not use a four-quarter ring or a square ring; it is about hopping to one window among many. Same family, a different picture.

## References, and what not to take from them

| Reference | What to learn from it | What must NOT be copied |
|-----------|----------------------|-------------------------|
| **DockDoor** (macOS window previews and switcher) | Its idea: windows shown as live cards you can jump to. | Its icon and name. |
| **Contexts** (macOS vertical window switcher) | Its idea: a plain vertical list with icon, app and title. | Its icon and name. |
| **Windows and macOS Alt+Tab / Cmd+Tab** | The universal gesture: hold a modifier, tap Tab. A Tab keycap or arrow is a fair, generic symbol. | Any OS logo or the exact built-in switcher visuals. |
| **Omarchy** (the logo and icon in `/usr/share/omarchy`) | Its look: chunky pixel blocks with notched corners, a half-block terminal wordmark, a love of monospace. | Its logo, its green, its exact pixel shapes. |
| **omagnet** (our own sister project) | The whole family look: palette, motion ticks, rounded geometry, wordmark style, tile shape (see Family above). | Its idea: the ring of four rounded quarters. |

Other brand names appear only as plain text, never as marks.

## Constraints every concept must meet

- **Works small.** The icon is still readable at 16 pixels and at 32 pixels, in one colour.
- **Works on light and dark.** A one-colour version for each, so it reads on Omarchy's light themes (such as "white") and dark ones (such as "tokyo-night").
- **No gradients needed.** The mark must stand without a gradient, shadow or glow. (A gradient may be added as polish.)
- **Vector first.** A real SVG source for the icon; PNG exports come from it. Simple shapes (rectangles, rounded rectangles, circles, paths), a handful of colours.
- **Own idea.** Different from the references above at a glance, even in a thumbnail.
- **Text rules.** No em-dash or en-dash anywhere in text; plain English.
- **Licence.** The artwork is made for this project and is released with it under the same MIT licence, unless the maintainer chooses otherwise.

## The three concepts to explore

| Folder | Idea |
|--------|------|
| `v1-stackhop/` | A cascade of three rounded window outlines in lilac. The front one, in violet, has just hopped up and to the right out of the stack, with the three grey motion ticks. "Found one window among many." |
| `v2-tilehop/` | Two rounded tiles side by side (the first lilac, the second violet) and a short rounded arc leaping from the first to the second, with the three motion ticks at the start of the arc. The Alt+Tab move, abstract and calm. |
| `v3-ohop/` | The letter `o` (the `oma` prefix and the violet `o` of the wordmark) built as a lilac ring; a small violet rounded square (a window) is caught mid-hop just above it with the three motion ticks. The name as a picture. |

## Deliverables per concept (the chosen one is then taken to a full kit)

`icon.svg` (the vector master on the graphite tile), `glyph.svg` (the mark alone, lilac and violet, for dark backgrounds), `glyph-light.svg` (ink and deep violet, for light backgrounds), `icon-mono.svg` (one-colour stencil), `icon-512.png` and `icon-16.png` (exports), `concept.png` (a 1024 pixel render
of the idea), and `notes.md` (the idea, the palette, why it differs from omagnet and the other references, how it reads at 16 pixels).
