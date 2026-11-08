# omahop tabs: privacy policy

This is the privacy policy of the "omahop tabs" browser extension and its helper (the companion of omahop). Last updated 2026-11-08. The developer is Felipe Paiva; the project page is https://github.com/felipecpaiva/omahop.

## What is read

The extension reads, for every open tab in normal and popup windows: the tab id, the window id,
whether it is the selected tab, whether its window is focused, the page title and the address.
The site icon (the small logo of the site, taken from the browser's own icon cache, one per site) is also read, to show next to a found tab. It also reads whether Chrome put a tab to sleep. Nothing else: no page content, no history, no cookies, no form data.

Incognito windows are never read. The manifest sets `"incognito": "not_allowed"`, so the
extension cannot even be switched on there, and both the extension and the helper drop any
window marked incognito as a second guard.

## Where it goes

The extension talks to one program only: the local helper named `com.omahop.tabs`, started by the
browser over native messaging (standard input and output, no network). The browser checks that
only this extension may start the helper, and the helper itself refuses any other caller.

The helper writes one file per browser profile to `$XDG_RUNTIME_DIR/omahop/` (a folder only you
can open, mode 700; files mode 600). That folder is in memory, not on disk.

## What never happens

- Nothing is sent over the network. Neither the extension nor the helper has network code, and
  the extension has no required host permissions and no content scripts; the drawing script is injected only on request, from a library shipped inside the extension and never from the network (the optional all-websites permission for page pictures is described below).
- Titles and addresses are never logged, not even in error messages (tests check this).
- Site icons are written, like the tab file, only in the same private in-memory folder (`tabicons/`), only while the setting is on, never for hidden sites, and deleted when the setting goes off or the browser closes.
- Page pictures (optional) live in the folder `tabpics/` of the same private in-memory folder: only while both settings are on, never for hidden sites. They are kept while your browser stays open and deleted when you close it, turn the setting off, or the site is ignored.
- Nothing is written anywhere else, and nothing is kept on disk.

## Page pictures (optional, off by default)

A found tab normally shows the icon of its site. You can additionally allow small pictures of
the pages. This is separate and needs two steps from you: allowing it on the extension's options
page (Chrome then asks for a broad permission, to read and change data on all websites), and
turning on the page pictures setting in omahop. Until both are on, no picture is ever taken.

What it does: when a tab is shown, the extension takes a picture of that tab (Chrome only allows
a picture of the tab you see, so a picture can be a little old), shrinks it, and sends it to the
local helper. The helper keeps it in memory and in the same private in-memory folder as the tab
file, and omahop reads it from there. Pictures are never sent over the network, never logged,
never taken in incognito windows, and never kept for sites on your ignore list (the helper
drops them at once). They are kept in memory while your browser stays open, so a page you
visited earlier still shows its picture after you reload the extension or close the tab. They are
deleted when you close the browser, turn the setting off, or the site is ignored. Files are named
by hashes only (of the site and of the page address), never by a title or an address. The
permission is used for nothing else.

## Off by default

The helper writes nothing until omahop's "Browser tabs" setting is on (omahop creates the flag
file `tabs.enabled`). Turning the setting off removes the flag, and the helper deletes its file
within a second. You can keep the extension installed with the setting off and nothing is stored.

## Drawn pictures of tabs you have not opened (optional, off by default)

A photograph can only be taken of the tab you are looking at. A further step, off unless you turn it on, lets the extension also make a picture of a tab you have not opened lately: with omahop's setting `browser_tab_previews_draw` on (and page pictures on, and the permission allowed on the options page), the extension draws pictures of your other tabs quietly in the background after they load, one at a time and slowly (at most one every 3 seconds, at most 60 an hour, never for a page with a very large number of elements or a minimized window), so they are ready when you search. It runs a small script inside that page, without showing the tab, only to read what is on screen and draw it again on your computer. The page itself is not changed and the tab is never switched to. The result is approximate: images from some sites may come out blank and a video shows its first frame. To let the images that a site allows be drawn, the page's images are loaded once more in a mode (CORS) that lets them be read: same site, same data, no new destination. The picture goes to the helper like any other and is stored the same way (marked as drawn in its name, and never replacing a photograph of the same page). Chrome's own pages and the new tab page cannot get a picture. Nothing about this leaves your computer, and sites on your ignore list never get a picture (omahop's helper tells the extension the ignore list, which stays on your computer, so it can skip those sites).

## Why a tab has no picture

While page pictures are on, the extension tells the helper, for a tab that has no picture, one short code saying why: `browser` (a Chrome page, the new tab page or another page no extension can draw), `heavy`, `failed`, `blocked`, `queued` or `limit`. These reasons carry only a short code per tab, no titles and no addresses. The helper keeps them in memory, writes them into the tab file next to the tab, and omahop shows them as a small label. The helper accepts only those codes and nothing else. They are never logged and never leave your computer.

## Hiding sites

The ignore list in omahop's settings (written to `tabs.ignore`) hides sites by host name. The
helper drops those tabs before writing, so they never reach any file. See `file-contract.md`.

## Permissions the browser shows

`tabs` (needed to read titles and addresses; Chrome describes it as reading your browsing
history), `favicon` (to read the site icons from the browser's own icon cache, without any network request), `scripting` (to run the small drawing script in a page, only with the optional steps above) and `nativeMessaging` (to talk to the helper). The optional all-websites permission (`<all_urls>`) is requested only when you click the button on the options page, and is used only to take the picture of a shown tab and, with the drawing setting on, to draw a picture of other tabs from their own content.

## Removing everything

1. Turn off "Browser tabs" in omahop.
2. Remove the extension on the browser's extensions page.
3. Run `install/omahop-tabs-install --remove`: it deletes the helper registration files it wrote
   and any helper files left in the runtime folder.

## Questions

Open an issue at https://github.com/felipecpaiva/omahop/issues.
