# Search browser tabs: spike and verdict (2026-11-07)

Question: can omahop search every tab of a browser (not only the active one) and jump to it, through a small browser extension, native messaging and a tiny helper, with no open port and no browser start flag? Plan: `docs/ROADMAP.md`, "Search browser tabs".

**Verdict: GO, conditional on three cheap live checks (section 10).** The hard parts that were open are proven or have a safe design. The remaining risk is mapping a browser window to a Hyprland window when two windows show the same active title, and install friction on branded Chrome.

Evidence labels: **PROVEN** (ran here, see `docs/research/spike-tabs/`), **DOC** (official documentation, link given), **MEMORY** (author knowledge, not re-checked), **UNVERIFIED** (needs the live check named). Machine: Google Chrome 157, Chromium 155, Omarchy on Hyprland, Wayland.

## 0. What the spike proved

`docs/research/spike-tabs/` holds a throwaway extension (`extension/`, MV3, permissions `tabs` and `nativeMessaging`), a 50 line stdlib Python host (`host.py`), a driver (`run.sh`) and a size test (`scale.py`). `bash run.sh` starts headless Chromium with a temporary `--user-data-dir` (no window, the running Chrome is never touched), puts the host manifest inside that profile, and checks:

- PROVEN: the extension id derived from the manifest `key` (`adaipbcblicbpanddfckabnffddngdoe` for the spike key) is the id Chrome passes to the host as its first argument (`chrome-extension://<id>/`). The id is fixed without the Web Store.
- PROVEN: `connectNative` launches the host, a snapshot of 2 windows and 3 tabs (id, window id, active flag, title, url) arrives, and the host writes `tabs.json` atomically with mode 600.
- PROVEN: writing `{"type":"activate","tab":N}` to the host's FIFO makes the service worker call `tabs.update(N,{active:true})`, and the next snapshot shows tab N active. Round trip is below the 200 ms poll step of the driver.
- PROVEN: branded Chrome 157 ignores `--load-extension` (same driver, no list ever appears), unbranded Chromium honours it.
- PROVEN: a synthetic 200 tab, 10 window snapshot is 34 KB, one atomic write costs 0.013 ms (`scale.py`).
- NOT PROVEN here: anything that needs a visible, focused Wayland window (section 4), and the pid link in section 3. Reason: both need a headed browser window on the user's desktop, which this spike must not open. The smallest manual step is in section 10.

## 1. Native messaging mechanics

- **Manifest per browser (Linux, user scope).** Chrome `~/.config/google-chrome/NativeMessagingHosts/`, Chromium `~/.config/chromium/NativeMessagingHosts/` (DOC: [native messaging](https://developer.chrome.com/docs/extensions/develop/concepts/native-messaging)). Brave `~/.config/BraveSoftware/Brave-Browser/NativeMessagingHosts/` and Edge `~/.config/microsoft-edge/NativeMessagingHosts/` (these directories exist on this machine; the layout is MEMORY for the docs). Firefox `~/.mozilla/native-messaging-hosts/` (MEMORY, MDN points to a separate manifests page). The directory is relative to the browser's user data dir, which is why the spike is hermetic. System scope: `/etc/opt/chrome/native-messaging-hosts/`, `/etc/chromium/native-messaging-hosts/`. `path` must be absolute.
- **Prior art on this machine:** Omarchy itself ships a native host for its Chromium extensions (`com.omarchy.copy_url`, a bash script), with one `allowed_origins` entry. A bash host with `jq` is therefore accepted style on Omarchy. Omarchy loads its own extensions with `--load-extension` in `chromium-flags.conf`; omahop must not copy that (start flag, and it does not work on branded Chrome).
- **`allowed_origins`:** exact `chrome-extension://<id>/`, no wildcards (DOC). The host also receives the caller origin as `argv[1]`, so the host can refuse any other caller itself.
- **Fixing the id without the Store:** put the public key in `manifest.json` `"key"`; the id is the first 128 bits of SHA-256 of the DER public key, mapped 0-9a-f to a-p (spike script reproduces Chrome's id exactly). DOC: [manifest key](https://developer.chrome.com/docs/extensions/reference/manifest/key) says to take the key from the Developer Dashboard (upload without publishing, Package tab, View public key). Recommended: use the Store's key, so the unpacked and the Store build have one id and the maintainer never holds a signing key.
- **Launch and framing:** `runtime.connectNative` starts one host process per connection and keeps it until the port is destroyed; `sendNativeMessage` starts one process per message (DOC). Framing is a 32 bit native-endian length then UTF-8 JSON. Limits: host to Chrome 1 MB, Chrome to host 64 MiB (DOC). Our heavy direction is extension to host, so limits are not a problem. When the browser quits, stdin hits EOF and the host exits (PROVEN: the host loop ends on EOF; the driver left no process behind).
- **MV3 service worker lifetime.** It sleeps after 30 s idle, but `connectNative` keeps it alive from Chrome 105, and extension API calls and messages reset the timer (DOC: [service worker lifecycle](https://developer.chrome.com/docs/extensions/develop/concepts/service-workers/lifecycle)). If the host disconnects the worker may stop, so reconnect in `onDisconnect`. **Cheapest robust pattern (this is what `sw.js` does):** one `connectNative` at start, a full snapshot on every tab or window event debounced 150 ms, reconnect with a 2 s delay on disconnect, no state in globals (the snapshot is rebuilt from `windows.getAll`). If the worker is woken by an event it reconnects and pushes a fresh snapshot, so no state can be lost. Optional belt: a `chrome.alarms` period of 30 s that calls the connect function if the port is null (min period 30 s since Chrome 120, DOC). Set `minimum_chrome_version` 116.

## 2. Distribution

| Route | What the user does | Notes |
|---|---|---|
| Web Store | Install from a link, run the helper installer | Review (typically days, MEMORY), one time developer fee (MEMORY), needs a privacy policy and justification for `tabs` and `nativeMessaging`. Chrome shows a "read your browsing history" style warning for `tabs` (MEMORY). Cleanest for users, outside our control for timing. |
| Load unpacked | Open `chrome://extensions`, turn on Developer mode, Load unpacked, pick the folder | Works in Chrome, Chromium, Brave, Edge. Chrome may nag about developer mode extensions at start (MEMORY). The folder must stay in place. |
| Start flag | `--load-extension` | **Dead on branded Chrome since 137**, and the escape switch was removed in 142 (reported in the [chromium-extensions announcement](https://groups.google.com/a/chromium.org/g/chromium-extensions/c/1-g8EFx2BBY/m/S0ET5wPjCAAJ) and issue threads); PROVEN here on 157. Works on Chromium and Chrome for Testing. Also breaks the "no start flag" rule. Rejected. |
| Local CRX via external extensions JSON | root writes `<id>.json` in `/opt/google/chrome/extensions/` with `external_crx` and `external_version` | DOC: [install extensions](https://developer.chrome.com/docs/extensions/how-to/distribute/install-extensions). Linux installs silently. Needs root and a signed CRX (we then own a private key). Offer only as an advanced note, UNVERIFIED on 157. |
| Chrome policy force-install | enterprise policy | Needs an update URL. Not for a personal tool. |

Minimal install (user): 1) install the extension (Store link, or Load unpacked), 2) run `omahop-tabs-install` (writes the host manifest into the data dir of each browser found, shows the files it will write, asks), 3) turn on "Browser tabs" in the omahop settings, 4) restart the browser once (the manifest is read at connect time; a reload of the extension is enough in most cases, UNVERIFIED).
Removal: turn the setting off, remove the extension in `chrome://extensions`, run `omahop-tabs-install --remove` (deletes the manifest files it wrote and `$XDG_RUNTIME_DIR/omahop/tabs*`). The plugin never installs or removes anything itself.

## 3. Mapping a browser window to a Hyprland window

Facts (read-only `hyprctl clients -j` on this machine, titles not recorded):
- Class `google-chrome`; title is `<active tab title> - Google Chrome`, with no profile name; **all windows of one browser process share one pid**. Equal titles are possible (two new tab pages). Other classes (MEMORY, to check per browser): Chromium `chromium`, Brave `Brave-browser`, Edge `microsoft-edge`, Firefox `firefox`.
- The extension knows window id (unique per browser session), `focused`, `type`, active tab title; `windows.getAll` gives no title for the window itself and no pid (DOC). Nothing in the extension API sets or reads the OS window title, and `chrome.windows.update` has no title field.
- The native host is a child of the browser process, so the host can report `getppid()` and `/proc/<ppid>/comm`. That should equal Hyprland's pid for every window of that browser (UNVERIFIED: live check 1; the headless run has no Hyprland window).

Most robust matching, in order, each step used only if the previous leaves ambiguity:
1. **Group by browser pid** (host ppid vs Hyprland pid) and class. This separates Chrome, Brave, Chromium, and separate `--user-data-dir` instances. One profile with one window is then an exact match with no title involved (the common case).
2. **Title:** a Hyprland window matches a browser window if its title starts with the active tab title (strip the known ` - <Browser name>` suffix, learned as the common suffix of that pid's windows). One-to-one results are accepted.
3. **Tie break:** equal titles resolve by focus (the extension's focused window against Hyprland's focused window), then window size (`windows.getAll` width and height against Hyprland `size`; on Wayland the position is not reported by Chrome, UNVERIFIED for size).
4. **Verify after the fact:** for a still ambiguous window, omahop focuses candidate 1, the extension reports `windows.onFocusChanged` (or `getLastFocused`) within a short time, and if the focused browser window id is not the tab's window, omahop tries the next candidate. Cost: one extra round trip, only in the tie case.

Profiles: each profile needs the extension installed, so each profile opens its own host connection (separate file `tabs.<hostpid>.json`); they share the browser pid and window ids stay unique, so merging is safe. PWAs and app windows (class `chrome-<appid>-Default`, MEMORY) are not listed by `windows.getAll` for another extension (DOC), so they stay ordinary windows with title search; this is correct, not a bug. Popups (`type: popup`) are included only when asked.

How it fails: (a) a page changes its title between snapshot and read (counters like "(3) ..."): the 150 ms debounce and a re-match at read time make this a stale one-shot, falling to step 3 or 4; (b) two truly identical windows where size and focus also tie: step 4 still activates the right tab in the right chrome window because the extension acts on a window id, only the Hyprland focus can be the sibling window, and the verify retry fixes it; (c) a host connection from a stale session: files whose host pid is gone are ignored; (d) a browser variant whose host ppid differs from the window pid (a wrapper script, Flatpak): fall back to class only.

## 4. Activating a tab and focusing the window

- DOC: `tabs.update({active:true})` "does not affect whether the window is focused"; `Tab.active` "does not necessarily mean the window is focused" ([tabs API](https://developer.chrome.com/docs/extensions/reference/api/tabs)). So a tab can be activated in an unfocused or other-workspace window. PROVEN in headless with two windows (the activated tab belonged to the first window, the second was created last); the focus semantics are only DOC until live check 3.
- `windows.update({focused:true})` asks the browser to take focus ([windows API](https://developer.chrome.com/docs/extensions/reference/api/windows)). On Wayland a client may not raise itself without an activation token, and Hyprland decides by its `focus_on_activate` setting (UNVERIFIED: live check 3). Do not depend on it.
- **Recommendation:** Hyprland is the authority for focus; the extension only calls `tabs.update`. Order: omahop writes the activate request first (fire and forget, tens of milliseconds), then immediately runs its normal `focus(window)` and raise. If a wrong-tab flash shows on screen, add a short wait for the `onActivated` snapshot before focusing (a state-file ack, about one tick). `focusWindow` stays in the protocol as an unused fallback.
- **Trap (important):** never open the FIFO for writing from the Hyprland Lua glue. `open(O_WRONLY)` blocks until a reader exists, and a stalled Lua call freezes the desktop (same class as the `hyprctl` gotcha in `docs/gotchas.md`). Use a detached helper `omahop-tabs-activate <tab>` started with `hl.exec_cmd`, which opens the FIFO `O_NONBLOCK` and exits at once when no host listens (ENXIO). Or let QML write the request file with its own process object.

## 5. Privacy and security

- Permissions: `tabs` (needed for `title` and `url`, DOC) and `nativeMessaging`. No `host_permissions`, no content scripts, no `activeTab`, no `favicon` (see section 6), no network code, MV3 forbids remote code. The extension has no way to send anything except to the host named in its code.
- Host manifest names one origin; the host also checks `argv[1]` and exits otherwise (recommended, 3 lines).
- What the helper could leak: tab titles and URLs. Design: the host writes only under `$XDG_RUNTIME_DIR/omahop` (tmpfs, mode 700 dir, 600 files, gone at logout), never logs titles or URLs (not even on error), never writes outside it, and has no network code. Its source is the repository, 50 to 80 lines, installed by a script that the user reads and runs.
- **Off means off:** omahop creates `$XDG_RUNTIME_DIR/omahop/tabs.enabled` when the setting is on and removes it (and the tab files) when off. The host writes nothing unless the flag exists and deletes its file when the flag disappears. A user can leave the extension installed with the setting off and nothing is stored.
- **Ignore list:** a list of host patterns in `config.toml`, in the settings app. Applied by the host before writing, so an ignored tab never reaches any file. (Stronger option: apply it in the extension from `storage`, so ignored tabs never leave the browser; costs a second settings place, so use the host.)
- **Incognito:** the extension is not enabled in incognito unless the user switches it on in `chrome://extensions`; it additionally filters `window.incognito` out. Default off, documented.
- Marketplace stance ("no code execution surprises"): the plugin (QML and Lua) installs, downloads and spawns nothing new except a detached `omahop-tabs-activate` it ships, only while the setting is on; the extension and host live in a separate folder with their own install and removal notes. A reviewer sees one read of a runtime file and one request file; the host is a separate artifact the user installs knowingly.

## 6. Scale

- Size: 200 tabs in 10 windows is 34 KB of JSON; atomic write 0.013 ms; parse is about 0.1 ms in Python, similar in QML JS (PROVEN, `scale.py`; synthetic text only). Far below the 1 MB host to Chrome cap and irrelevant for the 64 MiB opposite one.
- Traffic: event driven, never polling. A page load fires several `onUpdated` events; the 150 ms debounce reduces that to at most about 6 snapshots per second per active page load. Cost sits in the browser (a worker that stays awake, one idle host process), not in omahop.
- Idle cost of omahop stays zero: omahop reads the folder only when the switcher opens (list the folder, read at most a few 35 KB files), with no watcher and no timer. This honours the standards file.
- Favicons: leave them out of v1. Chrome hands the extension a `favIconUrl` that QML cannot always fetch (and `chrome-extension://` favicon URLs only resolve inside the browser). Rows use the browser's own app icon, as windows do today.
- Startup race: omahop before the browser: no files, so windows appear as today. Browser before omahop: the files already exist. Browser starts later: the host starts with the first connect, writes its file, the next open of the switcher sees it. Browser killed with SIGKILL leaves a stale file: omahop ignores a file whose host pid (`pid` field) has no `/proc` entry, checked by the same read step.

## 7. Firefox and the shared extension

- Differences (DOC: [MDN native messaging](https://developer.mozilla.org/en-US/docs/Mozilla/Add-ons/WebExtensions/Native_messaging)): manifest key `allowed_extensions` with the add-on id set by `browser_specific_settings.gecko.id`; Firefox passes the add-on id to the host; host manifest at `~/.mozilla/native-messaging-hosts/` (MEMORY); `connectNative` keeps the host until `disconnect()`; Firefox sends SIGTERM then SIGKILL; limits 1 MB from the host and much larger to it.
- WebExtension API: `tabs.query`, `tabs.update({active:true})`, `windows.getAll` and the same tab events exist under `browser.*` and `chrome.*`. The background context is an event page, not a service worker (`background.scripts`), UNVERIFIED for how long a native port keeps it alive; the same "reconnect on wake and resend a snapshot" pattern covers it.
- Install friction is higher: release Firefox needs a signed add-on (AMO listing or self-distributed signed xpi, MEMORY), temporary add-ons vanish at restart. Flatpak and Snap builds of any browser may not see the host manifest or run the host outside their sandbox (MEMORY): list as unsupported for v1.
- Shared code: one `sw.js` (renamed `background.js`) with a tiny namespace line, two `manifest.json` files (Chromium family with `key` and `service_worker`; Firefox with `gecko.id` and `scripts`). Chrome, Chromium, Brave and Edge share one build and one id (id derives from the key, so the same unpacked folder gives the same id in all four). Firefox is milestone 3.

## 8. Chosen architecture

```
 browser (Chromium family)                          omahop
 extension (MV3 service worker)                     Lua (focus, MRU, glue)   QML (search, rows)
   tabs + windows events --150 ms debounce-->        |                         |
   connectNative --stdio, 4 byte frames--> host ---> $XDG_RUNTIME_DIR/omahop/tabs.<hostpid>.json  (read when the switcher opens)
   tabs.update(active) <-- host <--- activate.fifo <-- omahop-tabs-activate <tab>  (detached, O_NONBLOCK)
```

File contract (versioned, `schema = 1`): `{schema, browser, pid, caller, profile, windows:[{id, focused, type, tabs:[{id, active, title, url}]}]}`. omahop side: a pure `Tabs.js` (parse, drop stale, apply ignore list, match to windows by section 3, return rows) tested in Node; `search.lua`/search in QML gets tab rows under their window, matched on title and url; Return sends the activate request then focuses the window. Setting `browser_tabs = false` by default in the `config.lua` defaults table and in the settings app.

## 9. Test plan

- **Pure (Node and `lua`, no browser):** parse and schema check; stale file dropped; ignore patterns; matching (unique pid, title prefix, equal titles resolved by focus, resolved by size, unresolved gives candidates list); search over tab title and url (case, unicode, empty title); 200 tab fixture under a time bound; request builder.
- **Glue (fake):** `hl` fake proves the activate path starts a detached command and never opens a FIFO in Lua; the setting off creates no flag file and reads no file; the helper test feeds a recorded framed stream to the host and asserts the file, mode 600, atomic replace, EOF exit, wrong `argv[1]` refusal, no output of titles on stderr (`host` tests in bash or Python).
- **Spike regression:** `docs/research/spike-tabs/run.sh` kept as a smoke test against Chromium (hermetic, no window).
- **Live (user at the machine, a temporary profile, data URLs only):** headed Chromium with the unpacked extension, three tabs in two windows: list appears; search a hidden tab by title; Return shows that tab and focuses its window; same with Chrome (Load unpacked); equal titles in two windows; ignore list hides a pattern; setting off deletes the files; browser quit removes the file.

## 10. Live checks that decide the final go (smallest manual steps)

1. **pid link:** start the headed spike profile, read the host's `getppid()` (add one line to `host.py` that writes it) and compare with the window's pid from `hyprctl clients -j` (read-only). Pass if equal.
2. **Title and class per browser:** open a second profile or Brave or Edge, list `class`, `title` suffix and `pid`. Confirms the suffix rule and the class table (MEMORY items in section 3).
3. **Focus semantics:** with two Chromium windows on two workspaces, send an activate request with `focusWindow` false then true while another window has focus; watch `hyprctl activewindow` (read-only) and the visible tab. Decides whether the wrong-tab flash needs the ack wait.

## 11. Effort (hours)

| Part | Work | Hours |
|---|---|---|
| Extension | sw (events, debounce, reconnect, incognito filter), two manifests, icons, Store listing, privacy text | 8 |
| Helper | host (bash or Python), flag file, ignore filter, install and remove script for 4 browsers, activate command, tests | 8 |
| omahop side | `Tabs.js` (parse, match, search), rows in cards and list, settings and ignore list UI, Lua glue, fake tests, live test | 16 |
| Docs | README section, install and removal notes, privacy statement, batch log, release highlight | 5 |
| Live validation, fixes | checks in section 10, Chrome and Chromium and Brave runs | 5 |
| Total | | about 42 |

## 12. Risks

1. **Equal-title ambiguity and the pid link** (matching). Mitigated by pid grouping, focus and size tie breaks and verify-and-retry; live checks 1 and 2 decide.
2. **Install friction and Store review.** Branded Chrome has no flag route since 137; users face Developer mode or Store review. The extension plus a separate helper is two installs; many users will stop. Mitigate with one `omahop-tabs-install` that prints each step and detects the browsers.
3. **Privacy perception.** `tabs` shows a browsing history warning. Mitigate with off-by-default, the enabled flag, runtime-only files, the ignore list, a short plain README and reviewable 80 line helper.
4. Sandboxed browsers (Flatpak, Snap) cannot reach the host; Firefox needs a signed add-on. Both are documented as unsupported at first.
5. Lua freeze if a FIFO is ever opened for write in the glue (section 4); guarded by a fake test.
6. Wayland focus: `windows.update` may be ignored; designed around.

## 13. Go or no-go, and the smallest first milestone

**GO**, Chromium family only, Firefox later. Smallest first milestone (about 14 h): the spike extension hardened (ignore incognito, reconnect), host writes `tabs.<pid>.json` only when the flag exists, omahop reads at open, list view shows tab rows under a window whose pid has exactly one browser window (the exact-match case), search matches title and url, Return sends activate then focuses. No settings UI beyond the one toggle, no ignore list UI (config key only), no Firefox. Ship as an experimental, off-by-default option with install notes for Load unpacked.
