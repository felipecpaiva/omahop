# Tab pictures for tabs that are not shown: spike and recommendation (2026-11-08)

Question: when omahop lists a browser tab that is NOT the one its window shows, can the extension give us an up to date picture of it, without switching tabs? Felipe's wording: "request an updated frame of that tab in the background". Related earlier work: `tabs-spike.md` (the optional extension, helper and file contract), `thumbnails-and-prior-art.md` (window thumbnails through the compositor).

**Short answer.** Chrome has no API that says "give me the thumbnail of tab X". There is no extension way to read the picture Chrome keeps for its own hover card. What an extension CAN do falls in three groups:

1. Take a picture while the tab is shown (`captureVisibleTab`), keep it, and show the last seen picture later. Invisible, cheap, pixel exact, but it is a memory of the tab, not a live frame.
2. Ask a hidden tab for a frame right now with the debugger (`Page.captureScreenshot`). This is the only method that returned real browser pixels of a hidden tab in my runs, but it needs the strongest permission, shows an infobar (not observed here, see section 8), and hung in some runs.
3. Draw the page again from its DOM inside the tab (`html2canvas` class libraries). Works on a hidden tab with no extra permission, but it is a re-drawing, not the browser's pixels.

`tabCapture` cannot do it for a tab the user never invoked the extension on (verified). Reloading the tab in a second window works but has real side effects. Ranking is in section 7.

## How claims were checked

Labels used below:

- **DOC**: official Chrome documentation, page named. I read the pages with a fetch tool that summarises them, so a quote is the summary's quote of the page, not a byte exact copy.
- **SRC**: Chromium source file, read at `main` through the same summarising fetch tool, not built or run here.
- **RAN**: I ran it, in the spike under `docs/research/spike-tab-preview/` (raw logs in `results/`).
- **MEMORY**: author knowledge, not re-checked this session.
- **NOT VERIFIED**: could not check, with the reason.

Environment of every RAN claim: Chromium 155 on Arch, `--headless=new`, a temporary profile, software rendering (`--disable-gpu --use-gl=disabled`), local pages on 127.0.0.1. The experiment driver talks to the extension's service worker through the DevTools port of that scratch instance only. Felipe's Chrome was never touched, no input was sent to the desktop.

**What headless Chromium cannot tell us (important).** It has no real window on a Wayland compositor. So these were NOT tested and any conclusion about them is open: occlusion (another window on top), windows on another workspace, minimized windows, frame callback throttling by the compositor, GPU rendering paths, the debugger infobar, the tab recording indicator, and anything that needs a user gesture (the `activeTab` grant). A background tab inside one headless window IS genuinely hidden: `document.visibilityState` was `hidden` for it and `visible` for the shown tab (RAN). So the hidden-tab results are meaningful for "tab not shown in its window", and weak for "window not visible".

## 1. How Chrome treats a background tab

| Fact | Evidence |
|---|---|
| A tab that is not the shown tab of its window has `visibilityState` `hidden` and fires `visibilitychange`. | DOC page lifecycle API; RAN (tab B hidden, tab A visible). |
| Chrome does not call `requestAnimationFrame` callbacks for a page in the background. | DOC "Background tabs" (developer.chrome.com/blog/background_tabs). RAN: a rAF counter in the hidden page read 5 after 20 s and 9 after 330 s, while a 1 s timer ran about 405 times. |
| Timers: each timer runs at most once per second in a background page, since Chrome 11; from Chrome 57 a budget system starts after 10 s hidden; pages playing audible audio, and (for the budget) pages with WebSocket or WebRTC, are exempt. | DOC background_tabs. RAN: a `setInterval(1000)` in the hidden page kept 1 tick per second from 60 s to 330 s (135 to 405 ticks). |
| Intensive throttling (Chrome 88): timers run once per minute only if the page was hidden more than 5 minutes, the timer chain is 5 or more, the page was silent for 30 s, and no WebRTC. | DOC timer-throttling-in-chrome-88. RAN: NOT reached. My last sample was about 5.5 minutes hidden and still showed 1 tick per second. This does not disprove it (only about 30 s past the 5 minute mark, and headless may differ). Treat "a page change driven by a timer may be up to a minute old after 5 minutes hidden" as DOC only. |
| A hidden tab produces no compositor frames of its own. Evidence is indirect: no rAF callbacks (RAN), and Chromium's own thumbnail code has to ask for "hidden capture" (below). | RAN for rAF; SRC for the capture request; the statement about the compositor itself is an inference, I did not read cc or viz code. |
| Window occlusion tracking in Chromium treats a covered window like a background tab. The design doc and the feature flag are Windows only; windows on another virtual desktop count as occluded there. I found no Linux or Wayland equivalent. | DOC/SRC: `docs/windows_native_window_occlusion_tracking.md`, `ui/base/ui_base_features.cc` (found by search, not read in full). Linux and Wayland: NOT VERIFIED, no source read and headless cannot show it. A Wayland compositor may stop sending frame callbacks to a surface it does not show (MEMORY); if so, the SHOWN tab of a window on another workspace may also stop painting. That is the first open question in section 9. |
| Freezing: a frozen page cannot run tasks, timers or event handlers; it stays in the tab strip with content in memory. `Tab.frozen` exists since Chrome 132. | DOC page lifecycle, DOC tabs API. RAN: the property was `false` for every tab in all runs (no freeze was triggered). |
| Discarding (Memory Saver, `tabs.discard`): the content is unloaded. No JavaScript runs. The tab stays in the tab strip with its title and favicon, and reloads when activated. Chrome avoids discarding tabs that play audio, use WebRTC, or update the title or favicon. | DOC page lifecycle, DOC tabs API. |
| What a discarded tab looks like to an extension. | RAN: `tabs.discard(B)` returned a tab with a NEW tab id (old id gone), `discarded: true`, `status: "unloaded"`, still in `tabs.query` with title and url. `executeScript` on it failed ("Cannot access contents"), `pageCapture.saveAsMHTML` failed ("Don't have permissions required to capture this page"), `Page.captureScreenshot` through the debugger failed ("Internal error"). `captureVisibleTab` still returned the other, shown tab. A discarded tab has no live content to ask for. The extension must handle the id change (rekey by url and title, or drop the old picture). |
| Chrome keeps a thumbnail for a discarded tab. | SRC `thumbnail_tab_helper.cc`: "Discarded tabs keep their last thumbnail through `DiscardedTabThumbnailData`, which is reattached to the new WebContents". Internal only (section 2). |

## 2. How Chrome's own hover card gets its picture

Read from `chrome/browser/ui/thumbnails/` at Chromium `main` (SRC, summarising fetch, so the exact constants are not known):

- `ThumbnailTabHelper` keeps a ref counted `ThumbnailImage` per tab. Its comments say the images serve the tablet tab strip and the tab hover card.
- **Capture at the moment the tab is hidden:** `CaptureThumbnailOnTabBackgrounded()` copies the view's surface (`CopyFromSurfaceSecure()`), with the comment that tab thumbnail previews are a trusted internal browser UI feature. So the main source is a snapshot of the last frame the user saw, taken when the tab is left.
- **Capture while shown:** a driver (`ThumbnailCaptureDriver`) has a state machine (no capture, requested, capturing, cooldown, have final capture) driven by page readiness (not ready, ready for initial capture, ready for final capture). There is a cooldown wait with a few retries to catch a late frame. It does not recapture on a timer, and if the page changes after a final capture it gets set up for a new capture.
- **Hidden capture exists but is limited:** `RequestCapture()` increments the capturer count with `stay_hidden=true` and a background video capturer can deliver frames (`kVideoFrame`). But the driver says (quote): "For now don't force-load background pages, or the current page if the thumbnail isn't being requested", marks this "not ideal" and links a TODO bug about forcing background tabs to render. So by default a background tab is NOT re-rendered for the hover card.
- **Discarded tabs** keep their last thumbnail (above).
- **Exposure:** the thumbnail lives in per tab user data and is consumed by the tab strip and the hover card. I found no extension API for it. The `tabs` API page has no thumbnail or screenshot field except `captureVisibleTab` (DOC, read in full for this question). `chrome://tab-search` and hover card are browser UI, not reachable from an extension.
- NOT VERIFIED: I could not open `tab_hover_card_thumbnail_observer.cc` (the path I tried returned 404), so how the card requests a capture is read only from the helper and driver.

**Conclusion for us:** Chrome's own answer is "show the last picture taken while the tab was visible or when it was hidden". It does not render the background tab on demand. An extension can copy that design exactly (section 5, idea A) with `captureVisibleTab`, minus the "at the moment of hiding" moment, which an extension cannot catch (section 5).

Source for these facts: https://chromium.googlesource.com/chromium/src/+/main/chrome/browser/ui/thumbnails/thumbnail_tab_helper.cc and `thumbnail_capture_driver.cc` in the same folder.

## 3. Candidate methods

Measured numbers come from RAN logs: `results/main.log`, `results/iso.log`, `results/main-results.json`. "Current" means the dominant colour of the picture equalled the colour the page had at that moment (the page changes colour every second and writes its state to a variable I read before and after the call).

### 3.1 `chrome.tabs.captureVisibleTab` (baseline)

- **How:** returns an image of the visible area of the active tab of a window. The only target input is `windowId`. DOC.
- **Permissions:** `<all_urls>` (a host permission) or `activeTab`. DOC. `chrome:` pages, other extensions' pages and `data:` URLs only with `activeTab`. Install warning for `<all_urls>`: "Read and change all your data on all websites" (MEMORY; the permission docs I fetched do not print warning strings). `activeTab` shows no warning (DOC permission-warnings).
- **Side effects:** none visible by design (MEMORY, not observable headless). Rate limit 2 calls per second (DOC).
- **Background tab:** NO. It returned the shown tab. RAN: with tab B hidden, `captureVisibleTab(window)` gave tab A (grey) 100 percent of the time (every call, 3 per run in the main run), never B.
- **Fidelity:** exact browser pixels of what is shown, video and cross origin content included (DOC says it captures the visible area; I did not test video through this call).
- **Cost:** RAN: 13 to 18 ms per call (software rendering, 900x513, PNG).
- **Privacy and review:** broad host permission means closer review (MEMORY). Pictures can contain anything on screen, so the ignore list and incognito rules from `tabs-spike.md` section 5 must apply before the call.
- **Fit:** good for the shown tab of each window; useless for hidden tabs on its own.

### 3.2 `chrome.tabCapture` (`capture` and `getMediaStreamId` with `targetTabId`)

- **How:** `getMediaStreamId({targetTabId})` returns a one use id, valid a few seconds, which an offscreen document (reason `USER_MEDIA`) turns into a `MediaStream` with `getUserMedia({video:{mandatory:{chromeMediaSource:'tab', chromeMediaSourceId:id}}})`, then draws a frame to a canvas. DOC (tabCapture, offscreen).
- **Permissions:** `tabCapture`. DOC: `capture()` works only on the active tab after the extension was invoked, and for `targetTabId` "Only tabs for which the extension has been granted the `activeTab` permission can be used as the target tab". Warning text: NOT VERIFIED.
- **Does a broad host permission replace the `activeTab` grant?** NO. RAN: with `<all_urls>` and `tabCapture` declared, `getMediaStreamId({targetTabId: B})` failed with "Extension has not been invoked for the current page (see activeTab permission)". Same on every call (a dozen calls across 4 runs, all denied). I also tried the Chromium test switch `--whitelisted-extension-id`, which made no difference (so I do not know if that switch does what I assumed).
- **Side effects:** DOC says the tab's audio stops playing for the user once captured unless routed back. A recording indicator is expected (MEMORY, Chrome shows tab capture in the tab strip), not observed here.
- **Background tab:** UNKNOWN. I could not reach the media step. Only a user gesture (toolbar click, shortcut, context menu) grants `activeTab`, and the question "does the grant on tab B still work after the user switched to tab A" needs a headful test (section 9, step 4). Chromium's own hover card uses an internal version of this (hidden capture with `stay_hidden`, SRC), which suggests the media path can serve a hidden tab, but the extension API gate is the problem, not the media path.
- **Fidelity:** video stream of the tab compositor output: would be exact, including video, if it works. NOT VERIFIED.
- **Cost:** a live stream per captured tab; we would open and close it per picture. NOT MEASURED.
- **Fit:** poor even if the media works, because it needs the user to have invoked the extension on each tab. Cannot serve "tabs never shown".

### 3.3 `chrome.debugger` with CDP `Page.captureScreenshot`

- **How:** `debugger.attach({tabId}, '1.3')`, `sendCommand('Page.captureScreenshot')`, `detach`. The `Page` domain is on the allowed list. DOC debugger.
- **Permissions:** `debugger` (cannot be an optional permission, DOC permissions page lists it among those that cannot) plus no host permission needed for attach on normal pages (MEMORY). Install warning: "Access the page debugger backend" and a data access warning (MEMORY, wording not verified).
- **Side effects:** Chrome shows an infobar "<extension> started debugging this browser" on the debugged tab for as long as it is attached (MEMORY; the debugger doc page does not mention it; headless has no UI so NOT OBSERVED). It can be hidden only with the start flag `--silent-debugger-extension-api`, which breaks our "no start flag" rule. Enterprise `runtime_blocked_hosts` can block attach (DOC).
- **Background tab:** YES, with caveats. RAN, hidden tab B that was never shown:
  - returned the CURRENT page (colour matched) at t0, at 60 s and at 330 s in the background (3 of 3 on the colour page: 59 ms, 44 ms, 56 ms).
  - it captures a forced frame, so a page whose picture is driven by timers or DOM changes shows its current state even though rAF is stopped. A page that draws only inside rAF would be stale (NOT TESTED).
  - **Flaky:** in the full run 2 of the 4 calls on freshly opened hidden pages hung until my 10 s guard fired (cross origin iframe page, CSP page); in the isolation run 2 of 5 hung (cross origin page, canvas page) and the others returned in 59 to 542 ms. The same page that hung once worked on the next try. On the SHOWN tab it returned in 30 ms every time (1 of 1). I did not find the cause. A real implementation needs a timeout, a retry and a detach in `finally`.
  - discarded tab: fails ("Internal error"), as every method.
- **Fidelity:** browser pixels, including canvas (RAN: magenta canvas correct) and video element (RAN: the video showed red, which was the FIRST frame of a stream that changes colour every 0.4 s; both the debugger and the rasterizer agreed on red, so a hidden tab's video seems not to advance in headless; cause not isolated). Cross origin iframe and image: NOT readable because the call hung (the rasterizer was blank there, see 3.4).
- **Cost:** 44 to 62 ms normally, up to 2.2 s and sometimes a hang (RAN). Memory: the PNG is about 10 KB for a flat page and larger for real pages.
- **Privacy and review:** strongest permission an extension can ask for. Store review will want a strong reason (MEMORY). A user sees the warning at install, which for a switcher is a hard sell.
- **Fit:** the only method that gives "an updated frame of a hidden tab", at the highest trust cost. Candidate for an advanced opt in, not for the default.

### 3.4 `chrome.scripting.executeScript` plus a DOM rasterizer

- **How:** inject a bundled library file into the tab (isolated world), draw `document.documentElement` to a canvas, return `toDataURL`. The library re-implements layout and painting from the DOM and computed styles; it does not copy the browser's pixels.
- **Permissions:** a host permission for the tab's site (`<all_urls>` for any site) or `activeTab` for that tab after a gesture; plus `scripting`. Warning: same as 3.1. DOC scripting (MEMORY for the exact rule).
- **Libraries (licence checked on the npm registry, RAN `npm view`):** html2canvas 1.4.1 MIT (about 199 KB minified); html-to-image 1.11.13 MIT (about 21 KB; draws through an SVG `foreignObject`); dom-to-image-more 3.11.0 MIT; dom-to-image 2.6.0 MIT (unmaintained, MEMORY). All MIT, so compatible with a public MIT plugin. MV3 forbids remote code, so the library must be bundled (DOC), which is allowed.
- **Side effects:** none visible. It runs in the hidden tab, so a CPU spike there is not seen. It runs page work and layout in the page's main thread for 0.1 to 0.8 s.
- **Background tab:** YES for html2canvas, NO for html-to-image in my harness.
  - html2canvas on the hidden colour page: current colour at t0, 60 s and 330 s (3 of 3 current), 459 to 824 ms the first time, 128 to 745 ms later.
  - html-to-image: did not work on hidden tabs in 5 of 5 tries in the main run: 3 hung until my 12 s guard fired (colour, canvas and CSP pages), 2 returned an error event (video and cross origin pages). On the shown tab it returned in 36 ms but the picture was black, so I cannot call it working at all in my harness (I did not debug it; it may be my options). Likely cause for the hang: it waits on image decoding that a hidden page does not schedule (MEMORY/guess, not tested).
- **Fidelity (RAN, html2canvas):** plain colours, text and a same origin canvas: correct. Cross origin image and cross site iframe: BLANK (the picture was 100 percent white, 0 percent non white, where the real page has a red image and a green frame). Video: first frame only (same as the debugger). Page body layout: when I drew `document.body` the picture was cropped and offset; `documentElement` was right, so the call needs care. Not tested: web fonts, shadow DOM, WebGL, heavy pages, real sites.
- **CSP:** on a page with a strict `Content-Security-Policy` (`default-src 'self'; img-src 'self'`) html2canvas still worked (same origin image only, so this is a weak test). A page that blocks `data:` or blob images may break the SVG based libraries (MEMORY).
- **Cost:** 100 to 850 ms of page main thread time per picture, memory proportional to page size.
- **Privacy and review:** needs the broad host permission anyway; no extra warning compared with 3.1. Code runs inside every page we capture, which a reviewer may question.
- **Fit:** invisible and no extra permission, but approximate. Best as a fallback picture.

### 3.5 `chrome.pageCapture.saveAsMHTML`

- **How:** returns the page as one MHTML file (blob). Permission `pageCapture`; tab id as input. DOC.
- **Background tab:** YES, but not an image. RAN: on the hidden tab it returned about 1 KB in 3 to 4 ms and the file contained the CURRENT state (background `rgb(255, 255, 0)` and the text `idx 3 tick 405` at 330 s). The first call right after load failed once with NotFoundError. On a discarded tab it fails.
- **Fidelity:** it is a document, not a picture. DOC says MHTML files can only be loaded from the local file system and only into the main frame. To turn it into a picture we would have to load it in a page and screenshot it, which is the "second window" method below.
- **Fit:** rejected. Large (it bundles resources) and no picture.

### 3.6 Reload the URL in a hidden window or offscreen document

- **How (window):** `windows.create({url, type:'popup', focused:false})` then `captureVisibleTab` of that window. **How (offscreen):** `offscreen.createDocument` with reason `DOM_SCRAPING` or `IFRAME_SCRIPTING` embeds the page in an iframe; it can read the DOM but cannot screenshot, only one offscreen document exists, and sites that refuse framing will not load. DOC offscreen. Not run.
- **Background tab:** it is not the tab, it is a second copy. RAN (window): a normal popup window with `focused:false` returned a correct picture of the page in 2.07 s (the page was loaded fresh). A minimized popup returned nothing (error not recorded). The server log counted ONE extra request for the page (7 to 8), confirming a double request.
- **Side effects (real desktop):** a new window appears on screen (flicker, focus and workspace behaviour on Hyprland unknown), a second request to the site, the page's scripts and analytics run again, cookies and login are shared so a logged in page loads logged in, the scroll position, form text and playing state of the real tab are NOT in the copy. A picture of a login page may show a different state than the live tab.
- **Privacy:** the extension causes extra requests the user did not make. Reviewers dislike it.
- **Fit:** rejected.

### 3.7 Other APIs checked

- A `tabs.captureTab` does not exist in Chrome's tabs API (DOC, the page lists only `captureVisibleTab`). Firefox has one (MEMORY, not checked).
- `desktopCapture.chooseDesktopMedia` and `getDisplayMedia`: show a picker and need a user gesture each time (MEMORY, not tested). Rejected: not silent.
- `sessions`, `tabGroups`, `topSites`, `readingList`, `sidePanel`: none exposes a page picture (MEMORY).
- `tabs.discard` and `Tab.autoDiscardable`: not a capture method, but `autoDiscardable: false` stops Chrome discarding a tab we want a live picture of (DOC). Not recommended: it costs the user memory, against their Memory Saver choice.
- Flags like `--auto-select-tab-capture-source-by-title`: start flags, rejected.

### 3.8 What other tab managers do

- Chrome itself: last snapshot, section 2 (SRC).
- Arc and Vivaldi are not extensions (browser UI), so they can render hover cards and thumbnails from inside the browser. Vivaldi shows tab thumbnails and a "tab tiling" view from its own UI layer (MEMORY, not verified how it captures). I did not research them further.
- Tab search extensions in the Web Store: from memory, most list titles and favicons only. Those that show page pictures take them with `captureVisibleTab` when the tab is shown and cache them, and need `<all_urls>` (MEMORY, no specific extension checked). I did not identify names, so treat this as a pattern, not a survey.

## 4. Comparison table (hidden tab)

| Method | Hidden tab never shown | Current frame | Extra permission | Visible side effect | Fidelity | Cost per picture | Evidence |
|---|---|---|---|---|---|---|---|
| captureVisibleTab | no | n/a | host (broad) or activeTab | none | exact | 15 ms | RAN |
| tabCapture | not reachable | unknown | tabCapture plus activeTab per tab | recording indicator (MEMORY) | exact if it works | unknown | RAN (denied), DOC |
| debugger screenshot | yes | yes (timers or DOM driven) | debugger | infobar (MEMORY) | exact, but 2 of 4 and 2 of 5 fresh-page calls hung | 45 to 60 ms, outliers 2 s | RAN |
| executeScript plus html2canvas | yes | yes | host (same as baseline) | none | approximate, blank cross origin, video first frame | 130 to 850 ms | RAN |
| executeScript plus html-to-image | no (3 hung, 2 errors of 5) | no | host | none | unknown | none | RAN |
| pageCapture MHTML | yes, but not an image | yes (DOM) | pageCapture | none | document only | 3 ms | RAN |
| reload in second window | not the tab | fresh copy | windows, host | window flash, double request | exact for the copy | 2 s | RAN (partly) |
| last seen snapshot (idea A) | no | no, last seen | same as baseline | none | exact | 15 ms while shown | RAN for the capture call |

## 5. Felipe's two ideas

### 5.1 Ask on demand when the search matches a tab with no or an old picture

This decides WHEN, not HOW. omahop would write `capture <tabId>` over the same path as the existing activate request (FIFO, detached helper, never opened from the Lua glue, see `tabs-spike.md` section 4), the extension takes the picture, the helper stores it, omahop shows it when it arrives (the card must tolerate a late picture).

Which methods stay invisible when triggered while the user types:

| Method | Invisible at search time? | Why |
|---|---|---|
| captureVisibleTab | yes, but cannot target a hidden tab | only the shown tab of a window; usable to refresh the shown tab of every window |
| html2canvas via executeScript | yes | runs in the hidden tab; 0.1 to 0.8 s of that tab's main thread; nothing on screen |
| debugger screenshot | probably yes | hidden tab, but the infobar is attached to that tab for the attach time (tens of ms) and MIGHT shift layout when that tab is later shown; NOT VERIFIED headful |
| tabCapture | no (indicator expected) and not available | needs an `activeTab` grant per tab |
| second window | no | a window appears |

Timing: all usable methods return in well under a second (RAN), so a request at the first matching keystroke would arrive before the user finishes typing. A rule like "ask once per tab per 60 s, only for tabs the search shows, at most 4 in flight" keeps load tiny. The debugger's hangs mean a 10 s guard and one retry are required, and the card must fall back to the icon.

Judgement: on demand fits our design. Combined with a stored snapshot it gives "last seen picture immediately, refresh in the background if it is old". It does not remove the need for a broad host permission, because both usable methods need it.

### 5.2 Extension side copies of Chrome's hover card behaviour

Chrome captures when the tab is left, which an extension cannot see in time: `tabs.onActivated` fires after the switch, and then `captureVisibleTab` returns the NEW tab (RAN confirms it returns only the shown tab). So the equivalents are:

**(a) Snapshots while the tab is shown (recommended).** Take a picture with `captureVisibleTab` of the shown tab of the focused window:

- once after load: `tabs.onUpdated` status `complete`, plus a settle delay of about 1.5 s (Chrome's own driver also waits for "final capture" readiness and a cooldown, SRC);
- after scroll or typing settles: a tiny content script is NOT needed; use `chrome.idle` and a timer instead, or only the periodic rule below;
- every 10 to 15 s while the window is focused and the user is not idle, skipped when the title, url and last picture age say nothing changed (cheap check: skip if the previous picture is under 10 s old);
- when omahop opens the switcher: omahop asks for one more capture of the shown tab of each browser window, so the tab the user is leaving has a picture from a moment ago (this is the closest thing to Chrome's "at the moment of hiding", and it is predictable because omahop knows the user pressed Alt+Tab);
- never for ignored hosts, incognito, or when the window is minimized or not visible.

Cost estimate (from RAN numbers, scaled; treat as estimates): a capture is about 15 ms of browser time in software rendering (probably less with the GPU, not measured). At one capture per 15 s that is 4 per minute, about 60 ms per minute, below 0.1 percent of one core. Scaling a picture to 480 px wide and JPEG quality 60 gave about 9 KB for a flat page and about 30 KB for a noisy worst case image (measured with Pillow on a synthetic and a noise image, not on real pages; 320 px: 6 to 10 KB; 640 px q70: 15 to 80 KB). For 200 tabs that is 2 to 6 MB in the runtime directory, written once per picture, deleted when the tab closes. The scaling and JPEG encode in the service worker with `OffscreenCanvas` was not measured, estimate 5 to 15 ms. Native messaging carries a 40 KB base64 message with no problem (limit 64 MiB to the host, DOC).

Limits: a tab that changed after the user left it still shows the old picture (same as Chrome's hover card). A tab never shown since the browser started (restored, or opened in the background) has no picture until idea (c). A window on another workspace may not be painting (open question 1).

**(b) Content script rasterizes on `visibilitychange` to hidden.** Works technically (html2canvas ran fine in hidden tabs, RAN) but is worse than (a): it needs a content script on every page (injection on `<all_urls>` is heavier for review than a capture call), takes 0.1 to 0.8 s of main thread at the moment the user leaves (jank in a page that is going away, and a risk that the tab gets frozen before it finishes), draws an approximation (blank cross origin images and iframes, first video frame, canvas without `preserveDrawingBuffer` risk), and costs memory in the page. Rejected as a primary path. Keep it only as the fallback in (c).

**(c) Combination (recommended).** (a) as the base, plus on demand fallbacks from 5.1 for tabs that have no snapshot:

1. Tab has a snapshot: show it, with its age. If older than 5 minutes and the tab is matched by a search, refresh with html2canvas on demand (invisible, no extra permission), and replace the picture when it arrives.
2. Tab has no snapshot: html2canvas on demand. Mark the card picture as "approximate" if the library returned blank regions (a simple check: more than 80 percent one colour is shown as an icon instead).
3. Advanced opt in switch "exact pictures of hidden tabs": use the debugger screenshot instead, with its own warning text in the settings page (infobar, Chrome warning, occasional timeout).

## 6. Permission and store review summary

- Base feature (a) plus the html2canvas fallback: one broad host permission (`<all_urls>`, or `optional_host_permissions` requested when the user turns pictures on, which keeps the base tab list at its current `tabs` plus `nativeMessaging` permissions), plus `scripting`. Warning text to expect: reads and changes data on all sites (MEMORY).
- Debugger tier: `debugger` on top, not optional (DOC), shows a stronger warning and an infobar.
- MV3: no remote code; libraries bundled (DOC).
- Pictures contain page content, so they are more sensitive than titles. Rules: off by default, never written outside `$XDG_RUNTIME_DIR/omahop`, deleted at logout and when the setting is off, ignore list applied BEFORE capture, incognito never, no pictures of tabs that are audible or on a user list of sensitive hosts by default (banking and mail patterns are the user's list, we ship none).

## 7. Recommendation and ranking

1. **First choice: last seen snapshots with `captureVisibleTab`** (5.2 a), refreshed when the switcher opens. Invisible, cheap, exact pixels, same behaviour as Chrome's own hover card, needs one host permission that the fallback also needs. It cannot show a change that happened after the user left the tab.
2. **Fallback and on demand refresh: `executeScript` plus html2canvas** (5.1, 5.2 c). Works on a hidden tab, no flicker, no extra permission, MIT, but approximate (cross origin content blank, video first frame). Verified current at 60 s and 330 s in the background.
3. **Advanced opt in: debugger `Page.captureScreenshot`.** The only tested way to get browser exact pixels of a hidden, never shown tab on request. Costs the strongest permission, an infobar (unverified), and hangs sometimes. Only if Felipe accepts that trade.
4. `tabCapture`: not usable for tabs the user never invoked the extension on (verified denial). Re-evaluate only if the headful step 4 shows the grant survives switching tabs.
5. Rejected: `pageCapture` (not an image), reload in a second window or offscreen document (side effects, double requests), content script rasterizing on `visibilitychange` (worse than 1 and 2), html-to-image (failed on hidden tabs in all my tries).

**What to tell the user on the extension page (plain text):**

> Optional page pictures. When you turn this on, the extension takes small pictures of the tab you are looking at, keeps them in memory on your computer (not on disk, not sent anywhere) and shows them in omahop's Alt+Tab list. To do this it needs permission to read all sites. Pictures can show anything on your screen, so you can list sites that are never pictured. Private windows are never pictured. Pictures are deleted when you turn this off or log out. Tabs you have not looked at since the browser started have no picture, or an approximate one drawn from the page's contents. An optional advanced mode asks Chrome to take exact pictures of background tabs through the debugging interface; Chrome then shows a "started debugging this browser" bar on that tab.

## 8. Decision table

| Need | Method | Verdict |
|---|---|---|
| Picture of a tab the user just left | captureVisibleTab while shown | yes, default |
| Picture of a tab never shown | html2canvas on demand (approximate) or debugger (exact, opt in) | fallback |
| Refresh a stale picture at search time | html2canvas on demand | yes, invisible |
| Exact live frame of a hidden tab | debugger | opt in only |
| Hidden tab, minimal permissions | none beyond the broad host permission | not possible with `tabs` alone |
| Discarded tab | nothing can be captured; show the last snapshot and mark it asleep | by design |
| Video inside a hidden tab | none reliable | last seen snapshot is better |

## 9. Open questions only a headful run can answer, with steps

Why headful: Wayland occlusion, other workspaces, the infobar and indicator, and `activeTab`. Do this in a scratch profile so your own Chrome profile is untouched. Do not use your normal browser window; start the Chromium below as a separate instance.

Setup (about 5 minutes):

1. `cd` to a copy of `docs/research/spike-tab-preview/`. Install the two libraries once: `mkdir n && cd n && npm i html2canvas@1.4.1 html-to-image@1.11.13 --ignore-scripts`, then copy `node_modules/html2canvas/dist/html2canvas.min.js` and `node_modules/html-to-image/dist/html-to-image.js` into `ext/`.
2. `python3 server.py &` (serves ports 8801 and 8802 on 127.0.0.1).
3. `chromium --user-data-dir=/tmp/tabspike-headful --load-extension=$PWD/ext --no-first-run http://127.0.0.1:8801/plain.html` (unbranded Chromium honours `--load-extension`; branded Chrome 137 and newer does not, see `tabs-spike.md` section 2).
4. In that window open a second tab at `http://127.0.0.1:8801/color.html` and switch back to the first. Open `chrome://extensions`, find "tabspike", click "service worker" to get its console. In that console you can call `state()`, `cvt(windowId)`, `dbg(tabId)`, `scr(tabId,'h2c')`, `tabcap(tabId, 700)`; add `.then(r=>show(r.url))` to see a picture on a new tab. Get ids from `await chrome.tabs.query({})`.

Questions, each with its pass condition:

1. **Does the SHOWN tab of a window on another workspace keep painting?** Put the Chromium window on workspace 2, stay on workspace 1, wait 30 s, then in the console call `show((await cvt(windowId)).url)` for that window id, and look at the colour against `state()`. Pass: current colour. Fail: stale or blank, which means we also need a different source for shown tabs (window thumbnails from the compositor already cover them, see `thumbnails-and-prior-art.md`). Repeat with another window fully covering it, and with it minimized (`captureVisibleTab` probably errors, record the message).
2. **Debugger on a hidden tab, headful.** With tab B hidden, run `await dbg(B)` five times, note the count of hangs (the run times out at 10 s) and whether a "started debugging this browser" bar appears, on which tab, and whether the page content jumps when you then switch to tab B while attached (call `chrome.debugger.attach({tabId:B},'1.3')` by hand and switch, then detach).
3. **Does html2canvas still return current content when the whole window is on another workspace?** `await scr(B,'h2c')` as in step 1.
4. **tabCapture grant survives a tab switch?** Click the extension toolbar icon while tab B is shown (this sets `self.invoked` and grants `activeTab` for B). Switch to tab A. In the console: `await tabcap(B, 700)`. Pass: a picture of B in `.url` and `gotFrame: true`. Also note whether a recording indicator shows in the tab strip and whether a stream still works 60 s later (repeat the call).
5. **Video and cross origin with the debugger.** Open `video.html` and `xorigin.html` as hidden tabs (create them while another tab is shown), run `dbg` and `scr(...,'h2c')`, compare. Pass: debugger shows the cross site frame (green) and a moving video colour.
6. **Intensive throttling.** Leave `color.html` hidden for 10 minutes, then `await dbg(B)` and read `state()`. Record whether the picture colour equals the page's `idx`, and the tick rate. This is the case I could not reach.
7. **Discarded tab on real Chrome (Memory Saver).** In `chrome://settings/performance` enable Memory Saver, let tab B sleep or call `chrome.tabs.discard(B)`, and confirm the new tab id and that no method returns a picture (matches RAN here).
8. **Real site spot check.** Repeat 2 and the html2canvas call on three real pages you do not mind capturing (one with video, one with a login you are signed out of). Judge the pictures by eye. I did not test any real site.

Sizes: also record picture size for a 480 px JPEG of those real pages, since my numbers come from synthetic images.

## 10. Reproducing the runs

`docs/research/spike-tab-preview/`: `ext/` (the scratch MV3 extension, `manifest.json`, `sw.js` with one function per method, offscreen consumer), `pages/` (colour page that changes every second and counts rAF frames, canvas, video, cross origin, CSP), `server.py` (two local ports, counts requests), `run.mjs` (main run: `node run.mjs 330 headless main`), `iso.mjs` (isolation run for the debugger hangs), `results/` (raw logs). The libraries are not committed (see setup step 1). Chromium runs used `ulimit -c 0 --disable-gpu --disable-software-rasterizer --use-gl=disabled --disable-crash-reporter --disable-breakpad`, one at a time. Earlier in the session the scratch Chromium crashed with SIGILL five times before these flags (each run left a core dump); after the flags, the three recorded runs and the isolation run completed with no new crash. The cause was not investigated beyond the GPU path.

Things the data does NOT show: that a run of 330 s covers intensive throttling; that any result carries over to GPU rendering or a Wayland compositor; that the debugger hang rate is the same headful; anything about real websites; the `activeTab` and indicator behaviour.
