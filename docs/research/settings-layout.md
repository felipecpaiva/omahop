# Settings window layout (research for D24)

Question: the settings window is one long scroll (nine groups, 40 settings, long help text under each). How do good apps keep a long settings list usable, and what fits omahop?

Method: web search and page fetches on 2026-11-09. Where a page could not be read (GNOME HIG, Apple HIG, KDE HIG returned no body text), the claim below is marked "snippet" or "not verified" and is not used as a reason.

## What the sources say

| Pattern | Who does it | Finding | Source |
|---|---|---|---|
| Side list of categories, one page at a time | VS Code (table of contents tree with a Commonly Used group first), Firefox (2024 to 2026 redesign moved top level categories to a left list and removed the mixed General page), KDE System Settings (sidebar categories, sidebar names kept consistent), GNOME (libadwaita preferences are pages and groups) | Every large settings UI splits by category and shows one at a time. Firefox dropped a catch-all General page because it held unrelated controls | [VS Code settings](https://code.visualstudio.com/docs/configure/settings), [Mozilla Connect thread](https://connect.mozilla.org/t5/discussions/firefox-settings-design-share-your-input/m-p/66410), [PCWorld on the redesign](https://pcworld.com/article/3169719/mozilla-is-making-it-easier-to-customise-settings-in-firefox.html), [KDE sidebar consistency patch](https://phabricator.kde.org/D24270), [libadwaita PreferencesDialog](https://gnome.pages.gitlab.gnome.org/libadwaita/doc/1.7/class.PreferencesDialog.html) |
| Tabs | macOS app settings windows (toolbar tabs, from the usual SwiftUI Settings scene; Apple's page was not readable, so this is general knowledge) | Fine for 3 to 6 tabs; a 7th plus nested groups wraps or truncates. A side list scales better for a growing list | not verified |
| Sub groups inside a page | libadwaita (groups with titles inside a page), VS Code (headings inside a tree node) | Titled groups keep one page scannable | libadwaita and VS Code links above |
| Progressive disclosure, "Advanced" fold | Nielsen Norman Group; VS Code (`@tag:advanced` settings hidden by default) | Move secondary options to a secondary area, keep two levels at most (a third makes users lose their place), say clearly what is behind the link, and do not hide things people need often. Decide the split from usage, not taste | [NN/g progressive disclosure](https://www.nngroup.com/articles/progressive-disclosure/), VS Code link above |
| Search box | VS Code, libadwaita (built in, off by default), Firefox, KDE | Used where the list is in the hundreds. I found no source that gives a size at which search pays off | links above; no threshold found |
| Show changed or modified | VS Code (modified bar, `@modified`), KDE (Highlight Changed Settings, with bugs about empty categories and missed pages) | Useful, but costs a feature per row and was buggy in KDE. Out of scope here (the existing "Reset to default" link already marks a changed row) | [KDE bug 518868](https://bugs.kde.org/show_bug.cgi?id=518868), [KDE bug 432953](https://bugs.kde.org/show_bug.cgi?id=432953) |
| Dependent options | practitioner and design system guidance (not primary research) | Hide an input control whose value is irrelevant; disable instead when the user should know the option exists; avoid layout jumps. Buttons stay visible | [WebAIM thread](https://webaim.org/discussion/mail_message?id=32872), [Unity UX essentials](https://www.foundations.unity3d.com/fundamentals/ux-essentials) |

Omarchy's own apps and shell plugins: the shell's Ui library has `Button`, `ButtonGroup` (a row of chips), `PanelSectionHeader`, `Toggle`, `NumberField`, `TextField` and no sidebar or tab widget; the stock panels (clock, weather, audio) are single small panels, and the third party plugins here (omagnet) are one scrolling page. So no Omarchy convention conflicts with a side list, and it can be built from `Button` and `PanelSectionHeader` with nothing new.

## Our case

40 settings, 7 categories, 21 of them long help paragraphs. Count after the change: General 7, Windows 9, Look 9, Keys 6, Peek strip 2, Browser tabs 4, Touchpad swipe 3. Of these, 14 are advanced (folded) and 11 are dependents (hidden while their switch is off), so the first view of any category is at most about 6 rows.

## Recommendation

| Choice | Decision | Why |
|---|---|---|
| Category navigation | Side list, one category at a time | Same pattern as VS Code, Firefox, KDE, GNOME; grows by adding a group, 7 entries fit without wrapping |
| Sub groups | Titled sub headings inside a category (`subgroup` in the spec) | libadwaita and VS Code pattern; keeps a page scannable |
| Advanced fold | One "Show advanced settings (n)" button at the end of a category; `advanced = true` on rare settings | NN/g: two levels only, label says what is behind it; one fold per category, not per sub group |
| Dependents | Nest under the parent (indent), hide while the parent is off (`depends`) | Hide inputs that do nothing; removes about 11 rows from the default view |
| Search box | Not now | Seven one click categories and about 6 visible rows each; sources use search at hundreds of settings and give no smaller threshold. Revisit when a category passes about 12 visible rows or the total passes about 60 |
| Tabs, modified highlight | No | Tabs do not scale; the reset link already marks changed rows |
