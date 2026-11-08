# omahop tabs: privacy policy

This is the privacy policy of the "omahop tabs" browser extension and its helper (the companion of omahop). Last updated 2026-11-08. The developer is Felipe Paiva; the project page is https://github.com/felipecpaiva/omahop.

## What is read

The extension reads, for every open tab in normal and popup windows: the tab id, the window id,
whether it is the selected tab, whether its window is focused, the page title and the address.
The site icon (the small logo of the site, taken from the browser's own icon cache, one per site) is also read, to show next to a found tab. Nothing else: no page content, no history, no cookies, no form data.

Incognito windows are never read. The manifest sets `"incognito": "not_allowed"`, so the
extension cannot even be switched on there, and both the extension and the helper drop any
window marked incognito as a second guard.

## Where it goes

The extension talks to one program only: the local helper named `com.omahop.tabs`, started by the
browser over native messaging (standard input and output, no network). The browser checks that
only this extension may start the helper, and the helper itself refuses any other caller.

The helper writes one file per browser profile to `$XDG_RUNTIME_DIR/omahop/` (a folder only you
can open, mode 700; files mode 600). That folder is in memory and is gone at logout.

## What never happens

- Nothing is sent over the network. Neither the extension nor the helper has network code, and
  the extension has no required host permissions and no content scripts (the optional all-websites permission for page pictures is described below).
- Titles and addresses are never logged, not even in error messages (tests check this).
- Site icons are written, like the tab file, only in the same private in-memory folder (`tabicons/`), only while the setting is on, never for hidden sites, and deleted when the setting goes off or the browser closes.
- Page pictures (optional) follow the same rules in the folder `tabpics/`: only while both settings are on, never for hidden sites, deleted when the setting goes off or the browser closes.
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
drops them at once). They are deleted when you turn the setting off, remove the permission,
close the tab or close the browser. The permission is used for nothing else.

## Off by default

The helper writes nothing until omahop's "Browser tabs" setting is on (omahop creates the flag
file `tabs.enabled`). Turning the setting off removes the flag, and the helper deletes its file
within a second. You can keep the extension installed with the setting off and nothing is stored.

## Hiding sites

The ignore list in omahop's settings (written to `tabs.ignore`) hides sites by host name. The
helper drops those tabs before writing, so they never reach any file.

## Permissions the browser shows

`tabs` (needed to read titles and addresses; Chrome describes it as reading your browsing
history), `favicon` (to read the site icons from the browser's own icon cache, without any network request) and `nativeMessaging` (to talk to the helper). The optional all-websites permission (`<all_urls>`) is requested only when you click the button on the options page, and is used only to take the picture of a shown tab. The optional all-websites permission is requested only when you click the button on the options page, and is used only to take the picture of a shown tab.

## Removing everything

1. Turn off "Browser tabs" in omahop.
2. Remove the extension on the browser's extensions page.
3. Run `install/omahop-tabs-install --remove`: it deletes the helper registration files it wrote
   and any helper files left in the runtime folder.

## Questions

Open an issue at https://github.com/felipecpaiva/omahop/issues.
