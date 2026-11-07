# Browser tabs: the file contract as omahop consumes it (schema 1)

The source of truth is `docs/file-contract.md` in the `omahop-tabs` repository (the browser extension and its native messaging helper, private while it is built). This page says what omahop reads, writes and checks, so a change on either side can be checked against it. Design and reasons: [research/tabs-spike.md](research/tabs-spike.md), decision D17 in [decisions.md](decisions.md).

## Folder

Everything lives in `$XDG_RUNTIME_DIR/omahop` (tmpfs, gone at logout). omahop makes it mode 700 at load.

| File | Writer | omahop does |
|---|---|---|
| `tabs.enabled` | omahop | Exists while `browser_tabs` is on (mode 600). Removed when it goes off. The helper writes nothing without it and deletes its own file within about a second. |
| `tabs.ignore` | omahop | `browser_tabs_ignore`, one pattern per line, lower case, mode 600. Written through a temporary file and a rename. |
| `tabs.<hostpid>.json` | helper | Read once per switcher session, at the first typed letter, only while the setting is on. Removed by omahop when the setting goes off. |
| `tabs.<hostpid>.activate` | helper (FIFO) | Written by `tools/omahop-tabs-activate` only, never opened by the Lua glue. Left alone when the setting goes off (the helper owns it). |
| `.tabs.*.tmp` | helper | Never read (the listing only takes `tabs.<digits>.json`, regular files, not links). |

Both omahop writers (`lua/omahop.lua` and `Service.qml`) go through one script, `tools/omahop-tabs-files <dir> on [pattern ...]` and `<dir> off`, which is idempotent.

## Tab file

`{schema, browser, pid, caller, profile, windows: [{id, focused, type, tabs: [{id, active, title, url}]}]}`, checked by `lua/tabs.lua` (`Tabs.parse`):

- `schema` must be `1`, else the file is skipped.
- `browser` a string (the browser's process name, such as `chromium` or `chrome`), at most 256 bytes; `pid` a non-negative integer (the helper's parent, the browser); `caller` a string or absent; `profile` a string, `null` or absent.
- every window: `id` integer, `focused` boolean, `type` string; every tab: `id` integer, `active` boolean, `title` and `url` strings. One wrong type rejects the whole file.
- Unknown fields are ignored.
- Limits: 1 MB per file, 8 files per read (newest first), 200 windows and 2000 tabs per file; a title is cut to 300 bytes on a character boundary and control characters become spaces; only the first 2048 bytes of a url are looked at.
- Stale: skipped when `/proc/<hostpid>` is gone (`hostpid` from the file name) or the file is older than 24 hours.
- Only `type = "normal"` windows get tab rows.

What leaves the parser: for each tab, its title, the url's host (lower case, no user, no port) and path (no query, no fragment). The query string and fragment are never kept. The state file carries only the title and the host, and only while a session is open.

## Matching a browser window to a Hyprland window

`Tabs.match`, following spike section 3: windows are grouped by process (a Hyprland window whose `pid` equals the file's `pid` or the helper's parent pid read from `/proc/<hostpid>/stat`); when no window carries either pid, by class (`chrome` to `google-chrome`, `chromium`, `brave` to `brave-browser`, `msedge` to `microsoft-edge`). Within a group: one window each is an exact match; otherwise the Hyprland title must be the active tab title, alone or followed by ` - ` and the browser name (the suffix seen most often is learned and narrows ties); a window with one candidate left is paired and the rest retried; the browser's focused window goes to the group's most recently used Hyprland window; one left on each side pair up. Still unresolved: the tabs go under the first candidate (no verify and retry yet).

## Ignore patterns

Same rules as the helper: case insensitive against the url host; a plain name hides that host and its subdomains (`bank.example` hides `login.bank.example`, not `notbank.example`); a glob (`*`, `?`, `[...]`, `[!...]`, as Python `fnmatch`) must match the whole host (`*.corp.example` hides `a.corp.example`, not `corp.example`); a tab with no host (`data:`, `file:`, `about:`) is never hidden. Allowed characters: letters, digits, dot, dash and the glob characters; anything else is skipped and logged by name only. omahop applies the list again when it reads (defence in depth).

## Activation

`tools/omahop-tabs-activate <hostpid> <tabId>`, started detached with `hl.exec_cmd`: both arguments must be plain integers of at most 10 digits; the FIFO must exist, be a FIFO and belong to the user; one line `<tabId>\n` is written with a non-blocking open (`dd oflag=nonblock`, so no listener means an immediate ENXIO) under a one second timeout. It prints and logs nothing. omahop writes the request first, then focuses and raises the matched window through Hyprland; neither the helper nor the extension focuses windows.
