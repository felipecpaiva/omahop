"""Live check of the pointer on the switcher (v0.3), with a virtual keyboard and mouse on a spare workspace with three coloured windows (recently used order C, B, A).
Spike S4 in one test: the overlay takes the pointer only over its card, hovering changes NOTHING (focus, selection), a click picks, the close button closes a window,
Alt+Delete closes the picked window. Your own config is saved and put back. Needs the plugin enabled and the shell restarted since the last QML change.
Usage: python3 tests/live_pointer.py"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, addr, clients, ev, read_state, sh
from uinput_kbd import Keyboard, Mouse

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.expanduser("~/.config/omahop/config.toml")
GEO = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "geometry")
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def rects():
    try:
        return [tuple(int(v) for v in line.split(",")) for line in open(GEO).read().split() if line]
    except OSError:
        return []


def wait_rects(n, seconds=3.0):
    end = time.time() + seconds
    while time.time() < end:
        r = rects()
        if len(r) == n:
            return r
        time.sleep(0.15)
    return rects()


def move(x, y):
    ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"); time.sleep(0.5)


saved = open(CFG).read() if os.path.exists(CFG) else None
start_cursor = sh("hyprctl", "cursorpos").strip().replace(",", "").split()
os.makedirs(os.path.dirname(CFG), exist_ok=True)
open(CFG, "w").write('style = "list"\nreveal_delay_ms = 0\n[windows]\nworkspaces = "current"\n')
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare() as sp, Keyboard() as kb, Mouse() as m:
        time.sleep(2.5)  # the snapshot of binds is taken 2 s after load
        sp.reset_order()   # C focused, order C, B, A
        # --- hover changes nothing
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        r = wait_rects(3)
        check("the overlay reports three row rectangles", len(r) == 3, str(r))
        if len(r) == 3:
            st0, focus0 = read_state().get("selected"), active_class()
            x, y, w, h = r[2]
            move(x + w // 2, y + h // 2); time.sleep(0.6)
            check("S4: hovering a row does not change the selection", read_state().get("selected") == st0, f"{st0} -> {read_state().get('selected')}")
            check("S4: hovering a row does not change the focused window", active_class() == focus0, f"{focus0} -> {active_class()}")
            check("S4: the session is still open after hovering", read_state().get("open") == "1")
            # --- a click picks that row (row 3 is window A)
            m.press(); time.sleep(0.1); m.release(); time.sleep(0.8)
            check("a click on row 3 picks window A", active_class() == "omahop-A", active_class())
            check("and the session is over", read_state().get("open") == "0", str(read_state()))
        kb.up("alt"); time.sleep(0.5)
        # --- the close button closes a window; the row leaves the list
        sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        r = wait_rects(3)
        if len(r) == 3:
            x, y, w, h = r[1]   # row 2 is window B
            move(x + w // 2, y + h // 2); time.sleep(0.5)
            move(x + w - 22, y + h // 2); time.sleep(0.5)   # the close button: 10 px margin + half of a 24 px button from the right edge
            m.press(); time.sleep(0.1); m.release(); time.sleep(1.5)
            names = [c["class"] for c in clients()]
            check("the close button closes window B", "omahop-B" not in names, str(names))
            check("the row left the list and the session is still open", read_state().get("open") == "1" and len(wait_rects(2)) == 2, str(read_state()))
        # --- Alt+Delete closes the picked window
        pick = read_state().get("selected")
        kb.down("delete"); kb.up("delete"); time.sleep(1.5)
        left = [c["class"] for c in clients() if c["class"].startswith("omahop-")]
        check("Alt+Delete closes the picked window", len(left) == 1, str(left))
        kb.up("alt"); time.sleep(0.6)
finally:
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    if len(start_cursor) == 2:
        move(int(float(start_cursor[0])), int(float(start_cursor[1])))
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall pointer checks passed")
sys.exit(1 if failed else 0)
