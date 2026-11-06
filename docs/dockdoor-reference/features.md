# DockDoor feature reference (for Omarchy / Hyprland / Quickshell port)

Researched 2026-11-06 at v1.42.2. Sources: dockdoor.net, dockdoor.net/docs, github.com/ejbills/DockDoor (README, AGENTS.md, releases, `DockDoor/consts.swift` which holds every `Defaults.Keys` setting with its default). Setting names below are the real UserDefaults keys from consts.swift. "Pro" = separate paid app, excluded.

## 1. What it is

DockDoor is a free, GPL-3.0 macOS menu-bar app (Swift 5.10, SwiftUI + AppKit, `LSUIElement`, macOS 13+, Intel/ARM) that adds window previews to the native Dock, a window-level Alt+Tab style switcher (default Option+Tab, `UserKeybind` keyCode 48 + Option), and a Cmd+Tab overlay that shows the highlighted app's windows. Technically: it never replaces the Dock. It observes the Dock process through the Accessibility API (`AXObserver` on the Dock's item list, selected-item-changed notifications, `AXUIElement` role/frame reads) to know which icon the mouse is on, enumerates windows through AX plus private APIs (`_AXUIElementGetWindow`, CoreGraphics Services `CGS*` window capture with options nominal/best resolution, CoreDock calls for orientation, autohide and magnification), captures thumbnails with CGS/ScreenCaptureKit (needs Screen Recording permission; Accessibility permission for the rest), and streams live previews via ScreenCaptureKit with configurable quality and frame rate. Global keys use a CGEventTap (`EventTapThread`, `KeybindHelper`). Media info comes from the MediaRemote private framework through the `MediaRemoteAdapter` package, with AppleScript as fallback. Previews are borderless SwiftUI windows over the Dock. It also exposes an AppleScript/`osascript` command interface. Privacy claim: no servers, analytics or crash reporters (developer's claim, UNVERIFIED independently).

Wayland translation in one line: the Dock is the only macOS-specific part. On Omarchy the "dock" would be a Quickshell bar/taskbar or the workspace/floating-window list, and Hyprland IPC (`hyprctl clients -j`, socket2 events) plus `hyprland-toplevel-export-v1` or `ext-foreign-toplevel-image-capture-source` + `ext-image-copy-capture` replace AX + CGS capture.

## 2. Feature table

Portability: easy / medium / hard / impossible, for Hyprland 0.56 + Quickshell. Source column abbreviations: SITE = https://dockdoor.net/ ; DOCS = https://dockdoor.net/docs ; GH = https://github.com/ejbills/DockDoor ; REL = https://github.com/ejbills/DockDoor/releases ; CONSTS = https://github.com/ejbills/DockDoor/blob/main/DockDoor/consts.swift

### A. Dock hover previews

| ID | Feature | What it does (behavior, defaults) | Setting names | Source | Portability |
|----|---------|-----------------------------------|---------------|--------|-------------|
| D1 | Hover preview of app windows | Hover a Dock icon, a panel of that app's windows (thumbnails) appears; click one to focus it | `enableDockPreviews`=true, `dockPreviewActivationMode`=hover | SITE, GH | medium: needs a taskbar/dock surface in Quickshell that knows hovered icon; the shell owns it so hover is trivial |
| D2 | Open delay | Wait before showing on hover | `openDelay`=0.2s; `useDelayOnlyForInitialOpen`=false (delay only first open, moving between icons is instant) | CONSTS | easy |
| D3 | Alternate activation modes | Show on hover, middle-click, or modifier+click on icon | `dockPreviewActivationMode` (hover / middleClick / modifierClick), `dockPreviewActivationModifier`=option | CONSTS | easy |
| D4 | Preview size | Card size, lock aspect ratio, spacing multiplier | `previewWidth`=300, `previewHeight`=187.5, `lockAspectRatio`=true, `globalPaddingMultiplier`=0.7 | CONSTS | easy |
| D5 | Dynamic image sizing | Each card sized to its window's real aspect ratio instead of fixed box | `allowDynamicImageSizing`=false | SITE, CONSTS | easy |
| D6 | Position and anchoring | Panel placed above/beside the icon with a gap; anchored to the icon; gap default adapts to magnification and dock side | `bufferFromDock`, `anchorDockPreviewPosition`=true | CONSTS | easy |
| D7 | Grid rows/columns limits | Bottom dock caps rows, side docks cap columns, then scrolls | `previewMaxRows`=1, `previewMaxColumns`=2 | CONSTS | easy |
| D8 | Fade-out and dismissal timing | Panel lingers after the mouse leaves so you can move into it; reentry guard | `inactivityTimeout`=0.2s, `fadeOutDuration`=0.4s, `preventPreviewReentryDuringFadeOut`=false, `showAnimations`=true | CONSTS | easy |
| D9 | Prevent Dock autohide | Keeps an autohidden Dock visible while a preview is open | `preventDockHide`=false | CONSTS | easy (bar-specific) |
| D10 | Preview hover action | Hovering a card does nothing, activates the window ("tap"), or shows a full-size preview of it | `previewHoverAction`=none (none/tap/previewFullSize), `keepPreviewOnHoverActivation`=false | CONSTS | medium: full-size peek needs a second large capture surface or Hyprland window peek (`hyprctl dispatch` focus + focus-follows) |
| D11 | Dock icon click action | Clicking active app's icon minimizes or hides its windows; restore-all-minimized option | `dockClickAction`=hide (minimize/hide), `shouldHideOnDockItemClick`=false, `restoreAllMinimizedWindowsOnDockClick`=true | SITE, CONSTS | easy: "minimize" maps to special workspace move |
| D12 | Windowless apps | Optionally shows apps with no windows (with a big Quit control); can open a new window | `showWindowlessAppsInDockPreview`=false, `showBigControlsWhenNoValidWindows`=true, `showWindowlessAppQuitButton`=true, `openNewWindowForWindowlessApps`=false | CONSTS | easy: only meaningful with a launcher/pinned-app list |
| D13 | Group app instances | Multiple instances of one app grouped under one icon | `groupAppInstancesInDock`=true | CONSTS | easy |
| D14 | Native tab collapsing | Collapses native macOS tabs into one window entry | `collapseNativeTabsIntoSingleWindow`=false | CONSTS | n/a on Wayland (no native tabs); skip |
| D15 | Single-window app skip | Do not preview apps that have only one window | `ignoreAppsWithSingleWindow`=false (+`...InCmdTab`) | CONSTS | easy |

### B. Preview card contents

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D16 | Window title | Title under/over card; position (default bottom-left), overflow style (truncate middle default, marquee exists), font size, visibility always or on hover, display condition (all / only some) | `showWindowTitle`=true, `windowTitlePosition`=bottomLeft, `titleOverflowStyle`=truncateMiddle, `windowTitleFontSize`, `windowTitleVisibility`=alwaysVisible, `windowTitleDisplayCondition`=all, `disableDockStyleTitles` | CONSTS | easy |
| D17 | App name / icon header | App name (style option) or icon only in header | `showAppName`=true, `appNameStyle`, `showAppIconOnly`=false | CONSTS | easy (icon theme lookup via Quickshell `DesktopEntries`) |
| D18 | Traffic-light window controls | Quit, close, minimize, fullscreen buttons on each card; choose which; position (default top-left); visibility never / dimmed on hover (default) / full opacity on hover / always; monochrome option; scale | `enabledTrafficLightButtons`=[quit,close,minimize,toggleFullScreen], `trafficLightButtonsPosition`=topLeft, `trafficLightButtonsVisibility`=dimmedOnPreviewHover, `useMonochromeTrafficLights`=false, `trafficLightButtonScale`=1.0, `disableDockStyleTrafficLights` | SITE, CONSTS | easy: close=`closewindow`, quit=kill pid, minimize=move to special workspace, fullscreen=`fullscreen`. Close sent politely via `hyprctl dispatch closewindow` |
| D19 | Embedded controls | Put controls inside the preview frame instead of a floating pill | `useEmbeddedDockPreviewElements`=false, `useEmbeddedMediaControls`=true | SITE, CONSTS | easy |
| D20 | Control position in panel | Where the header/controls strip sits (topTrailing default) | `dockPreviewControlPosition`, `windowSwitcherControlPosition`, `cmdTabControlPosition` | CONSTS | easy |
| D21 | Minimized / Hidden badges | Cards labeled Minimized or Hidden | `showMinimizedHiddenLabels`=true | CONSTS, REL 1.42.0 | easy (special-workspace = "minimized") |
| D22 | Space number badge | Shows which Space (desktop) a window lives on | `showSpaceNumber`=false | CONSTS | easy: workspace id from `hyprctl clients` |
| D23 | Mass actions | Close all / minimize all windows of the app at once | `showMassActionButtons`=true | SITE, CONSTS | easy |
| D24 | Pinning | Pin windows to keep order/position in the list | `enablePinning`=true, `persistedWindowOrder` | CONSTS | easy |
| D25 | Middle-click close | Middle-click a card closes that window; red-button closes only that window | (mouse action, `MouseActionsSection`) | SITE, GH | easy |
| D26 | Active window border / selection styling | Border on active window; selected card opacity; unselected content dimmed; custom hover highlight color | `showActiveWindowBorder`=false, `selectionOpacity`=0.4, `unselectedContentOpacity`=0.75, `hoverHighlightColor` | CONSTS | easy |
| D27 | Card corner radius | Uniform radius for cards | `uniformCardRadius`=true, `previewCornerRadius`=20 | CONSTS | easy |

### C. Capture: static vs live

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D28 | Static thumbnails with cache | Window screenshot cached; refreshed after lifespan; capture quality nominal or best; image scale; debounce on window processing | `screenCaptureCacheLifespan`=30s, `windowImageCaptureQuality`=nominal (nominal/best), `windowPreviewImageScale`=1, `windowProcessingDebounceInterval`=0.3s | CONSTS | medium: Hyprland needs `hyprland-toplevel-export-v1` (Quickshell `ScreencopyView` supports it); works for floating and tiled alike |
| D29 | Live preview (video stream) | Cards play the window live; separate toggles for dock and switcher; Dock default on (when live master on), switcher off | `enableLivePreview`=false (master), `enableLivePreviewForDock`=true, `enableLivePreviewForWindowSwitcher`=false | SITE, CONSTS | medium: Quickshell `ScreencopyView { live: true }` does exactly this; cost scales with number of cards |
| D30 | Live quality and frame rate | Quality ladder thumbnail 320px / low 480 / standard 640 / high 960 / retina 1280 / native; fps choices (dock 24, switcher 10 default) | `dockLivePreviewQuality`=high, `dockLivePreviewFrameRate`=fps24, `windowSwitcherLivePreviewQuality`=low, `windowSwitcherLivePreviewFrameRate`=fps10 | CONSTS | medium: scale via capture size; fps capped by frame callbacks |
| D31 | Live scope in switcher | Live only selected window / selected app's windows (default) / all | `windowSwitcherLivePreviewScope`=selectedAppWindows | CONSTS | easy once D29 exists, important perf lever |
| D32 | Stream keep-alive | Keep a stream open N seconds after the panel closes so reopening is instant | `livePreviewStreamKeepAlive`=0 | CONSTS, REL 1.42.0 | medium |
| D33 | Disable image preview | Show only title/icons, no captures | `disableImagePreview`=false | CONSTS | easy |
| D34 | Min window size filter | Ignores tiny windows (popups, helpers) | `disableMinWindowSizeFilter`=false | CONSTS | easy |

### D. Compact (list) mode

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D35 | Compact list layout | Text rows instead of thumbnails; title format app+title default; size small/medium/large; optional hide of traffic lights | `compactModeTitleFormat`=appNameAndTitle, `compactModeItemSize`=medium, `compactModeHideTrafficLights`=false | SITE, CONSTS | easy |
| D36 | Auto-compact threshold | Switch to list when window count passes N (0 = never), separately for dock / switcher / cmd-tab | `dockPreviewCompactThreshold`=0, `windowSwitcherCompactThreshold`=0, `cmdTabCompactThreshold`=0 | CONSTS | easy |

### E. Window switcher (Option+Tab)

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D37 | Window-level switcher | Lists every window (not app); hold modifier, tap Tab to advance, release to commit | `enableWindowSwitcher`=true, `UserKeybind` (Option+Tab) | SITE, GH | medium: needs a Hyprland submap or per-key binds (`bind` + `bindr` release); modifier-release detection is the hard part (use `bindrt`/submap with `catchall`) or a layer-shell surface with keyboard-interactive focus |
| D38 | Hold-to-cycle / instant | `instantWindowSwitcher` opens with no delay; `preventSwitcherHide` keeps it open | `instantWindowSwitcher`=false, `preventSwitcherHide`=false | CONSTS | medium |
| D39 | Combinable modifiers + multiple alternate shortcuts | Several shortcuts, each with own key, modifiers (Ctrl/Opt/Cmd combos) and filter mode (v1.42.0) | Settings > Gestures > Window Switcher > Alternate Shortcuts | REL 1.42.0, 1.42.3b1 | easy: just multiple binds into the same IPC |
| D40 | Backward cycling | Shift+Tab, or require explicit shift; configurable back key | `requireShiftTabToGoBack`=false, `switcherBackwardKeyCode`=56 (Shift) | CONSTS | easy |
| D41 | Layout and scrolling | Rows (max 8), scroll direction vertical/horizontal, ignore screen limit | `switcherMaxRows`=8, `windowSwitcherScrollDirection`=vertical, `switcherIgnoreScreenLimit`=false | CONSTS | easy |
| D42 | Placement | Open on screen with mouse (default), screen of last active window, or pinned screen; percent offsets, anchor to top, shift-key placement | `windowSwitcherPlacementStrategy`=screenWithMouse, `pinnedScreenIdentifier`, `windowSwitcherHorizontalOffsetPercent`/`VerticalOffsetPercent`=0, `windowSwitcherAnchorToTop`=false, `enableShiftWindowSwitcherPlacement`=false | CONSTS | easy: Quickshell per-screen `Variants` |
| D43 | Search | Type to filter windows; fuzzy match; trigger key `/`; optional auto-focus search on open | `enableWindowSwitcherSearch`=false, `searchTriggerKey`=/, `focusSearchOnWindowSwitcherOpen`=false, `searchFuzziness`=3 | SITE, CONSTS | easy (fuzzy match in QML or `fzf`-like JS); focus handling is the work |
| D44 | Keyboard navigation | Arrow keys; optional Vim motions (hjkl); pass arrows to system; preview shortcuts for close/minimize/hide/quit while the modifier is held (v1.42.1) | `enableVimMotions`=false, `passArrowsThroughToSystem`=false | CONSTS, REL 1.42.1 | easy once keyboard-grabbing layer surface exists |
| D45 | Mouse hover in switcher | Hover selects card; auto-scroll speed near edges | `enableMouseHoverInSwitcher`=true, `mouseHoverAutoScrollSpeed`=4.0 | CONSTS | easy |
| D46 | Trackpad swipe in switcher | Swipe sensitivity for trackpad-driven switcher | "Trackpad switcher swipe" section, swipe sensitivity (v1.41.0) | REL 1.40.8b2, 1.41.0 | hard: libinput gestures only via Hyprland `gesture` binds, no per-surface gesture data |
| D47 | Sort order | recentlyUsed (default), creationOrder, screenPosition, alphabeticalByTitle, alphabeticalByAppName; minimized last option; separate per mode | `windowSwitcherSortOrder`, `windowPreviewSortOrder`, `cmdTabSortOrder`, `sortMinimizedToEnd`=false, `useClassicWindowOrdering`=true | CONSTS, REL 1.42.0 | easy: needs MRU tracking via `activewindowv2` events (Hyprland already has `focusHistoryID` in `hyprctl clients -j`) |
| D48 | Scope filters | Current Space only, current monitor only, per mode (dock / switcher / cmd-tab) | `showWindowsFromCurrentSpaceOnly(InSwitcher/InCmdTab)`, `showWindowsFromCurrentMonitorOnly(...)` all false | CONSTS | easy |
| D49 | Include hidden / windowless apps | Hidden windows and windowless apps appear in switcher (default true / true) | `includeHiddenWindowsInSwitcher`=true, `showWindowlessAppsInSwitcher`=true | CONSTS | easy |
| D50 | Limit to frontmost app | Switcher only cycles the frontmost app's windows (like macOS Cmd+`) | `limitSwitcherToFrontmostApp`=false | CONSTS | easy: filter by class |
| D51 | Mouse follows focus | After committing, move cursor to the window: never / always / only if different display | `mouseFollowsFocusMode`=never | CONSTS | easy: `hyprctl dispatch movecursor` (Hyprland also has `cursor:warp_on_change_workspace`) |
| D52 | Switcher-specific appearance | Own header/title/icon size/traffic-light config separate from dock preview | `switcherShowAppHeader`, `switcherShowWindowTitle`, `switcherAppIconSize`, `switcherEnabledTrafficLightButtons`, etc. | CONSTS | easy |
| D53 | Selection survives events | Switcher does not jump to a window you just minimized/hid; keeps preview when app terminates option | `keepPreviewOnAppTerminate`=false | REL 1.42.1, CONSTS | easy |
| D54 | Fullscreen app blacklist | Switcher shortcut disabled when listed fullscreen apps (games) are focused | `fullscreenAppBlacklist`=[] | CONSTS | easy: Hyprland submap or check `fullscreen` in `activewindow` |

### F. Cmd+Tab overlay

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D55 | Cmd+Tab window strip | While the native app switcher is open, shows windows of the highlighted app above it; extra cycle key to move between those windows, backward key | `enableCmdTabEnhancements`=false, `cmdTabCycleKey`=A, `cmdTabBackwardCycleKey`=` (grave), `cmdTabAutoSelectFirstWindow`=false | SITE, GH | impossible as stated (no native switcher to augment). The idea collapses into D37 with an app-grouped mode |
| D56 | Cmd+Tab appearance, sort, filters | Separate title/traffic-light/position settings and filters | `cmdTab*` keys (see consts) | CONSTS | n/a, same as D52 |

### G. Widgets and media

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D57 | Media widget | Hover an app playing audio: a player (art, title, play/pause/next/prev, seek) shows in the preview; pin to desktop; synced lyrics for Spotify / Apple Music | `enableMediaWidget`=true, `mediaDetectionMode`=universal (universal / appleScriptOnly), `showSpecialAppControls`=true | SITE, GH, CONSTS | easy: MPRIS via Quickshell `Mpris` service; lyrics need an external API (UNVERIFIED which source DockDoor uses) |
| D58 | Media scroll behaviors | Scroll on dock icon of playing app adjusts volume (default) ; scroll on widget seeks (default), direction vertical | `dockIconMediaScrollBehavior`=adjustVolume, `mediaWidgetScrollBehavior`=seekPlayback, `mediaWidgetScrollDirection`=vertical | CONSTS | easy |
| D59 | Calendar widget | Hover Calendar app shows rest of today's events; calendar filter | `enableCalendarWidget`=true, `filteredCalendarIdentifiers`=[] | SITE, GH, CONSTS | hard/low value: no Calendar app on Omarchy; skip |
| D60 | Folder Pop | Hover a Dock folder to browse, sort (default date modified, reversed), open, drag files to other apps; hidden files toggle; per-folder sort memory | `enableFolderWidget`=false, `folderWidgetDefaultSortOrder`=dateModified, `folderWidgetDefaultSortReversed`=true, `folderWidgetRememberSortPerFolder`=true, `folderWidgetShowHiddenFiles`=false | SITE, GH | medium: needs a dock with folders (not an Omarchy concept); drag-and-drop to other windows is the hard part |
| D61 | Widget app filters / container look | Which apps get widgets; hide widget container background | `widgetAppFilters`=[], `hideWidgetContainerBackground`=false | CONSTS | easy |

### H. Appearance

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D62 | Background style | liquidGlass (default, macOS 26+), frosted material (ultraThin default), or clear; glass opacity, saturation, blur radius, refraction, tint opacity, border width/opacity | `dockBackgroundStyle`=liquidGlass, `dockBackgroundMaterial`=ultraThin, `dockGlassOpacity`=0.95, `dockGlassSaturation`=1.8, `dockGlassBlurRadius`=0, `dockGlassRefraction`=true, `dockBackgroundTintOpacity`=0.18, `dockBackgroundBorderOpacity`=0.15, `dockBackgroundBorderWidth`=1 | SITE, CONSTS | medium: blur = Hyprland `layerrule = blur` on the Quickshell namespace (works, with `ignorealpha`); refraction/liquid glass impossible, fake with tint+border |
| D63 | Theme / appearance mode | System / light / dark; custom background colour; opaque background | `appAppearanceMode`=system, `customBackgroundColor`, `useOpaquePreviewBackground`=false | CONSTS | easy: follow Omarchy theme colors (themed Quickshell palette) |
| D64 | Opacity and hiding of backgrounds | Panel opacity; hide card background; hide hover container background | `dockPreviewBackgroundOpacity`=1.0, `hidePreviewCardBackground`=false, `hideHoverContainerBackground`=false | CONSTS | easy |
| D65 | Shadow | Optional drop shadow under cards | `showPreviewShadow`=false, `previewShadowRadius`=8, `previewShadowOpacity`=0.2 | CONSTS | easy (Hyprland shadow per layer via layerrule is limited; do in QML) |
| D66 | Animated gradient palette | Fluid gradient background colors (custom palette) | `gradientColorPalette` | CONSTS | easy, cosmetic, low priority |
| D67 | Raised window level | Panel above fullscreen/other windows | `raisedWindowLevel`=true | CONSTS | easy: layer-shell `overlay` layer |
| D68 | Active app indicator | Dot/bar under the Dock icon of the active app; color, auto size/length | `showActiveAppIndicator`=false, `activeAppIndicatorColor`=accent, `activeAppIndicatorAutoSize`=true, `activeAppIndicatorAutoLength`=false | CONSTS, REL | easy (bar module) |

### I. Gestures and mouse actions

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D69 | Window Gestures (off by default) | Two-finger swipes on a window title bar snap to halves/corners/full; swipes on Dock icons minimize/restore; swipes on the menu bar switch apps; haptics, sensitivity, snap-area preview | Gestures tab, per-gesture toggles | REL 1.41.0, SITE | hard: title-bar hit-testing of foreign windows is not possible in Wayland; snapping is covered by omagnet/Magnet-like work anyway |
| D70 | Dock scroll gesture | Scroll on a Dock icon activates/hides the app (default) or brings its windows to current Space | `enableDockScrollGesture`=false, `dockIconScrollBehavior`=activateHide | SITE, CONSTS | easy on our own bar: `MouseArea` onWheel |
| D71 | Title-bar scroll to center | Scroll on a title bar centers/resizes the window to scale 0.8 (uniform or separate w/h), restore interval 1.5s | `enableTitleBarScrollGesture`=false, `titleBarScrollCenteredWindowScale`=0.8, `titleBarScrollCenteredWindowSizingMode`=uniform, `titleBarScrollRestoreWindowInterval`=1.5 | CONSTS | hard (title bar) / easy as keybind: center + resize via `hyprctl` |
| D72 | Swipe on preview to minimize/maximize | Two-finger swipe on a card minimizes or maximizes that window | (TrackpadGestureModifier) | SITE | medium: Quickshell can handle pointer wheel/touch on its own cards, true 2-finger swipe via `PinchHandler`/`DragHandler` on touch only |
| D73 | Aero shake | Shake a preview card (drag) to minimize all other windows (all / all except) | `aeroShakeAction`=none | SITE, CONSTS | medium: drag detection on our own surface; acting on others is easy |
| D74 | Quick quit | Cmd+right-click quits app, +Option force quits; clicking active icon minimizes | `enableCmdRightClickQuit`=true | SITE, GH | easy |
| D75 | Quit on last window close | Auto-quit app when its last window closes, with exclusion list; safeguards (not while locked, not menu-bar apps, cancelled if windows elsewhere) | `quitAppOnWindowClose`=false, `quitAppOnWindowCloseExcludedApps`=[] | CONSTS, REL 1.41.1b1 | medium: Hyprland `closewindow` event + client count per pid |
| D76 | Dock lock to one display | Pin Dock to one display, override with modifier | `enableDockLocking`=false, `lockedDockScreenIdentifier`, `dockLockOverrideModifier`=option | SITE, CONSTS | easy (bar on one monitor is just config) |

### J. Filters, ignore lists

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D77 | App-name filter | Hide apps by name from previews | `appNameFilters`=[] | CONSTS | easy (match `class`/`initialClass`) |
| D78 | Window-title filter | Hide windows by title substring | `windowTitleFilters`=[] | CONSTS | easy |
| D79 | Blacklist / whitelist | Open issue asks for whitelist mode too (UNVERIFIED if shipped) | n/a | GH issues | easy |
| D80 | Custom app directories | Extra dirs scanned for apps | `customAppDirectories`=[] | CONSTS | easy (desktop entries) |
| D81 | Grouped apps in switcher | Collapse listed apps' windows into one entry | `groupedAppsInSwitcher`=[] | CONSTS | easy |
| D82 | Never auto-quit list | See D75 exclusions | `quitAppOnWindowCloseExcludedApps` | REL 1.41.1b1 | easy |

### K. Multi-monitor, Spaces, Stage Manager

| ID | Feature | What it does | Setting names | Source | Portability |
|----|---------|--------------|---------------|--------|-------------|
| D83 | Cross-Space and cross-display listing | Windows on other desktops/displays, minimized and hidden ones, are all listed and focusable | `showWindowsFromCurrentSpaceOnly`, `...MonitorOnly` (D48) | SITE | easy: `hyprctl clients -j` has workspace + monitor; focus via `focuswindow address:` |
| D84 | Per-monitor panel placement | Switcher/preview opens on the right screen (see D42) | `windowSwitcherPlacementStrategy` | CONSTS | easy |
| D85 | Reserve screen space for third-party dock | Reserve an edge and size; apps report own space; AppleScript command | (Dock Previews settings) | REL 1.41.0 | easy: layer-shell exclusive zone does this natively |
| D86 | Tiling WM compat | Fixes for AeroSpace / yabai workspace switching | n/a | REL 1.42.0 | n/a |
| D87 | Stage Manager awareness | Accounts for the Stage Manager strip | n/a | REL 1.41.0 | n/a, skip |

### L. Automation, config, platform

| ID | Feature | What it does | Setting names / commands | Source | Portability |
|----|---------|--------------|--------------------------|--------|-------------|
| D88 | AppleScript/CLI | `show preview "App" [at "x,y"] [dock frame "x,y,w,h"] [with delay true]`, `hide preview`, `show switcher`; window actions `focus/minimize/close/maximize/hide window`, `toggle fullscreen`, `center window`, `position window "active" to left/right/top/bottom/top-left/...`; queries `list apps`, `list windows ["App"]`, `get active window`, `get window id`, `get windows` (JSON with base64 preview), `get help`. Lets Karabiner/BTT trigger the switcher | `osascript -e 'tell application "DockDoor" to show switcher'` | DOCS | easy: map to `qs ipc call` (Quickshell IpcHandler) so `bind = ALT, Tab, exec, qs ipc call switcher toggle` works |
| D89 | Settings export/import (JSON) | Backup and restore, with version warnings | Settings > Advanced | REL 1.40.8b1, 1.41.0 | easy |
| D90 | Settings search + live preview | Search in sidebar; live mock preview pinned at top of Settings (v1.42.0); show/hide descriptions | `showSettingsDescriptions`=true | REL 1.42.0, GH AGENTS.md | medium: only if we build a GUI settings app; otherwise a config file |
| D91 | Accessibility | Reduce Motion support; VoiceOver on traffic lights and media controls (v1.42.0) | n/a | REL 1.42.0 | medium: honor a reduce-animations flag; Orca/AT-SPI from Quickshell is limited (UNVERIFIED) |
| D92 | Debug logging | Debug mode with exportable local logs | `debugMode`=false | SITE | easy |
| D93 | Updates, menu-bar icon, i18n | Sparkle-style self-update, menu-bar icon toggle, Crowdin translations (30+ languages claimed) | `showMenuBarIcon`=true | SITE | n/a (pacman/AUR) |
| D94 | Parall integration | Previews for apps launched via Parall (multi-instance) | n/a | REL 1.40.6/1.40.7, SITE | n/a |
| D95 | Permissions flow | Needs Accessibility + Screen Recording; permission checker view | `lastKnownScreenRecordingPermission` | SITE | n/a: Wayland uses portal/protocol access instead; capture protocols are compositor-wide, no prompt on Hyprland |

## 3. Worth porting first (ranked)

1. D37 + D47 + D48 Window-level switcher with MRU order and workspace/monitor scope. Core value; maps to `hyprctl clients -j` focus history. Submap/modifier-release handling is the main risk.
2. D1 + D2 + D18 Hover preview panel from a taskbar/window-list with title, icon and close/minimize/quit controls. The signature feature, all data available over Hyprland IPC.
3. D28 + D29 + D31 Static then live thumbnails via Quickshell `ScreencopyView`, with live scope limited to selected app (perf lever). Without thumbnails the idea has no point.
4. D43 + D44 Search plus keyboard nav (arrows, optional Vim keys, Shift-Tab). Cheap, and big win on floating workspaces with many windows.
5. D88 IPC command surface (`qs ipc call`: show switcher, show preview, list windows, position window). Gives keybind integration and is the seam for tests.
6. D35 + D36 Compact list mode with auto-threshold. Thumbnails get costly past ~8 windows; the list is the cheap fallback.
7. D62 + D63 Themed background with Hyprland layer blur following the Omarchy theme. Needed so it does not look foreign.
8. D75 + D77 + D78 Filter lists (app class, title) plus min-size filter (D34). Prevents junk windows (popups, tray helpers, scratchpads) in the list.

Runners-up: D57 MPRIS media widget (easy, nice), D42 per-monitor placement, D50 limit to frontmost app (Cmd+` equivalent), D51 mouse follows focus.

## 4. Do not port

- D55/D56 Cmd+Tab overlay: augments a native switcher that Hyprland lacks; folded into D37.
- D59 Calendar widget: no Calendar app, low value.
- D60 Folder Pop: needs a dock with folders and cross-window drag-drop.
- D62 Liquid Glass refraction: macOS 26 compositor effect, not available; use blur plus tint.
- D69 Window gestures on title bars/menu bar and D71 title-bar scroll: Wayland does not let a shell hit-test foreign title bars; snapping belongs to omagnet.
- D46/D72 Trackpad swipe on switcher/previews: no per-surface multitouch for a layer surface (Hyprland `gesture` binds only global).
- D14 Native tab collapsing, D86/D87 yabai/Stage Manager, D93 updater, D94 Parall, D95 permissions flow: macOS-only.
- D66 Animated gradient and D90 settings search GUI: cosmetic or heavy, defer.
- DockDoor Pro (dock replacement, per-display docks, app profiles): paid separate app, out of scope.

## 5. What users say it lacks (short)

- GitHub open feature requests (top of tracker, 2026-11): Option+1..9 jump to Nth dock item; adjustable open delay for switcher; window search inside Cmd+Tab; general app blacklist for switcher shortcuts (not only fullscreen); grid view for both primary and secondary shortcuts; notification badges in switcher; least-recently-used sort; monitor number on each window in multi-monitor; whitelist as well as blacklist; hover actions in compact mode; dot colour for apps with windows.
- Open bugs: windows disappear from switcher after changing Spaces; apps with non-standard window layers show no preview (tracked); calendar widget crash; Logitech thumb-wheel scroll consumed.
- Third-party write-ups: sits on top of the Dock (not a replacement), a competing dock author claims no multi-monitor docks or folder stacks (biased source); Softpedia notes some thumbnail drawbacks inherent to macOS capture (details not visible, UNVERIFIED). Largely praised on r/macapps for the switcher and previews.
- Lesson for the port: the recurring pain is window enumeration reliability (apps with odd layers, Space changes). On Hyprland the compositor owns the window list, so this class of bug mostly disappears.

## Unverified / not read

- Lyrics provider for the media widget; exact `WindowAction` enum members beyond the four defaults; Pro feature details beyond the SITE blurb; release history before 1.40.6 (only 10 releases read); wiki (none found); reviews beyond search snippets.
