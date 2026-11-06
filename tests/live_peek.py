"""Live check of the peek strip (v0.3), virtual mouse, spare workspace with three coloured windows (A, B, C). Clicks on real positions the strip reports.
 - peek = off adds nothing to the desktop (no layer at all);
 - peek = always shows a slot per app; hovering a slot shows a card per window and changes NO focus; a click on a card goes to that window;
   the close button on a card closes the window;
 - peek = edge shows nothing until the pointer touches the edge, then the strip, and hides again after the pointer leaves.
Your own config is saved and put back. Needs the plugin enabled and the shell restarted since the last QML change. Usage: python3 tests/live_peek.py"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, addr, clients, ev, sh
from uinput_kbd import Mouse

CFG = os.path.expanduser("~/.config/omahop/config.toml")
GEO = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "peek-geometry-eDP-1")
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def peek_layer():
    return any(l["namespace"] == "omahop-peek" for m in json.loads(sh("hyprctl", "layers", "-j")).values() for ls in m["levels"].values() for l in ls)


def geo():
    try:
        out = []
        for line in open(GEO).read().split("\n"):
            if line:
                k, name, x, y, w, h = line.split(",")
                out.append((k, name, int(x), int(y), int(w), int(h)))
        return out
    except OSError:
        return []


def wait_geo(pred, seconds=4.0):
    end = time.time() + seconds
    while time.time() < end:
        g = geo()
        if pred(g):
            return g
        time.sleep(0.2)
    return geo()


def move(x, y, mouse=None):
    """Warp the pointer. A warp inside the window the pointer is already in sends the app no motion event (hover handlers stay still), a real mouse always does:
    pass the Mouse to add a one-pixel wiggle so the app sees motion at the new place."""
    ev(f"hl.dispatch(hl.dsp.cursor.move({{ x = {x}, y = {y} }}))"); time.sleep(0.4)
    if mouse is not None:
        mouse.move(1, 0); time.sleep(0.1); mouse.move(-1, 0)
    time.sleep(0.4)


def centre(r):
    return r[2] + r[4] // 2, r[3] + r[5] // 2


saved = open(CFG).read() if os.path.exists(CFG) else None
start = sh("hyprctl", "cursorpos").strip().replace(",", "").split()
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
os.makedirs(os.path.dirname(CFG), exist_ok=True)
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)   # the Lua side the strip calls into (focus_window)
try:
    with Spare() as sp, Mouse() as m:
        # --- off: nothing at all
        open(CFG, "w").write('peek = "off"\n'); time.sleep(2.5)
        check("peek = off adds no layer to the desktop", not peek_layer())
        # --- always
        open(CFG, "w").write('peek = "always"\n'); time.sleep(3.0)
        check("peek = always creates the strip layer", peek_layer())
        g = wait_geo(lambda g: any(r[1] == "omahop-A" for r in g))
        slots = {r[1]: r for r in g if r[0] == "slot"}
        check("a slot per app, including the test windows", all(f"omahop-{n}" in slots for n in "ABC"), str(sorted(slots)))
        if all(f"omahop-{n}" in slots for n in "ABC"):
            sp.focus("C")
            focus0 = active_class()
            x, y = centre(slots["omahop-A"])
            move(x, y); time.sleep(0.8)
            cards = [r for r in wait_geo(lambda g: any(r[0] == "card" for r in g)) if r[0] == "card"]
            check("hovering a slot shows a card for its window", len(cards) == 1, str(cards))
            check("S4: hovering the strip changes no focus", active_class() == focus0, f"{focus0} -> {active_class()}")
            if cards:
                cx, cy = centre(cards[0]); move(cx, cy); time.sleep(0.4)
                m.press(); time.sleep(0.1); m.release(); time.sleep(1.0)
                check("a click on the card goes to that window (A)", active_class() == "omahop-A", active_class())
            # the close button: top right of the card (the strip card layout: pad 8 + 4 from the top right, 24 px buttons, close is the right one)
            sp.focus("C")
            g = wait_geo(lambda g: any(r[1] == "omahop-B" for r in g)); slots = {r[1]: r for r in g if r[0] == "slot"}
            x, y = centre(slots["omahop-B"]); move(x, y); time.sleep(0.8)
            cards = [r for r in wait_geo(lambda g: any(r[0] == "card" for r in g)) if r[0] == "card"]
            if cards:
                _, _, cx, cy, cw, ch = cards[0]
                move(cx + cw // 2, cy + ch // 2); time.sleep(0.5)
                move(cx + cw - 8 - 4 - 12, cy + 8 + 4 + 12); time.sleep(0.5)
                m.press(); time.sleep(0.1); m.release(); time.sleep(1.5)
                check("the close button on a card closes the window (B)", "omahop-B" not in [c["class"] for c in clients()], str([c["class"] for c in clients()]))
        # --- edge: hidden until the pointer touches the edge
        open(CFG, "w").write('peek = "edge"\n'); time.sleep(3.0)
        move(640, 400); time.sleep(1.0)
        check("edge: nothing shown while the pointer is elsewhere", not [r for r in geo() if r[0] == "slot"], str(geo()))
        move(1279, 400); time.sleep(1.2)
        check("edge: the strip appears when the pointer touches the right edge", bool([r for r in wait_geo(lambda g: any(r[0] == "slot" for r in g)) if r[0] == "slot"]))
        # from the hot edge straight onto an app: the popup must show (the pointer leaves the hot zone and enters the strip in one jump)
        g = wait_geo(lambda g: any(r[1] == "omahop-A" for r in g)); slots = {r[1]: r for r in g if r[0] == "slot"}
        if "omahop-A" in slots:
            x, y = centre(slots["omahop-A"]); move(x, y, m); time.sleep(1.0)
            cards = [r for r in wait_geo(lambda g: any(r[0] == "card" for r in g)) if r[0] == "card"]
            check("edge: hovering an app right after the edge shows its window card", len(cards) >= 1, str(geo()))
        move(640, 400); time.sleep(1.5)
        check("edge: it hides again after the pointer leaves", not [r for r in geo() if r[0] == "slot"], str(geo()))
finally:
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    if len(start) == 2:
        move(int(float(start[0])), int(float(start[1])))
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall peek checks passed")
sys.exit(1 if failed else 0)
