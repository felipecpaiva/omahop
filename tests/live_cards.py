"""Live check of the cards style with REAL thumbnails, no key events: three coloured test windows (A red, B green, C blue) on a spare workspace, A covered by the others
and B minimized, a state file in cards style written by hand, and a screenshot of the overlay. The picture must hold all three colours (a thumbnail per window, also for the covered
and the minimized one) with thumbnails = snapshot, and none of them with thumbnails = off (icons only). Needs the plugin enabled and the shell restarted since the last QML change.
Usage: python3 tests/live_cards.py"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, addr, ev, sh

STATE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "state")
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def write(addrs, thumbnails, open_=1, selected=2, style="cards"):
    lines = ["version=1", f"open={open_}", f"revealed={open_}", f"selected={selected}", f"style={style}", f"thumbnails={thumbnails}", "border=on"]
    for i, (a, n) in enumerate(addrs):
        lines.append(f"w\t{a}\tomahop-{n}\t{1 if n == 'B' else 0}\t\tWindow {n}")
    open(STATE + ".new", "w").write("\n".join(lines) + "\n"); os.rename(STATE + ".new", STATE)


def colours(path):
    """Count strongly red, green and blue pixels of the picture (the test windows are pure colours; the theme and the icons are not)."""
    from struct import unpack
    raw = open(path, "rb").read()
    # PPM from grim -t ppm: header "P6\nW H\n255\n"
    parts = raw.split(b"\n", 3)
    w, h = (int(x) for x in parts[1].split()); data = parts[3]
    n = {"A": 0, "B": 0, "C": 0}
    for i in range(0, len(data) - 2, 3):
        r, g, b = data[i], data[i + 1], data[i + 2]
        # thresholds are loose on purpose: a minimized card is dimmed (opacity 0.7), so its green is darker than the window's own on a dark theme and lighter on a light one: judge it by how much green dominates
        if r > 120 and g < 50 and b < 50: n["A"] += 1
        elif g > 100 and g - max(r, b) > 80: n["B"] += 1
        elif b > 120 and r < 50 and g < 50: n["C"] += 1
    return n


with Spare() as sp:
    # shrink the test windows into the bottom-left corner, away from the strip, so the only big patches of colour in the picture are thumbnails
    for i, n in enumerate("ABC"):
        a = addr("omahop-" + n)
        ev(f'local w = hl.get_window("address:{a}"); hl.dispatch(hl.dsp.window.resize({{ x = 120, y = 80, relative = false, window = w }})); hl.dispatch(hl.dsp.window.move({{ x = {20 + i * 12}, y = {690 + i * 8}, relative = false, window = w }}))')
    time.sleep(1.0)
    ev(f'local w = hl.get_window("address:{addr("omahop-B")}"); hl.dispatch(hl.dsp.window.move({{ workspace = "special:minimized", follow = false, window = w }}))'); time.sleep(1.0)
    addrs = [(addr("omahop-" + n), n) for n in "ACB"]
    for thumbs, expect in (("snapshot", True), ("off", False)):
        write(addrs, thumbs); time.sleep(2.0)
        shot = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", f"cards-{thumbs}.ppm")
        subprocess.run(["grim", "-g", "250,150 780x300", "-t", "ppm", shot])
        n = colours(shot)
        keep = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", f"cards-{thumbs}.png")
        subprocess.run(["grim", "-g", "250,150 780x300", keep])
        if expect:
            check("snapshot: a picture for the covered window (A, red)", n["A"] > 400, str(n))
            check("snapshot: a picture for the minimized window (B, green)", n["B"] > 400, str(n))
            check("snapshot: a picture for the top window (C, blue)", n["C"] > 400, str(n))
        else:
            check("off: icons only, no window pictures", max(n.values()) < 100, str(n))
        os.remove(shot)
        if not failed: os.remove(keep)
    write([], "snapshot", open_=0, selected=0, style="list"); time.sleep(0.5)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall cards checks passed")
sys.exit(1 if failed else 0)
