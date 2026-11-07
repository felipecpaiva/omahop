# Spike: named profiles (v1.5)

A profile is a named bundle of settings, for example "work" (cards style, snapshot thumbnails, a few apps never listed) or
"gaming" (list style, step aside for fullscreen apps). The user switches between them without editing the file. This note
is the design; the chosen minimal version is built on branch `v1.5-profiles` (decision D19).

What the older notes said: `settings.md` "Later: profiles" and `feature-gap-analysis.md` C7, B37, F23 described a different
thing, per-shortcut profiles (each bound to its own chord, like BetterCmdTab). That needs a bind per profile and a repeating
group in the settings window, rated L. Named profiles switched by one setting give most of the value with neither, and do
not close the door: a later per-shortcut profile can name one of these bundles.

## 1. What a profile may override

Every setting in the spec, except:

| Setting | Why not |
|---|---|
| `takeover`, `modifier`, `same_app_key` | `reload = true`: they decide which binds exist, read once at load. A profile switch applies at the next Alt+Tab with no reload, so a profile value would be silently ignored until the next reload, which is worse than refusing it |
| `browser_tabs`, `browser_tabs_ignore` | Privacy. One place says whether tab titles are ever written to disk; a profile switch must never turn that on. They also drive a files script from two sides (Lua and QML) |
| `profile` | A profile cannot choose another profile (no chains, no loops) |
| `schema` | Hidden, describes the file |

The rule is metadata, not a list in code: a spec entry is overridable unless it has `reload`, `hidden` or `base_only`.
`config.lua` exports it as `C.overridable(rule)`, `tools/gen-spec.lua` writes it into `spec.json` as `overridable`, and the
QML side reads that flag. A new setting is overridable by default; marking it `reload` or `base_only` is the only way out.

## 2. Where profiles live

Options:

- (a) `[profiles.<name>]` tables in the same `config.toml`, with `[profiles.<name>.windows]` and `[profiles.<name>.keys]` for
  the nested sections. This is plain TOML (dotted table names).
- (b) One file per profile under `~/.config/omahop/profiles/<name>.toml`.

Chosen: (a). One file means one parser, one watcher in QML (`ConfigReader` already watches the file), one read per session
in Lua (already cached by text), and the settings window keeps editing one file with its line-preserving writer. (b) needs a
directory listing (Lua has no readdir; `find` would be one more detached helper) and a watcher per file. A profile name is
`[A-Za-z0-9_]+`, the same rule as keys; a table name with other characters is an unreadable line, as before.

Parser change: section headers now accept dots (`[profiles.work.windows]`) in both parsers, Lua `C.parse` and
`ConfigIO.parse`, and in `ConfigIO.range`, which finds the lines of a section when the settings window writes. Without that
last one a write to a top-level key would treat a profile's keys as top-level keys and could rewrite the profile's line.

## 3. How one is chosen

A top-level setting `profile` (text, default empty = no profile, group General). The settings window shows it as a choice row
whose values are "None" plus the names of the profiles found in the file. Hand-editing `profile = "work"` works the same.

Automatic choice (by the active workspace, by monitor count, by the focused app): a documented later step, not built. It is
not trivial: the choice would have to happen at the Alt+Tab press in Lua and at every frame in QML (the peek strip reads
config live), so the two sides could disagree for the same moment, and a rule language (`[profiles.work] when =
"monitors>1"`) is a new parser. If it comes, the shape is a pure `Profiles.pick(rules, context)` called only in Lua, which
then writes the chosen name to the state file for QML to read, so there is still one decision.

## 4. How it layers

For each setting in the spec, the value in use is the first valid one of: the active profile's value (only if the setting is
overridable), the base value, the default. So a bad value in a profile falls back to the base value, not to the default, and
is logged like any other bad value (`config: profiles.work.style = 5`). A profile key that is not overridable is logged
(`config: profiles.work.takeover: not overridable in a profile, ignored`) and ignored. An unknown profile name is logged and
the base settings are used. Keys a profile does not name keep the base value. Unknown keys inside a profile are ignored, as
they are in the base.

Built as `C.resolve(parsed)` in Lua (merge the base as before, then `C.apply_profile`), and `ConfigIO.resolve(parsed,
settings)` in JavaScript, with the same steps and the same problem strings. `C.merge` is unchanged, so every caller that
does not know about profiles keeps working.

## 5. The settings window

No new widget outside the window, no bar icon. Inside it:

- one more row in General, "Profile", drawn by the existing enum control, with "None" plus the profile names from the file;
- under any row the active profile overrides, one caption line: "Profile work sets this to Cards with thumbnails." The row
  itself still shows and edits the base value, so what the window writes is always the base; the caption explains why the
  switcher behaves differently.

Not built: creating, renaming or editing a profile's values in the window. That would need a second editing mode for every
row (edit base, edit profile) or a repeating group; profile bodies are written by hand in the file for now (the README and
`settings.md` show the shape). This is a known gap against the "one settings app for everything" principle, recorded in D19.

## 6. Precedence with the live ConfigReader

Lua reads the config at the start of each Alt+Tab (`reload_config`, cached by text) and passes `style`, `thumbnails`,
`border` and the rest to QML through the state file, so those follow the profile automatically. QML also reads a few
settings directly and live through `ConfigReader` (peek strip, icon theme, icon pack, thumbnail exclusions). Before this
change `ConfigReader.value` returned the raw file value with no validation. It now runs `ConfigIO.resolve` once per file
change and `value()` reads the result, so it applies the same layering and the same validation as Lua. Parity is a test:
`tests/config_io.test.mjs` runs fixtures through Lua `C.resolve` and JavaScript `ConfigIO.resolve` and compares every value
and every problem line.

## 7. Risks

- Two implementations of one rule (Lua and JavaScript). Mitigated by the parity test on shared fixtures, including bad values,
  non-overridable keys, unknown profiles and nested sections. A rule change in one file without the other fails run-all.
- The window cannot edit a profile's body (section 5).
- Older omahop versions read `[profiles.work]` as an unreadable line and then put the profile's keys into the previous
  section. A downgrade with profiles in the file mixes them into the base. Acceptable: the log names every unreadable line.
- Ordering: dotted tables can appear anywhere in the file; `ConfigIO.set` adds a new top-level key above the first table of
  any kind, so it never lands inside a profile.
- The word "profile" was used inside the glue for the same-app list (`on_tab(delta, profile)`); renamed to `list` so the two
  meanings do not mix.
