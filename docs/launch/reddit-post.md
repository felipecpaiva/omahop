# Reddit post draft

Target: r/omarchy (read the sub rules first; some subs want self-promotion flagged). Attach `docs/releases/media/v1.2.0-linger.gif` or `branding/demo/cards.gif` as the first image.

## Title

I made an Alt+Tab switcher for Omarchy's floating workspaces (omahop)

## Body

I run a lot of floating windows on Omarchy, and Alt+Tab only cycled the current workspace in a way that did not fit that. So I built omahop, a plugin that adds a proper switcher for floating workspaces.

What it does:

- Hold Alt, press Tab, get a list or cards (with window thumbnails) in your Omarchy theme. Let go of Alt to switch. A quick tap flips between your last two windows with no overlay.
- Type to search windows by title or app. Accents are ignored, and fuzzy matching is a setting.
- Mouse works too, plus quick keys: close, minimize, number keys to jump, Alt+backtick for windows of the same app.
- Tiling workspaces keep Omarchy's own Alt+Tab. It only takes over on floating ones.
- Optional extras, all off by default: peek strip, icon packs, browser tab search (needs a small companion extension), audio marker, touchpad swipe trigger, profiles.
- One settings window for everything. It never edits your hyprland.lua; you add one load line yourself, and the README lists exactly what it reads, writes and which keys it takes.

Tested live on a real Hyprland session with a virtual keyboard (not just unit tests). MIT licensed.

Repo: https://github.com/felipecpaiva/omahop

It is a young project. I would like to hear what breaks, which keys clash with your setup, and what you miss from other switchers. Disclosure: I wrote it, and I used an AI coding assistant while building it.

## Notes before posting

- Check the sub rules on self-promotion and AI disclosure, and post from your own account.
- Reply to comments yourself; do not let an assistant post for you.
- No private data in screenshots (titles, tabs, names).
