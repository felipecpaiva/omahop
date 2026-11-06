"""Live check of the same-app shortcut (v0.4): Alt + grave lists only the windows of the app you are in. Spare workspace with windows A, B, C (classes omahop-A, -B, -C)
plus a second window of class omahop-A titled alpha2. Hyprland is reloaded first so the chord is bound by the real load path (after the snapshot of existing binds).
Your own config is saved and put back. Usage: python3 tests/live_sameapp.py"""
import os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, addr, clients, ev, sh
from uinput_kbd import Keyboard

CFG = os.path.expanduser("~/.config/omahop/config.toml")
STATE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "state")
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def listed():
    try:
        return [l.split("\t")[2] + ":" + l.split("\t")[5] for l in open(STATE).read().split("\n") if l.startswith("w\t")]
    except OSError:
        return []


def selected():
    try:
        return next(l.split("=")[1] for l in open(STATE).read().split("\n") if l.startswith("selected="))
    except (OSError, StopIteration):
        return ""


saved = open(CFG).read() if os.path.exists(CFG) else None
os.makedirs(os.path.dirname(CFG), exist_ok=True)
open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nworkspaces = "current"\n')
subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(6.5)   # the chord is bound 3.5 s after load
try:
    with Spare() as sp, Keyboard() as kb:
        ev('hl.exec_cmd("[float; size 700 450; move 330 280] kitty --class omahop-A --title alpha2 -o background=#c00000 -e sleep 3600")'); time.sleep(2.5)
        check("two windows of the app exist", len([c for c in clients() if c["class"] == "omahop-A"]) == 2)
        sp.reset_order()
        sp.focus("A")
        import json
        def active(): d = json.loads(sh("hyprctl", "activewindow", "-j")); return d.get("class"), d.get("title")
        before = active()
        # Alt + grave from window A lists only the omahop-A windows
        kb.down("alt"); kb.down("grave"); kb.up("grave"); time.sleep(0.8)
        names = listed()
        check("Alt + grave lists only the windows of the focused app", len(names) == 2 and all(n.startswith("omahop-A") for n in names), str(names))
        check("the first pick is the app's other window", selected() == "2", selected())
        kb.up("alt"); time.sleep(0.8)
        after = active()
        check("releasing Alt goes to the app's other window (same app, a different window)", after[0] == "omahop-A" and after[1] != before[1], f"{before} -> {after}")
        # Alt + Tab still lists everything
        sp.focus("C")
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        check("Alt + Tab still lists every window", len(listed()) == 4, str(listed()))
        kb.up("alt"); time.sleep(0.6)
        # an app with one window: nothing to cycle, the session does not open
        sp.focus("C")
        kb.down("alt"); kb.down("grave"); kb.up("grave"); time.sleep(0.6)
        check("an app with a single window: no list", "open=1" not in open(STATE).read(), "")
        kb.up("alt"); time.sleep(0.4)
finally:
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)
print("\nFAILED: " + ", ".join(failed) if failed else "\nall same-app checks passed")
sys.exit(1 if failed else 0)
