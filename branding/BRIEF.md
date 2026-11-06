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
3. **At home on Omarchy.** It looks like it belongs beside Omarchy's own apps and themes, and beside its sister omagnet, without pretending to be official.
4. **Small and precise.** A sharp utility, not a platform.

## Name

`omahop`, written lowercase, one word. The `oma` prefix is Omarchy's habit (omarchy, omagnet, the community's `oma...` plugins) and `hop` is
the move: hop to a window. Say it "oh-ma-hop".

## Family

omagnet's mark is a violet "snap grid" (four rounded quarters, one displaced). omahop is a sibling, not a copy: it should sit well next to
it on a README or a launcher, but it must NOT use violet as its accent, and must not reuse the four-quarters ring. Omarchy's own look uses a
single bright green on a plain ground: do not use that green either. Choose one confident accent of your own (a warm or a cool colour that is
not violet and not green), plus a neutral.

## References, and what not to take from them

| Reference | What to learn from it | What must NOT be copied |
|-----------|----------------------|-------------------------|
| **DockDoor** (macOS window previews and switcher) | Its idea: windows shown as live cards you can jump to. | Its icon and name. |
| **Contexts** (macOS vertical window switcher) | Its idea: a plain vertical list with icon, app and title. | Its icon and name. |
| **Windows and macOS Alt+Tab / Cmd+Tab** | The universal gesture: hold a modifier, tap Tab. A Tab keycap or arrow is a fair, generic symbol. | Any OS logo or the exact built-in switcher visuals. |
| **Omarchy** (the logo and icon in `/usr/share/omarchy`) | Its look: chunky pixel blocks with notched corners, a half-block terminal wordmark, a love of monospace. | Its logo, its green, its exact pixel shapes. |
| **omagnet** (our own sister project) | Family feel: clean, geometric, a single accent, rounded app icon. | Its violet and its ring of four quarters. |

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
| `v1-stackhop/` | A stack of overlapping floating windows (rounded rectangles, cascaded). One window is lifted out of the stack and caught mid-hop, with a short motion arc. The "found one window among many" idea. |
| `v2-keyhop/` | The gesture itself: a Tab keycap (or a key with a tab arrow) with a small hop arc leaping from one tile to the next. The "Alt+Tab" idea, clean and geometric. |
| `v3-pixelhop/` | Terminal-native: a chunky pixel cursor block or small pixel mark hopping across three pixel window tiles, on an exact pixel grid with notched corners, a cousin of Omarchy's look. |

## Deliverables per concept (the chosen one is then taken to a full kit)

`icon.svg` (the vector master), `icon-mono.svg` (one-colour stencil), `icon-512.png` and `icon-16.png` (exports), `concept.png` (a 1024 pixel render
of the idea), and `notes.md` (the idea, the palette, why it differs from the references, how it reads at 16 pixels).
