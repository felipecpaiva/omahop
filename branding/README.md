# omahop branding

Three logo concepts in omagnet's visual family (second round, 2026-11-06; the first round was orange and unrelated to omagnet, and was dropped) so one can be chosen. Read [BRIEF.md](BRIEF.md) first: it says what the brand must say and what must not be copied.

| Folder | Idea |
|--------|------|
| `explorations/v1-stackhop/` | A cascade of window outlines, the front one in violet hopping out with the three motion ticks. |
| `explorations/v2-tilehop/` | Two tiles and a leaping arc between them, with the motion ticks. |
| `explorations/v3-ohop/` | The letter o as a ring with a violet window hopping over it. |

Each folder has `icon.svg` (the vector master), `icon-mono.svg`, `icon-512.png`, `icon-16.png`, `concept.png` and `notes.md`.
Concepts and first vectors come from an image model (Codex with its image tool), one task per direction, from the brief; the vectors are cleaned by hand where needed.
Once one concept is chosen, the full kit is built from it (icon set, wordmark, lockups, social cards, README banner, brand sheet), as for omagnet.

Licence: the artwork is made for this project and is released with it under the MIT licence unless the maintainer chooses a different licence for the brand.
omahop is not affiliated with or endorsed by Omarchy.

## Feature GIFs

`demo/` holds the captioned GIFs and MP4s for the README and the releases (switch, cards, search, settings), made by `tools/demo.py` on a spare workspace with real key and mouse events and demo windows with public content only. `tools/highlight.py` makes the still pictures in `highlights/`.

## Chosen shape and colour variations (round three)

Felipe picked `v2-tilehop` (two tiles and a leaping arc) and asked for a colour scheme different from omagnet's, in three variations. `tools/recolor.py` makes them from the concept's SVGs: the same shapes with a new palette, contrast checked (all pairs pass), each with its icon, glyphs, stencil, PNG exports and notes.

| Folder | Palette |
|---|---|
| `explorations/v2-tilehop-tide/` | Blue: ground `#0f1b24`, main `#e4f4fb`, accent `#38bdf8` |
| `explorations/v2-tilehop-coral/` | Rose red: ground `#1c1316`, main `#ffe8ec`, accent `#ff6b81` |
| `explorations/v2-tilehop-citrus/` | Golden yellow: ground `#1a1812`, main `#fff5d6`, accent `#ffc83d` |

Compare them on `board-v2-tilehop.png` (`python3 tools/board.py v2-tilehop-`). Once one is chosen, the full kit is built from it.

## Chosen: v2-tilehop in Citrus (full kit built)

Felipe chose the yellow variation. `tools/kit.py` builds the whole kit from one palette: `logo/` (icon, `icon-small` without ticks for 48 px and below, glyphs for dark and light, stencils, PNG sizes, favicon, wordmark and lockups), `social/` (GitHub social preview, cards, banners, avatar), the marketplace `preview.png` at the repo root, and `brand-sheet.png` (palette with computed contrast, type, spacing, do and do not).
The wordmark is vector strokes with the letters of the name only (o m a h p), the first `o` in citrus. Palette: ground `#1a1812`, cream `#fff5d6`, citrus `#ffc83d`, ticks `#7c7560`; on light backgrounds ink `#1a1812`, citrus deep `#9a6b00`.
To do by hand (needs the GitHub web page): upload `social/github-social-preview.png` as the repository's social preview.
