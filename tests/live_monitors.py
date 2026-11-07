"""Live check with TWO monitors (v1.0): the window set follows `windows.monitors`, and picking a window on the other monitor moves focus there.
Skips (exit 0, says SKIP) when only one monitor is connected. Puts one kitty window (omahop-D, title delta) on a spare floating workspace of the
other monitor, and removes it at the end. Your own config is saved and put back. Usage: python3 tests/live_monitors.py"""
import json, os, subprocess, sys, time
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from livehelp import Spare, active_class, addr, ev, sh
from uinput_kbd import Keyboard

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CFG = os.path.expanduser("~/.config/omahop/config.toml")
STATE = os.path.join(os.environ["XDG_RUNTIME_DIR"], "omahop", "state")
OTHER_WS = "5"
failed = []


def check(name, ok, detail=""):
    print(("ok   " if ok else "FAIL ") + name + ("" if ok else f"  ({detail})"))
    if not ok:
        failed.append(name)


def monitors():
    return json.loads(sh("hyprctl", "monitors", "-j"))


def focused_monitor():
    return next(m["name"] for m in monitors() if m["focused"])


def state():
    try:
        return open(STATE).read()
    except OSError:
        return ""


def classes():
    """The test's own windows in the list (your other windows may be listed too)."""
    return [c for c in (l.split("\t")[2] for l in state().split("\n") if l.startswith("w\t")) if c.startswith("omahop-")]


def key(kb, k):
    kb.down(k); kb.up(k); time.sleep(0.3)


mons = monitors()
if len(mons) < 2:
    print("SKIP live_monitors: only one monitor connected")
    sys.exit(0)
home = next(m["name"] for m in mons if m["focused"])
other = next(m["name"] for m in mons if m["name"] != home)
mode_file = os.path.expanduser(f"~/.local/state/omarchy/workspace-layouts/{OTHER_WS}.lua")
had_mode_file = os.path.exists(mode_file)
saved = open(CFG).read() if os.path.exists(CFG) else None
os.makedirs(os.path.dirname(CFG), exist_ok=True)
ev(f'dofile("{ROOT}/lua/omahop.lua")'); time.sleep(0.5)
try:
    with Spare() as sp, Keyboard() as kb:
        time.sleep(2.5)
        # a floating workspace with one window on the other monitor
        ev(f'hl.dispatch(hl.dsp.focus({{ monitor = "{other}" }}))'); time.sleep(0.6)
        ev(f'hl.dispatch(hl.dsp.focus({{ workspace = "{OTHER_WS}" }}))'); time.sleep(0.6)
        ev(f'o.workspace_mode({{ workspace = "{OTHER_WS}", mode = "floating" }})'); time.sleep(0.6)
        ev('hl.exec_cmd("[float; size 600 400] kitty --class omahop-D --title delta -e sleep 3600")'); time.sleep(2.0)
        other_id = next(m["id"] for m in mons if m["name"] == other)
        check("setup: the test window is on the other monitor", any(c["class"] == "omahop-D" and c["monitor"] == other_id for c in json.loads(sh("hyprctl", "clients", "-j"))), "omahop-D not on " + other)
        ev(f'hl.dispatch(hl.dsp.focus({{ monitor = "{home}" }}))'); time.sleep(0.6)
        sp.reset_order()
        check("setup: focus is back on the first monitor", focused_monitor() == home, focused_monitor())

        # active monitor only (default): D is not listed
        open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nmonitors = "active"\n')
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        check("monitors = active: the other monitor's window is not listed", "omahop-D" not in classes() and len(classes()) == 3, str(classes()))
        key(kb, "escape"); kb.up("alt"); time.sleep(0.5)

        # all monitors: D is listed, and picking it moves focus to the other monitor
        open(CFG, "w").write('reveal_delay_ms = 0\n[windows]\nmonitors = "all"\n'); sp.reset_order()
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        check("monitors = all: the other monitor's window is listed", "omahop-D" in classes() and len(classes()) == 4, str(classes()))
        for ch in "delta":
            key(kb, ch)
        check("search finds the window on the other monitor", "query=delta" in state(), state()[:160])
        kb.up("alt"); time.sleep(1.0)
        check("picking it focuses that window", active_class() == "omahop-D", active_class())
        check("and focus moves to the other monitor", focused_monitor() == other, focused_monitor())

        # back: the list from there still shows the first monitor's windows (monitors = all)
        kb.down("alt"); kb.down("tab"); kb.up("tab"); time.sleep(0.8)
        check("from the other monitor the list still holds all four windows", len(classes()) == 4, str(classes()))
        key(kb, "escape"); kb.up("alt"); time.sleep(0.5)
        ev(f'hl.dispatch(hl.dsp.focus({{ monitor = "{home}" }}))'); time.sleep(0.5)
finally:
    for c in json.loads(sh("hyprctl", "clients", "-j")):
        if c["class"] == "omahop-D":
            ev(f'local w = hl.get_window("address:{c["address"]}"); if w then hl.dispatch(hl.dsp.window.close({{ window = w }})) end')
    time.sleep(1.0)
    ev(f'hl.dispatch(hl.dsp.focus({{ monitor = "{home}" }}))')
    ev(f'o.workspace_mode({{ workspace = "{OTHER_WS}", mode = "dwindle" }})')
    if not had_mode_file and os.path.exists(mode_file):
        os.remove(mode_file)
    if saved is not None:
        open(CFG, "w").write(saved)
    elif os.path.exists(CFG):
        os.remove(CFG)
    subprocess.run(["hyprctl", "reload"], capture_output=True); time.sleep(2.0)

if failed:
    print("\nFAILED: " + ", ".join(failed))
    sys.exit(1)
print("\nall monitors checks passed")
