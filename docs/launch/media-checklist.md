# Media checklist: what goes where

| Place | File | Size | Notes |
|---|---|---|---|
| GitHub social preview | `branding/social/github-social-preview.png` | 1280x640 | Manual upload in repo settings |
| README header | `branding/social/banner-dark.png`, `banner-light.png` | 1600x400 | In the README with a light/dark `<picture>` |
| README demos | `branding/demo/*.gif` (switch, cards, search, settings, pointer, peek, quick, sameapp, hints) | 960 wide, under 1 MB each | In the README under "See it" |
| Marketplace card | `preview.png` (repo root) | 1280x640 | Lockup, tagline and the settings window |
| Release pages | the GIFs and stills named in `docs/releases/vX.Y.Z.md` | | Linked by raw URL on `main` |
| Release stills | `branding/highlights/` | | Made by `branding/tools/highlight.py` or the `DEMO_TAG` stills of `demo.py` |
| LinkedIn post image | `branding/social/card-linkedin.png` | 1200x627 | Or attach an MP4 from `branding/demo/` |
| X, Bluesky, Mastodon | `branding/social/card-x.png` | 1600x900 | Or a GIF |
| Square (Slack, Discord) | `branding/social/card-square.png` | 1080x1080 | |
| Wide card, light | `branding/social/card-wide-light.png` | 1200x630 | For light pages |
| Avatar | `branding/social/avatar-400.png` | 400x400 | |
| Favicon, app icon | `branding/logo/favicon.ico`, `icon-*.png`, `icon-small.svg` | 16 to 1024 | |
| Brand sheet | `branding/brand-sheet.png` | 1600x2150 | Palette with contrast, type, do and do not |

Rebuild: `python3 branding/tools/kit.py` (logo, wordmark, social, preview, sheet) and `python3 branding/tools/demo.py [scene ...]` (GIFs, needs a live session and about 2 minutes with hands off). Look at a contact sheet of every GIF and still before committing: only demo windows with public content may appear.
Posting anywhere is Felipe's call; drafts would go in this folder.
