"""Live checks of omahop with real key events (virtual keyboard through /dev/uinput) on a spare workspace with three coloured windows.
Needs a running Hyprland, kitty, grim, write access to /dev/uinput. Loads lua/omahop.lua into the running Hyprland with `hyprctl eval`
(replacing the stock Alt+Tab until the end) and puts everything back with `hyprctl reload`. Keep your hands off the keyboard (about 1 minute).
Your own ~/.config/omahop/config.toml is saved and put back. Usage: python3 tests/live.py"""
import os, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, ev, pixel, read_state, sh
from uinput_kbd import Keyboard

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def alt_tab(kb, tabs=1, hold=0.0, shift=False, release_alt=True):
    kb.down("alt")
    if shift:
        kb.down("shift")
    for _ in range(tabs):
        kb.down("tab"); time.sleep(hold); kb.up("tab")
    if shift:
        kb.up("shift")
    if release_alt:
        kb.up("alt")
    time.sleep(0.5)


# The test windows live on a spare workspace; limit the list to the current workspace so the user's own windows on other floating
# workspaces are not part of the test (this also exercises the config file). The file is removed afterwards unless the user had one.
CFG = os.path.expanduser("~/.config/omahop/config.toml")
had_cfg = os.path.exists(CFG)
saved_cfg = open(CFG).read() if had_cfg else None  # the user's own settings are put back at the end
os.makedirs(os.path.dirname(CFG), exist_ok=True)
open(CFG, "w").write('[windows]\nworkspaces = "current"\n')
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare() as sp, Keyboard() as kb:
        # creation order A, B, C: C is focused, recently used order is C, B, A
        check("start: C focused", active_class() == "omahop-C", active_class())

        alt_tab(kb)
        check("quick tap goes to the previous window (B)", active_class() == "omahop-B", active_class())
        check("and B is on top of the others", pixel(900, 600) == "B", pixel(900, 600))
        check("no overlay state left open", read_state().get("open") == "0", str(read_state()))

        alt_tab(kb)
        check("tap again flips back (C)", active_class() == "omahop-C", active_class())

        sp.reset_order()
        alt_tab(kb, tabs=2)
        check("hold Alt, Tab twice, release: third window (A)", active_class() == "omahop-A", active_class())
        check("and A is on top", pixel(900, 600) == "A", pixel(900, 600))

        sp.reset_order()
        alt_tab(kb, shift=True)
        check("Shift+Tab goes to the last window (A)", active_class() == "omahop-A", active_class())

        sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.3)
        st = read_state()
        check("session open and revealed while Alt is held", st.get("open") == "1" and st.get("revealed") == "1", str(st))
        layers = sh("hyprctl", "layers", "-j")
        check("overlay layer is on screen while revealed (needs the plugin enabled)", '"omahop"' in layers, "plugin not enabled? omarchy plugin list")
        kb.down("escape"); kb.up("escape"); time.sleep(0.2); kb.up("alt"); time.sleep(0.5)
        check("Alt+Escape cancels: focus stays on C", active_class() == "omahop-C", active_class())
        check("overlay layer is gone after cancel", '"omahop"' not in sh("hyprctl", "layers", "-j"))
        check("closed after cancel", read_state().get("open") == "0", str(read_state()))

        sp.reset_order()
        kb.down("alt"); kb.down("tab"); time.sleep(0.4)
        seen = []
        for _ in range(8):  # sample while Tab is held; with 3 windows the selection wraps, so count changes, not the final value
            seen.append(read_state().get("selected")); time.sleep(0.1)
        kb.up("tab"); kb.up("alt"); time.sleep(0.5)
        changes = sum(1 for a, b in zip(seen, seen[1:]) if a != b)
        check("holding Tab repeats (the selection keeps moving by itself)", changes >= 3, str(seen))

        sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); kb.down("right"); kb.up("right"); time.sleep(0.2); kb.up("alt"); time.sleep(0.5)
        check("Alt+Right moves the pick (B then A)", active_class() == "omahop-A", active_class())

        # search: hold Alt, Tab, then type part of a title; release picks the match (not the default previous window)
        time.sleep(2.5)  # the snapshot of the current binds is taken 2 s after the module loads
        sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.3)
        for k in ("a", "l", "p"):
            kb.down(k); kb.up(k)
        time.sleep(0.3)
        st = read_state()
        check("typing 'alp' puts the query in the state", st.get("query") == "alp", str(st))
        kb.up("alt"); time.sleep(0.6)
        check("release after typing 'alp' goes to alpha (A), not the default previous window (B)", active_class() == "omahop-A", active_class())
        sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.3)
        for k in ("b", "r", "a"):
            kb.down(k); kb.up(k)
        kb.down("backspace"); kb.up("backspace"); time.sleep(0.3)
        check("backspace removes the last letter", read_state().get("query") == "br", str(read_state()))
        kb.down("escape"); kb.up("escape"); time.sleep(0.3)
        st = read_state()
        check("the first Escape clears the query and keeps the list open", st.get("query") == "" and st.get("open") == "1", str(st))
        for k in ("z", "z", "z"):
            kb.down(k); kb.up(k)
        time.sleep(0.3)
        kb.up("alt"); time.sleep(0.6)
        check("nothing matched: releasing Alt leaves the focus where it was (C)", active_class() == "omahop-C", active_class())
        check("typed letters did not reach the app (no key echo in the state or a stuck session)", read_state().get("open") == "0", str(read_state()))

        # no key is left grabbed after sessions: a plain Escape reaches the app (kitty running sleep ignores it; just assert no state)
        check("binds cleaned: state closed", read_state().get("open") == "0")
finally:
    sh("hyprctl", "reload"); time.sleep(2.5)

ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare(mode="dwindle") as sp, Keyboard() as kb:
        time.sleep(0.5)
        before = active_class()
        alt_tab(kb)
        check("tiling workspace: stock Alt+Tab cycles windows", active_class() != before, f"{before} -> {active_class()}")
        check("tiling workspace: omahop stays closed", read_state().get("open") in (None, "0"), str(read_state()))
finally:
    sh("hyprctl", "reload"); time.sleep(2.5)

if had_cfg:
    open(CFG, "w").write(saved_cfg)
else:
    os.remove(CFG)
    try:
        os.rmdir(os.path.dirname(CFG))
    except OSError:
        pass
print("\nFAILED: " + ", ".join(failed) if failed else "\nall live checks passed")
sys.exit(1 if failed else 0)
