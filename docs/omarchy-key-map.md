# Which keys Omarchy already uses

Measured 2026-11-08 on Omarchy 4.5 (stock bindings) with `python3 tools/key-map.py`, which reads `hyprctl binds -j` and prints the tables below. Run it again after you change your bindings. A chord is a modifier plus a key. omahop never takes a chord that is already bound (rule D14), so a taken chord is lost for omahop, not stolen.

What omahop needs from the held key: Tab and Shift+Tab to open and go back, then, while the list is up, Escape, Return, Delete, the arrows, the same-app backtick, and letters, digits, Space and Backspace for the search.

Note: the **Alt** row shows omahop's own binds while the plugin is loaded (Alt+Tab and Alt+Shift+Tab). Super and the combos show only Omarchy's and your binds.

| Held key | Tab | Shift + Tab | Session keys taken | Typing keys taken (of 38) |
|---|---|---|---|---|
| Alt | taken: __lua | taken: __lua | GRAVE | 1: SPACE |
| Ctrl | free | free | none | 1: SPACE |
| Super | taken: Next workspace | taken: Previous workspace | ESCAPE, RETURN, LEFT, RIGHT, UP, DOWN, GRAVE | 19 |
| Ctrl + Alt | taken: Focus on next monitor | taken: Focus on previous monitor | RETURN, DELETE, LEFT, RIGHT, UP, DOWN | 11: C D E F G I J K T U BACKSPACE |
| Super + Alt | taken: Next window in group | taken: Previous window in group | RETURN, LEFT, RIGHT, UP, DOWN | 6: F G K L S SPACE |
| Super + Ctrl | taken: Former workspace | free | RETURN, DELETE, LEFT, RIGHT | 22 |
| Super + Ctrl + Alt | free | free | DELETE, LEFT, RIGHT | 9: B C D E F R T W Z |

Free keys (neither the plain chord nor its Shift variant is bound):

- **Alt**: A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 0 1 2 3 4 5 6 7 8 9 F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
- **Ctrl**: A B C D E F G H I J K L M N O P Q R S T U V W X Y Z 0 1 2 3 4 5 6 7 8 9 TAB GRAVE F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
- **Super**: H R U Z 0 1 2 3 4 5 6 7 8 9 F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
- **Ctrl + Alt**: A B H L M N O P Q R S V W X Y Z 0 1 2 3 4 5 6 7 8 9 GRAVE SPACE F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
- **Super + Alt**: C D H I J N O P Q R T U V W Y Z 0 1 2 3 4 5 6 7 8 9 GRAVE F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
- **Super + Ctrl**: J M Q U Y 0 1 2 3 4 5 6 7 8 9 GRAVE F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12
- **Super + Ctrl + Alt**: A G H I J K L M N O P Q S U V X Y 0 1 2 3 4 5 6 7 8 9 TAB GRAVE SPACE F1 F2 F3 F4 F5 F6 F7 F8 F9 F10 F11 F12

## What this says

- **Alt** (default): Tab is replaced on purpose (omahop runs Omarchy's own Alt+Tab where it is not active). Everything else is free except the backtick.
- **Ctrl**: every chord is free, but apps use Ctrl+Tab (browser tabs, editors), so it is a taste choice.
- **Super**: not a single Super key is out of reach, but Omarchy uses Super for 50 plain and 47 Shift chords. Tab and Shift+Tab are Omarchy's workspace switch, and 19 typing keys, Escape, Return and the arrows are taken. Super as the held key would give a list you can open only by changing a trigger key, and a search that cannot type most letters.
- **Super + Alt**, **Super + Ctrl**, **Ctrl + Alt**: Tab is taken in each (group window cycle, former workspace, focus next monitor). Super + Ctrl has Shift+Tab free but not Tab.
- **Super + Ctrl + Alt**: Tab and Shift+Tab are both free, but it is three keys held, and 9 typing keys are taken.

## What we can build on this

The blocker is the pair (held key, trigger key), not the held key alone. Today the trigger key is always Tab (`M.trigger_key` in `lua/omahop.lua`). A setting `trigger_key` (decision D31: the user presses their own chord in a key capture field, checked against the live binds, never taking an existing bind, no Super default) would let the pair be any free chord on the list above, for example Super + a free letter or digit, or Ctrl + Alt + Grave. omahop can check the pair against the live binds and log why it did not bind. Typing keys that Omarchy owns would simply not type (the same rule as today), and the list could say which ones in the settings window. This is not built yet; it is planned on the roadmap (D31).

If your bindings change (Omarchy updates, your own `bindings.lua`), run the tool again: it is the source of truth, this page is a snapshot.
