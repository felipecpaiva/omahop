# Releases

Rule (Felipe, 2026-11-06): every tag ships with a feature highlight. A release is not done until all of this exists.

| Item | Where |
|---|---|
| Release notes, written for users: one-line hook, what is new, what was fixed, how it was checked, known limits, how to update | `docs/releases/vX.Y.Z.md` (this is also the GitHub release body) |
| Highlight media of the headline feature: a screenshot (`.png`) or a short recording (`.gif` plus `.mp4`) made on a real screen, with made-up window names and nothing private | `branding/highlights/vX.Y.Z-<feature>.png` or `.gif` |
| The git tag, annotated | `git tag -a vX.Y.Z -m "..."`, pushed |
| The GitHub release for that tag, with the notes as body and the highlight embedded by its raw URL | `gh release create vX.Y.Z --notes-file docs/releases/vX.Y.Z.md` |
| README status line and the batch log entry | `README.md`, `docs/batch-log.md` |

Order: finish the code and the live run, record the highlight, write the notes, commit and push, tag, push the tag, create the release. Never mention which tool made
anything in the notes. Posting about a release anywhere else (social, forum, marketplace) is Felipe's call, drafts live in `docs/launch/` when we write them.
Media rules: no private content (window titles, hostnames, paths, other apps open), no virtual monitors on a dev machine (use an empty workspace, as for the v0.1.0 picture).
